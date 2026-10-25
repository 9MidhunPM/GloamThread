class_name ArenaLoot
extends Node2D
## A shared authored discovery. Session commits rewards, never a viewport.

var record: Dictionary
var world: Node
var collected: bool = false


func setup(data: Dictionary, session: Node) -> void:
	record = data
	world = session
	position = data.position
	z_index = 2


func get_hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-12, -22), Vector2(24, 22))


func take_damage(_amount: float, slot: int, _attack_id: int, _tags: Dictionary = {}) -> bool:
	return not collected and record.kind == "cache" and bool(world.call("collect_loot", str(record.id), slot))


func retire() -> void:
	collected = true
	hide()


func _draw() -> void:
	if record.get("kind") == "plant":
		draw_circle(Vector2(0, -10), 13, Color(0.42, 0.8, 0.58, 0.08))
		draw_line(Vector2(0, -1), Vector2(0, -18), Color("527e6b"), 2)
		draw_colored_polygon(PackedVector2Array([Vector2(0,-8),Vector2(-9,-15),Vector2(-11,-9),Vector2(-5,-5)]), Color("7ebd8d"))
		draw_colored_polygon(PackedVector2Array([Vector2(0,-13),Vector2(8,-20),Vector2(10,-13),Vector2(5,-9)]), Color("9bd297"))
		draw_circle(Vector2(0, -20), 3, Color("efe1ad"))
	else:
		draw_circle(Vector2(0, -10), 18, Color(0.95, 0.74, 0.32, 0.08))
		draw_style_box(_chest_box(), Rect2(-12, -18, 24, 17))
		draw_line(Vector2(-11, -12), Vector2(11, -12), Color("f0c478"), 2)
		draw_line(Vector2(-7, -17), Vector2(-7, -2), Color("bd915c"), 2)
		draw_line(Vector2(7, -17), Vector2(7, -2), Color("bd915c"), 2)
		draw_rect(Rect2(-2, -12, 5, 6), Color("f8df9c"))
		draw_rect(Rect2(0, -11, 1, 3), Color("5c4c3d"))


func _chest_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("684f42")
	box.border_color = Color("24363b")
	box.set_border_width_all(2)
	box.corner_radius_top_left = 3
	box.corner_radius_top_right = 3
	return box
