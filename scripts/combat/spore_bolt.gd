class_name SporeBolt
extends CharacterBody2D
## Bounded ground-plane projectile: sweep enemies only up to terrain contact.

const SPEED := 250.0
const LIFE_TICKS := 48
const RADIUS := 3.0

var source_slot: int = 0
var attack_id: int = 0
var direction := Vector2.RIGHT
var catalog: AssetCatalog
var _remaining: int = LIFE_TICKS


func _ready() -> void:
	add_to_group("combat_transients")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 128
	collision_mask = 1
	direction = Vector2.RIGHT if direction.is_zero_approx() else direction.normalized()
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	collision.shape = shape
	add_child(collision)
	if catalog != null:
		var sprite := Sprite2D.new()
		sprite.texture = catalog.frame_texture("effect_spore_impact_v1")
		sprite.rotation = direction.angle()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)


func _physics_process(delta: float) -> void:
	_remaining -= 1
	var before := global_position
	var collision := move_and_collide(direction * SPEED * delta)
	var after := global_position
	var nearest: Node2D
	var nearest_fraction := INF
	for candidate: Node in get_tree().get_nodes_in_group("combat_enemies"):
		if not candidate is Node2D or candidate.get("dead") == true:
			continue
		var enemy := candidate as Node2D
		if enemy.get_world_2d() != get_world_2d():
			continue
		var box: Rect2 = enemy.call("hurt_rect")
		var fraction := _entry_fraction(before, after, box.grow(RADIUS))
		if fraction < nearest_fraction:
			nearest_fraction = fraction
			nearest = enemy
	if nearest != null:
		global_position = before.lerp(after, nearest_fraction)
		nearest.call("receive_hit", 1, source_slot, attack_id, 1, 90)
		_impact()
	elif collision != null:
		_impact()
	elif _remaining <= 0:
		queue_free()


## Slab intersection gives the earliest contact along either axis, independent
## of tree order. Expanded hurtboxes include the projectile's small footprint.
func _entry_fraction(from: Vector2, to: Vector2, box: Rect2) -> float:
	var travel := to - from
	var enter := 0.0
	var leave := 1.0
	for axis in 2:
		if is_zero_approx(travel[axis]):
			if from[axis] < box.position[axis] or from[axis] > box.end[axis]:
				return INF
			continue
		var first := (box.position[axis] - from[axis]) / travel[axis]
		var last := (box.end[axis] - from[axis]) / travel[axis]
		enter = maxf(enter, minf(first, last))
		leave = minf(leave, maxf(first, last))
		if enter > leave:
			return INF
	return enter


func _impact() -> void:
	CombatQuery.effect(self, catalog, "effect_spore_impact_v1", global_position, direction)
	queue_free()
