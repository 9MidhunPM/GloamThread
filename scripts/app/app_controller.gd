extends Control
## Owns global screens; campaign simulation remains entirely in GameSession.

const SESSION_SCENE := preload("res://scenes/session/session.tscn")
const Action := CommandSnapshot.Action
var catalog: ContentCatalog
var session: GameSession
var menus: CanvasLayer
var saves := SaveRepository.new()
var settings_store := SettingsRepository.new()
var settings: Dictionary = {}
var screen: String = "title"
var _fatal: bool = false
var menu_owner: int = 0
var _join_continue: bool = false
var _swap_characters: bool = false
var _dialogue_line: int = 0
var _remap_slot: int = -1
var _remap_action: int = 0
var _toast: Label
var _toast_back: ColorRect
var _toast_ticks: int = 0
var _notices: Array[String] = []
var _reconnect_return: String = "title"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The original campaign owns two480x360 views; the arena restores its own
	# logical size on entry. Window/fullscreen preferences and saves stay intact.
	get_window().content_scale_size = Vector2i(960, 360)
	BrowserRuntime.set_mode("story")
	DisplayServer.window_set_title("Gloamthread - Story Mode")
	get_tree().auto_accept_quit = false
	process_physics_priority = 200
	var loaded := settings_store.load_settings()
	settings = loaded.settings
	_assign_initial_sources()
	if catalog == null:
		catalog = ContentCatalog.load_bundle()
	if not catalog.errors.is_empty():
		_show_fatal("Required game data could not load.\n" + "\n".join(catalog.errors))
		return
	var menu_script: GDScript = load("res://scripts/ui/game_menus.gd") as GDScript
	if menu_script == null or not menu_script.can_instantiate():
		_show_fatal("Menu data is missing. Please install a complete build.")
		return
	menus = menu_script.new() as CanvasLayer
	add_child(menus)
	menus.set_font(catalog.assets.font())
	menus.action_requested.connect(_on_action)
	_toast = Label.new()
	_toast.position = Vector2(16, 301)
	_toast.size = Vector2(928, 40)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_font_override("font", catalog.assets.font())
	_toast.add_theme_font_size_override("font_size", 8)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var toast_layer := CanvasLayer.new()
	toast_layer.layer = 30
	_toast_back = ColorRect.new()
	_toast_back.position = Vector2(12, 297)
	_toast_back.size = Vector2(936, 44)
	_toast_back.color = Color(0.04, 0.06, 0.09, 0.96)
	_toast_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_back.visible = false
	toast_layer.add_child(_toast_back)
	toast_layer.add_child(_toast)
	add_child(toast_layer)
	AudioDirector.register_bundle(catalog.assets)
	_apply_settings()
	InputRouter.device_lost.connect(_device_lost)
	InputRouter.device_returned.connect(_device_returned)
	InputRouter.joypad_list_changed.connect(_device_list_changed)
	_show_title()
	if not str(loaded.message).is_empty():
		_notify(str(loaded.message))


func _assign_initial_sources() -> void:
	for index in 2:
		InputRouter.clear(index)
	for index in 2:
		var identity: Dictionary = settings.sources[index]
		var source := DeviceSource.keyboard_left() if index == 0 else DeviceSource.keyboard_right()
		if identity.kind == "GAMEPAD":
			for device: int in Input.get_connected_joypads():
				if Input.get_joy_guid(device) == identity.guid and Input.get_joy_name(device) == identity.name:
					var candidate := DeviceSource.gamepad(device)
					var other := InputRouter.source_of(1 - index)
					if other == null or not other.conflicts_with(candidate):
						source = candidate
						break
		elif identity.kind == "KEYBOARD_LEFT":
			source = DeviceSource.keyboard_left()
		elif identity.kind == "KEYBOARD_RIGHT":
			source = DeviceSource.keyboard_right()
		var bindings := Bindings.from_dict(settings.player_bindings[index])
		if bindings.kind != source.kind:
			bindings = Bindings.defaults_for(source.kind)
		if InputRouter.assign(index, source, bindings) != OK:
			for fallback in InputRouter.available_sources(index):
				if fallback.is_keyboard() and InputRouter.assign(index, fallback) == OK:
					break


func _physics_process(_delta: float) -> void:
	if _toast_ticks > 0:
		_toast_ticks -= 1
		if _toast_ticks == 0 and is_instance_valid(_toast):
			_toast.text = ""
			_toast_back.visible = false
			if not _notices.is_empty():
				_notify(_notices.pop_front())


func _row(id: String, label: String, detail: String = "", enabled: bool = true, adjustable: bool = false) -> Dictionary:
	return {"id": id, "label": label, "detail": detail, "enabled": enabled, "adjustable": adjustable}


func _show(kind: String, title: String, body: String, rows: Array[Dictionary]) -> void:
	screen = kind
	menus.show_menu(kind, title, body, rows, menu_owner)


func _show_title(discard_unsaved: bool = false) -> void:
	if is_instance_valid(session):
		if not discard_unsaved:
			session.save_now()
			if not session.last_save_error.is_empty():
				session.request_mode("pause", menu_owner)
				_show("unsaved_title", "This thread has not been saved", session.last_save_error + "\nRetry, or explicitly discard progress since the last successful save.", [_row("retry_title", "Retry save and return"), _row("discard_title", "Discard unsaved progress and return"), _row("cancel", "Keep this journey open")])
				return
		session.free()
	get_tree().paused = false
	var saved := saves.load_campaign()
	var can_continue: bool = saved.status == "ok" or saved.status == "backup_available"
	_show("title", "Gloamthread: Story Mode", "Two couriers. Two views. One road home.\nA local adventure for two players.", [
		_row("new", "New journey"), _row("continue", "Continue", str(saved.message), can_continue),
		_row("settings", "Settings and controls"), _row("arena", "Back to arena"), _row("quit", "Browser home" if OS.has_feature("web") else "Quit")])
	AudioDirector.play_music("exploration")


func _show_join() -> void:
	if _join_continue:
		var loaded := saves.load_campaign()
		if loaded.status == "ok":
			_swap_characters = loaded.data.profile_ids[0] == "neri_fixed"
	var rows: Array[Dictionary] = []
	for index in 2:
		var source := InputRouter.source_of(index)
		rows.append(_row("source_%d" % index, "Player %d: %s" % [index + 1, source.display_name() if source != null else "Choose input"], "Confirm or Left/Right to change", true, true))
	rows.append(_row("swap", "Characters: %s" % ("P1 Neri / P2 Tavi" if _swap_characters else "P1 Tavi / P2 Neri"), "Saved character assignment" if _join_continue else "Different colours, one shared world", not _join_continue))
	rows.append(_row("start", "Continue journey" if _join_continue else "Begin journey", "Both players need distinct inputs", _devices_ready()))
	rows.append(_row("back", "Back"))
	_show("join", "Take an end", "Keyboard sharing: simultaneous keys depend on your keyboard's rollover.\nP1 WASD: Space jump, F slash, G special, E interact, Shift dash.\nP2 arrows: Period jump, Comma slash, Slash special, M interact, Apostrophe dash.\nTwo gamepads or keyboard + gamepad are also selectable.", rows)


func _devices_ready() -> bool:
	return InputRouter.is_joined(0) and InputRouter.is_joined(1) and not InputRouter.is_waiting_for_device(0) and not InputRouter.is_waiting_for_device(1)


func _cycle_source(index: int, direction: int = 1) -> void:
	var choices := InputRouter.available_sources(index)
	if choices.is_empty():
		return
	var current := InputRouter.source_of(index)
	var selected := -1
	for at in choices.size():
		if current != null and current.conflicts_with(choices[at]):
			selected = at
	var chosen := choices[posmod(selected + direction, choices.size())]
	InputRouter.assign(index, chosen)
	_persist_settings()


func _begin_campaign() -> void:
	if not _devices_ready():
		return
	var progress := TeamProgress.new()
	var initial_save_error := ""
	if _join_continue:
		var loaded := saves.load_campaign()
		if loaded.status != "ok" or not progress.load_save(loaded.data):
			_notify("The campaign could not load safely.")
			_show_title()
			return
	else:
		if _swap_characters:
			progress.profile_ids = ["neri_fixed", "tavi_fixed"]
		var written := saves.save_campaign(progress.to_save(), true)
		if not written.ok:
			initial_save_error = str(written.message)
			_notify(initial_save_error)
	if is_instance_valid(session):
		session.free()
	session = SESSION_SCENE.instantiate() as GameSession
	session.configure(catalog, progress, saves, _join_continue)
	session.last_save_error = initial_save_error
	session.reduced_flash = settings.reduced_flash
	session.reduced_shake = settings.reduced_shake
	session.mode_changed.connect(_session_mode)
	session.notice.connect(_notify)
	add_child(session)
	if not session.session_ready:
		var error := session.startup_error
		session.free()
		_show("error", "Journey could not start", error, [_row("back", "Back to title")])
		return
	_persist_settings()
	_session_mode("playing", 0)


func _session_mode(mode: String, owner: int) -> void:
	menu_owner = owner
	if mode == "playing":
		screen = "playing"
		menus.hide_menu()
	elif mode == "pause":
		_show_pause()
	elif mode == "map":
		_show_map()
	elif mode == "dialogue":
		_dialogue_line = 0
		_show_dialogue()
	elif mode == "reconnect":
		_show_reconnect()
	elif mode == "ending":
		_show("ending", "A road home", "The Lantern Loom answers. The district is together again.\nTwo threads. Still two colours. Strong enough together.", [
			_row("resume", "Keep exploring"), _row("replay", "New journey with characters swapped"), _row("title", "Return to title")])
	else:
		menus.hide_menu()


func _show_pause() -> void:
	_show("pause", "The thread is held", session.objective() + ("\nUnsaved: " + session.last_save_error if not session.last_save_error.is_empty() else ""), [_row("resume", "Resume"), _row("map", "Map"), _row("settings", "Settings and controls"), _row("save", "Save checkpoint progress"), _row("checkpoint", "Return together to checkpoint"), _row("title", "Return to title"), _row("arena", "Save and return to arena")])


func _show_map() -> void:
	var lines := PackedStringArray()
	for record: Dictionary in catalog.world.rooms:
		var room_id := str(record.id)
		var known := room_id in session.progress.explored_rooms
		lines.append(("> " if room_id == session.current_room_id else "  ") + (str(record.name) if known else "Unexplored"))
	lines.append("\n" + session.objective())
	lines.append("Checkpoint: " + session.progress.checkpoint_id.replace("_", " "))
	_show("map", "Threads of the district", "\n".join(lines), [_row("resume", "Return to journey")])


func _show_dialogue() -> void:
	var sequence := catalog.dialogue_sequence(session.dialogue_id)
	if _dialogue_line >= sequence.size():
		session.request_mode("playing", menu_owner)
		return
	var line: Dictionary = sequence[_dialogue_line]
	_show("dialogue", str(line.speaker) if not str(line.speaker).is_empty() else "Gloamthread", str(line.text), [_row("next", "Continue"), _row("skip", "Skip conversation")])


func _show_reconnect() -> void:
	var rows: Array[Dictionary] = []
	for index in 2:
		var source := InputRouter.source_of(index)
		rows.append(_row("source_%d" % index, "P%d: %s" % [index + 1, source.display_name() if source != null else "Unassigned"], "Disconnected" if InputRouter.is_waiting_for_device(index) else "Connected", true, true))
	rows.append(_row("resume" if is_instance_valid(session) else "finish_reconnect", "Resume together" if is_instance_valid(session) else "Return to menu", "Continue deliberately after reassignment", _devices_ready()))
	rows.append(_row("title", "Return to title"))
	_show("reconnect", "Hold the thread", "A controller disconnected. Reconnect it or choose a free input.\nThe world stays paused until Resume. A connected player owns this menu.\nIf both pads are lost, press Space to claim a free keyboard-left input. Mouse is also available.", rows)


func _show_settings() -> void:
	var rows: Array[Dictionary] = []
	for key: String in ["master_volume", "music_volume", "sfx_volume"]:
		rows.append(_row(key, key.replace("_", " ").capitalize() + ": %d%%" % roundi(float(settings[key]) * 100), "Left/Right or confirm", true, true))
	for key: String in ["reduced_flash", "reduced_shake"]:
		rows.append(_row(key, key.replace("_", " ").capitalize() + ": " + ("On" if settings[key] else "Off")))
	for index in 2:
		rows.append(_row("controls_%d" % index, "Player %d controls" % (index + 1)))
	rows.append(_row("back", "Back"))
	_show("settings", "Settings", "Changes are saved separately from campaign progress.", rows)


func _show_controls(index: int) -> void:
	var bindings := InputRouter.bindings_of(index)
	if bindings == null:
		_notify("Choose an input before editing controls.")
		_show_join()
		return
	var rows: Array[Dictionary] = []
	for action: int in CommandSnapshot.ALL_ACTIONS:
		rows.append(_row("bind_%d_%d" % [index, action], CommandSnapshot.action_name(action as Action).capitalize(), bindings.prompt_label(action)))
	if bindings.kind == DeviceSource.Kind.GAMEPAD:
		rows.append(_row("deadzone_%d" % index, "Stick deadzone: %d%%" % roundi(bindings.deadzone * 100), "Left/Right or confirm", true, true))
	rows.append(_row("defaults_%d" % index, "Restore this player's defaults"))
	rows.append(_row("back", "Back"))
	_show("controls_%d" % index, "Player %d controls" % (index + 1), "Select an action, then press a key/button on this player's input.\nEscape cancels capture. Duplicate controls are refused.", rows)


func _on_action(action: String, payload: Variant = null) -> void:
	var direction := int(payload.direction) if payload is Dictionary and payload.has("direction") else 1
	if action.begins_with("source_"):
		_cycle_source(int(action.get_slice("_", 1)), direction)
		_show_reconnect() if screen == "reconnect" else _show_join()
		return
	if action.begins_with("controls_"):
		_show_controls(int(action.get_slice("_", 1)))
		return
	if action.begins_with("deadzone_"):
		var index := int(action.get_slice("_", 1))
		var bindings := InputRouter.bindings_of(index)
		bindings.deadzone = clampf(bindings.deadzone + direction * 0.05, 0.05, 0.9)
		InputRouter.set_bindings(index, bindings)
		_persist_settings()
		_show_controls(index)
		return
	if action.begins_with("defaults_"):
		var index := int(action.get_slice("_", 1))
		InputRouter.set_bindings(index, Bindings.defaults_for(InputRouter.source_of(index).kind))
		_persist_settings()
		_show_controls(index)
		return
	if action.begins_with("bind_"):
		_remap_slot = int(action.get_slice("_", 1))
		_remap_action = int(action.get_slice("_", 2))
		_show("capture", "Choose a control", "Press a key/button on Player %d's input for %s.\nEscape cancels." % [_remap_slot + 1, CommandSnapshot.action_name(_remap_action as Action)], [_row("cancel", "Cancel")])
		return
	if action in ["master_volume", "music_volume", "sfx_volume"]:
		settings[action] = clampf(float(settings[action]) + direction * 0.1, 0, 1)
		_apply_settings()
		_persist_settings()
		_show_settings()
		return
	if action in ["reduced_flash", "reduced_shake"]:
		settings[action] = not settings[action]
		_apply_settings()
		_persist_settings()
		_show_settings()
		return
	match action:
		"arena": _return_to_arena()
		"quit", "retry_quit": _quit_requested()
		"discard_quit": _finish_quit()
		"retry_title": _show_title()
		"discard_title": _show_title(true)
		"finish_reconnect":
			if _devices_ready():
				if _reconnect_return == "join":
					_show_join()
				elif _reconnect_return == "settings" or _reconnect_return.begins_with("controls_") or _reconnect_return == "capture":
					_show_settings()
				else:
					_show_title()
		"new", "replay":
			_join_continue = false
			_swap_characters = action == "replay" and is_instance_valid(session) and session.progress.profile_ids[0] == "tavi_fixed"
			var existing := saves.load_campaign()
			if existing.status != "missing":
				_show("confirm_new", "Start a new journey?", "This replaces the current campaign. Settings are kept.\nAn unreadable save is preserved for manual recovery.", [_row("confirm_new", "Start new journey"), _row("back", "Back")])
			else:
				_show_join()
		"confirm_new": _show_join()
		"continue":
			var existing := saves.load_campaign()
			if existing.status == "backup_available":
				_show("backup", "A previous thread survives", str(existing.message), [_row("recover", "Recover last known good backup"), _row("back", "Back")])
			else:
				_join_continue = true
				_show_join()
		"recover":
			var result := saves.recover_backup()
			if result.ok:
				_join_continue = true
				_show_join()
			else:
				_notify(str(result.message))
		"swap":
			_swap_characters = not _swap_characters
			_show_join()
		"start": _begin_campaign()
		"resume":
			if is_instance_valid(session) and _devices_ready():
				session.request_mode("playing", menu_owner)
		"map": session.request_mode("map", menu_owner)
		"next":
			_dialogue_line += 1
			_show_dialogue()
		"skip": session.request_mode("playing", menu_owner)
		"settings":
			if is_instance_valid(session):
				session.request_mode("settings", menu_owner)
			_show_settings()
		"checkpoint":
			_show("confirm_recovery", "Return to the checkpoint?", "Both couriers heal. Encounters reset; permanent restorations remain.", [_row("recover_team", "Return together"), _row("cancel", "Keep exploring")])
		"recover_team": session.request_recovery("Returned together to the checkpoint.")
		"save":
			session.save_now()
		"title":
			AudioDirector.stop_cues()
			_show_title()
		"back", "cancel": _back()


func _return_to_arena() -> void:
	if is_instance_valid(session):
		# Reuse the campaign's existing save/error/discard flow before leaving.
		_show_title()
		if is_instance_valid(session):
			return
	get_tree().paused = false
	InputRouter.flush()
	AudioDirector.stop_cues()
	var error := get_tree().change_scene_to_file("res://scenes/arena/boot.tscn")
	if error != OK:
		_notify("Arena mode could not open. (%s)" % error_string(error))


func _back() -> void:
	if _remap_slot >= 0:
		var index := _remap_slot
		_remap_slot = -1
		InputRouter.flush()
		_show_controls(index)
	elif screen.begins_with("controls_"):
		_show_settings()
	elif screen == "settings":
		if is_instance_valid(session):
			session.request_mode("pause", menu_owner)
		else:
			_show_title()
	elif screen in ["unsaved_title", "unsaved_quit"]:
		session.request_mode("pause", menu_owner)
	elif screen == "confirm_recovery":
		session.request_mode("pause", menu_owner)
	elif screen == "reconnect":
		if _devices_ready():
			if is_instance_valid(session):
				session.request_mode("playing", menu_owner)
			else:
				_on_action("finish_reconnect")
	elif screen in ["pause", "map", "dialogue"]:
		if _devices_ready():
			session.request_mode("playing", menu_owner)
	else:
		_show_title()


func _input(event: InputEvent) -> void:
	if _fatal:
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			_quit_requested()
		return
	if screen == "reconnect" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		for index in 2:
			if not InputRouter.is_waiting_for_device(index):
				continue
			for candidate in InputRouter.available_sources(index):
				if candidate.kind == DeviceSource.Kind.KEYBOARD_LEFT:
					InputRouter.assign(index, candidate)
					menu_owner = index
					_persist_settings()
					_show_reconnect()
					get_viewport().set_input_as_handled()
					return
	if _remap_slot < 0:
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_back()
		get_viewport().set_input_as_handled()
		return
	var source := InputRouter.source_of(_remap_slot)
	var control: Variant = null
	if source.is_keyboard() and event is InputEventKey and event.pressed and not event.echo:
		control = int(event.physical_keycode)
	elif source.is_gamepad() and event.device == source.joy_id:
		if event is InputEventJoypadButton and event.pressed:
			control = {"button": int(event.button_index)}
		elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.65:
			control = {"axis": int(event.axis), "sign": 1 if event.axis_value > 0 else -1}
	if control == null:
		return
	var bindings := InputRouter.bindings_of(_remap_slot)
	for other: int in bindings.controls:
		if other != _remap_action and control in bindings.controls[other]:
			_notify("That control already has an action. Choose another.")
			return
	# Keyboard zones share hardware: never install a key claimed by the partner.
	var partner := InputRouter.bindings_of(1 - _remap_slot)
	if source.is_keyboard() and partner.kind != DeviceSource.Kind.GAMEPAD:
		for controls: Array in partner.controls.values():
			if control in controls:
				_notify("The other player already uses that key.")
				return
	bindings.controls[_remap_action] = [control]
	InputRouter.set_bindings(_remap_slot, bindings)
	_persist_settings()
	_back()
	get_viewport().set_input_as_handled()


func _apply_settings() -> void:
	AudioDirector.set_levels(settings.master_volume, settings.music_volume, settings.sfx_volume)
	if is_instance_valid(session):
		session.reduced_flash = settings.reduced_flash
		session.reduced_shake = settings.reduced_shake
		for player in session.players:
			player.reduced_flash = settings.reduced_flash


func _persist_settings() -> void:
	for index in 2:
		if InputRouter.source_of(index) != null and InputRouter.bindings_of(index) != null:
			settings.sources[index] = InputRouter.source_of(index).identity()
			settings.player_bindings[index] = InputRouter.bindings_of(index).to_dict()
	var result := settings_store.save_settings(settings)
	if not result.ok:
		_notify(str(result.message))


func _device_lost(_slot: int, _source: DeviceSource) -> void:
	_remap_slot = -1
	InputRouter.flush()
	for index in 2:
		if InputRouter.is_joined(index) and not InputRouter.is_waiting_for_device(index):
			menu_owner = index
			break
	if not is_instance_valid(session) and screen != "reconnect":
		_reconnect_return = screen
	_show_reconnect()


func _device_returned(slot: int, _source: DeviceSource) -> void:
	if InputRouter.is_waiting_for_device(menu_owner) or not InputRouter.is_joined(menu_owner):
		menu_owner = slot
	if screen == "reconnect":
		_show_reconnect()
	elif screen == "join":
		_show_join()


func _device_list_changed() -> void:
	if screen == "join":
		_show_join()


func _notify(message: String) -> void:
	if not is_instance_valid(_toast) or message.is_empty():
		return
	# Durability errors must survive a same-tick story/checkpoint notice.
	if _toast_ticks > 0:
		if message != _toast.text and message not in _notices:
			_notices.append(message)
		return
	_toast.text = message
	_toast_back.visible = true
	_toast_ticks = 360


func _show_fatal(message: String) -> void:
	# Emergency engine-default text stays readable when the original font itself
	# is absent. No gameplay/session is created with missing required resources.
	_fatal = true
	screen = "error"
	var background := ColorRect.new()
	background.size = Vector2(960, 360)
	background.color = Color("#10141c")
	add_child(background)
	var label := Label.new()
	label.name = "StartupErrorMessage"
	label.position = Vector2(64, 48)
	label.size = Vector2(832, 220)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	label.clip_text = true
	label.text = "Gloamthread: Two Ends\nPlease install a complete build. Escape exits.\n" + message.left(700)
	add_child(label)
	var button := Button.new()
	button.name = "StartupQuit"
	button.position = Vector2(64, 292)
	button.size = Vector2(160, 36)
	button.text = "Quit"
	button.pressed.connect(_quit_requested)
	add_child(button)
	button.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_requested()


func _quit_requested() -> void:
	if is_instance_valid(session):
		session.save_now()
		if not session.last_save_error.is_empty():
			session.request_mode("pause", menu_owner)
			_show("unsaved_quit", "This thread has not been saved", session.last_save_error + "\nRetry or explicitly discard the unsaved progress before quitting.", [_row("retry_quit", "Retry save and quit"), _row("discard_quit", "Discard unsaved progress and quit"), _row("cancel", "Keep this journey open")])
			return
	_finish_quit()


func _finish_quit() -> void:
	if OS.has_feature("web"):
		BrowserRuntime.home()
	else:
		get_tree().quit()


func browser_focus_lost() -> void:
	if is_instance_valid(session):
		session.save_now()
		if not session.last_save_error.is_empty():
			_notify(session.last_save_error)
		if session.mode == "playing":
			session.request_mode("pause", menu_owner)
			_show_pause()
	InputRouter.flush()
