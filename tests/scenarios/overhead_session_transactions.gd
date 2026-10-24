extends Scenario
## Controlled transaction fixtures, not a route playthrough or encounter-balance claim.
const SESSION := preload("res://scenes/session/session.tscn")
const Action := CommandSnapshot.Action
var _session: GameSession


func run() -> void:
	for slot in 2:
		InputRouter.clear(slot)
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
	_session = SESSION.instantiate() as GameSession
	_session.fixture_mode = true
	_session.room_path = "res://content/rooms/r00.json"
	_session.set("_focus_pause_enabled", false)
	add_child(_session)
	assert_true(_session.session_ready, "overhead transaction fixture starts")
	if _session.session_ready:
		_freeze()
		await _revive_boundaries()
		await _boss_before_wipe()
		await _recovery_mid_dash()
	get_tree().paused = false
	_session.free()
	for slot in 2:
		InputRouter.set_test_input(slot, 0)
		InputRouter.clear_test_input(slot)
		InputRouter.clear(slot)
	AudioDirector.stop_music()
	AudioDirector.stop_cues()


func _revive_boundaries() -> void:
	var rescuer := _session.players[0]
	var fallen := _session.players[1]
	rescuer.reset_at(Vector2(120,253))
	fallen.reset_at(Vector2(144,253))
	fallen.immunity_ticks = 0
	fallen.take_hit(fallen.max_hearts)
	fallen.downed_ticks = 719
	fallen.revive_progress_ticks = 89
	InputRouter.set_test_input(0, Action.INTERACT)
	await _steps(1)
	assert_true(not fallen.downed and fallen.hearts == 2, "completed hold revive wins on the timeout boundary")
	assert_eq(_session.recovery_count, 0, "boundary revive does not also schedule recovery")
	assert_eq(fallen.immunity_ticks, 90, "revive grants ninety protected physics ticks")
	InputRouter.set_test_input(0, 0)
	await _steps(1)
	fallen.immunity_ticks = 0
	fallen.take_hit(fallen.max_hearts)
	fallen.revive_progress_ticks = 50
	rescuer.immunity_ticks = 0
	rescuer.take_hit(1)
	InputRouter.set_test_input(0, Action.INTERACT)
	await _steps(1)
	assert_eq(fallen.revive_progress_ticks, 0, "rescuer damage interrupts a held revive in the same tick")
	InputRouter.set_test_input(0, 0)
	fallen.downed_ticks = 718
	await _steps(1)
	assert_eq(_session.recovery_count, 0, "downed timeout is not early")
	await _steps(1)
	assert_eq(_session.recovery_count, 1, "tick 720 schedules exactly one shared recovery")
	assert_eq(_session.current_room_id, "r00", "fixture checkpoint restores both couriers to Lantern Rest")
	for player in _session.players:
		assert_true(not player.downed and player.hearts == player.max_hearts, "recovery restores both couriers")
	_freeze()


func _boss_before_wipe() -> void:
	_session.room_path = "res://content/rooms/r05.json"
	assert_true(_session.call("_load_room", "r05", "from_r04", true), "controlled coordinator fixture loads Broken Bell")
	_freeze()
	var enemy := _session.boss()
	assert_true(enemy != null, "one shared boss exists")
	if enemy == null:
		return
	enemy.receive_hit(100, 0, CombatQuery.next_attack_id())
	for flag in ["boss_spoolwarden", "threadstep", "shortcut_bell"]:
		assert_true(_session.progress.has_flag(flag), "defeat commits the complete reward synchronously: " + flag)
	_session.room_path = "res://content/rooms/r00.json"
	var recoveries := _session.recovery_count
	for player in _session.players:
		player.immunity_ticks = 0
		player.take_hit(player.max_hearts)
	await _steps(1)
	assert_eq(_session.recovery_count, recoveries+1, "same-tick team wipe schedules one recovery")
	for flag in ["boss_spoolwarden", "threadstep", "shortcut_bell"]:
		assert_true(_session.progress.has_flag(flag), "wipe preserves committed reward: " + flag)
	_session.room_path = "res://content/rooms/r05.json"
	assert_true(_session.call("_load_room", "r05", "from_r04", true), "cleared boss room reloads")
	assert_true(_session.boss() == null and _session.enemies.is_empty(), "committed boss cannot respawn")
	_freeze()


func _recovery_mid_dash() -> void:
	_session.room_path = "res://content/rooms/r01.json"
	assert_true(_session.call("_load_room", "r01", "from_r00", true), "recovery fixture loads an authored dash crossing")
	var player := _session.players[0]
	player.reset_at(Vector2(626,109))
	player.set_physics_process(true)
	InputRouter.set_test_input(0, Action.RIGHT | Action.DASH)
	await _steps(5)
	assert_true(player.dash_ticks > 0 and not _session.room.can_stand_at(player.position), "recovery interrupts an actual water crossing")
	_session.room_path = "res://content/rooms/r00.json"
	var recoveries := _session.recovery_count
	_session.request_recovery("Controlled mid-dash recovery")
	await _steps(1)
	assert_eq(_session.recovery_count, recoveries+1, "mid-dash recovery replaces the room exactly once")
	assert_eq(player.dash_ticks, 0, "room replacement cancels old dash duration")
	assert_true(player.get_collision_exceptions().is_empty(), "room replacement clears stale water exception ownership")
	assert_true(_session.room.can_stand_at(player.position), "recovery ends at a complete dry checkpoint footprint")
	assert_eq(_session.presentation.room_slot.get_child_count(), 1, "recovery retains one authoritative room")
	InputRouter.set_test_input(0, 0)


func _freeze() -> void:
	for player in _session.players:
		player.set_physics_process(false)
	for enemy in _session.enemies:
		enemy.set_physics_process(false)


func _steps(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
