class_name ArenaParallax
extends Node2D
## Per-view scenery only. Shared terrain/actors stay in the authoritative world.

const INDEX := "res://assets/arena/scenery/index.json"
const FOLDER := "res://assets/arena/scenery"
const FILES := ["sky.png", "far.png", "canopy.png", "foreground.png"]
static var _media: Array[Dictionary] = []
static var _loaded: bool = false
static var _errors := PackedStringArray()

var view_size := Vector2i(640, 360)
var world_origin := Vector2.ZERO
var appearance: Dictionary = {}
var _clock: int = 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_media()


func update_view(origin: Vector2, dimensions: Vector2i, theme: Dictionary) -> void:
	if world_origin != origin or view_size != dimensions or appearance.get("id", "") != theme.get("id", ""):
		world_origin = origin
		view_size = dimensions
		appearance = theme
		queue_redraw()


func _physics_process(_delta: float) -> void:
	_clock += 1
	if _clock % 8 == 0:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(view_size)), Color("101c29"))
	var palette: Array = appearance.get("theme", {}).get("palette", ["#213b46", "#3e696a", "#8bab91", "#f2ca80"])
	var accent := Color(str(palette[mini(2, palette.size() - 1)]))
	var background: Texture2D = appearance.get("background")
	if _media.is_empty():
		if background != null:
			_repeat(background, Vector2(-world_origin.x * 0.08, -world_origin.y * 0.03), Color.WHITE)
		return
	for index in _media.size():
		var record: Dictionary = _media[index]
		var drift := roundf(sin(float(_clock) / 320.0 + index) * (2.0 if index == 0 else 1.0))
		var offset := Vector2(-world_origin.x * float(record.factor) + drift, -world_origin.y * float(record.y_factor))
		var tint := Color.WHITE.lerp(accent.lightened(0.3), 0.18 if index == 0 else 0.3)
		_repeat(record.texture, offset, tint)
		if index == 0 and background != null:
			# Retained/generated scenery colours remain visible between the original
			# silhouette layers; neither image determines collisions or navigation.
			_repeat(background, Vector2(-world_origin.x * 0.1, -world_origin.y * 0.05), Color(1, 1, 1, 0.28))


func _repeat(texture: Texture2D, at: Vector2, tint: Color) -> void:
	var width := int(texture.get_width())
	var height := int(texture.get_height())
	if width <= 0 or height <= 0:
		return
	var start := Vector2(posmod(roundi(at.x), width) - width, posmod(roundi(at.y), height) - height)
	for x in range(int(start.x), view_size.x, width):
		for y in range(int(start.y), view_size.y, height):
			draw_texture(texture, Vector2(x, y), tint)


static func _load_media() -> void:
	if _loaded:
		return
	_loaded = true
	var result := _inspect_media(INDEX, true)
	_errors = result.errors
	_media = result.layers


static func media_errors(index_path: String = INDEX) -> PackedStringArray:
	if index_path == INDEX:
		_load_media()
		return _errors.duplicate()
	# Explicit alternate indexes are useful for isolated admission checks. They
	# neither populate nor clear the running game's immutable texture/error cache.
	return _inspect_media(index_path, false).errors


static func _inspect_media(index_path: String, create_textures: bool) -> Dictionary:
	var errors := PackedStringArray()
	var checked: Array[Dictionary] = []
	var file := FileAccess.open(index_path, FileAccess.READ)
	if file == null:
		return {"layers": checked, "errors": PackedStringArray(["Required scrolling scenery index is missing. Reinstall the complete game."])}
	if file.get_length() <= 0 or file.get_length() > 65536:
		return {"layers": checked, "errors": PackedStringArray(["Scrolling scenery index is empty or exceeds its size limit."])}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"layers": checked, "errors": PackedStringArray(["Scrolling scenery index is not valid JSON."])}
	var raw: Variant = parser.data
	if not raw is Dictionary or typeof(raw.get("schema_version")) == TYPE_BOOL or raw.get("schema_version") != 1 or raw.get("content_version") != "scrolling-world-v1" or not raw.get("layers") is Array:
		return {"layers": checked, "errors": PackedStringArray(["Scrolling scenery index has an unsupported version or missing layer list."])}
	if raw.layers.size() != FILES.size():
		errors.append("Scrolling scenery requires exactly four layers: sky, far, canopy and foreground.")
	for index in FILES.size():
		var label: String = FILES[index]
		if index >= raw.layers.size():
			errors.append("Required scenery layer " + label + " is missing from the index.")
			continue
		var record: Variant = raw.layers[index]
		if not record is Dictionary or record.get("file") != label or record.get("id") != label.get_basename() or not record.get("sha256") is String or record.sha256.length() != 64:
			errors.append("Scenery record for " + label + " has an invalid identity, filename or hash.")
			continue
		var declared: Variant = record.get("size")
		if not declared is Array or declared.size() != 2 or not _dimension(declared[0], 640) or not _dimension(declared[1], 360):
			errors.append("Scenery layer " + label + " must declare a 640 x 360 image.")
			continue
		var factor: Variant = record.get("factor")
		var y_factor: Variant = record.get("y_factor")
		if not _factor(factor) or not _factor(y_factor):
			errors.append("Scenery layer " + label + " has a non-finite or out-of-range parallax factor.")
			continue
		var path := index_path.get_base_dir().path_join(label)
		var image_file := FileAccess.open(path, FileAccess.READ)
		if image_file == null:
			errors.append("Required scenery layer " + label + " is missing. Reinstall the complete game.")
			continue
		if image_file.get_length() <= 0 or image_file.get_length() > 4 * 1024 * 1024:
			errors.append("Scenery layer " + label + " is empty or exceeds its size limit.")
			continue
		var bytes := image_file.get_buffer(image_file.get_length())
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(bytes)
		if hash.finish().hex_encode() != record.sha256:
			errors.append("Scenery layer " + label + " failed its integrity hash check.")
			continue
		# Check bounded dimensions before allocating decoded image pixels.
		if bytes.size() < 33 or bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]) or bytes.slice(12, 16).get_string_from_ascii() != "IHDR" or bytes.slice(16, 24) != PackedByteArray([0, 0, 2, 128, 0, 0, 1, 104]):
			errors.append("Scenery layer " + label + " must be a 640 x 360 PNG.")
			continue
		var image := Image.new()
		if image.load_png_from_buffer(bytes) != OK or image.get_size() != Vector2i(640, 360):
			errors.append("Scenery layer " + label + " could not be decoded as a complete image.")
			continue
		checked.append({"texture": ImageTexture.create_from_image(image) if create_textures else null, "factor": float(factor), "y_factor": float(y_factor)})
	if not errors.is_empty():
		checked.clear()
	return {"layers": checked, "errors": errors}


static func _factor(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= 0 and value <= 1


static func _dimension(value: Variant, expected: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == expected
