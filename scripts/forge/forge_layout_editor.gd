class_name ForgeLayoutEditor
extends Control
## Local-only annotation of retained raw boards after conversion rejection.

signal apply_requested(layout: Dictionary)
signal dismissed

const LayoutCanvas = preload("res://scripts/forge/forge_layout_canvas.gd")
const Bridge = preload("res://scripts/forge/forge_bridge.gd")

var context: Dictionary
var hosted_conversion: bool = false
var layout: Dictionary
var canvas: ForgeLayoutCanvas
var board_tabs: TabBar
var target: OptionButton
var cutoff: HSlider
var aspect: CheckBox
var save_button: Button
var notice: Label
var _coordinates: Array[SpinBox] = []
var _preview: TextureRect
var _cutoff_label: Label
var _keys: Array[String] = []
var _syncing: bool = false
var _illustrated: bool = false


func setup(raw_context: Dictionary, cost_text: String) -> void:
	context = raw_context
	layout = context["layout"].duplicate(true)
	_illustrated = layout.has("master_file") or context.get("art_mode") == "illustrated-master-v1"
	set_meta("cost_text", cost_text)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color("#101922")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	page.add_child(_label("CORRECT THE RETAINED ARTWORK", 32))
	page.add_child(_label("No new image request. Select one isolated part per crop; exclude captions, grids and neighbouring body parts.", 20))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24)
	page.add_child(row)
	var boards := VBoxContainer.new()
	boards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(boards)
	board_tabs = TabBar.new()
	board_tabs.add_tab("Parts board")
	board_tabs.add_tab("Theme board")
	board_tabs.tab_changed.connect(_board_changed)
	boards.add_child(board_tabs)
	canvas = LayoutCanvas.new()
	canvas.custom_minimum_size = Vector2(640, 640)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.selection_changed.connect(_crop_selected)
	boards.add_child(canvas)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 510
	panel.add_theme_constant_override("separation", 10)
	row.add_child(panel)
	panel.add_child(_label("Assign the highlighted rectangle to", 21))
	target = OptionButton.new()
	target.custom_minimum_size.y = 44
	target.item_selected.connect(_target_changed)
	panel.add_child(target)
	var instruction := _label("Choose a target, then drag on its board. Crop each limb separately. Master is the whole character. The background must contain scenery only; crop out any giant character.", 18)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(instruction)
	var numbers := HBoxContainer.new()
	panel.add_child(numbers)
	for title: String in ["X", "Y", "Width", "Height"]:
		var column := VBoxContainer.new()
		numbers.add_child(column)
		column.add_child(_label(title, 17))
		var number := SpinBox.new()
		number.min_value = 0 if _coordinates.size() < 2 else 4
		number.max_value = 1020 if _coordinates.size() < 2 else 1024
		number.step = 1
		number.custom_minimum_size.x = 115
		number.value_changed.connect(_numeric_crop)
		column.add_child(number)
		_coordinates.append(number)
	aspect = CheckBox.new()
	aspect.text = "Keep background drag at 16:9"
	aspect.button_pressed = true
	aspect.toggled.connect(func(_enabled: bool) -> void: _update_aspect())
	panel.add_child(aspect)
	_cutoff_label = _label("", 18)
	panel.add_child(_cutoff_label)
	cutoff = HSlider.new()
	cutoff.min_value = 1
	cutoff.max_value = 255
	cutoff.step = 1
	cutoff.value = layout["alpha_cutoff"]
	cutoff.value_changed.connect(_cutoff_changed)
	panel.add_child(cutoff)
	var alpha_help := _label("Parts/master only: discard pixels below this opacity. Start at 192 for translucent haze; lower it if details disappear. It cannot remove an opaque painted background.", 17)
	alpha_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(alpha_help)
	_preview = TextureRect.new()
	# Leave room for prices and the conversion actions on the 1080px UI canvas.
	_preview.custom_minimum_size = Vector2(360, 180)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(_preview)
	var cost := _label(str(get_meta("cost_text", "")) + ("\nThis correction converts saved images on the server without a model request." if hosted_conversion else "\nThis correction uses cached images and local conversion only."), 17)
	cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(cost)
	notice = _label("Review every target; conversion cannot invent missing limbs. This creates a new draft with fresh masks/pivots. Your previous draft and preview stay intact.", 18)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.y = 44
	page.add_child(notice)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 20)
	page.add_child(actions)
	var back := Button.new()
	back.text = "Back — keep existing preview"
	back.custom_minimum_size.y = 48
	back.pressed.connect(func() -> void: dismissed.emit())
	actions.add_child(back)
	save_button = Button.new()
	save_button.text = "Save corrections & convert" if hosted_conversion else "Save corrections & convert locally"
	save_button.custom_minimum_size.y = 48
	save_button.pressed.connect(_apply)
	actions.add_child(save_button)
	_board_changed(0)
	_cutoff_changed(cutoff.value)
	if _illustrated:
		board_tabs.set_tab_disabled(0, true)
		board_tabs.current_tab = 1
		notice.text = "Your complete illustrated character is preserved. Adjust scenery here; edit its full-character mask and pivot on the preview page."


func _board_changed(index: int) -> void:
	_keys.clear()
	target.clear()
	if index == 0:
		for id: String in Bridge.LAYOUT_PARTS[context["rig_id"]]:
			_keys.append(id)
		_keys.append("master")
	else:
		_keys = ["background", "material_0", "material_1", "material_2", "material_3"]
	for key: String in _keys:
		target.add_item(key.replace("_", " ").capitalize())
	canvas.set_board(context["parts" if index == 0 else "theme"])
	_target_changed(0)


func _target_changed(index: int) -> void:
	target.select(index)
	var key := _keys[index]
	var crop: Array
	if key == "master":
		crop = layout["master_crop"]
	elif key == "background":
		crop = layout["background_crop"]
	elif key.begins_with("material_"):
		if not layout.has("material_crops"):
			layout["material_crops"] = Bridge.new().default_source_layout(context)["material_crops"]
		crop = layout["material_crops"][int(key.trim_prefix("material_"))]
	else:
		crop = layout["parts"][key]["crop"]
	canvas.set_crop(crop)
	_sync_coordinates(crop)
	_update_aspect()
	_refresh_preview()


func _update_aspect() -> void:
	var is_background := not _keys.is_empty() and _keys[target.selected] == "background"
	aspect.visible = is_background
	canvas.lock_widescreen = is_background and aspect.button_pressed


func _crop_selected(crop: Array) -> void:
	var key := _keys[target.selected]
	if key == "master":
		layout["master_crop"] = crop.duplicate()
	elif key == "background":
		layout["background_crop"] = crop.duplicate()
	elif key.begins_with("material_"):
		layout["material_crops"][int(key.trim_prefix("material_"))] = crop.duplicate()
	else:
		layout["parts"][key]["crop"] = crop.duplicate()
	canvas.set_crop(crop)
	_sync_coordinates(crop)
	_refresh_preview()


func _sync_coordinates(crop: Array) -> void:
	_syncing = true
	for index in 4:
		_coordinates[index].value = crop[index]
	_syncing = false


func _numeric_crop(_value: float) -> void:
	if _syncing:
		return
	var x := int(_coordinates[0].value)
	var y := int(_coordinates[1].value)
	_crop_selected([x, y, mini(int(_coordinates[2].value), 1024 - x), mini(int(_coordinates[3].value), 1024 - y)])


func _cutoff_changed(value: float) -> void:
	layout["alpha_cutoff"] = int(value)
	_cutoff_label.text = "Opacity cutoff: %d / 255" % int(value)
	_refresh_preview()


func _refresh_preview() -> void:
	if canvas.image == null:
		return
	var cropped := canvas.image.get_region(canvas.crop)
	if board_tabs.current_tab == 0:
		# Resize only the preview; conversion always receives original coordinates.
		var factor := minf(1.0, 300.0 / maxi(cropped.get_width(), cropped.get_height()))
		cropped.resize(maxi(1, roundi(cropped.get_width() * factor)), maxi(1, roundi(cropped.get_height() * factor)), Image.INTERPOLATE_NEAREST)
		for y in cropped.get_height():
			for x in cropped.get_width():
				var color := cropped.get_pixel(x, y)
				color.a = 1.0 if roundi(color.a * 255.0) >= int(layout["alpha_cutoff"]) else 0.0
				cropped.set_pixel(x, y, color)
	_preview.texture = ImageTexture.create_from_image(cropped)


func _apply() -> void:
	var error := Bridge.new().source_layout_error(layout, context)
	if not error.is_empty():
		notice.text = error
		return
	var issue := Bridge.new().source_layout_pixel_issue(layout, context)
	if not issue.is_empty():
		if not _illustrated:
			board_tabs.current_tab = 0
			var index := _keys.find(issue["target"])
			if index >= 0:
				_target_changed(index)
		notice.text = issue["error"]
		notice.add_theme_color_override("font_color", Color("#ffd4a1"))
		target.grab_focus()
		return
	apply_requested.emit(layout.duplicate(true))


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label
