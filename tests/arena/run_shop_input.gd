extends Scenario
## Actual App input regression: both shop panels commit within one physics tick.


func run() -> void:
	var app := ArenaApp.new()
	add_child(app)
	await ticks(2)
	app._show_lobby(2)
	for slot in 2:
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
	app._begin_run()
	await ticks(2)
	app.session.player_states[0].coins = 100
	app.session.player_states[1].coins = 100
	app.session._open_shop()
	await ticks(2)
	var first: Dictionary = app.session.shop_offers[0][0].duplicate(true)
	var second: Dictionary = app.session.shop_offers[1][0].duplicate(true)
	InputRouter.set_test_input(0, CommandSnapshot.Action.ATTACK)
	InputRouter.set_test_input(1, CommandSnapshot.Action.ATTACK)
	await ticks(2)
	assert_eq(app.session.player_states[0].coins, 100 - int(first.price), "same-tick P1 confirmation debits only its owned offer")
	assert_eq(app.session.player_states[1].coins, 100 - int(second.price), "P1 redraw cannot discard same-tick P2 confirmation")
	assert_eq(app.session.player_states[0].rank(first.id), 1, "P1 upgrade commits exactly once")
	assert_eq(app.session.player_states[1].rank(second.id), 1, "P2 upgrade commits exactly once")
	await ticks(3)
	assert_eq(app.session.player_states[0].coins, 100 - int(first.price), "held confirm does not repeat purchases")
	assert_eq(app.session.player_states[1].coins, 100 - int(second.price), "held P2 confirm does not repeat purchases")
	for slot in 2:
		InputRouter.set_test_input(slot, 0)
		for button: Button in app.shop_buttons[slot]:
			assert_eq(button.focus_mode, Control.FOCUS_NONE, "global Godot UI focus cannot bypass owned shop controls")
	await ticks(2)
	var wallets := [app.session.player_states[0].coins, app.session.player_states[1].coins]
	# Godot's default ui_accept is global and may originate from any controller.
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	Input.parse_input_event(accept)
	await ticks(2)
	accept = InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = false
	Input.parse_input_event(accept)
	var foreign_pad := InputEventJoypadButton.new()
	foreign_pad.device = 99
	foreign_pad.button_index = JOY_BUTTON_A
	foreign_pad.pressed = true
	Input.parse_input_event(foreign_pad)
	await ticks(2)
	foreign_pad = InputEventJoypadButton.new()
	foreign_pad.device = 99
	foreign_pad.button_index = JOY_BUTTON_A
	foreign_pad.pressed = false
	Input.parse_input_event(foreign_pad)
	assert_eq(app.session.player_states[0].coins, wallets[0], "unowned global accept cannot spend P1 coins")
	assert_eq(app.session.player_states[1].coins, wallets[1], "unowned global accept cannot spend P2 coins")
	for slot in 2:
		app.shop_cursor[slot] = app.shop_buttons[slot].size() - 1
		InputRouter.set_test_input(slot, CommandSnapshot.Action.ATTACK)
	await ticks(2)
	assert_eq(app.session.wave, 2, "simultaneous ready confirmations advance exactly once")
	assert_eq(app.session.phase, "countdown", "both panels ready leave the shop together")
	app._show_title()
