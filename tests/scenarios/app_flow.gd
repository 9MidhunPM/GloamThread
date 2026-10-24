extends Scenario
## Screens and persistence are exercised through their public action boundary;
## campaign_route separately drives the complete world with owned commands.

const App := preload("res://scripts/app/app_controller.gd")
const Action := CommandSnapshot.Action

func run() -> void:
	var folder := "user://app-flow-%d" % Time.get_ticks_usec()
	var app := App.new()
	app.saves.path = folder + "/save.json"
	app.settings_store.path = folder + "/settings.json"
	add_child(app)
	await ticks(2)
	assert_eq(app.screen, "title", "boot opens title rather than silently starting players")
	app._on_action("new")
	assert_eq(app.screen, "join", "new journey requires explicit input assignment")
	assert_true(app._devices_ready(), "distinct default keyboard zones are ready")
	app._on_action("swap")
	app._on_action("start")
	assert_true(is_instance_valid(app.session) and app.session.session_ready, "join starts a validated campaign")
	assert_eq(app.session.progress.profile_ids, ["neri_fixed", "tavi_fixed"], "character swap preserves fixed profiles")
	assert_eq(app.session.presentation.viewport_a.canvas_cull_mask, 5, "P1 swapped character receives Moss view")
	assert_eq(app.session.presentation.viewport_b.canvas_cull_mask, 3, "P2 swapped character receives Ember view")
	app.session._focus_pause_enabled = false
	InputRouter.set_test_input(0, 0)
	InputRouter.set_test_input(1, 0)
	await ticks(3)
	InputRouter.set_test_input(1, Action.PAUSE)
	await ticks(2)
	assert_eq(app.screen, "pause", "either owned player can open shared pause")
	assert_eq(app.menu_owner, 1, "requesting player owns the menu")
	assert_true(get_tree().paused, "pause freezes both views' shared world")
	InputRouter.set_test_input(1, 0)
	var positions := [app.session.players[0].position, app.session.players[1].position]
	await ticks(5)
	assert_eq(app.session.players[0].position, positions[0], "P1 is frozen in menu")
	assert_eq(app.session.players[1].position, positions[1], "P2 is frozen in menu")
	app._on_action("map")
	assert_eq(app.screen, "map", "map is a shared screen")
	app._on_action("cancel")
	app.session.request_mode("pause", 0)
	app._on_action("settings")
	app._on_action("master_volume", {"direction": -1})
	app._on_action("reduced_flash")
	assert_true(app.session.players[0].reduced_flash and app.session.players[1].reduced_flash, "accessibility changes reach both couriers")
	app._on_action("controls_0")
	app._on_action("bind_0_%d" % Action.ATTACK)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_H
	key.pressed = true
	app._input(key)
	assert_eq(InputRouter.bindings_of(0).keys_for(Action.ATTACK), [KEY_H], "remapping persists an owned physical key")
	app._on_action("back")
	app._on_action("back")
	# A checkpoint's success story must not hide an actual disk failure.
	app._toast_ticks = 0
	app._notices.clear()
	app.saves.failure_stage = "write"
	app.session._activate_checkpoint({"checkpoint_id":"checkpoint_a", "id":"rest_lantern"})
	assert_true(not app.session.last_save_error.is_empty(), "failed durability is retained in session status")
	assert_true(app._toast.text.contains("save") or app._toast.text.contains("Save"), "save failure reaches visible toast before success story")
	assert_true(not app._notices.is_empty(), "same-tick success notice is queued rather than overwriting failure")
	app.saves.failure_stage = ""
	app._on_action("save")
	assert_eq(app.session.last_save_error, "", "successful retry clears persistent durability error")
	app._on_action("title")
	assert_eq(app.screen, "title", "return to title disposes the old campaign")
	app._on_action("continue")
	app._on_action("start")
	assert_eq(app.session.progress.profile_ids, ["neri_fixed", "tavi_fixed"], "Continue loads saved characters")
	assert_eq(app.session.current_room_id, "r00", "Continue loads validated checkpoint room")
	app.session._focus_pause_enabled = false
	app.session.request_mode("pause", 0)
	app._on_action("title")
	app.free()
	get_tree().paused = false
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)
	var dir := DirAccess.open(folder)
	if dir != null:
		for file: String in dir.get_files():
			dir.remove(file)
	DirAccess.remove_absolute(folder)
