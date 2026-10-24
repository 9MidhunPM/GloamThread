class_name ArenaProjectile
extends CharacterBody2D
## Bounded, source-owned swept projectile. Art never owns hit detection.
var _world: Node
var _direction := Vector2.RIGHT
var _damage := 0.0
var _slot := -1
var _tags: Dictionary = {}
var _attack_id := 0
var _life := 120
var _pierce := 0
var _hits: Dictionary = {}
var _speed := 330.0
var _gravity := 0.0
var _hostile := false
var _color := Color.WHITE

func setup(world: Node, at: Vector2, direction: Vector2, damage: float, slot: int, tags: Dictionary) -> void:
	_world = world
	position = at
	_direction = Vector2.RIGHT if direction.is_zero_approx() else direction.normalized()
	_damage = maxf(0.0, damage)
	_slot = slot
	_tags = tags.duplicate(true)
	_attack_id = int(tags.get("attack_id", ArenaCombat.next_id()))
	_hostile = bool(tags.get("hostile", false))
	_speed = clampf(float(tags.get("speed", 180.0 if _hostile else 330.0)), 40.0, 650.0)
	_gravity = clampf(float(tags.get("gravity", 0.0)), 0.0, 1600.0)
	_pierce = clampi(int(tags.get("pierce", 0)), 0, 8)
	_life = clampi(int(tags.get("life", 120)), 1, 180)
	_color = Color("#ed765c") if _hostile else ArenaFighter.COLORS.get(str(tags.get("kit", "frost")), Color.WHITE)
	velocity = _direction * _speed

func _ready() -> void:
	add_to_group("arena_projectiles")
	collision_layer = 128
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CircleShape2D.new()
	shape.radius = 3.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	# Fail closed if a caller forgot its own pool cap.
	var count := 0
	for projectile: Node in get_tree().get_nodes_in_group("arena_projectiles"):
		if projectile.get("_world") == _world:
			count += 1
	if count > 128:
		queue_free()

func _physics_process(delta: float) -> void:
	if not ArenaCombat.playing(_world):
		return
	_life -= 1
	velocity.y += _gravity * delta
	var before := global_position
	var terrain := move_and_collide(velocity * delta)
	var after := global_position
	var candidates: Array[Dictionary] = []
	for target: Node in ArenaCombat.actors(_world, "fighters" if _hostile else "enemies"):
		if not is_instance_valid(target) or _hits.has(target.get_instance_id()):
			continue
		if bool(target.get("downed" if _hostile else "dead")):
			continue
		var box: Rect2 = target.call("get_hurt_rect")
		var entry := _entry_fraction(before, after, box.grow(3.0))
		if entry != INF:
			candidates.append({"target":target,"entry":entry})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.entry) < float(b.entry))
	for item in candidates:
		var target: Node = item.target
		_hits[target.get_instance_id()] = true
		if _hostile:
			target.call("take_damage", _damage, before, -1)
		else:
			target.call("take_damage", _damage, _slot, _attack_id, _tags)
		ArenaCombat.effect(_world, before.lerp(after, float(item.entry)), _color, "impact")
		if _pierce <= 0:
			queue_free()
			return
		_pierce -= 1
	if terrain != null or _life <= 0 or global_position.x < -48 or global_position.x > 688 or global_position.y < -96 or global_position.y > 400:
		queue_free()
	queue_redraw()

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

func _draw() -> void:
	var tail := -velocity.normalized() * 9.0
	draw_line(tail, Vector2.ZERO, Color(_color, 0.45), 4.0)
	draw_circle(Vector2.ZERO, 3.0, _color)
	draw_circle(Vector2(-1,-1), 1.0, Color.WHITE)
