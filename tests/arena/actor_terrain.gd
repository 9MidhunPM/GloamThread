extends Scenario
const FIXTURE := preload("res://tests/arena/actor_fixture.gd")
const Action := CommandSnapshot.Action

func run() -> void:
	InputRouter.clear(0)
	InputRouter.assign(0,DeviceSource.keyboard_left())
	InputRouter.set_test_input(0,0)
	var world:Node2D=FIXTURE.new()
	add_child(world)
	world.floor_body()
	var platform:StaticBody2D=world.box(Vector2(200,292),Vector2(112,8),true)
	world.platforms=[[144,288,112]]
	var fighter:=ArenaFighter.new()
	fighter.setup(0,"ember",world,{})
	fighter.position=Vector2(200,320)
	world.add_child(fighter)
	world.fighters.append(fighter)
	await _steps(3)
	InputRouter.set_test_input(0,Action.JUMP)
	var peak:=fighter.position.y
	for tick in 40:
		await _steps(1)
		peak=minf(peak,fighter.position.y)
	assert_true(peak<=272,"canonical jump reaches at least48px above the floor")
	assert_true(fighter.is_on_floor() and absf(fighter.position.y-288)<0.2,"jump lands on a reachable one-way platform")
	InputRouter.set_test_input(0,0)
	await _steps(1)
	InputRouter.set_test_input(0,Action.DOWN|Action.JUMP)
	await _steps(20)
	assert_true(fighter.is_on_floor() and absf(fighter.position.y-320)<0.2,"drop-through preserves the solid arena floor")
	assert_true(not fighter.get_collision_exceptions().has(platform),"drop-through clears its temporary platform exception")
	InputRouter.set_test_input(0,0)
	await _steps(3)
	world.box(Vector2(260,200),Vector2(16,240))
	InputRouter.set_test_input(0,Action.RIGHT|Action.DASH)
	await _steps(10)
	assert_true(fighter.position.x<243.2,"dodge always collides with solid walls")
	InputRouter.set_test_input(0,Action.LEFT)
	await _steps(12)
	assert_true(fighter.position.x<225,"motor recovers away from a wall after dodge")
	# A ground enemy can jump toward a courier on a32px platform.
	fighter.position=Vector2(200,288)
	fighter.velocity=Vector2.ZERO
	fighter.immunity_ticks=10000
	InputRouter.set_test_input(0,0)
	var enemy:=ArenaEnemy.new()
	enemy.setup("chaser",world,1,1)
	enemy.position=Vector2(180,320)
	world.add_child(enemy)
	world.enemies.append(enemy)
	var reached:=false
	for tick in 160:
		await _steps(1)
		reached=reached or enemy.position.y<292
	assert_true(reached,"ground AI can contest a platform instead of leaving a safe perch")
	InputRouter.clear_test_input()
	InputRouter.clear(0)

func _steps(count:int)->void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
