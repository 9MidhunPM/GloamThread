class_name GrayboxSkin
extends RefCounted
## Render-only diagnostic terrain skin used before the finished theme art
## (milestone M4 replaces it with ThemePresenter). It draws the same logical
## grid for both themes with a different tint so the per-viewport culling can
## be checked by eye. Contains no collision, triggers or scripts with effects.

const DIAG_TILES := "res://assets/generated/diagnostic/tiles_diag.png"
## Atlas slots in the diagnostic tile sheet (8 columns, padded 20px stride).
const SLOT_FILL := Vector2i(0, 0)
const SLOT_TOP := Vector2i(1, 0)
const SLOT_ONE_WAY := Vector2i(2, 0)
const SLOT_HAZARD := Vector2i(3, 0)


static func build_layer(definition: RoomDefinition, layer_name: String, tint: Color) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = _make_tile_set()
	layer.modulate = tint
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for y in definition.height:
		for x in definition.width:
			var tile := Vector2i(x, y)
			var slot := _slot_for(definition, tile)
			if slot.x >= 0:
				layer.set_cell(tile, 0, slot)
	return layer


static func _slot_for(definition: RoomDefinition, tile: Vector2i) -> Vector2i:
	if definition.is_solid(tile):
		return SLOT_FILL if definition.is_solid(tile + Vector2i.UP) else SLOT_TOP
	if definition.is_one_way(tile):
		return SLOT_ONE_WAY
	if definition.is_hazard(tile):
		return SLOT_HAZARD
	return Vector2i(-1, -1)


static func _make_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(RoomDefinition.TILE, RoomDefinition.TILE)
	var source := TileSetAtlasSource.new()
	var texture: Texture2D = load(DIAG_TILES)
	if texture == null:
		push_error("GrayboxSkin: missing %s; run python3 tools/generate_assets.py" % DIAG_TILES)
		return tile_set
	source.texture = texture
	source.margins = Vector2i(2, 2)
	source.separation = Vector2i(4, 4)
	source.texture_region_size = Vector2i(RoomDefinition.TILE, RoomDefinition.TILE)
	for slot in [SLOT_FILL, SLOT_TOP, SLOT_ONE_WAY, SLOT_HAZARD]:
		source.create_tile(slot)
	tile_set.add_source(source, 0)
	return tile_set
