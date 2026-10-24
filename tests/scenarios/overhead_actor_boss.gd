extends Scenario
## Actual boss clocks/physics with controlled courier placements, not a route playtest.
const PLAYER := preload("res://scenes/actors/player.tscn")
var _players: Array[PlayerController] = []
var _world: Node2D

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
		player.position = Vector2(300, 300 + (50 if slot == 0 else -50))
		_world.add_child(player)
		_players.append(player)
	var boss := _boss_at(Vector2(300, 300))
	await _until(boss, "anticipation", 50)
	assert_eq(boss.get("_move_name"), "sweep", "boss begins its readable sweep pattern")
	assert_eq(boss.position, Vector2(300, 300), "boss applies no gravity while already in range")
	var direction: Vector2 = boss.get("_attack_direction")
	await _steps(44)
	assert_eq(_players[0].hearts, 5, "sweep telegraph cannot damage couriers")
	assert_eq(boss.get("_attack_direction"), direction, "boss locks its telegraphed sector")
	await _steps(2)
	assert_eq(_players[0].hearts, 4, "sweep reaches its front-facing sector")
	assert_eq(_players[1].hearts, 5, "sweep excludes a courier behind the boss")
	_players[0].immunity_ticks = 0
	_players[0].reset_at(Vector2(300, 350))
	_players[1].reset_at(Vector2(300, 340))
	await _steps(12)
	assert_eq(_players[0].hearts, 4, "one boss sweep cannot re-hit after artificial immunity removal")
	assert_eq(_players[1].hearts, 4, "same shared sweep can hit the other courier once")
	await _until(boss, "recovery", 3)
	assert_eq(boss.velocity, Vector2.ZERO, "sweep exposes stationary recovery")
	await _until(boss, "anticipation", 100)
	assert_eq(boss.get("_move_name"), "strike", "boss advances from sweep to radial strike")
	for slot in 2:
		_players[slot].reset_at(boss.position + Vector2(40 if slot == 0 else -40, 0))
		_players[slot].immunity_ticks = 0
	await _steps(60)
	assert_eq(_players[0].hearts, 4, "strike has sixty complete anticipation ticks")
	await _steps(1)
	assert_eq(_players[0].hearts, 3, "radial strike reaches the courier on one side")
	assert_eq(_players[1].hearts, 3, "radial strike reaches the courier on the opposite side")
	await _until(boss, "recovery", 20)
	_players[0].reset_at(boss.position + Vector2(0, 150))
	_players[1].reset_at(boss.position + Vector2(150, 0))
	for player in _players:
		player.immunity_ticks = 10000
	await _until(boss, "anticipation", 110)
	assert_eq(boss.get("_move_name"), "charge", "boss cycles to a planar line charge")
	var charge_start := boss.position
	direction = boss.get("_attack_direction")
	assert_true(direction.y > 0.9, "charge aims down the overhead plane")
	var wall := _wall_at(boss.position + Vector2(0, 55))
	await _until(boss, "active", 50)
	await _until(boss, "recovery", 40)
	assert_true(boss.position.y > charge_start.y, "boss charge advances along Y")
	assert_true(boss.position.y < wall.position.y - 1.0, "solid wall ends boss charge without crossing")
	assert_true(boss.get_collision_exceptions().is_empty(), "boss never bypasses water or walls")
	wall.queue_free()
	# Stagger/bonus conditions are shared enemy state, with unique attack IDs.
	boss.receive_hit(1, 0, CombatQuery.next_attack_id(), 3, 90)
	boss.receive_hit(1, 0, CombatQuery.next_attack_id(), 3, 90)
	assert_eq(boss.slow_ticks, 0, "boss is immune to Spore slow")
	assert_true(boss.slow_immune_ticks > 0, "slow immunity has a feedback lifetime")
	assert_eq(boss.get("_state"), "stagger", "six stagger points open one shared window")
	var feedback := Label.new()
	boss.add_child(feedback)
	boss.set("_feedback", feedback)
	await _steps(1)
	assert_true(feedback.text.begins_with("Partner strike!"), "slow resistance never conceals the partner-strike opening")
	var health_before := boss.health
	boss.receive_hit(1, 0, CombatQuery.next_attack_id())
	assert_eq(boss.health, health_before - 1, "the stagger initiator receives no partner bonus")
	boss.receive_hit(1, 1, CombatQuery.next_attack_id())
	assert_eq(boss.health, health_before - 6, "the other courier receives one four-damage Cross-stitch bonus")
	boss.receive_hit(1, 1, CombatQuery.next_attack_id())
	assert_eq(boss.health, health_before - 7, "one stagger window cannot pay the bonus twice")
	assert_eq(boss.cross_stitch_count, 1, "one shared bonus is recorded")
	var frozen_health := boss.health
	var frozen_clock: int = boss.get("_state_ticks")
	get_tree().paused = true
	await _steps(20)
	assert_eq(boss.health, frozen_health, "pause does not advance boss damage")
	assert_eq(boss.get("_state_ticks"), frozen_clock, "pause does not expire a Cross-stitch opening")
	get_tree().paused = false
	boss.queue_free()
	await _steps(1)
	# This isolated damage-contract fixture proves optional co-op bonus: all
	# thirty ordinary hits come from one slot and still produce one defeat.
	boss = _boss_at(Vector2(300, 300))
	var defeats: Array[int] = []
	boss.defeated.connect(func(_enemy: CombatEnemy) -> void: defeats.append(1))
	for hit in 30:
		boss.receive_hit(1, 0, CombatQuery.next_attack_id())
	assert_true(boss.dead, "ordinary attacks can defeat the boss without Cross-stitch")
	assert_eq(boss.cross_stitch_count, 0, "optional bonus is never silently required")
	assert_eq(defeats.size(), 1, "boss outcome emits exactly once")
	assert_true(not boss.receive_hit(1, 1, CombatQuery.next_attack_id()), "late damage cannot repeat a boss outcome")
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)

func _boss_at(at: Vector2) -> CombatEnemy:
	var boss := CombatEnemy.new()
	boss.position = at
	boss.configure("spoolwarden", _players, null, Rect2(0, 0, 900, 700))
	_world.add_child(boss)
	return boss

func _wall_at(at: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = at
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(120, 4)
	collision.shape = shape
	wall.add_child(collision)
	_world.add_child(wall)
	return wall

func _until(boss: CombatEnemy, state: String, limit: int) -> void:
	for tick in limit:
		if boss.get("_state") == state:
			return
		await _steps(1)
	assert_eq(boss.get("_state"), state, "boss reaches " + state + " within its declared phase bound")

func _steps(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
