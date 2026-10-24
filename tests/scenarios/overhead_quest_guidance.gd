extends Scenario
## Pure fixtures exercise objectives/routing, with no scene or progress mutation.

const Quest := preload("res://scripts/session/quest_director.gd")


func run() -> void:
	var world := _world()
	var original_world := world.duplicate(true)
	var team := TeamProgress.new()
	var before := team.to_save()
	var result := Quest.describe(team, "r01", world)
	assert_eq(result.id, "meet_oru", "new team is guided to Oru first")
	assert_eq(result.route, ["r01", "r00"], "backtracking to the introduction uses the open graph")
	assert_eq(result.target_kind, "npc", "introduction has an actionable local kind")
	assert_eq(team.to_save(), before, "guidance cannot commit the introduction itself")
	team.commit_flags(["met_oru"])
	result = Quest.describe(team, "r00", world)
	assert_eq(result.id, "restore_spindle", "introduction advances to the cooperative bridge")
	assert_eq(result.route, ["r00", "r01", "r02"], "bridge lesson uses the unlocked approach")
	team.commit_flags(["bridge_spindle"])
	result = Quest.describe(team, "r00", world)
	assert_eq(result.id, "free_warden", "first bridge advances to Spoolwarden")
	assert_eq(result.route, ["r00", "r01", "r02", "r03", "r04", "r05"], "boss route cannot use its still-locked shortcut")
	team.commit_flags(["boss_spoolwarden", "threadstep", "shortcut_bell"])
	result = Quest.describe(team, "r05", world)
	assert_eq(result.id, "restore_causeway", "shared boss reward advances to the dash lesson")
	assert_eq(result.route, ["r05", "r01", "r06"], "post-boss route chooses the shortest unlocked shortcut")
	assert_eq(result.next_room, "r01", "local compass points at the immediate room rather than across the district")
	team.commit_flags(["bridge_causeway"])
	result = Quest.describe(team, "r06", world)
	assert_eq(result.id, "restore_loom", "Causeway repair advances to the Loom")
	assert_eq(result.route, ["r06", "r07"], "restored causeway opens the authored connection")
	team.commit_flags(["loom_restored"])
	result = Quest.describe(team, "r07", world)
	assert_eq(result.id, "return_home", "restoration directs both couriers home")
	assert_eq(result.route, ["r07", "r00"], "restoration uses the new home connection")
	assert_true(Quest.describe(team, "r00", world).text.contains("home together"), "home arrival has a completion objective")
	var fresh := TeamProgress.new()
	result = Quest.describe(fresh, "r07", world)
	assert_true(not result.reachable and result.route.is_empty() and result.text.contains("No open route"), "locked islands report an explicit unreachable objective")
	assert_true(not Quest.describe(fresh, "r99", world).reachable, "unknown current rooms never invent a path")
	assert_true(not Quest.describe(null, "r00", world).reachable, "missing team state cannot invent an active quest route")
	var invalid_world := world.duplicate(true)
	invalid_world.connections = [{"a": "r07", "b": "r00", "requires_all": true}]
	assert_true(not Quest.describe(fresh, "r07", invalid_world).reachable, "malformed gate declarations remain closed")
	assert_eq(world, original_world, "routing never changes world metadata")
	_test_local_targets(world)


func _test_local_targets(world: Dictionary) -> void:
	var team := TeamProgress.new()
	var home := _definition("r00")
	home.entities = [{"id": "oru", "type": "npc", "character_id": "oru", "tile": [4, 19]}]
	var targets := Quest.local_targets(home, Quest.describe(team, "r00", world))
	assert_eq(targets.size(), 1, "Oru has one local target")
	assert_eq(targets[0].entity_id, "oru", "local targets expose authored identities")
	assert_eq(targets[0].feet_position, RoomDefinition.feet_position(Vector2i(4, 19)), "target coordinates use the canonical feet convention")
	team.commit_flags(["met_oru"])
	var steps := _definition("r02")
	steps.entities = [{"id": "pair", "type": "anchor_pair", "flag": "bridge_spindle", "anchors": [{"id": "west", "tile": [5, 19]}, {"id": "east", "tile": [9, 19]}]}]
	targets = Quest.local_targets(steps, Quest.describe(team, "r02", world))
	assert_eq(targets.size(), 2, "both distinct bridge ends remain visible to proximity selection")
	assert_eq(targets[0].parent_id, "pair", "anchor targets retain their owning pair identity")
	assert_eq(targets[1].entity_id, "east", "second end has its own stable identity")
	assert_true(Quest.local_targets(steps, {"reachable": 1}).is_empty(), "malformed reachability cannot enable a target")
	var atrium := _definition("r01")
	atrium.entities = [
		{"id": "to_steps", "type": "exit", "target_room": "r02", "requires_all": [], "rect": [3, 18, 5, 3]},
		{"id": "locked_duplicate", "type": "exit", "target_room": "r02", "requires_all": ["threadstep"], "rect": [12, 18, 5, 3]},
		{"id": "wrong_way", "type": "exit", "target_room": "r00", "requires_all": [], "rect": [20, 18, 5, 3]},
	]
	targets = Quest.local_targets(atrium, Quest.describe(team, "r01", world))
	assert_eq(targets.size(), 1, "only an unlocked exit on the shortest route is suggested")
	assert_eq(targets[0].entity_id, "to_steps", "target exit goes to the immediate destination room")
	assert_true(Rect2(48, 288, 80, 48).has_point(targets[0].feet_position), "rally target is a safe feet position inside its rectangle")
	assert_true(Quest.local_targets(_definition("r07"), Quest.describe(TeamProgress.new(), "r07", world)).is_empty(), "unreachable objectives have no fabricated local targets")
	team.commit_flags(["bridge_spindle"])
	var bell := _definition("r05")
	bell.entities = [{"id": "spoolwarden", "type": "spoolwarden", "tile": [14, 19]}]
	targets = Quest.local_targets(bell, Quest.describe(team, "r05", world))
	assert_true(targets.size() == 1 and targets[0].entity_id == "spoolwarden", "boss objective points to the one encounter actor")
	team.commit_flags(["boss_spoolwarden", "threadstep", "shortcut_bell", "bridge_causeway"])
	var loom := _definition("r07")
	loom.entities = [{"id": "loom", "type": "loom", "flag": "loom_restored", "stations": [{"id": "ember_end", "tile": [6, 19]}, {"id": "moss_end", "tile": [10, 19]}]}]
	targets = Quest.local_targets(loom, Quest.describe(team, "r07", world))
	assert_eq(targets.size(), 2, "Loom objective exposes both cooperative stations")
	assert_eq(targets[0].kind, "station", "station targets are distinct from bridge anchors")
	team.commit_flags(["loom_restored"])
	assert_true(Quest.local_targets(home, Quest.describe(team, "r00", world)).is_empty(), "completed home objective invents no extra interaction")


func _definition(id: String) -> RoomDefinition:
	var definition := RoomDefinition.new()
	definition.id = id
	definition.width = 30
	definition.height = 23
	for row in 23:
		definition.rows.append("#".repeat(30) if row >= 20 else ".".repeat(30))
	return definition


func _world() -> Dictionary:
	var rooms := []
	for id: String in TeamProgress.ROOM_IDS:
		rooms.append({"id": id, "name": id})
	return {"rooms": rooms, "connections": [
		{"a": "r00", "b": "r01", "requires_all": []}, {"a": "r01", "b": "r02", "requires_all": []},
		{"a": "r02", "b": "r03", "requires_all": ["bridge_spindle"]}, {"a": "r03", "b": "r04", "requires_all": []},
		{"a": "r04", "b": "r05", "requires_all": []}, {"a": "r05", "b": "r01", "requires_all": ["shortcut_bell"]},
		{"a": "r01", "b": "r06", "requires_all": ["threadstep"]}, {"a": "r06", "b": "r07", "requires_all": ["bridge_causeway"]},
		{"a": "r07", "b": "r00", "requires_all": ["loom_restored"]},
	]}
