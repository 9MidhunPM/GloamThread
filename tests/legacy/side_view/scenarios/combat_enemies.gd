extends Scenario

const PLAYER := preload("res://scenes/actors/player.tscn")
var _world: Node2D
var _players: Array[PlayerController] = []


func run() -> void:
	_world = Node2D.new()
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(500, 328)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1000, 16)
	collision.shape = shape
	floor_body.add_child(collision)
	_world.add_child(floor_body)
	for slot in 2:
		InputRouter.clear(slot)
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
		var player := PLAYER.instantiate() as PlayerController
		player.slot_index = slot
		player.position = Vector2(200 + slot * 80, 320)
		_world.add_child(player)
		_players.append(player)
	await _steps(3)
	for kind: String in ["spoolmite", "wickwing"]:
		var enemy := CombatEnemy.new()
		enemy.configure(kind, _players, null, Rect2(0, 0, 1000, 400))
		enemy.position = Vector2(310, 230 if kind == "wickwing" else 320)
		_world.add_child(enemy)
		var seen: Dictionary = {}
		for _tick in 170:
			await _steps(1)
			seen[enemy.animation_state] = true
			for player in _players:
				player.immunity_ticks = 5
		assert_true(seen.has("anticipation"), "%s telegraphs an attack" % kind)
		assert_true(seen.has("dive" if kind == "wickwing" else "charge"), "%s performs its real attack" % kind)
		assert_true(seen.has("recovery"), "%s exposes recovery" % kind)
		enemy.free()
	for kind: String in ["spoolmite", "wickwing"]:
		_players[0].restore(Vector2(200, 320))
		_players[0].immunity_ticks = 0
		_players[1].restore(Vector2(800, 320))
		var nearby := CombatEnemy.new()
		nearby.configure(kind, _players, null, Rect2(0, 0, 1000, 400))
		nearby.position = Vector2(230 if kind == "wickwing" else 220, 230 if kind == "wickwing" else 320)
		_world.add_child(nearby)
		await _steps(100)
		assert_eq(_players[0].hearts, 4, "%s active contact damages a courier once per attack" % kind)
		nearby.free()
	_players[0].restore(Vector2(200, 320))
	_players[1].restore(Vector2(280, 320))
	var boss := CombatEnemy.new()
	boss.configure("spoolwarden", _players, null, Rect2(0, 0, 1000, 400))
	boss.position = Vector2(340, 320)
	_world.add_child(boss)
	var boss_states: Dictionary = {}
	for _tick in 540:
		await _steps(1)
		boss_states[boss.animation_state] = true
		for player in _players:
			player.immunity_ticks = 5
	for move: String in ["sweep", "strike", "charge"]:
		assert_true(boss_states.has(move + "_anticipation") and boss_states.has(move + "_active") and boss_states.has(move + "_recovery"), "boss %s has complete visible phases" % move)
	var first_id := CombatQuery.next_attack_id()
	assert_true(boss.receive_hit(1, 0, first_id, 6, 90), "valid boss hit applies")
	assert_true(not boss.receive_hit(1, 0, first_id, 6, 90), "same attack cannot damage boss twice")
	assert_true(boss.slow_ticks == 0 and boss.slow_immune_ticks > 0, "boss slow immunity supplies feedback state")
	assert_eq(boss.animation_state, "stagger", "stagger exposes boss seam")
	boss.receive_hit(1, 0, CombatQuery.next_attack_id())
	assert_eq(boss.cross_stitch_count, 0, "setup player cannot supply their own follow-up")
	var before := boss.health
	boss.receive_hit(1, 1, CombatQuery.next_attack_id())
	assert_eq(before - boss.health, 5, "other player earns the bounded four-point Cross-stitch bonus")
	boss.receive_hit(1, 1, CombatQuery.next_attack_id())
	assert_eq(boss.cross_stitch_count, 1, "Cross-stitch only fires once in the stagger window")
	var defeat_count := {"value": 0}
	boss.defeated.connect(func(_enemy: CombatEnemy) -> void: defeat_count["value"] += 1)
	while not boss.dead:
		boss.receive_hit(1, 0, CombatQuery.next_attack_id(), 0)
	boss.receive_hit(1, 1, CombatQuery.next_attack_id())
	assert_eq(defeat_count["value"], 1, "boss defeat signal and reward opportunity occur once")
	boss.free()
	var reversed := CombatEnemy.new()
	reversed.configure("spoolwarden", [], null, Rect2(0, 0, 1000, 400))
	_world.add_child(reversed)
	reversed.receive_hit(1, 1, CombatQuery.next_attack_id(), 6)
	reversed.receive_hit(1, 0, CombatQuery.next_attack_id())
	assert_eq(reversed.cross_stitch_count, 1, "either player can set up and finish Cross-stitch")
	reversed.free()
	get_tree().paused = false
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)


func _steps(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame
		await get_tree().process_frame
