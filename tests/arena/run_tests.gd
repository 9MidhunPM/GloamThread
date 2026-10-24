extends SceneTree
## Active wave-game scenario suite; the old campaign runner remains historical.

class Capture extends Logger:
	var errors: PackedStringArray = []
	func _log_error(_fn: String, file: String, line: int, code: String, reason: String, _notify: bool, type: int, _trace: Array[ScriptBacktrace]) -> void:
		if type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s" % [file, line, reason if reason != "" else code])

var capture := Capture.new()
var failed: int = 0
var passed: int = 0


func _initialize() -> void:
	OS.add_logger(capture)
	call_deferred("_run")


func _run() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--filter":
		filter = args[1]
	elif not args.is_empty():
		printerr("Usage: -- --filter substring")
		quit(1)
		return
	var files := DirAccess.get_files_at("res://tests/arena")
	files.sort()
	for filename: String in files:
		if not filename.ends_with(".gd") or filename in ["run_tests.gd", "actor_fixture.gd"] or (not filter.is_empty() and not filename.contains(filter)):
			continue
		var script := load("res://tests/arena/" + filename) as GDScript
		if script == null or not script.can_instantiate():
			printerr("FAIL load " + filename)
			failed += 1
			continue
		var instance: Variant = script.new()
		if not instance is Scenario:
			if instance is Node:
				instance.free()
			continue
		paused = false
		capture.errors.clear()
		root.add_child(instance)
		print("RUN ", filename)
		await instance.run()
		await process_frame
		for error: String in capture.errors:
			instance.failures.append(error)
		if instance.failures.is_empty():
			print("PASS ", filename)
			passed += 1
		else:
			printerr("FAIL ", filename, " ", instance.failures)
			failed += 1
		instance.free()
		var router := root.get_node("InputRouter")
		router.clear_test_input()
		for slot in 2:
			router.clear(slot)
		await process_frame
	await _retire_audio()
	print("Arena scenarios: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 and passed > 0 else 1)


func _retire_audio() -> void:
	var audio := root.get_node("AudioDirector")
	var playing: Array[WeakRef] = []
	for node: Node in audio.get_children():
		if node is AudioStreamPlayer and node.has_stream_playback():
			playing.append(weakref(node.get_stream_playback()))
	audio.stop_music()
	audio.stop_cues()
	var deadline := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline:
		var active := false
		for reference in playing:
			active = active or reference.get_ref() != null
		if not active:
			return
		await process_frame
