extends Scenario
## Roll displacement, owned direction lock and bounded evasion on real bodies.

const PLAYER := preload("res://scenes/actors/player.tscn")
const Action := CommandSnapshot.Action
var _player: PlayerController
var _world: Node2D


func run() -> void:
	_world = Node2D.new()
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	InputRouter.clear(0)
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.set_test_input(0, 0)
	_player = PLAYER.instantiate() as PlayerController
	_player.position = Vector2(100, 100)
	_world.add_child(_player)
	_player.set_room_context(Rect2(0, 0, 500, 400), Callable(), Callable())
	await _steps(2)
	InputRouter.set_test_input(0, Action.RIGHT | Action.JUMP)
	await _steps(1)
	assert_eq(_player.animation_state, "roll", "legacy bit 16 begins the overhead roll")
	assert_true(not _player.take_hit(1), "roll protects its first physics tick")
	InputRouter.set_test_input(0, Action.UP)
	await _steps(5)
	assert_true(not _player.take_hit(1), "sixth roll tick is still protected")
	assert_eq(_player.facing_vector, Vector2.RIGHT, "changing input cannot rotate an active roll")
	var frozen := _player.position
	var frozen_ticks: int = _player.get("roll_ticks")
	get_tree().paused = true
	await _steps(10)
	assert_eq(_player.position, frozen, "pause freezes roll movement")
	assert_eq(_player.get("roll_ticks"), frozen_ticks, "pause freezes roll duration")
	get_tree().paused = false
	await _steps(6)
	assert_true(_player.position.distance_to(Vector2(136, 100)) < 0.1, "twelve 180px/s ticks travel exactly 36px")
	InputRouter.set_test_input(0, 0)
	await _steps(3)
	assert_true(_player.position.distance_to(Vector2(136, 100)) < 0.1, "completed roll leaves no unrequested momentum")
	assert_true(_player.take_hit(1), "roll does not provide immunity after its six-tick window")
	_player.restore(Vector2(100, 200))
	InputRouter.set_test_input(0, 0)
	await _steps(2)
	_obstacle("WaterCollision", Vector2(130, 200))
	InputRouter.set_test_input(0, Action.RIGHT | Action.JUMP)
	await _steps(12)
	assert_true(_player.position.x < 116.1, "roll cannot bypass water collision")
	InputRouter.set_test_input(0, 0)
	await _steps(1)
	InputRouter.set_test_input(0, Action.JUMP)
	await _steps(1)
	assert_eq(_player.get("roll_ticks"), 0, "roll cannot restart during its cooldown")
	_player.restore(Vector2(100, 300))
	InputRouter.set_test_input(0, 0)
	await _steps(2)
	_obstacle("SolidWall", Vector2(130, 300))
	InputRouter.set_test_input(0, Action.RIGHT | Action.JUMP)
	await _steps(12)
	assert_true(_player.position.x < 116.1, "roll never bypasses solid walls")
	InputRouter.clear_test_input()
	InputRouter.clear(0)


func _obstacle(body_name: String, at: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = body_name
	body.position = at
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 48)
	collision.shape = shape
	body.add_child(collision)
	_world.add_child(body)


func _steps(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
