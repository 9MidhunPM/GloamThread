extends Control
## Original menu-only composition using the project's retained pixel art.
## No gameplay actors, world, collision, rewards or audio are instantiated here.

const Action := CommandSnapshot.Action
const EMBER := Color("#e3ad6a")
const MOSS := Color("#bce0a1")
const INK := Color("#10141c")

var _catalog: AssetCatalog
var _font: Font
var _clock: float = 0.0
var _textures: Dictionary = {}
var _guides: Array[Label] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true


func configure(font: Font) -> void:
	_font = font
	if _catalog == null:
		# Fixed local IDs only. This optional illustration is not a user-bundle
		# admission path; the application validates required resources first.
		_catalog = AssetCatalog.load_from_path("res://assets/manifest.json")
		for theme: String in ["ember", "moss"]:
			for part: String in ["far", "middle", "near"]:
				var id := "background_%s_%s_v1" % [theme, part]
				_textures[id] = _catalog.texture(id)
		for id: String in ["fixed_tavi_v1", "fixed_neri_v1", "terrain_ember_v1", "terrain_moss_v1", "props_v1"]:
			_textures[id] = _catalog.texture(id)
	if _guides.is_empty():
		for slot in 2:
			var guide := Label.new()
			guide.name = "P%dGuide" % [slot + 1]
			guide.position = Vector2(10 + slot * 200, 232)
			guide.size = Vector2(170, 26)
			guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			guide.max_lines_visible = 3
			guide.add_theme_font_size_override("font_size", 8)
			guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
			guide.focus_mode = Control.FOCUS_NONE
			add_child(guide)
			_guides.append(guide)
	update_controls()
	queue_redraw()


func update_controls() -> void:
	for slot in _guides.size():
		var bindings := InputRouter.bindings_of(slot)
		if bindings == null:
			_guides[slot].text = "P%d: Choose input in New journey" % [slot + 1]
		else:
			var text := "P%d IN GAME\n[%s] Slash / [%s] Special" % [
				slot + 1, bindings.prompt_label(Action.ATTACK),
				bindings.prompt_label(Action.SPECIAL)]
			var clean := ""
			for character in text:
				var code := character.unicode_at(0)
				clean += character if character == "\n" or (code >= 32 and code <= 126) else char(65533)
			_guides[slot].text = clean


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	# A decorative menu clock only; world timers remain at the physics rate.
	_clock = fmod(_clock + delta, 240.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 388, 264), INK)
	for side in 2:
		var theme := "ember" if side == 0 else "moss"
		var rect := Rect2(side * 200, 0, 188, 220)
		for part: String in ["far", "middle", "near"]:
			var texture: Texture2D = _textures.get("background_%s_%s_v1" % [theme, part])
			if texture != null:
				draw_texture_rect_region(texture, rect, Rect2(120, 80, 188, 220))
		# Terrain remains decorative. Both halves share one authored baseline.
		for tile in 12:
			_draw_frame("terrain_%s_v1" % theme, 1, Vector2(side * 200 + tile * 16, 202), 1)
		draw_rect(rect, EMBER if side == 0 else MOSS, false, 1)
	# Brass loom ribs and a shared thread connect the two material treatments.
	for x: int in [181, 203]:
		draw_rect(Rect2(x, 28, 4, 174), Color("#845044"))
		draw_rect(Rect2(x + 1, 28, 1, 174), EMBER)
	draw_line(Vector2(181, 32), Vector2(207, 32), EMBER, 2)
	draw_line(Vector2(185, 88), Vector2(203, 88), Color("#d5d2b8"), 1)
	draw_line(Vector2(185, 116), Vector2(203, 116), MOSS, 1)
	for x in range(188, 202, 3):
		draw_line(Vector2(x, 36), Vector2(x, 198), Color("#644258"), 1)
	_draw_frame("fixed_tavi_v1", int(_clock * 5) % 4, Vector2(44, 116), 2)
	_draw_frame("fixed_neri_v1", int(_clock * 5) % 4, Vector2(260, 116), 2)
	_draw_frame("props_v1", 7, Vector2(178, 142), 1)
	for i in 8:
		var x := 16 + i * 47
		var y := 40 + posmod(int(_clock * 5) + i * 23, 100)
		draw_rect(Rect2(x, y, 1, 2), EMBER if i < 4 else MOSS)
	if _font != null:
		draw_string(_font, Vector2(12, 18), "EMBER", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, EMBER)
		draw_string(_font, Vector2(346, 18), "MOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, MOSS)
		draw_string(_font, Vector2(100, 226), "TWO ENDS. ONE ADVENTURE.", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#d5d2b8"))


func _draw_frame(id: String, index: int, position: Vector2, scale: int) -> void:
	if _catalog == null:
		return
	var record: Dictionary = _catalog.entries.get(id, {})
	var frames: Array = record.get("frames", [])
	var texture: Texture2D = _textures.get(id)
	if texture == null or index < 0 or index >= frames.size():
		return
	var frame: Array = frames[index]
	draw_texture_rect_region(texture, Rect2(position, Vector2(frame[2], frame[3]) * scale),
		Rect2(frame[0], frame[1], frame[2], frame[3]))
