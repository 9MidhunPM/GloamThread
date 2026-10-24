class_name RoomDefinition
extends RefCounted
## Canonical room data parsed from content/rooms/<id>.json.
##
## One definition drives collision, spawns, entities and both theme skins, so
## the Ember and Moss views can never disagree about where an edge is
## (docs/ARCHITECTURE.md §3). Validation mirrors tools/validate_content.py.

const SCHEMA_VERSION := 1
const TILE := 16
## Smallest room that fills one 480x360 view (30 x 22.5 tiles).
const MIN_WIDTH := 30
const MIN_HEIGHT := 23
const MAX_WIDTH := 90
const MAX_HEIGHT := 30

const CHAR_SOLID := "#"
const CHAR_BRIDGE := "="
const CHAR_WATER := "~"
const CHAR_EMPTY := "."
const CHAR_HAZARD := "^"
const VALID_CHARS := "#=.~^"
const ROOM_IDS := ["r00", "r01", "r02", "r03", "r04", "r05", "r06", "r07"]
const PROGRESS_FLAGS := ["bridge_spindle", "bridge_causeway", "boss_spoolwarden", "threadstep", "shortcut_bell", "loom_restored", "lantern_charm", "met_oru"]
const ENTITY_FIELDS := {
	"spoolmite": ["tile"],
	"wickwing": ["tile"],
	"spoolwarden": ["tile"],
	"exit": ["rect", "target_room", "target_entrance", "requires_all"],
	"checkpoint": ["tile", "checkpoint_id", "entrance"],
	"anchor_pair": ["anchors", "bridge_rect", "flag"],
	"npc": ["tile", "character_id", "dialogue_id", "restored_dialogue_id"],
	"secret": ["tile", "flag"],
	"loom": ["stations", "flag"],
}

var id: String = ""
var display_name: String = ""
var width: int = 0
var height: int = 0
## Rows of tile characters, top to bottom.
var rows: PackedStringArray = PackedStringArray()
## Entrance id -> Array of two Vector2i feet tiles (player 1, player 2).
var spawns: Dictionary = {}
## Raw entity dictionaries; interpreted by Room when instancing.
var entities: Array[Dictionary] = []
## Render-only placement records; asset references are checked by ContentCatalog.
var decor: Array[Dictionary] = []
var errors: PackedStringArray = PackedStringArray()


static func load_from_path(path: String) -> RoomDefinition:
	var definition := RoomDefinition.new()
	if not FileAccess.file_exists(path):
		definition.errors.append("room file not found: %s" % path)
		return definition
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		definition.errors.append("room file is not a JSON object: %s" % path)
		return definition
	definition.parse(parsed as Dictionary)
	return definition


func is_valid() -> bool:
	return errors.is_empty()


func parse(data: Dictionary) -> void:
	errors.clear()
	width = 0
	height = 0
	rows = PackedStringArray()
	spawns = {}
	entities = []
	decor = []
	var room_fields := ["schema_version", "content_version", "id", "name", "tiles", "spawns", "entities"]
	if data.has("decor"):
		room_fields.append("decor")
	_check_fields(data, room_fields, "room")
	if data.get("content_version") != "overhead-v1":
		errors.append("content_version must be overhead-v1")
	if not _is_integer(data.get("schema_version")) or data.get("schema_version") != SCHEMA_VERSION:
		errors.append("schema_version must be %d" % SCHEMA_VERSION)
	id = data.get("id", "") if data.get("id") is String else ""
	if id not in ROOM_IDS:
		errors.append("room id must be r00 through r07")
	display_name = data.get("name", "") if data.get("name") is String else ""
	_check_text(data.get("name"), "room name")
	_parse_tiles(data.get("tiles", []))
	# Never inspect coordinates against incomplete or ragged geometry.
	if not errors.is_empty():
		return
	_parse_spawns(data.get("spawns", {}))
	_parse_entities(data.get("entities", []))
	_parse_decor(data.get("decor", []))


func _parse_tiles(raw: Variant) -> void:
	rows = PackedStringArray()
	if not (raw is Array) or (raw as Array).is_empty():
		errors.append("tiles must be a non-empty array of strings")
		return
	for row: Variant in (raw as Array):
		if not (row is String):
			errors.append("tile rows must be strings")
			return
		rows.append(row as String)
	width = rows[0].length()
	height = rows.size()
	for y in height:
		if rows[y].length() != width:
			errors.append("tile row %d has length %d, expected %d" % [y, rows[y].length(), width])
		for x in rows[y].length():
			if not VALID_CHARS.contains(rows[y][x]):
				errors.append("invalid tile char '%s' at (%d, %d)" % [rows[y][x], x, y])
	if width < MIN_WIDTH or height < MIN_HEIGHT or width > MAX_WIDTH or height > MAX_HEIGHT:
		errors.append("room must be %d..%d by %d..%d tiles (got %dx%d)" % [MIN_WIDTH, MAX_WIDTH, MIN_HEIGHT, MAX_HEIGHT, width, height])


func _parse_spawns(raw: Variant) -> void:
	spawns = {}
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		errors.append("spawns must map entrance ids to two feet tiles")
		return
	for entrance: Variant in (raw as Dictionary):
		if not _identifier(entrance, "spawn entrance"):
			continue
		var pair: Variant = (raw as Dictionary)[entrance]
		if not (pair is Array) or (pair as Array).size() != 2:
			errors.append("spawn '%s' must list exactly two tiles" % entrance)
			continue
		var tiles: Array[Vector2i] = []
		for item: Variant in (pair as Array):
			var tile := _tile_from(item, "spawn '%s'" % entrance)
			if tile.x < 0:
				continue
			if not is_safe_spawn(tile):
				errors.append("spawn '%s' tile (%d, %d) is not a safe dry floor cell" % [entrance, tile.x, tile.y])
				continue
			tiles.append(tile)
		if tiles.size() == 2:
			if tiles[0] == tiles[1]:
				errors.append("spawn '%s' must provide distinct feet tiles" % entrance)
			spawns[str(entrance)] = tiles


func _parse_entities(raw: Variant) -> void:
	entities = []
	if not (raw is Array):
		errors.append("entities must be an array")
		return
	var seen_ids: Dictionary = {}
	var bridges: Array[Rect2i] = []
	for item: Variant in (raw as Array):
		if not (item is Dictionary):
			errors.append("entities must be objects")
			continue
		var entity: Dictionary = item
		var type: Variant = entity.get("type")
		if not type is String or not ENTITY_FIELDS.has(type):
			errors.append("entity has an unknown type")
			continue
		var context := "entity '%s'" % str(entity.get("id", type))
		var expected_fields: Array = ["type", "id"] + ENTITY_FIELDS[type]
		if not _check_fields(entity, expected_fields, context):
			continue
		_claim_id(entity.get("id"), seen_ids, context)
		var tile := Vector2i(-1, -1)
		if entity.has("tile"):
			tile = _tile_from(entity["tile"], context)
			if tile.x >= 0:
				if char_at(tile) not in [CHAR_EMPTY, CHAR_BRIDGE]:
					errors.append("%s tile must be dry walkable floor" % context)
				if type in ["diagnostic_mover", "spoolmite", "spoolwarden", "checkpoint", "npc", "secret"] and not is_safe_spawn(tile):
					errors.append("%s needs a safe dry footprint" % context)
				if type in ["spoolmite", "wickwing", "spoolwarden"]:
					_check_enemy_spacing(tile, context)
		match type:
			"diagnostic_mover":
				var distance: Variant = entity["range_tiles"]
				if not _is_integer(distance) or distance <= 0:
					errors.append("%s range_tiles must be a positive integer" % context)
				elif tile.x >= 0 and (tile.x - distance < 0 or tile.x + distance >= width):
					errors.append("%s range leaves the room" % context)
			"exit":
				_parse_exit(entity, context)
			"checkpoint":
				_identifier(entity["checkpoint_id"], context + "/checkpoint_id")
				if entity["checkpoint_id"] not in ["checkpoint_a", "checkpoint_b"]:
					errors.append("%s checkpoint_id is unknown" % context)
				if not _identifier(entity["entrance"], context + "/entrance") or not spawns.has(entity["entrance"]):
					errors.append("%s checkpoint entrance does not resolve" % context)
			"anchor_pair", "loom":
				_parse_pair(entity, seen_ids, bridges, context)
			"npc":
				if entity["character_id"] != "oru" or entity["dialogue_id"] != "oru_intro" or entity["restored_dialogue_id"] != "oru_return":
					errors.append("%s requires Oru and the authored intro/return dialogue IDs" % context)
			"secret":
				if id != "r03" or entity["flag"] != "lantern_charm":
					errors.append("%s must be the lantern_charm in r03" % context)
		entities.append(entity.duplicate(true))


func _check_enemy_spacing(tile: Vector2i, context: String) -> void:
	for pair: Array in spawns.values():
		for spawn: Vector2i in pair:
			if absi(tile.x - spawn.x) <= 3 and absi(tile.y - spawn.y) <= 3:
				errors.append("%s is too close to an entrance spawn" % context)
				return


func _parse_exit(entity: Dictionary, context: String) -> void:
	var zone := _rect_from(entity["rect"], context + "/rect")
	if zone.has_area():
		if zone.size.x < 3 or zone.size.y < 2:
			errors.append("%s rally rectangle must fit both couriers" % context)
		var standing_tiles := 0
		for y in range(zone.position.y, zone.end.y):
			for x in range(zone.position.x, zone.end.x):
				# Feet are tile centre plus five pixels, inside the rally cell.
				if is_safe_spawn(Vector2i(x, y)):
					standing_tiles += 1
		if standing_tiles < 2:
			errors.append("%s rally rectangle needs two safe standing feet positions" % context)
	if entity["target_room"] not in ROOM_IDS:
		errors.append("%s target_room is unknown" % context)
	_identifier(entity["target_entrance"], context + "/target_entrance")
	var required: Variant = entity["requires_all"]
	if not required is Array:
		errors.append("%s requires_all must be an array" % context)
		return
	var seen: Dictionary = {}
	for flag: Variant in required:
		if not flag is String or flag not in PROGRESS_FLAGS:
			errors.append("%s requires_all contains an unknown flag" % context)
		elif seen.has(flag):
			errors.append("%s requires_all repeats '%s'" % [context, flag])
		else:
			seen[flag] = true


func _parse_pair(entity: Dictionary, seen_ids: Dictionary, bridges: Array[Rect2i], context: String) -> void:
	var is_bridge: bool = entity["type"] == "anchor_pair"
	var field: String = "anchors" if is_bridge else "stations"
	var expected_flag: String = str({"r02": "bridge_spindle", "r06": "bridge_causeway"}.get(id, "")) if is_bridge else "loom_restored"
	if expected_flag.is_empty() or entity["flag"] != expected_flag or (not is_bridge and id != "r07"):
		errors.append("%s has an incorrect progression flag or room" % context)
	var points: Variant = entity[field]
	if not points is Array or points.size() != 2:
		errors.append("%s/%s requires exactly two distinct points" % [context, field])
	else:
		var positions: Array[Vector2i] = []
		for point: Variant in points:
			if not point is Dictionary or not _check_fields(point, ["id", "tile"], context + "/" + field):
				errors.append("%s/%s entries require id and tile" % [context, field])
				continue
			_claim_id(point.get("id"), seen_ids, context + "/" + field)
			var tile := _tile_from(point.get("tile"), context + "/" + field)
			if tile.x < 0:
				continue
			if not is_safe_spawn(tile):
				errors.append("%s/%s needs a safe dry approach before restoration" % [context, field])
			if tile in positions:
				errors.append("%s/%s points must occupy distinct tiles" % [context, field])
			positions.append(tile)
	if not is_bridge:
		return
	var span := _rect_from(entity["bridge_rect"], context + "/bridge_rect")
	if not span.has_area():
		return
	for y in range(span.position.y, span.end.y):
		for x in range(span.position.x, span.end.x):
			if char_at(Vector2i(x, y)) != CHAR_WATER:
				errors.append("%s bridge span must cover water before restoration" % context)
				break
	for previous: Rect2i in bridges:
		if span.intersects(previous):
			errors.append("%s bridge spans overlap" % context)
	bridges.append(span)


func _parse_decor(raw: Variant) -> void:
	if not raw is Array:
		errors.append("decor must be an array")
		return
	for index in raw.size():
		var item: Variant = raw[index]
		var context := "decor[%d]" % index
		if not item is Dictionary or not _check_fields(item, ["asset_id", "frame", "position_px", "theme", "z"], context):
			errors.append("%s requires only asset_id/frame/position_px/theme/z" % context)
			continue
		_identifier(item["asset_id"], context + "/asset_id")
		if not _is_integer(item["frame"]) or item["frame"] < 0:
			errors.append("%s frame must be a nonnegative integer" % context)
		var position: Variant = item["position_px"]
		if not position is Array or position.size() != 2 or not _is_integer(position[0]) or not _is_integer(position[1]):
			errors.append("%s position_px must contain two integers" % context)
		elif position[0] < 0 or position[1] < 0 or position[0] > width * TILE or position[1] > height * TILE:
			errors.append("%s position_px is outside the room" % context)
		if item["theme"] not in ["common", "ember", "moss"]:
			errors.append("%s theme is unknown" % context)
		if not _is_integer(item["z"]) or item["z"] < -4096 or item["z"] > 4096:
			errors.append("%s z must be an integer in -4096..4096" % context)
		decor.append(item.duplicate(true))


func _check_fields(data: Dictionary, expected: Array, context: String) -> bool:
	if data.size() != expected.size():
		errors.append("%s has missing or unexpected fields" % context)
		return false
	for field: Variant in expected:
		if not data.has(field):
			errors.append("%s is missing field '%s'" % [context, field])
			return false
	return true


func _identifier(value: Variant, context: String) -> bool:
	if not value is String or value.is_empty():
		errors.append("%s requires a nonempty identifier" % context)
		return false
	for index in value.length():
		var code: int = value.unicode_at(index)
		var letter: bool = code >= 97 and code <= 122
		if not letter and (index == 0 or not ((code >= 48 and code <= 57) or code == 95)):
			errors.append("%s requires lowercase letters, digits and underscores, starting with a letter" % context)
			return false
	return true


func _claim_id(value: Variant, seen: Dictionary, context: String) -> void:
	if not _identifier(value, context + "/id"):
		return
	if seen.has(value):
		errors.append("%s repeats entity/interaction id '%s'" % [context, value])
	seen[value] = true


func _check_text(value: Variant, context: String) -> void:
	if not value is String or value.is_empty():
		errors.append("%s must be nonempty printable ASCII text" % context)
		return
	for index in value.length():
		var code: int = value.unicode_at(index)
		if code < 32 or code > 126:
			errors.append("%s must use the authored printable ASCII font" % context)
			return


func _rect_from(value: Variant, context: String) -> Rect2i:
	if not value is Array or value.size() != 4:
		errors.append("%s must be an integer [x, y, width, height] rectangle" % context)
		return Rect2i()
	for part: Variant in value:
		if not _is_integer(part):
			errors.append("%s rectangle values must be integers" % context)
			return Rect2i()
	if value[0] < 0 or value[1] < 0 or value[2] <= 0 or value[3] <= 0 or value[0] + value[2] > width or value[1] + value[3] > height:
		errors.append("%s needs positive dimensions within the room" % context)
		return Rect2i()
	return Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3]))


func _tile_from(value: Variant, context: String) -> Vector2i:
	if value is Array and (value as Array).size() == 2:
		var list: Array = value
		if _is_integer(list[0]) and _is_integer(list[1]):
			if list[0] < 0 or list[1] < 0 or list[0] >= width or list[1] >= height:
				errors.append("%s tile is out of bounds" % context)
				return Vector2i(-1, -1)
			var tile := Vector2i(int(list[0]), int(list[1]))
			return tile
	errors.append("%s tile must be an integer [x, y] pair" % context)
	return Vector2i(-1, -1)


static func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


# --- queries ---------------------------------------------------------------------

func in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < width and tile.y < height


func char_at(tile: Vector2i) -> String:
	if not in_bounds(tile):
		return CHAR_SOLID
	if tile.y >= rows.size() or tile.x >= rows[tile.y].length():
		return CHAR_SOLID
	return rows[tile.y][tile.x]


func is_solid(tile: Vector2i) -> bool:
	return char_at(tile) == CHAR_SOLID


func is_one_way(_tile: Vector2i) -> bool:
	# Legacy visual/test callers can ask; overhead rooms have no one-way floors.
	return false


func is_water(tile: Vector2i) -> bool:
	return char_at(tile) == CHAR_WATER


func is_hazard(tile: Vector2i) -> bool:
	return char_at(tile) == CHAR_HAZARD


func is_ground(tile: Vector2i) -> bool:
	return char_at(tile) in [CHAR_EMPTY, CHAR_BRIDGE, CHAR_HAZARD]


## The centred 12x10 footprint fits wholly inside one 16px authored cell.
## Spawn/interaction points exclude hazards even though hazards are walkable.
func is_safe_spawn(tile: Vector2i) -> bool:
	return in_bounds(tile) and char_at(tile) in [CHAR_EMPTY, CHAR_BRIDGE]


static func footprint(feet: Vector2) -> Rect2:
	return Rect2(feet + Vector2(-6, -10), Vector2(12, 10))


func pixel_size() -> Vector2:
	return Vector2(width * TILE, height * TILE)


func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, pixel_size())


## The visible feet sit five pixels below the cell's collision centre.
static func feet_position(tile: Vector2i) -> Vector2:
	return tile_center(tile) + Vector2(0, 5)


static func tile_center(tile: Vector2i) -> Vector2:
	return Vector2((tile.x + 0.5) * TILE, (tile.y + 0.5) * TILE)


func spawn_positions(entrance: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var tiles: Array = spawns.get(entrance, [])
	for tile: Vector2i in tiles:
		out.append(feet_position(tile))
	return out
