extends Scenario
## Synthetic engine input events test routing; physical gamepads remain unverified.

const Action := CommandSnapshot.Action

func pad(device: int) -> DeviceSource:
	var source := DeviceSource.new()
	source.kind = DeviceSource.Kind.GAMEPAD
	source.joy_id = device
	source.guid = "same-fixture-guid"
	source.device_name = "Identical fixture pad"
	return source

func motion(device: int, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func button(device: int, which: JoyButton, held: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = which
	event.pressed = held
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	for kind: DeviceSource.Kind in [DeviceSource.Kind.KEYBOARD_LEFT, DeviceSource.Kind.KEYBOARD_RIGHT, DeviceSource.Kind.GAMEPAD]:
		var original := Bindings.defaults_for(kind)
		var roundtrip := Bindings.from_dict(JSON.parse_string(JSON.stringify(original.to_dict())))
		assert_true(roundtrip.controls == original.controls, "JSON binding round trip")
		for action: Action in CommandSnapshot.ALL_ACTIONS:
			assert_true(roundtrip.prompt_label(action) == original.prompt_label(action), "JSON prompt round trip")
	for bad: Variant in [null, true, "0.2", NAN, INF, {}, []]:
		var invalid_deadzone := Bindings.from_dict({"kind": "GAMEPAD", "deadzone": bad})
		assert_true(invalid_deadzone.deadzone == 0.3, "invalid deadzone retains default")
	for invalid: Variant in [[-1], [true], [65.5], [{}], [KEY_A, "bad"], [999999], "bad"]:
		var invalid_keys := Bindings.from_dict({"kind": "KEYBOARD_LEFT", "controls": {"jump": invalid}})
		assert_true(invalid_keys.keys_for(Action.JUMP) == [KEY_SPACE], "invalid keyboard mapping retains complete default")
	for invalid: Variant in [[{"button": -1}], [{"button": JOY_BUTTON_MAX}], [{"button": 1.2}], [{"button": true}], [{"axis": JOY_AXIS_MAX, "sign": 1}], [{"axis": 0, "sign": 0}], [{"axis": 0}], [{"button": 0, "axis": 0}], [{"axis": 0, "sign": 1, "extra": 3}], [1]]:
		var invalid_pad := Bindings.from_dict({"kind": "GAMEPAD", "controls": {"jump": invalid}})
		assert_true(invalid_pad.pad_controls_for(Action.JUMP) == [{"button": JOY_BUTTON_A}], "invalid gamepad mapping retains default")
	var unbound := Bindings.from_dict({"kind": "KEYBOARD_LEFT", "controls": {"jump": []}})
	assert_true(unbound.keys_for(Action.JUMP).is_empty(), "explicit unbind remains valid")
	var malformed_keys := Bindings.from_dict({"kind": "KEYBOARD_LEFT", "controls": {17: [KEY_A]}})
	assert_true(malformed_keys.keys_for(Action.JUMP) == [KEY_SPACE], "non-string action ignored safely")
	var router: Node = load("res://scripts/input/input_router.gd").new()
	add_child(router)
	router.set_physics_process(false)
	assert_true(router.assign(0, pad(11)) == OK, "assign first pad")
	assert_true(router.assign(1, pad(12)) == OK, "assign distinct pad")
	assert_true(router.assign(1, pad(11)) == ERR_ALREADY_IN_USE, "reject duplicate source")
	assert_true(router.assign(1, pad(12), Bindings.defaults_for(DeviceSource.Kind.KEYBOARD_LEFT)) == ERR_INVALID_PARAMETER, "reject mismatched binding kind")
	var remapped := Bindings.defaults_for(DeviceSource.Kind.GAMEPAD)
	remapped.controls[Action.LEFT] = [{"axis": JOY_AXIS_RIGHT_X, "sign": -1}]
	remapped.controls[Action.RIGHT] = [{"axis": JOY_AXIS_RIGHT_X, "sign": 1}]
	router.set_bindings(0, remapped)
	motion(11, JOY_AXIS_LEFT_X, 0.8)
	router._physics_process(1.0 / 60.0)
	assert_true(is_zero_approx(router.snapshot(0).move_x), "unbound original stick cannot move player")
	motion(11, JOY_AXIS_RIGHT_X, 0.7)
	router._physics_process(1.0 / 60.0)
	assert_true(is_equal_approx(router.snapshot(0).move_x, 0.7), "bound right stick preserves analog strength")
	assert_true(router.snapshot(0).is_held(Action.RIGHT), "remapped held direction agrees with analog axis")
	assert_true(router.snapshot(1).is_neutral(), "first pad does not control other player")
	router.flush(0)
	router._physics_process(1.0 / 60.0)
	assert_true(is_zero_approx(router.snapshot(0).move_x), "held analog movement is suppressed after flush")
	motion(11, JOY_AXIS_RIGHT_X, 0.0)
	router._physics_process(1.0 / 60.0)
	motion(11, JOY_AXIS_RIGHT_X, 0.7)
	router._physics_process(1.0 / 60.0)
	assert_true(is_equal_approx(router.snapshot(0).move_x, 0.7), "analog movement resumes only after returning to neutral")
	motion(11, JOY_AXIS_RIGHT_X, 0.1)
	router._physics_process(1.0 / 60.0)
	assert_true(is_zero_approx(router.snapshot(0).move_x), "remapped stick respects deadzone")
	button(11, JOY_BUTTON_A, true)
	router.flush(0)
	router._physics_process(1.0 / 60.0)
	assert_true(not router.snapshot(0).is_held(Action.JUMP), "held jump suppressed after flush")
	button(11, JOY_BUTTON_A, false)
	router._physics_process(1.0 / 60.0)
	button(11, JOY_BUTTON_A, true)
	router._physics_process(1.0 / 60.0)
	assert_true(router.snapshot(0).just_pressed(Action.JUMP), "fresh press restored after release")
	router._on_joy_connection_changed(11, false)
	router.set_test_input(0, Action.ATTACK)
	router._physics_process(1.0 / 60.0)
	assert_true(router.snapshot(0).is_neutral(), "disconnected input remains neutral")
	assert_true(router.source_of(0).joy_id == -1, "lost OS index invalidated")
	assert_true(router.source_of(1).joy_id == 12 and not router.is_waiting_for_device(1), "other slot stays assigned after loss")
	router.clear_test_input(0)
	router._on_joy_connection_changed(12, false)
	router._reconnect_device(13, "same-fixture-guid", "Identical fixture pad")
	assert_true(router.source_of(0).joy_id == 13 and not router.is_waiting_for_device(0), "first identical waiting pad reconnects once")
	assert_true(router.is_waiting_for_device(1) and router.source_of(1).joy_id == -1, "same reconnect does not claim second slot")
	router._reconnect_device(13, "same-fixture-guid", "Identical fixture pad")
	assert_true(router.is_waiting_for_device(1), "duplicate notification cannot duplicate ownership")
	router._reconnect_device(14, "same-fixture-guid", "Identical fixture pad")
	assert_true(router.source_of(0).joy_id == 13 and router.source_of(1).joy_id == 14, "second identical pad preserves first assignment")
	motion(11, JOY_AXIS_LEFT_X, 0.0)
	motion(11, JOY_AXIS_RIGHT_X, 0.0)
	button(11, JOY_BUTTON_A, false)
	router.free()
