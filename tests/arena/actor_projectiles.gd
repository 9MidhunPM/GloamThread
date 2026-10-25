extends Scenario
## Controlled target placements isolate actual projectile sweep and ownership.
const FIXTURE := preload("res://tests/arena/actor_fixture.gd")

class ImpactTarget extends ArenaEnemy:
	var impacts: Array[Dictionary] = []
	func take_damage(amount: float, slot: int, attack_id: int, tags: Dictionary = {}) -> bool:
		impacts.append({"slot": slot, "id": attack_id, "tags": tags.duplicate(true)})
		return super.take_damage(amount, slot, attack_id, tags)

func run() -> void:
	_check_direct_origins()
	InputRouter.clear(0)
	InputRouter.assign(0,DeviceSource.keyboard_left())
	InputRouter.set_test_input(0,0)
	var world:Node2D=FIXTURE.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.floor_body()
	var fighter:=ArenaFighter.new()
	fighter.setup(0,"frost",world,{})
	fighter.position=Vector2(500,320)
	fighter.health=50
	world.add_child(fighter)
	world.fighters.append(fighter)
	# Far target deliberately enters the list first; sweep order must win.
	var far:=_target(world,Vector2(190,320))
	var near:=_target(world,Vector2(140,320))
	var beyond:=_target(world,Vector2(250,320))
	world.box(Vector2(220,260),Vector2(4,120))
	var source_tags := {"kit":"frost","pierce":5,"freeze":2,"lifesteal":0.1,"critical":true,"hit_from":Vector2(600,300)}
	world.spawn_projectile(Vector2(100,300),Vector2.RIGHT,20,0,source_tags)
	await _steps(30)
	assert_eq(near.health,80.0,"projectile reaches first swept target")
	assert_eq(far.health,80.0,"bounded pierce continues to second target")
	assert_eq(beyond.health,100.0,"terrain stops projectile before target behind a wall")
	assert_eq(fighter.health,54.0,"direct projectile hits apply source-owned lifesteal once each")
	assert_true(near.get("_freeze")>0 and far.get("_freeze")>0,"projectile path applies control upgrades through the same damage boundary")
	assert_eq(near.get("_last_source"),0,"projectile source identity survives travel")
	assert_true(near.impacts[0].tags.get("hit_from") is Vector2 and near.impacts[0].tags.get("hit_from", Vector2.INF).x < near.position.x, "a shot arriving from the left retains that direction when its owner is on the right")
	assert_true(far.impacts[0].tags.get("hit_from", Vector2.INF).x > near.impacts[0].tags.get("hit_from", Vector2.INF).x and far.impacts[0].tags.get("hit_from", Vector2.INF).x < far.position.x, "a piercing shot supplies the local approach side at each later target")
	assert_true(near.impacts[0].tags.get("critical", false) and far.impacts[0].tags.get("critical", false), "impact direction preserves the critical tag on each pierced hit")
	assert_eq(source_tags.hit_from, Vector2(600,300), "impact tags do not mutate the caller's retained packet")
	for old:Node in world.enemies:old.queue_free()
	world.enemies.clear()
	await _steps(1)
	# One piercing charge is one extra hit, with bounded first-to-last travel.
	var a:=_target(world,Vector2(100,320))
	var b:=_target(world,Vector2(140,320))
	var c:=_target(world,Vector2(180,320))
	world.spawn_projectile(Vector2(60,300),Vector2.RIGHT,10,0,{"pierce":1})
	await _steps(30)
	assert_eq(a.health,90.0,"piercing shot hits its first target")
	assert_eq(b.health,90.0,"one pierce allows exactly one extra target")
	assert_eq(c.health,100.0,"pierce exhaustion prevents a third hit")
	var projectile:=ArenaProjectile.new()
	projectile.setup(world,Vector2(350,80),Vector2.RIGHT,10,0,{"life":12})
	world.add_child(projectile)
	await _steps(1)
	var at:=projectile.position
	get_tree().paused = true
	await _steps(15)
	assert_true(is_instance_valid(projectile),"shared pause freezes projectile lifetime")
	assert_eq(projectile.position,at,"shared pause freezes projectile travel")
	get_tree().paused = false
	await _steps(11)
	assert_true(not is_instance_valid(projectile),"projectile lifetime remains bounded by combat ticks")
	projectile = ArenaProjectile.new()
	projectile.setup(world, Vector2(350, 80), Vector2.RIGHT, 10, 0, {"life": 12})
	world.add_child(projectile)
	world.phase = "shop"
	await _steps(15)
	assert_true(not is_instance_valid(projectile), "friendly shots keep a bounded lifetime during free intermission")
	world.phase = "combat"
	# Production callers cap earlier; the actor is also bounded defensively.
	for index in 130:
		var shot:=ArenaProjectile.new()
		shot.setup(world,Vector2(320,100),Vector2.RIGHT,1,0,{})
		world.add_child(shot)
	await _steps(2)
	var count:=0
	for node:Node in get_tree().get_nodes_in_group("arena_projectiles"):
		if node.get("_world")==world:count+=1
	assert_true(count<=128,"actor-level projectile cap prevents unbounded effects")
	InputRouter.clear_test_input()
	InputRouter.clear(0)

func _target(world:Node2D,at:Vector2)->ImpactTarget:
	var enemy:=ImpactTarget.new()
	enemy.setup("chaser",world,world.enemies.size()+1,1)
	enemy.position=at
	world.add_child(enemy)
	enemy.health=100
	enemy.max_health=100
	enemy.set_physics_process(false)
	world.enemies.append(enemy)
	return enemy

func _check_direct_origins() -> void:
	var world: Node2D = FIXTURE.new()
	add_child(world)
	var fighter := ArenaFighter.new()
	fighter.setup(0, "ember", world, {})
	fighter.position = Vector2(100, 320)
	world.add_child(fighter)
	world.fighters.append(fighter)
	fighter.set_physics_process(false)
	# Moving after windup must not leave the guard testing an obsolete source side.
	fighter._start_attack(false)
	fighter.position = Vector2(200, 320)
	fighter._emit_attack(false)
	assert_eq(world.hits[-1].tags.get("hit_from"), fighter.get_hurt_rect().get_center(), "direct melee direction uses the attacker at impact, after movement during windup")
	for family: String in ["stone", "nature"]:
		fighter.kit_id = family
		fighter._start_attack(true)
		fighter.position.x += 30
		fighter._emit_attack(true)
		assert_eq(world.hits[-1].tags.get("hit_from"), fighter.get_hurt_rect().get_center(), "%s area damage retains its actual source point" % family)
	fighter.kit_id = "ember"
	fighter.stats.thorns = 1.0
	fighter.take_damage(10, fighter.position + Vector2(40, 0), -1)
	assert_true(world.hits[-1].tags.get("reflected", false), "reflected damage keeps its existing combat tag")
	assert_eq(world.hits[-1].tags.get("hit_from"), fighter.get_hurt_rect().get_center(), "reflected damage approaches from the struck fighter")
	world.free()

func _steps(count:int)->void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
