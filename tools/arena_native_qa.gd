extends SceneTree
## Native renderer observation: ordinary UI plus an explicit capped-crowd fixture.
## This fixture is not the ordinary-input run or a human playtest.

var app: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var folder := "/tmp/gloamthread-arena-native-qa"
	var candidate_path := ""
	var args := OS.get_cmdline_user_args()
	for index in range(0, args.size() - 1, 2):
		if args[index] == "--output":
			folder = args[index + 1]
		elif args[index] == "--candidate":
			candidate_path = args[index + 1]
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1920, 1080)
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	var app_script := load("res://scripts/arena/arena_app.gd") as GDScript
	app = app_script.new()
	app.settings_store.path = "user://native-qa-settings.json"
	app.records.path = "user://native-qa-records.json"
	root.add_child(app)
	await _capture(folder, "title")
	if not candidate_path.is_empty():
		var loaded: Dictionary = app.library.load_bundle(candidate_path)
		if not loaded.ok:
			printerr("Native candidate rejected: ", loaded.error)
			quit(1)
			return
		app.selected[0] = loaded.bundle
	app._show_lobby(2)
	await _capture(folder, "lobby")
	app._open_creator(0)
	app.creator._tabs.current_tab = 1
	await _capture(folder, "creator")
	app.creator.cancelled.emit()
	app._begin_run()
	await process_frame
	var world: Node = app.session
	world.phase = "combat"
	world.spawn_queue.clear()
	world.telegraphs.clear()
	for index in 32:
		_spawn(world, index)
	var samples: Array[float] = []
	var process_samples: Array[float] = []
	var physics_samples: Array[float] = []
	var started := Time.get_ticks_usec()
	var previous := started
	var maximum_enemies := 0
	var maximum_projectiles := 0
	var router := root.get_node("InputRouter")
	var step := 0
	while Time.get_ticks_usec() - started < 10_000_000:
		paused = false
		if app.screen == "pause":
			app._resume()
		if str(world.phase) != "combat":
			break
		for slot in 2:
			var fighter: Node = world.fighters[slot]
			var held := CommandSnapshot.Action.ATTACK
			if step % 120 == 0:
				held |= CommandSnapshot.Action.SPECIAL
			router.set_test_input(slot, held)
		while world.living_enemies() < 32:
			_spawn(world, step + world.living_enemies())
		maximum_enemies = maxi(maximum_enemies, world.living_enemies())
		if step % 6 == 0:
			world.spawn_projectile(Vector2(30, 220 + step % 90), Vector2.RIGHT, 1.0, -1, {"hostile": true, "speed": 170, "life": 180})
		maximum_projectiles = maxi(maximum_projectiles, get_nodes_in_group("arena_projectiles").size())
		# Hidden Wayland windows may stop presentation callbacks. This explicitly
		# measures offscreen native rendering, separately from physical scanout.
		RenderingServer.force_draw(false)
		await process_frame
		var now := Time.get_ticks_usec()
		if now - started > 1_000_000:
			samples.append((now - previous) / 1000.0)
			process_samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
			physics_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000)
		previous = now
		step += 1
	samples.sort()
	process_samples.sort()
	physics_samples.sort()
	var report := {"fixture": "Production App with 32 manually spawned ordinary enemies, replacement spawns and ordinary owned attacks. Explicit offscreen native draw on an agent workspace; not a normal route, scanout FPS or physical display playtest.", "engine": Engine.get_version_info().string, "renderer": RenderingServer.get_video_adapter_name(), "display": DisplayServer.get_name(), "root_size": [root.size.x, root.size.y], "world_size": [app.world_view.size.x, app.world_view.size.y], "observed_max_enemies": maximum_enemies, "observed_max_projectiles": maximum_projectiles, "render_frames": samples.size(), "duration_seconds": (Time.get_ticks_usec() - started) / 1000000.0, "median_frame_ms": _percentile(samples, 0.5), "p95_frame_ms": _percentile(samples, 0.95), "p99_frame_ms": _percentile(samples, 0.99), "maximum_frame_ms": _percentile(samples, 1.0), "p95_process_ms": _percentile(process_samples, 0.95), "p95_physics_ms": _percentile(physics_samples, 0.95), "final_phase": world.phase, "human_playtest": false}
	await _capture(folder, "crowd_fixture")
	world._open_shop()
	await _capture(folder, "shop")
	var file := FileAccess.open(folder.path_join("profile.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("ARENA_NATIVE_QA ", JSON.stringify(report))
	app.free()
	router.clear_test_input()
	root.get_node("AudioDirector").stop_music()
	root.get_node("AudioDirector").stop_cues()
	await create_timer(0.1).timeout
	quit()


func _spawn(world: Node, index: int) -> void:
	world._spawn_enemy({"role": ArenaCatalog.ROLES[posmod(index, 6)], "boss": "", "elite": index % 7 == 0, "position": Vector2(40 + posmod(index, 24) * 23, 200 if index % 6 == 4 else 320)})


func _capture(folder: String, name: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(folder.path_join(name + ".png"))


func _percentile(values: Array[float], fraction: float) -> float:
	return values[mini(values.size() - 1, int(values.size() * fraction))] if not values.is_empty() else 0.0
