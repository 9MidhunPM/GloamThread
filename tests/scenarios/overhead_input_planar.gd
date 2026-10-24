extends Scenario
## Synthetic owned-device events prove planar commands, not physical hardware.

const Action := CommandSnapshot.Action


func run() -> void:
	for axis: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
		var diagonal := CommandSnapshot.from_state(axis.x, axis.y, 0, 0)
		assert_true(Vector2(diagonal.move_x, diagonal.move_y).is_equal_approx(axis.normalized()), "digital diagonals have unit length in every direction")
	var gentle := CommandSnapshot.from_state(0.3, -0.4, 0, 0)
	assert_true(Vector2(gentle.move_x, gentle.move_y).is_equal_approx(Vector2(0.3, -0.4)), "analog magnitude below one remains unchanged")
	var malformed := CommandSnapshot.from_state(NAN, INF, 0, 0)
	assert_true(malformed.is_neutral(), "non-finite motion cannot enter actor physics")
	var oversized := CommandSnapshot.from_state(1e100, -1e100, 0, 0)
	assert_true(Vector2(oversized.move_x, oversized.move_y).is_equal_approx(Vector2(1, -1).normalized()), "out-of-range finite axes cannot overflow the planar vector")
	var router: Node = load("res://scripts/input/input_router.gd").new()
	add_child(router)
	router.set_physics_process(false)
	router.assign(0, DeviceSource.keyboard_left())
	router.assign(1, DeviceSource.keyboard_right())
	router.set_test_input(0, Action.UP | Action.RIGHT | Action.ATTACK)
	router.set_test_input(1, Action.DOWN | Action.LEFT | Action.SPECIAL)
	router._physics_process(1.0 / 60.0)
	assert_true(Vector2(router.snapshot(0).move_x, router.snapshot(0).move_y).is_equal_approx(Vector2(1, -1).normalized()), "keyboard command boundary normalizes its two axes")
	assert_true(Vector2(router.snapshot(1).move_x, router.snapshot(1).move_y).is_equal_approx(Vector2(-1, 1).normalized()), "partner has a separate normalized direction")
	assert_true(router.snapshot(0).just_pressed(Action.ATTACK) and not router.snapshot(1).is_held(Action.ATTACK), "simultaneous movement never leaks an attack to the partner")
	router.clear_test_input()
	router.clear(0)
	router.clear(1)
	router.assign(0, _pad(11))
	router.assign(1, _pad(12))
	_motion(11, JOY_AXIS_LEFT_X, 0.4)
	_motion(11, JOY_AXIS_LEFT_Y, -0.5)
	router._physics_process(1.0 / 60.0)
	assert_true(Vector2(router.snapshot(0).move_x, router.snapshot(0).move_y).is_equal_approx(Vector2(0.4, -0.5)), "owned gamepad preserves two-axis analog magnitude")
	assert_true(router.snapshot(1).is_neutral(), "a gamepad can never steer the other slot")
	router.flush(0)
	router._physics_process(1.0 / 60.0)
	assert_true(router.snapshot(0).is_neutral(), "flush suppresses both held analog axes")
	_motion(11, JOY_AXIS_LEFT_X, 0.0)
	_motion(11, JOY_AXIS_LEFT_Y, 0.0)
	router._physics_process(1.0 / 60.0)
	_motion(11, JOY_AXIS_LEFT_X, 0.8)
	_motion(11, JOY_AXIS_LEFT_Y, 0.8)
	router._physics_process(1.0 / 60.0)
	assert_true(Vector2(router.snapshot(0).move_x, router.snapshot(0).move_y).is_equal_approx(Vector2(1, 1).normalized()), "full diagonal stick input caps speed after a fresh release")
	_motion(12, JOY_AXIS_LEFT_X, -0.4)
	_motion(12, JOY_AXIS_LEFT_Y, 0.5)
	router._physics_process(1.0 / 60.0)
	assert_true(Vector2(router.snapshot(1).move_x, router.snapshot(1).move_y).is_equal_approx(Vector2(-0.4, 0.5)), "second physical index owns its independent analog vector")
	router._on_joy_connection_changed(11, false)
	router._physics_process(1.0 / 60.0)
	assert_true(router.snapshot(0).is_neutral(), "lost pad yields a neutral planar command")
	assert_true(not router.snapshot(1).is_neutral(), "one pad loss leaves its partner's ownership intact")
	for device: int in [11, 12]:
		_motion(device, JOY_AXIS_LEFT_X, 0.0)
		_motion(device, JOY_AXIS_LEFT_Y, 0.0)
	router.free()


func _pad(id: int) -> DeviceSource:
	var source := DeviceSource.new()
	source.kind = DeviceSource.Kind.GAMEPAD
	source.joy_id = id
	source.guid = "overhead-planar-fixture-%d" % id
	source.device_name = "Synthetic planar pad %d" % id
	return source


func _motion(device: int, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()
