class_name ArenaCombat
extends RefCounted
static var _serial := 0
const SOLID_MASK := 1
const TERRAIN_MASK := 1 | 256

static func next_id() -> int:
	_serial += 1
	return _serial

static func playing(world: Node) -> bool:
	return is_instance_valid(world) and str(world.get("phase")) == "combat"

static func moving(world: Node, slot: int) -> bool:
	return is_instance_valid(world) and (bool(world.call("movement_allowed", slot)) if world.has_method("movement_allowed") else playing(world))

static func bounds(world: Node) -> Rect2:
	return world.call("world_bounds") if is_instance_valid(world) and world.has_method("world_bounds") else Rect2(16, -64, 608, 464)

static func safe_position(world: Node, at: Vector2) -> Vector2:
	return world.call("safe_position", at) if is_instance_valid(world) and world.has_method("safe_position") else Vector2(clampf(at.x, 32, 608), 320)

static func actors(world: Node, field: String) -> Array:
	var value: Variant = world.get(field) if is_instance_valid(world) else null
	return value if value is Array else []

static func clear_line(actor: CollisionObject2D, from: Vector2, to: Vector2, mask: int = TERRAIN_MASK) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, mask, [actor.get_rid()])
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
