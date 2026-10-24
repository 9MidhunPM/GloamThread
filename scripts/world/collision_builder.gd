class_name CollisionBuilder
extends RefCounted
## Builds one canonical collision tree from the room's logical tile grid.
##
## Solid cells are merged into the fewest axis-aligned rectangles (greedy row
## runs, then vertical merge of identical runs) so bodies never catch on tile
## seams. One-way runs use a child body so a dropping courier can ignore only
## those platforms briefly. Theme skins never add collision shapes.

const PHYSICS_LAYER_WORLD := 1


static func build(definition: RoomDefinition) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "Collision"
	body.collision_layer = PHYSICS_LAYER_WORLD
	body.collision_mask = 0
	var index := 0
	for rect in solid_rects(definition):
		body.add_child(_rect_shape("Solid%d" % index, rect, false))
		index += 1
	var one_way := StaticBody2D.new()
	one_way.name = "OneWayCollision"
	one_way.collision_layer = PHYSICS_LAYER_WORLD
	one_way.collision_mask = 0
	body.add_child(one_way)
	index = 0
	for rect in one_way_rects(definition):
		one_way.add_child(_rect_shape("OneWay%d" % index, rect, true))
		index += 1
	return body


## Axis-aligned rectangles (in tiles) covering every solid cell exactly once.
static func solid_rects(definition: RoomDefinition) -> Array[Rect2i]:
	var runs: Array[Rect2i] = []
	for y in definition.height:
		var x := 0
		while x < definition.width:
			if definition.is_solid(Vector2i(x, y)):
				var start := x
				while x < definition.width and definition.is_solid(Vector2i(x, y)):
					x += 1
				runs.append(Rect2i(start, y, x - start, 1))
			else:
				x += 1
	return _merge_vertically(runs)


## One rectangle per horizontal run of one-way cells (never merged vertically).
static func one_way_rects(definition: RoomDefinition) -> Array[Rect2i]:
	var runs: Array[Rect2i] = []
	for y in definition.height:
		var x := 0
		while x < definition.width:
			if definition.is_one_way(Vector2i(x, y)):
				var start := x
				while x < definition.width and definition.is_one_way(Vector2i(x, y)):
					x += 1
				runs.append(Rect2i(start, y, x - start, 1))
			else:
				x += 1
	return runs


static func _merge_vertically(runs: Array[Rect2i]) -> Array[Rect2i]:
	var merged: Array[Rect2i] = []
	for run in runs:
		var extended := false
		for i in merged.size():
			var below := merged[i]
			if below.position.x == run.position.x and below.size.x == run.size.x and below.end.y == run.position.y:
				merged[i] = Rect2i(below.position, Vector2i(below.size.x, below.size.y + 1))
				extended = true
				break
		if not extended:
			merged.append(run)
	return merged


static func _rect_shape(shape_name: String, tiles: Rect2i, one_way: bool) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	shape.name = shape_name
	var rect := RectangleShape2D.new()
	var size := Vector2(tiles.size) * RoomDefinition.TILE
	rect.size = size
	shape.shape = rect
	shape.position = Vector2(tiles.position) * RoomDefinition.TILE + size * 0.5
	if one_way:
		shape.one_way_collision = true
		shape.one_way_collision_margin = 4.0
	return shape
