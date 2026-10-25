class_name ArenaFighter
extends CharacterBody2D
## One owned-input fighter. RunSession owns wallets, shopping and team recovery.
const Action := CommandSnapshot.Action
const GRAVITY := 1600.0
const JUMP_SPEED := -400.0
const DODGE_TICKS := 10
const COLORS := {"ember": Color("#ef884a"), "frost": Color("#8bd5ed"), "storm": Color("#e8d76b"), "stone": Color("#c6a080"), "nature": Color("#91c978"), "shadow": Color("#c093e9")}
const BASIC_TICKS := {"ember": 18, "frost": 24, "storm": 12, "stone": 30, "nature": 24, "shadow": 16}
var slot_index := 0
var kit_id := "ember"
var health := 100.0
var max_health := 100.0
var downed := false
var special_ticks := 0
var facing := 1
var stats: Dictionary = {"damage":12.0,"attack_speed":1.0,"special_cooldown":360.0,"max_health":100.0,"move_speed":140.0,"crit":0.05,"dodge_cooldown":48.0,"lifesteal":0.0,"thorns":0.0,"projectile_count":1.0,"area":1.0,"burn":0.0,"freeze":0.0,"chain":0.0,"stagger":0.0,"regen":0.0,"pierce":0.0}
var immunity_ticks := 0
var dodge_ticks := 0
var dodge_cooldown := 0
var revive_progress_ticks := 0
var _world: Node
var _appearance: Dictionary
var _avatar: ArenaAvatar
var _owner_marker: ArenaOwnershipMarker
var _coyote := 0
var _jump_buffer := 0
var _hurt := 0
var _armour := 0
var _dodge_immunity := 0
var _attack := ""
var _attack_tick := 0
var _attack_total := 0
var _attack_emit := 0
var _attack_id := 0
var _attack_facing := 1
var _attack_tags: Dictionary = {}
var _drop_body: PhysicsBody2D
var _drop_ticks := 0
var _rng := RandomNumberGenerator.new()

func setup(slot: int, family: String, world: Node, appearance: Dictionary) -> void:
	slot_index = slot
	kit_id = family if COLORS.has(family) else "ember"
	_world = world
	_appearance = appearance
	_rng.randomize()
	if is_node_ready():
		_avatar.setup(appearance)
		_owner_marker.set_slot(slot_index)

func _ready() -> void:
	# Fighters stay readable when nonblocking enemy bodies overlap them.
	z_index = 10
	collision_layer = 2
	collision_mask = ArenaCombat.TERRAIN_MASK
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 38)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -19)
	add_child(collision)
	_owner_marker = ArenaOwnershipMarker.new()
	_owner_marker.name = "OwnershipMarker"
	_owner_marker.set_slot(slot_index)
	add_child(_owner_marker)
	_avatar = ArenaAvatar.new()
	add_child(_avatar)
	_avatar.setup(_appearance)

func apply_stats(next: Dictionary, heal_delta: float = 0.0) -> void:
	for key: String in stats:
		if next.has(key) and (next[key] is int or next[key] is float) and is_finite(float(next[key])):
			stats[key] = float(next[key])
	max_health = maxf(1.0, float(stats.max_health))
	health = clampf(health + maxf(0.0, heal_delta), 0.0, max_health)

func heal(amount: float) -> void:
	if not downed and amount > 0.0:
		health = minf(max_health, health + amount)

func get_hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-9, -38), Vector2(18, 38))

func _physics_process(delta: float) -> void:
	if not ArenaCombat.moving(_world, slot_index):
		return
	_tick_clocks()
	if downed:
		velocity = Vector2(0, minf(velocity.y + GRAVITY * delta, 500))
		move_and_slide()
		_avatar.play("downed")
		_avatar.tick()
		return
	if ArenaCombat.playing(_world):
		heal((float(stats.regen) + (1.0 if kit_id == "nature" else 0.0)) * delta)
	var input := InputRouter.snapshot(slot_index)
	var grounded := is_on_floor() and velocity.y >= 0.0
	_coyote = 6 if grounded else maxi(0, _coyote - 1)
	if input.just_pressed(Action.JUMP):
		if grounded and input.is_held(Action.DOWN) and _drop_through():
			grounded = false
		else:
			_jump_buffer = 6
	if _hurt == 0 and dodge_ticks == 0:
		if _attack.is_empty() and absf(input.move_x) > 0.01:
			facing = -1 if input.move_x < 0 else 1
		if input.just_pressed(Action.DASH) and dodge_cooldown == 0:
			_attack = ""
			dodge_ticks = DODGE_TICKS
			_dodge_immunity = 8
			dodge_cooldown = maxi(12, int(stats.dodge_cooldown))
			_avatar.play("dash", true)
			ArenaCombat.effect(_world, global_position, COLORS[kit_id], "dodge")
		elif _attack.is_empty():
			if input.just_pressed(Action.SPECIAL) and special_ticks == 0 and ArenaCombat.playing(_world):
				_start_attack(true)
			elif input.is_held(Action.ATTACK):
				_start_attack(false)
	_avatar.flip_h = facing < 0
	if dodge_ticks > 0:
		velocity = Vector2(facing * 360.0, 0)
		move_and_slide()
		dodge_ticks -= 1
		if dodge_ticks == 0:
			velocity = Vector2.ZERO
		_avatar.tick()
		return
	if _hurt == 0:
		velocity.x = move_toward(velocity.x, input.move_x * float(stats.move_speed) * (0.55 if not _attack.is_empty() else 1.0), 1200.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, 500.0)
	if _jump_buffer > 0 and _coyote > 0 and _hurt == 0:
		velocity.y = JUMP_SPEED
		_jump_buffer = 0
		_coyote = 0
	if not input.is_held(Action.JUMP) and velocity.y < -180.0:
		velocity.y = -180.0
	move_and_slide()
	if global_position.y > ArenaCombat.bounds(_world).end.y + 64:
		global_position = ArenaCombat.safe_position(_world, global_position)
		velocity = Vector2.ZERO
	if is_on_floor() and _jump_buffer > 0 and _hurt == 0:
		velocity.y = JUMP_SPEED
		_jump_buffer = 0
	_jump_buffer = maxi(0, _jump_buffer - 1)
	_tick_attack()
	_avatar.flip_h = facing < 0
	if _hurt > 0:
		_avatar.play("hurt")
	elif not _attack.is_empty():
		_avatar.play("special" if _attack == "special" else "slash")
	elif not is_on_floor():
		_avatar.play("rise" if velocity.y < 0 else "fall")
	else:
		_avatar.play("run" if absf(velocity.x) > 5 else "idle")
	_avatar.tick()

func _tick_clocks() -> void:
	immunity_ticks = maxi(0, immunity_ticks - 1)
	special_ticks = maxi(0, special_ticks - 1)
	dodge_cooldown = maxi(0, dodge_cooldown - 1)
	_dodge_immunity = maxi(0, _dodge_immunity - 1)
	_hurt = maxi(0, _hurt - 1)
	_armour = maxi(0, _armour - 1)
	if _drop_ticks > 0:
		_drop_ticks -= 1
		if _drop_ticks == 0:
			_end_drop()
	_avatar.modulate.a = 0.65 if immunity_ticks > 0 or _dodge_immunity > 0 else 1.0

func _start_attack(special: bool) -> void:
	_attack = "special" if special else "basic"
	_attack_tick = 0
	_attack_total = 26 if special else maxi(7, int(round(float(BASIC_TICKS[kit_id]) / maxf(0.25, float(stats.attack_speed)))))
	_attack_emit = 9 if special else maxi(2, int(_attack_total * 0.3))
	_attack_id = ArenaCombat.next_id()
	_attack_facing = facing
	_attack_tags = _tags()
	if _rng.randf() < clampf(float(stats.crit), 0.0, 1.0):
		_attack_tags["critical"] = true
	if special:
		special_ticks = maxi(30, int(stats.special_cooldown))
	_avatar.play("special" if special else "slash", true)

func _tags() -> Dictionary:
	return {"kit":kit_id,"burn":int(stats.burn),"freeze":int(stats.freeze),"chain":int(stats.chain),"stagger":int(stats.stagger),"pierce":int(stats.pierce),"lifesteal":float(stats.lifesteal)}

func _tick_attack() -> void:
	if _attack.is_empty():
		return
	_attack_tick += 1
	if _attack_tick == _attack_emit:
		_emit_attack(_attack == "special")
	if _attack_tick >= _attack_total:
		_attack = ""

func _emit_attack(special: bool) -> void:
	var damage := float(stats.damage) * (1.75 if bool(_attack_tags.get("critical", false)) else 1.0)
	var area := maxf(0.5, float(stats.area))
	var tags := _attack_tags.duplicate(true)
	var centre := get_hurt_rect().get_center()
	tags["hit_from"] = centre
	if not special:
		match kit_id:
			"frost", "nature":
				tags["freeze" if kit_id == "frost" else "pierce"] += 1
				_shoot(centre, damage * 0.85, tags, maxi(1, int(stats.projectile_count)))
				return
			"ember": tags.burn += 1
			"stone":
				damage *= 1.65
				tags.stagger += 2
			"storm": damage *= 0.8
			"shadow": tags["mark"] = 1
		_melee(52.0 * area, 44.0 * area, damage, tags)
	else:
		match kit_id:
			"ember":
				tags.burn += 3
				_melee(118.0 * area, 60.0 * area, damage * 2.3, tags)
			"frost":
				tags.freeze += 3
				tags["shatter"] = true
				_shoot(centre, damage * 1.5, tags, maxi(3, int(stats.projectile_count) + 2))
			"storm":
				tags.chain += 3
				_melee(90.0 * area, 60.0 * area, damage * 1.8, tags)
			"stone":
				_armour = 120
				tags.stagger += 4
				_world.call("hit_enemies", Rect2(global_position + Vector2(-95, -60) * area, Vector2(190, 66) * area), damage * 2.4, slot_index, _attack_id, tags)
			"nature":
				tags.freeze += 2
				tags["root"] = true
				_world.call("hit_enemies", Rect2(global_position + Vector2(-85, -48) * area, Vector2(170, 56) * area), damage * 1.6, slot_index, _attack_id, tags)
				heal(max_health * 0.12)
			"shadow":
				tags.pierce += 3
				tags["consume_marks"] = true
				_shoot(centre, damage * 1.8, tags, maxi(1, int(stats.projectile_count)))
	ArenaCombat.effect(_world, centre + Vector2(_attack_facing * 28, 0), COLORS[kit_id], kit_id + ("_special" if special else "_strike"))

func _melee(reach: float, height: float, damage: float, tags: Dictionary) -> void:
	var centre := get_hurt_rect().get_center()
	var rect := Rect2(centre + Vector2(0 if _attack_facing > 0 else -reach, -height * 0.5), Vector2(reach, height))
	_world.call("hit_enemies", rect, damage, slot_index, _attack_id, tags)

func _shoot(origin: Vector2, damage: float, tags: Dictionary, count: int) -> void:
	count = clampi(count, 1, 7)
	for index in count:
		var angle := (float(index) - (count - 1) * 0.5) * 0.12
		var direction := Vector2(_attack_facing, 0).rotated(angle)
		var packet := tags.duplicate(true)
		packet["attack_id"] = ArenaCombat.next_id()
		_world.call("spawn_projectile", origin, direction, damage, slot_index, packet)

func take_damage(amount: float, from: Vector2, owner_slot: int = -1) -> void:
	if not ArenaCombat.playing(_world) or downed or amount <= 0.0 or immunity_ticks > 0 or _dodge_immunity > 0 or owner_slot >= 0:
		return
	var reduction := 0.8 if kit_id == "stone" else 1.0
	if _armour > 0:
		reduction *= 0.5
	var actual := minf(health, amount * reduction)
	health = maxf(0.0, health - actual)
	immunity_ticks = 36
	_hurt = 12
	_attack = ""
	dodge_ticks = 0
	velocity = Vector2(150 if global_position.x >= from.x else -150, -90)
	_world.call("on_fighter_hit", slot_index)
	ArenaCombat.effect(_world, get_hurt_rect().get_center(), Color.WHITE, "hurt")
	if float(stats.thorns) > 0.0:
		_world.call("hit_enemies", get_hurt_rect().grow(28), actual * float(stats.thorns), slot_index, ArenaCombat.next_id(), {"reflected":true,"hit_from":get_hurt_rect().get_center()})
	if health <= 0.0:
		downed = true
		revive_progress_ticks = 0
		_avatar.play("downed", true)

func revive() -> void:
	if not downed:
		return
	downed = false
	health = maxf(1.0, max_health * 0.35)
	immunity_ticks = 90
	revive_progress_ticks = 0
	velocity = Vector2.ZERO
	_attack = ""
	_avatar.play("revive", true)

## Call before the session removes old terrain. Health and bought stats stay
## owned by the run; only temporary action state and per-wave charges reset.
func reset_for_wave(at: Vector2) -> void:
	_end_drop()
	global_position = at
	velocity = Vector2.ZERO
	_coyote = 0
	_jump_buffer = 0
	_hurt = 0
	_armour = 0
	_dodge_immunity = 0
	dodge_ticks = 0
	dodge_cooldown = 0
	special_ticks = 0
	_attack = ""
	_attack_tick = 0
	_attack_tags.clear()
	revive_progress_ticks = 0
	immunity_ticks = 45
	if is_node_ready():
		_avatar.play("downed" if downed else "idle", true)
		reset_physics_interpolation()


func _drop_through() -> bool:
	for index in get_slide_collision_count():
		var contact := get_slide_collision(index)
		var body := contact.get_collider() as PhysicsBody2D
		if body != null and contact.get_normal().y < -0.5 and (body.is_in_group("arena_one_way") or bool(body.get_meta("arena_one_way", false))):
			_drop_body = body
			_drop_ticks = 12
			add_collision_exception_with(body)
			global_position.y += 3.0
			velocity.y = 60.0
			_coyote = 0
			_jump_buffer = 0
			return true
	return false

func _end_drop() -> void:
	if is_instance_valid(_drop_body):
		remove_collision_exception_with(_drop_body)
	_drop_body = null
	_drop_ticks = 0

func _exit_tree() -> void:
	_end_drop()
