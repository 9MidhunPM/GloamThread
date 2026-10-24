extends Scenario
## Data-boundary regressions that can run before the content packet arrives.

const RoomData := preload("res://scripts/world/room_definition.gd")


func run() -> void:
	var valid := _room()
	var definition := RoomData.new()
	definition.parse(valid)
	assert_true(definition.is_valid(), "paired feet tiles above a real floor load")
	assert_eq(definition.spawn_positions("start")[0], Vector2(56, 352), "spawn coordinates use the documented feet origin")
	assert_true(not definition.is_safe_spawn(Vector2i(3, 22)), "outside-room support is never real ground")
	assert_true(not definition.is_safe_spawn(Vector2i(3, 0)), "the complete courier must fit below the room ceiling")

	var from_json: Dictionary = JSON.parse_string(JSON.stringify(valid))
	definition.parse(from_json)
	assert_true(definition.is_valid(), "integer-valued JSON numbers round-trip")

	var fractional := _room()
	fractional["spawns"]["start"][0][0] = 3.5
	definition.parse(fractional)
	assert_true(not definition.is_valid(), "fractional tile coordinates are rejected, not truncated")

	var ceiling := _room()
	ceiling["tiles"][20] = "...#" + ".".repeat(26)
	definition.parse(ceiling)
	assert_true(not definition.is_valid(), "a feet tile with insufficient body clearance is rejected")

	var no_floor := _room()
	no_floor["tiles"][22] = ".".repeat(30)
	no_floor["spawns"]["start"] = [[3, 22], [6, 22]]
	definition.parse(no_floor)
	assert_true(not definition.is_valid(), "a bottom-row spawn cannot stand on the out-of-bounds sentinel")

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
	missing_id["entities"] = [{"type": "diagnostic_mover", "tile": [10, 21]}]
	definition.parse(missing_id)
	assert_true(not definition.is_valid(), "entity IDs are required for stable state references")

	var duplicate_ids := _room()
	duplicate_ids["entities"] = [
		{"type": "diagnostic_mover", "id": "mover", "tile": [10, 21]},
		{"type": "diagnostic_mover", "id": "mover", "tile": [12, 21]},
	]
	definition.parse(duplicate_ids)
	assert_true(not definition.is_valid(), "duplicate entity IDs fail")

	var bad_version := _room()
	bad_version["schema_version"] = "1"
	definition.parse(bad_version)
	assert_true(not definition.is_valid(), "the schema version must be numeric")


func _room() -> Dictionary:
	var rows: Array[String] = []
	for row in 23:
		rows.append("#".repeat(30) if row == 22 else ".".repeat(30))
	return {
		"schema_version": 1,
		"id": "r00",
		"name": "Runtime validation fixture",
		"tiles": rows,
		"spawns": {"start": [[3, 21], [6, 21]]},
		"entities": [],
	}
