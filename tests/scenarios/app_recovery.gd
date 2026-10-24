extends Scenario
## File-backed application recovery and synthetic Router hotplug notifications.
## Fake gamepad identities/waiting flags do not establish physical hardware QA.

const App := preload("res://scripts/app/app_controller.gd")
const Action := CommandSnapshot.Action
var _app: Control
var _folder: String


func run() -> void:
	_folder = "user://app-recovery-%d" % Time.get_ticks_usec()
	var preferences := SettingsRepository.new()
	preferences.path = _folder.path_join("settings.json")
	var settings := preferences.defaults()
	settings.sources[0] = DeviceSource.keyboard_right().identity()
	settings.sources[1] = {"kind": "GAMEPAD", "guid": "missing-recovery-fixture", "name": "Missing fixture pad"}
	settings.player_bindings[0] = Bindings.defaults_for(DeviceSource.Kind.KEYBOARD_RIGHT).to_dict()
	settings.player_bindings[1] = Bindings.defaults_for(DeviceSource.Kind.GAMEPAD).to_dict()
	assert_true(preferences.save_settings(settings).ok, "create actual saved device preferences")
	_app = App.new()
	_app.saves.path = _folder.path_join("save.json")
	_app.settings_store.path = preferences.path
	add_child(_app)
	InputRouter.set_test_input(0, 0)
	InputRouter.set_test_input(1, 0)
	await _steps(2)
	assert_eq(_app.screen, "title", "recovery fixture boots real application menus")
	assert_true(InputRouter.source_of(0) != null and InputRouter.source_of(1) != null, "missing saved pad never leaves a null source")
	assert_eq(InputRouter.source_of(0).kind, DeviceSource.Kind.KEYBOARD_RIGHT, "P1 keeps its saved keyboard-right preference")
	assert_eq(InputRouter.source_of(1).kind, DeviceSource.Kind.KEYBOARD_LEFT, "missing P2 pad falls back to the distinct available keyboard zone")
	assert_true(_app._devices_ready() and not InputRouter.source_of(0).conflicts_with(InputRouter.source_of(1)), "fallback produces two usable distinct assignments")
	_test_capture_interruption()
	_test_menu_owner_loss()
	_test_owner_return()
	await _test_unsaved_title()
	await _cleanup()


func _test_capture_interruption() -> void:
	var pad := _pad(2101, "capture")
	assert_eq(InputRouter.assign(0, pad), OK, "assign synthetic capture pad")
	_app.menu_owner = 0
	_app._on_action("settings")
	_app._on_action("controls_0")
	_app._on_action("bind_0_%d" % Action.ATTACK)
	assert_eq(_app._remap_slot, 0, "binding capture owns selected slot")
	var before := InputRouter.bindings_of(0).to_dict()
	InputRouter._on_joy_connection_changed(2101, false)
	assert_true(InputRouter.is_waiting_for_device(0), "synthetic disconnect marks Router waiting state")
	assert_eq(_app._remap_slot, -1, "device loss cancels an in-progress remap capture")
	assert_eq(_app.screen, "reconnect", "interrupted capture shows recovery menu")
	assert_eq(_app.menu_owner, 1, "connected partner takes the menu after owner loss")
	var unrelated := InputEventKey.new()
	unrelated.physical_keycode = KEY_Z
	unrelated.pressed = true
	_app._input(unrelated)
	assert_eq(InputRouter.bindings_of(0).to_dict(), before, "later unrelated input cannot finish the cancelled capture")
	InputRouter._reconnect_device(2102, pad.guid, pad.device_name)
	assert_true(not InputRouter.is_waiting_for_device(0), "synthetic identity reconnect restores the waiting assignment")
	_app._on_action("finish_reconnect")
	assert_eq(_app.screen, "settings", "interrupted controls return deliberately to settings")


func _test_menu_owner_loss() -> void:
	for previous: String in ["title", "settings", "join"]:
		_assign_keyboards()
		if previous == "title":
			_app._show_title()
		elif previous == "settings":
			_app._show_settings()
		else:
			_app._join_continue = false
			_app._show_join()
		var pad := _pad(2201, previous)
		InputRouter.assign(0, pad)
		_app.menu_owner = 0
		InputRouter._on_joy_connection_changed(2201, false)
		assert_eq(_app.screen, "reconnect", "%s owner loss shows reconnect instead of stranding the menu" % previous)
		assert_eq(_app.menu_owner, 1, "%s menu transfers to its connected player" % previous)
		assert_true(not InputRouter.is_waiting_for_device(_app.menu_owner), "reconnect owner is an available input")
		InputRouter._reconnect_device(2202, pad.guid, pad.device_name)
		assert_eq(_app.screen, "reconnect", "device return does not automatically dismiss recovery")
		_app._on_action("finish_reconnect")
		assert_eq(_app.screen, previous, "deliberate recovery returns to %s" % previous)
	# The menu's owned Pause/cancel edge must be safe without a campaign session.
	_assign_keyboards()
	_app._show_title()
	var pad := _pad(2251, "cancel")
	InputRouter.assign(0, pad)
	InputRouter._on_joy_connection_changed(2251, false)
	InputRouter._reconnect_device(2252, pad.guid, pad.device_name)
	_app._on_action("cancel")
	assert_true(_app.screen in ["title", "reconnect"], "cancel after title reconnect has a safe no-session destination")
	assert_true(not is_instance_valid(_app.session), "menu recovery cannot invent a gameplay session")


func _test_owner_return() -> void:
	_assign_keyboards()
	_app._show_title()
	var first := _pad(2301, "first")
	var second := _pad(2302, "second")
	InputRouter.assign(0, first)
	InputRouter.assign(1, second)
	_app.menu_owner = 0
	InputRouter._on_joy_connection_changed(2301, false)
	InputRouter._on_joy_connection_changed(2302, false)
	assert_true(InputRouter.is_waiting_for_device(0) and InputRouter.is_waiting_for_device(1), "both synthetic pads can enter waiting state")
	InputRouter._reconnect_device(2303, first.guid, first.device_name)
	assert_eq(_app.menu_owner, 0, "a returned player takes ownership when the previous owner is still missing")
	assert_eq(_app.screen, "reconnect", "one returned pad keeps recovery visible")
	assert_true(not _app._devices_ready(), "one returned pad cannot resume for two players")
	_assign_keyboards()
	_app._on_action("finish_reconnect")
	assert_eq(_app.screen, "title", "explicit keyboard reassignment can recover to title")


func _test_unsaved_title() -> void:
	_assign_keyboards()
	_app.menu_owner = 0
	_app._show_title()
	_app._on_action("new")
	_app._on_action("start")
	assert_true(is_instance_valid(_app.session) and _app.session.session_ready, "actual writable campaign starts before fault injection")
	if not is_instance_valid(_app.session):
		return
	_app.session._focus_pause_enabled = false
	var campaign_id: int = _app.session.get_instance_id()
	var saved_before := FileAccess.get_file_as_string(_app.saves.path)
	var secret_flag: Array[String] = ["lantern_charm"]
	_app.session.progress.commit_flags(secret_flag)
	_app.saves.failure_stage = "write"
	_app._on_action("title")
	assert_eq(_app.screen, "unsaved_title", "failed return-to-title save exposes retry/discard decision")
	assert_true(is_instance_valid(_app.session) and _app.session.get_instance_id() == campaign_id, "failed save retains the current session")
	assert_true(get_tree().paused and not _app.session.last_save_error.is_empty(), "unsaved title decision freezes gameplay with a durability error")
	assert_eq(FileAccess.get_file_as_string(_app.saves.path), saved_before, "failed return preserves the previous actual save")
	_app._on_action("cancel")
	assert_eq(_app.screen, "pause", "cancel keeps the journey available through pause")
	assert_true(is_instance_valid(_app.session) and _app.session.get_instance_id() == campaign_id and _app.session.progress.has_flag("lantern_charm"), "cancel preserves the exact unsaved campaign")
	_app._on_action("resume")
	assert_eq(_app.screen, "playing", "cancelled exit can resume ordinary play")
	_app._on_action("title")
	assert_eq(_app.screen, "unsaved_title", "a second failed save remains recoverable")
	_app.saves.failure_stage = ""
	_app._on_action("retry_title")
	assert_eq(_app.screen, "title", "retry returns to title after storage becomes writable")
	assert_true(not is_instance_valid(_app.session), "successful retry disposes the old session")
	assert_true("lantern_charm" in _app.saves.load_campaign().data.secret_flags, "successful retry makes previously unsaved progress durable")
	_app._on_action("continue")
	_app._on_action("start")
	assert_true(is_instance_valid(_app.session) and _app.session.progress.has_flag("lantern_charm"), "Continue sees the saved retry result")
	_app.session._focus_pause_enabled = false
	var bridge_flag: Array[String] = ["bridge_spindle"]
	_app.session.progress.commit_flags(bridge_flag)
	var discard_bytes := FileAccess.get_file_as_string(_app.saves.path)
	_app.saves.failure_stage = "write"
	_app._on_action("title")
	assert_eq(_app.screen, "unsaved_title", "discard is offered only after a visible save failure")
	_app._on_action("discard_title")
	assert_eq(_app.screen, "title", "explicit discard returns to title")
	assert_true(not is_instance_valid(_app.session), "explicit discard releases the unsaved session")
	assert_eq(FileAccess.get_file_as_string(_app.saves.path), discard_bytes, "explicit discard does not alter the last successful save")
	assert_true("bridge_spindle" not in _app.saves.load_campaign().data.restored_pairs, "discarded progress is absent from durable campaign")
	_app.saves.failure_stage = ""
	await _steps(1)


func _assign_keyboards() -> void:
	InputRouter.clear(0)
	InputRouter.clear(1)
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.assign(1, DeviceSource.keyboard_right())
	InputRouter.set_test_input(0, 0)
	InputRouter.set_test_input(1, 0)
	InputRouter.flush()


func _pad(id: int, suffix: String) -> DeviceSource:
	var source := DeviceSource.new()
	source.kind = DeviceSource.Kind.GAMEPAD
	source.joy_id = id
	source.guid = "app-recovery-fixture-" + suffix
	source.device_name = "Synthetic recovery pad " + suffix
	return source


func _steps(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _cleanup() -> void:
	_app.free()
	get_tree().paused = false
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)
	for filename: String in DirAccess.get_files_at(_folder):
		DirAccess.remove_absolute(_folder.path_join(filename))
	DirAccess.remove_absolute(_folder)
	var pending: Array[WeakRef] = []
	for node: Node in AudioDirector.get_children():
		if node is AudioStreamPlayer and node.has_stream_playback():
			pending.append(weakref(node.get_stream_playback()))
	AudioDirector.stop_music()
	AudioDirector.stop_cues()
	var deadline := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline:
		var active := false
		for playback: WeakRef in pending:
			active = active or playback.get_ref() != null
		if not active:
			return
		await get_tree().process_frame
	assert_true(false, "app recovery fixture retires stopped audio playback")
