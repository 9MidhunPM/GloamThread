extends SceneTree
## Built-in scenario runner: one shared engine process, bounded asynchronous
## scenarios, no external test addon. A synchronous infinite loop still needs
## an external process timeout because it blocks Godot's main thread.

const ScenarioBase = preload("res://tests/scenario.gd")
const SCENARIO_DIRECTORY := "res://tests/scenarios"
class ErrorCapture extends Logger:
	var messages: PackedStringArray = PackedStringArray()
	var lock := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		lock.lock()
		messages.append("%s:%d: %s" % [file, line, rationale if not rationale.is_empty() else code])
		lock.unlock()

	func drain() -> PackedStringArray:
		lock.lock()
		var result := messages.duplicate()
		messages.clear()
		lock.unlock()
		return result

var _errors := ErrorCapture.new()
var _timeout_msec: int = 30_000

var _filter: String = ""
var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	# Godot runtime errors do not throw through an awaited GDScript method.
	# Capture the engine stream so a crashed scenario can never print PASS.
	# https://docs.godotengine.org/en/4.7/classes/class_logger.html
	OS.add_logger(_errors)
	call_deferred("_run_all")


func _run_all() -> void:
	if not _parse_arguments():
		quit(1)
		return
	if not DirAccess.dir_exists_absolute(SCENARIO_DIRECTORY):
		printerr("FAIL: scenario directory is missing: %s" % SCENARIO_DIRECTORY)
		quit(1)
		return
	var files: PackedStringArray = DirAccess.get_files_at(SCENARIO_DIRECTORY)
	files.sort()
	var selected: PackedStringArray = PackedStringArray()
	for filename: String in files:
		if filename.ends_with(".gd") and (_filter.is_empty() or filename.contains(_filter)):
			selected.append(filename)
	if selected.is_empty():
		printerr("FAIL: no scenarios matched filter '%s'" % _filter)
		quit(1)
		return
	for filename: String in selected:
		await _run_one(filename)
	await _retire_audio()
	print("Scenarios: %d passed, %d failed, %d total" % [_passed, _failed, selected.size()])
	quit(0 if _failed == 0 else 1)


func _parse_arguments() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.size() % 2 != 0:
		printerr("Usage: [--filter substring] [--timeout-seconds 1..600]")
		return false
	for index in range(0, args.size(), 2):
		if args[index] == "--filter" and not args[index + 1].is_empty():
			_filter = args[index + 1]
		elif args[index] == "--timeout-seconds" and args[index + 1].is_valid_int() and int(args[index + 1]) in range(1, 601):
			_timeout_msec = int(args[index + 1]) * 1000
		else:
			printerr("Unknown or invalid scenario option: %s" % args[index])
			return false
	return true


func _run_one(filename: String) -> void:
	var path: String = SCENARIO_DIRECTORY.path_join(filename)
	var script: GDScript = load(path) as GDScript
	if script == null or not script.can_instantiate():
		_record_load_failure(filename, "could not load/instantiate scenario script")
		return
	var instance: Variant = script.new()
	if not (instance is ScenarioBase):
		if instance is Object and not (instance is RefCounted):
			instance.free()
		_record_load_failure(filename, "script must extend Scenario")
		return
	var scenario: ScenarioBase = instance as ScenarioBase
	scenario.name = filename.get_basename()
	scenario.process_mode = Node.PROCESS_MODE_ALWAYS
	paused = false
	root.add_child(scenario)
	print("RUN  %s" % filename)
	var completion: Dictionary = {"done": false}
	var started: int = Time.get_ticks_msec()
	_invoke_scenario(scenario, completion)
	while not completion["done"] and Time.get_ticks_msec() - started < _timeout_msec:
		await process_frame
	if not completion["done"]:
		scenario.failures.append("timed out after %d seconds" % (_timeout_msec / 1000))
	scenario.failures.append_array(_errors.drain())
	if scenario.failures.is_empty():
		_passed += 1
		print("PASS %s" % filename)
	else:
		_failed += 1
		printerr("FAIL %s" % filename)
		for failure: String in scenario.failures:
			printerr("  - %s" % failure)
	paused = false
	scenario.free()
	await process_frame


func _invoke_scenario(scenario: ScenarioBase, completion: Dictionary) -> void:
	await scenario.run()
	completion["done"] = true


func _record_load_failure(filename: String, message: String) -> void:
	_failed += 1
	printerr("FAIL %s: %s" % [filename, message])


func _retire_audio() -> void:
	# Mixing is asynchronous even when scenario physics runs with --fixed-fps.
	var pending: Array[WeakRef] = []
	var director := root.get_node_or_null("AudioDirector")
	if director == null:
		return
	for node: Node in director.get_children():
		if node is AudioStreamPlayer and node.has_stream_playback():
			pending.append(weakref(node.get_stream_playback()))
	director.stop_music()
	director.stop_cues()
	var deadline := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline:
		var alive := false
		for playback in pending:
			alive = alive or playback.get_ref() != null
		if not alive:
			return
		await process_frame
	_failed += 1
	printerr("FAIL: stopped scenario audio did not retire within one second")
