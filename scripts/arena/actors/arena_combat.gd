class_name ArenaCombat
extends RefCounted
static var _serial := 0

static func next_id() -> int:
	_serial += 1
	return _serial

static func playing(world: Node) -> bool:
	return is_instance_valid(world) and str(world.get("phase")) == "combat"

static func actors(world: Node, field: String) -> Array:
	var value: Variant = world.get(field) if is_instance_valid(world) else null
	return value if value is Array else []

static func clear_line(actor: CollisionObject2D, from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1, [actor.get_rid()])
	return actor.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

static func effect(world: Node, at: Vector2, color: Color, kind: String) -> void:
	if is_instance_valid(world) and world.has_method("effect"):
		world.call("effect", at, color, kind)

static func heal_source(world: Node, slot: int, amount: float) -> void:
	if amount <= 0.0:
		return
	for fighter: Node in actors(world, "fighters"):
		if is_instance_valid(fighter) and int(fighter.get("slot_index")) == slot and fighter.has_method("heal"):
			fighter.call("heal", amount)
			return
