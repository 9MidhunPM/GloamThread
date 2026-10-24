class_name CollisionBuilder
extends RefCounted
## Canonical walls and water are separate bodies. Floors never add collision.

const PHYSICS_LAYER_WORLD := 1


static func build(definition: RoomDefinition) -> StaticBody2D:
	var walls := StaticBody2D.new()
	walls.name = "Collision"
	walls.collision_layer = PHYSICS_LAYER_WORLD
	walls.collision_mask = 0
	var wall_rectangles := solid_rects(definition)
	for index in wall_rectangles.size():
		walls.add_child(_rect_shape("Wall%d" % index, wall_rectangles[index]))
	var water := StaticBody2D.new()
	water.name = "WaterCollision"
	water.collision_layer = PHYSICS_LAYER_WORLD
	water.collision_mask = 0
	walls.add_child(water)
	var rectangles := water_rects(definition)
	for index in rectangles.size():
		water.add_child(_rect_shape("Water%d" % index, rectangles[index]))
	for entity: Dictionary in definition.entities:
		if entity["type"] == "anchor_pair":
			water.add_child(_rect_shape("Bridge_" + entity["flag"], bridge_rect(entity)))
	return walls


static func bridge_rect(entity: Dictionary) -> Rect2i:
	var rect: Array = entity["bridge_rect"]
	return Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3]))


static func solid_rects(definition: RoomDefinition) -> Array[Rect2i]:
	return _rectangles(definition, "#", [])


static func water_rects(definition: RoomDefinition) -> Array[Rect2i]:
	var excluded: Array[Rect2i] = []
	for entity: Dictionary in definition.entities:
		if entity["type"] == "anchor_pair":
			excluded.append(bridge_rect(entity))
	return _rectangles(definition, "~", excluded)


static func _rectangles(definition: RoomDefinition, marker: String, excluded: Array[Rect2i]) -> Array[Rect2i]:
	var runs: Array[Rect2i] = []
	for y in definition.height:
		var x := 0
		while x < definition.width:
			if _matches(definition, Vector2i(x, y), marker, excluded):
				var start := x
				while x < definition.width and _matches(definition, Vector2i(x, y), marker, excluded):
					x += 1
				runs.append(Rect2i(start, y, x - start, 1))
			else:
				x += 1
	return _merge_vertically(runs)


static func _matches(definition: RoomDefinition, tile: Vector2i, marker: String, excluded: Array[Rect2i]) -> bool:
	if definition.char_at(tile) != marker:
		return false
	for rect: Rect2i in excluded:
		if rect.has_point(tile):
			return false
	return true


static func _merge_vertically(runs: Array[Rect2i]) -> Array[Rect2i]:
	var merged: Array[Rect2i] = []
	for run: Rect2i in runs:
		var extended := false
		for index in merged.size():
			var previous := merged[index]
			if previous.position.x == run.position.x and previous.size.x == run.size.x and previous.end.y == run.position.y:
				merged[index] = Rect2i(previous.position, Vector2i(previous.size.x, previous.size.y + 1))
				extended = true
				break
		if not extended:
			merged.append(run)
	return merged


static func _rect_shape(shape_name: String, tiles: Rect2i, _legacy_one_way: bool = false) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	shape.name = shape_name
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(tiles.size) * RoomDefinition.TILE
	shape.shape = rectangle
	shape.position = Vector2(tiles.position) * RoomDefinition.TILE + rectangle.size * 0.5
	return shape
