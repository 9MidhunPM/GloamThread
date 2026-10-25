class_name ArenaApp
extends Control
## Fullscreen app flow and owner-scoped menus. ArenaRunSession owns simulation.

const Action := CommandSnapshot.Action
const INK := Color("eee9d9")
const MUTED := Color("9caeb3")
const GOLD := Color("f1bc68")
const PANEL := Color("14242e")

var catalog: ArenaCatalog
var library := FighterLibrary.new()
var bundles: Array[Dictionary] = []
var selected: Array[Dictionary] = []
var session: ArenaRunSession
var world_view: SubViewport
var world_container: SubViewportContainer
var presentation: Control
var viewport_root: Control
var overlay: Control
var hud: Control
var creator: CharacterCreator
var settings_store := SettingsRepository.new()
var settings: Dictionary = {}
var records := ArenaRecords.new()
var assets: AssetCatalog
var font: Font
var screen: String = "title"
var roster_size: int = 1
var menu_buttons: Array[Button] = []
var menu_cursor: int = 0
var shop_buttons: Array[Array] = []
var shop_cursor: Array[int] = [0, 0]
var _hud_labels: Array[Label] = []
var _health_bars: Array[ProgressBar] = []
var _special_bars: Array[ProgressBar] = []
var _wave_label: Label
var _combo_label: Label
var _centre_label: Label
var _boss_label: Label
var _boss_bar: ProgressBar
var _message: Label
var _toast_ticks: int = 0
var _ticks: int = 0
var _creation_return: String = "title"
var _result_recorded: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 200
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().auto_accept_quit = false
	DisplayServer.window_set_title("Gloamthread - Wave Arena")
	settings = settings_store.load_settings().settings
	_assign_controls()
	assets = AssetCatalog.load_from_path("res://assets/manifest.json")
	font = assets.font()
	AudioDirector.register_bundle(assets)
	var audio_errors := ArenaAudio.register_original()
	_apply_settings()
	catalog = ArenaCatalog.load_catalog()
	bundles = library.list_bundles()
	viewport_root = Control.new()
	viewport_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(viewport_root)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var toast_layer := CanvasLayer.new()
	toast_layer.layer = 50
	add_child(toast_layer)
	_message = _label("", Vector2(280, 1000), Vector2(1360, 55), 22, GOLD, toast_layer)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	InputRouter.device_lost.connect(_device_lost)
	if not catalog.errors.is_empty() or bundles.is_empty() or font == null or not assets.errors.is_empty() or not audio_errors.is_empty():
		_show_error("\n".join(catalog.errors) + "\n" + "\n".join(library.errors) + "\n" + "\n".join(assets.errors) + "\n" + "\n".join(audio_errors))
		return
	selected = [bundles[0], bundles[mini(1, bundles.size() - 1)]]
	for slot in mini(2, library.default_players.size()):
		for bundle: Dictionary in bundles:
			if bundle.id == library.default_players[slot]:
				selected[slot] = bundle
				break
	_show_title()


func _assign_controls() -> void:
	for slot in 2:
		InputRouter.clear(slot)
	for slot in 2:
		var source := DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right()
		var identity: Dictionary = settings.sources[slot]
		if identity.kind == "GAMEPAD":
			for id: int in Input.get_connected_joypads():
				if Input.get_joy_guid(id) == identity.guid and Input.get_joy_name(id) == identity.name:
					var candidate := DeviceSource.gamepad(id)
					var taken := InputRouter.source_of(1 - slot)
					if taken == null or not candidate.conflicts_with(taken):
						source = candidate
		var binding := Bindings.from_dict(settings.player_bindings[slot])
		if binding.kind != source.kind:
			binding = Bindings.defaults_for(source.kind)
		InputRouter.assign(slot, source, binding)


func _apply_settings() -> void:
	AudioDirector.set_levels(settings.master_volume, settings.music_volume, settings.sfx_volume)
	if is_instance_valid(session):
		session.reduced_flash = settings.reduced_flash
		session.reduced_shake = settings.reduced_shake


func _clear_menu(kind: String, flush_inputs: bool = true) -> void:
	for node in overlay.get_children():
		overlay.remove_child(node)
		node.queue_free()
	screen = kind
	menu_buttons.clear()
	menu_cursor = 0
	if flush_inputs:
		InputRouter.flush()


func _show_title() -> void:
	get_tree().paused = false
	if is_instance_valid(session):
		viewport_root.get_child(0).free()
		session = null
		world_view = null
		world_container = null
		presentation = null
	if is_instance_valid(hud):
		hud.free()
	_clear_menu("title")
	_background(selected[0])
	_label("LOCAL ARCADE  /  1-2 PLAYERS", Vector2(106, 91), Vector2(900, 36), 22, GOLD)
	_label("GLOAMTHREAD", Vector2(96, 149), Vector2(1600, 110), 80, INK)
	_label("WEAVE. FIGHT. REPEAT.", Vector2(106, 277), Vector2(900, 52), 30, GOLD)
	_label("Draw your fighter. Explore a changing world.\nTwenty waves. Hidden trails. Bring a friend.", Vector2(108, 355), Vector2(900, 100), 24, MUTED)
	_button("SOLO RUN", Rect2(108, 502, 650, 80), func() -> void: _show_lobby(1), true)
	_button("LOCAL CO-OP", Rect2(108, 596, 650, 80), func() -> void: _show_lobby(2))
	_button("CHARACTER FORGE", Rect2(108, 690, 650, 80), func() -> void: _open_creator(0))
	_button("SETTINGS & CONTROLS", Rect2(108, 784, 650, 72), _show_settings)
	_button("QUIT", Rect2(108, 870, 650, 64), func() -> void: get_tree().quit())
	_preview(selected[0], Rect2(1000, 330, 480, 480), false)
	_preview(selected[1], Rect2(1390, 410, 390, 390), true)
	_label("PERSONAL BUILDS\nSHARED MAYHEM", Vector2(1080, 820), Vector2(680, 110), 36, INK)
	_label("20 WAVES + ENDLESS  |  MADE FROM YOUR DRAWINGS", Vector2(106, 994), Vector2(1690, 40), 20, MUTED)
	AudioDirector.play_music("arena")
	_focus_menu()


func _show_lobby(count: int = 0) -> void:
	if count > 0:
		roster_size = count
	_clear_menu("lobby")
	_background(selected[0])
	_label("CHOOSE YOUR FIGHTERS", Vector2(112, 72), Vector2(1650, 80), 52, INK)
	_label("One shared arena. Every upgrade is yours.", Vector2(116, 160), Vector2(1650, 50), 24, MUTED)
	for slot in roster_size:
		var x := 130.0 + slot * 850 if roster_size == 2 else 520.0
		_panel(Rect2(x, 235, 800, 590))
		var kit: Dictionary = catalog.kits[selected[slot].kit_id]
		_label("PLAYER %d" % (slot + 1), Vector2(x + 36, 267), Vector2(700, 40), 22, GOLD)
		_preview(selected[slot], Rect2(x + 35, 320, 260, 260), slot == 1)
		_label(str(selected[slot].name).to_upper(), Vector2(x + 320, 330), Vector2(440, 60), 28, INK)
		_label(str(kit.name) + "\n\n" + str(kit.get("special_name", "Special")) + "\n" + str(kit.get("passive_name", "Passive")), Vector2(x + 320, 408), Vector2(440, 160), 20, MUTED)
		_button("CHANGE FIGHTER", Rect2(x + 34, 600, 350, 64), _cycle_character.bind(slot))
		_button("DRAW / IMPORT", Rect2(x + 412, 600, 350, 64), _open_creator.bind(slot))
		var source := InputRouter.source_of(slot)
		_button("P%d INPUT: %s" % [slot + 1, source.short_label() if source != null else "NONE"], Rect2(x + 34, 690, 728, 64), _cycle_source.bind(slot))
	_label("P1  WASD / Space jump / F attack / G special / Shift dodge / E revive\nP2  Arrows / . jump / , attack / / special / ' dodge / M revive\nGamepad  Left stick / A jump / X attack / B special / RB dodge / Y revive", Vector2(135, 852), Vector2(1270, 115), 19, MUTED)
	_button("START RUN", Rect2(1420, 855, 365, 84), _begin_run, true)
	_button("BACK", Rect2(1420, 955, 365, 60), _show_title)
	_focus_menu()


func _cycle_character(slot: int) -> void:
	var current := -1
	for i in bundles.size():
		if bundles[i].get("manifest_path") == selected[slot].get("manifest_path"):
			current = i
	selected[slot] = bundles[(current + 1) % bundles.size()]
	_show_lobby()


func _cycle_source(slot: int) -> void:
	var choices := InputRouter.available_sources(slot)
	var current := InputRouter.source_of(slot)
	var index := -1
	for i in choices.size():
		if current != null and current.conflicts_with(choices[i]):
			index = i
	if not choices.is_empty():
		InputRouter.assign(slot, choices[(index + 1) % choices.size()])
	_persist_settings()
	if screen == "reconnect":
		_show_reconnect()
	else:
		_show_lobby()


func _open_creator(slot: int) -> void:
	_creation_return = screen
	_clear_menu("creator")
	creator = CharacterCreator.new()
	creator.setup(slot, library)
	creator.completed.connect(func(bundle: Dictionary) -> void:
		selected[slot] = bundle
		bundles = library.list_bundles()
		creator.queue_free()
		_show_lobby() if _creation_return == "lobby" else _show_title())
	creator.cancelled.connect(func() -> void:
		creator.queue_free()
		_show_lobby() if _creation_return == "lobby" else _show_title())
	overlay.add_child(creator)


func _begin_run(seed: int = 0) -> void:
	for slot in roster_size:
		if not InputRouter.is_joined(slot) or InputRouter.is_waiting_for_device(slot):
			_toast("Assign a connected input to every active player.")
			return
	_clear_menu("playing")
	_result_recorded = false
	var bundles_for_run: Array[Dictionary] = []
	for slot in roster_size:
		bundles_for_run.append(selected[slot])
	session = ArenaRunSession.new()
	session.configure(catalog, bundles_for_run, seed)
	session.font = font
	session.reduced_flash = settings.reduced_flash
	session.reduced_shake = settings.reduced_shake
	session.phase_changed.connect(_phase_changed)
	session.changed.connect(_run_changed)
	session.notice.connect(_toast)
	presentation = load("res://scripts/arena/arena_presentation.gd").new()
	viewport_root.add_child(presentation)
	presentation.setup(session)
	session.presentation = presentation
	world_view = presentation.viewport_a
	world_container = presentation.container_a
	_build_hud()
	_persist_settings()


func _build_hud() -> void:
	if is_instance_valid(hud):
		hud.free()
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	move_child(hud, overlay.get_index())
	_hud_labels.clear()
	_health_bars.clear()
	_special_bars.clear()
	for slot in roster_size:
		var x := 48.0 if slot == 0 else 1352.0
		_panel(Rect2(x - 12, 24, 540, 136), hud)
		var label := _label("", Vector2(x + 18, 38), Vector2(480, 55), 23, GOLD, hud)
		_hud_labels.append(label)
		_health_bars.append(_bar(Rect2(x + 18, 98, 480, 15), Color("e88175"), hud))
		_special_bars.append(_bar(Rect2(x + 18, 124, 480, 6), Color("83bfc5"), hud))
	_wave_label = _label("", Vector2(655, 35), Vector2(610, 80), 32, INK, hud)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label = _label("", Vector2(655, 112), Vector2(610, 50), 24, GOLD, hud)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label = _label("", Vector2(600, 177), Vector2(720, 34), 22, INK, hud)
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_bar = _bar(Rect2(600, 218, 720, 10), Color("c993ac"), hud)
	_boss_bar.visible = false
	_centre_label = _label("", Vector2(380, 405), Vector2(1160, 240), 60, INK, hud)
	_centre_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_centre_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label("ESC / START  PAUSE", Vector2(48, 1024), Vector2(500, 35), 18, MUTED, hud)
	_update_hud()


func _phase_changed(value: String) -> void:
	if value == "error":
		_show_error(session.load_error)
	elif value == "shop":
		_show_shop()
	elif value in ["victory", "defeat"]:
		_show_results()
	elif value in ["countdown", "combat", "clear"]:
		_clear_menu("playing")
	_update_hud()


func _run_changed() -> void:
	if screen == "shop" and is_instance_valid(session) and session.phase == "shop":
		_show_shop(false)


func _show_shop(reset: bool = true) -> void:
	_clear_menu("shop", reset)
	if reset:
		shop_cursor = [0, 0]
	shop_buttons.clear()
	for slot in roster_size:
		var half_x := slot * 960.0 if roster_size == 2 else 0.0
		if not session.shop_open[slot]:
			shop_buttons.append([])
			var caption := "READY - CHANGE SHOP" if session.shop_ready[slot] else "EXPLORE / OPEN SHOP"
			_button("P%d  %s [%s]" % [slot + 1, caption, InputRouter.bindings_of(slot).prompt_label(Action.INTERACT)], Rect2(half_x + 35, 980, 820, 60), session.set_shop_open.bind(slot, true), false, false)
			continue
		var shade := ColorRect.new()
		shade.position = Vector2(half_x, 0)
		shade.size = Vector2(960 if roster_size == 2 else 1920, 1080)
		shade.color = Color(0.02, 0.04, 0.06, 0.78)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(shade)
		var x := half_x + 72 if roster_size == 2 else 520.0
		_panel(Rect2(x, 220, 816, 742))
		var state := session.player_states[slot]
		_label("WAVE %02d CLEAR / P%d" % [session.wave, slot + 1], Vector2(x + 28, 244), Vector2(750, 35), 23, MUTED)
		_label("%s / %d COINS" % [selected[slot].name, state.coins], Vector2(x + 28, 288), Vector2(750, 45), 27, GOLD)
		var buttons: Array = []
		var row := 0
		for offer: Dictionary in session.shop_offers[slot]:
			var button := _button("", Rect2(x + 28, 343 + row * 94, 760, 84), _shop_purchase.bind(slot, str(offer.id)), false, false)
			_label("%s %s" % [offer.name, "I".repeat(int(offer.rank))], Vector2(18, 9), Vector2(510, 28), 22, INK, button)
			var price := _label("%d COINS" % offer.price, Vector2(563, 10), Vector2(175, 28), 20, GOLD, button)
			price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			var description := _label(str(offer.description), Vector2(18, 43), Vector2(716, 35), 18, MUTED, button)
			description.max_lines_visible = 2
			button.disabled = state.coins < int(offer.price)
			buttons.append(button)
			row += 1
		var heal := _button("HEAL +35% / 5C", Rect2(x + 28, 730, 370, 54), _shop_purchase.bind(slot, "heal"), false, false)
		heal.disabled = state.coins < 5 or session.fighters[slot].health >= session.fighters[slot].max_health
		buttons.append(heal)
		var roll := _button("REROLL / FREE" if not session.rerolled[slot] else "REROLL USED", Rect2(x + 416, 730, 372, 54), _shop_reroll.bind(slot), false, false)
		roll.disabled = session.rerolled[slot]
		buttons.append(roll)
		buttons.append(_button("EXPLORE - KEEP SHOPPING LATER", Rect2(x + 28, 802, 760, 56), session.set_shop_open.bind(slot, false), false, false))
		buttons.append(_button("READY FOR NEXT WAVE", Rect2(x + 28, 878, 760, 56), _shop_ready.bind(slot), true, false))
		shop_buttons.append(buttons)
		shop_cursor[slot] = mini(shop_cursor[slot], buttons.size() - 1)
		_label("Own Up/Down selects; Attack/Jump confirms.
Explore freely. Everyone must Ready.", Vector2(x + 6, 980), Vector2(810, 62), 19, MUTED)
	_focus_shop()


func _shop_purchase(slot: int, id: String) -> void:
	var result := session.try_purchase(slot, id)
	_toast(str(result.message))


func _shop_reroll(slot: int) -> void:
	session.reroll(slot)


func _shop_ready(slot: int) -> void:
	session.toggle_ready(slot)


func _show_pause() -> void:
	get_tree().paused = true
	_clear_menu("pause")
	_shade()
	_panel(Rect2(555, 245, 810, 615))
	_label("THREAD HELD", Vector2(615, 302), Vector2(690, 80), 48, INK)
	_button("RESUME", Rect2(615, 440, 690, 80), _resume, true)
	_button("SETTINGS & CONTROLS", Rect2(615, 540, 690, 80), _show_settings)
	_button("END RUN", Rect2(615, 640, 690, 80), _confirm_end_run)
	_label("WORLD SEED %d" % session.seed_value, Vector2(615, 393), Vector2(690, 30), 18, MUTED)
	_focus_menu()


func _confirm_end_run() -> void:
	_clear_menu("abandon")
	_shade()
	_panel(Rect2(555, 300, 810, 470))
	_label("END THIS RUN?", Vector2(615, 350), Vector2(700, 80), 40, INK)
	_label("Run power resets. Your saved fighters stay in the library.", Vector2(615, 460), Vector2(700, 85), 22, MUTED)
	_button("KEEP PLAYING", Rect2(615, 570, 330, 80), _resume, true)
	_button("END RUN", Rect2(975, 570, 330, 80), _show_title)
	_focus_menu()


func _resume() -> void:
	for slot in roster_size:
		if InputRouter.is_waiting_for_device(slot):
			_show_reconnect()
			return
	get_tree().paused = false
	if session.phase == "shop":
		_show_shop(false)
	elif session.phase in ["victory", "defeat"]:
		_show_results()
	else:
		_clear_menu("playing")


func _show_settings() -> void:
	_clear_menu("settings")
	if not is_instance_valid(session):
		_background(selected[0])
	_shade()
	_panel(Rect2(320, 150, 1280, 780))
	_label("SETTINGS & CONTROLS", Vector2(380, 195), Vector2(1160, 75), 42, INK)
	_button("FULLSCREEN: %s  /  F11" % ("ON" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "OFF"), Rect2(380, 310, 1160, 70), _toggle_fullscreen)
	_button("MASTER VOLUME: %d%%" % roundi(settings.master_volume * 100), Rect2(380, 400, 1160, 70), _cycle_volume)
	_button("REDUCED FLASH: " + ("ON" if settings.reduced_flash else "OFF"), Rect2(380, 490, 1160, 70), _toggle_setting.bind("reduced_flash"))
	_button("REDUCED SHAKE: " + ("ON" if settings.reduced_shake else "OFF"), Rect2(380, 580, 1160, 70), _toggle_setting.bind("reduced_shake"))
	_label("P1  WASD / Space / F / G / Shift / E\nP2  Arrows / . / , / / / ' / M\nGamepad  Stick / A / X / B / RB / Y\nMove / Jump / Attack / Special / Dodge / Revive", Vector2(384, 680), Vector2(1120, 150), 22, MUTED)
	_button("BACK", Rect2(1160, 820, 380, 65), func() -> void: _show_pause() if is_instance_valid(session) else _show_title(), true)
	_focus_menu()


func _toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if screen == "settings":
		_show_settings()


func _cycle_volume() -> void:
	settings.master_volume = fmod(float(settings.master_volume) + 0.1, 1.1)
	_apply_settings()
	_persist_settings()
	_show_settings()


func _toggle_setting(id: String) -> void:
	settings[id] = not settings[id]
	_apply_settings()
	_persist_settings()
	_show_settings()


func _persist_settings() -> void:
	for slot in 2:
		var source := InputRouter.source_of(slot)
		if source != null:
			settings.sources[slot] = source.identity()
			settings.player_bindings[slot] = InputRouter.bindings_of(slot).to_dict()
	var result := settings_store.save_settings(settings)
	if not result.ok:
		_toast(str(result.message))


func _device_lost(slot: int, _source: DeviceSource) -> void:
	if is_instance_valid(session) and slot < roster_size:
		get_tree().paused = true
		_show_reconnect()


func _show_reconnect() -> void:
	_clear_menu("reconnect")
	_shade()
	_panel(Rect2(450, 230, 1020, 650))
	_label("RECONNECT TO CONTINUE", Vector2(510, 280), Vector2(900, 80), 40, INK)
	for slot in roster_size:
		var source := InputRouter.source_of(slot)
		_button("P%d: %s  -  CHANGE INPUT" % [slot + 1, source.short_label() if source != null else "NONE"], Rect2(510, 430 + 105 * slot, 900, 80), _cycle_source.bind(slot))
	_button("RESUME", Rect2(510, 690, 430, 80), _resume, true)
	_button("END RUN", Rect2(980, 690, 430, 80), _confirm_end_run)
	_focus_menu()


func _show_results() -> void:
	_clear_menu("results")
	_shade()
	var won := session.phase == "victory"
	if not _result_recorded:
		_result_recorded = true
		if not records.record_run(session.summary()):
			_toast(records.error)
	_panel(Rect2(390, 180, 1140, 735))
	_label("THE LOOM IS YOURS" if won else "ONE MORE THREAD?", Vector2(455, 245), Vector2(1010, 100), 52, GOLD)
	var summary := session.summary()
	var body := "WAVE %02d   /   BEST COMBO %d   /   %d:%02d\n\n" % [session.wave, session.best_combo, int(summary.seconds) / 60, int(summary.seconds) % 60]
	for i in session.player_states.size():
		var state := session.player_states[i]
		body += "P%d  %s  |  %d KILLS  |  %d COINS SPENT\n\n" % [i + 1, selected[i].name, state.kills, state.spent]
	_label(body, Vector2(460, 380), Vector2(1000, 250), 26, INK)
	if won:
		_button("CONTINUE INTO ENDLESS", Rect2(460, 650, 1000, 80), _continue_endless, true)
		_button("BANK THE WIN & RETURN", Rect2(460, 750, 1000, 70), _show_title)
	else:
		_button("NEW RUN", Rect2(460, 650, 1000, 80), _restart_run, true)
		_button("RETURN TO TITLE", Rect2(460, 750, 1000, 70), _show_title)
	_focus_menu()


func _continue_endless() -> void:
	_result_recorded = false
	session.continue_endless()


func _restart_run() -> void:
	_show_title()
	_begin_run()


func _physics_process(_delta: float) -> void:
	_ticks += 1
	if is_instance_valid(session):
		_message.position.y = 170
		_message.visible = screen != "playing" or not is_instance_valid(_boss_bar) or not _boss_bar.visible
	else:
		_message.position.y = 1000
		_message.show()
	if _toast_ticks > 0:
		if _message.visible:
			_toast_ticks -= 1
		if _toast_ticks == 0:
			_message.text = ""
	if screen == "creator" or screen == "error":
		return
	if is_instance_valid(session) and screen in ["playing", "shop"]:
		if is_instance_valid(presentation):
			presentation.force_split = session.shop_open.has(true)
		for slot in roster_size:
			if InputRouter.snapshot(slot).just_pressed(Action.PAUSE):
				_show_pause()
				return
		if screen == "shop":
			_poll_shop()
		if _ticks % 6 == 0:
			_update_hud()
	elif not menu_buttons.is_empty():
		var command := InputRouter.snapshot(0)
		if command.just_pressed(Action.DOWN) or command.just_pressed(Action.RIGHT):
			menu_cursor = (menu_cursor + 1) % menu_buttons.size()
			_focus_menu()
		elif command.just_pressed(Action.UP) or command.just_pressed(Action.LEFT):
			menu_cursor = posmod(menu_cursor - 1, menu_buttons.size())
			_focus_menu()
		elif command.just_pressed(Action.JUMP) or command.just_pressed(Action.ATTACK) or command.just_pressed(Action.INTERACT):
			menu_buttons[menu_cursor].pressed.emit()
		elif command.just_pressed(Action.PAUSE) and is_instance_valid(session) and screen == "pause":
			_resume()


func _poll_shop() -> void:
	for slot in roster_size:
		if not session.shop_open[slot]:
			if InputRouter.snapshot(slot).just_pressed(Action.INTERACT):
				session.set_shop_open(slot, true)
			continue
		if slot >= shop_buttons.size() or shop_buttons[slot].is_empty():
			continue
		var command := InputRouter.snapshot(slot)
		if command.just_pressed(Action.DOWN) or command.just_pressed(Action.RIGHT):
			shop_cursor[slot] = (shop_cursor[slot] + 1) % shop_buttons[slot].size()
			_focus_shop()
		elif command.just_pressed(Action.UP) or command.just_pressed(Action.LEFT):
			shop_cursor[slot] = posmod(shop_cursor[slot] - 1, shop_buttons[slot].size())
			_focus_shop()
		elif command.just_pressed(Action.JUMP) or command.just_pressed(Action.ATTACK) or command.just_pressed(Action.INTERACT):
			var button: Button = shop_buttons[slot][shop_cursor[slot]]
			if not button.disabled:
				button.pressed.emit()
				if screen != "shop":
					return


func _focus_menu() -> void:
	for i in menu_buttons.size():
		var button := menu_buttons[i]
		var active := i == menu_cursor
		var primary: bool = button.get_meta("primary", false)
		button.add_theme_stylebox_override("normal", _style(Color("efcf8d") if active else (GOLD if primary else PANEL), INK if active else (GOLD if primary else Color("39535a"))))
		button.add_theme_color_override("font_color", Color("17212a") if active or primary else INK)


func _focus_shop() -> void:
	for slot in shop_buttons.size():
		for i in shop_buttons[slot].size():
			var button: Button = shop_buttons[slot][i]
			var primary: bool = button.get_meta("primary", false)
			button.add_theme_stylebox_override("normal", _style(GOLD if primary else (Color("263d45") if i == shop_cursor[slot] else PANEL), GOLD if i == shop_cursor[slot] or primary else Color("39535a")))
			button.add_theme_color_override("font_color", Color("17212a") if primary else INK)


func _update_hud() -> void:
	if not is_instance_valid(session) or not is_instance_valid(_wave_label):
		return
	for slot in mini(_hud_labels.size(), session.fighters.size()):
		var fighter: Node = session.fighters[slot]
		var state := session.player_states[slot]
		_hud_labels[slot].text = "P%d  %s   %d COINS\n%s" % [slot + 1, selected[slot].name, state.coins, "DOWNED - HOLD REVIVE NEARBY" if fighter.downed else "%d / %d HP" % [ceili(fighter.health), ceili(fighter.max_health)]]
		_health_bars[slot].value = 100.0 * fighter.health / maxf(1, fighter.max_health)
		_special_bars[slot].value = 100.0 * (1.0 - float(fighter.special_ticks) / maxf(1, float(fighter.stats.special_cooldown)))
	_wave_label.text = "WAVE %02d%s\n%s" % [session.wave, "  /  ENDLESS" if session.endless else " / 20", str(catalog.arenas[session.stage].name).to_upper()]
	_combo_label.text = "%d CHAIN!" % session.combo if session.combo >= 3 else ""
	var boss: ArenaEnemy
	for enemy: ArenaEnemy in session.enemies:
		if not enemy.dead and enemy.boss_id != "":
			boss = enemy
			break
	_boss_bar.visible = boss != null
	_boss_label.text = boss.boss_id.to_upper() if boss != null else ""
	if boss != null:
		_boss_bar.value = 100 * boss.health / maxf(1, boss.max_health)
	match session.phase:
		"countdown": _centre_label.text = "WAVE %02d\n%s" % [session.wave, str(maxi(1, ceili((150 - session.phase_ticks) / 60.0)))]
		"clear": _centre_label.text = "WAVE CLEARED\n+%d COINS EACH" % (8 + 2 * ((session.wave - 1) / 5))
		_: _centre_label.text = ""


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F11:
			_toggle_fullscreen()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE and is_instance_valid(session) and screen in ["playing", "shop"]:
			_show_pause()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(session) and screen in ["playing", "shop"]:
		_show_pause()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(session):
			_show_pause()
		else:
			get_tree().quit()


func _toast(message: String) -> void:
	if is_instance_valid(_message):
		_message.text = message
		_toast_ticks = 180


func _show_error(message: String) -> void:
	_clear_menu("error")
	_shade()
	_label("GLOAMTHREAD NEEDS A COMPLETE BUILD", Vector2(150, 180), Vector2(1600, 100), 40, INK)
	_label(message, Vector2(150, 330), Vector2(1600, 500), 24, INK)
	_button("QUIT", Rect2(150, 880, 450, 80), func() -> void: get_tree().quit())


func _background(bundle: Dictionary) -> void:
	var background := TextureRect.new()
	background.texture = bundle.get("background")
	background.position = Vector2.ZERO
	background.size = Vector2(1920, 1080)
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(background)
	_shade(0.74)


func _shade(alpha: float = 0.86) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.045, 0.065, alpha)
	shade.size = Vector2(1920, 1080)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)


func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_left = 24
	style.content_margin_right = 24
	return style


func _panel(rect: Rect2, parent: Node = null) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style(PANEL, Color("385058")))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else overlay).add_child(panel)
	return panel


func _label(text: String, at: Vector2, dimensions: Vector2, pixels: int, color: Color, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", pixels)
	if font != null:
		label.add_theme_font_override("font", font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else overlay).add_child(label)
	return label


func _button(text: String, rect: Rect2, action: Callable, primary: bool = false, navigable: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.set_meta("primary", primary)
	button.position = rect.position
	button.size = rect.size
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 22 if text.contains("\n") else 25)
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_color_override("font_color", Color("17212a") if primary else INK)
	button.add_theme_color_override("font_hover_color", Color("17212a"))
	button.add_theme_color_override("font_focus_color", Color("17212a"))
	button.add_theme_color_override("font_disabled_color", Color("74858c"))
	button.add_theme_stylebox_override("normal", _style(GOLD if primary else PANEL, GOLD if primary else Color("39535a")))
	button.add_theme_stylebox_override("hover", _style(Color("efcf8d"), GOLD))
	button.add_theme_stylebox_override("focus", _style(Color("efcf8d"), INK))
	button.add_theme_stylebox_override("pressed", _style(Color("c49451"), GOLD))
	button.add_theme_stylebox_override("disabled", _style(Color("132029"), Color("293b43")))
	button.pressed.connect(action)
	overlay.add_child(button)
	if navigable:
		menu_buttons.append(button)
	return button


func _preview(bundle: Dictionary, rect: Rect2, flip: bool) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = bundle.get("atlas")
	atlas.region = Rect2(2, 2, 64, 64)
	var portrait := TextureRect.new()
	portrait.texture = atlas
	portrait.position = rect.position
	portrait.size = rect.size
	portrait.flip_h = flip
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(portrait)


func _bar(rect: Rect2, color: Color, parent: Node) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = rect.position
	bar.size = rect.size
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _style(Color("0d1720"), Color("0d1720")))
	bar.add_theme_stylebox_override("fill", _style(color, color))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar
