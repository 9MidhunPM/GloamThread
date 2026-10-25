class_name CharacterCreator
extends Control
## Fullscreen local library and creation flow. No credentials or SDK in Godot.

signal completed(bundle: Dictionary)
signal cancelled

const Library = preload("res://scripts/forge/fighter_library.gd")
const Canvas = preload("res://scripts/forge/forge_canvas.gd")
const Bridge = preload("res://scripts/forge/forge_bridge.gd")
const LayoutEditor = preload("res://scripts/forge/forge_layout_editor.gd")
const CLIPS := {"idle": [0, 4], "run": [4, 6], "rise": [10, 2], "fall": [12, 2], "land": [14, 2], "slash": [16, 4], "special": [20, 4], "hurt": [24, 2], "dash": [26, 2], "downed": [28, 2], "revive": [30, 2]}
const PART_IDS := {"upright": ["torso", "head", "arm_back", "arm_front", "leg_back", "leg_front"], "quadruped": ["torso", "head", "leg_back_left", "leg_back_right", "leg_front_left", "leg_front_right", "tail"], "floating": ["torso", "arm_back", "arm_front"]}

var library: FighterLibrary
var slot: int = 0
var bridge: ForgeBridge = Bridge.new()
var job_path: String = ""
var candidate: Dictionary = {}
var state: String = "idle"

var _tabs: TabContainer
var _library_grid: GridContainer
var _canvas: ForgeCanvas
var _mask_canvas: ForgeCanvas
var _description: TextEdit
var _name: LineEdit
var _rig: OptionButton
var _kit: OptionButton
var _theme_name: LineEdit
var _palette: LineEdit
var _motif: LineEdit
var _message: Label
var _cost: Label
var _analyse: Button
var _setup_check: Button
var _generate: Button
var _retry: Button
var _cancel_job: Button
var _accept: Button
var _bake: Button
var _background: TextureRect
var _portrait: TextureRect
var _sprite: TextureRect
var _clip: OptionButton
var _part: OptionButton
var _pivot_x: SpinBox
var _pivot_y: SpinBox
var _part_records: Array[Dictionary] = []
var _mask_data: Dictionary = {}
var _joint_data: Dictionary = {}
var _selected_part: String = ""
var _dialog: FileDialog
var _poll_elapsed: float = 0.0
var _animation_tick: int = 0
var _last_preview_frame: int = -1
var _last_status: String = ""
var _operation: String = ""
var _busy: bool = false
var _edit_dirty: bool = false
var _loading_part: bool = false
var _started_msec: int = 0
var _source_controls: Array[BaseButton] = []
var _features: Array[String] = []
var _import_bytes := PackedByteArray()
var _import_extension: String = ""
var _job_source_hash: String = ""
var _preview_job_path: String = ""
var _repair: Button
var _layout_editor: ForgeLayoutEditor
var _layout_context: Dictionary = {}
var _layout_job_path: String = ""
var _layout_focus: Dictionary = {}
var _retry_allowed: bool = false
var _kit_chosen_by_player: bool = false
var _applying_proposal: bool = false


func setup(player_slot: int, fighter_library: FighterLibrary) -> void:
	slot = player_slot
	library = fighter_library
	if is_node_ready():
		_refresh_library()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if library == null:
		library = Library.new()
	_build_ui()
	_refresh_library()
	_refresh_configuration(false)


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#101922")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)
	var header := HBoxContainer.new()
	page.add_child(header)
	var title := _label("MAKE YOUR MARK", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_label("PLAYER %d" % (slot + 1), 22))
	header.add_child(_button("Back", _leave))
	page.add_child(_label("Your drawing. Your fighter. Choose a saved character or forge a new one.", 20, Color("#a2b5bc")))
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", 22)
	page.add_child(_tabs)
	var library_scroll := ScrollContainer.new()
	library_scroll.name = "Your fighters"
	_tabs.add_child(library_scroll)
	_library_grid = GridContainer.new()
	_library_grid.columns = 4
	_library_grid.add_theme_constant_override("h_separation", 22)
	_library_grid.add_theme_constant_override("v_separation", 20)
	_library_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_scroll.add_child(_library_grid)
	var forge_scroll := ScrollContainer.new()
	forge_scroll.name = "Draw & forge"
	_tabs.add_child(forge_scroll)
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 28)
	forge_scroll.add_child(columns)
	_build_source(columns)
	_build_proposal(columns)
	_build_preview(columns)
	# Request cancellation and acceptance must remain visible while forms scroll.
	var action_bar := HBoxContainer.new()
	action_bar.name = "CreationActions"
	action_bar.add_theme_constant_override("separation", 16)
	page.add_child(action_bar)
	for button: Button in [_generate, _cancel_job, _retry]:
		button.reparent(action_bar)
	_repair = _button("Correct cached layout", _open_layout_editor)
	_repair.visible = false
	action_bar.add_child(_repair)
	_cost.reparent(action_bar)
	_cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cost.custom_minimum_size.x = 400
	_accept.reparent(action_bar)
	action_bar.visible = _tabs.current_tab == 1
	_tabs.tab_changed.connect(func(index: int) -> void: action_bar.visible = index == 1)
	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.filters = PackedStringArray(["*.png ; PNG image", "*.jpg, *.jpeg ; JPEG image"])
	_dialog.title = "Choose your original drawing"
	_dialog.file_selected.connect(import_source)
	add_child(_dialog)
	_message = _label("Saved fighters work offline. New AI artwork uses your configured local authoring service.", 20)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.y = 54
	page.add_child(_message)
	_apply_theme()
	for field: LineEdit in [_name, _theme_name, _palette, _motif]:
		field.text_changed.connect(func(_text: String) -> void: _proposal_edited())
	_rig.item_selected.connect(func(_index: int) -> void: _proposal_edited())
	_kit.item_selected.connect(func(_index: int) -> void:
		_kit_chosen_by_player = true
		_proposal_edited())
	_name.text_changed.connect(func(_text: String) -> void: _identity_edited())
	_description.text_changed.connect(_identity_edited)
	_update_controls()


func _build_source(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 520
	column.add_theme_constant_override("separation", 12)
	parent.add_child(column)
	column.add_child(_label("01 / YOUR ORIGINAL", 23))
	_canvas = Canvas.new()
	_canvas.name = "DrawingCanvas"
	_canvas.custom_minimum_size = Vector2(448, 384)
	column.add_child(_canvas)
	var colours := HBoxContainer.new()
	column.add_child(colours)
	for hex: String in ["#e8e1c9", "#e4a85b", "#e56f65", "#87bba4", "#6ca7ce", "#a38ecb", "#293247", "#ffffff"]:
		var color := Color(hex)
		var swatch := _button("", func() -> void: _canvas.ink = color; _canvas.eraser = false)
		swatch.custom_minimum_size = Vector2(48, 38)
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(6)
		swatch.add_theme_stylebox_override("normal", style)
		colours.add_child(swatch)
		_source_controls.append(swatch)
	var tools_row := HBoxContainer.new()
	column.add_child(tools_row)
	tools_row.add_child(_button("Pen", func() -> void: _canvas.eraser = false))
	tools_row.add_child(_button("Eraser", func() -> void: _canvas.eraser = true))
	tools_row.add_child(_button("Clear", _canvas.clear_canvas))
	tools_row.add_child(_button("Import image", func() -> void: _dialog.popup_centered_ratio(0.75)))
	for child: Node in tools_row.get_children():
		_source_controls.append(child as BaseButton)
	var brush := HSlider.new()
	brush.min_value = 1
	brush.max_value = 24
	brush.value = 8
	brush.custom_minimum_size.x = 120
	brush.tooltip_text = "Brush radius"
	brush.value_changed.connect(func(value: float) -> void: _canvas.brush_size = int(value))
	column.add_child(brush)
	column.add_child(_label("Tell us about your character (optional)", 18))
	_description = TextEdit.new()
	_description.placeholder_text = "A little storm fox with a copper scarf…"
	_description.custom_minimum_size.y = 80
	_description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	column.add_child(_description)


func _build_proposal(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 410
	column.add_theme_constant_override("separation", 12)
	parent.add_child(column)
	column.add_child(_label("02 / SHAPE THE IDEA", 23))
	_analyse = _button("Analyse drawing", analyse_source)
	column.add_child(_analyse)
	_setup_check = _button("Check AI setup / budget", _refresh_configuration)
	column.add_child(_setup_check)
	column.add_child(_label("Review every suggestion before generating.", 17, Color("#a2b5bc")))
	_name = _field(column, "Fighter name / weapon concept (guides artwork)", "My fighter", 40)
	column.add_child(_label("Body shape", 18))
	_rig = _options(Library.RIGS)
	column.add_child(_rig)
	column.add_child(_label("Ability family", 18))
	_kit = _options(Library.KITS)
	column.add_child(_kit)
	_theme_name = _field(column, "Arena theme", "Copper dusk", 60)
	_palette = _field(column, "Palette · 4–8 hex colours, separated by commas", "#17232E,#355D69,#E4A85B,#E8E1C9", 80)
	_motif = _field(column, "Theme motif", "Copper threads and drifting stars", 400)
	var notice := _label("Body shape changes animation. Your selected ability family supplies tested combat powers.", 18, Color("#a2b5bc"))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(notice)
	_generate = _button("Generate artwork", generate_candidate)
	column.add_child(_generate)
	_cost = _label("No local dollar cap. Model requests use your API account.\nLocal edits and accepted fighters work offline.", 17, Color("#a2b5bc"))
	_cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_cost)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	_cancel_job = _button("Cancel request", _cancel_request)
	actions.add_child(_cancel_job)
	_retry = _button("New attempt", _retry_job)
	actions.add_child(_retry)
	var caution := _label("Reservations are conservative allowances, not billing. Cancellation stops later work; a request already sent may still be billed.", 16, Color("#a2b5bc"))
	caution.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(caution)


func _build_preview(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 640
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	parent.add_child(column)
	column.add_child(_label("03 / MAKE IT YOURS", 23))
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(640, 360)
	column.add_child(stage)
	_background = _texture_rect()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_background)
	_sprite = _texture_rect()
	_sprite.position = Vector2(224, 120)
	_sprite.size = Vector2(192, 192)
	stage.add_child(_sprite)
	_portrait = _texture_rect()
	_portrait.position = Vector2(16, 16)
	_portrait.size = Vector2(96, 96)
	stage.add_child(_portrait)
	_clip = _options(CLIPS.keys())
	_clip.item_selected.connect(func(_index: int) -> void: _animation_tick = 0)
	column.add_child(_clip)
	var corrections := HBoxContainer.new()
	corrections.add_theme_constant_override("separation", 14)
	column.add_child(corrections)
	_mask_canvas = Canvas.new()
	_mask_canvas.name = "MaskCanvas"
	_mask_canvas.custom_minimum_size = Vector2(256, 256)
	_mask_canvas.changed.connect(_mask_changed)
	_mask_canvas.pivot_changed.connect(_pivot_changed)
	corrections.add_child(_mask_canvas)
	var edits := VBoxContainer.new()
	edits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corrections.add_child(edits)
	edits.add_child(_label("Part masks & joints", 20))
	_part = OptionButton.new()
	_part.item_selected.connect(_select_part)
	edits.add_child(_part)
	var tools_row := HBoxContainer.new()
	edits.add_child(tools_row)
	tools_row.add_child(_button("Erase", func() -> void: _mask_canvas.eraser = true; _mask_canvas.pivot_mode = false))
	tools_row.add_child(_button("Restore", func() -> void: _mask_canvas.eraser = false; _mask_canvas.pivot_mode = false))
	tools_row.add_child(_button("Joint", func() -> void: _mask_canvas.pivot_mode = true))
	var joints := HBoxContainer.new()
	edits.add_child(joints)
	for axis in 2:
		joints.add_child(_label("X" if axis == 0 else "Y", 18))
		var spinner := SpinBox.new()
		spinner.min_value = 0
		spinner.max_value = 63
		spinner.step = 1
		spinner.custom_minimum_size.x = 105
		spinner.value_changed.connect(_numeric_pivot)
		joints.add_child(spinner)
		if axis == 0:
			_pivot_x = spinner
		else:
			_pivot_y = spinner
	_bake = _button("Apply edits · local bake", bake_edits)
	edits.add_child(_bake)
	var detail := _label("Erase unwanted pixels or move a joint, then rebake and inspect every animation.", 16, Color("#a2b5bc"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	edits.add_child(detail)
	_accept = _button("Accept fighter & play", accept_preview)
	column.add_child(_accept)


func _refresh_library() -> void:
	for child: Node in _library_grid.get_children():
		child.queue_free()
	var bundles := library.list_bundles()
	for bundle: Dictionary in bundles:
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(370, 360)
		_library_grid.add_child(card)
		var image := _texture_rect()
		image.texture = bundle["portrait"]
		image.custom_minimum_size = Vector2(256, 256)
		card.add_child(image)
		card.add_child(_label(bundle["name"], 26))
		card.add_child(_label("%s / %s" % [bundle["rig_id"].capitalize(), bundle["kit_id"].capitalize()], 18, Color("#a2b5bc")))
		card.add_child(_button("Choose fighter", func() -> void: completed.emit(bundle)))
	if bundles.is_empty():
		var empty := _label("No validated fighters found. Create a fighter or check the built-in asset installation.", 22)
		empty.custom_minimum_size.x = 700
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_library_grid.add_child(empty)
	var jobs := DirAccess.get_directories_at(bridge.job_root) if DirAccess.dir_exists_absolute(bridge.job_root) else PackedStringArray()
	jobs.reverse()
	var shown := 0
	for folder: String in jobs:
		if shown >= 8:
			break
		var path := ProjectSettings.globalize_path(bridge.job_root).path_join(folder).path_join("job.json")
		if not bridge.trusted_job(path):
			continue
		var status := bridge.status(path)
		if status.get("state") in ["complete", "awaiting_approval", "failed", "cancelled"]:
			var button := _button("Resume draft\n%s\n%s" % [folder, status.get("state", "")], func() -> void: resume_job(path))
			button.custom_minimum_size = Vector2(370, 130)
			_library_grid.add_child(button)
			shown += 1


func import_source(path: String) -> void:
	if _busy:
		_notice("Wait for this request to finish or cancel it before replacing the drawing.")
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 16 * 1024 * 1024:
		_notice("Choose a PNG or JPEG smaller than 16 MB.")
		return
	var bytes := file.get_buffer(file.get_length())
	var dimensions := _source_dimensions(bytes)
	if dimensions.x <= 0 or dimensions.y <= 0 or dimensions.x > 4096 or dimensions.y > 4096:
		_notice("Source must be a single PNG or JPEG, at most 4096 pixels on each side.")
		return
	var image := Image.new()
	var error := image.load_png_from_buffer(bytes) if bytes[0] == 137 else image.load_jpg_from_buffer(bytes)
	if error != OK:
		_notice("The selected image could not be decoded.")
		return
	_import_bytes = bytes
	_import_extension = "png" if bytes[0] == 137 else "jpg"
	var fit := minf(1.0, 1024.0 / maxi(dimensions.x, dimensions.y))
	if fit < 1.0:
		image.resize(maxi(1, roundi(dimensions.x * fit)), maxi(1, roundi(dimensions.y * fit)), Image.INTERPOLATE_LANCZOS)
	_canvas.set_image(image)
	_notice("Source imported. Review its silhouette, then analyse or choose your own settings.")


func analyse_source() -> void:
	if not _new_job():
		return
	_start("analyse")


func generate_candidate() -> void:
	if _busy:
		return
	_apply_identity_kit()
	var proposal := _proposal()
	if proposal.is_empty():
		return
	if not job_path.is_empty():
		var existing := bridge.read_json(job_path)
		var frozen := bridge.generation_proposal_hash(job_path)
		if _drawing_hash() != _job_source_hash or str(existing.get("description", "")) != _description.text.strip_edges() or (not frozen.is_empty() and frozen != bridge.proposal_hash(proposal)):
			job_path = ""
	if job_path.is_empty() and not _new_job():
		return
	var job := bridge.read_json(job_path)
	job["preferred_name"] = proposal["name"]
	job["proposal"] = proposal
	if not bridge.write_json(job_path, job) or not bridge.write_json(job_path.get_base_dir().path_join("proposal.json"), proposal):
		_notice("Could not save the approved proposal.")
		return
	# Snapshot the approved design before launching any generation attempt. The
	# Python worker retains the authoritative paid reservation in its global ledger.
	if not bridge.freeze_generation_proposal(job_path, proposal):
		_notice("Could not retain the approved design. No request was sent.")
		return
	_start("generate")


func _proposal() -> Dictionary:
	var colours: Array[String] = []
	var regex := RegEx.new()
	regex.compile("^#[0-9a-fA-F]{6}$")
	for raw: String in _palette.text.split(","):
		var colour := raw.strip_edges()
		if regex.search(colour) == null:
			_notice("Enter 4–8 palette colours as #RRGGBB, separated by commas.")
			return {}
		colours.append(colour)
	if colours.size() < 4 or colours.size() > 8 or not _valid_text(_name.text.strip_edges(), 40) or not _valid_text(_theme_name.text.strip_edges(), 60) or not _valid_text(_motif.text.strip_edges(), 400):
		_notice("Use a name up to 40 characters, a theme up to 60, a motif up to 400, and 4–8 palette colours.")
		return {}
	if _features.size() > 12 or not _features.all(func(feature: String) -> bool: return _valid_text(feature, 160)):
		_notice("A proposal can retain up to 12 visual features, each up to 160 characters.")
		return {}
	return {"name": _name.text.strip_edges(), "rig_id": Library.RIGS[_rig.selected], "kit_id": Library.KITS[_kit.selected], "theme": {"name": _theme_name.text.strip_edges(), "palette": colours, "motif": _motif.text.strip_edges()}, "features": _features.duplicate()}


func _new_job() -> bool:
	if _busy:
		return false
	var preferred_name := _name.text.strip_edges()
	if preferred_name == "My fighter":
		preferred_name = ""
	var created := bridge.create_job(_canvas.pixels, _description.text, preferred_name)
	if not created["ok"]:
		_notice(created["error"])
		return false
	job_path = created["path"]
	_job_source_hash = FileAccess.get_sha256(job_path.get_base_dir().path_join("source.png"))
	if not _import_bytes.is_empty():
		var retained := FileAccess.open(job_path.get_base_dir().path_join("source_original." + _import_extension), FileAccess.WRITE)
		if retained == null:
			_notice("Could not retain the original imported image. No request was sent.")
			return false
		retained.store_buffer(_import_bytes)
		retained.flush()
		if retained.get_error() != OK:
			_notice("Could not retain the original imported image. No request was sent.")
			return false
	# Keep the previous validated preview and edits until a new valid bundle arrives.
	# Its parts remain tied to _preview_job_path, never written into this new job.
	return true


func _start(command: String) -> void:
	var result := bridge.start(command, job_path)
	if not result["ok"]:
		_notice(result["error"])
		return
	_operation = command
	_layout_context = {}
	_busy = true
	state = "queued"
	_started_msec = Time.get_ticks_msec()
	_last_status = ""
	_notice("%s… You can cancel later work; any in-flight request may still finish." % command.capitalize())
	_update_controls()


func _process(delta: float) -> void:
	if not _busy:
		return
	_poll_elapsed += delta
	if _poll_elapsed < 0.3:
		return
	_poll_elapsed = 0.0
	var report := bridge.status(job_path)
	if not report.is_empty():
		_handle_status(report)
	if _busy and Time.get_ticks_msec() - _started_msec > 1500 and not OS.is_process_running(bridge.pid):
		_busy = false
		state = "failed"
		_notice("The authoring worker stopped without a finished result. Your drawing and accepted fighters are preserved.")
		_offer_layout_correction()
		_update_controls()


func _handle_status(report: Dictionary) -> void:
	var serial := JSON.stringify(report)
	if serial == _last_status:
		return
	_last_status = serial
	state = str(report.get("state", "failed"))
	_notice(str(report.get("message", state.capitalize())))
	_update_budget(report)
	_retry_allowed = bool(report.get("retry_allowed", false))
	# The legacy preflight message means no missing image was attempted. An
	# earlier analysis or verified cached image can still have a retained cost.
	_retry_allowed = _retry_allowed or (state == "failed" and str(report.get("message", "")) == "The remaining shared or job budget cannot cover all missing image requests. No image request or new reservation was made.")
	if state == "awaiting_approval":
		var proposal: Dictionary = report.get("proposal", {}) if report.get("proposal", {}) is Dictionary else {}
		if proposal.is_empty():
			proposal = bridge.read_json(job_path.get_base_dir().path_join("proposal.json"))
		var preferred_name: String = bridge.read_json(job_path).get("preferred_name", "")
		if not preferred_name.is_empty():
			proposal["name"] = preferred_name
		if _kit_chosen_by_player:
			proposal["kit_id"] = Library.KITS[_kit.selected]
		_apply_proposal(proposal)
		_apply_identity_kit()
		_busy = false
	elif state == "complete":
		_busy = false
		_preview_candidate(report.get("candidate_path", ""))
	elif state in ["failed", "cancelled"]:
		_busy = false
	if state == "failed":
		_offer_layout_correction()
	_update_controls()


func _refresh_configuration(show_notice: bool = true) -> void:
	if _busy:
		return
	var report := bridge.configuration()
	if not report.get("ok", false):
		if show_notice:
			_notice(str(report.get("error", "Local AI setup is unavailable.")))
		return
	var current := bridge.status(job_path) if not job_path.is_empty() else {}
	if current.get("budget") is Dictionary:
		for field: String in ["job_limit_usd", "job_reserved_usd", "job_remaining_usd", "required_usd"]:
			if current["budget"].has(field):
				report["budget"][field] = current["budget"][field]
	_update_budget(report)
	if show_notice:
		_notice("AI setup ready. No request was made." if report.get("key_present", false) else "Add OPENAI_API_KEY to " + str(report.get("configuration_file", "the local authoring .env")) + ". No request was made.")


func _update_budget(report: Dictionary) -> void:
	var budget: Variant = report.get("budget")
	if not budget is Dictionary or not budget.has("total_limit_usd"):
		return
	if budget.get("limits_enabled", true) == false:
		_cost.text = "No local dollar cap | recorded estimates $%.2f\nNext request estimate $%.2f; local edits free" % [float(budget.get("total_reserved_usd", 0)), float(budget.get("required_usd", 0))]
		return
	_cost.text = "Total $%.2f / $%.2f reserved | $%.2f left\nJob $%.2f / $%.2f left | Need $%.2f; local edits free" % [float(budget.get("total_reserved_usd", 0)), float(budget.get("total_limit_usd", 0)), float(budget.get("total_remaining_usd", 0)), float(budget.get("job_remaining_usd", 0)), float(budget.get("job_limit_usd", 0.5)), float(budget.get("required_usd", 0))]


func _offer_layout_correction() -> void:
	_layout_context = {}
	if job_path.is_empty() or not FileAccess.file_exists(job_path.get_base_dir().path_join("raw/parts.png")) or not FileAccess.file_exists(job_path.get_base_dir().path_join("raw/theme.png")):
		return
	var context := bridge.raw_layout_context(job_path)
	if not context["ok"]:
		_notice(_message.text + " " + context["error"])
		return
	_layout_context = context
	_layout_job_path = job_path
	_open_layout_editor(_message.text)


func _open_layout_editor(error_message: String = "") -> void:
	if _busy or _layout_context.is_empty() or job_path != _layout_job_path or is_instance_valid(_layout_editor):
		return
	# Mouse blocking alone does not stop Tab reaching hidden paid actions.
	_layout_focus.clear()
	for control: Control in find_children("*", "Control", true, false):
		_layout_focus[control] = control.focus_mode
		control.focus_mode = Control.FOCUS_NONE
	_layout_editor = LayoutEditor.new()
	_layout_editor.setup(_layout_context, _cost.text)
	_layout_editor.dismissed.connect(_close_layout_editor)
	_layout_editor.apply_requested.connect(_convert_layout)
	add_child(_layout_editor)
	if not error_message.is_empty():
		_layout_editor.notice.text = error_message + " Review the highlighted crops, then convert locally. No new image request is needed."
	_layout_editor.save_button.grab_focus()


func _close_layout_editor() -> void:
	if is_instance_valid(_layout_editor):
		_layout_editor.hide()
		_layout_editor.queue_free()
	_layout_editor = null
	for control: Variant in _layout_focus:
		if is_instance_valid(control):
			control.focus_mode = _layout_focus[control]
	_layout_focus.clear()
	if _repair.visible:
		_repair.grab_focus()


func _convert_layout(layout: Dictionary) -> void:
	if _busy or job_path != _layout_job_path:
		return
	var retained := bridge.read_json(job_path)
	var current := _proposal()
	if current.is_empty() or bridge.proposal_hash(current) != bridge.proposal_hash(retained.get("proposal", {})):
		_layout_editor.notice.text = "Restore the retained draft's approved settings before correcting its cached art. New designs need a separate generation."
		return
	var created := bridge.create_layout_job(job_path, layout)
	if not created["ok"]:
		_layout_editor.notice.text = created["error"]
		return
	job_path = created["path"]
	_job_source_hash = FileAccess.get_sha256(job_path.get_base_dir().path_join("source.png"))
	_start("bake")
	if _busy:
		_close_layout_editor()
		_notice("Converting cached crops locally in a new draft. Earlier masks/pivots remain in the old draft; the new candidate starts with fresh joints and masks.")
	else:
		_layout_job_path = job_path
		_layout_editor.notice.text = _message.text


func _apply_proposal(proposal: Dictionary) -> void:
	_applying_proposal = true
	_features.clear()
	if proposal.get("features") is Array:
		for feature: Variant in proposal["features"]:
			if feature is String and _features.size() < 12 and _valid_text(feature, 160):
				_features.append(feature)
	_name.text = str(proposal.get("name", _name.text)).left(40)
	var rig_index := Library.RIGS.find(proposal.get("rig_id"))
	var kit_index := Library.KITS.find(proposal.get("kit_id"))
	if rig_index >= 0:
		_rig.select(rig_index)
	if kit_index >= 0:
		_kit.select(kit_index)
	var theme: Variant = proposal.get("theme", {})
	if theme is Dictionary:
		_theme_name.text = str(theme.get("name", _theme_name.text)).left(60)
		_motif.text = str(theme.get("motif", _motif.text)).left(400)
		if theme.get("palette") is Array:
			_palette.text = ",".join(theme["palette"])
	_applying_proposal = false


func _identity_edited() -> void:
	if _applying_proposal or _busy:
		return
	_apply_identity_kit()
	_proposal_edited()


func _apply_identity_kit() -> void:
	if _kit_chosen_by_player:
		return
	# A named weapon is stronger evidence than an uncertain sketch or theme.
	# The player can explicitly override this suggestion in the ability dropdown.
	for text: String in [_name.text, _description.text]:
		var intent := _identity_kit(text)
		if not intent.is_empty():
			_kit.select(Library.KITS.find(intent))
			return


func _identity_kit(text: String) -> String:
	var rules := {
		"stone": "sword|swordsman|swordswoman|swordsmen|knight|warrior|samurai|katana|blade|duelist|saber|sabre|greatsword|longsword|broadsword|axe|axeman|hammer|paladin|spear|spearman|lancer|shield",
		"shadow": "dagger|rogue|assassin|ninja|scythe|reaper",
		"storm": "brawler|boxer|monk|fist|punch",
		"frost": "archer|bow|bowman|crossbow|gunner|gun|rifle|sniper|wizard|mage|sorcerer|witch",
		"nature": "druid|thorn|thorns|plant|vine|vines|dryad|healer",
	}
	for kit: String in rules:
		var words := RegEx.new()
		words.compile("(?i)\\b(" + rules[kit] + ")\\b")
		if words.search(text) != null:
			return kit
	return ""


func _preview_candidate(reported_path: Variant = "") -> void:
	# Only immediate, fixed-name candidate directories in this trusted local job.
	var path := bridge.candidate_path(job_path, reported_path)
	if path.is_empty():
		state = "failed"
		_notice("Worker reported a candidate outside this job. Previous preview is preserved.")
		return
	var checked := library.load_bundle(path.path_join("manifest.json"))
	if not checked["ok"]:
		state = "failed"
		_notice("Candidate rejected; previous preview is preserved: " + checked["error"])
		return
	candidate = checked["bundle"]
	_preview_job_path = job_path
	_background.texture = candidate["background"]
	_portrait.texture = candidate["portrait"]
	_animation_tick = 0
	_last_preview_frame = -1
	_edit_dirty = false
	_load_parts()
	# Candidate metadata is the accepted truth, including after reopening a draft.
	_apply_proposal({"name": candidate["name"], "rig_id": candidate["rig_id"], "kit_id": candidate["kit_id"], "theme": candidate["theme"], "features": _features.duplicate()})
	_notice("Conversion complete. Review every animation, then Accept fighter & play to save it in Your fighters.")


func resume_job(path: String) -> void:
	if _busy or not bridge.trusted_job(path):
		return
	job_path = path
	var job := bridge.read_json(path)
	_operation = "generate" if job.has("proposal") else "analyse"
	var source_path := path.get_base_dir().path_join("source.png")
	if FileAccess.file_exists(source_path):
		import_source(source_path)
	_job_source_hash = FileAccess.get_sha256(source_path)
	_description.text = str(job.get("description", "")).left(2000)
	_apply_proposal(job.get("proposal", {}) if job.get("proposal") is Dictionary else bridge.read_json(path.get_base_dir().path_join("proposal.json")))
	_tabs.current_tab = 1
	_last_status = ""
	_handle_status(bridge.status(path))


func _load_parts() -> void:
	_part.clear()
	_part_records.clear()
	_mask_data.clear()
	_joint_data.clear()
	_selected_part = ""
	var folder := job_path.get_base_dir()
	var rig := bridge.read_json(folder.path_join("rig.json"))
	if rig.get("schema_version") != 1 or rig.get("rig_id") not in PART_IDS or rig.get("rig_id") != candidate.get("rig_id") or not rig.get("parts") is Array:
		return
	var edits := bridge.read_json(folder.path_join("rig_edits.json"))
	var overrides: Dictionary = edits.get("parts", {}) if edits.get("parts") is Dictionary else {}
	for raw: Variant in rig["parts"]:
		if not raw is Dictionary or raw.get("id") not in PART_IDS[rig["rig_id"]]:
			continue
		var id: String = raw["id"]
		if raw.get("file") != "parts/" + id + ".png" or not _valid_joint(raw.get("pivot")):
			continue
		var image := _part_image(folder.path_join(raw["file"]))
		if image == null or _mask_data.has(id):
			continue
		var mask := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		mask.fill(Color.WHITE)
		var joint := Vector2(raw["pivot"][0], raw["pivot"][1])
		var override: Dictionary = overrides.get(id, {}) if overrides.get(id) is Dictionary else {}
		if override.get("mask_file") == "masks/" + id + ".png":
			var retained := _part_image(folder.path_join(override["mask_file"]))
			if retained != null:
				mask = retained
		if _valid_joint(override.get("pivot")):
			joint = Vector2(override["pivot"][0], override["pivot"][1])
		_mask_data[id] = mask
		_joint_data[id] = joint
		_part_records.append({"id": id, "image": image})
		_part.add_item(id.replace("_", " ").capitalize())
	if not _part_records.is_empty():
		_select_part(0)


func _part_image(path: String) -> Image:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1024 * 1024:
		return null
	var bytes := file.get_buffer(file.get_length())
	if _source_dimensions(bytes) != Vector2i(64, 64):
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


func _valid_joint(value: Variant) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for coordinate: Variant in value:
		if typeof(coordinate) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(coordinate)) or coordinate < 0 or coordinate > 63:
			return false
	return true


func _select_part(index: int) -> void:
	if index < 0 or index >= _part_records.size():
		return
	_loading_part = true
	_selected_part = _part_records[index]["id"]
	var joint: Vector2 = _joint_data[_selected_part]
	_mask_canvas.set_mask(_part_records[index]["image"], _mask_data[_selected_part], joint)
	_pivot_x.value = joint.x
	_pivot_y.value = joint.y
	_loading_part = false


func _mask_changed() -> void:
	if _selected_part.is_empty() or _loading_part:
		return
	_mask_data[_selected_part] = _mask_canvas.pixels.duplicate()
	_edit_dirty = true
	_update_controls()


func _pivot_changed(value: Vector2) -> void:
	if _selected_part.is_empty() or _loading_part:
		return
	_joint_data[_selected_part] = value
	_loading_part = true
	_pivot_x.value = value.x
	_pivot_y.value = value.y
	_loading_part = false
	_edit_dirty = true
	_update_controls()


func _numeric_pivot(_value: float) -> void:
	if _loading_part or _selected_part.is_empty():
		return
	var joint := Vector2(_pivot_x.value, _pivot_y.value)
	_mask_canvas.pivot = joint
	_mask_canvas.queue_redraw()
	_pivot_changed(joint)


func bake_edits() -> void:
	if _busy or job_path.is_empty() or job_path != _preview_job_path or _part_records.is_empty():
		return
	var folder := job_path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(folder.path_join("masks")) != OK:
		_notice("Could not retain edited masks.")
		return
	var parts: Dictionary = {}
	for id: String in _mask_data:
		var mask: Image = _mask_data[id]
		if mask.save_png(folder.path_join("masks/" + id + ".png")) != OK:
			_notice("Could not save a mask correction.")
			return
		var joint: Vector2 = _joint_data[id]
		parts[id] = {"pivot": [int(joint.x), int(joint.y)], "mask_file": "masks/" + id + ".png"}
	if not bridge.write_json(folder.path_join("rig_edits.json"), {"schema_version": 1, "parts": parts}):
		_notice("Could not save joint corrections.")
		return
	_start("bake")


func accept_preview() -> void:
	if _busy or candidate.is_empty() or _edit_dirty or not _matches_preview():
		return
	var result := library.accept_candidate(candidate["manifest_path"])
	if not result["ok"]:
		_notice(result["error"])
		return
	completed.emit(result["bundle"])


func _cancel_request() -> void:
	if bridge.cancel(job_path):
		_notice("Cancellation requested. Any in-flight request may still be billed; no later request should start.")
		_cancel_job.disabled = true


func _retry_job() -> void:
	if _busy:
		return
	if _retry_allowed and not job_path.is_empty():
		if _operation == "analyse":
			_start("analyse")
		else:
			generate_candidate()
		return
	job_path = ""
	if _operation == "analyse":
		analyse_source()
	else:
		generate_candidate()


func _leave() -> void:
	if _busy:
		bridge.cancel(job_path)
	cancelled.emit()


func _update_controls() -> void:
	if _analyse == null:
		return
	_analyse.disabled = _busy
	_setup_check.disabled = _busy
	_generate.disabled = _busy
	_cancel_job.disabled = not _busy
	_retry.disabled = _busy or state not in ["failed", "cancelled"]
	_retry.text = "Resume blocked job" if _retry_allowed else "New attempt"
	_repair.visible = not _busy and not _layout_context.is_empty() and job_path == _layout_job_path
	_accept.disabled = _busy or candidate.is_empty() or _edit_dirty or not _matches_preview()
	var can_edit_parts := not _busy and not _part_records.is_empty() and job_path == _preview_job_path
	_bake.disabled = not can_edit_parts or not _edit_dirty
	for field: LineEdit in [_name, _theme_name, _palette, _motif]:
		field.editable = not _busy
	_rig.disabled = _busy
	_kit.disabled = _busy
	_part.disabled = not can_edit_parts
	_pivot_x.editable = can_edit_parts
	_pivot_y.editable = can_edit_parts
	_mask_canvas.mouse_filter = Control.MOUSE_FILTER_STOP if can_edit_parts else Control.MOUSE_FILTER_IGNORE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE if _busy else Control.MOUSE_FILTER_STOP
	_description.editable = not _busy
	for button: BaseButton in _source_controls:
		button.disabled = _busy


func _proposal_edited() -> void:
	if not candidate.is_empty() and not _matches_preview():
		_notice("Settings changed. Generate an updated candidate before accepting; the previous preview is retained.")
	_update_controls()


func _matches_preview() -> bool:
	if candidate.is_empty():
		return false
	return _name.text.strip_edges() == candidate.get("name") and Library.RIGS[_rig.selected] == candidate.get("rig_id") and Library.KITS[_kit.selected] == candidate.get("kit_id") and _theme_name.text.strip_edges() == candidate.get("theme", {}).get("name") and _motif.text.strip_edges() == candidate.get("theme", {}).get("motif") and _palette.text.replace(" ", "") == ",".join(candidate.get("theme", {}).get("palette", []))


func _drawing_hash() -> String:
	if _canvas.pixels == null:
		return ""
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(_canvas.pixels.save_png_to_buffer())
	return digest.finish().hex_encode()


func _valid_text(value: String, limit: int) -> bool:
	if value.strip_edges().is_empty() or value.length() > limit:
		return false
	for index in value.length():
		if value.unicode_at(index) < 32:
			return false
	return true


func _physics_process(_delta: float) -> void:
	if candidate.is_empty() or _sprite == null:
		return
	_animation_tick += 1
	var clip_name: String = CLIPS.keys()[_clip.selected]
	var clip_data: Array = CLIPS[clip_name]
	var frame := int(clip_data[0]) + (_animation_tick / (8 if clip_name == "idle" else 5)) % int(clip_data[1])
	if frame == _last_preview_frame:
		return
	_last_preview_frame = frame
	var texture := AtlasTexture.new()
	texture.atlas = candidate["atlas"]
	texture.region = Rect2((frame % 8) * 68 + 2, (frame / 8) * 68 + 2, 64, 64)
	_sprite.texture = texture


func _notice(message: String) -> void:
	if _message != null:
		_message.text = message.left(1000)


func _field(parent: VBoxContainer, caption: String, initial: String, limit: int) -> LineEdit:
	parent.add_child(_label(caption, 18))
	var field := LineEdit.new()
	field.text = initial
	field.max_length = limit
	field.custom_minimum_size.y = 42
	parent.add_child(field)
	return field


func _options(values: Array) -> OptionButton:
	var choice := OptionButton.new()
	choice.custom_minimum_size.y = 42
	for value: Variant in values:
		choice.add_item(str(value).capitalize())
	return choice


func _label(text: String, font_size: int = 20, colour: Color = Color("#e8e1c9")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(action)
	return button


func _texture_rect() -> TextureRect:
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect


func _apply_theme() -> void:
	var theme := Theme.new()
	theme.default_font_size = 20
	for type: String in ["Button", "OptionButton", "LineEdit", "TextEdit", "SpinBox", "TabContainer"]:
		theme.set_color("font_color", type, Color("#e8e1c9"))
	for variant: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#2b4b58") if variant in ["hover", "pressed"] else Color("#20333f")
		style.set_corner_radius_all(6)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		if variant == "focus":
			style.draw_center = false
			style.border_color = Color("#e4a85b")
			style.set_border_width_all(2)
		for type: String in ["Button", "OptionButton", "LineEdit"]:
			theme.set_stylebox(variant, type, style)
	self.theme = theme


func _source_dimensions(bytes: PackedByteArray) -> Vector2i:
	if bytes.size() >= 33 and bytes.slice(0, 8) == PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		var width := 0
		var height := 0
		for index in 4:
			width = (width << 8) | bytes[16 + index]
			height = (height << 8) | bytes[20 + index]
		return Vector2i(width, height)
	if bytes.size() < 4 or bytes[0] != 255 or bytes[1] != 216:
		return Vector2i.ZERO
	var offset := 2
	while offset + 4 <= bytes.size():
		if bytes[offset] != 255:
			return Vector2i.ZERO
		var marker := int(bytes[offset + 1])
		if marker == 255:
			offset += 1
			continue
		if marker in [216, 217, 1] or marker in range(208, 216):
			offset += 2
			continue
		var length := int(bytes[offset + 2]) * 256 + int(bytes[offset + 3])
		if length < 2 or offset + 2 + length > bytes.size():
			return Vector2i.ZERO
		if marker in [192, 193, 194, 195, 197, 198, 199, 201, 202, 203, 205, 206, 207] and length >= 7:
			return Vector2i(int(bytes[offset + 7]) * 256 + int(bytes[offset + 8]), int(bytes[offset + 5]) * 256 + int(bytes[offset + 6]))
		offset += length + 2
	return Vector2i.ZERO
