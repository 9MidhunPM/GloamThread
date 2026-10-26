extends SceneTree
## Entire original campaign, using owned-input waypoints rather than room skips.
const Shared := preload("res://tools/arena_showcase.gd")
const ROOM_NOTES := {
	"r00": "LANTERN REST / Oru, the first checkpoint and a reason to return home.",
	"r01": "MOSSFOOT ATRIUM / Remember the blocked upper route; return after earning Threadstep.",
	"r02": "SPINDLE STEPS / Each courier takes a separate staircase and activates a different anchor.",
	"r03": "GLASSWING GALLERY / Cooperative combat, then a climb to the hidden Lantern Charm.",
	"r04": "WARDEN'S LANDING / Activate the second checkpoint before confronting the guardian.",
	"r05": "BROKEN BELL / Fight the live Spoolwarden and earn team Threadstep.",
	"r06": "SEVERED CAUSEWAY / Jump + dash across the gap, then weave the second paired bridge.",
	"r07": "LANTERN LOOM / Light both stations, restore the road, and return home together."
}

class StoryOverlay extends CanvasLayer:
	var controller: SceneTree
	var caption: Label
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process_input(true)
		layer = 100
		var back := ColorRect.new()
		back.position = Vector2(0, 360)
		back.size = Vector2(960, 60)
		back.color = Color("0b1620")
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(back)
		caption = Label.new()
		caption.position = Vector2(12, 366)
		caption.size = Vector2(936, 50)
		caption.add_theme_font_size_override("font_size", 11)
		caption.add_theme_color_override("font_color", Color("f2e2b9"))
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(caption)
	func _input(event: InputEvent) -> void:
		if not event is InputEventKey or not event.pressed or event.echo: return
		match event.physical_keycode:
			KEY_SPACE: controller.toggle_pause()
			KEY_1: controller.set_speed(1)
			KEY_2: controller.set_speed(2)
			KEY_4: controller.set_speed(4)
			KEY_ESCAPE: controller.stop_tour()
			_: return
		get_viewport().set_input_as_handled()

var options := {"mode": "full", "speed": 1, "report": "/tmp/gloamthread-story-showcase.json"}
var errors := Shared.Errors.new()
var driver: Node
var overlay: StoryOverlay
var viewer_paused := false
var quit_requested := false
var finishing := false
var attached := false
var room_events: Array[Dictionary] = []
var dialogue_events: Array[Dictionary] = []
var _dialogue_key := ""
var _dialogue_elapsed := 0.0

func _initialize() -> void:
	OS.add_logger(errors)
	call_deferred("_run")

func _parse() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.size() % 2 != 0: return false
	for index in range(0, args.size(), 2):
		var key := args[index].trim_prefix("--")
		if not options.has(key): return false
		if key == "speed":
			if not args[index + 1].is_valid_int(): return false
			options[key] = int(args[index + 1])
		else: options[key] = args[index + 1]
	return options.mode in ["full", "smoke"] and options.speed in [1, 2, 4] and not str(options.report).is_empty()

func _run() -> void:
	if not _parse() or (DisplayServer.get_name() == "headless" and options.mode != "smoke"):
		printerr("Usage: ./story_showcase.sh [--smoke] [--speed 1|2|4] [--report PATH]")
		quit(2)
		return
	root.close_requested.connect(stop_tour)
	set_speed(options.speed)
	if DisplayServer.get_name() != "headless":
		overlay = StoryOverlay.new()
		overlay.controller = self
		root.add_child(overlay)
	var script := load("res://tools/story_showcase_driver.gd") as GDScript
	if script == null or not script.can_instantiate():
		errors.messages.append("Story showcase driver could not load.")
		await _finish()
		return
	driver = script.new()
	driver.smoke = options.mode == "smoke"
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(driver)
	await driver.run()
	if not quit_requested and options.mode != "smoke" and driver._route_complete:
		# Hold the ending card for seven viewing seconds. Frame time (not the
		# wall clock) keeps this right when Movie Maker renders slower than real time.
		var remaining := 7.0
		while remaining > 0.0 and not quit_requested:
			await process_frame
			remaining -= root.get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	await _finish()

func _process(delta: float) -> bool:
	if finishing or not is_instance_valid(driver) or not is_instance_valid(driver.session): return false
	var session: Node = driver.session
	if not attached:
		attached = true
		# Two original480x360 views remain intact; the viewing banner lives below.
		# Movie Maker scales the root texture to cover 16:9, so recordings use a
		# 16:9 canvas (blank band below the banner) instead of cropping the views.
		root.content_scale_size = Vector2i(960, 540) if OS.has_feature("movie") else Vector2i(960, 420)
		if DisplayServer.get_name() != "headless": root.mode = Window.MODE_FULLSCREEN
		session.room_changed.connect(_room_changed)
		_room_changed(session.current_room_id)
	if session.mode == "dialogue" and not viewer_paused:
		var key := "%s:%d" % [session.dialogue_id, driver.app._dialogue_line]
		var sequence: Array = driver.app.catalog.dialogue_sequence(session.dialogue_id)
		if key != _dialogue_key:
			_dialogue_key = key
			_dialogue_elapsed = 0
			dialogue_events.append({"id": session.dialogue_id, "line": driver.app._dialogue_line})
		_dialogue_elapsed += delta
		var hold := 0.0 if options.mode == "smoke" else maxf(2.5, str(sequence[driver.app._dialogue_line].text).length() / 20.0)
		if _dialogue_elapsed >= hold: driver.app._on_action("next")
	if overlay != null:
		var flags: Dictionary = session.progress.flags
		overlay.caption.text = "STORY AUTOPLAY / TAVI + NERI / %d OF 8 ROOMS   |   %s\n%s\nSPACE pause/resume   1/2/4 speed (%dx)   ESC quit   |   Boss:%s  Dash:%s  Secret:%s%s" % [driver._visited.size(), str(session.current_room_id).to_upper(), ROOM_NOTES.get(session.current_room_id, ""), options.speed, flags.has("boss_spoolwarden"), flags.has("threadstep"), flags.has("lantern_charm"), " / PAUSED" if viewer_paused or session.mode == "pause" else ""]
	return false

func _room_changed(room_id: String) -> void:
	room_events.append({"room": room_id, "tick": driver._tick_count, "flags": driver.session.progress.flags.duplicate()})

func toggle_pause() -> void:
	if not is_instance_valid(driver) or not is_instance_valid(driver.session): return
	var session: Node = driver.session
	if session.mode == "pause" and not viewer_paused:
		_release_bot_inputs()
		session.request_mode("playing", 0)
		return
	viewer_paused = not viewer_paused
	if viewer_paused and session.mode == "playing": session.request_mode("pause", 0)
	elif not viewer_paused and session.mode == "pause":
		_release_bot_inputs()
		session.request_mode("playing", 0)

func _release_bot_inputs() -> void:
	# Resume flushes held actions until release. Give that real menu boundary a
	# neutral bot snapshot before the waypoint controller reissues its movement.
	for slot in 2: root.get_node("InputRouter").set_test_input(slot, 0)

func set_speed(value: int) -> void:
	options.speed = value
	Engine.time_scale = float(value)
	Engine.physics_ticks_per_second = 60 * value

func stop_tour() -> void:
	if finishing: return
	quit_requested = true
	if is_instance_valid(driver): driver.cancelled = true
	_finish()

func _finish() -> void:
	if finishing: return
	finishing = true
	paused = true
	var report := {"mode": options.mode, "engine": Engine.get_version_info().string, "display": DisplayServer.get_name(), "completed": false, "interrupted": quit_requested, "rooms": room_events, "dialogue": dialogue_events, "errors": errors.messages, "human_playtest": false, "input": "Owned keyboard snapshots and actual menu actions, sequential eight-room campaign. No actor placement, damage/health overrides, room skips or progression grants."}
	var temporary := ""
	if is_instance_valid(driver):
		driver.cancelled = true
		temporary = driver.temporary_dir
		report.failures = driver.failures
		report.visited = driver._visited
		report.physics_ticks = driver._tick_count
		if is_instance_valid(driver.session):
			report.flags = driver.session.progress.flags.duplicate()
			report.final_mode = driver.session.mode
			report.recoveries = driver.session.recovery_count
			report.hearts = [driver.session.players[0].hearts, driver.session.players[1].hearts]
			report.downed = [driver.session.players[0].downed, driver.session.players[1].downed]
			report.saved = driver.session.save_repository.load_campaign().status
			report.completed = driver._route_complete and driver.failures.is_empty() and errors.messages.is_empty() and not quit_requested
		if is_instance_valid(driver.app): driver.app.free()
		# The cancelled route may still await a frame; retire it with the tree.
	var router := root.get_node("InputRouter")
	router.clear_test_input()
	for slot in 2: router.clear(slot)
	await _retire_audio()
	if temporary.begins_with("/tmp/gloamthread-story-showcase-"):
		for name: String in DirAccess.get_files_at(temporary): DirAccess.remove_absolute(temporary.path_join(name))
		DirAccess.remove_absolute(temporary)
	report.source_hashes = {}
	for path: String in ["tools/story_showcase.gd", "tools/story_showcase_driver.gd", "tests/scenarios/campaign_route.gd", "scripts/session/game_session.gd", "scripts/app/app_controller.gd"]:
		report.source_hashes[path] = FileAccess.get_sha256("res://" + path)
	report.completed = report.completed and errors.messages.is_empty()
	var file := FileAccess.open(options.report, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write story report: ", options.report)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	Engine.time_scale = 1
	Engine.physics_ticks_per_second = 60
	print("STORY_SHOWCASE_RESULT ", JSON.stringify({"completed": report.completed, "interrupted": quit_requested, "failures": report.get("failures", []), "errors": errors.messages, "report": options.report}))
	quit(0 if errors.messages.is_empty() and (report.completed or quit_requested) else 1)

func _retire_audio() -> void:
	var audio := root.get_node("AudioDirector")
	var playbacks: Array[WeakRef] = []
	for player: Node in audio.get_children():
		if player is AudioStreamPlayer and player.has_stream_playback(): playbacks.append(weakref(player.get_stream_playback()))
	audio.stop_music()
	audio.stop_cues()
	var deadline := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline and playbacks.any(func(reference: WeakRef) -> bool: return reference.get_ref() != null):
		await process_frame
