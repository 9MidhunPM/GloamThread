extends SceneTree
## Built-in scenario runner: one shared engine process, bounded asynchronous
## scenarios, no external test addon. A synchronous infinite loop still needs
## an external process timeout because it blocks Godot's main thread.

const ScenarioBase = preload("res://tests/scenario.gd")
const SCENARIO_DIRECTORY := "res://tests/scenarios"
const SCENARIO_TIMEOUT_MSEC := 30_000

var _filter: String = ""
var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
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
	print("Scenarios: %d passed, %d failed, %d total" % [_passed, _failed, selected.size()])
	quit(0 if _failed == 0 else 1)


func _parse_arguments() -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		return true
	if args.size() == 2 and args[0] == "--filter" and not args[1].is_empty():
		_filter = args[1]
		return true
	printerr("Usage: godot --headless --path . --script tests/run_tests.gd [-- --filter substring]")
	return false


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
	while not completion["done"] and Time.get_ticks_msec() - started < SCENARIO_TIMEOUT_MSEC:
		await process_frame
	if not completion["done"]:
		scenario.failures.append("timed out after %d seconds" % (SCENARIO_TIMEOUT_MSEC / 1000))
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
