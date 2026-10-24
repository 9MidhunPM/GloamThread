extends Scenario
## Real enemy FSMs and bodies; controlled placements isolate attack/collision cases.
const PLAYER := preload("res://scenes/actors/player.tscn")
var _players: Array[PlayerController] = []
var _world: Node2D
var _bounds := Rect2(0, 0, 800, 600)
var _water_rect := Rect2(270, 140, 60, 32)

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
		player.position = Vector2(100 + slot * 400, 180)
		player.immunity_ticks = 10000
		_world.add_child(player)
		_players.append(player)
	var mite := _enemy("spoolmite", Vector2(100, 100))
	await _steps(1)
	assert_eq(mite.get("_state"), "anticipation", "Spoolmite notices a courier on the vertical ground axis")
	assert_eq(mite.position, Vector2(100, 100), "ground enemy windup does not apply gravity")
	var locked: Vector2 = mite.get("_attack_direction")
	_players[0].reset_at(Vector2(180, 180))
	await _steps(30)
	assert_eq(mite.get("_state"), "charge", "Spoolmite completes thirty warning ticks")
	assert_eq(mite.get("_attack_direction"), locked, "Spoolmite does not track during its telegraph")
	await _steps(8)
	assert_true(mite.position.y > 120.0 and absf(mite.position.x - 100.0) < 0.1, "locked charge moves down the overhead plane")
	var frozen := mite.position
	var clock: int = mite.get("_state_ticks")
	get_tree().paused = true
	await _steps(8)
	assert_eq(mite.position, frozen, "shared pause freezes enemy movement")
	assert_eq(mite.get("_state_ticks"), clock, "shared pause freezes enemy attack clocks")
	get_tree().paused = false
	await _steps(16)
	assert_eq(mite.get("_state"), "recovery", "charge exposes a recovery window")
	assert_eq(mite.velocity, Vector2.ZERO, "charge does not coast beyond its active phase")
	assert_true(mite.receive_hit(1, 0, CombatQuery.next_attack_id(), 1, 90), "ordinary enemy accepts Spore slow")
	assert_eq(mite.slow_ticks, 90, "ordinary enemy records bounded slow duration")
	mite.queue_free()
	await _steps(1)
	# Wickwing crosses only the supplied water body, then stops at a solid wall.
	_players[0].reset_at(Vector2(300, 220))
	var water := _body(_water_rect)
	_body(Rect2(270, 190, 60, 4))
	var wing := _enemy("wickwing", Vector2(300, 100))
	wing.set_room_context(_bounds, _dry, Callable(), water)
	await _steps(1)
	assert_true(wing.get_collision_exceptions().has(water), "Wickwing explicitly excepts its known room water")
	assert_eq(wing.position, Vector2(300, 100), "visual hover never changes logical feet during windup")
	await _steps(36)
	assert_eq(wing.get("_state"), "dive", "Wickwing telegraphs before its dive")
	await _steps(32)
	assert_true(wing.position.y > 172.0, "Wickwing traverses the complete water gap")
	assert_true(wing.position.y < 190.1, "Wickwing never disables wall collision")
	assert_eq(wing.get("_state"), "recovery", "wall contact ends a dive in recovery")
	assert_true(wing.hurt_rect().get_center().distance_to(wing.position + Vector2(0, -5)) < 0.1, "hover offset remains separate from the ground hurtbox")
	wing.queue_free()
	water.queue_free()
	await _steps(1)
	# An unblocked flying attack returns toward dry courier approaches, so Tavi
	# can engage it without standing in water. This is a controlled water fixture.
	_players[0].reset_at(Vector2(450, 300))
	_water_rect = Rect2(390, 270, 32, 80)
	water = _body(_water_rect)
	wing = _enemy("wickwing", Vector2(360, 300))
	wing.set_room_context(_bounds, _dry, Callable(), water)
	await _steps(74)
	assert_eq(wing.get("_state"), "recovery", "full dive reaches its visible recovery window")
	await _steps(60)
	assert_true(_dry(wing.position), "Wickwing recovery returns to a dry attack approach")
	assert_true(wing.position.distance_to(_players[0].position) < 32.0, "close-range courier can reach the recovering Wickwing")
	# Both enemy types retain exactly-once defeat and per-attack dedup.
	var deaths: Array[int] = []
	wing.defeated.connect(func(_enemy: CombatEnemy) -> void: deaths.append(1))
	var attack_id := CombatQuery.next_attack_id()
	assert_true(wing.receive_hit(1, 0, attack_id), "first enemy damage is accepted")
	assert_true(not wing.receive_hit(1, 1, attack_id), "one attack identity cannot hit an enemy twice")
	assert_true(wing.receive_hit(1, 1, CombatQuery.next_attack_id()), "distinct attack can defeat enemy")
	assert_true(not wing.receive_hit(1, 0, CombatQuery.next_attack_id()), "defeated enemy rejects later damage")
	assert_eq(deaths.size(), 1, "enemy defeat is emitted exactly once")
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)

func _enemy(kind: String, at: Vector2) -> CombatEnemy:
	var enemy := CombatEnemy.new()
	enemy.position = at
	enemy.configure(kind, _players, null, _bounds)
	_world.add_child(enemy)
	return enemy

func _dry(feet: Vector2) -> bool:
	return not Rect2(feet + Vector2(-6, -10), Vector2(12, 10)).intersects(_water_rect)

func _body(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	_world.add_child(body)
	return body

func _steps(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
