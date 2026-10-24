extends Scenario
## Engine layout and public GUI-event checks, not a hardware/visual acceptance claim.

const MENU_PATH := "res://scripts/ui/game_menus.gd"
const FONT_PATH := "res://assets/generated/font/weft_5x7.fnt"
const Action := CommandSnapshot.Action

var _script: GDScript
var _menu: CanvasLayer
var _font: Font
var _events: Array[Dictionary] = []


func run() -> void:
	if not FileAccess.file_exists(MENU_PATH):
		assert_true(false, "GameMenus implementation is missing: %s" % MENU_PATH)
		return
	_script = load(MENU_PATH) as GDScript
	_font = load(FONT_PATH) as Font
	if _script == null or not _script.can_instantiate() or _font == null:
		assert_true(false, "menu script and original bitmap font must load")
		return
	await _test_kinds_font_and_focus()
	await _test_long_body_scroll()
	await _test_long_rows_and_selection_scroll()
	await _test_glyph_replacement()
	await _test_missing_font_and_invalid_owner()
	await _test_callback_screen_change()
	await _test_adjustment_callback_updates()
	await _test_same_snapshot_deduplication()
	await _test_stale_generation_and_scroll()
	await _test_mouse_rows_and_arrows()
	await _test_stationary_hover()
	await _cleanup()


func _setup(with_font: bool = true) -> void:
	await _cleanup()
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.assign(1, DeviceSource.keyboard_right())
	InputRouter.set_test_input(0, 0)
	InputRouter.set_test_input(1, 0)
	_menu = _script.new() as CanvasLayer
	# Supplying the original font before ready must also be supported.
	if with_font:
		_menu.call("set_font", _font)
	add_child(_menu)
	_menu.connect("action_requested", _record_action)
	await _step(2)


func _record_action(action: String, payload: Variant) -> void:
	_events.append({"action": action, "payload": payload})


func _show(kind: String, body: String, rows: Array[Dictionary], owner: int = 0, title: String = "Menu layout") -> void:
	_menu.call("show_menu", kind, title, body, rows, owner)
	await _step(3)


func _node(node_name: String) -> Node:
	var found := _menu.find_child(node_name, true, false)
	assert_true(found != null, "named public menu node exists: %s" % node_name)
	return found


func _rows() -> VBoxContainer:
	return _node("Rows") as VBoxContainer


func _scroll() -> ScrollContainer:
	return _node("Scroll") as ScrollContainer


func _step(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _pulse(mask: int, slot: int = 0) -> void:
	InputRouter.set_test_input(slot, mask)
	await _step(1)
	InputRouter.set_test_input(slot, 0)
	await _step(1)


func _expect(expected: Array[Dictionary], context: String) -> void:
	assert_eq(_events, expected, context)
	_events.clear()


func _test_kinds_font_and_focus() -> void:
	await _setup()
	for kind: String in ["title", "join", "pause", "map", "dialogue", "settings", "reconnect", "ending", "controls"]:
		await _show(kind, "A readable shared screen.", [
			{"id": "next", "label": "Continue", "detail": "Both couriers share this choice."},
			{"id": "volume", "label": "Volume", "adjustable": true},
			{"id": "locked", "label": "Unavailable", "enabled": false},
		])
		assert_true(_menu.visible, "%s kind opens" % kind)
		assert_eq(_menu.get("last_error"), "", "%s kind has no validation error" % kind)
		var screen := _node("MenuRoot") as Control
		var panel := _node("Panel") as Control
		var scroll := _scroll()
		assert_eq(screen.size, Vector2(960, 360), "logical overlay is the composite viewport")
		assert_true(screen.get_global_rect().encloses(panel.get_global_rect()), "panel fits inside composite")
		assert_true(panel.get_global_rect().encloses(scroll.get_global_rect()), "scroll area fits inside panel")
		assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "menu does not require horizontal scrolling")
		assert_eq(screen.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "original bitmap font uses nearest sampling")
		_assert_font_and_focus(screen, kind)
		await _pulse(Action.JUMP)
		_expect([{"action": "next", "payload": null}], "%s kind emits the caller's action ID" % kind)


func _assert_font_and_focus(node: Node, context: String) -> void:
	if node is Control:
		assert_eq(node.focus_mode, Control.FOCUS_NONE, "%s has no native focus on %s" % [context, node.get_path()])
	if node is Label:
		assert_eq(node.get_theme_font("font"), _font, "%s label uses the supplied original font: %s" % [context, node.get_path()])
	for child: Node in node.get_children():
		_assert_font_and_focus(child, context)


func _test_long_body_scroll() -> void:
	await _setup()
	var body := ""
	for index in 18:
		body += "Paragraph %02d: Tavi and Neri follow the lantern thread. Every line must remain reachable by scrolling.\n\n" % index
	await _show("dialogue", body, [{"id": "continue", "label": "Continue together"}])
	var scroll := _scroll()
	var body_label := _node("Body") as Label
	assert_eq(body_label.text, body, "long body text is retained")
	assert_true(body_label.size.y > scroll.size.y, "long body exceeds the scroll viewport")
	assert_true(body_label.autowrap_mode != TextServer.AUTOWRAP_OFF, "body wraps")
	assert_eq(scroll.scroll_vertical, 0, "new screen starts at the first paragraph")
	await _pulse(Action.DOWN)
	assert_true(scroll.scroll_vertical > 0, "owned down input scrolls long body before action rows")
	await _pulse(Action.UP)
	assert_eq(scroll.scroll_vertical, 0, "owned up input returns to first paragraph")
	# The selected action remains operable while the user reads the body.
	await _pulse(Action.INTERACT)
	_expect([{"action": "continue", "payload": null}], "long body keeps its action available")
	await _show("credits", body, [])
	await _pulse(Action.DOWN)
	assert_true(scroll.scroll_vertical > 0, "an informational screen without rows still scrolls")
	await _pulse(Action.UP)
	assert_eq(scroll.scroll_vertical, 0, "rowless informational screen scrolls back")
	await _pulse(Action.PAUSE)
	_expect([{"action": "cancel", "payload": null}], "long rowless screen can be cancelled")


func _test_long_rows_and_selection_scroll() -> void:
	await _setup()
	var rows: Array[Dictionary] = []
	for index in 8:
		rows.append({"id": "row_%d" % index,
			"label": "Row %d: A long descriptive choice that wraps without hiding its important final words" % index,
			"detail": "This explanatory detail remains readable across multiple lines. ".repeat(5)})
	await _show("controls", "", rows, 0, "An unusually long title which stays inside the heading area ".repeat(4))
	var scroll := _scroll()
	var title := _node("Title") as Label
	assert_true(title.clip_text, "long title clips within its reserved heading area")
	assert_true(not (_node("Body") as Label).visible, "empty body reserves no visible text region")
	var row_nodes := _rows().get_children()
	assert_eq(row_nodes.size(), 8, "all long action rows are retained")
	for row_node: Node in row_nodes:
		var row := row_node as Control
		assert_true(row.size.x <= scroll.size.x, "long row fits scroll width")
		for label_name: String in ["Label", "Detail"]:
			var label := row.find_child(label_name, true, false) as Label
			assert_true(label != null and label.autowrap_mode != TextServer.AUTOWRAP_OFF, "long %s wraps" % label_name)
			if label != null:
				assert_true(row.get_global_rect().encloses(label.get_global_rect()), "wrapped %s remains inside its row" % label_name)
	for _index in 7:
		await _pulse(Action.DOWN)
	assert_true(scroll.scroll_vertical > 0, "navigation scrolls toward lower selected actions")
	var last_row := row_nodes[7] as Control
	assert_true(scroll.get_global_rect().intersects(last_row.get_global_rect()), "last selected row is visible")
	await _pulse(Action.INTERACT)
	_expect([{"action": "row_7", "payload": null}], "all long rows can be reached by owned navigation")


func _test_glyph_replacement() -> void:
	await _setup()
	await _show("dialogue", "line\r\ntab\tend é 🧵", [{"id": "next", "label": "Neri — next", "detail": "Café → home"}], 0, "Tavi’s thread")
	# The apostrophe replacement must preserve the following s.
	assert_eq((_node("Title") as Label).text, "Tavi%ss thread" % char(65533), "title replacement preserves remaining ASCII")
	assert_eq((_node("Body") as Label).text, "line\ntab    end %s %s" % [char(65533), char(65533)], "line breaks/tabs normalize and unsupported glyphs have explicit replacements")
	var row := _rows().get_child(0)
	assert_eq((row.find_child("Label", true, false) as Label).text, "Neri %s next" % char(65533), "row label uses supported glyph boundary")
	assert_eq((row.find_child("Detail", true, false) as Label).text, "Caf%s %s home" % [char(65533), char(65533)], "detail uses supported glyph boundary")


func _test_missing_font_and_invalid_owner() -> void:
	await _setup(false)
	await _show("title", "", [{"id": "start", "label": "Start"}])
	assert_true(not _menu.visible, "menu cannot open without the original font")
	assert_true(not str(_menu.get("last_error")).is_empty(), "missing font reports its failure")
	await _pulse(Action.JUMP)
	_expect([], "missing font cannot fabricate an active menu")
	_menu.call("set_font", _font)
	await _show("title", "", [{"id": "retained", "label": "Retained"}])
	for owner: int in [-1, 2, 100]:
		await _show("invalid", "Bad owner", [{"id": "wrong", "label": "Wrong"}], owner)
		assert_true(not str(_menu.get("last_error")).is_empty(), "invalid owner reports failure")
		await _pulse(Action.JUMP, 1)
		_expect([], "invalid owner does not grant partner control")
		await _pulse(Action.JUMP)
		_expect([{"action": "retained", "payload": null}], "invalid owner preserves current menu")
	_menu.call("set_font", null)
	await _step(1)
	assert_true(not _menu.visible, "removing required font closes the menu visibly")
	await _pulse(Action.INTERACT)
	_expect([], "font invalidation leaves no actionable hidden menu")


func _test_callback_screen_change() -> void:
	await _setup()
	await _show("title", "", [{"id": "open_join", "label": "Join"}])
	_menu.connect("action_requested", _open_next_screen)
	InputRouter.set_test_input(0, Action.JUMP | Action.INTERACT)
	await _step(1)
	_expect([{"action": "open_join", "payload": null}], "first screen emits before callback changes screen")
	await _step(30)
	_expect([], "held confirmation cannot activate the callback's new screen")
	assert_eq((_node("Title") as Label).text, "Join together", "callback installs the new screen")
	InputRouter.set_test_input(0, 0)
	await _step(1)
	await _pulse(Action.INTERACT)
	_expect([{"action": "begin", "payload": null}], "new screen accepts a fresh confirmation")


func _open_next_screen(action: String, _payload: Variant) -> void:
	if action == "open_join":
		var rows: Array[Dictionary] = [{"id": "begin", "label": "Begin together"}]
		_menu.call("show_menu", "join", "Join together", "Ready both couriers.", rows, 0)


func _test_adjustment_callback_updates() -> void:
	await _setup()
	await _show("settings", "", [{"id": "volume", "label": "Volume", "adjustable": true}])
	_menu.connect("action_requested", _update_adjusted_screen)
	InputRouter.set_test_input(0, Action.RIGHT)
	await _step(31)
	_expect([
		{"action": "volume", "payload": {"direction": 1}},
		{"action": "volume", "payload": {"direction": 1}},
		{"action": "volume", "payload": {"direction": 1}},
		{"action": "volume", "payload": {"direction": 1}},
	], "same-kind callback refresh preserves the owned held-adjustment repeat cadence")
	assert_eq((_node("Title") as Label).text, "Updated settings", "adjustment callback updates the visible screen")
	InputRouter.set_test_input(0, 0)
	await _step(1)


func _update_adjusted_screen(action: String, payload: Variant) -> void:
	if action == "volume" and payload is Dictionary:
		var rows: Array[Dictionary] = [{"id": "volume", "label": "Updated volume", "adjustable": true}]
		_menu.call("show_menu", "settings", "Updated settings", "", rows, 0)


func _test_same_snapshot_deduplication() -> void:
	await _setup()
	await _show("pause", "", [{"id": "resume", "label": "Resume"}])
	InputRouter.set_test_input(0, Action.JUMP)
	await _step(1)
	_expect([{"action": "resume", "payload": null}], "fresh snapshot activates once")
	# A host calling the engine lifecycle again must not consume the same edge.
	_menu.call("_physics_process", 1.0 / 60.0)
	_menu.call("_physics_process", 1.0 / 60.0)
	_expect([], "the same immutable snapshot cannot be activated twice")
	InputRouter.set_test_input(0, 0)
	await _step(1)


func _test_stale_generation_and_scroll() -> void:
	await _setup()
	var long_body := "A long preserved paragraph for generation checks.\n".repeat(40)
	await _show("map", long_body, [{"id": "old", "label": "Old action"}])
	var scroll := _scroll()
	scroll.scroll_vertical = 140
	var old_row := _rows().get_child(0) as Control
	var next_rows: Array[Dictionary] = [{"id": "new", "label": "New action"}]
	_menu.call("show_menu", "map", "Updated map", long_body, next_rows, 0)
	# The removed row is queued for deletion but can still deliver a GUI callback.
	old_row.gui_input.emit(_mouse_button(Vector2(20, 12)))
	old_row.mouse_entered.emit()
	_expect([], "stale row generation cannot activate a rebuilt menu")
	_menu.call("show_menu", "ending", "Ending", long_body, next_rows, 0)
	await _step(3)
	assert_eq(scroll.scroll_vertical, 0, "stale deferred scroll cannot overwrite a newer screen")
	var hidden_row := _rows().get_child(0) as Control
	_menu.call("hide_menu")
	hidden_row.gui_input.emit(_mouse_button(Vector2(20, 12)))
	_expect([], "hidden row callbacks cannot emit actions")


func _mouse_button(position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT, pressed: bool = true, double_click: bool = false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.double_click = double_click
	event.position = position
	return event


func _test_mouse_rows_and_arrows() -> void:
	await _setup()
	await _show("settings", "", [
		{"id": "back", "label": "Back"},
		{"id": "volume", "label": "Volume", "adjustable": true},
		{"id": "locked", "label": "Locked", "enabled": false, "adjustable": true},
	])
	var back := _rows().get_child(0) as Control
	var adjustable := _rows().get_child(1) as Control
	var disabled := _rows().get_child(2) as Control
	# This first click goes through the viewport's GUI hit testing; later events
	# exercise the public row signals for cases that need exact local positions.
	var click_position := back.get_global_rect().get_center()
	var press := _mouse_button(click_position)
	press.global_position = click_position
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(press, true)
	var release := _mouse_button(click_position, MOUSE_BUTTON_LEFT, false)
	release.global_position = click_position
	get_viewport().push_input(release, true)
	await _step(1)
	_expect([{"action": "back", "payload": null}], "left click emits a normal row action")
	for event: InputEventMouseButton in [
		_mouse_button(Vector2(30, 12), MOUSE_BUTTON_LEFT, false),
		_mouse_button(Vector2(30, 12), MOUSE_BUTTON_LEFT, true, true),
		_mouse_button(Vector2(30, 12), MOUSE_BUTTON_RIGHT),
	]:
		back.gui_input.emit(event)
	_expect([], "release, duplicate double click and right button do not activate")
	adjustable.gui_input.emit(_mouse_button(Vector2(adjustable.size.x - 60, 12)))
	adjustable.gui_input.emit(_mouse_button(Vector2(adjustable.size.x - 20, 12)))
	_expect([{"action": "volume", "payload": {"direction": -1}}, {"action": "volume", "payload": {"direction": 1}}], "mouse adjustment arrows emit explicit directions")
	adjustable.gui_input.emit(_mouse_button(Vector2(30, 12)))
	_expect([{"action": "volume", "payload": null}], "adjustable row label click confirms without direction")
	disabled.gui_input.emit(_mouse_button(Vector2(30, 12)))
	disabled.gui_input.emit(_mouse_button(Vector2(disabled.size.x - 20, 12)))
	_expect([], "disabled row and adjustment arrow ignore clicks")
	await _pulse(Action.INTERACT)
	_expect([{"action": "volume", "payload": null}], "disabled mouse click does not steal the selected action")


func _test_stationary_hover() -> void:
	await _setup()
	await _show("pause", "", [{"id": "first", "label": "First"}, {"id": "selected", "label": "Selected"}])
	await _pulse(Action.DOWN)
	var first := _rows().get_child(0) as Control
	first.mouse_entered.emit()
	var stationary := InputEventMouseMotion.new()
	stationary.position = Vector2(20, 12)
	stationary.relative = Vector2.ZERO
	first.gui_input.emit(stationary)
	await _pulse(Action.INTERACT)
	_expect([{"action": "selected", "payload": null}], "stationary pointer cannot steal owned keyboard selection during a rebuild")
	var moving := InputEventMouseMotion.new()
	moving.position = Vector2(22, 12)
	moving.relative = Vector2(2, 0)
	first.gui_input.emit(moving)
	await _pulse(Action.INTERACT)
	_expect([{"action": "first", "payload": null}], "real pointer movement can select an enabled row")


func _cleanup() -> void:
	get_tree().paused = false
	if is_instance_valid(_menu):
		_menu.free()
	_menu = null
	InputRouter.set_test_input(0, 0)
	InputRouter.set_test_input(1, 0)
	await _step(1)
	InputRouter.clear_test_input(0)
	InputRouter.clear_test_input(1)
	InputRouter.clear(0)
	InputRouter.clear(1)
	_events.clear()
