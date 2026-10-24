extends Scenario
## Real authored coordinates with controlled placements; world metadata only, no art/playthrough claim.
const SESSION := preload("res://scenes/session/session.tscn")
const Action := CommandSnapshot.Action
var _session: GameSession
var _metadata: ContentCatalog


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
	assert_true(_session.session_ready, "guidance fixture starts")
	_metadata = ContentCatalog.new()
	_metadata.world = JSON.parse_string(FileAccess.get_file_as_string("res://content/world.json"))
	_session.progress.commit_flags(["met_oru"])
	await _anchor_assignment()
	await _station_assignment()
	get_tree().paused = false
	_session.catalog = null
	_session.free()
	for slot in 2:
		InputRouter.set_test_input(slot, 0)
		InputRouter.clear_test_input(slot)
		InputRouter.clear(slot)


func _load(id: String, entrance: String) -> void:
	_session.catalog = null
	_session.room_path = "res://content/rooms/%s.json" % id
	assert_true(_session.call("_load_room", id, entrance, true), "authored guidance room loads: " + id)
	_session.catalog = _metadata
	for player in _session.players:
		player.set_physics_process(false)


func _anchor_assignment() -> void:
	_load("r02", "from_r01")
	_session.players[0].reset_at(RoomDefinition.feet_position(Vector2i(24,9)))
	_session.players[1].reset_at(RoomDefinition.feet_position(Vector2i(10,10)))
	assert_eq(_session.local_targets(0).size(), 2, "both anchors are initially available to each courier")
	await _press(0)
	assert_true(_session.local_targets(0).is_empty(), "claimed courier is never assigned a second anchor")
	var remaining := _session.local_targets(1)
	assert_eq(remaining.size(), 1, "unassigned partner is guided only to the remaining anchor")
	if remaining.size() == 1:
		assert_eq(remaining[0].entity_id, "spindle_east", "remaining local target has the unclaimed anchor identity")
	assert_eq(_session.local_targets().size(), 2, "pure campaign/map targets remain independent of transient slot assignments")
	assert_true(_session.interaction_hints[0].begins_with("Your end"), "owner gets their own held-end status")
	var bottom := _session.presentation.get("_objective_b") as Label
	assert_true(bottom.text.contains("Anchor: SE"), "partner compass selects the unclaimed southern anchor")
	_session.players[1].reset_at(_session.players[0].position)
	await _steps(1)
	assert_true(_session.interaction_hints[1].begins_with("Partner holds"), "partner never claims ownership of another slot's held end")
	_session.players[1].reset_at(RoomDefinition.feet_position(Vector2i(24,21)))
	await _press(1)
	assert_true(_session.progress.has_flag("bridge_spindle"), "different assigned ends complete the repair")
	var route := _session.local_targets(0)
	assert_true(route.size() == 1 and route[0].kind == "exit", "completed repair immediately guides both couriers onward")


func _station_assignment() -> void:
	_session.progress.commit_flags(["boss_spoolwarden", "threadstep", "shortcut_bell", "bridge_causeway"])
	_load("r07", "from_r06")
	_session.players[1].reset_at(RoomDefinition.feet_position(Vector2i(19,14)))
	_session.players[0].reset_at(RoomDefinition.feet_position(Vector2i(8,14)))
	await _press(1)
	assert_true(_session.local_targets(1).is_empty(), "claimed Loom station gives its owner no second assignment")
	var remaining := _session.local_targets(0)
	assert_true(remaining.size() == 1 and remaining[0].feet_position == RoomDefinition.feet_position(Vector2i(28,14)), "Loom partner is guided to the unclaimed station")
	var fallen := _session.players[0]
	fallen.immunity_ticks = 0
	fallen.take_hit(fallen.max_hearts)
	await _steps(1)
	assert_true(_session.local_targets(0).is_empty(), "downed courier has no actionable local target")
	assert_eq(_session.interaction_hints[0], "", "downed courier cannot get an interaction prompt")
	var bottom := _session.presentation.get("_objective_a") as Label
	assert_true(bottom.text.contains("Your partner") and not bottom.text.contains("Hold"), "downed HUD gives rescue status, not a self-revive action")


func _press(slot: int) -> void:
	InputRouter.set_test_input(slot, Action.INTERACT)
	await _steps(1)
	InputRouter.set_test_input(slot, 0)
	await _steps(1)


func _steps(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
