extends Scenario
## Actual atlas/animator fixture tests direction-hint lifetime, not authored art.
const PLAYER := preload("res://scenes/actors/player.tscn")
const CATALOG := preload("res://tests/fixtures/overhead_actor_catalog.gd")

func run() -> void:
	var world := Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	InputRouter.clear(0)
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.set_test_input(0, 0)
	var player := PLAYER.instantiate() as PlayerController
	player.position = Vector2(300, 180)
	player.immunity_ticks = 10000
	world.add_child(player)
	var catalog: AssetCatalog = CATALOG.new()
	var clips := {}
	for state: String in ["idle", "walk", "anticipation", "charge", "recovery", "defeat"]:
		clips[state] = {"frames": [0], "ticks": [6], "loop": true}
	catalog.add_atlas("spoolmite_v1", Vector2i(32, 32), Vector2i(16, 27), 1, clips)
	catalog.add_atlas("effect_enemy_warning_v1", Vector2i(32, 32), Vector2i(16, 16), 6,
		{"play": {"frames": [0, 1, 2, 3, 4, 5], "ticks": [2, 2, 2, 2, 2, 2], "loop": false}})
	var enemy := CombatEnemy.new()
	enemy.position = Vector2(300, 100)
	enemy.configure("spoolmite", [player], catalog, Rect2(0, 0, 800, 600))
	world.add_child(enemy)
	await _steps(1)
	var marker := enemy.get_node("AttackDirectionHint") as Node2D
	var sprite: Sprite2D = enemy.get("_warning_sprite")
	var animator: SpriteAnimator = enemy.get("_warning_animator")
	assert_true(marker.visible, "real enemy anticipation starts its direction marker")
	assert_true(is_equal_approx(marker.rotation, PI * 0.5), "+X warning rotates one quarter turn toward the target")
	assert_eq(marker.scale, Vector2.ONE, "direction marker rotates without mirroring its authored atlas")
	assert_eq(sprite.offset, Vector2(-16, -16), "warning uses the authored central pivot")
	assert_eq((sprite.texture as AtlasTexture).region.position.x, 0.0, "warning begins at frame zero")
	await _steps(12)
	assert_true(animator.finished, "warning non-loop clip finishes once during the longer windup")
	assert_true(marker.visible, "finished warning remains visible through windup")
	var final_frame := sprite.texture
	await _steps(5)
	assert_eq(sprite.texture, final_frame, "remaining windup ticks hold the last frame instead of restarting")
	assert_eq(player.hearts, 5, "direction hint has no damage effect")
	var remaining: int = enemy.get("_state_ticks")
	get_tree().paused = true
	await _steps(10)
	assert_eq(enemy.get("_state_ticks"), remaining, "pause holds warning lifetime with the shared attack clock")
	assert_eq(sprite.texture, final_frame, "pause holds the warning frame")
	get_tree().paused = false
	await _steps(remaining)
	assert_eq(enemy.get("_state"), "charge", "normal windup reaches the active move")
	assert_true(not marker.visible, "active state clears the direction-only warning")
	assert_true(not animator.is_physics_processing(), "hidden warning stops its presentation clock")
	# Controlled new windups verify each quarter turn and restart serial. The
	# marker remains a direction hint, with no promised sector/radius geometry.
	for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		enemy.set("_attack_direction", direction)
		enemy.call("_enter", "anticipation", 30)
		assert_true(marker.visible, "new windup shows the same authored marker")
		assert_true(Vector2.RIGHT.rotated(marker.rotation).distance_to(direction) < 0.01, "warning supports each cardinal quarter turn")
		assert_eq((sprite.texture as AtlasTexture).region.position.x, 0.0, "new windup serial restarts frame zero")
		enemy.call("_enter", "recovery", 36)
		assert_true(not marker.visible, "state exit clears a warning immediately")
	enemy.call("_enter", "anticipation", 30)
	enemy.receive_hit(100, 0, CombatQuery.next_attack_id())
	assert_true(not marker.visible, "defeat clears warning on the same transition")
	assert_true(catalog.errors.is_empty(), "warning fixture consumes valid catalog entries")
	InputRouter.clear_test_input()
	InputRouter.clear(0)

func _steps(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
