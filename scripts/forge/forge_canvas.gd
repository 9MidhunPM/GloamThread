class_name ForgeCanvas
extends Control
## Small pixel canvas shared by drawing and transparent part-mask correction.

signal changed
signal pivot_changed(value: Vector2)

var ink := Color("#e4a85b")
var brush_size: int = 8
var eraser: bool = false
var pivot_mode: bool = false
var pivot := Vector2(32, 32)
var pixels: Image
var _texture: ImageTexture
var _part: Image
var _drawing: bool = false
var _previous := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if pixels == null:
		clear_canvas()


func clear_canvas() -> void:
	pixels = Image.create(512, 512, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	_part = null
	_refresh()


func set_image(image: Image) -> void:
	pixels = image.duplicate()
	pixels.convert(Image.FORMAT_RGBA8)
	_part = null
	_refresh()


func set_mask(part: Image, mask: Image, joint: Vector2) -> void:
	_part = part.duplicate()
	_part.convert(Image.FORMAT_RGBA8)
	pixels = mask.duplicate()
	pixels.convert(Image.FORMAT_RGBA8)
	pivot = joint
	brush_size = 2
	_refresh()


func has_drawing() -> bool:
	return pixels != null and not pixels.is_invisible()


func paint_at(point: Vector2) -> void:
	if pixels == null:
		return
	var radius := maxi(1, brush_size)
	var color := Color.TRANSPARENT if eraser else (Color.WHITE if _part != null else ink)
	for y in range(maxi(0, int(point.y) - radius), mini(pixels.get_height(), int(point.y) + radius + 1)):
		for x in range(maxi(0, int(point.x) - radius), mini(pixels.get_width(), int(point.x) + radius + 1)):
			if Vector2(x, y).distance_to(point) <= radius:
				pixels.set_pixel(x, y, color)
	_refresh()
	changed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drawing = event.pressed
		if _drawing:
			_previous = _to_pixel(event.position)
			if pivot_mode:
				_set_pivot(_previous)
			else:
				paint_at(_previous)
		accept_event()
	elif event is InputEventMouseMotion and _drawing:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_drawing = false
			return
		var current := _to_pixel(event.position)
		if pivot_mode:
			_set_pivot(current)
		else:
			var steps := maxi(1, ceili(_previous.distance_to(current) / maxf(1.0, brush_size * 0.5)))
			for index in range(1, steps + 1):
				paint_at(_previous.lerp(current, float(index) / steps))
		_previous = current
		accept_event()


func _set_pivot(point: Vector2) -> void:
	pivot = point.round().clamp(Vector2.ZERO, Vector2(pixels.get_size()) - Vector2.ONE)
	queue_redraw()
	pivot_changed.emit(pivot)


func _to_pixel(point: Vector2) -> Vector2:
	var rect := _image_rect()
	return ((point - rect.position) / rect.size * Vector2(pixels.get_size())).clamp(Vector2.ZERO, Vector2(pixels.get_size()) - Vector2.ONE)


func _image_rect() -> Rect2:
	if pixels == null:
		return Rect2(Vector2.ZERO, size)
	var scale_factor := minf(size.x / pixels.get_width(), size.y / pixels.get_height())
	var extent := Vector2(pixels.get_size()) * scale_factor
	return Rect2((size - extent) * 0.5, extent)


func _refresh() -> void:
	var display: Image = pixels
	if _part != null:
		display = _part.duplicate()
		for y in display.get_height():
			for x in display.get_width():
				var colour := display.get_pixel(x, y)
				colour.a *= pixels.get_pixel(x, y).a
				display.set_pixel(x, y, colour)
	_texture = ImageTexture.create_from_image(display)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#17232e"))
	for y in range(0, int(size.y), 24):
		for x in range(0, int(size.x), 24):
			if (x / 24 + y / 24) % 2 == 0:
				draw_rect(Rect2(x, y, mini(24, int(size.x) - x), mini(24, int(size.y) - y)), Color("#21313c"))
	if _texture != null:
		var rect := _image_rect()
		draw_texture_rect(_texture, rect, false)
		if _part != null:
			var joint := rect.position + pivot / Vector2(pixels.get_size()) * rect.size
			draw_circle(joint, 7, Color("#f4bf70"), false, 2)
			draw_line(joint - Vector2(12, 0), joint + Vector2(12, 0), Color.WHITE, 2)
			draw_line(joint - Vector2(0, 12), joint + Vector2(0, 12), Color.WHITE, 2)
