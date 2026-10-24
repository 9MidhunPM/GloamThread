class_name ThemePresenter
extends RefCounted
## All returned nodes are presentation-only; canonical collision belongs to Room.


static func build_terrain(definition: RoomDefinition, catalog: AssetCatalog, theme_id: String) -> TileMapLayer:
	var layer := _layer(catalog, theme_id)
	layer.name = "Terrain"
	var ids: Array = catalog.entries["terrain_%s_v1" % theme_id]["tile_ids"]
	for y in definition.height:
		for x in definition.width:
			var id := _tile_id(definition, Vector2i(x, y))
			var index := ids.find(id)
			if index >= 0:
				layer.set_cell(Vector2i(x, y), 0, Vector2i(index % 8, index / 8))
	return layer


static func build_bridge(rect: Rect2i, catalog: AssetCatalog, theme_id: String) -> TileMapLayer:
	var layer := _layer(catalog, theme_id)
	layer.name = "RestoredBridge"
	var ids: Array = catalog.entries["terrain_%s_v1" % theme_id]["tile_ids"]
	for x in rect.size.x:
		var part := "middle"
		if rect.size.x == 1:
			part = "single"
		elif x == 0:
			part = "left"
		elif x == rect.size.x - 1:
			part = "right"
		var index := ids.find("bridge_" + part)
		layer.set_cell(rect.position + Vector2i(x, 0), 0, Vector2i(index % 8, index / 8))
	return layer


static func _layer(catalog: AssetCatalog, theme_id: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	var source := TileSetAtlasSource.new()
	source.texture = catalog.texture("terrain_%s_v1" % theme_id)
	source.margins = Vector2i(2, 2)
	source.separation = Vector2i(4, 4)
	source.texture_region_size = Vector2i(16, 16)
	for index in 48:
		source.create_tile(Vector2i(index % 8, index / 8))
	tiles.add_source(source, 0)
	layer.tile_set = tiles
	return layer


static func _tile_id(definition: RoomDefinition, tile: Vector2i) -> String:
	if definition.is_solid(tile):
		var above := definition.is_solid(tile + Vector2i.UP)
		var left := definition.is_solid(tile + Vector2i.LEFT)
		var right := definition.is_solid(tile + Vector2i.RIGHT)
		var below := definition.is_solid(tile + Vector2i.DOWN)
		var family := "solid_fill"
		if not above:
			if not left:
				return "corner_outer_tl"
			if not right:
				return "corner_outer_tr"
			family = "solid_top"
		elif not below:
			family = "solid_bottom"
		elif not left:
			family = "solid_left"
		elif not right:
			family = "solid_right"
		var variation: int = posmod(tile.x * 7 + tile.y * 3, 4)
		return family if variation == 0 else "%s_%d" % [family, variation + 1]
	var family := ""
	if definition.is_one_way(tile):
		family = "one_way"
	elif definition.is_hazard(tile):
		family = "hazard"
	if family.is_empty():
		return ""
	var marker := definition.char_at(tile)
	var left: bool = definition.char_at(tile + Vector2i.LEFT) == marker
	var right: bool = definition.char_at(tile + Vector2i.RIGHT) == marker
	var part := "middle"
	if not left and not right:
		part = "single"
	elif not left:
		part = "left"
	elif not right:
		part = "right"
	return family + "_" + part


## Add this CanvasLayer directly under the matching SubViewport, never World2D.
static func build_background(catalog: AssetCatalog, theme_id: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "Background_" + theme_id
	layer.layer = -10
	var fill := ColorRect.new()
	fill.name = "Sky"
	fill.size = Vector2(480, 360)
	fill.color = Color("10141c")
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fill)
	for part: String in ["far", "middle", "near"]:
		var sprite := Sprite2D.new()
		sprite.name = part
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = catalog.texture("background_%s_%s_v1" % [theme_id, part])
		layer.add_child(sprite)
	return layer


## Finite images pan only a few integer pixels; the far layer and sky stay fixed.
static func update_background(layer: CanvasLayer, camera_position: Vector2, room_bounds: Rect2) -> void:
	var travel := room_bounds.size - Vector2(480, 360)
	var fraction := Vector2(0.5, 0.5)
	if travel.x > 0:
		fraction.x = clampf((camera_position.x - room_bounds.position.x - 240.0) / travel.x, 0.0, 1.0)
	if travel.y > 0:
		fraction.y = clampf((camera_position.y - room_bounds.position.y - 180.0) / travel.y, 0.0, 1.0)
	for index in 2:
		var sprite := layer.get_node("middle" if index == 0 else "near") as Sprite2D
		sprite.position = (Vector2(0.5, 0.5) - fraction) * Vector2(8, 4) * (index + 1)
		sprite.position = sprite.position.round()
