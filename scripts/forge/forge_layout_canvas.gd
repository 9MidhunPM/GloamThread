class_name ForgeLayoutCanvas
extends Control
## Rectangle selection in fixed 1024px source coordinates, never file paths.

signal selection_changed(crop: Array)

var image: Image
var crop := Rect2i(0, 0, 341, 341)
var lock_widescreen: bool = false
var _texture: ImageTexture
var _dragging: bool = false
var _start := Vector2i.ZERO


func set_board(value: Image) -> void:
	image = value
	_texture = ImageTexture.create_from_image(image)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func set_crop(value: Array) -> void:
	crop = Rect2i(value[0], value[1], value[2], value[3])
	queue_redraw()


func image_rect() -> Rect2:
	var extent := minf(size.x, size.y)
	return Rect2((size - Vector2.ONE * extent) * 0.5, Vector2.ONE * extent)


func source_point(point: Vector2) -> Vector2i:
	var rect := image_rect()
	return Vector2i(((point - rect.position) / maxf(rect.size.x, 1.0) * 1024.0).floor().clamp(Vector2.ZERO, Vector2(1023, 1023)))


func select_between(first: Vector2i, last: Vector2i) -> void:
	var low := first.min(last).clamp(Vector2i.ZERO, Vector2i(1020, 1020))
	var high := first.max(last).clamp(Vector2i.ZERO, Vector2i(1023, 1023))
	var extent := (high - low + Vector2i.ONE).max(Vector2i(4, 4))
	if lock_widescreen:
		var units := maxi(1, mini(extent.x / 16, extent.y / 9))
		units = mini(units, mini((1024 - low.x) / 16, (1024 - low.y) / 9))
		if units < 1:
			low = low.min(Vector2i(1008, 1015))
			units = 1
		extent = Vector2i(16, 9) * units
	crop = Rect2i(low, extent)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not image_rect().has_point(event.position):
				return
			_dragging = true
			_start = source_point(event.position)
			select_between(_start, _start)
		elif _dragging:
			select_between(_start, source_point(event.position))
			_dragging = false
			selection_changed.emit([crop.position.x, crop.position.y, crop.size.x, crop.size.y])
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_dragging = false
			return
		select_between(_start, source_point(event.position))
		accept_event()


func _draw() -> void:
	var rect := image_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#101922"))
	if _texture == null:
		return
	draw_texture_rect(_texture, rect, false)
	var selected := Rect2(rect.position + Vector2(crop.position) / 1024.0 * rect.size, Vector2(crop.size) / 1024.0 * rect.size)
	draw_rect(selected, Color(0.89, 0.66, 0.36, 0.15))
	draw_rect(selected, Color.BLACK, false, 5)
	draw_rect(selected, Color("#ffc66e"), false, 2)
