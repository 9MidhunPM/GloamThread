class_name CombatQuery
extends RefCounted
## Small shared hit-query helpers. Art and camera count never alter hurtboxes.

static var _next_attack_id: int = 0


static func next_attack_id() -> int:
	_next_attack_id += 1
	return _next_attack_id


static func clear_line(actor: Node2D, from: Vector2, to: Vector2) -> bool:
	if from.distance_squared_to(to) < 1.0:
		return true
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	if actor is CollisionObject2D:
		query.exclude = [(actor as CollisionObject2D).get_rid()]
	return actor.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


static func enemies_in(actor: Node2D, rectangle: Rect2) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var origin := actor.global_position
	if actor.has_method("hurt_rect"):
		var actor_box: Rect2 = actor.call("hurt_rect")
		origin = actor_box.get_center()
	for candidate: Node in actor.get_tree().get_nodes_in_group("combat_enemies"):
		if not candidate is Node2D or candidate.get("dead") == true:
			continue
		var enemy := candidate as Node2D
		if enemy.get_world_2d() != actor.get_world_2d():
			continue
		var hurtbox: Rect2 = enemy.call("hurt_rect")
		if rectangle.intersects(hurtbox) and clear_line(actor, origin, hurtbox.get_center()):
			targets.append(enemy)
	return targets


## Cardinal attack footprint around the actor's ground-plane centre.
static func directional_rect(origin: Vector2, direction: Vector2, reach: float, width: float) -> Rect2:
	if absf(direction.x) > absf(direction.y):
		return Rect2(origin + Vector2(0.0 if direction.x > 0.0 else -reach, -width * 0.5), Vector2(reach, width))
	return Rect2(origin + Vector2(-width * 0.5, 0.0 if direction.y > 0.0 else -reach), Vector2(width, reach))


static func effect(actor: Node2D, catalog: AssetCatalog, asset_id: String, at: Vector2, direction: Vector2 = Vector2.RIGHT) -> void:
	if catalog == null or not catalog.entries.has(asset_id):
		return
	var effect_node := Node2D.new()
	effect_node.name = "CombatEffect"
	effect_node.add_to_group("combat_transients")
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect_node.add_child(sprite)
	var animator_script: Script = load("res://scripts/presentation/sprite_animator.gd")
	var animator: Node = animator_script.new()
	effect_node.add_child(animator)
	actor.get_parent().add_child(effect_node)
	effect_node.global_position = at
	effect_node.rotation = direction.angle()
	animator.call("configure", sprite, catalog, asset_id)
	var clips: Dictionary = catalog.entries[asset_id].get("animations", {})
	if not clips.is_empty():
		animator.call("play", str(clips.keys()[0]))
	# This timer uses the scene's physics clock and pauses with gameplay.
	var timer := Timer.new()
	timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	timer.one_shot = true
	timer.wait_time = 0.8
	effect_node.add_child(timer)
	timer.timeout.connect(effect_node.queue_free)
	timer.start()
