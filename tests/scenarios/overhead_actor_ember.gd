extends Scenario
## Directed special emission uses actual physics line-of-sight and enemy fixtures.
const PLAYER := preload("res://scenes/actors/player.tscn")
const TARGET := preload("res://tests/fixtures/overhead_actor_target.gd")
const Action := CommandSnapshot.Action

func run() -> void:
	InputRouter.clear(0)
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.set_test_input(0, 0)
	var player := PLAYER.instantiate() as PlayerController
	player.position = Vector2(200, 200)
	player.facing = PlayerController.Facing.UP
	add_child(player)
	var front := _target_at(Vector2(200, 168))
	var diagonal := _target_at(Vector2(224, 176))
	var behind := _target_at(Vector2(200, 224))
	var flank := _target_at(Vector2(238, 200))
	var distant := _target_at(Vector2(200, 130))
	await _steps(2)
	InputRouter.set_test_input(0, Action.SPECIAL)
	await _steps(7)
	assert_eq(front.hits.size(), 0, "Ember Arc does not emit before tick eight")
	await _steps(1)
	assert_eq(front.hits.size(), 1, "Ember Arc emits on the eighth tick")
	assert_eq(diagonal.hits.size(), 1, "close fan includes its diagonal shoulder")
	assert_eq(behind.hits.size(), 0, "Ember Arc excludes targets behind its origin")
	assert_eq(flank.hits.size(), 0, "close fan excludes its perpendicular flank")
	assert_eq(distant.hits.size(), 0, "close fan has bounded reach")
	if not front.hits.is_empty():
		assert_eq(front.hits[0].damage, 2, "Ember Arc retains its stronger close damage")
		assert_eq(front.hits[0].stagger, 3, "Ember Arc retains its stagger role")
	await _steps(14)
	assert_eq(front.hits.size(), 1, "special emits only once")
	assert_eq(player.get("_attack_kind"), "", "special recovery finishes after twenty-two ticks")
	# A wall between the ground-plane centres blocks this whole fan hit.
	player.restore(Vector2(200, 200))
	player.facing = PlayerController.Facing.UP
	var wall := StaticBody2D.new()
	wall.position = Vector2(200, 182)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 4)
	collision.shape = shape
	wall.add_child(collision)
	add_child(wall)
	InputRouter.set_test_input(0, 0)
	await _steps(2)
	InputRouter.set_test_input(0, Action.SPECIAL)
	await _steps(8)
	assert_eq(front.hits.size(), 1, "Ember Arc cannot strike through a solid wall")
	InputRouter.clear_test_input()
	InputRouter.clear(0)

func _target_at(at: Vector2) -> Node2D:
	var target: Node2D = TARGET.new()
	target.position = at
	add_child(target)
	return target

func _steps(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
