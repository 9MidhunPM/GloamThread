extends Scenario
## Accessibility settings: persistence bounds, assists, remapping and menus.

const Action := CommandSnapshot.Action
const TEMP := "user://test_accessibility_settings.json"


func run() -> void:
	_check_repository()
	var app := ArenaApp.new()
	app.settings_store.path = TEMP
	add_child(app)
	await ticks(2)
	_check_settings_menu(app)
	_check_remap(app)
	await _check_assists(app)
	app._show_title()
	assert_eq(Engine.time_scale, 1.0, "leaving a run restores normal engine time")
	app.free()
	for suffix: String in ["", ".tmp"]:
		if FileAccess.file_exists(TEMP + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP + suffix))


func _check_repository() -> void:
	var store := SettingsRepository.new()
	store.path = TEMP
	var defaults := store.defaults()
	assert_eq(defaults.damage_taken, 1.0, "assists default to off")
	assert_eq(defaults.attack_toggle, [false, false], "hold-to-attack is the default")
	var odd := store._normalise({"damage_taken": 0.1, "game_speed": 3, "attack_toggle": [true], "high_contrast": "yes", "narration": true})
	assert_eq(odd.damage_taken, 1.0, "unlisted damage multipliers are refused")
	assert_eq(odd.game_speed, 1.0, "unlisted game speeds are refused")
	assert_eq(odd.attack_toggle, [false, false], "malformed attack toggles fall back")
	assert_eq(odd.high_contrast, false, "non-boolean contrast flag ignored")
	var chosen := defaults.duplicate(true)
	chosen.merge({"damage_taken": 0.5, "game_speed": 0.6, "attack_toggle": [true, false], "high_contrast": true}, true)
	assert_true(store.save_settings(chosen).ok, "accessibility settings save")
	var loaded: Dictionary = store.load_settings().settings
	assert_eq([loaded.damage_taken, loaded.game_speed, loaded.attack_toggle, loaded.high_contrast], [0.5, 0.6, [true, false], true], "accessibility settings survive a save/load round trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))


func _check_settings_menu(app: ArenaApp) -> void:
	app.settings = app.settings_store.defaults()
	app._show_settings()
	assert_eq(app.screen, "settings", "settings screen opens")
	assert_true(app.menu_buttons.size() >= 15, "settings expose display, audio, accessibility, assist and remap rows")
	app.menu_cursor = 1
	app._focus_menu()
	var adjust: Callable = app.menu_buttons[1].get_meta("adjust", Callable())
	assert_true(adjust.is_valid(), "volume rows accept Left/Right adjustment")
	adjust.call(1)
	assert_eq(app.settings.master_volume, 0.8, "Right raises master volume by one step")
	assert_eq(app.menu_cursor, 1, "changing a value keeps the cursor on that row")
	assert_true(app._hint_label.text.contains("loudness"), "focused option explains itself in a visible hint")
	app._toggle_setting("high_contrast")
	assert_eq(app._style(ArenaApp.PANEL, Color("39535a")).border_width_left, 4, "high contrast thickens outlines")
	app._toggle_narration()
	if not app._tts_ready():
		assert_eq(app.settings.narration, false, "narration stays off when no voice exists")
		assert_true(app._message.text.contains("text-to-speech"), "missing voices are reported, not hidden")
	app._toggle_setting("high_contrast")


func _check_remap(app: ArenaApp) -> void:
	app._show_remap(0)
	assert_eq(app.screen, "remap_0", "P1 remap screen opens")
	assert_eq(app.assign_control(0, Action.JUMP, KEY_K), "", "a free key can be assigned")
	assert_eq(InputRouter.bindings_of(0).keys_for(Action.JUMP), [KEY_K], "the live binding changes immediately")
	assert_true(not app.assign_control(0, Action.ATTACK, KEY_K).is_empty(), "a key already used by another action is refused")
	assert_true(not app.assign_control(0, Action.SPECIAL, KEY_PERIOD).is_empty(), "a key owned by the other keyboard player is refused")
	var saved := Bindings.from_dict(app.settings_store.load_settings().settings.player_bindings[0])
	assert_eq(saved.keys_for(Action.JUMP), [KEY_K], "remapped keys persist")
	app._reset_bindings(0)
	assert_eq(InputRouter.bindings_of(0).keys_for(Action.JUMP), [KEY_SPACE], "reset restores defaults")
	assert_true(app._controls_line(0).contains("Jump Space"), "lobby/settings control text reflects live bindings")


func _check_assists(app: ArenaApp) -> void:
	app.settings.damage_taken = 0.5
	app.settings.game_speed = 0.8
	app.settings.attack_toggle = [true, false]
	app._show_title()
	app._show_lobby(1)
	app._cycle_source(0)
	assert_eq(InputRouter.source_of(0).kind, DeviceSource.Kind.KEYBOARD_RIGHT, "solo P1 can choose the arrow-key side")
	assert_eq(InputRouter.source_of(1).kind, DeviceSource.Kind.KEYBOARD_LEFT, "idle P2 moves to the free keyboard side")
	app._cycle_source(0)
	assert_eq(InputRouter.source_of(0).kind, DeviceSource.Kind.KEYBOARD_LEFT, "cycling returns P1 to WASD")
	app._begin_run(18427)
	await ticks(2)
	assert_eq(Engine.time_scale, 0.8, "game speed assist slows engine time during a run")
	var fighter: ArenaFighter = app.session.fighters[0]
	assert_eq(fighter.damage_taken_scale, 0.5, "damage assist reaches the fighter")
	assert_true(fighter.attack_toggle, "toggle-attack reaches the fighter")
	for _index in 240:
		if app.session.phase == "combat":
			break
		await ticks(1)
	assert_eq(app.session.phase, "combat", "run reaches combat")
	InputRouter.set_test_input(0, Action.ATTACK)
	await ticks(1)
	InputRouter.set_test_input(0, 0)
	await ticks(2)
	assert_true(fighter.auto_attacking, "one Attack press starts repeating attacks")
	InputRouter.set_test_input(0, Action.ATTACK)
	await ticks(1)
	InputRouter.set_test_input(0, 0)
	await ticks(1)
	assert_true(not fighter.auto_attacking, "a second press stops them")
	InputRouter.clear_test_input()
	fighter.health = fighter.max_health
	fighter.immunity_ticks = 0
	fighter._dodge_immunity = 0
	var before := fighter.health
	fighter.take_damage(20.0, fighter.global_position + Vector2(30, 0))
	var expected := 20.0 * (0.8 if fighter.kit_id == "stone" else 1.0) * 0.5
	assert_true(absf(before - fighter.health - expected) < 0.01, "incoming damage is halved by the assist")
	assert_true(app.session.summary().assisted, "assisted runs are labelled in saved summaries")
	app.settings = app.settings_store.defaults()
	app._apply_settings()
	assert_eq(Engine.time_scale, 1.0, "returning speed to 100% restores engine time")
