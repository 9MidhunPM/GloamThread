class_name ArenaBackdrop
extends Node2D

var appearance: Dictionary = {}
var platforms: Array = []
var stage: int = 0
var clock: int = 0


func _physics_process(_delta: float) -> void:
	clock += 1
	if clock % 6 == 0:
		queue_redraw()


func _draw() -> void:
	var palette: Array = appearance.get("theme", {}).get("palette", ["#19273b", "#29474f", "#648376", "#e8bd72"])
	var accent := Color(str(palette[mini(2, palette.size() - 1)]))
	var back: Texture2D = appearance.get("background")
	if back != null:
		draw_texture_rect(back, Rect2(0, 0, 640, 360), false)
	else:
		draw_rect(Rect2(0, 0, 640, 360), Color("101a2b"))
	# Quiet edges frame the action even when a generated background is bright.
	draw_rect(Rect2(0, 0, 640, 45), Color(0.02, 0.03, 0.06, 0.28))
	var material: Texture2D = appearance.get("materials")
	_surface(Rect2(16, 320, 608, 40), material, accent)
	for platform: Array in platforms:
		_surface(Rect2(float(platform[0]), float(platform[1]), float(platform[2]), 8), material, accent)
	for edge: int in [16, 624]:
		draw_line(Vector2(edge, 90), Vector2(edge, 320), Color(accent, 0.45), 2)
		draw_circle(Vector2(edge, 308), 4, Color("ffd48c"))
	# Original hanging pennants communicate the current stage without obscuring actors.
	for i in 4:
		var x := 230.0 + i * 60
		draw_line(Vector2(x, 0), Vector2(x, 65), Color(accent, 0.3), 1)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 6, 44), Vector2(x + 6, 44), Vector2(x + 6, 65), Vector2(x, 61), Vector2(x - 6, 65)]), Color(accent, 0.75 if i <= stage else 0.15))


func _surface(rect: Rect2, texture: Texture2D, accent: Color) -> void:
	draw_rect(rect, Color("14222c"))
	if texture != null:
		for x in range(int(rect.position.x), int(rect.end.x), 16):
			for y in range(int(rect.position.y), int(rect.end.y), 16):
				var size := Vector2(minf(16, rect.end.x - x), minf(16, rect.end.y - y))
				draw_texture_rect_region(texture, Rect2(Vector2(x, y), size), Rect2(Vector2(0, (stage % 4) * 32), size), Color(0.65, 0.7, 0.75, 1))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), accent.lightened(0.25))
	draw_rect(Rect2(rect.position + Vector2(0, 2), Vector2(rect.size.x, 1)), Color("08131e"))
