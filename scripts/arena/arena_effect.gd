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
	var remaining := 1.0 - float(age) / lifetime
	var ink := Color(tint, remaining * (0.5 if reduced_flash else 1.0))
	if kind in ["damage", "coin"] and font != null:
		draw_string(font, Vector2(-3, -2), text_value, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, ink)
	elif kind == "trail":
		draw_rect(Rect2(-2, -2, 4, 4), ink)
	else:
		for i in (3 if reduced_flash else 6):
			var heading := Vector2.from_angle(float(i) * TAU / 6.0)
			draw_rect(Rect2(heading * (2.0 + age * 0.6), Vector2(2, 2)), ink)
		if kind in ["slam", "special", "freeze"]:
			draw_arc(Vector2.ZERO, float(age) * 1.8, 0, TAU, 16, ink, 1.0)
