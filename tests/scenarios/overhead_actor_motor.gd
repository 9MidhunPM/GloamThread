extends Scenario
## Real floating bodies with owned snapshots; provisional null-catalog fixtures.

const PLAYER := preload("res://scenes/actors/player.tscn")
const Action := CommandSnapshot.Action
var _world: Node2D
var _players: Array[PlayerController] = []
var _bounds := Rect2(0, 0, 1000, 800)


func run() -> void:
	_world = Node2D.new()
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	for slot in 2:
		InputRouter.clear(slot)
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
		var player := PLAYER.instantiate() as PlayerController
		player.slot_index = slot
		player.configure({"id": "tavi_fixed", "max_hearts": 5}, null, TeamProgress.new())
		player.position = Vector2(100, 100)
		_world.add_child(player)
		player.set_room_context(_bounds, _can_stand, _can_cross)
		_players.append(player)
	var player := _players[0]
	await _steps(10)
	assert_eq(player.position, Vector2(100, 100), "stationary couriers have no gravity drift")
	assert_eq(player.hurt_rect().size, Vector2(12, 10), "combat footprint matches the overhead feet contract")
	assert_eq((player.get_node("CollisionShape2D") as CollisionShape2D).position, Vector2(0, -5), "body is anchored at the feet")
	InputRouter.set_test_input(0, Action.RIGHT)
	await _steps(8)
	var start := player.position
	await _steps(30)
	assert_true(absf(player.position.x - start.x - 55.0) < 0.1, "steady cardinal speed is 110 pixels per second")
	assert_eq(_players[1].position, Vector2(100, 100), "other owner's input remains independent without body blocking")
	assert_eq(player.facing, PlayerController.Facing.RIGHT, "horizontal motion selects right bank")
	InputRouter.set_test_input(0, Action.RIGHT | Action.DOWN)
	await _steps(8)
	start = player.position
	await _steps(30)
	assert_true(absf(player.position.distance_to(start) - 55.0) < 0.1, "diagonal motion is not faster than cardinal motion")
	assert_eq(player.facing, PlayerController.Facing.RIGHT, "diagonal tie preserves a matching prior facing")
	InputRouter.set_test_input(0, Action.UP)
	await _steps(8)
	assert_eq(player.facing_vector, Vector2.UP, "up is real ground-plane movement")
	assert_eq(player.animation_key, "run_up", "semantic run chooses the directional clip key")
	InputRouter.set_test_input(0, 0, 0.3, 0.4)
	await _steps(8)
	start = player.position
	await _steps(30)
	assert_true(player.position.distance_to(start + Vector2(16.5, 22.0)) < 0.1, "analogue magnitude is preserved rather than forced to full speed")
	InputRouter.set_test_input(0, 0)
	player.reset_at(Vector2(-50, -50))
	await _steps(1)
	assert_eq(player.position, Vector2(6, 10), "top and left bounds contain the complete feet footprint")
	player.reset_at(Vector2(1200, 900))
	await _steps(1)
	assert_eq(player.position, Vector2(994, 800), "bottom and right bounds contain the complete feet footprint")
	_wall()
	player.reset_at(Vector2(300, 100))
	InputRouter.set_test_input(0, Action.RIGHT)
	await _steps(60)
	assert_true(player.position.x <= 336.1, "ordinary movement cannot cross a solid wall")
	get_tree().paused = true
	start = player.position
	await _steps(8)
	assert_eq(player.position, start, "shared pause freezes the floating motor")
	get_tree().paused = false
	InputRouter.set_test_input(0, 0)
	player.immunity_ticks = 0
	player.take_hit(player.hearts)
	start = player.position
	InputRouter.set_test_input(0, Action.DOWN)
	await _steps(12)
	assert_eq(player.position, start, "downed courier remains fixed on the ground plane")
	player.revive()
	assert_true(player.hearts == 2 and player.immunity_ticks == 90, "motor migration preserves the revive API")
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)


func _can_stand(feet: Vector2) -> bool:
	return _bounds.encloses(Rect2(feet + Vector2(-6, -10), Vector2(12, 10)))


func _can_cross(_from: Vector2, to: Vector2) -> bool:
	return _can_stand(to)


func _wall() -> void:
	var wall := StaticBody2D.new()
	wall.position = Vector2(350, 100)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 200)
	collision.shape = shape
	wall.add_child(collision)
	_world.add_child(wall)


func _steps(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
