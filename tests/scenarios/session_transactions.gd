extends Scenario
## Controlled placements isolate the real coordinator's transactions. Actors
## are frozen for fixture positioning; this is not a normal-input route run.

const SESSION := preload("res://scenes/session/session.tscn")
const Action := CommandSnapshot.Action
var _session: GameSession


func run() -> void:
	InputRouter.clear(0)
	InputRouter.clear(1)
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.assign(1, DeviceSource.keyboard_right())
	InputRouter.set_test_input(0, 0)
	InputRouter.set_test_input(1, 0)
	_session = SESSION.instantiate() as GameSession
	_session.set("_focus_pause_enabled", false)
	add_child(_session)
	assert_true(_session.session_ready, "production session starts for transaction fixtures: %s" % _session.startup_error)
	if not _session.session_ready:
		_cleanup()
		return
	_freeze_actors()
	await _steps(2)
	await _check_latches()
	await _check_exit_rally()
	await _check_revive()
	await _check_boss_then_wipe()
	await _retire_audio()
	_cleanup()


func _check_latches() -> void:
	assert_true(_session.call("_load_room", "r02", "from_r01", true), "controlled fixture loads Spindle Steps")
	_freeze_actors()
	var pair := _entity("spindle_pair")
	var points: Array = pair.anchors
	var before_shapes := _session.room.collision.get_child_count()
	var before_sounds := int(AudioDirector.emission_counts.get(&"bridge_restored", 0))
	_session.players[0].reset_at(GameSession._centre(points[0].tile))
	_session.players[1].reset_at(Vector2(104, 352))
	await _press(0)
	assert_true(not _session.progress.has_flag("bridge_spindle"), "one anchor cannot restore the bridge")
	_session.players[0].reset_at(GameSession._centre(points[1].tile))
	await _press(0)
	assert_true(not _session.progress.has_flag("bridge_spindle"), "the same slot cannot claim both anchor ends")
	assert_eq(_session.room.collision.get_child_count(), before_shapes, "incomplete pair adds no collision")
	_session.players[1].reset_at(GameSession._centre(points[1].tile))
	await _press(1)
	assert_true(_session.progress.has_flag("bridge_spindle"), "different slots complete the paired anchor transaction")
	assert_eq(_session.room.collision.get_child_count(), before_shapes + 1, "bridge completion adds exactly one shared collider")
	assert_eq(int(AudioDirector.emission_counts.get(&"bridge_restored", 0)) - before_sounds, 1, "bridge restoration sounds exactly once")
	await _press(1)
	_session.room.set_progress(_session.progress.flags)
	assert_eq(_session.room.collision.get_child_count(), before_shapes + 1, "repeated interaction and progress replay never duplicate the bridge")
	assert_eq(int(AudioDirector.emission_counts.get(&"bridge_restored", 0)) - before_sounds, 1, "completed pair never repeats its reward cue")

	_session.progress.commit_flags(["boss_spoolwarden", "threadstep", "shortcut_bell"])
	assert_true(_session.call("_load_room", "r06", "from_r01", true), "controlled fixture loads second anchor pair")
	_freeze_actors()
	pair = _entity("causeway_pair")
	points = pair.anchors
	for slot in 2:
		_session.players[slot].reset_at(GameSession._centre(points[slot].tile))
		InputRouter.set_test_input(slot, Action.INTERACT)
	await _steps(1)
	assert_true(_session.progress.has_flag("bridge_causeway"), "simultaneous distinct anchor presses both survive one physics tick")
	await _release()


func _check_exit_rally() -> void:
	assert_true(_session.call("_load_room", "r00", "start", true), "controlled fixture reloads the start room")
	_freeze_actors()
	var exit := _entity("to_atrium")
	var rally := GameSession._tile_rect(exit.rect).get_center()
	_session.players[0].reset_at(rally)
	_session.players[1].reset_at(Vector2(104, 320))
	assert_true(not _session.request_transition("to_atrium", 0), "one player cannot leave the partner in another room")
	_session.players[1].reset_at(rally)
	_session.players[1].immunity_ticks = 0
	_session.players[1].take_hit(_session.players[1].max_hearts)
	assert_true(not _session.request_transition("to_atrium", 0), "a downed partner cannot satisfy the exit rally")
	_session.players[1].revive()
	var before_transitions := _session.transition_count
	InputRouter.set_test_input(0, Action.INTERACT)
	InputRouter.set_test_input(1, Action.INTERACT)
	await _steps(2)
	assert_eq(_session.current_room_id, "r01", "both living couriers enter the validated destination")
	assert_eq(_session.transition_count, before_transitions + 1, "simultaneous exit presses replace the room once")
	assert_eq(_session.presentation.room_slot.get_child_count(), 1, "transition retains exactly one authoritative room")
	var expected: Array[Vector2] = _session.room.definition.spawn_positions("from_r00")
	for slot in 2:
		assert_eq(_session.players[slot].position, expected[slot], "both players use the destination's paired safe spawn")
	assert_eq(_session.players[1].hearts, 2, "ordinary room transitions preserve surviving health")
	await _release()


func _check_revive() -> void:
	assert_true(_session.call("_load_room", "r00", "start", true), "revive fixture uses a safe room")
	_freeze_actors()
	var fallen := _session.players[0]
	var rescuer := _session.players[1]
	fallen.reset_at(Vector2(160, 320))
	rescuer.reset_at(Vector2(184, 320))
	fallen.immunity_ticks = 0
	fallen.take_hit(fallen.max_hearts)
	InputRouter.set_test_input(1, Action.INTERACT)
	await _steps(89)
	assert_true(fallen.downed and fallen.revive_progress_ticks == 89, "revive remains incomplete at 89 physics ticks")
	await _steps(1)
	assert_true(not fallen.downed and fallen.hearts == 2 and fallen.immunity_ticks == 90, "the 90th held tick revives with two hearts and protection")
	await _release()
	fallen.immunity_ticks = 0
	fallen.take_hit(fallen.hearts)
	InputRouter.set_test_input(1, Action.INTERACT)
	await _steps(30)
	assert_eq(fallen.revive_progress_ticks, 30, "continuous held input advances revive progress")
	rescuer.immunity_ticks = 0
	rescuer.take_hit(1)
	await _steps(1)
	assert_eq(fallen.revive_progress_ticks, 0, "damage to the rescuer interrupts accumulated revive progress")
	await _steps(20)
	assert_eq(fallen.revive_progress_ticks, 20, "held revival starts a fresh count after interruption")
	await _release()
	assert_eq(fallen.revive_progress_ticks, 0, "releasing interact cancels partial revival")

	var recoveries := _session.recovery_count
	fallen.downed_ticks = 719
	fallen.revive_progress_ticks = 89
	InputRouter.set_test_input(1, Action.INTERACT)
	await _steps(1)
	assert_true(not fallen.downed, "completed revive wins the exact timeout boundary")
	assert_eq(_session.recovery_count, recoveries, "timeout boundary cannot recover after a successful same-tick revive")
	await _release()
	fallen.immunity_ticks = 0
	fallen.take_hit(fallen.hearts)
	fallen.downed_ticks = 718
	await _steps(1)
	assert_true(fallen.downed and fallen.downed_ticks == 719, "downed timer stays active below 720 ticks")
	assert_eq(_session.recovery_count, recoveries, "checkpoint recovery is not early")
	await _steps(1)
	assert_eq(_session.recovery_count, recoveries + 1, "720th downed tick commits one recovery")
	assert_eq(_session.current_room_id, "r00", "timeout returns both players to their validated checkpoint")
	for player in _session.players:
		assert_true(not player.downed and player.hearts == player.max_hearts, "checkpoint recovery restores both couriers")


func _check_boss_then_wipe() -> void:
	# A separate fresh team isolates reward-before-wipe ordering from the
	# traversal unlocks used only to reach the previous paired-anchor fixture.
	_session.free()
	_session = SESSION.instantiate() as GameSession
	_session.set("_focus_pause_enabled", false)
	add_child(_session)
	assert_true(_session.session_ready, "fresh boss transaction fixture starts")
	if not _session.session_ready:
		return
	assert_true(_session.call("_load_room", "r05", "from_r04", true), "controlled fixture loads the actual boss room")
	_freeze_actors()
	var boss := _session.boss()
	assert_true(boss != null, "one live boss exists before the outcome")
	if boss == null:
		return
	boss.receive_hit(100, 0, CombatQuery.next_attack_id())
	assert_true(_session.progress.has_flag("boss_spoolwarden") and _session.progress.has_flag("threadstep") and _session.progress.has_flag("shortcut_bell"), "boss defeat commits the complete shared outcome synchronously")
	for player in _session.players:
		player.immunity_ticks = 0
		player.take_hit(player.max_hearts)
	await _steps(1)
	assert_eq(_session.recovery_count, 1, "team wipe produces exactly one recovery")
	assert_true(_session.progress.has_flag("boss_spoolwarden") and _session.progress.has_flag("threadstep") and _session.progress.has_flag("shortcut_bell"), "same-frame wipe cannot erase the already committed boss outcome")
	assert_true(_session.call("_load_room", "r05", "from_r04", true), "return to cleared boss room succeeds")
	assert_true(_session.boss() == null and _session.enemies.is_empty(), "cleared boss does not respawn after checkpoint recovery")


func _entity(id: String) -> Dictionary:
	for entity: Dictionary in _session.room.definition.entities:
		if entity.id == id:
			return entity
	assert_true(false, "required production fixture entity is present: " + id)
	return {}


func _freeze_actors() -> void:
	for actor: PlayerController in _session.players:
		actor.set_physics_process(false)
	for enemy: CombatEnemy in _session.enemies:
		enemy.set_physics_process(false)


func _press(slot: int) -> void:
	InputRouter.set_test_input(slot, Action.INTERACT)
	await _steps(1)
	await _release()


func _release() -> void:
	InputRouter.set_test_input(0, 0)
	InputRouter.set_test_input(1, 0)
	await _steps(1)


func _steps(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _cleanup() -> void:
	get_tree().paused = false
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)
	AudioDirector.stop_music()
	AudioDirector.stop_cues()


func _retire_audio() -> void:
	# AudioServer releases stopped playbacks on its mixing thread, independently
	# of accelerated physics. Verify that retirement before the runner exits.
	var pending: Array[WeakRef] = []
	for node: Node in AudioDirector.get_children():
		if node is AudioStreamPlayer and node.has_stream_playback():
			pending.append(weakref(node.get_stream_playback()))
	AudioDirector.stop_music()
	AudioDirector.stop_cues()
	var deadline := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline:
		var alive := false
		for playback: WeakRef in pending:
			alive = alive or playback.get_ref() != null
		if not alive:
			return
		await get_tree().process_frame
	assert_true(false, "transaction fixture releases stopped audio playbacks")
