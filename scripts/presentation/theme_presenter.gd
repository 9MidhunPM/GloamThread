class_name ThemePresenter
extends RefCounted
## Opaque ground materials share canonical geometry; every node is render-only.

const TILE_IDS := [
 "floor_path_1", "floor_path_2", "floor_grass_1", "floor_grass_2",
 "wall_fill_1", "wall_fill_2", "wall_fill_3", "wall_fill_4",
 "wall_edge_north", "wall_edge_east", "wall_edge_south", "wall_edge_west",
 "wall_corner_outer_ne", "wall_corner_outer_se", "wall_corner_outer_sw", "wall_corner_outer_nw",
 "wall_corner_inner_ne", "wall_corner_inner_se", "wall_corner_inner_sw", "wall_corner_inner_nw",
 "water_fill_1", "water_fill_2", "water_fill_3", "water_fill_4",
 "water_edge_north", "water_edge_east", "water_edge_south", "water_edge_west",
 "water_corner_ne", "water_corner_se", "water_corner_sw", "water_corner_nw",
 "bridge_plank_1", "bridge_plank_2", "bridge_rail_north", "bridge_rail_south",
 "seam_rune_1", "seam_rune_2", "seam_rune_3", "seam_rune_4",
 "background_earth_1", "background_earth_2", "background_roots_1", "background_roots_2",
 "hazard_glass_1", "hazard_glass_2", "hazard_thread_1", "hazard_thread_2",
]


static func build_terrain(definition: RoomDefinition, catalog: AssetCatalog, theme_id: String) -> TileMapLayer:
	var layer := _layer(catalog, theme_id)
	layer.name = "Terrain"
	for y in definition.height:
		for x in definition.width:
			var index := TILE_IDS.find(_tile_id(definition, Vector2i(x, y)))
			layer.set_cell(Vector2i(x, y), 0, Vector2i(index % 8, index / 8))
	return layer


static func build_bridge(rect: Rect2i, catalog: AssetCatalog, theme_id: String) -> TileMapLayer:
	var layer := _layer(catalog, theme_id)
	layer.name = "RestoredBridge"
	for y in rect.size.y:
		for x in rect.size.x:
			var id := "bridge_plank_%d" % (1 + posmod(x + y, 2))
			if rect.size.y > 2 and y == 0:
				id = "bridge_rail_north"
			elif rect.size.y > 2 and y == rect.size.y - 1:
				id = "bridge_rail_south"
			var index := TILE_IDS.find(id)
			layer.set_cell(rect.position + Vector2i(x, y), 0, Vector2i(index % 8, index / 8))
	return layer


static func _layer(catalog: AssetCatalog, theme_id: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	var source := TileSetAtlasSource.new()
	if catalog != null:
		source.texture = catalog.texture("terrain_%s_v1" % theme_id)
		source.margins = Vector2i(2, 2)
		source.separation = Vector2i(4, 4)
	else:
		# Explicit null-catalog prototype for focused geometry/physics checks.
		# Production must pass the validated original overhead atlas.
		var image := Image.create(128, 96, false, Image.FORMAT_RGBA8)
		for index in 48:
			var colour := Color("705a47") if theme_id == "ember" else Color("42644d")
			if index >= 4 and index < 20: colour = Color("282c38")
			elif index >= 20 and index < 32: colour = Color("273c63")
			elif index >= 32 and index < 36: colour = Color("bfa578")
			elif index >= 44: colour = Color("d27876")
			image.fill_rect(Rect2i(index % 8 * 16, index / 8 * 16, 16, 16), colour)
		source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(16, 16)
	for index in 48:
		source.create_tile(Vector2i(index % 8, index / 8))
	tiles.add_source(source, 0)
	layer.tile_set = tiles
	return layer


static func _tile_id(definition: RoomDefinition, tile: Vector2i) -> String:
	var marker := definition.char_at(tile)
	if marker in ["#", "~"]:
		var material := "wall" if marker == "#" else "water"
		var north := definition.char_at(tile + Vector2i.UP) != marker
		var east := definition.char_at(tile + Vector2i.RIGHT) != marker
		var south := definition.char_at(tile + Vector2i.DOWN) != marker
		var west := definition.char_at(tile + Vector2i.LEFT) != marker
		var corner := ""
		if north and east: corner = "ne"
		elif east and south: corner = "se"
		elif south and west: corner = "sw"
		elif west and north: corner = "nw"
		if not corner.is_empty():
			return material + ("_corner_outer_" if marker == "#" else "_corner_") + corner
		for pair: Array in [[north, "north"], [east, "east"], [south, "south"], [west, "west"]]:
			if pair[0]: return material + "_edge_" + pair[1]
		if marker == "#":
			for pair: Array in [[Vector2i(1,-1),"ne"],[Vector2i(1,1),"se"],[Vector2i(-1,1),"sw"],[Vector2i(-1,-1),"nw"]]:
				if definition.char_at(tile + pair[0]) != "#": return "wall_corner_inner_" + pair[1]
		return "%s_fill_%d" % [material, 1 + posmod(tile.x * 3 + tile.y, 4)]
	if marker == "=": return "bridge_plank_%d" % (1 + posmod(tile.x + tile.y, 2))
	if marker == "^": return "hazard_%s_%d" % ["glass" if definition.id == "r03" else "thread", 1 + posmod(tile.x + tile.y, 2)]
	var main_path := absi(tile.y - definition.height / 2) <= 3 or absi(tile.x - definition.width / 2) <= 2
	return "floor_%s_%d" % ["path" if main_path else "grass", 1 + posmod(tile.x * 5 + tile.y * 3, 2)]


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
