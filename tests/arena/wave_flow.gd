extends Scenario
## Controlled production coordinator fixture; not an ordinary-input playthrough.
var catalog: ArenaCatalog
var bundle: Dictionary

func run() -> void:
	catalog=ArenaCatalog.load_catalog()
	var bundles:=FighterLibrary.new().list_bundles()
	assert_true(catalog.errors.is_empty() and not bundles.is_empty(),"wave fixture admits actual content")
	if not catalog.errors.is_empty() or bundles.is_empty():return
	bundle=bundles[0]
	AudioDirector.register_bundle(AssetCatalog.load_from_path("res://assets/manifest.json"))
	assert_true(ArenaAudio.register_original().is_empty(),"production arena audio is registered")
	InputRouter.clear(0);InputRouter.assign(0,DeviceSource.keyboard_left());InputRouter.set_test_input(0,0)
	await _nearby_cave_catchup()
	await _quick_wave_flow()
	InputRouter.clear_test_input();InputRouter.clear(0)

func _world() -> ArenaRunSession:
	var world:=ArenaRunSession.new()
	world.configure(catalog,[bundle],18427)
	add_child(world)
	world.set_physics_process(false)
	for fighter:ArenaFighter in world.fighters: fighter.set_physics_process(false)
	return world

func _nearby_cave_catchup() -> void:
	var world:=_world()
	await ticks(2)
	world.spawn_queue.clear();world.telegraphs.clear();world._set_phase("combat")
	world._spawn_enemy({"role":"chaser","boss":"","elite":false,"position":Vector2(580,624)})
	var enemy:ArenaEnemy=world.enemies[0]
	enemy.set_physics_process(false)
	enemy.take_damage(7,0,ArenaCombat.next_id())
	var identity:=enemy.get_instance_id();var spawn_id:=enemy.spawn_id
	var health:=enemy.health;var original:=enemy.position
	assert_true(enemy.position.distance_to(world.fighters[0].position)<960 and not world._enemy_visible(enemy),"nearby cave survivor is hidden despite being below the old distance threshold")
	for tick in 179:world._process_pursuit()
	assert_true(world.telegraphs.is_empty(),"nearby pursuit still waits its full180ticks")
	world._process_pursuit()
	assert_eq(world.telegraphs.size(),1,"nearby unseen survivor receives one catch-up warning at180ticks")
	if world.telegraphs.size()!=1:
		world.free();return
	var warning:Dictionary=world.telegraphs[0]
	assert_eq(warning.kind,"relocate","warning moves the existing actor instead of spawning a replacement")
	assert_eq(warning.ticks,42,"ordinary catch-up retains42tick safety warning")
	assert_true(warning.position.distance_to(world.fighters[0].position)>=96,"catch-up destination preserves96px player clearance")
	for tick in 41:world._process_spawns()
	assert_eq(enemy.position,original,"catch-up cannot move before the warning expires")
	world._process_spawns()
	assert_eq(enemy.get_instance_id(),identity,"catch-up retains the actual enemy node")
	assert_eq(enemy.spawn_id,spawn_id,"catch-up retains reward identity")
	assert_eq(enemy.health,health,"catch-up preserves damaged health")
	assert_eq(enemy.position,warning.position,"expired warning moves to its validated destination")
	assert_eq(enemy._state,"recover","catch-up gives recovery instead of an immediate attack")
	assert_true(world.telegraphs.is_empty() and world.living_enemies()==1,"catch-up retires its warning without duplicating enemies")
	world.free()

func _quick_wave_flow() -> void:
	var world:=_world()
	await ticks(2)
	for tick in 44:world._physics_process(1.0/60.0)
	assert_eq(world.phase,"countdown","wave-one countdown lasts44full ticks")
	world._physics_process(1.0/60.0)
	assert_eq(world.phase,"combat","wave one begins on countdown tick45")
	var budget:=world.spawn_queue.size()
	world._physics_process(1.0/60.0)
	assert_eq(world.telegraphs.size(),3,"empty combat begins with a three-enemy warned batch")
	for warning:Dictionary in world.telegraphs:
		assert_eq(warning.ticks,24,"normal arrival warning is24ticks")
		assert_true(warning.position.distance_to(world.fighters[0].position)>=96,"initial batch keeps96px clearance")
	var maximum:=0
	var minimum:=INF
	for tick in 110:
		world._physics_process(1.0/60.0)
		maximum=maxi(maximum,world.living_enemies()+world.telegraphs.size())
		for enemy:ArenaEnemy in world.enemies:
			enemy.set_physics_process(false)
			minimum=minf(minimum,enemy.position.distance_to(world.fighters[0].position))
	assert_eq(world.living_enemies(),world.director.live_cap(1),"rapid cadence fills the real solo wave-one cap")
	assert_true(maximum<=world.director.live_cap(1),"live and warned arrivals share one bounded cap")
	assert_true(minimum>=96,"every actual arrival retains minimum player clearance")
	for tick in 150:
		for enemy:ArenaEnemy in world.enemies.duplicate():
			enemy.take_damage(100000,0,ArenaCombat.next_id())
			assert_true(world._spawn_ticks<=1,"accepted kill releases the replenishment cadence gate")
		world._physics_process(1.0/60.0)
		for enemy:ArenaEnemy in world.enemies:enemy.set_physics_process(false)
		if world.phase=="clear":break
	assert_eq(world.phase,"clear","fast kills exhaust the genuine queued wave without stalling")
	assert_eq(world.player_states[0].kills,budget,"all queued actors die and reward exactly once")
	for tick in 23:world._physics_process(1.0/60.0)
	assert_eq(world.phase,"clear","clear presentation remains for23ticks")
	world._physics_process(1.0/60.0)
	assert_eq(world.phase,"shop","wave-one clear reaches the actual shop on tick24")
	world.toggle_ready(0)
	assert_true(world.wave==2 and world.phase=="countdown","owned Ready begins wave two exactly once")
	for tick in 44:world._physics_process(1.0/60.0)
	assert_eq(world.phase,"countdown","wave two preserves the45tick countdown")
	world._physics_process(1.0/60.0)
	assert_eq(world.phase,"combat","wave two starts on its45th countdown tick")
	world.free()
