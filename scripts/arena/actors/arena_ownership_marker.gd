class_name ArenaOwnershipMarker
extends Node2D
## Small original pixel glyph and grounding ellipse keep identical rigs readable.
const COLORS := [Color("#f6c667"), Color("#68d9df")]
const GLYPHS := {"P":["110","101","110","100","100"],"1":["010","110","010","010","111"],"2":["110","001","010","100","111"]}
var slot_index := 0
var label_text: String:
	get: return "P%d" % (slot_index + 1)
var identity_color: Color:
	get: return COLORS[clampi(slot_index, 0, 1)]

func set_slot(slot: int) -> void:
	slot_index = clampi(slot, 0, 1)
	queue_redraw()

func _draw() -> void:
	var points := PackedVector2Array()
	for step in 25:
		var angle := step * TAU / 24.0
		points.append(Vector2(cos(angle) * 15.0, sin(angle) * 3.0 + 1.0))
	draw_polyline(points, Color(identity_color, 0.8), 1.0)
	draw_rect(Rect2(-5,4,10,7), Color("#242434"))
	var glyphs: Array = [GLYPHS.P, GLYPHS["1" if slot_index == 0 else "2"]]
	for index in 2:
		for row in 5:
			for column in 3:
				if str(glyphs[index][row])[column] == "1":
					draw_rect(Rect2(-4 + index * 4 + column, 5 + row, 1, 1), identity_color)
