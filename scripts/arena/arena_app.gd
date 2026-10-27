class_name ArenaApp
extends Control
## Fullscreen app flow and owner-scoped menus. ArenaRunSession owns simulation.

const Action := CommandSnapshot.Action
const Identity := preload("res://scripts/forge/fighter_identity.gd")
const INK := Color("eee9d9")
const MUTED := Color("9caeb3")
const GOLD := Color("f1bc68")
const PANEL := Color("14242e")
## Actions a player may remap. Pause stays fixed so a menu is always reachable.
const REMAP_ACTIONS: Array[int] = [Action.LEFT, Action.RIGHT, Action.UP, Action.DOWN, Action.JUMP, Action.ATTACK, Action.SPECIAL, Action.DASH, Action.INTERACT]
const ACTION_NAMES := {Action.LEFT: "MOVE LEFT", Action.RIGHT: "MOVE RIGHT", Action.UP: "UP / MENU UP", Action.DOWN: "DOWN / DROP", Action.JUMP: "JUMP", Action.ATTACK: "ATTACK", Action.SPECIAL: "SPECIAL", Action.DASH: "DODGE", Action.INTERACT: "REVIVE / SHOP", Action.PAUSE: "PAUSE"}

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
var _speed_applied: bool = false
var _remap_slot: int = -1
var _remap_action: int = 0
var _announcement: String = ""
var _fresh_screen: bool = true
var _hint_label: Label
var _voice: String = ""
var _downed_spoken: Array[bool] = [false, false]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 200
	get_window().content_scale_size = Vector2i(1920, 1080)
	BrowserRuntime.set_mode("arena")
	if OS.has_feature("web"):
		BrowserRuntime.fullscreen_changed.connect(_browser_fullscreen_changed)
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
		session.damage_taken_scale = settings.damage_taken
		session.game_speed = settings.game_speed
		session.attack_toggle = settings.attack_toggle.duplicate()
		session.apply_assists()
	_apply_game_speed()


## Slow-motion assist scales Engine time only while a run exists, so fixed
## 60 Hz ticks keep their meaning. Untouched at 100% so showcase tools keep
## control of their own viewing speed.
func _apply_game_speed() -> void:
	var wanted := float(settings.game_speed) if is_instance_valid(session) else 1.0
	if wanted < 1.0:
		Engine.time_scale = wanted
		_speed_applied = true
	elif _speed_applied:
		Engine.time_scale = 1.0
		_speed_applied = false


func _exit_tree() -> void:
	if _speed_applied:
		Engine.time_scale = 1.0
		_speed_applied = false


func _clear_menu(kind: String, flush_inputs: bool = true) -> void:
	for node in overlay.get_children():
		overlay.remove_child(node)
		node.queue_free()
	# Rebuilding the same screen (a changed setting) keeps the cursor and skips
	# the screen announcement, so keyboard and narration users keep their place.
	_fresh_screen = kind != screen
	if _fresh_screen:
		menu_cursor = 0
		_announcement = ""
	screen = kind
	menu_buttons.clear()
	_hint_label = null
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
	_apply_game_speed()
	if is_instance_valid(hud):
		hud.free()
	_clear_menu("title")
	_announce("Gloamthread main menu")
	_background(selected[0])
	_label("LOCAL ARCADE  /  1-2 PLAYERS", Vector2(106, 91), Vector2(900, 36), 22, GOLD)
	_label("GLOAMTHREAD", Vector2(96, 149), Vector2(1600, 110), 80, INK)
	_label("WEAVE. FIGHT. REPEAT.", Vector2(106, 277), Vector2(900, 52), 30, GOLD)
	_label("Draw your fighter. Explore a changing world.\nTwenty waves. Hidden trails. Bring a friend.", Vector2(108, 355), Vector2(900, 100), 24, MUTED)
	_button("SOLO RUN", Rect2(108, 502, 650, 64), func() -> void: _show_lobby(1), true)
	_button("LOCAL CO-OP", Rect2(108, 578, 650, 64), func() -> void: _show_lobby(2))
	_button("STORY MODE (2 PLAYERS)", Rect2(108, 654, 650, 64), _open_story)
	_button("CHARACTER FORGE", Rect2(108, 730, 650, 64), func() -> void: _open_creator(0))
	_button("SETTINGS & CONTROLS", Rect2(108, 806, 650, 64), _show_settings)
	_button("BROWSER HOME" if OS.has_feature("web") else "QUIT", Rect2(108, 882, 650, 56), _quit_game)
	_preview(selected[0], Rect2(1000, 330, 480, 480), false)
	_preview(selected[1], Rect2(1390, 410, 390, 390), true)
	_label("PERSONAL BUILDS\nSHARED MAYHEM", Vector2(1080, 820), Vector2(680, 110), 36, INK)
	_label("20 WAVES + ENDLESS  |  MADE FROM YOUR DRAWINGS", Vector2(106, 994), Vector2(1690, 40), 20, MUTED)
	AudioDirector.play_music("arena")
	_focus_menu()


func _open_story() -> void:
	get_tree().paused = false
	InputRouter.flush()
	AudioDirector.stop_cues()
	var error := get_tree().change_scene_to_file("res://scenes/app/boot.tscn")
	if error != OK:
		_toast("Story Mode could not open. Please install the complete game. (%s)" % error_string(error))


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
		var kit: Dictionary = catalog.kits[Identity.resolve(selected[slot])]
		_label("PLAYER %d" % (slot + 1), Vector2(x + 36, 267), Vector2(700, 40), 22, GOLD)
		_preview(selected[slot], Rect2(x + 35, 320, 260, 260), slot == 1)
		_label(str(selected[slot].name).to_upper(), Vector2(x + 320, 330), Vector2(440, 60), 28, INK)
		_label(str(kit.name) + "\n\n" + str(kit.get("special_name", "Special")) + "\n" + str(kit.get("passive_name", "Passive")), Vector2(x + 320, 408), Vector2(440, 160), 20, MUTED)
		_button("CHANGE FIGHTER", Rect2(x + 34, 600, 350, 64), _cycle_character.bind(slot))
		_button("DRAW / IMPORT", Rect2(x + 412, 600, 350, 64), _open_creator.bind(slot))
		var source := InputRouter.source_of(slot)
		_option("P%d INPUT: %s" % [slot + 1, source.short_label() if source != null else "NONE"], Rect2(x + 34, 690, 728, 64), _cycle_source.bind(slot), "Cycles keyboard left, keyboard right and connected gamepads for player %d." % (slot + 1))
	var lines: PackedStringArray = []
	for slot in roster_size:
		lines.append(_controls_line(slot))
	lines.append("Remap keys, toggle-attack and assists: Settings & Controls.")
	_label("\n".join(lines), Vector2(135, 852), Vector2(1270, 115), 19, MUTED)
	_button("START RUN", Rect2(1420, 855, 365, 84), _begin_run, true)
	_button("BACK", Rect2(1420, 955, 365, 60), _show_title)
	var names: PackedStringArray = []
	for slot in roster_size:
		names.append("Player %d: %s" % [slot + 1, selected[slot].name])
	_announce("Choose your fighters. " + ". ".join(names))
	_focus_menu()


func _cycle_character(slot: int) -> void:
	var current := -1
	for i in bundles.size():
		if bundles[i].get("manifest_path") == selected[slot].get("manifest_path"):
			current = i
	selected[slot] = bundles[(current + 1) % bundles.size()]
	_show_lobby()


func _cycle_source(slot: int) -> void:
	# Solo: the idle P2 slot must not stop P1 choosing the right-hand
	# (arrow) keyboard side. P2 temporarily releases its source and takes
	# whichever keyboard side remains afterwards.
	var idle_source: DeviceSource = InputRouter.source_of(1) if roster_size == 1 and slot == 0 else null
	var idle_bindings: Bindings = InputRouter.bindings_of(1) if idle_source != null else null
	if idle_source != null:
		InputRouter.clear(1)
	var choices := InputRouter.available_sources(slot)
	var current := InputRouter.source_of(slot)
	var index := -1
	for i in choices.size():
		if current != null and current.conflicts_with(choices[i]):
			index = i
	if not choices.is_empty():
		InputRouter.assign(slot, choices[(index + 1) % choices.size()])
	if idle_source != null:
		var free := InputRouter.available_sources(1)
		var restore: DeviceSource = idle_source if free.any(func(item: DeviceSource) -> bool: return item.conflicts_with(idle_source)) else null
		for candidate in free:
			if restore == null and candidate.is_keyboard():
				restore = candidate
		if restore != null:
			InputRouter.assign(1, restore, idle_bindings if idle_bindings != null and idle_bindings.kind == restore.kind else null)
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
		_show_lobby()
		_toast("%s selected for P%d. Start a run when ready." % [bundle.name, slot + 1]))
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
	_apply_settings()
	_downed_spoken = [false, false]
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
		if value == "countdown":
			_speak("Wave %d%s" % [session.wave, " endless" if session.endless else ""])
		elif value == "clear":
			_speak("Wave cleared")
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
			button.accessibility_name = "%s rank %d. %d coins. %s" % [offer.name, int(offer.rank), int(offer.price), offer.description]
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
	if reset:
		var wallets: PackedStringArray = []
		for slot in roster_size:
			wallets.append("Player %d has %d coins" % [slot + 1, session.player_states[slot].coins])
		_speak("Wave %d cleared. Shop open. %s. Up and down choose, attack buys." % [session.wave, ". ".join(wallets)])


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
	_announce("Paused")
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
	_announce("End this run? Run power resets. Your saved fighters stay in the library.")
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
	_announce("Settings and controls. Up and down move. Left and right change values.")
	if not is_instance_valid(session):
		_background(selected[0])
	_shade()
	_panel(Rect2(250, 100, 1420, 880))
	_label("SETTINGS & CONTROLS", Vector2(300, 128), Vector2(1320, 70), 42, INK)
	_label("SIGHT & SOUND", Vector2(300, 214), Vector2(640, 36), 22, GOLD)
	_label("ASSIST & CONTROLS", Vector2(980, 214), Vector2(640, 36), 22, GOLD)
	var left := func(row: int) -> Rect2: return Rect2(300, 260 + row * 72, 640, 60)
	var right := func(row: int) -> Rect2: return Rect2(980, 260 + row * 72, 640, 60)
	var fullscreen := BrowserRuntime.is_fullscreen()
	_option("FULLSCREEN: %s" % _on_off(fullscreen), left.call(0), _toggle_fullscreen, "Switch between fullscreen and a window. F11 also works anywhere.")
	var volumes := [["master_volume", "MASTER VOLUME", "Overall loudness."], ["music_volume", "MUSIC VOLUME", "Background music only."], ["sfx_volume", "EFFECTS VOLUME", "Hits, warnings and menu sounds."]]
	for index in volumes.size():
		var row: Array = volumes[index]
		_option("%s: %d%%" % [row[1], roundi(float(settings[row[0]]) * 100)], left.call(1 + index), _adjust_volume.bind(1, row[0], true), str(row[2]) + " Left and right change it in 10% steps.", _adjust_volume.bind(row[0], false))
	_option("REDUCED FLASH: %s" % _on_off(settings.reduced_flash), left.call(4), _toggle_setting.bind("reduced_flash"), "Softer, fewer hit sparks and no blinking invulnerability.")
	_option("REDUCED SHAKE: %s" % _on_off(settings.reduced_shake), left.call(5), _toggle_setting.bind("reduced_shake"), "Removes camera shake from hits and boss slams.")
	_option("HIGH CONTRAST: %s" % _on_off(settings.high_contrast), left.call(6), _toggle_setting.bind("high_contrast"), "Brighter text, solid backdrops and thick borders on menus and the HUD.")
	_option("READ MENUS ALOUD: %s" % _on_off(settings.narration), right.call(0), _toggle_narration, "Speaks menus, shop items, waves and notices with your system text-to-speech voice.")
	_option("DAMAGE TAKEN: %d%%" % roundi(float(settings.damage_taken) * 100), right.call(1), _step_setting.bind(1, "damage_taken", SettingsRepository.DAMAGE_TAKEN_STEPS), "Assist: enemies deal less damage to every player. Runs are marked as assisted.", _step_setting.bind("damage_taken", SettingsRepository.DAMAGE_TAKEN_STEPS))
	_option("GAME SPEED: %d%%" % roundi(float(settings.game_speed) * 100), right.call(2), _step_setting.bind(1, "game_speed", SettingsRepository.GAME_SPEED_STEPS), "Assist: slows the whole fight so there is more time to react. Runs are marked as assisted.", _step_setting.bind("game_speed", SettingsRepository.GAME_SPEED_STEPS))
	for slot in 2:
		var toggle: bool = settings.attack_toggle[slot]
		_option("P%d ATTACK: %s" % [slot + 1, "PRESS TO TOGGLE" if toggle else "HOLD"], right.call(3 + slot), _toggle_attack_mode.bind(slot), "Toggle: press Attack once to keep attacking, press again to stop. No holding needed.")
	for slot in 2:
		_option("P%d CONTROLS: REMAP KEYS" % (slot + 1), right.call(5 + slot), _show_remap.bind(slot), "Choose new keys or buttons for player %d. %s" % [slot + 1, _controls_line(slot)])
	_hint_label = _label("", Vector2(300, 776), Vector2(1320, 90), 22, INK)
	_button("BACK", Rect2(1290, 890, 330, 64), func() -> void: _show_pause() if is_instance_valid(session) else _show_title(), true)
	_focus_menu()


func _on_off(value: bool) -> String:
	return "ON" if value else "OFF"


func _toggle_fullscreen() -> void:
	if OS.has_feature("web"):
		BrowserRuntime.fullscreen()
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if screen == "settings":
		_show_settings()


func _browser_fullscreen_changed() -> void:
	if screen == "settings":
		_show_settings()


## Confirm/click raises the level and wraps to 0%; Left/Right clamp.
func _adjust_volume(direction: int, key: String, wrap: bool = false) -> void:
	var value := snappedf(float(settings[key]) + 0.1 * direction, 0.1)
	settings[key] = 0.0 if wrap and value > 1.0 else clampf(value, 0.0, 1.0)
	_settings_changed()


func _step_setting(direction: int, key: String, steps: Array) -> void:
	var index := maxi(0, steps.find(float(settings[key])))
	settings[key] = steps[posmod(index + direction, steps.size())]
	_settings_changed()


func _toggle_setting(id: String) -> void:
	settings[id] = not settings[id]
	if id == "high_contrast" and is_instance_valid(session):
		_build_hud()
	_settings_changed()


func _toggle_attack_mode(slot: int) -> void:
	settings.attack_toggle[slot] = not settings.attack_toggle[slot]
	_settings_changed()


func _toggle_narration() -> void:
	if not settings.narration and not _tts_ready():
		_toast("No text-to-speech voice found. Install speech-dispatcher with a voice such as espeak-ng, then restart.")
		return
	settings.narration = not settings.narration
	_settings_changed()


func _settings_changed() -> void:
	_apply_settings()
	_persist_settings()
	_show_settings()


func _show_remap(slot: int) -> void:
	var source := InputRouter.source_of(slot)
	if source == null or InputRouter.bindings_of(slot) == null:
		_toast("Assign an input to P%d in the lobby before remapping." % (slot + 1))
		return
	_clear_menu("remap_%d" % slot)
	_announce("Player %d controls, %s. Choose an action, then press its new key or button." % [slot + 1, source.display_name()])
	if not is_instance_valid(session):
		_background(selected[0])
	_shade()
	_panel(Rect2(250, 100, 1420, 880))
	_label("P%d CONTROLS  /  %s" % [slot + 1, source.display_name().to_upper()], Vector2(300, 128), Vector2(1320, 70), 36, INK)
	var bindings := InputRouter.bindings_of(slot)
	for index in REMAP_ACTIONS.size():
		var action := REMAP_ACTIONS[index]
		var column := 0 if index < 5 else 1
		var rect := Rect2(300 + column * 680, 230 + (index - column * 5) * 72, 640, 60)
		_option("%s: %s" % [ACTION_NAMES[action], _labels_for(bindings, action)], rect, _begin_capture.bind(slot, action), "Select, then press the new %s control on this player's input." % str(ACTION_NAMES[action]).to_lower())
	if bindings.kind == DeviceSource.Kind.GAMEPAD:
		_option("STICK DEADZONE: %d%%" % roundi(bindings.deadzone * 100), Rect2(980, 518, 640, 60), _adjust_deadzone.bind(1, slot), "How far the stick moves before it counts. Raise it for drifting sticks or unsteady hands.", _adjust_deadzone.bind(slot))
	_option("RESET P%d TO DEFAULTS" % (slot + 1), Rect2(980, 590, 640, 60), _reset_bindings.bind(slot), "Restore the original layout for this input.")
	_label("Pause stays on %s. Keys used by another action, or by the other keyboard player, are refused so nobody loses a control." % _labels_for(bindings, Action.PAUSE), Vector2(300, 676), Vector2(1320, 80), 20, MUTED)
	_hint_label = _label("", Vector2(300, 776), Vector2(1320, 90), 22, INK)
	_button("BACK", Rect2(1290, 890, 330, 64), _show_settings, true)
	_focus_menu()


func _labels_for(bindings: Bindings, action: int) -> String:
	var labels: PackedStringArray = []
	for control: Variant in bindings.controls.get(action, []):
		var single := Bindings.new()
		single.kind = bindings.kind
		single.controls = {action: [control]}
		labels.append(single.prompt_label(action))
	return " / ".join(labels) if not labels.is_empty() else "UNBOUND"


func _begin_capture(slot: int, action: int) -> void:
	_remap_slot = slot
	_remap_action = action
	var cursor := menu_cursor
	_clear_menu("remap_wait")
	menu_cursor = cursor
	var gamepad := InputRouter.source_of(slot).is_gamepad()
	var prompt := "Press the new %s %s for player %d.\n%s cancels." % [str(ACTION_NAMES[action]).to_lower(), "button" if gamepad else "key", slot + 1, "Start or Escape" if gamepad else "Escape"]
	_shade()
	_panel(Rect2(450, 330, 1020, 380))
	_label("CHOOSE A CONTROL", Vector2(510, 370), Vector2(900, 70), 40, GOLD)
	_label(prompt.to_upper(), Vector2(510, 460), Vector2(900, 120), 26, INK)
	_button("CANCEL", Rect2(510, 600, 400, 70), _end_capture, false, false)
	_speak("Choose a control. " + prompt)


func _end_capture() -> void:
	var slot := _remap_slot
	_remap_slot = -1
	# Treat the return as a rebuild of the same screen: cursor stays on the
	# remapped action and narration speaks it without repeating the title.
	screen = "remap_%d" % slot
	_show_remap(slot)


func _input(event: InputEvent) -> void:
	if screen != "remap_wait" or _remap_slot < 0:
		return
	var source := InputRouter.source_of(_remap_slot)
	var cancel: bool = event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE
	cancel = cancel or (source.is_gamepad() and event is InputEventJoypadButton and event.pressed and event.device == source.joy_id and event.button_index == JOY_BUTTON_START)
	if cancel:
		get_viewport().set_input_as_handled()
		_end_capture()
		return
	var control: Variant = null
	if source.is_keyboard() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode != KEY_F11:
		control = int(event.physical_keycode)
	elif source.is_gamepad() and event.device == source.joy_id:
		if event is InputEventJoypadButton and event.pressed:
			control = {"button": int(event.button_index)}
		elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.65:
			control = {"axis": int(event.axis), "sign": 1 if event.axis_value > 0 else -1}
	if control == null:
		return
	get_viewport().set_input_as_handled()
	var message := assign_control(_remap_slot, _remap_action, control)
	if not message.is_empty():
		_toast(message)
		return
	_toast("%s set to %s for P%d." % [ACTION_NAMES[_remap_action], _labels_for(InputRouter.bindings_of(_remap_slot), _remap_action), _remap_slot + 1])
	_end_capture()


## Installs one control for an action using the same refusal rules as Story
## Mode. Returns an empty string on success or a player-facing reason.
func assign_control(slot: int, action: int, control: Variant) -> String:
	var bindings := InputRouter.bindings_of(slot)
	if bindings == null:
		return "Assign an input before remapping."
	for other: int in bindings.controls:
		if other != action and control in bindings.controls[other]:
			return "That control already does %s. Choose another." % str(ACTION_NAMES.get(other, "another action")).to_lower()
	var partner := InputRouter.bindings_of(1 - slot)
	if bindings.kind != DeviceSource.Kind.GAMEPAD and partner != null and partner.kind != DeviceSource.Kind.GAMEPAD:
		for controls: Array in partner.controls.values():
			if control in controls:
				return "The other player already uses that key."
	var next: Array = [control]
	# A movement button keeps the analogue stick working alongside it.
	if control is Dictionary and control.has("button") and action in [Action.LEFT, Action.RIGHT, Action.UP, Action.DOWN]:
		for existing: Variant in bindings.controls.get(action, []):
			if existing is Dictionary and existing.has("axis"):
				next.append(existing)
	bindings.controls[action] = next
	InputRouter.set_bindings(slot, bindings)
	_persist_settings()
	return ""


func _adjust_deadzone(direction: int, slot: int) -> void:
	var bindings := InputRouter.bindings_of(slot)
	bindings.deadzone = clampf(snappedf(bindings.deadzone + 0.05 * direction, 0.05), 0.05, 0.9)
	InputRouter.set_bindings(slot, bindings)
	_persist_settings()
	_show_remap(slot)


func _reset_bindings(slot: int) -> void:
	InputRouter.set_bindings(slot, Bindings.defaults_for(InputRouter.source_of(slot).kind))
	_persist_settings()
	_toast("P%d controls restored to defaults." % (slot + 1))
	_show_remap(slot)


func _controls_line(slot: int) -> String:
	var source := InputRouter.source_of(slot)
	var bindings := InputRouter.bindings_of(slot)
	if source == null or bindings == null:
		return "P%d  no input assigned" % (slot + 1)
	var move := "/".join([bindings.prompt_label(Action.LEFT), bindings.prompt_label(Action.RIGHT), bindings.prompt_label(Action.UP), bindings.prompt_label(Action.DOWN)])
	if source.is_gamepad():
		move += " or stick"
	return "P%d %s  Move %s  Jump %s  Attack %s  Special %s  Dodge %s  Revive %s  Pause %s" % [slot + 1, source.short_label(), move, bindings.prompt_label(Action.JUMP), bindings.prompt_label(Action.ATTACK), bindings.prompt_label(Action.SPECIAL), bindings.prompt_label(Action.DASH), bindings.prompt_label(Action.INTERACT), bindings.prompt_label(Action.PAUSE)]


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
	_announce("Reconnect to continue. A controller disconnected.")
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
	var body := "WAVE %02d   /   BEST COMBO %d   /   %d:%02d\n" % [session.wave, session.best_combo, int(summary.seconds) / 60, int(summary.seconds) % 60]
	body += ("ASSISTED RUN: %d%% DAMAGE TAKEN / %d%% SPEED\n\n" % [roundi(session.damage_taken_scale * 100), roundi(session.game_speed * 100)]) if session.assisted() else "\n"
	for i in session.player_states.size():
		var state := session.player_states[i]
		body += "P%d  %s  |  %d KILLS  |  %d COINS SPENT\n\n" % [i + 1, selected[i].name, state.kills, state.spent]
	_label(body, Vector2(460, 380), Vector2(1000, 250), 26, INK)
	_announce(("Victory. The loom is yours. " if won else "Defeat. One more thread? ") + body.replace("|", ","))
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
		var adjust: Callable = menu_buttons[menu_cursor].get_meta("adjust", Callable())
		if adjust.is_valid() and (command.just_pressed(Action.LEFT) or command.just_pressed(Action.RIGHT)):
			adjust.call(1 if command.just_pressed(Action.RIGHT) else -1)
		elif command.just_pressed(Action.DOWN) or command.just_pressed(Action.RIGHT):
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
			_speak_shop(slot)
		elif command.just_pressed(Action.UP) or command.just_pressed(Action.LEFT):
			shop_cursor[slot] = posmod(shop_cursor[slot] - 1, shop_buttons[slot].size())
			_focus_shop()
			_speak_shop(slot)
		elif command.just_pressed(Action.JUMP) or command.just_pressed(Action.ATTACK) or command.just_pressed(Action.INTERACT):
			var button: Button = shop_buttons[slot][shop_cursor[slot]]
			if not button.disabled:
				button.pressed.emit()
				if screen != "shop":
					return


func _focus_menu() -> void:
	menu_cursor = clampi(menu_cursor, 0, maxi(0, menu_buttons.size() - 1))
	for i in menu_buttons.size():
		var button := menu_buttons[i]
		var active := i == menu_cursor
		var primary: bool = button.get_meta("primary", false)
		button.add_theme_stylebox_override("normal", _style(Color("efcf8d") if active else (GOLD if primary else PANEL), INK if active else (GOLD if primary else Color("39535a"))))
		button.add_theme_color_override("font_color", Color("17212a") if active or primary else INK)
	if menu_buttons.is_empty():
		return
	var focused := menu_buttons[menu_cursor]
	var hint := str(focused.get_meta("hint", ""))
	if is_instance_valid(_hint_label):
		_hint_label.text = hint
	var speech := "%s. %s" % [focused.text, hint] if not hint.is_empty() else focused.text
	_speak(speech if _announcement.is_empty() else _announcement + ". " + speech)
	_announcement = ""


func _speak_shop(slot: int) -> void:
	if slot < shop_buttons.size() and not shop_buttons[slot].is_empty():
		var button: Button = shop_buttons[slot][shop_cursor[slot]]
		_speak("Player %d. %s%s" % [slot + 1, button.accessibility_name, ". Not available" if button.disabled else ""])


## Narration queues a screen title until the first focused item is spoken.
func _announce(text: String) -> void:
	if _fresh_screen:
		_announcement = text


func _tts_ready() -> bool:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return false
	if _voice.is_empty():
		var voices := DisplayServer.tts_get_voices_for_language(OS.get_locale_language())
		if voices.is_empty():
			for voice: Dictionary in DisplayServer.tts_get_voices():
				voices.append(str(voice.get("id", "")))
		_voice = voices[0] if not voices.is_empty() else ""
	return not _voice.is_empty()


## Optional OS text-to-speech for menus and notices; silent when disabled.
func _speak(text: String) -> void:
	if not settings.get("narration", false) or text.strip_edges().is_empty() or not _tts_ready():
		return
	DisplayServer.tts_speak(text.replace("\n", ". "), _voice, clampi(roundi(float(settings.master_volume) * 100), 10, 100), 1.0, 1.0, 0, true)


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
		_hud_labels[slot].text = "P%d  %s   %d COINS\n%s%s" % [slot + 1, selected[slot].name, state.coins, "DOWNED - HOLD REVIVE NEARBY" if fighter.downed else "%d / %d HP" % [ceili(fighter.health), ceili(fighter.max_health)], "   AUTO-ATTACK" if fighter.attack_toggle and fighter.auto_attacking and not fighter.downed else ""]
		if fighter.downed != _downed_spoken[slot]:
			_downed_spoken[slot] = fighter.downed
			if fighter.downed:
				_speak("Player %d is down. Partner, hold revive nearby." % (slot + 1))
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
		"countdown": _centre_label.text = "WAVE %02d\n%s" % [session.wave, str(maxi(1, ceili((ArenaRunSession.COUNTDOWN_TICKS - session.phase_ticks) / 60.0)))]
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
			_quit_game()


func browser_focus_lost() -> void:
	if is_instance_valid(session) and screen in ["playing", "shop"]:
		_show_pause()
	InputRouter.flush()


func _quit_game() -> void:
	if OS.has_feature("web"):
		BrowserRuntime.home()
	else:
		get_tree().quit()


func _toast(message: String) -> void:
	if is_instance_valid(_message):
		_message.text = message
		_toast_ticks = 180
		_speak(message)


func _show_error(message: String) -> void:
	_clear_menu("error")
	_shade()
	_label("GLOAMTHREAD NEEDS A COMPLETE BUILD", Vector2(150, 180), Vector2(1600, 100), 40, INK)
	_label(message, Vector2(150, 330), Vector2(1600, 500), 24, INK)
	_button("BROWSER HOME" if OS.has_feature("web") else "QUIT", Rect2(150, 880, 450, 80), _quit_game)


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
	shade.color = Color(0.025, 0.045, 0.065, maxf(alpha, 0.95) if _high_contrast() else alpha)
	shade.size = Vector2(1920, 1080)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)


func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	# High contrast lifts dim borders to ink and thickens every outline.
	style.border_color = INK if _high_contrast() and border.v < 0.5 else border
	style.set_border_width_all(4 if _high_contrast() else 2)
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
	label.add_theme_color_override("font_color", INK if _high_contrast() and color == MUTED else color)
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
	button.add_theme_color_override("font_disabled_color", Color("b4c0c4") if _high_contrast() else Color("74858c"))
	button.accessibility_name = text
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


## A navigable button with a spoken/visible hint and optional Left/Right adjust.
func _option(text: String, rect: Rect2, action: Callable, hint: String, adjust: Callable = Callable()) -> Button:
	var button := _button(text, rect, action)
	button.set_meta("hint", hint)
	button.tooltip_text = hint
	button.accessibility_description = hint
	if adjust.is_valid():
		button.set_meta("adjust", adjust)
	return button


func _high_contrast() -> bool:
	return bool(settings.get("high_contrast", false))


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
