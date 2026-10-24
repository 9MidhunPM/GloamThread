class_name ArenaEffect
extends Node2D
## Small bounded pixel effects; gameplay never depends on these nodes.

var tint: Color = Color("ffc97a")
var kind: String = "burst"
var text_value: String = ""
var lifetime: int = 24
var age: int = 0
var target: Vector2 = Vector2.ZERO
var font: Font
var reduced_flash: bool = false
var direction: float = 1.0


func _physics_process(_delta: float) -> void:
	age += 1
	if kind in ["damage", "coin"]:
		position.y -= 0.45
	if kind == "trail":
		position = position.lerp(target, 0.13)
	if age >= lifetime:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var remaining := clampf(1.0 - float(age) / maxf(1.0, lifetime), 0.0, 1.0)
	var ink := Color(tint, remaining * (0.5 if reduced_flash else 1.0))
	if kind in ["damage", "coin"] and font != null:
		draw_string(font, Vector2(-3, -2), text_value, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, ink)
		return
	elif kind == "trail":
		draw_rect(Rect2(-2, -2, 4, 4), ink)
		return
	var phase := clampf(float(age) / maxf(1.0, lifetime - 1), 0.0, 1.0)
	var core := Color(tint.lightened(0.35), ink.a)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1 if direction < 0 else 1, 1))
	match kind:
		"ember_special": _flame_fan(phase, ink, core)
		"frost_special": _ice_fan(phase, ink, core)
		"storm_special": _lightning(phase, ink, core, true)
		"stone_special", "slam": _ground_slam(phase, ink, core)
		"nature_special", "root": _vines(phase, ink, core)
		"shadow_special": _shadow_lance(phase, ink, core)
		"chain": _lightning(phase, ink, core, false)
		"shatter", "freeze": _shatter(phase, ink, core)
		"dodge": _dodge(phase, ink)
		"enemy_warning":
			_pixel_line([Vector2(-6, -8), Vector2(0, -13 - phase * 4), Vector2(6, -8)], ink, 2)
			draw_rect(Rect2(-1, -5, 2, 5), ink)
			draw_rect(Rect2(-1, 3, 2, 2), ink)
		_:
			for i in (3 if reduced_flash else 6):
				var heading := Vector2.from_angle(float(i) * TAU / 6.0)
				draw_rect(Rect2((heading * (2.0 + age * 0.6)).round(), Vector2(2, 2)), ink)
			if kind == "special":
				draw_arc(Vector2.ZERO, float(age) * 1.8, 0, TAU, 16, ink, 1.0)


func _flame_fan(phase: float, ink: Color, core: Color) -> void:
	# Three tongues open from one narrow throat, then lift and taper together.
	var reach := 24.0 + 34.0 * phase
	var spread := 9.0 + 14.0 * phase
	_pixel_polygon([Vector2(-22, 0), Vector2(6, -8), Vector2(reach - 9, -spread), Vector2(reach - 14, -4), Vector2(reach + 8, -5), Vector2(reach - 2, 5), Vector2(reach - 8, spread), Vector2(4, 8)], ink)
	_pixel_polygon([Vector2(-18, 0), Vector2(16, -4), Vector2(reach - 1, -9), Vector2(reach - 10, 0), Vector2(reach - 3, 8), Vector2(12, 4)], core)
	if not reduced_flash:
		for side in [-1, 1]:
			var at := Vector2(reach + 12, side * (spread + 3) - phase * 7).round()
			draw_rect(Rect2(at, Vector2(3, 3)), ink)


func _ice_fan(phase: float, ink: Color, core: Color) -> void:
	var count := 3 if reduced_flash else 5
	for index in count:
		var lane := float(index) - float(count - 1) * 0.5
		var at := Vector2(4 + phase * 34 - absf(lane) * 4, lane * (8 + phase * 8))
		var length := 13.0 - phase * 4
		_pixel_polygon([at + Vector2(-length, 0), at + Vector2(-2, -4), at + Vector2(length, 0), at + Vector2(-2, 4)], ink)
		_pixel_line([at + Vector2(-length + 3, 0), at + Vector2(length - 3, 0)], core, 1)


func _lightning(phase: float, ink: Color, core: Color, branching: bool) -> void:
	var reach := (46.0 if branching else 25.0) + phase * 10
	var bend := 6.0 + phase * 4
	var points: Array[Vector2] = [Vector2(-reach, 0), Vector2(-reach * 0.45, -bend), Vector2(-8, 4), Vector2(3, -7), Vector2(18, 5), Vector2(reach, -2)]
	_pixel_line(points, ink, 3 if branching else 2)
	_pixel_line(points, core, 1)
	if branching and not reduced_flash:
		_pixel_line([Vector2(-8, 4), Vector2(-1, 15), Vector2(17, 22)], ink, 2)
		_pixel_line([Vector2(18, 5), Vector2(28, -12), Vector2(44, -18)], ink, 2)


func _ground_slam(phase: float, ink: Color, core: Color) -> void:
	var spread := 12.0 + phase * 52
	# Feet are 19px below the emitted fighter-centre cue. Broken ground lines
	# stay local; this effect does not imply an additional collision surface.
	_pixel_line([Vector2(-28 - spread, 18), Vector2(-28 - spread * 0.6, 14), Vector2(-28, 18), Vector2(-28 + spread * 0.6, 14), Vector2(-28 + spread, 18)], ink, 3)
	for side in [-1, 1]:
		var at := Vector2(-28 + side * spread * 0.65, 16)
		var height := 5.0 + sin(phase * PI) * 20
		_pixel_polygon([at + Vector2(-7, 0), at + Vector2(-4, -height), at + Vector2(3, -height - 3), at + Vector2(8, 0)], ink)
		_pixel_line([at + Vector2(-3, -height + 2), at + Vector2(2, -height + 1)], core, 2)
	if not reduced_flash:
		draw_rect(Rect2(Vector2(-31, -4 - phase * 9).round(), Vector2(6, 4)), core)


func _vines(phase: float, ink: Color, core: Color) -> void:
	var count := 2 if reduced_flash else 3
	var growth := minf(1.0, phase * 4 + 0.25)
	for index in count:
		var x := -28.0 + (float(index) - float(count - 1) * 0.5) * 29
		var height := (25.0 if index % 2 == 0 else 36.0) * growth
		var bend := 5.0 + phase * 3
		_pixel_line([Vector2(x - 9, 18), Vector2(x, 13), Vector2(x + bend, 2), Vector2(x - 3, 18 - height)], ink, 3)
		_pixel_polygon([Vector2(x + bend, 5), Vector2(x + 17, 1), Vector2(x + 13, 11), Vector2(x + bend, 10)], core)
		_pixel_polygon([Vector2(x + 1, 12 - height * 0.5), Vector2(x - 12, 4 - height * 0.5), Vector2(x - 10, 15 - height * 0.5)], ink)
	_pixel_line([Vector2(-62, 19), Vector2(-28, 16), Vector2(7, 19)], ink, 2)


func _shadow_lance(phase: float, ink: Color, core: Color) -> void:
	var tip := 16.0 + phase * 54
	var width := 6.0 * (1.0 - phase * 0.6)
	_pixel_polygon([Vector2(-28, 0), Vector2(-8, -width), Vector2(tip - 12, -3), Vector2(tip, 0), Vector2(tip - 12, 3), Vector2(-8, width)], ink)
	_pixel_line([Vector2(-16, 0), Vector2(tip - 7, 0)], core, 1)
	if not reduced_flash:
		for side in [-1, 1]:
			_pixel_line([Vector2(-22 + phase * 20, side * 9), Vector2(-4 + phase * 20, side * 7)], ink, 1)


func _shatter(phase: float, ink: Color, core: Color) -> void:
	for index in (3 if reduced_flash else 6):
		var heading := Vector2.from_angle(float(index) * TAU / (3 if reduced_flash else 6) - PI * 0.5)
		var at := heading * (5 + phase * 23)
		var side := heading.orthogonal() * 3
		_pixel_polygon([at - heading * 6, at + side, at + heading * 7, at - side], ink)
		_pixel_line([at - heading * 2, at + heading * 4], core, 1)


func _dodge(phase: float, ink: Color) -> void:
	# A grounded slipstream, kept below the body so it cannot obscure an attack.
	var spread := 7.0 + phase * 16
	for side in [-1, 1]:
		_pixel_line([Vector2(side * spread, -5), Vector2(side * (spread + 9), -2), Vector2(side * (spread + 13), 1)], ink, 2)
	if not reduced_flash:
		_pixel_line([Vector2(-9, 3), Vector2(0, 5), Vector2(9, 3)], ink, 1)


func _pixel_line(points: Array[Vector2], color: Color, width: float) -> void:
	var pixels := PackedVector2Array()
	for point: Vector2 in points: pixels.append(point.round())
	draw_polyline(pixels, color, width, false)


func _pixel_polygon(points: Array[Vector2], color: Color) -> void:
	var pixels := PackedVector2Array()
	for point: Vector2 in points: pixels.append(point.round())
	draw_colored_polygon(pixels, color)
