extends Scenario
## Real physics ticks verify swept projectile ordering, walls, lifetime and owned emission.
const PLAYER := preload("res://scenes/actors/player.tscn")
const TARGET := preload("res://tests/fixtures/overhead_actor_target.gd")
const Action := CommandSnapshot.Action

func run() -> void:
	var far := _target_at(Vector2(200, 100))
	var near := _target_at(Vector2(150, 100))
	var bolt := _bolt_at(Vector2(100, 95), Vector2.RIGHT)
	await _steps(28)
	assert_eq(near.hits.size(), 1, "projectile hits the nearest target, regardless of tree order")
	assert_eq(far.hits.size(), 0, "one projectile cannot pass through its first target")
	assert_true(not is_instance_valid(bolt), "impact retires the projectile")
	if not near.hits.is_empty():
		assert_eq(near.hits[0].slow, 90, "Neri applies her bounded slow role")
	var vertical := _target_at(Vector2(300, 150))
	_bolt_at(Vector2(300, 200), Vector2.UP)
	await _steps(20)
	assert_eq(vertical.hits.size(), 1, "vertical projectile uses the Y axis")
	var diagonal := _target_at(Vector2(440, 245))
	_bolt_at(Vector2(400, 200), Vector2.ONE)
	await _steps(20)
	assert_eq(diagonal.hits.size(), 1, "swept projectile supports both axes together")
	var wall := StaticBody2D.new()
	wall.position = Vector2(150, 300)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4, 40)
	collision.shape = shape
	wall.add_child(collision)
	add_child(wall)
	var blocked := _target_at(Vector2(170, 305))
	await _steps(1)
	bolt = _bolt_at(Vector2(100, 300), Vector2.RIGHT)
	await _steps(20)
	assert_eq(blocked.hits.size(), 0, "wall contact wins before targets behind terrain")
	assert_true(not is_instance_valid(bolt), "terrain impact retires projectile")
	bolt = _bolt_at(Vector2(600, 400), Vector2.RIGHT)
	await _steps(47)
	assert_true(is_instance_valid(bolt), "empty-space projectile remains bounded for its declared lifetime")
	await _steps(1)
	assert_true(not is_instance_valid(bolt), "projectile retires on its forty-eighth physics tick")
	# Production player special starts at its ground centre, avoiding a spawn
	# offset that could put a shot through a wall beside the courier.
	InputRouter.clear(0)
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.set_test_input(0, 0)
	var player := PLAYER.instantiate() as PlayerController
	player.special_id = "spore_bolt"
	player.position = Vector2(600, 200)
	player.facing = PlayerController.Facing.UP
	add_child(player)
	var emitted := _target_at(Vector2(600, 170))
	await _steps(2)
	InputRouter.set_test_input(0, Action.SPECIAL)
	await _steps(7)
	assert_eq(get_tree().get_nodes_in_group("combat_transients").size(), 0, "Spore Bolt waits for emission tick eight")
	await _steps(1)
	assert_eq(get_tree().get_nodes_in_group("combat_transients").size(), 1, "Spore Bolt emits exactly once on tick eight")
	await _steps(14)
	assert_eq(emitted.hits.size(), 1, "owned special preserves locked upward facing")
	assert_eq(player.get("_attack_kind"), "", "Spore Bolt shares the twenty-two-tick special contract")
	# Known water is the only flight exception; the next solid wall still wins.
	player.restore(Vector2(600, 100))
	player.facing = PlayerController.Facing.RIGHT
	var water := _body_at(Vector2(628, 100), Vector2(16, 40))
	_body_at(Vector2(680, 100), Vector2(4, 40))
	player.set_room_context(Rect2(0, 0, 1000, 500), Callable(), Callable(), water)
	var beyond_wall := _target_at(Vector2(700, 100))
	InputRouter.set_test_input(0, 0)
	await _steps(2)
	InputRouter.set_test_input(0, Action.SPECIAL)
	await _steps(18)
	var flights := get_tree().get_nodes_in_group("combat_transients")
	assert_eq(flights.size(), 1, "room-owned shot flies over its known water body")
	if flights.size() == 1:
		assert_true(flights[0].global_position.x > 636.0, "shot has crossed the whole water span")
		assert_true(flights[0].get_collision_exceptions().has(water), "flight exception is the exact room water body")
	await _steps(20)
	assert_eq(beyond_wall.hits.size(), 0, "water flight never disables the wall behind it")
	assert_eq(get_tree().get_nodes_in_group("combat_transients").size(), 0, "wall still retires the water-crossing shot")
	InputRouter.clear_test_input()
	InputRouter.clear(0)

func _body_at(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func _target_at(at: Vector2) -> Node2D:
	var target: Node2D = TARGET.new()
	target.position = at
	add_child(target)
	return target

func _bolt_at(at: Vector2, direction: Vector2) -> SporeBolt:
	var bolt := SporeBolt.new()
	bolt.position = at
	bolt.direction = direction
	bolt.attack_id = CombatQuery.next_attack_id()
	add_child(bolt)
	return bolt

func _steps(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
