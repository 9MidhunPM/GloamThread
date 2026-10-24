extends Scenario
const FIXTURE := preload("res://tests/arena/actor_fixture.gd")
const Action := CommandSnapshot.Action

func run() -> void:
	var world:Node2D=FIXTURE.new()
	add_child(world)
	world.floor_body()
	var platform:StaticBody2D=world.box(Vector2(200,292),Vector2(112,8),true)
	for slot in 2:
		InputRouter.clear(slot)
		InputRouter.assign(slot,DeviceSource.keyboard_left() if slot==0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot,0)
		var fighter:=ArenaFighter.new()
		fighter.setup(slot,"ember",world,{})
		fighter.position=Vector2(180+slot*40,288)
		world.add_child(fighter)
		world.fighters.append(fighter)
	await _steps(3)
	var first:ArenaFighter=world.fighters[0]
	var second:ArenaFighter=world.fighters[1]
	var first_marker:ArenaOwnershipMarker=first.get_node("OwnershipMarker")
	var second_marker:ArenaOwnershipMarker=second.get_node("OwnershipMarker")
	assert_eq(first_marker.label_text,"P1","first identical appearance has an explicit owned glyph")
	assert_eq(second_marker.label_text,"P2","second identical appearance has an explicit owned glyph")
	assert_true(first_marker.identity_color!=second_marker.identity_color,"owned glyphs also have distinct grounding colors")
	assert_true(first_marker.get_index()<first.get("_avatar").get_index(),"marker renders beneath the accepted appearance")
	InputRouter.set_test_input(0,Action.ATTACK)
	await _steps(1)
	assert_true(not str(first.get("_attack")).is_empty(),"controlled reset interrupts a real attack windup")
	world.phase="shop"
	first.health=64
	first.apply_stats({"damage":25.0})
	first.special_ticks=120
	first.dodge_cooldown=30
	first.reset_for_wave(Vector2(100,320))
	assert_eq(first.health,64.0,"wave reset preserves existing health")
	assert_eq(first.stats.damage,25.0,"wave reset preserves purchased combat stats")
	assert_eq(first.special_ticks,0,"fresh wave refills the manual special")
	assert_eq(first.dodge_cooldown,0,"fresh wave refills dodge")
	assert_eq(first.immunity_ticks,45,"fresh wave grants bounded spawn immunity")
	InputRouter.set_test_input(0,0)
	world.phase="combat"
	await _steps(35)
	assert_eq(world.hits.size(),0,"interrupted old-wave windup cannot attack in the next wave")
	# Begin an actual platform drop, then reset before that body is removed.
	first.position=Vector2(200,288)
	first.velocity=Vector2.ZERO
	await _steps(3)
	InputRouter.set_test_input(0,Action.DOWN|Action.JUMP)
	await _steps(1)
	assert_true(first.get_collision_exceptions().has(platform),"drop fixture owns the contacted one-way exception")
	world.phase="shop"
	first.reset_for_wave(Vector2(100,320))
	assert_true(not first.get_collision_exceptions().has(platform),"wave reset removes the old exception while its body still exists")
	platform.queue_free()
	InputRouter.set_test_input(0,0)
	world.phase="combat"
	await _steps(4)
	assert_true(first.is_on_floor() and absf(first.position.y-320)<0.2,"next wave keeps normal floor collision after interrupted drop")
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)

func _steps(count:int)->void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
