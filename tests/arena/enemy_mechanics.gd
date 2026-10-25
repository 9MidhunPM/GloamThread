extends Scenario
const FIXTURE := preload("res://tests/arena/actor_fixture.gd")

class MechanicWorld extends FIXTURE:
	var shot_ticks: Array[int] = []
	func spawn_projectile(at: Vector2, direction: Vector2, damage: float, slot: int, tags: Dictionary) -> void:
		shot_ticks.append(Engine.get_physics_frames())
		super.spawn_projectile(at,direction,damage,slot,tags)

class OccludedWorld extends MechanicWorld:
	var flight_queries: int = 0
	func flight_anchor(at: Vector2) -> Vector2:
		flight_queries+=1
		return Vector2(at.x,120)
	func navigation_step(_from: Vector2,to: Vector2) -> Dictionary:
		return {"point":Vector2(to.x,120),"jump":false,"drop":false}


func run() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	InputRouter.clear(0)
	InputRouter.assign(0,DeviceSource.keyboard_left())
	InputRouter.set_test_input(0,0)
	await _charger_commitment()
	await _charge_hit_and_wall()
	await _heavy_counters()
	await _chain_contact_side()
	await _shooter_burst_and_pause()
	await _flyer_marked_dive()
	await _flyer_occluded_commitment()
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	assert_eq(ArenaEnemy._reservations.size(),0,"mechanics cleanup releases every close-attack reservation")


func _world(with_flight_navigation: bool=false) -> MechanicWorld:
	var world:MechanicWorld=OccludedWorld.new() if with_flight_navigation else MechanicWorld.new()
	world.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.floor_body()
	var fighter:=ArenaFighter.new()
	fighter.setup(0,"ember",world,{})
	fighter.position=Vector2(360,320)
	fighter.immunity_ticks=10000
	world.add_child(fighter)
	fighter.set_physics_process(false)
	world.fighters.append(fighter)
	return world


func _enemy(world: MechanicWorld, role: String, at: Vector2) -> ArenaEnemy:
	var enemy:=ArenaEnemy.new()
	enemy.setup(role,world,world.enemies.size()+1,1)
	enemy.position=at
	world.add_child(enemy)
	world.enemies.append(enemy)
	return enemy


func _charger_commitment() -> void:
	var world:=_world()
	var enemy:=_enemy(world,"charger",Vector2(220,320))
	await _until(enemy,"windup",50)
	assert_eq(enemy._state,"windup","charger telegraphs from beyond melee range")
	var start:=enemy.position
	var facing:=enemy._facing
	world.fighters[0].position=Vector2(100,320)
	await _steps(15)
	assert_eq(enemy.position,start,"charger stands still during its baitable tell")
	assert_eq(enemy._facing,facing,"crossing the charger during its tell cannot turn the charge")
	await _until(enemy,"active",40)
	assert_eq(enemy._state,"active","charger commits after its full windup")
	await _until(enemy,"recover",40)
	var distance:float=(enemy.position.x-start.x)*facing
	assert_true(distance>=100 and distance<=116,"committed charge has a bounded112px lane; actual "+str(distance))
	assert_eq(world.fighter_hits.size(),0,"stepping behind the locked charge avoids its hit")
	assert_true(enemy._state_ticks>=50,"missed charge leaves a long punish window")
	var stopped:=enemy.position
	await _steps(15)
	assert_eq(enemy.position,stopped,"charge cannot continue sliding through recovery")
	world.free()


func _charge_hit_and_wall() -> void:
	var world:=_world()
	var fighter:ArenaFighter=world.fighters[0]
	fighter.position=Vector2(310,320)
	var enemy:=_enemy(world,"charger",Vector2(220,320))
	await _until(enemy,"active",80)
	for tick in 30:
		fighter.immunity_ticks=0
		await _steps(1)
		if enemy._state=="recover": break
	assert_eq(world.fighter_hits.size(),1,"charge hits each slot once even when fighter immunity is cleared by the fixture")
	assert_eq(fighter.health,88.0,"charge applies its owned base damage once")
	world.free()
	world=_world()
	enemy=_enemy(world,"charger",Vector2(220,320))
	await _until(enemy,"active",80)
	world.box(Vector2(286,270),Vector2(16,100))
	await _until(enemy,"recover",40)
	assert_true(enemy.position.x<270 and enemy._state_ticks>=50,"terrain stops a charge early and exposes the same wall counter window")
	assert_eq(enemy.velocity.x,0.0,"wall impact stops hostile movement immediately")
	world.free()


func _heavy_counters() -> void:
	var world:=_world()
	var enemy:=_enemy(world,"heavy",Vector2(400,320))
	enemy.set_physics_process(false)
	enemy._facing=-1
	world.fighters[0].position=Vector2(500,320)
	var hit:=ArenaCombat.next_id()
	enemy.take_damage(20,0,hit,{"hit_from":Vector2(350,300)})
	assert_true(is_equal_approx(enemy.health,63),"frontal guard accepts35percent chip using contact side, despite owner being behind")
	assert_true(not enemy.take_damage(20,0,hit,{"hit_from":Vector2(450,300)}),"repeating a guarded attack cannot deal or change sides twice")
	enemy.health=100
	enemy.take_damage(20,0,ArenaCombat.next_id(),{"hit_from":Vector2(450,300)})
	assert_eq(enemy.health,75.0,"rear counter bypasses guard and earns25percent bonus")
	assert_true(enemy._state=="recover" and enemy._state_ticks>=36,"rear counter breaks the guarded stance")
	enemy.take_damage(20,0,ArenaCombat.next_id(),{"hit_from":Vector2(350,300)})
	assert_eq(enemy.health,55.0,"guard remains fully open throughout recovery")
	enemy._enter("windup",18)
	enemy.health=100
	enemy.take_damage(20,0,ArenaCombat.next_id(),{"hit_from":Vector2(350,300)})
	assert_eq(enemy.health,80.0,"last18windup ticks are a genuine frontal counter window")
	for control:String in ["freeze","stagger"]:
		enemy._freeze=0;enemy._stagger=0;enemy.health=100
		enemy._enter("windup",48)
		var tags:Dictionary={"hit_from":Vector2(350,300)}
		tags[control]=1 if control=="freeze" else 2
		enemy.take_damage(20,0,ArenaCombat.next_id(),tags)
		assert_eq(enemy.health,75.0,control+" breaks guard instead of losing damage to the shield")
		assert_true(enemy._state=="recover" and enemy._state_ticks>=48,control+" keeps a long explicit broken-guard window")
	enemy._freeze=0;enemy._stagger=0;enemy.health=100
	enemy._enter("approach",0)
	enemy.take_damage(20,0,ArenaCombat.next_id(),{"dot":true,"hit_from":Vector2(350,300)})
	assert_eq(enemy.health,80.0,"damage-over-time ignores facing and guard reduction")
	enemy.health=1
	var outcomes:Array[int]=[]
	enemy.defeated.connect(func(_enemy:ArenaEnemy,slot:int)->void:outcomes.append(slot))
	assert_true(enemy.take_damage(10,0,ArenaCombat.next_id(),{"dot":true}),"accepted lethal packet still defeats guarded actors")
	assert_true(not enemy.take_damage(10,0,ArenaCombat.next_id()),"defeated guard rejects a second lethal packet")
	assert_eq(outcomes,[0],"guarded enemy emits one reward outcome to the lethal source")
	world.free()


func _chain_contact_side() -> void:
	var world:=_world()
	world.fighters[0].position=Vector2(500,320)
	var origin:=_enemy(world,"chaser",Vector2(100,320))
	var heavy:=_enemy(world,"heavy",Vector2(160,320))
	origin.set_physics_process(false);heavy.set_physics_process(false)
	heavy._facing=-1;heavy.health=100
	origin.take_damage(10,0,ArenaCombat.next_id(),{"chain":1,"hit_from":Vector2(500,300)})
	assert_true(is_equal_approx(heavy.health,97.55),"chain guard uses previous enemy contact side rather than copying the original owner position")
	assert_eq(heavy._last_source,0,"chain counter mechanics preserve lethal ownership")
	world.free()


func _shooter_burst_and_pause() -> void:
	var world:=_world()
	var enemy:=_enemy(world,"shooter",Vector2(180,320))
	await _until(enemy,"windup",60)
	assert_eq(enemy._state,"windup","skirmisher stops to announce its aimed burst")
	var start:=enemy.position
	var aim:=enemy._aim
	var clock:=enemy._state_ticks
	var age:=enemy._age
	get_tree().paused=true
	await _steps(12)
	get_tree().paused=false
	assert_eq(enemy._state_ticks,clock,"shared pause freezes windup clock")
	assert_eq(enemy._age,age,"pause freezes animation/combat age without catch-up")
	assert_eq(world.shots.size(),0,"pause cannot emit deferred burst shots")
	world.fighters[0].position=Vector2(420,220)
	await _until(enemy,"active",60)
	assert_eq(enemy.position,start,"shooter stands still through its whole tell")
	await _until(enemy,"recover",35)
	assert_eq(world.shots.size(),3,"one committed burst emits exactly three bounded projectiles")
	if world.shots.size()==3:
		for shot:Dictionary in world.shots:
			assert_eq(shot.direction,aim,"moving after the tell cannot home or retarget later burst shots")
		assert_eq(world.shot_ticks[1]-world.shot_ticks[0],9,"second shot follows a nine tick beat")
		assert_eq(world.shot_ticks[2]-world.shot_ticks[1],9,"third shot follows the same readable beat")
	assert_eq(enemy.position,start,"the full burst is stationary and counterable")
	await _steps(30)
	assert_eq(world.shots.size(),3,"long post-burst cooldown prevents immediate repeated fire")
	world.free()
	world=_world()
	enemy=_enemy(world,"shooter",Vector2(180,320))
	await _until(enemy,"active",80)
	enemy.take_damage(1,0,ArenaCombat.next_id(),{"freeze":1})
	await _steps(22)
	assert_eq(world.shots.size(),1,"control interrupts the remaining burst instead of scheduling ghost shots")
	world.free()


func _flyer_marked_dive() -> void:
	var world:=_world()
	var enemy:=_enemy(world,"flyer",Vector2(240,220))
	await _until(enemy,"windup",70)
	assert_eq(enemy._state,"windup","flyer announces a marked dive")
	var mark:=enemy._target_point
	var point:=enemy._attack_point
	var aim:=enemy._aim
	world.fighters[0].position=Vector2(140,320)
	await _steps(15)
	assert_eq(enemy._target_point,mark,"dive ground mark remains at its announced spot")
	assert_eq(enemy._aim,aim,"dive direction remains committed when the target sidesteps")
	await _until(enemy,"active",40)
	var start:=enemy.position
	await _until(enemy,"recover",50)
	var travel:float=(enemy.position-start).dot(aim)
	assert_true(travel>100 and travel<=160,"dive has bounded travel rather than homing pursuit")
	assert_true(enemy.get_hurt_rect().get_center().distance_to(point)<10,"dive ends near its original marked impact point")
	assert_eq(world.fighter_hits.size(),0,"stepping off the mark avoids the committed dive")
	var low:=enemy.position.y
	await _steps(12)
	assert_true(enemy.position.y<low,"flyer retreats after its vulnerable landing")
	world.free()


func _flyer_occluded_commitment() -> void:
	# A real wall occludes the moved fighter, but not the announced dive point.
	# The spy anchor makes a forbidden mid-attack navigation reset observable.
	var world:=_world(true) as OccludedWorld
	world.box(Vector2(420,240),Vector2(16,160))
	var enemy:=_enemy(world,"flyer",Vector2(240,220))
	await _until(enemy,"windup",70)
	var mark:=enemy._target_point
	var point:=enemy._attack_point
	var aim:=enemy._aim
	world.fighters[0].position=Vector2(470,320)
	await _steps(12)
	assert_eq(enemy._state,"windup","target crossing a solid wall cannot cancel the marked tell")
	assert_eq(world.flight_queries,0,"committed tell cannot ask for a new pursuit route")
	assert_eq(enemy._target_point,mark,"occluded live target cannot replace the ground mark")
	world.fighters[0].position=Vector2(360,320)
	await _until(enemy,"active",60)
	assert_eq(enemy._state,"active","occluded-target tell still reaches its announced attack")
	world.fighters[0].position=Vector2(470,320)
	await _steps(8)
	assert_eq(enemy._state,"active","target crossing a wall during the dive cannot turn it into pursuit")
	assert_eq(enemy._aim,aim,"occlusion during active travel cannot retarget direction")
	await _until(enemy,"recover",50)
	assert_eq(world.flight_queries,0,"marked dive reaches recovery before choosing a new route")
	assert_true(enemy.get_hurt_rect().get_center().distance_to(point)<10,"occluded-target dive finishes at the original announced point")
	assert_eq(world.fighter_hits.size(),0,"the hidden sidestepping target is never hit through solid terrain")
	world.free()
	# If terrain itself blocks the committed lane, the real body must stop and
	# recover, rather than cancel the tell or tunnel toward the marked fighter.
	world=_world(true) as OccludedWorld
	enemy=_enemy(world,"flyer",Vector2(240,220))
	await _until(enemy,"windup",70)
	mark=enemy._target_point
	world.box(Vector2(306,240),Vector2(16,160))
	await _until(enemy,"active",60)
	assert_eq(enemy._state,"active","new obstruction preserves the already committed tell")
	await _until(enemy,"recover",45)
	assert_true(enemy.get_hurt_rect().end.x<=298.2,"real solid collision stops the dive before the wall")
	assert_eq(enemy._target_point,mark,"wall collision never replaces the announced mark")
	assert_eq(world.flight_queries,0,"blocked committed body recovers before it may reroute")
	assert_eq(enemy.velocity,Vector2.ZERO,"solid impact immediately stops committed dive velocity")
	assert_eq(world.fighter_hits.size(),0,"blocked dive cannot damage a fighter across the wall")
	world.free()


func _until(enemy:ArenaEnemy,state:String,limit:int) -> void:
	for tick in limit:
		if enemy._state==state:return
		await _steps(1)


func _steps(count:int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
