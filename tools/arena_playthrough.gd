extends SceneTree
## Source-only QA harness. Gameplay uses the ordinary-input route driver.
class Capture extends Logger:
	var errors: PackedStringArray = []
	func _log_error(_fn: String, file: String, line: int, code: String, reason: String, _notify: bool, type: int, _trace: Array[ScriptBacktrace]) -> void:
		if type != Logger.ERROR_TYPE_WARNING: errors.append("%s:%d %s" % [file,line,reason if reason != "" else code])
var capture := Capture.new()

func _initialize() -> void:
	OS.add_logger(capture)
	call_deferred("_run")

func _run() -> void:
	var options := {"players":1,"waves":20,"fighter":0,"output":"/tmp/gloamthread-arena-route.json","capture":""}
	var args := OS.get_cmdline_user_args()
	if args.size() % 2 != 0:
		printerr("Usage: -- --players 1|2 --waves 1..25 --fighter 0|1 --output /tmp/report.json --capture /tmp/captures")
		quit(2)
		return
	for index in range(0,args.size(),2):
		var key := args[index].trim_prefix("--")
		if not options.has(key):
			printerr("Unknown route option: " + key)
			quit(2)
			return
		options[key] = int(args[index+1]) if key in ["players","waves","fighter"] else args[index+1]
	if int(options.players) not in [1,2] or int(options.waves) < 1 or int(options.waves) > 25 or int(options.fighter) not in [0,1]:
		printerr("Route argument outside supported bounds.")
		quit(2)
		return
	var script := load("res://tests/arena/route_driver.gd") as GDScript
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var driver: Node = script.new()
	root.add_child(driver)
	var started := Time.get_ticks_msec()
	var report: Dictionary = await driver.run(options.players,options.waves,options.capture,options.fighter)
	report.wall_seconds = (Time.get_ticks_msec()-started)/1000.0
	report.engine = Engine.get_version_info().string
	report.display = DisplayServer.get_name()
	report.physics_hz = Engine.physics_ticks_per_second
	report.fixed_fps = "--fixed-fps" in OS.get_cmdline_args()
	report.engine_errors = Array(capture.errors)
	if not capture.errors.is_empty(): report.success = false
	var file := FileAccess.open(options.output,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	else:
		printerr("Could not write route report.")
		report.success = false
	print("ARENA_ROUTE_RESULT ", JSON.stringify({"success":report.success,"wave":report.get("final_summary",{}).get("wave",0),"ticks":report.get("ticks",0),"errors":report.errors,"engine_errors":report.engine_errors,"report":options.output}))
	paused = false
	driver.free()
	var router := root.get_node("InputRouter")
	router.clear_test_input()
	for slot in 2: router.clear(slot)
	await _retire_audio()
	quit(0 if bool(report.success) else 1)

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
