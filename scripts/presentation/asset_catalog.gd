class_name AssetCatalog
extends RefCounted
## ResourceLoader preserves exported import remaps. Offline tools verify hashes.

var entries: Dictionary = {}
var sfx: Dictionary = {}
var music: Dictionary = {}
var stage: String = ""
var errors: PackedStringArray = PackedStringArray()
var _textures: Dictionary = {}
var _frames: Dictionary = {}
var _streams: Dictionary = {}
var _font: Font


static func load_from_path(path: String) -> AssetCatalog:
	var catalog := AssetCatalog.new()
	if not FileAccess.file_exists(path):
		catalog.errors.append("Asset manifest is missing: %s" % path)
		return catalog
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		catalog.errors.append("Asset manifest must be a JSON object")
		return catalog
	var parsed: Dictionary = parser.data
	if not RoomDefinition._is_integer(parsed.get("schema_version")) or parsed.schema_version != 1 or not parsed.get("content_version") is String or parsed.content_version != "overhead-v1":
		catalog.errors.append("Asset manifest requires schema 1 and content overhead-v1")
		return catalog
	catalog.stage = str(parsed.get("stage", ""))
	if catalog.stage not in ["diagnostic", "full"]:
		catalog.errors.append("Asset stage must be diagnostic or full")
	if not parsed.get("assets") is Array:
		catalog.errors.append("Asset manifest assets must be an array")
		return catalog
	for record: Variant in parsed["assets"]:
		catalog._read_record(record)
	for name: String in ["sfx", "music"]:
		var mapping: Variant = parsed.get(name)
		if not mapping is Dictionary:
			catalog.errors.append("Manifest %s must be an object" % name)
			continue
		for cue: Variant in mapping:
			var asset_id: Variant = mapping[cue]
			if not cue is String or not asset_id is String or not catalog.entries.has(asset_id) or catalog.entries[asset_id].get("kind") != name:
				catalog.errors.append("Invalid %s reference: %s" % [name, str(cue)])
				continue
			if name == "sfx":
				catalog.sfx[cue] = asset_id
			else:
				catalog.music[cue] = asset_id
	return catalog


func _read_record(raw: Variant) -> void:
	if not raw is Dictionary:
		errors.append("Asset records must be objects")
		return
	var record: Dictionary = raw
	var asset_id: Variant = record.get("id")
	var path: Variant = record.get("path")
	var kind: Variant = record.get("kind")
	if not asset_id is String or asset_id.is_empty() or entries.has(asset_id):
		errors.append("Missing or duplicate asset id: %s" % str(asset_id))
		return
	if not path is String or not safe_output_path(path):
		errors.append("Unsafe asset path: %s" % asset_id)
		return
	var extensions := {"sprite_atlas": "png", "tile_atlas": "png", "image": "png", "font": "fnt", "sfx": "wav", "music": "wav"}
	if not kind is String or not extensions.has(kind) or path.get_extension() != extensions[kind]:
		errors.append("Asset kind/path mismatch: %s" % asset_id)
		return
	var errors_before := errors.size()
	if not record.get("diagnostic") is bool or (stage == "full" and record.get("diagnostic")):
		errors.append("Invalid diagnostic status: %s" % asset_id)
	if kind in ["sprite_atlas", "tile_atlas", "image"] and not _numbers(record.get("size"), 2, 1):
		errors.append("Invalid image size: %s" % asset_id)
	if kind in ["sprite_atlas", "tile_atlas"]:
		_validate_atlas(asset_id, record)
	if kind in ["sfx", "music"]:
		for field: String in ["sample_rate", "channels", "sample_width_bytes", "sample_frames"]:
			if not RoomDefinition._is_integer(record.get(field)) or record[field] <= 0:
				errors.append("Invalid audio %s: %s" % [field, asset_id])
		if errors.size() != errors_before:
			return
		if record.get("sample_rate") != 44100 or record.get("sample_width_bytes") != 2 or record.get("channels") != (1 if kind == "sfx" else 2):
			errors.append("Unsupported PCM format: %s" % asset_id)
		var first: Variant = record.get("loop_start")
		var last: Variant = record.get("loop_end")
		if not record.has_all(["loop_start", "loop_end"]):
			errors.append("Missing audio loop fields: %s" % asset_id)
		elif first != null or last != null:
			if not RoomDefinition._is_integer(first) or not RoomDefinition._is_integer(last) or first < 0 or last <= first or last > record.get("sample_frames", 0):
				errors.append("Invalid audio loop bounds: %s" % asset_id)
	# Invalid records never reach resource consumers, even while the complete
	# bundle continues collecting useful validation messages.
	if errors.size() == errors_before:
		entries[asset_id] = record.duplicate(true)


func _validate_atlas(asset_id: String, record: Dictionary) -> void:
	if not _numbers(record.get("cell_size"), 2, 1) or not _numbers(record.get("origin"), 2, 0):
		errors.append("Invalid atlas cell/origin: %s" % asset_id)
	var frames: Variant = record.get("frames")
	if not frames is Array or frames.is_empty():
		errors.append("Atlas frames are missing: %s" % asset_id)
		return
	for frame: Variant in frames:
		if not _numbers(frame, 4, 0) or frame[2] <= 0 or frame[3] <= 0:
			errors.append("Invalid atlas frame: %s" % asset_id)
		elif _numbers(record.get("size"), 2, 1) and (frame[0] + frame[2] > record["size"][0] or frame[1] + frame[3] > record["size"][1]):
			errors.append("Frame outside atlas: %s" % asset_id)
	var clips: Variant = record.get("animations")
	if not clips is Dictionary:
		errors.append("Atlas animations must be an object: %s" % asset_id)
		return
	for state: Variant in clips:
		var clip: Variant = clips[state]
		if not clip is Dictionary or not clip.get("frames") is Array or not clip.get("ticks") is Array or not clip.get("loop") is bool:
			errors.append("Invalid animation: %s/%s" % [asset_id, str(state)])
			continue
		if clip["frames"].is_empty() or clip["frames"].size() != clip["ticks"].size():
			errors.append("Animation frame/tick counts differ: %s/%s" % [asset_id, str(state)])
			continue
		for i in clip["frames"].size():
			if not RoomDefinition._is_integer(clip["frames"][i]) or clip["frames"][i] < 0 or clip["frames"][i] >= frames.size() or not RoomDefinition._is_integer(clip["ticks"][i]) or clip["ticks"][i] <= 0:
				errors.append("Invalid animation index/duration: %s/%s" % [asset_id, str(state)])


static func _numbers(value: Variant, count: int, minimum: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for number: Variant in value:
		if not RoomDefinition._is_integer(number) or number < minimum:
			return false
	return true


static func safe_output_path(path: String) -> bool:
	if not path.begins_with("assets/generated/") or path.contains("\\") or path.contains(":"):
		return false
	for index in path.length():
		if path.unicode_at(index) < 32:
			return false
	for part: String in path.split("/"):
		if part == ".." or part == "." or part.is_empty():
			return false
	return true


func texture(asset_id: String) -> Texture2D:
	if _textures.has(asset_id):
		return _textures[asset_id]
	if not entries.has(asset_id) or entries[asset_id].get("kind") not in ["sprite_atlas", "tile_atlas", "image"]:
		errors.append("Required image is missing: %s" % asset_id)
		return null
	var record: Dictionary = entries[asset_id]
	var resource_path := "res://" + str(record["path"])
	if not ResourceLoader.exists(resource_path):
		errors.append("Required image resource is missing: %s" % asset_id)
		return null
	var loaded := load(resource_path) as Texture2D
	if loaded == null or not dimensions_match(record.get("size"), loaded.get_width(), loaded.get_height()):
		errors.append("Image missing or dimensions differ: %s" % asset_id)
		return null
	_textures[asset_id] = loaded
	return loaded


static func dimensions_match(value: Variant, width: int, height: int) -> bool:
	return _numbers(value, 2, 1) and int(value[0]) == width and int(value[1]) == height


func frame_texture(asset_id: String, frame_index: int = 0) -> Texture2D:
	var key := "%s:%d" % [asset_id, frame_index]
	if _frames.has(key):
		return _frames[key]
	var whole := texture(asset_id)
	if whole == null:
		return null
	var rectangles: Variant = entries[asset_id].get("frames")
	if not rectangles is Array or frame_index < 0 or frame_index >= rectangles.size():
		errors.append("Image frame is missing: %s/%d" % [asset_id, frame_index])
		return null
	var rect: Array = rectangles[frame_index]
	var frame := AtlasTexture.new()
	frame.atlas = whole
	frame.region = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
	_frames[key] = frame
	return frame


func animation(asset_id: String, state: String) -> Dictionary:
	var record: Dictionary = entries.get(asset_id, {})
	var clips: Variant = record.get("animations", {})
	if not clips is Dictionary:
		errors.append("Atlas animations must be an object: %s" % asset_id)
		return {}
	var clip: Variant = clips.get(state, {})
	if not clip is Dictionary:
		errors.append("Animation must be an object: %s/%s" % [asset_id, state])
		return {}
	return clip


func font() -> Font:
	if _font == null and entries.has("font_v1"):
		var resource_path := "res://" + str(entries["font_v1"]["path"])
		if ResourceLoader.exists(resource_path):
			_font = load(resource_path) as Font
	if _font == null:
		errors.append("Original font could not load")
	return _font


func audio(asset_id: String) -> AudioStream:
	if _streams.has(asset_id):
		return _streams[asset_id]
	if not entries.has(asset_id) or entries[asset_id].get("kind") not in ["sfx", "music"]:
		errors.append("Required audio is missing: %s" % asset_id)
		return null
	var record: Dictionary = entries[asset_id]
	var resource_path := "res://" + str(record["path"])
	if not ResourceLoader.exists(resource_path):
		errors.append("Required PCM resource is missing: %s" % asset_id)
		return null
	var source := load(resource_path) as AudioStreamWAV
	if source == null:
		errors.append("PCM stream could not load: %s" % asset_id)
		return null
	var stream := source.duplicate() as AudioStreamWAV
	if record.get("loop_start") != null:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = int(record["loop_start"])
		stream.loop_end = int(record["loop_end"])
	else:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_streams[asset_id] = stream
	return stream
