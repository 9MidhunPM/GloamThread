class_name AssetCatalog
extends RefCounted
## Small fixed-bundle boundary. Content selects data, never scripts/resources.

var entries: Dictionary = {}
var errors: PackedStringArray = PackedStringArray()


static func load_from_path(path: String) -> AssetCatalog:
	var catalog := AssetCatalog.new()
	if not FileAccess.file_exists(path):
		catalog.errors.append("Asset manifest is missing: %s" % path)
		return catalog
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema_version") != 1:
		catalog.errors.append("Asset manifest must be a schema-version-1 object")
		return catalog
	var assets: Variant = parsed.get("assets")
	if not assets is Array:
		catalog.errors.append("Asset manifest assets must be an array")
		return catalog
	for record: Variant in assets:
		if not record is Dictionary:
			catalog.errors.append("Asset records must be objects")
			continue
		var asset_id: String = str(record.get("id", ""))
		var asset_path: String = str(record.get("path", ""))
		var kind: String = str(record.get("kind", ""))
		if asset_id.is_empty() or catalog.entries.has(asset_id):
			catalog.errors.append("Missing or duplicate asset id: %s" % asset_id)
			continue
		if not safe_output_path(asset_path):
			catalog.errors.append("Unsafe asset path for %s" % asset_id)
			continue
		var expected_extension := ""
		match kind:
			"sprite_atlas", "tile_atlas", "image": expected_extension = "png"
			"font": expected_extension = "fnt"
			"sfx", "music": expected_extension = "wav"
			_:
				catalog.errors.append("Unknown asset kind for %s" % asset_id)
				continue
		if asset_path.get_extension() != expected_extension:
			catalog.errors.append("Asset kind/path mismatch for %s" % asset_id)
			continue
		catalog.entries[asset_id] = record.duplicate(true)
	return catalog


static func safe_output_path(path: String) -> bool:
	if not path.begins_with("assets/generated/") or path.contains("\\") or path.contains(":"):
		return false
	for part in path.split("/"):
		if part == ".." or part == "." or part.is_empty():
			return false
	return true


func frame_texture(asset_id: String, frame_index: int = 0) -> Texture2D:
	if not entries.has(asset_id):
		errors.append("Required sprite asset is missing: %s" % asset_id)
		return null
	var record: Dictionary = entries[asset_id]
	if record.get("kind") not in ["sprite_atlas", "tile_atlas", "image"]:
		errors.append("Required asset is not an image: %s" % asset_id)
		return null
	var texture := load("res://" + str(record["path"])) as Texture2D
	if texture == null:
		errors.append("Image could not load: %s" % asset_id)
		return null
	var size: Variant = record.get("size")
	if not size is Array or size.size() != 2 or size[0] != texture.get_width() or size[1] != texture.get_height():
		errors.append("Image dimensions disagree with manifest: %s" % asset_id)
		return null
	var frames: Variant = record.get("frames")
	if not frames is Array or frame_index < 0 or frame_index >= frames.size():
		errors.append("Image frame is missing: %s" % asset_id)
		return null
	var rectangle: Variant = frames[frame_index]
	if not rectangle is Array or rectangle.size() != 4:
		errors.append("Image frame rectangle is malformed: %s" % asset_id)
		return null
	for value: Variant in rectangle:
		if not RoomDefinition._is_integer(value):
			errors.append("Image frame coordinates must be integers: %s" % asset_id)
			return null
	var region := Rect2(float(rectangle[0]), float(rectangle[1]), float(rectangle[2]), float(rectangle[3]))
	if region.size.x <= 0 or region.size.y <= 0 or not Rect2(Vector2.ZERO, texture.get_size()).encloses(region):
		errors.append("Image frame exceeds its atlas: %s" % asset_id)
		return null
	var frame := AtlasTexture.new()
	frame.atlas = texture
	frame.region = region
	return frame
