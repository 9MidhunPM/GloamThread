extends Scenario
## Synthetic events exercise device admission/reconnection, not real gamepads.

const Action := CommandSnapshot.Action


func run() -> void:
	var router: Node = load("res://scripts/input/input_router.gd").new()
	add_child(router)
	router.set_physics_process(false)
	assert_eq(router.assign(0, _pad(-1)), ERR_INVALID_PARAMETER, "negative gamepad index is never admitted as an input owner")
	assert_true(not router.is_joined(0), "invalid assignment leaves the slot unjoined")
	assert_eq(router.assign(0, _pad(11)), OK, "first synthetic index joins")
	assert_eq(router.assign(1, _pad(12)), OK, "second synthetic index joins independently")
	_button(11, true)
	router._physics_process(1.0 / 60.0)
	assert_true(router.snapshot(0).just_pressed(Action.ROLL), "first pad Roll belongs to its player")
	assert_true(router.snapshot(1).is_neutral(), "first pad cannot issue partner commands")
	router._on_joy_connection_changed(11, false)
	router._physics_process(1.0 / 60.0)
	assert_true(router.is_waiting_for_device(0) and router.snapshot(0).is_neutral(), "disconnect freezes owned commands")
	assert_eq(router.source_of(0).joy_id, -1, "old OS index is discarded after loss")
	router._reconnect_device(-1, "overhead-owner-fixture", "Synthetic owned pad")
	assert_true(router.is_waiting_for_device(0), "negative reconnect cannot activate an invalid device index")
	_button(13, true)
	router._reconnect_device(13, "overhead-owner-fixture", "Synthetic owned pad")
	router._physics_process(1.0 / 60.0)
	assert_true(not router.is_waiting_for_device(0) and router.source_of(0).joy_id == 13, "identity reconnect claims exactly one live OS index")
	assert_true(router.snapshot(0).is_neutral(), "Roll held during reconnect is suppressed until physical release")
	assert_eq(router.source_of(1).joy_id, 12, "reconnect leaves the partner's live source untouched")
	_button(13, false)
	router._physics_process(1.0 / 60.0)
	_button(13, true)
	router._physics_process(1.0 / 60.0)
	assert_true(router.snapshot(0).just_pressed(Action.ROLL), "fresh release/press restores the returned player's action")
	_button(14, true)
	assert_eq(router.assign(0, _pad(14)), OK, "explicit reassignment accepts another valid source")
	router._physics_process(1.0 / 60.0)
	assert_true(router.snapshot(0).is_neutral(), "held action on a newly assigned source is latched")
	assert_true(router.snapshot(1).is_neutral(), "source changes never inject a partner edge")
	for device: int in [11, 12, 13, 14]:
		_button(device, false)
	router.free()


func _pad(id: int) -> DeviceSource:
	var source := DeviceSource.new()
	source.kind = DeviceSource.Kind.GAMEPAD
	source.joy_id = id
	source.guid = "overhead-owner-fixture"
	source.device_name = "Synthetic owned pad"
	return source


func _button(device: int, held: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = JOY_BUTTON_A
	event.pressed = held
	Input.parse_input_event(event)
	Input.flush_buffered_events()
