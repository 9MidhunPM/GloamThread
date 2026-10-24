extends Scenario
const FIXTURE := preload("res://tests/arena/actor_fixture.gd")

func run() -> void:
	InputRouter.clear(0)
	InputRouter.assign(0,DeviceSource.keyboard_left())
	InputRouter.set_test_input(0,0)
	for role:String in ["swarm","chaser","charger","shooter","flyer","heavy"]:
		var world:Node2D=FIXTURE.new()
		add_child(world)
		world.floor_body()
		var fighter:=_fighter(world)
		var enemy:=ArenaEnemy.new()
		enemy.setup(role,world,0,1)
		enemy.position=Vector2(100 if role=="shooter" else 280,320)
		world.add_child(enemy)
		world.enemies.append(enemy)
		var observed:Dictionary={}
		for tick in 180:
			observed[enemy.get("_state")]=true
			await _steps(1)
		assert_true(observed.has("windup") and observed.has("active") and observed.has("recover"),role+" has a complete readable attack cycle")
		if role=="shooter":assert_true(world.shots.size()>0,"shooter emits a real bounded projectile")
		assert_true(fighter.health==100,"scenario immunity prevents accidental test defeat")
		world.free()
	for boss_id:String in ["warden","artillery","tempest","loom"]:
		var world:Node2D=FIXTURE.new()
		add_child(world)
		world.floor_body()
		_fighter(world)
		var boss:=ArenaEnemy.new()
		boss.setup("heavy",world,0,5,false,boss_id)
		boss.position=Vector2(260,320)
		world.add_child(boss)
		world.enemies.append(boss)
		var patterns:Dictionary={}
		for tick in 500:
			if boss.get("_state")=="active":patterns[boss.get("_pattern")]=true
			await _steps(1)
		assert_eq(patterns.size(),3,boss_id+" executes its three distinct pattern phases")
		if boss_id in ["artillery","loom"]:assert_true(world.shots.size()>=8,boss_id+" implements its multi-projectile pattern set")
		boss.take_damage(1,0,ArenaCombat.next_id(),{"freeze":4})
		assert_eq(boss.get("_freeze"),0,"boss control resistance prevents permanent freezing")
		assert_true(boss.get("_slow")>0,"freeze still has a bounded boss slowdown effect")
		world.free()
	# Crowd reservations bound overlapping attack tells without body blocking.
	var crowd:Node2D=FIXTURE.new()
	add_child(crowd)
	crowd.floor_body()
	_fighter(crowd)
	for index in 12:
		var enemy:=ArenaEnemy.new()
		enemy.setup("chaser",crowd,index,1)
		enemy.position=Vector2(300,320)
		crowd.add_child(enemy)
		crowd.enemies.append(enemy)
	await _steps(3)
	var attacking:=0
	for enemy:ArenaEnemy in crowd.enemies:
		if enemy.get("_reserved"):attacking+=1
	assert_true(attacking<=2,"solo crowd admits at most two simultaneous attack reservations")
	assert_true(crowd.enemies[0].position!=crowd.enemies[11].position,"crowd steering separates overlapping enemies")
	crowd.free()
	assert_eq(ArenaEnemy._reservations.size(),0,"leaving encounters releases static weak-reference handles")
	InputRouter.clear_test_input()
	InputRouter.clear(0)

func _fighter(world:Node2D)->ArenaFighter:
	var fighter:=ArenaFighter.new()
	fighter.setup(0,"ember",world,{})
	fighter.position=Vector2(320,320)
	fighter.immunity_ticks=10000
	world.add_child(fighter)
	world.fighters.append(fighter)
	return fighter

func _steps(count:int)->void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
