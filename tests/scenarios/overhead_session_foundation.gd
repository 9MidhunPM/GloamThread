extends Scenario
## Isolated coordinator fixtures; placements are deliberate and are not a campaign playthrough.
const SESSION := preload("res://scenes/session/session.tscn")
const Action := CommandSnapshot.Action
var _session: GameSession


func run() -> void:
	for slot in 2:
		InputRouter.clear(slot)
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
	await _home_dialogue()
	await _bridge_and_hazard()
	await _actor_contexts()
	get_tree().paused = false
	if is_instance_valid(_session):
		_session.free()
	for slot in 2:
		InputRouter.set_test_input(slot, 0)
		InputRouter.clear_test_input(slot)
		InputRouter.clear(slot)
	AudioDirector.stop_music()
	AudioDirector.stop_cues()


func _start(path: String) -> void:
	if is_instance_valid(_session):
		_session.free()
	_session = SESSION.instantiate() as GameSession
	_session.fixture_mode = true
	_session.room_path = path
	_session.set("_focus_pause_enabled", false)
	add_child(_session)
	assert_true(_session.session_ready, "overhead fixture session starts: %s" % _session.startup_error)


func _home_dialogue() -> void:
	_start("res://content/rooms/r00.json")
	if not _session.session_ready:
		return
	assert_true(_session.presentation.viewport_a.world_2d == _session.presentation.viewport_b.world_2d, "both views share one authoritative World2D")
	assert_true(_session.presentation.actors.y_sort_enabled, "actors and props share one sortable branch")
	assert_true(_session.room.entity_visuals.get_parent() == _session.presentation.actors, "room props are nested under the actor sorting parent")
	assert_eq(FollowCamera.TARGET_OFFSET, Vector2(0,-5), "camera follows the planar collision centre")
	for actor in _session.players:
		actor.set_physics_process(false)
	_session.players[0].reset_at(RoomDefinition.feet_position(Vector2i(15,11)))
	_session.players[1].reset_at(RoomDefinition.feet_position(Vector2i(7,18)))
	await _steps(2)
	assert_true(_session.interaction_hints[0].contains("Oru"), "nearby living player gets Oru prompt")
	assert_eq(_session.interaction_hints[1], "", "distant partner never inherits another player's prompt")
	assert_true(_session.presentation.hud_a.text.contains("Roll "), "HUD names the bound roll action")
	assert_true(_session.presentation.hud_b.text.contains("Dash locked"), "HUD explicitly shows the locked team dash")
	InputRouter.set_test_input(0, Action.INTERACT)
	await _steps(1)
	assert_eq(_session.mode, "dialogue", "owned interaction starts Oru's dialogue")
	assert_true(not _session.progress.has_flag("met_oru"), "opening dialogue alone does not commit introduction")
	assert_true(get_tree().paused, "dialogue pauses the shared world")
	assert_true(_session.complete_dialogue(), "UI completion boundary commits the finished dialogue")
	assert_true(_session.progress.has_flag("met_oru"), "completed intro opens the shared introduction gate")
	assert_eq(_session.mode, "playing", "completed dialogue returns to play")
	assert_true(not _session.complete_dialogue(), "repeated UI completion outside dialogue is ignored")
	InputRouter.set_test_input(0, 0)
	await _steps(1)
	_session.request_mode("pause", 1)
	var frozen := _session.players[0].position
	await _steps(3)
	assert_eq(_session.players[0].position, frozen, "pause freezes both-view simulation")
	_session.request_mode("playing", 1)


func _bridge_and_hazard() -> void:
	_start("res://tests/fixtures/overhead_world_room.json")
	if not _session.session_ready:
		return
	assert_eq(_session.current_room_id, "r02", "fixture keeps its validated room identity")
	for actor in _session.players:
		actor.set_physics_process(false)
	_session.players[0].reset_at(RoomDefinition.feet_position(Vector2i(9,8)))
	_session.players[1].reset_at(RoomDefinition.feet_position(Vector2i(9,14)))
	await _steps(2)
	var blocker := _session.room.water_body.get_node("Bridge_bridge_spindle") as CollisionShape2D
	var shapes := _session.room.water_body.get_child_count()
	for slot in 2:
		InputRouter.set_test_input(slot, Action.INTERACT)
	await _steps(1)
	assert_true(_session.progress.has_flag("bridge_spindle"), "same-tick distinct owned presses restore the pair once")
	assert_true(blocker.disabled, "session transaction removes only the named water blocker")
	assert_eq(_session.room.water_body.get_child_count(), shapes, "repair never creates another collision body or floor")
	for slot in 2:
		InputRouter.set_test_input(slot, 0)
	await _steps(1)
	var player := _session.players[0]
	player.reset_at(Vector2(72,270))
	player.immunity_ticks = 0
	var hearts := player.hearts
	await _steps(1)
	assert_eq(player.hearts, hearts, "hazards do not hit an obsolete tall side-view body")
	player.reset_at(Vector2(72,250))
	await _steps(1)
	assert_eq(player.hearts, hearts-1, "walkable hazard hits the real planar hurt rectangle")
	assert_true(is_equal_approx(player.velocity.length(),60.0), "hazard knockback is a planar sixty-pixel vector")
	player.restore(RoomDefinition.feet_position(Vector2i(10,17)))
	player.set_physics_process(true)
	InputRouter.set_test_input(0, Action.RIGHT)
	await _steps(24)
	assert_true(player.position.x < 186.1, "session-wired actor stops against water outside the repair")
	assert_true(_session.room.can_stand_at(player.position), "actor remains on a safe dry footprint")
	InputRouter.set_test_input(0, 0)
	player.set_physics_process(false)
	player.immunity_ticks = 0
	player.take_hit(player.max_hearts)
	_session.players[1].reset_at(player.position+Vector2(-24,0))
	await _steps(1)
	assert_eq(_session.interaction_hints[0], "", "downed player receives no local action prompt")
	assert_true(_session.interaction_hints[1].contains("revive"), "only living nearby partner receives rescue action")
	var bottom := _session.presentation.get("_objective_a") as Label
	assert_true(bottom.text.contains("Your partner"), "downed view shows passive rescue guidance")
	_session.players[0].revive()


func _actor_contexts() -> void:
	_session.room_path = "res://content/rooms/r03.json"
	assert_true(_session.call("_load_room", "r03", "from_r02", true), "encounter fixture loads authored Gallery geometry")
	assert_eq(_session.enemies.size(), 4, "one shared instance of each authored Gallery enemy")
	for enemy in _session.enemies:
		assert_true(enemy.get("_water_body") == _session.room.water_body, "each enemy receives this room's water body")
		var query: Callable = enemy.get("_can_stand")
		assert_true(query.is_valid(), "enemy receives the authoritative dry footprint query")
		if enemy.kind == "wickwing":
			assert_true(enemy.get_collision_exceptions().has(_session.room.water_body), "hovering enemy bypasses only this room's water body")
	_session.room_path = "res://content/rooms/r01.json"
	assert_true(_session.call("_load_room", "r01", "from_r00", true), "dash fixture loads the authored Atrium gap")
	assert_eq(_session.enemies.size(), 0, "room replacement removes the previous encounter once")
	_session.progress.commit_flags(["boss_spoolwarden", "threadstep", "shortcut_bell"])
	var player := _session.players[0]
	player.reset_at(Vector2(626,109))
	player.set_physics_process(true)
	InputRouter.set_test_input(0, Action.RIGHT | Action.DASH)
	await _steps(12)
	InputRouter.set_test_input(0, 0)
	assert_true(player.position.distance_to(Vector2(686,109)) < 0.1, "session-wired normal dash input crosses the authored two-tile gap")
	assert_true(_session.room.can_stand_at(player.position), "session dash ends with a completely dry footprint")
	assert_true(not player.get_collision_exceptions().has(_session.room.water_body), "session dash restores water collision at landing")
	await _steps(1)
	assert_true(not _session.presentation.hud_a.text.contains("Dash locked"), "shared unlock updates both HUDs")


func _steps(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
