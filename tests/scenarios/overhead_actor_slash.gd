extends Scenario
## Owned input drives the real motor/attack clock against motionless hit fixtures.
const PLAYER := preload("res://scenes/actors/player.tscn")
const TARGET := preload("res://tests/fixtures/overhead_actor_target.gd")
const Action := CommandSnapshot.Action
var _players: Array[PlayerController] = []

func run() -> void:
	for slot in 2:
		InputRouter.clear(slot)
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
		var player := PLAYER.instantiate() as PlayerController
		player.slot_index = slot
		player.position = Vector2(160, 160)
		add_child(player)
		_players.append(player)
	await _steps(2)
	var directions := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
	for direction_index in 4:
		var player := _players[0]
		player.reset_at(Vector2(160, 160))
		player.facing = direction_index as PlayerController.Facing
		var front: Node2D = TARGET.new()
		front.position = player.position + directions[direction_index] * 24.0
		add_child(front)
		var back: Node2D = TARGET.new()
		back.position = player.position - directions[direction_index] * 24.0
		add_child(back)
		InputRouter.set_test_input(0, Action.ATTACK)
		await _steps(6)
		assert_eq(front.hits.size(), 0, "slash has six complete windup ticks")
		InputRouter.set_test_input(0, Action.ATTACK | Action.RIGHT)
		await _steps(1)
		assert_eq(front.hits.size(), 1, "slash strikes its facing direction at tick seven")
		assert_eq(player.facing, direction_index, "facing locks throughout slash")
		InputRouter.set_test_input(0, Action.ATTACK)
		await _steps(5)
		assert_eq(front.hits.size(), 1, "six active ticks cannot duplicate a swing hit")
		assert_eq(back.hits.size(), 0, "slash does not hit behind the courier")
		await _steps(6)
		assert_eq(player.get("_attack_kind"), "", "slash finishes after eighteen ticks")
		await _steps(8)
		assert_eq(front.hits.size(), 1, "holding attack does not create another edge")
		assert_eq(_players[1].hearts, 5, "overlapping teammate cannot receive friendly fire")
		front.queue_free()
		back.queue_free()
		InputRouter.set_test_input(0, 0)
		await _steps(1)
	# A new edge during the final six ticks queues exactly one next swing.
	InputRouter.set_test_input(0, Action.ATTACK)
	await _steps(12)
	InputRouter.set_test_input(0, 0)
	await _steps(1)
	InputRouter.set_test_input(0, Action.ATTACK)
	await _steps(6)
	assert_eq(_players[0].get("_attack_tick"), 1, "six-tick attack buffer starts the queued swing when recovery ends")
	# The same edge early in a swing expires; it cannot become a delayed attack.
	_players[0].reset_at(Vector2(160, 160))
	InputRouter.set_test_input(0, 0)
	await _steps(1)
	InputRouter.set_test_input(0, Action.ATTACK)
	await _steps(2)
	InputRouter.set_test_input(0, 0)
	await _steps(1)
	InputRouter.set_test_input(0, Action.ATTACK)
	await _steps(18)
	assert_eq(_players[0].get("_attack_kind"), "", "an expired early attack edge is not retained")
	# Two independent swings on one enemy remain separate, with unique attack IDs.
	for player in _players:
		player.reset_at(Vector2(160, 160))
		player.facing = PlayerController.Facing.RIGHT
	var shared: Node2D = TARGET.new()
	shared.position = Vector2(184, 160)
	add_child(shared)
	InputRouter.set_test_input(0, 0)
	InputRouter.set_test_input(1, 0)
	await _steps(1)
	InputRouter.set_test_input(0, Action.ATTACK)
	InputRouter.set_test_input(1, Action.ATTACK)
	await _steps(12)
	assert_eq(shared.hits.size(), 2, "simultaneous couriers each land one swing")
	if shared.hits.size() == 2:
		assert_true(shared.hits[0].attack_id != shared.hits[1].attack_id, "players never share an attack identity")
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)

func _steps(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
