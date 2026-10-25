class_name ArenaFrontier
extends Node2D
## Boundary scenery only: the session retains all movement and expansion rules.

const WOOD := Color("29434a")
const SHADOW := Color("101d28")
const EDGE := Color("71958a")
const BRASS := Color("ba8754")
const LIGHT := Color("efcb91")

var bounds := Rect2()
var regions: int = 1
var font: Font
var label: String = ""


func setup(world_bounds: Rect2, region_count: int, world_font: Font) -> void:
	bounds = world_bounds
	regions = clampi(region_count, 1, 4)
	font = world_font
	label = "NEXT REGION AFTER WAVE %d" % (regions * 5) if regions < 4 else "EDGE OF THE LOOM"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 2
	queue_redraw()


func _draw() -> void:
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return
	_boundary(bounds.position.x, 1)
	_boundary(bounds.end.x, -1)
	_gate(bounds.position.x, 1, "THE LOOM BEGINS")
	_gate(bounds.end.x, -1, label)


func _boundary(edge_x: float, inward: int) -> void:
	# The entire height is marked, including the shallow cave and raised route.
	var x := roundf(edge_x + inward * 5)
	draw_rect(Rect2(edge_x - 1 if inward < 0 else edge_x, bounds.position.y, 1, bounds.size.y), EDGE)
	draw_rect(Rect2(x - 3, bounds.position.y, 6, bounds.size.y), SHADOW)
	draw_rect(Rect2(x - 1, bounds.position.y, 2, bounds.size.y), WOOD)
	for y in range(ceili(bounds.position.y / 48.0) * 48, int(bounds.end.y), 48):
		draw_rect(Rect2(x - 4, y, 8, 4), BRASS)
		draw_rect(Rect2(x - 3, y + 4, 6, 2), EDGE)
		# Inward stitches lead the eye back toward traversable world space.
		draw_line(Vector2(x + inward * 4, y + 3), Vector2(x + inward * 12, y + 9), WOOD, 2)
	for foot_y in [320.0, 624.0]:
		_lantern(Vector2(x + inward * 12, bounds.position.y + foot_y - 30))


func _gate(edge_x: float, inward: int, caption: String) -> void:
	var post_x := roundf(edge_x + inward * 16)
	var ground := bounds.position.y + 320
	draw_rect(Rect2(post_x - 4, ground - 76, 8, 76), SHADOW)
	draw_rect(Rect2(post_x - 2, ground - 74, 4, 74), WOOD)
	for y in [ground - 69, ground - 12]:
		draw_rect(Rect2(post_x - 4, y, 8, 4), BRASS)
	var reach := Vector2(post_x + inward * 30, ground - 76)
	draw_line(Vector2(post_x, ground - 76), reach, SHADOW, 6)
	draw_line(Vector2(post_x, ground - 77), reach, EDGE, 2)
	_lantern(reach + Vector2(0, 9))
	# At the playable edge, the board extends inward so either camera can read it.
	if font == null:
		return
	var text_size := 8
	var board_width := ceilf(font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x) + 14
	var board_x := edge_x + 26 if inward > 0 else edge_x - board_width - 26
	var board := Rect2(roundf(board_x), ground - 106, board_width, 21)
	draw_rect(board.grow(1), SHADOW)
	draw_rect(board, WOOD)
	draw_rect(Rect2(board.position, Vector2(board.size.x, 2)), BRASS)
	for x in [board.position.x + 3, board.end.x - 4]:
		draw_rect(Rect2(x, board.position.y + 8, 2, 2), LIGHT)
	draw_string(font, board.position + Vector2(7, 14), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, LIGHT)
	draw_line(Vector2(post_x, ground - 76), Vector2(board_x + (0 if inward > 0 else board_width), ground - 85), BRASS, 1)


func _lantern(at: Vector2) -> void:
	at = at.round()
	draw_rect(Rect2(at - Vector2(9, 5), Vector2(18, 17)), Color(LIGHT, 0.06))
	draw_line(at - Vector2(0, 7), at - Vector2(0, 2), BRASS, 1)
	draw_rect(Rect2(at - Vector2(5, 2), Vector2(10, 11)), SHADOW)
	draw_rect(Rect2(at - Vector2(3, 0), Vector2(6, 7)), BRASS)
	draw_rect(Rect2(at - Vector2(2, -1), Vector2(4, 4)), LIGHT)
	draw_rect(Rect2(at - Vector2(6, 3), Vector2(12, 2)), EDGE)
	draw_rect(Rect2(at + Vector2(-5, 8), Vector2(10, 2)), EDGE)
