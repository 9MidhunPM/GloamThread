class_name SporeBolt
extends CharacterBody2D
## One bounded, terrain-colliding projectile. It never queries player targets.

const SPEED := 250.0
const LIFE_TICKS := 48

var source_slot: int = 0
var attack_id: int = 0
var direction: int = 1
var catalog: AssetCatalog
var _remaining: int = LIFE_TICKS


func _ready() -> void:
	add_to_group("combat_transients")
	collision_layer = 128
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 3.0
	collision.shape = shape
	add_child(collision)
	if catalog != null:
		var sprite := Sprite2D.new()
		sprite.texture = catalog.frame_texture("effect_spore_impact_v1")
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)


func _physics_process(delta: float) -> void:
	_remaining -= 1
	if _remaining <= 0:
		queue_free()
		return
	var before := global_position
	var collision := move_and_collide(Vector2(direction * SPEED * delta, 0.0))
	var rectangle := Rect2(Vector2(minf(before.x, global_position.x) - 4.0, global_position.y - 4.0), Vector2(absf(global_position.x - before.x) + 8.0, 8.0))
	for enemy in CombatQuery.enemies_in(self, rectangle):
		if bool(enemy.call("receive_hit", 1, source_slot, attack_id, 1, 90)):
			CombatQuery.effect(self, catalog, "effect_spore_impact_v1", global_position)
			queue_free()
			return
	if collision != null:
		CombatQuery.effect(self, catalog, "effect_spore_impact_v1", global_position)
		queue_free()
