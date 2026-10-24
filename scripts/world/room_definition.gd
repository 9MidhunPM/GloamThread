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

const CHAR_SOLID := "#"
const CHAR_ONE_WAY := "="
const CHAR_EMPTY := "."
const CHAR_HAZARD := "^"
const VALID_CHARS := "#=.^"

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
	if int(data.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("schema_version must be %d" % SCHEMA_VERSION)
	id = str(data.get("id", ""))
	if id.is_empty():
		errors.append("missing room id")
	display_name = str(data.get("name", id))
	_parse_tiles(data.get("tiles", []))
	_parse_spawns(data.get("spawns", {}))
	_parse_entities(data.get("entities", []))


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
	if width < MIN_WIDTH or height < MIN_HEIGHT:
		errors.append("room must be at least %dx%d tiles (got %dx%d)" % [MIN_WIDTH, MIN_HEIGHT, width, height])


func _parse_spawns(raw: Variant) -> void:
	spawns = {}
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		errors.append("spawns must map entrance ids to two feet tiles")
		return
	for entrance: Variant in (raw as Dictionary):
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
				errors.append("spawn '%s' tile (%d, %d) is not an empty tile over solid ground" % [entrance, tile.x, tile.y])
			tiles.append(tile)
		if tiles.size() == 2:
			spawns[str(entrance)] = tiles


func _parse_entities(raw: Variant) -> void:
	entities = []
	if not (raw is Array):
		errors.append("entities must be an array")
		return
	var seen_ids := {}
	for item: Variant in (raw as Array):
		if not (item is Dictionary):
			errors.append("entities must be objects")
			continue
		var entity: Dictionary = item
		var type := str(entity.get("type", ""))
		if type.is_empty():
			errors.append("entity without type")
			continue
		var entity_id := str(entity.get("id", ""))
		if not entity_id.is_empty():
			if seen_ids.has(entity_id):
				errors.append("duplicate entity id '%s'" % entity_id)
			seen_ids[entity_id] = true
		if entity.has("tile"):
			var tile := _tile_from(entity["tile"], "entity '%s'" % type)
			if tile.x >= 0 and not in_bounds(tile):
				errors.append("entity '%s' tile (%d, %d) out of bounds" % [type, tile.x, tile.y])
		entities.append(entity)


func _tile_from(value: Variant, context: String) -> Vector2i:
	if value is Array and (value as Array).size() == 2:
		var list: Array = value
		if (list[0] is float or list[0] is int) and (list[1] is float or list[1] is int):
			var tile := Vector2i(int(list[0]), int(list[1]))
			if in_bounds(tile):
				return tile
			errors.append("%s tile (%d, %d) out of bounds" % [context, tile.x, tile.y])
			return Vector2i(-1, -1)
	errors.append("%s tile must be [x, y]" % context)
	return Vector2i(-1, -1)


# --- queries ---------------------------------------------------------------------

func in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < width and tile.y < height


func char_at(tile: Vector2i) -> String:
	if not in_bounds(tile):
		return CHAR_SOLID
	return rows[tile.y][tile.x]


func is_solid(tile: Vector2i) -> bool:
	return char_at(tile) == CHAR_SOLID


func is_one_way(tile: Vector2i) -> bool:
	return char_at(tile) == CHAR_ONE_WAY


func is_hazard(tile: Vector2i) -> bool:
	return char_at(tile) == CHAR_HAZARD


func is_ground(tile: Vector2i) -> bool:
	return is_solid(tile) or is_one_way(tile)


## A safe spawn is an empty tile with headroom above and ground directly below.
func is_safe_spawn(tile: Vector2i) -> bool:
	if not in_bounds(tile) or char_at(tile) != CHAR_EMPTY:
		return false
	if tile.y > 0 and char_at(tile + Vector2i.UP) == CHAR_SOLID:
		return false
	return is_ground(tile + Vector2i.DOWN)


func pixel_size() -> Vector2:
	return Vector2(width * TILE, height * TILE)


func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, pixel_size())


## World position of an actor's feet standing on the floor of [param tile].
static func feet_position(tile: Vector2i) -> Vector2:
	return Vector2((tile.x + 0.5) * TILE, (tile.y + 1) * TILE)


static func tile_center(tile: Vector2i) -> Vector2:
	return Vector2((tile.x + 0.5) * TILE, (tile.y + 0.5) * TILE)


func spawn_positions(entrance: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var tiles: Array = spawns.get(entrance, spawns.get("start", []))
	for tile: Vector2i in tiles:
		out.append(feet_position(tile))
	return out
