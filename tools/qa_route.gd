class_name QaRoute
extends SceneTree
## Native rendered observation of the unchanged campaign scenario.
## Run without --headless or --fixed-fps. Gameplay uses synthetic owned input;
## this harness never moves an actor, changes progress, or drives the route.

const ROUTE_PATH := "res://tests/scenarios/campaign_route.gd"
const CAPTURE_ROOMS := ["r00", "r02", "r03", "r05", "r06", "r07"]
const TIMEOUT_MSEC := 600_000

var _output: String = "/tmp/gloamthread-render-qa"
var _scenario: Scenario
# Resolve gameplay only after autoloads initialize. A SceneTree main script's
# static GameSession dependency compiles before InputRouter/AudioDirector exist.
var _session: Variant = null
var _started_msec: int = 0
var _finishing: bool = false
var _capture_pending: int = 0
var _last_capture_frame: int = -100
var _requested: Dictionary = {}
var _captures: Array[Dictionary] = []
var _samples: Array[Dictionary] = []
var _failures: Array[String] = []
var _environment: Dictionary = {}


func _initialize() -> void:
	_started_msec = Time.get_ticks_msec()
	var configured := OS.get_environment("GLOAMTHREAD_QA_OUTPUT")
	if not configured.is_empty():
		_output = configured
	call_deferred("_run")


func _run() -> void:
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		printerr("RENDER_QA_FAIL could not create output directory: " + _output)
		quit(1)
		return
	_environment = {
		"engine": Engine.get_version_info(),
		"os": OS.get_name(),
		"cpu": OS.get_processor_name(),
		"display_server": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"gpu_name": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"window_size_px": _size(DisplayServer.window_get_size()),
		"root_viewport_size_px": _size(root.size),
		"logical_composite_px": _size(root.content_scale_size),
		"physics_hz": Engine.physics_ticks_per_second,
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"input": "Synthetic owned command snapshots: keyboard-left P1, keyboard-right P2; not physical-device or human-play evidence.",
		"route": ROUTE_PATH,
		"menu_boundary": "The campaign scenario invokes production AppController menu actions; movement and combat use owned input snapshots.",
	}
	if DisplayServer.get_name() == "headless" or "--fixed-fps" in OS.get_cmdline_args():
		_failures.append("Rendered performance QA requires a native display and no --fixed-fps acceleration.")
		await _finish(false)
		return
	if Engine.physics_ticks_per_second != 60:
		_failures.append("The campaign route requires the configured 60 Hz physics clock.")
		await _finish(false)
		return
	Engine.max_fps = 144
	_environment["max_fps_cap"] = Engine.max_fps
	root.title = "Gloamthread — native QA with synthetic inputs"
	node_added.connect(_on_node_added)
	var script := load(ROUTE_PATH) as GDScript
	if script == null or not script.can_instantiate():
		_failures.append("The campaign route script could not load.")
		await _finish(false)
		return
	_scenario = script.new() as Scenario
	if _scenario == null:
		_failures.append("The campaign route must extend Scenario.")
		await _finish(false)
		return
	_scenario.name = "RenderedCampaignRoute"
	_scenario.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_scenario)
	print("RENDER_QA_START " + JSON.stringify(_environment))
	await _scenario.run()
	_failures.append_array(_scenario.failures)
	await _finish(true)


func _on_node_added(node: Node) -> void:
	var attached := node.get_script() as Script
	if attached != null and attached.resource_path == "res://scripts/session/game_session.gd":
		_session = node
		_session.room_changed.connect(_on_room_changed)
		_session.mode_changed.connect(_on_mode_changed)


func _on_room_changed(room_id: String) -> void:
	if room_id in CAPTURE_ROOMS:
		_request_capture("room_" + room_id)


func _on_mode_changed(mode: String, _owner: int) -> void:
	if mode == "ending":
		_request_capture("ending")


func _process(delta: float) -> bool:
	if _finishing:
		return false
	if Time.get_ticks_msec() - _started_msec > TIMEOUT_MSEC:
		_failures.append("Campaign observation exceeded its 600-second wall-clock limit; inspect the engine log for a stalled route or script error.")
		_finish(false)
		return false
	if not is_instance_valid(_session) or _session.current_room_id != "r05":
		return false
	var boss: Variant = _session.boss()
	var boss_state: String = boss.animation_state if is_instance_valid(boss) else "defeated"
	_samples.append({
		"elapsed_sec": (Time.get_ticks_msec() - _started_msec) / 1000.0,
		"process_delta_sec": delta,
		"monitor_process_sec": Performance.get_monitor(Performance.TIME_PROCESS),
		"monitor_physics_sec": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
		"monitor_fps": Performance.get_monitor(Performance.TIME_FPS),
		"boss_state": boss_state,
		"paused": paused,
		"capture_pending": _capture_pending > 0,
		"window_size_px": _size(DisplayServer.window_get_size()),
		"capture_previous_frame": Engine.get_process_frames() - _last_capture_frame <= 1,
	})
	if boss_state.ends_with("_active"):
		_request_capture("room_r05_combat")
	return false


func _request_capture(label: String) -> void:
	if _requested.has(label) or _finishing:
		return
	_requested[label] = true
	_capture_pending += 1
	_capture(label)


func _capture(label: String) -> void:
	# Wait for actual rendering; a texture requested during a room transaction
	# could otherwise still contain the previous frame.
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if frame == null or frame.is_empty():
		_failures.append("Rendered viewport was empty for " + label)
		_capture_pending -= 1
		return
	var record := {
		"label": label,
		"file": label + ".png",
		"elapsed_sec": (Time.get_ticks_msec() - _started_msec) / 1000.0,
		"image_size_px": _size(frame.get_size()),
		"window_size_px": _size(DisplayServer.window_get_size()),
		"after_frame_post_draw": true,
		"process_frame": Engine.get_process_frames(),
		"synthetic_input": true,
	}
	if is_instance_valid(_session):
		record["room"] = _session.current_room_id
		record["mode"] = _session.mode
		record["physics_frame"] = Engine.get_physics_frames()
		var players: Array[Dictionary] = []
		for player: Variant in _session.players:
			players.append({"slot": player.slot_index, "feet": [player.position.x, player.position.y], "hearts": player.hearts, "animation": player.animation_state})
		record["players"] = players
	else:
		_failures.append("Session ended before capture: " + label)
	var error := frame.save_png(_output.path_join(label + ".png"))
	_last_capture_frame = Engine.get_process_frames()
	if error != OK:
		_failures.append("PNG write failed for %s: %s" % [label, error_string(error)])
	else:
		_captures.append(record)
		print("RENDER_QA_CAPTURE " + JSON.stringify(record))
	_capture_pending -= 1


func _finish(route_returned: bool) -> void:
	if _finishing:
		return
	_finishing = true
	var deadline := Time.get_ticks_msec() + 2000
	while _capture_pending > 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	if _capture_pending > 0:
		_failures.append("One or more viewport captures did not finish.")
	var labels: Array[String] = []
	for record: Dictionary in _captures:
		labels.append(str(record.label))
	for room_id: String in CAPTURE_ROOMS:
		if "room_" + room_id not in labels:
			_failures.append("Missing rendered room capture: " + room_id)
	if "ending" not in labels:
		_failures.append("Missing rendered ending capture.")
	if _samples.is_empty():
		_failures.append("No real-time r05 performance samples were collected.")
	var report := {
		"schema_version": 1,
		"success": route_returned and _failures.is_empty(),
		"route_returned": route_returned,
		"failures": _failures,
		"environment": _environment,
		"elapsed_wall_sec": (Time.get_ticks_msec() - _started_msec) / 1000.0,
		"captures": _captures,
		"performance_scope": "Every process frame while the active room is r05, including approach/combat/exit. Performance.TIME_PROCESS and TIME_PHYSICS_PROCESS are CPU seconds reported by Godot, not GPU timings; FPS is the engine monitor. PNG capture can affect frame timing and is marked in raw samples. No hardware-controller, human-play, or audio-listening claim.",
		"r05_summary": _summaries(),
		"r05_samples": _samples,
	}
	var report_file := FileAccess.open(_output.path_join("report.json"), FileAccess.WRITE)
	if report_file == null:
		printerr("RENDER_QA_FAIL could not write report.json: " + error_string(FileAccess.get_open_error()))
		quit(1)
		return
	report_file.store_string(JSON.stringify(report, "\t"))
	report_file.close()
	print("RENDER_QA_RESULT " + JSON.stringify({"success": report.success, "captures": _captures.size(), "r05_samples": _samples.size(), "failures": _failures, "report": _output.path_join("report.json")}))
	quit(0 if report.success else 1)


func _summaries() -> Dictionary:
	var result := {"sample_count": _samples.size()}
	for field: String in ["process_delta_sec", "monitor_process_sec", "monitor_physics_sec", "monitor_fps"]:
		var values: Array[float] = []
		var total := 0.0
		for sample: Dictionary in _samples:
			var value: float = float(sample[field])
			values.append(value)
			total += value
		if values.is_empty():
			continue
		values.sort()
		result[field] = {"min": values[0], "mean": total / values.size(), "median": values[values.size() / 2], "p95": values[mini(values.size() - 1, ceili(values.size() * 0.95) - 1)], "max": values[-1]}
	return result


static func _size(value: Vector2i) -> Array[int]:
	return [value.x, value.y]
