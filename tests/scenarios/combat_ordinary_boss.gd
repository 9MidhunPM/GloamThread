extends Scenario
## Actual slash input against boss health, with AI attacks isolated. This is
## evidence of no compulsory Cross-stitch gate, not a normal-input boss run.

const PLAYER := preload("res://scenes/actors/player.tscn")


func run() -> void:
	var world := Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(500, 328)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1000, 16)
	collision.shape = shape
	floor_body.add_child(collision)
	world.add_child(floor_body)
	InputRouter.clear(0)
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.set_test_input(0, 0)
	var player := PLAYER.instantiate() as PlayerController
	player.slot_index = 0
	player.position = Vector2(200, 320)
	world.add_child(player)
	var boss := CombatEnemy.new()
	boss.configure("spoolwarden", [], null, Rect2(0, 0, 1000, 400))
	boss.position = Vector2(230, 320)
	world.add_child(boss)
	await _steps(3)
	for _swing in 30:
		InputRouter.set_test_input(0, CommandSnapshot.Action.ATTACK)
		await _steps(25)
		InputRouter.set_test_input(0, 0)
		await _steps(2)
	assert_true(boss.dead, "ordinary slash inputs can finish boss health without Cross-stitch")
	assert_eq(boss.cross_stitch_count, 0, "ordinary defeat did not use optional bonus")
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)


func _steps(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame
		await get_tree().process_frame
