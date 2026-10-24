extends Scenario
## Actual shared session/physics, with explicit test-only geometry and no art.

const SESSION := preload("res://scenes/session/session.tscn")
const Action := CommandSnapshot.Action


func run() -> void:
	InputRouter.clear(0)
	InputRouter.clear(1)
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.assign(1, DeviceSource.keyboard_right())
	InputRouter.set_test_input(0, 0)
	InputRouter.set_test_input(1, 0)
	var session := SESSION.instantiate() as GameSession
	session.fixture_mode = true
	session.room_path = "res://tests/fixtures/m0_room.json"
	add_child(session)
	assert_true(session.session_ready, "the real session starts from its explicit physics fixture: %s" % session.startup_error)
	if not session.session_ready:
		_cleanup()
		return
	await ticks(30)
	assert_eq(session.players.size(), 2, "one instance of each courier")
	assert_eq(session.presentation.room_slot.get_child_count(), 1, "exactly one active room")
	assert_eq(session.presentation.actors.get_child_count(), 3, "two players and one diagnostic mover")
	assert_true(session.presentation.viewport_a.world_2d == session.presentation.viewport_b.world_2d, "both cameras share the same world")
	assert_eq(session.presentation.viewport_a.size, Vector2i(480, 360), "left logical view size")
	assert_eq(session.presentation.viewport_b.size, Vector2i(480, 360), "right logical view size")
	assert_eq(session.presentation.viewport_a.canvas_cull_mask, 3, "Ember view mask")
	assert_eq(session.presentation.viewport_b.canvas_cull_mask, 5, "Moss view mask")
	assert_eq(session.room.theme_gameplay_node_count(), 0, "theme roots contain no gameplay collision")
	assert_true(not session.presentation.viewport_a.audio_listener_enable_2d and not session.presentation.viewport_b.audio_listener_enable_2d, "viewport listeners never duplicate audio")
	var first := session.players[0]
	var second := session.players[1]
	var first_feet := first.position
	var second_feet := second.position
	var mover_before := session.mover.position
	await ticks(30)
	assert_true(first.position.distance_to(first_feet) < 0.1 and second.position.distance_to(second_feet) < 0.1, "both couriers rest stably on canonical ground")
	assert_true(session.mover.position.distance_to(mover_before) > 1.0, "one shared mover advances at physics ticks")
	InputRouter.set_test_input(0, Action.RIGHT)
	await ticks(90)
	assert_true(first.position.x > first_feet.x + 140.0, "owned input moves player one")
	assert_true(second.position.distance_to(second_feet) < 0.1, "player two stays independent")
	assert_true(session.presentation.camera_a.position.x > session.presentation.camera_b.position.x, "camera centres diverge within the same room")
	InputRouter.set_test_input(0, 0)
	await ticks(10)
	first.reset_at(Vector2(152, 320))
	second.reset_at(Vector2(152, 320))
	await ticks(5)
	assert_true(first.position.distance_to(second.position) < 0.1, "courier bodies can overlap without blocking")
	InputRouter.set_test_input(0, Action.JUMP)
	await ticks(8)
	assert_true(first.position.y < second.position.y - 20.0, "only the assigned player jumps")
	InputRouter.set_test_input(0, 0)
	await ticks(40)
	session.set_paused(true)
	var frozen_player := first.position
	var frozen_mover := session.mover.position
	await ticks(30)
	assert_eq(first.position, frozen_player, "shared pause freezes the player")
	assert_eq(session.mover.position, frozen_mover, "shared pause freezes encounter motion")
	session.set_paused(false)
	await ticks(10)
	assert_true(session.mover.position.distance_to(frozen_mover) > 0.1, "resume advances simulation without wall-clock catch-up")
	_cleanup()


func _cleanup() -> void:
	get_tree().paused = false
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)
