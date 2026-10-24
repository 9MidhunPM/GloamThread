extends Scenario
## Settings migration and owned snapshots only; this does not test roll motion.

const Action := CommandSnapshot.Action


func run() -> void:
	assert_eq(Action.ROLL, 16, "Roll preserves the established action bit")
	assert_eq(Action.JUMP, Action.ROLL, "transitional Jump alias retains source compatibility")
	assert_eq(CommandSnapshot.action_name(Action.ROLL), "roll", "saved action name is canonical Roll")
	assert_eq(CommandSnapshot.action_from_name("jump"), Action.ROLL, "legacy Jump names migrate to Roll")
	assert_eq(CommandSnapshot.action_from_name("roll"), Action.ROLL, "overhead names resolve to Roll")
	assert_eq(CommandSnapshot.ALL_ACTIONS.count(Action.ROLL), 1, "alias cannot poll twice or duplicate settings rows")
	for kind: DeviceSource.Kind in [DeviceSource.Kind.KEYBOARD_LEFT, DeviceSource.Kind.KEYBOARD_RIGHT, DeviceSource.Kind.GAMEPAD]:
		var defaults := Bindings.defaults_for(kind)
		var data := defaults.to_dict()
		assert_true(data.controls.has("roll") and not data.controls.has("jump"), "defaults serialize only Roll")
		var legacy: Dictionary = JSON.parse_string(JSON.stringify(data))
		legacy.controls.jump = legacy.controls.roll
		legacy.controls.erase("roll")
		var migrated := Bindings.from_dict(legacy)
		assert_eq(migrated.controls, defaults.controls, "legacy binding retains its original physical control")
		assert_eq(migrated.prompt_label(Action.ROLL), defaults.prompt_label(Action.ROLL), "migrated action displays the current control")
		assert_true(migrated.to_dict().controls.has("roll") and not migrated.to_dict().controls.has("jump"), "round trip removes old action names")
	for controls: Dictionary in [{"roll": [KEY_Q], "jump": [KEY_R]}, {"jump": [KEY_R], "roll": [KEY_Q]}]:
		var mixed := Bindings.from_dict({"kind": "KEYBOARD_LEFT", "controls": controls})
		assert_eq(mixed.keys_for(Action.ROLL), [KEY_Q], "canonical binding wins independent of JSON ordering")
	var settings := SettingsRepository.new()
	settings.path = "user://overhead-roll-%d.json" % Time.get_ticks_usec()
	var old_settings := settings.defaults()
	old_settings.player_bindings[0].controls = {"jump": [KEY_Q]}
	var file := FileAccess.open(settings.path, FileAccess.WRITE)
	assert_true(file != null, "create actual legacy settings fixture")
	if file == null:
		return
	file.store_string(JSON.stringify(old_settings))
	file.close()
	var loaded: Dictionary = settings.load_settings().settings
	assert_eq(Bindings.from_dict(loaded.player_bindings[0]).keys_for(Action.ROLL), [KEY_Q], "legacy settings load the remapped Roll key")
	assert_true(settings.save_settings(loaded).ok, "migrated settings save through actual serialization")
	var serialized: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(settings.path))
	assert_true(serialized.player_bindings[0].controls.has("roll") and not serialized.player_bindings[0].controls.has("jump"), "disk settings become canonical after save")
	DirAccess.remove_absolute(settings.path)
	var router: Node = load("res://scripts/input/input_router.gd").new()
	add_child(router)
	router.set_physics_process(false)
	router.assign(0, DeviceSource.keyboard_left())
	router.assign(1, DeviceSource.keyboard_right())
	router.set_test_input(0, Action.ROLL)
	router._physics_process(1.0 / 60.0)
	assert_true(router.snapshot(0).just_pressed(Action.ROLL), "owned Roll produces one fresh edge")
	assert_true(router.snapshot(1).is_neutral(), "Roll never enters the other player's snapshot")
	router.flush(0)
	router._physics_process(1.0 / 60.0)
	assert_true(not router.snapshot(0).is_held(Action.ROLL), "menu flush latches held Roll")
	router.set_test_input(0, 0)
	router._physics_process(1.0 / 60.0)
	router.set_test_input(0, Action.ROLL)
	router._physics_process(1.0 / 60.0)
	assert_true(router.snapshot(0).just_pressed(Action.ROLL), "Roll requires a fresh press after release")
	router.free()
