extends Scenario
const MAP := preload("res://scripts/arena/arena_map.gd")
const Action := CommandSnapshot.Action

class MapWorld:
	extends "res://tests/arena/actor_fixture.gd"
	var map: RefCounted
	func world_bounds() -> Rect2:return map.bounds
	func safe_position(at: Vector2) -> Vector2:return map.safe_position(at)
	func navigation_step(from: Vector2,to: Vector2) -> Dictionary:return map.navigation_step(from,to)
	func movement_allowed(_slot: int) -> bool:return true

func run() -> void:
	InputRouter.clear(0);InputRouter.assign(0,DeviceSource.keyboard_left());InputRouter.set_test_input(0,0)
	var map: RefCounted = MAP.new();map.configure(18427)
	var world := MapWorld.new();world.map=map;world.platforms=map.platforms;add_child(world)
	for chunk: Dictionary in map.chunks:
		for rect: Rect2 in chunk.solids:world.box(rect.get_center(),rect.size)
		for raw: Array in chunk.platforms:world.box(Vector2(float(raw[0])+float(raw[2])/2,float(raw[1])+4),Vector2(float(raw[2]),8),true)
	var fighter := ArenaFighter.new();fighter.setup(0,"ember",world,{});fighter.position=Vector2(270,320);world.add_child(fighter);world.fighters.append(fighter)
	await _steps(3)
	for target: Vector2 in [Vector2(304,224),Vector2(320,624),Vector2(1000,320),Vector2(1600,624)]:
		var reached := await _walk_fighter(fighter,map,target)
		assert_true(reached,"actual owned-input fighter traverses main/raised/cave route to %s; ended %s" % [str(target),str(fighter.position)])
		if not reached:break
	# Controlled pursuit fixture: no reward/session overrides; actual enemy motor,
	# platform exceptions and map instructions must ascend the final cave shaft.
	InputRouter.set_test_input(0,0)
	var entrance: Array = map.chunks[0].platforms[0]
	var exit := Vector2(float(entrance[0])+float(entrance[2])/2,320)
	fighter.position=exit;fighter.velocity=Vector2.ZERO;fighter.immunity_ticks=100000
	var enemy := ArenaEnemy.new();enemy.setup("chaser",world,1,1);enemy.position=Vector2(320,624);world.add_child(enemy);world.enemies.append(enemy)
	await _steps(3)
	var reached := false
	for tick in 3000:
		await _steps(1)
		if absf(enemy.position.y-320)<12 and absf(enemy.position.x-exit.x)<70:
			reached=true;break
	assert_true(reached,"actual chaser leaves cave and reaches main-shaft target; ended %s target%s" % [str(enemy.position),str(exit)])
	InputRouter.clear_test_input();InputRouter.clear(0)

func _walk_fighter(fighter: ArenaFighter,map: RefCounted,target: Vector2) -> bool:
	var hold_jump := 0
	for tick in 3000:
		if fighter.position.distance_to(target)<18 and fighter.is_on_floor():
			InputRouter.set_test_input(0,0);return true
		var step: Dictionary = map.navigation_step(fighter.position,target)
		var gap: float = step.point.x-fighter.position.x
		var held := Action.RIGHT if gap>3 else Action.LEFT if gap< -3 else 0
		if fighter.is_on_floor() and bool(step.drop):held|=Action.DOWN|Action.JUMP;hold_jump=0
		elif fighter.is_on_floor() and bool(step.jump):hold_jump=20
		if hold_jump>0:held|=Action.JUMP;hold_jump-=1
		InputRouter.set_test_input(0,held)
		await _steps(1)
	return false

func _steps(count: int)->void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
