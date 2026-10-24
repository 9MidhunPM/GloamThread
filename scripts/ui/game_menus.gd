class_name GameMenus
extends CanvasLayer
## One shared, render-only menu. The application interprets emitted intents;
## this component never pauses gameplay, assigns devices or writes settings.

signal action_requested(action: String, payload: Variant)

const Action := CommandSnapshot.Action
const REPEAT_DELAY := 18
const REPEAT_INTERVAL := 6
const SCROLL_STEP := 32
const BACKGROUND := Color("#10141c")
const PANEL := Color("#1c2432")
const EDGE := Color("#41465a")
const FOCUS := Color("#ffe0a1")

var last_error: String = ""
var _font: Font
var _kind: String = ""
var _owner_slot: int = 0
var _rows: Array[Dictionary] = []
var _selected: int = -1
var _generation: int = 0
var _repeat_action: int = 0
var _repeat_ticks: int = 0
var _last_snapshot: CommandSnapshot
var _screen: Control
var _title: Label
var _body: Label
var _footer: Label
var _scroll: ScrollContainer
var _rows_box: VBoxContainer
var _row_panels: Array[PanelContainer] = []
var _row_marks: Array[Label] = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	visible = false


func _ready() -> void:
	_ensure_ui()


func set_font(font: Font) -> void:
	_font = font
	if font == null:
		_reject("GameMenus requires the project's original font")
		hide_menu()
		return
	if _screen != null:
		_apply_font()


func show_menu(kind: String, title: String, body: String, rows: Array[Dictionary], owner_slot: int = 0) -> void:
	# Validate before touching the existing menu or its input ownership.
	if _font == null:
		_reject("GameMenus: call set_font with the original font before show_menu")
		return
	if owner_slot < 0 or owner_slot >= InputRouter.slot_count():
		_reject("GameMenus: owner_slot must identify player 0 or 1")
		return
	if kind.is_empty():
		_reject("GameMenus: kind must be nonempty")
		return
	var next_rows: Array[Dictionary] = []
	var ids: Dictionary = {}
	for row: Dictionary in rows:
		var id: Variant = row.get("id")
		var label: Variant = row.get("label")
		if not id is String or id.strip_edges().is_empty() or ids.has(id):
			_reject("GameMenus: rows require nonempty unique string ids")
			return
		if not label is String or label.strip_edges().is_empty():
			_reject("GameMenus: each row requires a nonempty string label")
			return
		if not row.get("detail", "") is String or not row.get("enabled", true) is bool or not row.get("adjustable", false) is bool:
			_reject("GameMenus: row detail/enabled/adjustable types are invalid")
			return
		ids[id] = true
		next_rows.append({"id": id, "label": label, "detail": row.get("detail", ""),
			"enabled": row.get("enabled", true), "adjustable": row.get("adjustable", false)})
	_ensure_ui()
	var same_menu := visible and _kind == kind
	var input_boundary := not same_menu or _owner_slot != owner_slot
	var selected_id := str(_rows[_selected]["id"]) if _selected >= 0 and _selected < _rows.size() else ""
	var scroll_y := _scroll.scroll_vertical if same_menu else 0
	if input_boundary:
		# This is a shared overlay: neither player's held gameplay action may
		# leak through its entry/exit, even though only the owner navigates it.
		InputRouter.flush()
		_reset_repeat()
		_last_snapshot = null
	_kind = kind
	_owner_slot = owner_slot
	_rows = next_rows
	_selected = -1
	for index in _rows.size():
		if _rows[index]["enabled"] and (_selected == -1 or (same_menu and _rows[index]["id"] == selected_id)):
			_selected = index
			if same_menu and _rows[index]["id"] == selected_id:
				break
	_generation += 1
	_title.text = _glyph_text(title)
	_body.text = _glyph_text(body)
	_body.visible = not body.is_empty()
	_rebuild_rows()
	_update_footer()
	visible = true
	last_error = ""
	_restore_scroll.call_deferred(_generation, scroll_y)


func hide_menu() -> void:
	if visible:
		InputRouter.flush()
	visible = false
	_kind = ""
	_generation += 1
	_reset_repeat()
	_last_snapshot = null


func _physics_process(_delta: float) -> void:
	if not visible or _screen == null:
		return
	_update_footer()
	var commands: CommandSnapshot = InputRouter.snapshot(_owner_slot)
	# A snapshot is immutable and replaced by InputRouter each physics tick.
	# Never consume the same pressed edge twice, even if called again by a host.
	if commands == _last_snapshot:
		return
	_last_snapshot = commands
	if commands.just_pressed(Action.PAUSE):
		_reset_repeat()
		action_requested.emit("cancel", null)
		return
	if commands.just_pressed(Action.JUMP) or commands.just_pressed(Action.INTERACT):
		_reset_repeat()
		_confirm()
		return
	var action := _direction_action(commands)
	if action == 0:
		_reset_repeat()
		return
	if action != _repeat_action or commands.just_pressed(action as Action):
		_repeat_action = action
		_repeat_ticks = 0
		_step(action)
		return
	_repeat_ticks += 1
	if _repeat_ticks >= REPEAT_DELAY and (_repeat_ticks - REPEAT_DELAY) % REPEAT_INTERVAL == 0:
		_step(action)


func _direction_action(commands: CommandSnapshot) -> int:
	var vertical := int(commands.is_held(Action.DOWN)) - int(commands.is_held(Action.UP))
	if vertical != 0:
		return Action.DOWN if vertical > 0 else Action.UP
	var horizontal := int(commands.is_held(Action.RIGHT)) - int(commands.is_held(Action.LEFT))
	if horizontal != 0:
		return Action.RIGHT if horizontal > 0 else Action.LEFT
	return 0


func _step(action: int) -> void:
	if action == Action.UP or action == Action.DOWN:
		_navigate(-1 if action == Action.UP else 1)
		return
	if _selected >= 0 and _rows[_selected]["enabled"] and _rows[_selected]["adjustable"]:
		var id: String = _rows[_selected]["id"]
		action_requested.emit(id, {"direction": -1 if action == Action.LEFT else 1})


func _navigate(direction: int) -> void:
	if _selected < 0:
		_scroll.scroll_vertical += direction * SCROLL_STEP
		return
	var selected_rect := _row_panels[_selected].get_global_rect()
	var viewport_rect := _scroll.get_global_rect()
	# Long bodies remain readable before moving on to the action rows.
	if direction > 0 and selected_rect.position.y >= viewport_rect.end.y:
		_scroll.scroll_vertical += SCROLL_STEP
		return
	if direction < 0 and selected_rect.end.y <= viewport_rect.position.y:
		_scroll.scroll_vertical -= SCROLL_STEP
		return
	var next := _selected + direction
	while next >= 0 and next < _rows.size() and not _rows[next]["enabled"]:
		next += direction
	if next < 0 or next >= _rows.size():
		_scroll.scroll_vertical += direction * SCROLL_STEP
		return
	_selected = next
	_refresh_selection()
	_scroll.ensure_control_visible(_row_panels[_selected])


func _confirm() -> void:
	if _selected >= 0 and _rows[_selected]["enabled"]:
		var id: String = _rows[_selected]["id"]
		action_requested.emit(id, null)


func _reset_repeat() -> void:
	_repeat_action = 0
	_repeat_ticks = 0


func _reject(message: String) -> void:
	last_error = message
	push_error(message)


static func _glyph_text(text: String) -> String:
	var clean := ""
	for character in text.replace("\r\n", "\n").replace("\t", "    "):
		var code := character.unicode_at(0)
		clean += character if character == "\n" or (code >= 32 and code <= 126) else char(65533)
	return clean


func _ensure_ui() -> void:
	if _screen != null:
		return
	_screen = Control.new()
	_screen.name = "MenuRoot"
	_screen.size = Vector2(960, 360)
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_screen.focus_mode = Control.FOCUS_NONE
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_screen)
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.size = _screen.size
	shade.color = Color(0.063, 0.078, 0.110, 0.94)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(shade)
	var panel := Panel.new()
	panel.name = "Panel"
	panel.position = Vector2(24, 24)
	panel.size = Vector2(912, 312)
	panel.add_theme_stylebox_override("panel", _box(PANEL, EDGE, 1))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(panel)
	_title = _label("Title", 24)
	_title.position = Vector2(44, 36)
	_title.size = Vector2(872, 32)
	_title.clip_text = true
	_screen.add_child(_title)
	var seam := ColorRect.new()
	seam.name = "Seam"
	seam.position = Vector2(44, 72)
	seam.size = Vector2(872, 2)
	seam.color = FOCUS
	seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(seam)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.position = Vector2(44, 84)
	_scroll.size = Vector2(872, 212)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.focus_mode = Control.FOCUS_NONE
	_scroll.follow_focus = false
	_screen.add_child(_scroll)
	var bar := _scroll.get_v_scroll_bar()
	bar.focus_mode = Control.FOCUS_NONE
	bar.add_theme_stylebox_override("scroll", _box(BACKGROUND, BACKGROUND, 0))
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, _box(EDGE if state == "grabber" else FOCUS, EDGE, 0))
	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size.x = 848
	content.add_theme_constant_override("separation", 12)
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(content)
	_body = _label("Body", 16)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_body)
	_rows_box = VBoxContainer.new()
	_rows_box.name = "Rows"
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 6)
	_rows_box.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(_rows_box)
	_footer = _label("Footer", 8)
	_footer.position = Vector2(44, 312)
	_footer.size = Vector2(872, 16)
	_footer.clip_text = true
	_screen.add_child(_footer)
	if _font != null:
		_apply_font()


func _apply_font() -> void:
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", Color.WHITE)
	_screen.theme = theme


static func _label(node_name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	return label


static func _box(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	return style


func _rebuild_rows() -> void:
	for child in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_row_panels.clear()
	_row_marks.clear()
	for index in _rows.size():
		var row: Dictionary = _rows[index]
		var panel := PanelContainer.new()
		panel.name = "Row_%d" % index
		panel.focus_mode = Control.FOCUS_NONE
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if row["enabled"] else Control.CURSOR_ARROW
		panel.gui_input.connect(_row_mouse.bind(index, _generation))
		var margin := MarginContainer.new()
		for edge: String in ["left", "right"]:
			margin.add_theme_constant_override("margin_" + edge, 12)
		for edge: String in ["top", "bottom"]:
			margin.add_theme_constant_override("margin_" + edge, 8)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(margin)
		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation", 4)
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(lines)
		var heading := HBoxContainer.new()
		heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.add_child(heading)
		var mark := _label("Mark", 16)
		mark.custom_minimum_size.x = 20
		heading.add_child(mark)
		var label := _label("Label", 16)
		label.text = _glyph_text(str(row["label"]) if row["enabled"] else "Unavailable: " + str(row["label"]))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(label)
		if row["adjustable"]:
			var arrows := _label("Adjust", 16)
			arrows.text = "<   >"
			arrows.custom_minimum_size.x = 60
			heading.add_child(arrows)
		if not str(row["detail"]).is_empty():
			var detail := _label("Detail", 8)
			detail.text = _glyph_text(row["detail"])
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lines.add_child(detail)
		if not row["enabled"]:
			lines.modulate = Color(0.60, 0.64, 0.68)
		_rows_box.add_child(panel)
		_row_panels.append(panel)
		_row_marks.append(mark)
	_refresh_selection()


func _refresh_selection() -> void:
	for index in _row_panels.size():
		var selected := index == _selected
		_row_panels[index].add_theme_stylebox_override("panel", _box(Color("#293247") if selected else PANEL,
			FOCUS if selected else EDGE, 2 if selected else 1))
		_row_marks[index].text = ">" if selected else ("-" if not _rows[index]["enabled"] else " ")


func _row_mouse(event: InputEvent, index: int, generation: int) -> void:
	if not visible or generation != _generation or not _rows[index]["enabled"]:
		return
	# Rebuilding under a stationary pointer must not steal keyboard selection.
	if event is InputEventMouseMotion:
		if not event.relative.is_zero_approx():
			_selected = index
			_refresh_selection()
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed or event.double_click:
		return
	_selected = index
	_refresh_selection()
	_row_panels[index].accept_event()
	if _rows[index]["adjustable"] and event.position.x >= _row_panels[index].size.x - 80:
		var direction := -1 if event.position.x < _row_panels[index].size.x - 42 else 1
		action_requested.emit(str(_rows[index]["id"]), {"direction": direction})
		return
	_confirm()


func _update_footer() -> void:
	var bindings: Bindings = InputRouter.bindings_of(_owner_slot)
	var source: DeviceSource = InputRouter.source_of(_owner_slot)
	var device := source.short_label() if source != null else "UNASSIGNED"
	if bindings == null:
		_footer.text = "P%d %s | Assign an input source to use keyboard/gamepad controls" % [_owner_slot + 1, device]
		return
	_footer.text = _glyph_text("P%d %s | %s/%s Select/scroll | %s/%s Choose | %s Back | %s/%s Adjust" % [
		_owner_slot + 1, device, bindings.prompt_label(Action.UP), bindings.prompt_label(Action.DOWN),
		bindings.prompt_label(Action.JUMP), bindings.prompt_label(Action.INTERACT), bindings.prompt_label(Action.PAUSE),
		bindings.prompt_label(Action.LEFT), bindings.prompt_label(Action.RIGHT)])


func _restore_scroll(generation: int, scroll_y: int) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if visible and generation == _generation:
		_scroll.scroll_vertical = scroll_y
