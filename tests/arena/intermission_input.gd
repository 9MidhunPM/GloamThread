extends Scenario
## Actual owned input and shared pause during free exploration, not a bot win.

func run() -> void:
	var app := ArenaApp.new()
	add_child(app)
	await ticks(2)
	app._show_lobby(2)
	for slot in 2:
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
	app._begin_run(18427)
	await ticks(2)
	var world := app.session
	world._open_shop()
	await ticks(3)
	var first := world.fighters[0] as ArenaFighter
	var second := world.fighters[1] as ArenaFighter
	var initial := first.position
	var partner := second.position
	for slot in 2: InputRouter.set_test_input(slot, CommandSnapshot.Action.RIGHT)
	await ticks(16)
	assert_eq(first.position, initial, "open owned shop consumes P1 movement")
	assert_eq(second.position, partner, "open owned shop consumes P2 movement")
	world.set_shop_open(0, false)
	for slot in 2: InputRouter.set_test_input(slot, 0)
	await ticks(2)
	InputRouter.set_test_input(0, CommandSnapshot.Action.RIGHT)
	InputRouter.set_test_input(1, CommandSnapshot.Action.RIGHT)
	await ticks(20)
	assert_true(first.position.x > initial.x + 20, "P1 can explore through owned movement while P2 shops")
	assert_eq(second.position, partner, "P1 exploration never moves the shopping partner")
	for slot in 2: InputRouter.set_test_input(slot, 0)
	first.health = 40
	first.stats.regen = 600
	await ticks(60)
	assert_eq(first.health, 40.0, "untimed intermission cannot farm passive regeneration")
	var phase_ticks := world.phase_ticks
	var at := first.position
	app._show_pause()
	await ticks(20)
	assert_eq(world.phase_ticks, phase_ticks, "shared pause freezes the session beneath always-running menu UI")
	assert_eq(first.position, at, "shared pause freezes exploring actors too")
	app._resume()
	await ticks(2)
	assert_true(not world.shop_open[0] and world.shop_open[1], "resume preserves independent open/closed shop state")
	InputRouter.set_test_input(0, CommandSnapshot.Action.INTERACT)
	await ticks(2)
	assert_true(world.shop_open[0] and not world.shop_ready[0], "owned interact reopens the explorer's shop without readying it")
	assert_eq(world.wave, 1, "exploration and shop reopen never advance a wave")
	InputRouter.set_test_input(0, 0)
	await ticks(2)
	app.shop_cursor[0] = app.shop_buttons[0].size() - 1
	InputRouter.set_test_input(0, CommandSnapshot.Action.ATTACK)
	await ticks(3)
	assert_true(world.shop_ready[0] and not world.shop_open[0], "first owned ready closes only that panel")
	assert_eq(first._attack, "", "held ready confirmation cannot turn into an exploration attack")
	assert_eq(world.wave, 1, "the partner remains free to shop before shared advance")
	app._show_title()
