extends SceneTree
## Controlled native render fixtures, not a normal-input route or human playtest.
## Uses production App/session/actors once, with explicit placement/state setup.

class Capture extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String, reason: String, _notify: bool, type: int, _trace: Array[ScriptBacktrace]) -> void:
		if type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s" % [file, line, reason if not reason.is_empty() else code])

const SOURCE_FILES := ["scripts/arena/arena_app.gd", "scripts/arena/run_session.gd", "scripts/arena/arena_map.gd", "scripts/arena/arena_chunk.gd", "scripts/arena/arena_presentation.gd", "scripts/arena/arena_parallax.gd", "scripts/arena/actors/arena_enemy.gd", "scripts/arena/actors/arena_fighter.gd", "content/arena/world.json", "assets/arena/scenery/index.json", "tools/scrolling_native_qa.gd"]
var app: Node
var world: Node
var presentation: Node
var router: Node
var output := "/tmp/gloamthread-scrolling-native"
var capture := Capture.new()
var cases: Array[Dictionary] = []


func _initialize() -> void:
	OS.add_logger(capture)
	call_deferred("_run")


func _run() -> void:
	var profile := false
	var args := OS.get_cmdline_user_args()
	var cursor := 0
	while cursor < args.size():
		if args[cursor] == "--profile":
			profile = true
		elif args[cursor] == "--output" and cursor + 1 < args.size():
			cursor += 1
			output = args[cursor]
		else:
			printerr("Usage: -- --output /tmp/captures [--profile]")
			quit(2)
			return
		cursor += 1
	DirAccess.make_dir_recursive_absolute(output)
	var before := _source_hashes()
	router = root.get_node("InputRouter")
	root.size = Vector2i(1920, 1080)
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	var script := load("res://scripts/arena/arena_app.gd") as GDScript
	app = script.new()
	var stamp := str(Time.get_ticks_usec())
	app.settings_store.path = "user://scrolling-native-settings-" + stamp + ".json"
	app.records.path = "user://scrolling-native-records-" + stamp + ".json"
	root.add_child(app)
	await process_frame
	app._show_lobby(2)
	app._begin_run(18427)
	world = app.session
	presentation = app.presentation
	if not is_instance_valid(world) or world.phase == "error":
		printerr("Native fixture could not start the actual scrolling session.")
		quit(1)
		return
	world.set_physics_process(false)
	presentation.set_physics_process(false)
	for fighter: Node in world.fighters:
		fighter.set_physics_process(false)
		router.set_test_input(int(fighter.slot_index), 0)
	world.spawn_queue.clear()
	world.telegraphs.clear()
	world._set_phase("combat")
	var landmark: Dictionary = world.map.landmarks[0]
	var centre: Vector2 = landmark.position
	_place(centre - Vector2(60, 0), centre + Vector2(60, 0))
	await _capture("merged_landmark", "Initial four-chunk region, first original landmark; explicit grounded placements and frozen encounter/actors.")
	_place(centre, Vector2(centre.x + 270, 624))
	await _capture("split_main_cave", "Vertical separation selects dynamic split: P1 on main ground, P2 in the connected shallow cave.")
	world.wave = 15
	world.stage = 2
	world._open_shop()
	world.set_shop_open(0, false)
	world.set_shop_open(1, false)
	world._set_phase("combat")
	var frontier := float(world.world_bounds().end.x)
	_place(Vector2(frontier - 220, 320), Vector2(frontier - 100, 320))
	await _capture("expanded_frontier", "Sixteen-chunk region after the three stage expansions; right frontier clamp and alternate owner theme.")
	world._open_shop()
	for state: RefCounted in world.player_states:
		state.coins = 24
	world.set_shop_open(0, false)
	world.set_shop_open(1, true)
	_place(Vector2(1850, 320), Vector2(2200, 320))
	world.fighters[0].set_physics_process(true)
	var start: Vector2 = world.fighters[0].position
	router.set_test_input(0, CommandSnapshot.Action.RIGHT)
	for frame in 60:
		_hold_focus_state()
		await physics_frame
		presentation._physics_process(1.0 / 60.0)
	router.set_test_input(0, 0)
	world.fighters[0].set_physics_process(false)
	app._update_hud()
	await _capture("personal_shop_exploration", "P1 traverses through ordinary owned right input for sixty physics ticks while P2's actual personal shop remains open. Initial positions and wallets are controlled fixture values.")
	var exploration := {"start": [start.x, start.y], "end": [world.fighters[0].position.x, world.fighters[0].position.y], "moved": world.fighters[0].position.x > start.x + 20, "p1_movement_allowed": world.movement_allowed(0), "p2_movement_allowed": world.movement_allowed(1), "shop_open": world.shop_open.duplicate()}
	var profile_result: Dictionary = {}
	if profile:
		profile_result = await _profile()
	var after := _source_hashes()
	var report := {"fixture": "Actual production App with explicit controlled placements/state. Shared world/audio instantiated once. Native hidden-workspace offscreen force_draw captures; not a normal route, scanout-FPS measure or human playtest.", "human_playtest": false, "engine": Engine.get_version_info().string, "display": DisplayServer.get_name(), "renderer": RenderingServer.get_video_adapter_name(), "root_size": [root.size.x, root.size.y], "source_sha256": before, "source_changed_during_fixture": before != after, "cases": cases, "personal_shop_input": exploration, "errors": capture.errors, "profile": profile_result, "passed": capture.errors.is_empty() and exploration.moved and exploration.p1_movement_allowed and not exploration.p2_movement_allowed}
	_write(output.path_join("report.json"), report)
	print("SCROLLING_NATIVE_QA ", JSON.stringify(report))
	app.free()
	router.clear_test_input()
	for slot in 2:
		router.clear(slot)
	await _retire_audio()
	quit(0 if report.passed else 1)


func _hold_focus_state() -> void:
	paused = false
	if app.screen == "pause":
		app._resume()


func _place(first: Vector2, second: Vector2) -> void:
	_hold_focus_state()
	for slot in 2:
		world.fighters[slot].position = world.safe_position(first if slot == 0 else second)
		world.fighters[slot].velocity = Vector2.ZERO
		world.fighters[slot].reset_physics_interpolation()
	world._process_discoveries()
	presentation.force_split = world.shop_open.has(true)
	# Exercise the production hysteresis, then snap only the render interpolation
	# for a stable fixture capture. No duplicate world or per-view actor exists.
	for tick in 60:
		presentation._physics_process(1.0 / 60.0)
	presentation._snap = true
	presentation._update_cameras(0.0)
	app._update_hud()


func _capture(label: String, note: String) -> void:
	_hold_focus_state()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var screenshot := root.get_texture().get_image()
	if screenshot == null or screenshot.is_empty() or screenshot.save_png(output.path_join(label + ".png")) != OK:
		capture.errors.append("Could not retain native capture " + label)
	var rectangles: Array = []
	for rect: Rect2 in presentation.visible_world_rects():
		rectangles.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	var positions: Array = []
	for fighter: Node2D in world.fighters:
		positions.append([fighter.position.x, fighter.position.y])
	cases.append({"name": label, "note": note, "split": presentation.split, "view_sizes": [[presentation.viewport_a.size.x, presentation.viewport_a.size.y], [presentation.viewport_b.size.x, presentation.viewport_b.size.y]], "visible_world_rects": rectangles, "player_positions": positions, "phase": world.phase, "chunks": world.map.chunks.size(), "same_world": presentation.viewport_a.world_2d == presentation.viewport_b.world_2d, "fighters": world.fighters.size(), "shop_open": world.shop_open.duplicate(), "capture_sha256": FileAccess.get_sha256(output.path_join(label + ".png"))})


func _profile() -> Dictionary:
	# Optional controlled load; Root runs this only after other CPU work is quiet.
	# Health and immunity are normal; stop/report if this fixture ends early.
	world.set_shop_open(0, false)
	world.set_shop_open(1, false)
	world._set_phase("combat")
	world.wave = 1
	world.wave_record = world.director.definition(1)
	world.spawn_queue.clear()
	world.telegraphs.clear()
	_place(Vector2(2600, 320), Vector2(3900, 320))
	for fighter: Node in world.fighters:
		fighter.set_physics_process(true)
	world.set_physics_process(true)
	presentation.set_physics_process(true)
	# Precompute fixture-only arrival anchors outside the timed loop. Production
	# spawning uses validated anchors; scanning safe_position per replacement
	# would benchmark harness work rather than the game.
	var arrivals: Array[Array] = []
	for fighter: Node2D in world.fighters:
		var points: Array[Vector2] = []
		for at: Vector2 in world.map.spawn_candidates(fighter.position, 420):
			if absf(at.y - 320) < 1: points.append(at)
		arrivals.append(points)
	var samples: Array[float] = []
	var physics: Array[float] = []
	var process: Array[float] = []
	var started := Time.get_ticks_usec()
	var previous := started
	var maximum_enemies := 0
	var maximum_projectiles := 0
	var tick := 0
	while Time.get_ticks_usec() - started < 10_000_000:
		_hold_focus_state()
		if world.phase != "combat":
			break
		for slot in 2:
			router.set_test_input(slot, CommandSnapshot.Action.ATTACK | (CommandSnapshot.Action.SPECIAL if tick % 120 == 0 else 0))
		while world.living_enemies() < 32:
			var index := int(world.living_enemies())
			var fighter: Node2D = world.fighters[index % 2]
			var points: Array = arrivals[index % 2]
			var at: Vector2 = points[(index / 2) % points.size()]
			var role: String = ArenaCatalog.ROLES[posmod(index + tick, 6)]
			world._spawn_enemy({"role": role, "boss": "", "elite": index % 7 == 0, "position": at - Vector2(0, 80) if role == "flyer" else at})
		maximum_enemies = maxi(maximum_enemies, world.living_enemies())
		if tick % 6 == 0:
			for slot in 2:
				var fighter: Node2D = world.fighters[slot]
				world.spawn_projectile(fighter.position + Vector2(-135, -85), Vector2(1, 0.15), 1, -1, {"hostile": true, "speed": 170, "life": 180})
		maximum_projectiles = maxi(maximum_projectiles, get_nodes_in_group("arena_projectiles").size())
		RenderingServer.force_draw(false)
		await process_frame
		var now := Time.get_ticks_usec()
		if now - started > 1_000_000:
			samples.append(float(now - previous) / 1000.0)
			physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		previous = now
		tick += 1
	for slot in 2:
		router.set_test_input(slot, 0)
	samples.sort()
	physics.sort()
	process.sort()
	await _capture("split_crowd_fixture", "Optional bounded split-view load: manually replenished thirty-two ordinary enemies and nearby projectiles around both players, with ordinary owned attacks and normal health/immunity.")
	var report := {"offscreen_rendering_only": true, "fixture_wave": 1, "fixture_note": "32 manually replenished wave-one actors with normal starter stats; not production wave-one concurrency or human balance. Replacement anchors precomputed outside timing.", "duration_seconds": float(Time.get_ticks_usec() - started) / 1000000.0, "observed_max_enemies": maximum_enemies, "observed_max_projectiles": maximum_projectiles, "frames": samples.size(), "median_frame_ms": _percentile(samples, 0.5), "p95_frame_ms": _percentile(samples, 0.95), "p99_frame_ms": _percentile(samples, 0.99), "maximum_frame_ms": _percentile(samples, 1.0), "p95_physics_ms": _percentile(physics, 0.95), "p95_process_ms": _percentile(process, 0.95), "final_phase": world.phase, "split": presentation.split}
	_write(output.path_join("profile.json"), report)
	return report


func _percentile(values: Array[float], fraction: float) -> float:
	return values[mini(values.size() - 1, int(values.size() * fraction))] if not values.is_empty() else 0.0


func _source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in SOURCE_FILES:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result


func _write(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		capture.errors.append("Could not retain native report.")
		return
	file.store_string(JSON.stringify(value, "\t") + "\n")
	file.close()


func _retire_audio() -> void:
	var audio := root.get_node("AudioDirector")
	var references: Array[WeakRef] = []
	for voice: Node in audio.get_children():
		if voice is AudioStreamPlayer and voice.has_stream_playback():
			references.append(weakref(voice.get_stream_playback()))
	audio.stop_music()
	audio.stop_cues()
	var deadline := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline and references.any(func(reference: WeakRef) -> bool: return reference.get_ref() != null):
		await process_frame
