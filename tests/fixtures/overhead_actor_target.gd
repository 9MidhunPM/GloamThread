extends CharacterBody2D
## Motionless enemy-shaped fixture: real world hit queries, no enemy AI.
var dead := false
var hits: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("combat_enemies")
	collision_layer = 4
	collision_mask = 1

func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-6, -10), Vector2(12, 10))

func receive_hit(damage: int, slot: int, attack_id: int, stagger: int = 1, slow_ticks: int = 0) -> bool:
	hits.append({"damage": damage, "slot": slot, "attack_id": attack_id, "stagger": stagger, "slow": slow_ticks})
	return true
