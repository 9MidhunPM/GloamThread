extends Node
## Isolated UI fixture, not application flow or gameplay acceptance.
## Launch explicitly: godot --path . scenes/ui/menu_preview.tscn -- --menu settings

const MenuScript := preload("res://scripts/ui/game_menus.gd")
const KINDS: Array[String] = ["title", "join", "pause", "map", "dialogue", "settings", "controls", "reconnect", "ending"]

class LongPromptBindings:
	extends Bindings
	# Synthetic label lengths, never saved or claimed as physical key names.
	func prompt_label(action: int) -> String:
		return "PhysicalKey-" + CommandSnapshot.action_name(action as CommandSnapshot.Action).capitalize()

var _menus: MenuScript
var _kind: String = "title"
var _capture_directory: String = ""
var _music: int = 70
var _effects: int = 80
var _reduced_flash: bool = false
var _long_prompts: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().title = "Gloamthread menu preview"
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.assign(1, DeviceSource.keyboard_right())
	for index in 2:
		InputRouter.clear_test_input(index)
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--menu" and index + 1 < args.size():
			_kind = args[index + 1]
		if args[index] == "--capture-dir" and index + 1 < args.size():
			_capture_directory = args[index + 1]
		if args[index] == "--long-prompts":
			_long_prompts = true
	if _long_prompts:
		var bindings := LongPromptBindings.new()
		bindings.kind = DeviceSource.Kind.KEYBOARD_LEFT
		bindings.controls = Bindings.defaults_for(bindings.kind).controls.duplicate(true)
		InputRouter.set_bindings(0, bindings)
	if _kind not in KINDS:
		push_error("Unknown UI fixture kind: %s" % _kind)
		get_tree().quit(1)
		return
	_menus = MenuScript.new()
	add_child(_menus)
	_menus.set_font(load("res://assets/generated/font/weft_5x7.fnt") as Font)
	_menus.action_requested.connect(_on_action)
	_show_kind(_kind)
	if not _capture_directory.is_empty():
		_capture_all.call_deferred()


func _row(id: String, label: String, detail: String = "", enabled: bool = true, adjustable: bool = false) -> Dictionary:
	return {"id": id, "label": label, "detail": detail, "enabled": enabled, "adjustable": adjustable}


func _show_kind(kind: String) -> void:
	_kind = kind
	var title := ""
	var body := ""
	var rows: Array[Dictionary] = []
	match kind:
		"title":
			title = "GLOAMTHREAD: TWO ENDS"
			body = "Two couriers. One unraveling kingdom. Two ways of seeing it."
			rows = [_row("join", "Begin together", "Choose Tavi and Neri, then claim a separate input source."),
				_row("continue", "Continue", "No campaign is loaded in this isolated UI fixture.", false),
				_row("settings", "Settings"), _row("quit", "Quit preview")]
		"join":
			title = "TWO ENDS, ONE THREAD"
			body = "P1 TAVI / EMBER: 5 hearts, Ember Arc.\nP2 NERI / MOSS: 4 hearts, Spore Bolt.\nEach courier needs a different input source."
			rows = [_row("p1_source", "P1 source: keyboard left", "WASD movement; the footer follows your actual bindings."),
				_row("p2_source", "P2 source: keyboard right", "Arrow movement; physical key rollover still needs real-player review."),
				_row("start", "Both ready - start", "Fixture readiness only; application owns actual join validation."),
				_row("title", "Back to title")]
		"pause":
			title = "A MOMENT TO MEND"
			body = "The application owns shared pause. This renderer only requests an action."
			rows = [_row("resume", "Resume"), _row("map", "Map"), _row("settings", "Settings"), _row("title", "Return to title")]
		"map":
			title = "THE WEFTLANDS"
			body = "Rest -> Atrium -> Steps -> Gallery -> Landing -> Broken Bell\nAfter the Warden: Atrium -> Causeway -> Lantern Loom."
			rows = [_row("r00", "r00  Lantern Rest", "Checkpoint A / Oru / the dark road home"),
				_row("r01", "r01  Mossfoot Atrium", "Remember the severed causeway branch"),
				_row("r02", "r02  Spindle Steps", "Two anchors restore one shared bridge"),
				_row("r03", "r03  Glasswing Gallery", "Enemy lessons and an optional lantern charm"),
				_row("r04", "r04  Warden's Landing", "Checkpoint B"), _row("r05", "r05  Broken Bell", "Spoolwarden / shared Threadstep"),
				_row("r06", "r06  Severed Causeway", "Threadstep route / the second anchor pair"), _row("r07", "r07  Lantern Loom", "Restore the road home")]
		"dialogue":
			title = "ORU / 1 OF 3"
			body = "The far district is still there. The way home isn't.\n\nRestore the Lantern Loom. Follow the path through the Atrium."
			rows = [_row("next", "Next line"), _row("skip", "Skip dialogue")]
		"settings":
			title = "SETTINGS"
			body = "Values here are preview memory only. The application owns validation and storage."
			rows = [_row("music", "Music volume", "%d%%" % _music, true, true),
				_row("effects", "Effects volume", "%d%%" % _effects, true, true),
				_row("flashes", "Reduced flashes", "On" if _reduced_flash else "Off", true, true),
				_row("controls", "Controls / remapping"), _row("pause", "Back")]
		"controls":
			title = "P1 CONTROLS"
			body = "The application performs capture and conflict checks. These rows request a binding action."
			for action: CommandSnapshot.Action in CommandSnapshot.ALL_ACTIONS:
				rows.append(_row("bind_" + CommandSnapshot.action_name(action), CommandSnapshot.action_name(action).capitalize(),
					InputRouter.bindings_of(0).prompt_label(action)))
			rows.append(_row("settings", "Back to settings"))
		"reconnect":
			title = "KEEP THE OTHER END CLOSE"
			body = "P2's assigned controller is unavailable. The application keeps the shared world paused while a source is reassigned."
			rows = [_row("reassign", "Choose another source", "The application supplies compatible, unclaimed sources."),
				_row("resume", "Resume together", "Unavailable until the application confirms both owners.", false),
				_row("title", "Return to title")]
		"ending":
			title = "THE ROAD HOME"
			body = "The Lantern Loom is lit. Two threads. Still two colours.\nStrong enough together.\n\nThis is the ending UI fixture, not evidence of a completed campaign."
			rows = [_row("resume", "Continue exploring"), _row("new_game", "New game", "The application must confirm before resetting campaign progress."),
				_row("title", "Return to title")]
	_menus.show_menu(kind, title + (" / LONG PROMPTS" if _long_prompts else ""), body, rows, 0)
	print("UI_PREVIEW_KIND %s" % kind)
	_log_layout.call_deferred(kind, rows)


func _log_layout(kind: String, rows: Array[Dictionary]) -> void:
	for _index in 3:
		await get_tree().process_frame
	if kind != _kind:
		return
	var container := _menus.get_node("MenuRoot/Scroll/Content/Rows")
	var rectangles: Array[Dictionary] = []
	for index in mini(rows.size(), container.get_child_count()):
		var control := container.get_child(index) as Control
		var rect := control.get_global_rect()
		rectangles.append({"id": rows[index]["id"], "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
	var footer := _menus.get_node("MenuRoot/Footer") as Label
	print("UI_PREVIEW_LAYOUT %s" % JSON.stringify({"kind": kind, "rows": rectangles, "footer_lines": footer.get_line_count()}))


func _on_action(action: String, payload: Variant) -> void:
	print("UI_PREVIEW_ACTION %s" % JSON.stringify({"action": action, "payload": payload}))
	if payload is Dictionary and payload.has("direction"):
		var direction := int(payload["direction"])
		if action == "music":
			_music = clampi(_music + direction * 5, 0, 100)
		elif action == "effects":
			_effects = clampi(_effects + direction * 5, 0, 100)
		elif action == "flashes":
			_reduced_flash = not _reduced_flash
		_show_kind(_kind)
		return
	if action in KINDS:
		_show_kind(action)
	elif action == "cancel":
		_show_kind("title" if _kind == "pause" else "pause")
	elif action == "quit":
		get_tree().quit()


func _capture_all() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native UI captures require a rendering display, not the headless dummy driver")
		get_tree().quit(1)
		return
	var initial_kind := _kind
	if DirAccess.make_dir_recursive_absolute(_capture_directory) != OK:
		push_error("Cannot create UI capture directory")
		get_tree().quit(1)
		return
	for kind: String in KINDS:
		_show_kind(kind)
		for _index in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := _capture_directory.path_join(kind + ".png")
		if image == null or image.is_empty() or image.save_png(path) != OK:
			push_error("UI native capture failed: %s" % path)
			get_tree().quit(1)
			return
		print("UI_RENDER_CAPTURE %s" % JSON.stringify({"kind": kind, "path": path, "width": image.get_width(), "height": image.get_height(), "driver": DisplayServer.get_name()}))
	_show_kind(initial_kind)
