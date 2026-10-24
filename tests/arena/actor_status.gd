extends Scenario
const FIXTURE := preload("res://tests/arena/actor_fixture.gd")
var world: Node2D

func run() -> void:
	world = FIXTURE.new()
	add_child(world)
	world.floor_body()
	for slot in 2:
		InputRouter.clear(slot)
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
		var fighter := ArenaFighter.new()
		fighter.setup(slot,"ember",world,{})
		fighter.position=Vector2(500+slot*50,320)
		world.add_child(fighter)
		world.fighters.append(fighter)
	var enemy:=_enemy(Vector2(100,320))
	var first: ArenaFighter=world.fighters[0]
	first.health=40
	var id:=ArenaCombat.next_id()
	assert_true(enemy.take_damage(20,0,id,{"lifesteal":0.25}),"accepted damage has one combat identity")
	assert_eq(first.health,45.0,"lifesteal heals the actual source using dealt damage")
	assert_true(not enemy.take_damage(20,1,id),"duplicate attack cannot damage or heal twice")
	assert_eq(enemy.health,80.0,"dedup leaves enemy health unchanged")
	var frozen:=_enemy(Vector2(220,320))
	frozen.take_damage(10,1,ArenaCombat.next_id(),{"freeze":2})
	assert_true(frozen.get("_freeze")>0,"freeze strength creates bounded control")
	frozen.take_damage(10,1,ArenaCombat.next_id(),{"shatter":true})
	assert_eq(frozen.health,75.0,"shatter consumes existing freeze for extra damage")
	var marked:=_enemy(Vector2(300,320))
	for hit in 3: marked.take_damage(1,0,ArenaCombat.next_id(),{"mark":1})
	marked.take_damage(10,1,ArenaCombat.next_id(),{"consume_marks":true})
	assert_eq(marked.health,87.0,"other player's shadow attack cannot consume private marks")
	marked.take_damage(10,0,ArenaCombat.next_id(),{"consume_marks":true})
	assert_true(is_equal_approx(marked.health,66.5),"own marks amplify and are consumed once")
	# Controlled DOT attribution: delayed lethal tick retains the source slot.
	var burning:=_enemy(Vector2(400,320))
	burning.health=3
	var payouts: Array[int]=[]
	burning.defeated.connect(func(_enemy: ArenaEnemy,slot:int)->void:payouts.append(slot))
	burning.take_damage(1,1,ArenaCombat.next_id(),{"burn":2})
	world.phase="shop"
	await _steps(35)
	assert_eq(burning.health,2.0,"shop phase cannot advance damage-over-time")
	world.phase="combat"
	await _steps(30)
	assert_eq(payouts,[1],"lethal burn attributes exactly one outcome to its source")
	# Bounded chain uses the same serial and source for every jump.
	for old: Node in world.enemies: old.queue_free()
	world.enemies.clear()
	await _steps(1)
	var chain_a:=_enemy(Vector2(100,320))
	var chain_b:=_enemy(Vector2(150,320))
	var chain_c:=_enemy(Vector2(200,320))
	chain_a.take_damage(10,0,ArenaCombat.next_id(),{"chain":2})
	assert_eq(chain_a.health,90.0,"initial chain target receives base hit")
	assert_eq(chain_b.health,93.0,"first chain jump has bounded falloff")
	assert_true(is_equal_approx(chain_c.health,95.1),"second chain jump has bounded falloff")
	assert_eq(chain_c.get("_last_source"),0,"chain retains source player identity")
	assert_eq(chain_a.get("_received").size(),1,"chain cannot loop back into the first target")
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)

func _enemy(at:Vector2)->ArenaEnemy:
	var enemy:=ArenaEnemy.new()
	enemy.setup("chaser",world,world.enemies.size()+1,1)
	enemy.position=at
	world.add_child(enemy)
	enemy.health=100
	enemy.max_health=100
	world.enemies.append(enemy)
	return enemy

func _steps(count:int)->void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
