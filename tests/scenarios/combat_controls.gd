extends Scenario
## Real bodies, actual owned snapshots and physics ticks; no visual/hardware claim.

const PLAYER := preload("res://scenes/actors/player.tscn")
const Action := CommandSnapshot.Action
var _world: Node2D
var _players: Array[PlayerController] = []
var _progress := TeamProgress.new()


func run() -> void:
	_world = Node2D.new()
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	_floor("Solid", Vector2(500, 328), Vector2(1000, 16), false)
	for slot in 2:
		InputRouter.clear(slot)
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
		var player := PLAYER.instantiate() as PlayerController
		player.slot_index = slot
		player.configure({"id": "tavi_fixed" if slot == 0 else "neri_fixed", "max_hearts": 5 if slot == 0 else 4, "special_id": "ember_arc" if slot == 0 else "spore_bolt"}, null, _progress)
		player.position = Vector2(160, 320)
		player.room_bounds = Rect2(0, 0, 1000, 400)
		_world.add_child(player)
		_players.append(player)
	await _steps(4)
	var enemy := _enemy("spoolmite", Vector2(182, 320))
	var hit_sounds_before := int(AudioDirector.emission_counts.get(&"hit", 0))
	InputRouter.set_test_input(0, Action.ATTACK)
	await _steps(18)
	assert_eq(enemy.health, 2, "one slash damages an overlapping enemy only once")
	assert_eq(int(AudioDirector.emission_counts.get(&"hit", 0)) - hit_sounds_before, 1, "one confirmed swing produces one shared hit sound")
	assert_eq(_players[1].hearts, 4, "partner overlap causes no friendly fire")
	await _steps(20)
	assert_eq(enemy.health, 2, "holding attack does not repeat a swing")
	enemy.free()
	await _reset_players()
	enemy = _enemy("spoolmite", Vector2(182, 320))
	InputRouter.set_test_input(0, Action.ATTACK)
	InputRouter.set_test_input(1, Action.ATTACK)
	await _steps(18)
	assert_eq(enemy.health, 1, "independent simultaneous swings both count once")
	enemy.free()
	await _reset_players()
	enemy = _enemy("spoolmite", Vector2(190, 320))
	InputRouter.set_test_input(0, Action.SPECIAL)
	await _steps(22)
	assert_eq(enemy.health, 1, "Ember Arc applies its real two-damage hit once")
	enemy.free()
	await _reset_players()
	enemy = _enemy("spoolmite", Vector2(225, 320))
	InputRouter.set_test_input(1, Action.SPECIAL)
	await _steps(30)
	assert_eq(enemy.health, 2, "Spore Bolt travels to and damages its target")
	assert_true(enemy.slow_ticks > 0, "Spore Bolt applies bounded ordinary-enemy slow")
	assert_eq(_players[0].hearts, 5, "Spore Bolt never hits the overlapping partner")
	enemy.free()
	await _reset_players()
	var wall := _floor("BlockingWall", Vector2(190, 280), Vector2(12, 80), false)
	enemy = _enemy("spoolmite", Vector2(210, 320))
	InputRouter.set_test_input(0, Action.SPECIAL)
	InputRouter.set_test_input(1, Action.SPECIAL)
	await _steps(35)
	assert_eq(enemy.health, 3, "melee and projectile cannot damage through solid terrain")
	assert_true(get_tree().get_nodes_in_group("combat_transients").is_empty(), "terrain collision removes the projectile")
	enemy.free()
	wall.free()
	await _reset_players()
	InputRouter.set_test_input(1, Action.SPECIAL)
	await _steps(60)
	assert_true(get_tree().get_nodes_in_group("combat_transients").is_empty(), "missed projectile expires at its bounded lifetime")
	await _reset_players()
	var first := _players[0]
	first.immunity_ticks = 0
	assert_true(first.take_hit(1), "first enemy hit damages courier")
	assert_true(not first.take_hit(1), "same-tick damage is rejected by immunity")
	first.reduced_flash = true
	await _steps(1)
	var protected_alpha := (first.get_node("Visual/Sprite2D") as Sprite2D).modulate.a
	await _steps(9)
	assert_true(is_equal_approx(protected_alpha, 0.65) and is_equal_approx((first.get_node("Visual/Sprite2D") as Sprite2D).modulate.a, protected_alpha), "reduced-flash immunity uses a steady visible alpha")
	var frozen_immunity := first.immunity_ticks
	get_tree().paused = true
	await _steps(12)
	assert_eq(first.immunity_ticks, frozen_immunity, "pause freezes damage immunity")
	get_tree().paused = false
	first.immunity_ticks = 0
	assert_true(first.take_hit(5), "lethal damage downs the courier")
	assert_true(first.downed and first.hearts == 0, "downed health/state are explicit")
	var down_position := first.position
	InputRouter.set_test_input(0, Action.RIGHT | Action.ATTACK)
	await _steps(10)
	assert_true(absf(first.position.x - down_position.x) < 0.01, "downed courier cannot move or attack")
	assert_eq(first.downed_ticks, 0, "actor leaves the authoritative downed timer to the session")
	first.revive()
	assert_true(not first.downed and first.hearts == 2 and first.immunity_ticks == 90, "revive restores two hearts and protection")
	await _reset_players()
	InputRouter.set_test_input(0, Action.DASH)
	await _steps(2)
	assert_eq(first.dash_ticks, 0, "dash remains locked before team reward")
	_progress.commit_flags(["boss_spoolwarden", "threadstep", "shortcut_bell"])
	InputRouter.set_test_input(0, 0)
	await _steps(2)
	var dash_start := first.position.x
	InputRouter.set_test_input(0, Action.DASH)
	await _steps(12)
	var dash_distance := first.position.x - dash_start
	assert_true(absf(dash_distance - 72.0) < 0.1, "twelve 360px/s ticks produce a 72px grounded dash")
	print("DASH_METRICS " + JSON.stringify({"speed_px_s": 360, "duration_ticks": 12, "ground_distance_px": dash_distance, "physics_hz": 60}))
	await _reset_players()
	InputRouter.set_test_input(0, Action.JUMP)
	await _steps(5)
	var air_start := first.position
	InputRouter.set_test_input(0, Action.JUMP | Action.DASH)
	await _steps(12)
	assert_true(absf(first.position.x - air_start.x - 72.0) < 0.1 and absf(first.position.y - air_start.y) < 0.1, "air dash travels 72px without gravity during its twelve ticks")
	assert_true(first.get("_air_dash_available") == false, "air dash consumes its single airborne charge")
	first.dash_cooldown_ticks = 0
	InputRouter.set_test_input(0, 0)
	await _steps(1)
	InputRouter.set_test_input(0, Action.DASH)
	await _steps(1)
	assert_eq(first.dash_ticks, 0, "airborne charge prevents a second dash even after cooldown")
	await _reset_players()
	_floor("OneWayCollision", Vector2(220, 248), Vector2(200, 16), true)
	first.reset_at(Vector2(200, 240))
	_players[1].reset_at(Vector2(240, 240))
	await _steps(5)
	InputRouter.set_test_input(0, Action.DOWN | Action.JUMP)
	await _steps(24)
	assert_true(first.position.y > 280.0, "down-jump passes through the one-way body")
	assert_true(absf(_players[1].position.y - 240.0) < 0.1, "partner keeps independent one-way collision")
	await _steps(20)
	assert_true(first.is_on_floor() and absf(first.position.y - 320.0) < 0.1, "drop-through preserves solid floor collision")
	_cleanup()


func _steps(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _reset_players() -> void:
	for slot in 2:
		InputRouter.set_test_input(slot, 0)
		_players[slot].restore(Vector2(160, 320))
	await _steps(3)


func _enemy(kind: String, position: Vector2) -> CombatEnemy:
	var enemy := CombatEnemy.new()
	enemy.configure(kind, [], null, Rect2(0, 0, 1000, 400))
	enemy.position = position
	_world.add_child(enemy)
	return enemy


func _floor(body_name: String, position: Vector2, size: Vector2, one_way: bool) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = body_name
	body.position = position
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.one_way_collision = one_way
	collision.one_way_collision_margin = 4.0
	body.add_child(collision)
	_world.add_child(body)
	return body


func _cleanup() -> void:
	get_tree().paused = false
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)
