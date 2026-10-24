extends Scenario
## Public GameMenus scenarios. Synthetic owned input is not a hardware/UI review.

const MENU_PATH := "res://scripts/ui/game_menus.gd"
const FONT_PATH := "res://assets/generated/font/weft_5x7.fnt"
const Action := CommandSnapshot.Action

var _menu_script: GDScript
var _menu: CanvasLayer
var _events: Array[Dictionary] = []


func run() -> void:
	# Load dynamically so the first RED run gives a useful missing-feature result.
	if not FileAccess.file_exists(MENU_PATH):
		assert_true(false, "GameMenus implementation is missing: %s" % MENU_PATH)
		return
	_menu_script = load(MENU_PATH) as GDScript
	if _menu_script == null or not _menu_script.can_instantiate():
		assert_true(false, "GameMenus must load as an instantiable GDScript")
		return
	await _test_owner_zero()
	await _test_owner_one()
	await _test_disabled_and_empty_rows()
	await _test_malformed_rows_preserve_menu()
	await _test_confirm_deduplication()
	await _test_cancel_priority()
	await _test_adjustments_and_opposite_axes()
	await _test_navigation_repeat_boundaries()
	await _test_adjustment_repeat_boundaries()
	await _test_show_and_hide_flush()
	await _test_owner_change_flush()
	await _test_same_kind_preserves_selected_id()
	await _test_global_pause_processing()
	await _cleanup()


func _setup_menu() -> void:
	await _cleanup()
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.assign(1, DeviceSource.keyboard_right())
	InputRouter.set_test_input(0, 0)
	InputRouter.set_test_input(1, 0)
	_menu = _menu_script.new() as CanvasLayer
	assert_true(_menu != null, "GameMenus extends CanvasLayer")
	if _menu == null:
		return
	add_child(_menu)
	for method: String in ["set_font", "show_menu", "hide_menu"]:
		assert_true(_menu.has_method(method), "GameMenus public method exists: %s" % method)
	assert_true(_menu.has_signal("action_requested"), "GameMenus exposes action_requested")
	_menu.connect("action_requested", _record_action)
	var font := load(FONT_PATH) as Font
	assert_true(font != null, "original bitmap font loads for menu scenarios")
	_menu.call("set_font", font)
	await _step(1)


func _record_action(action: String, payload: Variant) -> void:
	_events.append({"action": action, "payload": payload})


func _show(rows: Array[Dictionary], owner: int = 0, kind: String = "test") -> void:
	_menu.call("show_menu", kind, "Menu scenario", "Choose an action.", rows, owner)
	await _step(1)


func _step(count: int) -> void:
	# physics_frame fires before callbacks; process_frame observes their result.
	for _index in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _pulse(slot: int, mask: int) -> void:
	InputRouter.set_test_input(slot, mask)
	await _step(1)
	InputRouter.set_test_input(slot, 0)
	await _step(1)


func _assert_events(expected: Array[Dictionary], context: String) -> void:
	assert_eq(_events, expected, context)
	_events.clear()


func _test_owner_zero() -> void:
	await _setup_menu()
	await _show([{"id": "first", "label": "First"}, {"id": "second", "label": "Second"}])
	await _pulse(1, Action.DOWN)
	await _pulse(1, Action.JUMP | Action.INTERACT | Action.PAUSE)
	_assert_events([], "partner cannot navigate, confirm or cancel owner-zero menu")
	await _pulse(0, Action.INTERACT)
	_assert_events([{"action": "first", "payload": null}], "partner navigation did not change selection")
	await _pulse(0, Action.DOWN)
	await _pulse(0, Action.JUMP)
	_assert_events([{"action": "second", "payload": null}], "owner navigates and confirms through snapshots")


func _test_owner_one() -> void:
	await _setup_menu()
	await _show([{"id": "first", "label": "First"}, {"id": "second", "label": "Second"}], 1)
	await _pulse(0, Action.DOWN)
	await _pulse(0, Action.INTERACT | Action.PAUSE)
	_assert_events([], "player zero cannot operate player one's menu")
	await _pulse(1, Action.DOWN)
	await _pulse(1, Action.INTERACT)
	_assert_events([{"action": "second", "payload": null}], "player one independently navigates and confirms")


func _test_disabled_and_empty_rows() -> void:
	await _setup_menu()
	await _show([
		{"id": "locked_first", "label": "Unavailable", "enabled": false},
		{"id": "available", "label": "Available"},
		{"id": "locked_middle", "label": "Unavailable too", "enabled": false},
		{"id": "last", "label": "Last available"},
	])
	await _pulse(0, Action.JUMP)
	_assert_events([{"action": "available", "payload": null}], "initial selection skips disabled first row")
	await _pulse(0, Action.DOWN)
	await _pulse(0, Action.INTERACT)
	_assert_events([{"action": "last", "payload": null}], "down navigation skips disabled middle row")
	await _pulse(0, Action.UP)
	await _pulse(0, Action.JUMP)
	_assert_events([{"action": "available", "payload": null}], "up navigation skips disabled middle row")
	await _show([{"id": "locked", "label": "No actions", "enabled": false, "adjustable": true}], 0, "disabled")
	await _pulse(0, Action.DOWN | Action.RIGHT | Action.JUMP | Action.INTERACT)
	await _pulse(0, Action.UP | Action.LEFT)
	_assert_events([], "all-disabled menu has no selection or adjustment")
	await _pulse(0, Action.PAUSE)
	_assert_events([{"action": "cancel", "payload": null}], "all-disabled menu can still be cancelled")
	await _show([], 0, "empty")
	await _pulse(0, Action.DOWN | Action.JUMP | Action.INTERACT)
	_assert_events([], "empty rows are valid and cannot activate an action")
	await _pulse(0, Action.PAUSE)
	_assert_events([{"action": "cancel", "payload": null}], "empty menu can still be cancelled")


func _test_malformed_rows_preserve_menu() -> void:
	await _setup_menu()
	await _show([{"id": "first", "label": "First"}, {"id": "retained", "label": "Retained"}])
	await _pulse(0, Action.DOWN)
	var malformed: Array[Dictionary] = [
		{"label": "Missing id"},
		{"id": "", "label": "Empty id"},
		{"id": "   ", "label": "Whitespace id"},
		{"id": 12, "label": "Numeric id"},
		{"id": true, "label": "Boolean id"},
		{"id": "missing_label"},
		{"id": "wrong_label", "label": 12},
		{"id": "wrong_detail", "label": "Bad detail", "detail": false},
		{"id": "wrong_enabled", "label": "Bad enabled", "enabled": 1},
		{"id": "wrong_adjustable", "label": "Bad adjustment", "adjustable": "yes"},
	]
	for row: Dictionary in malformed:
		# A rejected update must preserve kind, owner, rows and selected action.
		await _show([row], 1, "rejected")
		await _pulse(1, Action.INTERACT)
		_assert_events([], "invalid row cannot steal menu ownership: %s" % JSON.stringify(row))
		await _pulse(0, Action.JUMP)
		_assert_events([{"action": "retained", "payload": null}], "invalid row leaves previous menu intact: %s" % JSON.stringify(row))
	await _show([{"id": "duplicate", "label": "One"}, {"id": "duplicate", "label": "Two"}], 1, "rejected")
	await _pulse(0, Action.INTERACT)
	_assert_events([{"action": "retained", "payload": null}], "duplicate ids reject the complete update")


func _test_confirm_deduplication() -> void:
	await _setup_menu()
	await _show([{"id": "activate", "label": "Activate"}])
	InputRouter.set_test_input(0, Action.JUMP | Action.INTERACT)
	await _step(1)
	_assert_events([{"action": "activate", "payload": null}], "jump plus interact emits exactly one activation")
	await _step(40)
	_assert_events([], "held confirmation never repeats")
	InputRouter.set_test_input(0, 0)
	await _step(1)
	await _pulse(0, Action.INTERACT)
	_assert_events([{"action": "activate", "payload": null}], "a fresh confirmation works after release")
	await _pulse(0, Action.SPECIAL | Action.ATTACK | Action.DASH | Action.MAP)
	_assert_events([], "non-menu gameplay actions do not activate or cancel")


func _test_cancel_priority() -> void:
	await _setup_menu()
	await _show([{"id": "setting", "label": "Setting", "adjustable": true}])
	await _pulse(0, Action.PAUSE | Action.JUMP | Action.INTERACT | Action.RIGHT)
	_assert_events([{"action": "cancel", "payload": null}], "cancel wins over simultaneous confirmation and adjustment")
	InputRouter.set_test_input(0, Action.PAUSE | Action.JUMP | Action.INTERACT)
	await _step(1)
	_assert_events([{"action": "cancel", "payload": null}], "fresh cancel emits once")
	await _step(40)
	_assert_events([], "held cancel and confirm never repeat")
	InputRouter.set_test_input(0, 0)
	await _step(1)


func _test_adjustments_and_opposite_axes() -> void:
	await _setup_menu()
	await _show([{"id": "volume", "label": "Volume", "adjustable": true}, {"id": "back", "label": "Back"}])
	await _pulse(0, Action.LEFT)
	_assert_events([{"action": "volume", "payload": {"direction": -1}}], "left adjustment carries negative direction")
	await _pulse(0, Action.RIGHT)
	_assert_events([{"action": "volume", "payload": {"direction": 1}}], "right adjustment carries positive direction")
	InputRouter.set_test_input(0, Action.RIGHT)
	await _step(1)
	_assert_events([{"action": "volume", "payload": {"direction": 1}}], "fresh horizontal movement adjusts once")
	InputRouter.set_test_input(0, Action.LEFT | Action.RIGHT)
	await _step(30)
	_assert_events([], "opposite held horizontal actions stay neutral even when one is newly pressed")
	InputRouter.set_test_input(0, 0)
	await _step(1)
	await _pulse(0, Action.DOWN)
	await _pulse(0, Action.LEFT | Action.RIGHT)
	await _pulse(0, Action.LEFT)
	await _pulse(0, Action.RIGHT)
	_assert_events([], "horizontal input does not activate nonadjustable rows")
	await _pulse(0, Action.JUMP)
	_assert_events([{"action": "back", "payload": null}], "adjustment does not change selected row")
	await _show([{"id": "first", "label": "First"}, {"id": "second", "label": "Second"}, {"id": "third", "label": "Third"}], 0, "vertical_opposites")
	InputRouter.set_test_input(0, Action.DOWN)
	await _step(1)
	InputRouter.set_test_input(0, Action.DOWN | Action.UP)
	await _step(30)
	InputRouter.set_test_input(0, Action.DOWN | Action.UP | Action.JUMP)
	await _step(1)
	_assert_events([{"action": "second", "payload": null}], "opposite vertical actions preserve selection across repeat delay")
	InputRouter.set_test_input(0, 0)
	await _step(1)


func _test_navigation_repeat_boundaries() -> void:
	for boundary: Dictionary in [
		{"ticks": 1, "id": "row_1"}, {"ticks": 18, "id": "row_1"},
		{"ticks": 19, "id": "row_2"}, {"ticks": 24, "id": "row_2"},
		{"ticks": 25, "id": "row_3"}, {"ticks": 31, "id": "row_4"},
	]:
		await _setup_menu()
		var rows: Array[Dictionary] = []
		for index in 6:
			rows.append({"id": "row_%d" % index, "label": "Row %d" % index})
		await _show(rows)
		InputRouter.set_test_input(0, Action.DOWN)
		await _step(int(boundary["ticks"]))
		InputRouter.set_test_input(0, 0)
		await _step(1)
		await _pulse(0, Action.JUMP)
		_assert_events([{"action": boundary["id"], "payload": null}], "vertical repeat boundary at held tick %d" % boundary["ticks"])


func _test_adjustment_repeat_boundaries() -> void:
	await _setup_menu()
	await _show([{"id": "level", "label": "Level", "adjustable": true}])
	InputRouter.set_test_input(0, Action.RIGHT)
	for tick in range(1, 32):
		await _step(1)
		var expected: Array[Dictionary] = []
		if tick in [1, 19, 25, 31]:
			expected.append({"action": "level", "payload": {"direction": 1}})
		_assert_events(expected, "horizontal repeat boundary at held tick %d" % tick)
	InputRouter.set_test_input(0, 0)
	await _step(1)


func _test_show_and_hide_flush() -> void:
	await _setup_menu()
	InputRouter.set_test_input(0, Action.JUMP | Action.INTERACT | Action.DOWN)
	InputRouter.set_test_input(1, Action.ATTACK | Action.RIGHT)
	await _show([{"id": "first", "label": "First"}, {"id": "second", "label": "Second"}])
	await _step(25)
	_assert_events([], "show suppresses held inputs until released")
	assert_true(InputRouter.snapshot(0).is_neutral() and InputRouter.snapshot(1).is_neutral(), "show flushes both owned input streams")
	InputRouter.set_test_input(0, 0)
	InputRouter.set_test_input(1, 0)
	await _step(1)
	await _pulse(0, Action.INTERACT)
	_assert_events([{"action": "first", "payload": null}], "held navigation on show did not move selection")
	InputRouter.set_test_input(0, Action.JUMP | Action.ATTACK)
	InputRouter.set_test_input(1, Action.INTERACT | Action.RIGHT)
	_menu.call("hide_menu")
	await _step(1)
	assert_true(InputRouter.snapshot(0).is_neutral() and InputRouter.snapshot(1).is_neutral(), "hide flushes both streams before gameplay resumes")
	await _step(25)
	_assert_events([], "hidden menu ignores held input")
	InputRouter.set_test_input(0, 0)
	InputRouter.set_test_input(1, 0)
	await _step(1)
	await _pulse(0, Action.INTERACT | Action.PAUSE)
	_assert_events([], "hidden menu ignores fresh input too")


func _test_owner_change_flush() -> void:
	await _setup_menu()
	var rows: Array[Dictionary] = [{"id": "first", "label": "First"}, {"id": "second", "label": "Second"}, {"id": "third", "label": "Third"}]
	await _show(rows)
	await _pulse(0, Action.DOWN)
	InputRouter.set_test_input(0, Action.JUMP)
	InputRouter.set_test_input(1, Action.INTERACT | Action.DOWN)
	await _show(rows, 1)
	await _step(25)
	_assert_events([], "owner changes suppress held input from both players")
	assert_true(InputRouter.snapshot(0).is_neutral() and InputRouter.snapshot(1).is_neutral(), "owner change flushes both streams")
	InputRouter.set_test_input(0, 0)
	InputRouter.set_test_input(1, 0)
	await _step(1)
	await _pulse(0, Action.DOWN | Action.JUMP)
	_assert_events([], "old owner cannot operate the reassigned menu")
	await _pulse(1, Action.INTERACT)
	_assert_events([{"action": "second", "payload": null}], "new owner activates preserved selection after release")


func _test_same_kind_preserves_selected_id() -> void:
	await _setup_menu()
	await _show([{"id": "alpha", "label": "Alpha"}, {"id": "beta", "label": "Beta"}, {"id": "gamma", "label": "Gamma"}], 0, "settings")
	await _pulse(0, Action.DOWN)
	await _show([{"id": "gamma", "label": "Gamma moved"}, {"id": "alpha", "label": "Alpha moved"}, {"id": "beta", "label": "Beta changed", "detail": "New detail"}], 0, "settings")
	await _pulse(0, Action.JUMP)
	_assert_events([{"action": "beta", "payload": null}], "same-kind update preserves selected id through reorder and label changes")
	await _show([{"id": "locked", "label": "Locked", "enabled": false}, {"id": "delta", "label": "Delta"}], 0, "settings")
	await _pulse(0, Action.INTERACT)
	_assert_events([{"action": "delta", "payload": null}], "removed selected id falls back to first enabled row")
	await _show([{"id": "delta", "label": "Delta", "enabled": false}, {"id": "epsilon", "label": "Epsilon"}], 0, "settings")
	await _pulse(0, Action.JUMP)
	_assert_events([{"action": "epsilon", "payload": null}], "disabled selected id falls back to an enabled row")
	await _show([{"id": "new_first", "label": "New first"}, {"id": "epsilon", "label": "Previous selection"}], 0, "different_kind")
	await _pulse(0, Action.JUMP)
	_assert_events([{"action": "new_first", "payload": null}], "a different menu kind starts at its first enabled row")


func _test_global_pause_processing() -> void:
	await _setup_menu()
	await _show([{"id": "first", "label": "First"}, {"id": "second", "label": "Second"}], 1, "pause")
	get_tree().paused = true
	await _pulse(1, Action.DOWN)
	await _pulse(1, Action.INTERACT)
	_assert_events([{"action": "second", "payload": null}], "menu receives owned input while the shared world is paused")
	assert_true(get_tree().paused, "menu selection does not change session pause ownership")
	await _pulse(1, Action.PAUSE)
	_assert_events([{"action": "cancel", "payload": null}], "cancel remains available during global pause")
	assert_true(get_tree().paused, "cancel requests action without unpausing the session directly")
	_menu.call("hide_menu")
	assert_true(get_tree().paused, "hiding a menu does not mutate the session pause flag")
	get_tree().paused = false


func _cleanup() -> void:
	get_tree().paused = false
	if is_instance_valid(_menu):
		_menu.free()
	_menu = null
	InputRouter.set_test_input(0, 0)
	InputRouter.set_test_input(1, 0)
	await _step(1)
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)
	_events.clear()
