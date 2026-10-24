extends Scenario
## Active overhead data-boundary regressions; no rendering or route claim.

const RoomData := preload("res://scripts/world/room_definition.gd")


func run() -> void:
	var valid := _room()
	var definition := RoomData.new()
	definition.parse(valid)
	assert_true(definition.is_valid(), "paired dry floor cells load")
	assert_eq(definition.spawn_positions("start")[0], Vector2(56, 349), "spawn coordinates use the documented feet origin")
	assert_true(not definition.is_safe_spawn(Vector2i(3, 22)), "wall cells cannot be used as dry spawn cells")
	assert_true(not definition.is_safe_spawn(Vector2i(3, 0)), "a boundary wall cannot contain a spawn footprint")

	var from_json: Dictionary = JSON.parse_string(JSON.stringify(valid))
	definition.parse(from_json)
	assert_true(definition.is_valid(), "integer-valued JSON numbers round-trip")

	var fractional := _room()
	fractional["spawns"]["start"][0][0] = 3.5
	definition.parse(fractional)
	assert_true(not definition.is_valid(), "fractional tile coordinates are rejected, not truncated")

	for obstacle: String in ["#", "~", "^"]:
		var blocked := _room()
		blocked["tiles"][21] = "#.." + obstacle + ".".repeat(25) + "#"
		definition.parse(blocked)
		assert_true(not definition.is_valid(), "wall, water and hazard spawn cells are rejected")

	var outside := _room()
	outside["spawns"]["start"] = [[3, 23], [6, 21]]
	definition.parse(outside)
	assert_true(not definition.is_valid(), "out-of-bounds cells never become valid ground")

	var ragged := _room()
	ragged["tiles"][0] = ".".repeat(29)
	definition.parse(ragged)
	assert_true(not definition.is_valid(), "ragged tile rows reject before coordinate validation")
	assert_true(definition.spawns.is_empty(), "a failed parse cannot retain entrances from a previous room")

	var oversize := _room()
	oversize["tiles"] = []
	for row in 23:
		oversize["tiles"].append("#".repeat(91) if row == 22 else ".".repeat(91))
	definition.parse(oversize)
	assert_true(not definition.is_valid(), "room dimensions obey the shared upper bounds")

	var overlapping := _room()
	overlapping["spawns"]["start"] = [[3, 21], [3, 21]]
	definition.parse(overlapping)
	assert_true(not definition.is_valid(), "entrances provide distinct partner spawn positions")

	var missing_id := _room()
	missing_id["entities"] = [{"type": "wickwing", "tile": [10, 10]}]
	definition.parse(missing_id)
	assert_true(not definition.is_valid(), "entity IDs are required for stable state references")

	var duplicate_ids := _room()
	duplicate_ids["entities"] = [
		{"type": "wickwing", "id": "wing", "tile": [10, 10]},
		{"type": "wickwing", "id": "wing", "tile": [12, 10]},
	]
	definition.parse(duplicate_ids)
	assert_true(not definition.is_valid(), "duplicate entity IDs fail")

	var bad_version := _room()
	bad_version["schema_version"] = "1"
	definition.parse(bad_version)
	assert_true(not definition.is_valid(), "the schema version must be numeric")

	for version: Variant in ["phase1-v1", true, null, 1]:
		var incompatible := _room()
		incompatible.content_version = version
		definition.parse(incompatible)
		assert_true(not definition.is_valid(), "incompatible content version is a recoverable validation failure")


func _room() -> Dictionary:
	var rows: Array[String] = []
	for row in 23:
		rows.append("#".repeat(30) if row in [0, 22] else "#" + ".".repeat(28) + "#")
	return {
		"schema_version": 1,
		"content_version": "overhead-v1",
		"id": "r00",
		"name": "Runtime validation fixture",
		"tiles": rows,
		"spawns": {"start": [[3, 21], [6, 21]]},
		"entities": [],
	}
