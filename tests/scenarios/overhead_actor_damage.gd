extends Scenario
## Owned input and actual physics cover damage interruption and planar recovery.
const PLAYER := preload("res://scenes/actors/player.tscn")
const TARGET := preload("res://tests/fixtures/overhead_actor_target.gd")
const Action := CommandSnapshot.Action

func run() -> void:
	var world := Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	InputRouter.clear(0)
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.set_test_input(0, 0)
	var player := PLAYER.instantiate() as PlayerController
	player.position = Vector2(200, 200)
	player.facing = PlayerController.Facing.RIGHT
	player.reduced_flash = true
	world.add_child(player)
	var enemy: Node2D = TARGET.new()
	enemy.position = Vector2(224, 200)
	world.add_child(enemy)
	var damage_events: Array[int] = []
	var down_events: Array[int] = []
	player.damage_received.connect(func(_player: PlayerController) -> void: damage_events.append(1))
	player.downed_started.connect(func(_player: PlayerController) -> void: down_events.append(1))
	await _steps(2)
	InputRouter.set_test_input(0, Action.ATTACK)
	await _steps(5)
	assert_true(player.take_hit(1, Vector2(100, 60)), "one valid hit interrupts windup")
	assert_eq(player.animation_state, "hurt", "hurt feedback starts on the accepted hit")
	assert_eq(damage_events.size(), 1, "damage signal emits once per accepted hit")
	assert_true(not player.take_hit(1), "damage immunity rejects repeated contact")
	var at := player.position
	await _steps(4)
	assert_true(player.position.x > at.x and player.position.y > at.y, "knockback moves on both ground-plane axes")
	assert_eq(enemy.hits.size(), 0, "interrupted windup cannot emit a delayed attack")
	var sprite := player.get_node("Visual/Sprite2D") as Sprite2D
	var alpha := sprite.modulate.a
	await _steps(4)
	assert_eq(sprite.modulate.a, alpha, "reduced-flash immunity uses a steady marker")
	assert_true(alpha < 1.0 and alpha > 0.0, "steady immunity marker remains visible")
	var immunity := player.immunity_ticks
	get_tree().paused = true
	await _steps(10)
	assert_eq(player.immunity_ticks, immunity, "pause freezes damage immunity")
	get_tree().paused = false
	InputRouter.set_test_input(0, 0)
	await _steps(immunity)
	assert_eq(player.immunity_ticks, 0, "immunity expires on its physics clock")
	assert_eq(sprite.modulate.a, 1.0, "immunity expiry restores normal opacity")
	assert_true(player.take_hit(100, Vector2(80, -80)), "lethal accepted hit downs the courier")
	assert_eq(player.animation_state, "downed", "downed pose starts with the transition")
	assert_eq(down_events.size(), 1, "downed signal emits once")
	at = player.position
	InputRouter.set_test_input(0, Action.DOWN | Action.ATTACK | Action.JUMP | Action.DASH)
	await _steps(20)
	assert_eq(player.position, at, "downed courier ignores motor and action commands")
	assert_eq(enemy.hits.size(), 0, "downed actions cannot damage targets")
	assert_true(not player.take_hit(1), "downed state rejects repeated damage")
	InputRouter.set_test_input(0, 0)
	player.revive()
	assert_eq(player.hearts, 2, "revive grants exactly two hearts")
	assert_eq(player.immunity_ticks, 90, "revive grants its specified immunity")
	assert_eq(player.animation_state, "revive", "revive feedback starts immediately")
	await _steps(15)
	assert_eq(player.animation_state, "revive", "revive pose lasts for the authored sixteen-tick sequence")
	await _steps(1)
	assert_eq(player.animation_state, "idle", "revive sequence returns to motor presentation on time")
	assert_eq(damage_events.size(), 2, "only the two accepted hits emitted damage")
	player.restore(Vector2(300, 300))
	assert_eq(player.hearts, player.max_hearts, "checkpoint restore returns full health")
	assert_eq(player.velocity, Vector2.ZERO, "checkpoint restore clears knockback")
	assert_eq(player.animation_state, "idle", "checkpoint restore clears transient damage presentation")
	InputRouter.clear_test_input()
	InputRouter.clear(0)

func _steps(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
