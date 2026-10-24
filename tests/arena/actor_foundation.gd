extends Scenario
const FIXTURE := preload("res://tests/arena/actor_fixture.gd")
const Action := CommandSnapshot.Action

func run() -> void:
	var world: Node2D = FIXTURE.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.floor_body()
	world.box(Vector2(8,160), Vector2(16,320))
	world.box(Vector2(632,160), Vector2(16,320))
	for slot in 2:
		InputRouter.clear(slot)
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
		var fighter := ArenaFighter.new()
		fighter.setup(slot, "ember", world, {})
		fighter.position = Vector2(160 + slot * 80, 320)
		world.add_child(fighter)
		world.fighters.append(fighter)
	await _steps(3)
	var first: ArenaFighter = world.fighters[0]
	var second: ArenaFighter = world.fighters[1]
	var second_start := second.position
	InputRouter.set_test_input(0, Action.RIGHT)
	await _steps(20)
	assert_true(first.position.x > 195, "owned input moves the first fighter")
	assert_eq(second.position, second_start, "owned input never moves the other fighter")
	InputRouter.set_test_input(0, Action.ATTACK)
	await _steps(60)
	assert_true(world.hits.size() >= 3, "holding basic attack produces deliberate repeated swings")
	for hit: Dictionary in world.hits: assert_eq(hit.slot, 0, "basic attacks preserve player source")
	var before_health := second.health
	second.take_damage(20, first.position, 0)
	assert_eq(second.health, before_health, "player-owned damage cannot cause friendly fire")
	InputRouter.set_test_input(0, 0)
	await _steps(30)
	InputRouter.set_test_input(0, Action.DASH)
	await _steps(1)
	first.take_damage(20, first.position + Vector2(10,0))
	assert_eq(first.health, 100.0, "dodge starts with bounded evasion")
	await _steps(9)
	first.take_damage(20, first.position + Vector2(10,0))
	assert_eq(first.health, 80.0, "dodge no longer evades after its window")
	assert_eq(world.fighter_hits.size(), 1, "accepted damage notifies the session once")
	var clock := first.dodge_cooldown
	var at := first.position
	world.phase = "shop"
	await _steps(10)
	assert_eq(first.dodge_cooldown, clock, "shop phase freezes actor timers")
	assert_eq(first.position, at, "shop phase freezes actor physics")
	world.phase = "combat"
	first.immunity_ticks = 0
	first.take_damage(1000, first.position)
	assert_true(first.downed, "lethal accepted damage downs the fighter")
	first.revive()
	assert_true(not first.downed and first.health == 35.0, "revive restores the fighter with bounded health")
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)

func _steps(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
