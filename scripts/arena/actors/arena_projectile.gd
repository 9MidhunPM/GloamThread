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
var _candidates: Array[Node2D] = []
var _entries: Array[float] = []

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
	z_index = 12
	add_to_group("arena_projectiles")
	collision_layer = 128
	collision_mask = ArenaCombat.TERRAIN_MASK
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
	if not ArenaCombat.playing(_world) and (_hostile or not str(_world.get("phase")) in ["shop", "countdown", "clear"]):
		return
	_life -= 1
	velocity.y += _gravity * delta
	var before := global_position
	var terrain := move_and_collide(velocity * delta)
	var after := global_position
	_candidates.clear()
	_entries.clear()
	# Read the current roster and current hurtboxes after terrain clamps travel.
	# Most sweeps miss: avoid allocating a Dictionary/comparator for each hit.
	if _hostile:
		for target: ArenaFighter in ArenaCombat.actors(_world, "fighters"):
			if is_instance_valid(target) and not target.downed and not _hits.has(target.get_instance_id()):
				_insert_hit(target, _entry_fraction(before, after, target.get_hurt_rect().grow(3.0)))
	else:
		for target: ArenaEnemy in ArenaCombat.actors(_world, "enemies"):
			if is_instance_valid(target) and not target.dead and not _hits.has(target.get_instance_id()):
				_insert_hit(target, _entry_fraction(before, after, target.get_hurt_rect().grow(3.0)))
		for target: Node2D in ArenaCombat.actors(_world, "loot_nodes"):
			if is_instance_valid(target) and not target.collected and target.record.kind == "cache" and not _hits.has(target.get_instance_id()):
				_insert_hit(target, _entry_fraction(before, after, target.get_hurt_rect().grow(3.0)))
	for index in _candidates.size():
		var target: Node2D = _candidates[index]
		_hits[target.get_instance_id()] = true
		if _hostile:
			(target as ArenaFighter).take_damage(_damage, before, -1)
		else:
			target.take_damage(_damage, _slot, _attack_id, _tags)
		ArenaCombat.effect(_world, before.lerp(after, _entries[index]), _color, "impact")
		if _pierce <= 0:
			queue_free()
			return
		_pierce -= 1
	if terrain != null or _life <= 0 or not ArenaCombat.bounds(_world).grow(80).has_point(global_position):
		queue_free()
	# Node2D transforms move retained draw commands. Only gravity changes the
	# tail's local direction; straight shots keep exactly the same drawing.
	if _gravity != 0.0:
		queue_redraw()

func _insert_hit(target: Node2D, entry: float) -> void:
	if entry == INF:
		return
	var index := 0
	while index < _entries.size() and _entries[index] <= entry:
		index += 1
	_candidates.insert(index, target)
	_entries.insert(index, entry)

func _entry_fraction(from: Vector2, to: Vector2, box: Rect2) -> float:
	var travel := to - from
	var end := box.end
	# Cheap rejection covers the usual distant/other-platform target before
	# either division, including zero-length and edge-touching sweeps.
	if (from.y < box.position.y and to.y < box.position.y) or (from.y > end.y and to.y > end.y) or (from.x < box.position.x and to.x < box.position.x) or (from.x > end.x and to.x > end.x):
		return INF
	var enter := 0.0
	var leave := 1.0
	if is_zero_approx(travel.x):
		if from.x < box.position.x or from.x > end.x: return INF
	else:
		var first := (box.position.x - from.x) / travel.x
		var last := (end.x - from.x) / travel.x
		enter = maxf(enter, minf(first, last))
		leave = minf(leave, maxf(first, last))
		if enter > leave:
			return INF
	if is_zero_approx(travel.y):
		if from.y < box.position.y or from.y > end.y: return INF
	else:
		var first := (box.position.y - from.y) / travel.y
		var last := (end.y - from.y) / travel.y
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
