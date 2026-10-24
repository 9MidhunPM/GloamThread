extends Scenario
## Actual SpriteAnimator + player physics with a diagnostic atlas, not art QA.
const PLAYER := preload("res://scenes/actors/player.tscn")
const CATALOG := preload("res://tests/fixtures/overhead_actor_catalog.gd")
const Action := CommandSnapshot.Action

func run() -> void:
	InputRouter.clear(0)
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.set_test_input(0, 0)
	var catalog: AssetCatalog = CATALOG.new()
	var player := PLAYER.instantiate() as PlayerController
	player.configure({"visual_bundle_id": "test_courier"}, catalog, null)
	player.facing = PlayerController.Facing.RIGHT
	player.position = Vector2(160, 160)
	add_child(player)
	await _steps(2)
	var sprite := player.get_node("Visual/Sprite2D") as Sprite2D
	var animator: SpriteAnimator = player.get("_animator")
	InputRouter.set_test_input(0, Action.ATTACK)
	await _steps(1)
	assert_eq(animator.state, "slash_right", "first swing selects the directional clip")
	assert_eq(_atlas_x(sprite), 0.0, "first swing begins at its windup frame")
	await _steps(11)
	assert_eq(_atlas_x(sprite), 128.0, "first swing reaches its recovery frame without restarting every tick")
	InputRouter.set_test_input(0, 0)
	await _steps(1)
	InputRouter.set_test_input(0, Action.ATTACK)
	await _steps(4)
	assert_eq(_atlas_x(sprite), 128.0, "queued edge does not prematurely restart the active recovery")
	await _steps(1)
	assert_eq(animator.state, "idle_right", "tick eighteen completes the old swing through idle")
	await _steps(1)
	assert_eq(animator.state, "slash_right", "the buffered same-facing swing selects its clip again")
	assert_eq(_atlas_x(sprite), 0.0, "buffered swing restarts at windup frame zero")
	assert_eq(player.get("_attack_tick"), 1, "animation restart matches the new attack serial")
	assert_true(not animator.finished, "buffered swing is a new live clip")
	await _steps(3)
	assert_eq(_atlas_x(sprite), 32.0, "the restarted clip advances normally")
	# Non-loop clips hold their final frame under repeated same-state calls.
	# Warnings/revive cannot silently autorestart after finishing.
	var held_sprite := Sprite2D.new()
	add_child(held_sprite)
	var held := SpriteAnimator.new()
	add_child(held)
	held.configure(held_sprite, catalog, "test_courier")
	held.play("revive_right")
	await _steps(16)
	assert_true(held.finished, "non-loop clip completes once")
	var held_frame := held_sprite.texture
	for tick in 8:
		held.play("revive_right")
		await _steps(1)
	assert_true(held.finished, "same-state calls do not autorestart a finished clip")
	assert_eq(held_sprite.texture, held_frame, "same-state calls hold the final frame")
	assert_true(catalog.errors.is_empty(), "animation fixture uses valid catalog accesses")
	InputRouter.clear_test_input()
	InputRouter.clear(0)

func _atlas_x(sprite: Sprite2D) -> float:
	var atlas := sprite.texture as AtlasTexture
	return -1.0 if atlas == null else atlas.region.position.x

func _steps(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
