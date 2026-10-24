class_name PlayerController
extends CharacterBody2D
## Owned-input courier motor and attacks. Team down/revive timing and room
## transactions remain with GameSession; all timers here use physics ticks.

signal damage_received(player: PlayerController)
signal downed_started(player: PlayerController)

const GRAVITY := 1400.0
const JUMP_SPEED := -330.0
const MAX_SPEED := 110.0
const GROUND_ACCEL := 900.0
const AIR_ACCEL := 600.0
const MAX_FALL := 400.0
const JUMP_RELEASE_SPEED := -140.0
const COYOTE_TICKS := 6
const JUMP_BUFFER_TICKS := 6
const DASH_SPEED := 360.0
const DASH_TICKS := 12
const DASH_COOLDOWN_TICKS := 30
const DAMAGE_IMMUNITY_TICKS := 45
const REVIVE_IMMUNITY_TICKS := 90
const Action := CommandSnapshot.Action

var slot_index: int = 0
var profile_id: String = ""
var max_hearts: int = 5
var hearts: int = 5
var downed: bool = false
var downed_ticks: int = 0
var revive_progress_ticks: int = 0
var room_bounds: Rect2 = Rect2()
var animation_state: String = "idle"
var facing: int = 1
var immunity_ticks: int = 0
var special_cooldown_ticks: int = 0
var dash_cooldown_ticks: int = 0
var dash_ticks: int = 0
var special_id: String = "ember_arc"
var reduced_flash: bool = false
var sprite_texture: Texture2D:
	set(value):
		sprite_texture = value
		if is_node_ready():
			_sprite.texture = value

var _coyote_ticks: int = 0
var _jump_buffer_ticks: int = 0
var _hurt_ticks: int = 0
var _revive_animation_ticks: int = 0
var _land_ticks: int = 0
var _air_dash_available: bool = true
var _attack_kind: String = ""
var _attack_tick: int = 0
var _attack_id: int = 0
var _attack_facing: int = 1
var _hit_targets: Dictionary = {}
var _catalog: AssetCatalog
var _progress: TeamProgress
var _visual_id: String = ""
var _animator: Node
var _drop_body: PhysicsBody2D
var _drop_ticks: int = 0
var _last_safe_feet := Vector2.ZERO

@onready var _visual: Node2D = $Visual
@onready var _sprite: Sprite2D = $Visual/Sprite2D


func _ready() -> void:
	add_to_group("couriers")
	_sprite.texture = sprite_texture
	_last_safe_feet = global_position
	_setup_animator()


func configure(profile: Dictionary, catalog: AssetCatalog, progress: TeamProgress) -> void:
	profile_id = str(profile.get("id", profile_id))
	max_hearts = clampi(int(profile.get("max_hearts", 5)), 3, 6)
	hearts = max_hearts
	special_id = str(profile.get("special_id", "ember_arc"))
	_visual_id = str(profile.get("visual_bundle_id", ""))
	_catalog = catalog
	_progress = progress
	if is_node_ready():
		_setup_animator()


func _setup_animator() -> void:
	if _catalog == null or _visual_id.is_empty() or _animator != null:
		return
	var animator_script: Script = load("res://scripts/presentation/sprite_animator.gd")
	_animator = animator_script.new()
	_visual.add_child(_animator)
	_animator.call("configure", _sprite, _catalog, _visual_id)
	_animator.call("play", animation_state)


func _physics_process(delta: float) -> void:
	_tick_cooldowns()
	if downed:
		velocity.x = 0.0
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		move_and_slide()
		_keep_in_room()
		_set_animation("downed")
		return
	var commands: CommandSnapshot = InputRouter.snapshot(slot_index)
	# A buffered landing can already have queued upward velocity for this tick.
	var grounded := is_on_floor() and velocity.y >= 0.0
	if grounded:
		_coyote_ticks = COYOTE_TICKS
		_last_safe_feet = global_position
		if dash_ticks == 0:
			_air_dash_available = true
	if commands.just_pressed(Action.JUMP):
		if commands.is_held(Action.DOWN) and grounded and _start_drop_through():
			grounded = false
		else:
			_jump_buffer_ticks = JUMP_BUFFER_TICKS
	if _attack_kind.is_empty() and _hurt_ticks == 0 and dash_ticks == 0:
		if commands.just_pressed(Action.DASH) and _can_dash():
			_start_dash(commands.move_x)
		elif commands.just_pressed(Action.SPECIAL) and special_cooldown_ticks == 0:
			_start_attack(special_id)
		elif commands.just_pressed(Action.ATTACK):
			_start_attack("slash")
	if dash_ticks > 0:
		velocity = Vector2(facing * DASH_SPEED, 0.0)
		move_and_slide()
		_keep_in_room()
		dash_ticks -= 1
		_set_animation("dash")
		return

	var acceleration := GROUND_ACCEL if grounded else AIR_ACCEL
	if _hurt_ticks == 0:
		var move_scale := 1.0 if _attack_kind.is_empty() else 0.4
		velocity.x = move_toward(velocity.x, commands.move_x * MAX_SPEED * move_scale, acceleration * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	if not is_zero_approx(commands.move_x) and _attack_kind.is_empty() and _hurt_ticks == 0:
		facing = -1 if commands.move_x < 0.0 else 1
	_visual.scale.x = facing

	if _jump_buffer_ticks > 0 and _coyote_ticks > 0 and _hurt_ticks == 0:
		_start_jump()
	_cut_released_jump(commands)
	move_and_slide()
	_keep_in_room()

	# Consume a buffered press on the landing tick, before its grace expires.
	# Motion starts next tick; never run a second physics move in this frame.
	if not grounded and is_on_floor():
		AudioDirector.play_cue(&"land")
		_land_ticks = 10
		if _jump_buffer_ticks > 0 and _hurt_ticks == 0:
			_start_jump()
			_cut_released_jump(commands)
	_coyote_ticks = maxi(0, _coyote_ticks - 1)
	_jump_buffer_ticks = maxi(0, _jump_buffer_ticks - 1)
	_update_attack()
	_update_animation()


func _start_jump() -> void:
	velocity.y = JUMP_SPEED
	_coyote_ticks = 0
	_jump_buffer_ticks = 0
	AudioDirector.play_cue(&"jump")


func _cut_released_jump(commands: CommandSnapshot) -> void:
	if not commands.is_held(Action.JUMP) and velocity.y < JUMP_RELEASE_SPEED:
		velocity.y = JUMP_RELEASE_SPEED


func reset_at(feet_position: Vector2) -> void:
	_end_drop_through()
	global_position = feet_position
	velocity = Vector2.ZERO
	_coyote_ticks = 0
	_jump_buffer_ticks = 0
	_attack_kind = ""
	_hit_targets.clear()
	dash_ticks = 0
	_air_dash_available = true
	_hurt_ticks = 0
	_land_ticks = 0
	_last_safe_feet = feet_position
	if is_inside_tree():
		reset_physics_interpolation()


func restore(feet_position: Vector2) -> void:
	reset_at(feet_position)
	hearts = max_hearts
	downed = false
	downed_ticks = 0
	revive_progress_ticks = 0
	immunity_ticks = REVIVE_IMMUNITY_TICKS
	special_cooldown_ticks = 0
	dash_cooldown_ticks = 0
	_revive_animation_ticks = 0
	_set_animation("idle")


func revive() -> void:
	if not downed:
		return
	downed = false
	hearts = mini(2, max_hearts)
	downed_ticks = 0
	revive_progress_ticks = 0
	immunity_ticks = REVIVE_IMMUNITY_TICKS
	_revive_animation_ticks = 18
	velocity = Vector2.ZERO
	AudioDirector.play_cue(&"revive")
	CombatQuery.effect(self, _catalog, "effect_revive_v1", global_position)


func take_hit(amount: int, knockback: Vector2 = Vector2.ZERO) -> bool:
	if downed or immunity_ticks > 0 or amount <= 0:
		return false
	hearts = maxi(0, hearts - amount)
	immunity_ticks = DAMAGE_IMMUNITY_TICKS
	_hurt_ticks = 12
	_attack_kind = ""
	dash_ticks = 0
	velocity = knockback
	revive_progress_ticks = 0
	AudioDirector.play_cue(&"hurt")
	damage_received.emit(self)
	if hearts == 0:
		downed = true
		downed_ticks = 0
		AudioDirector.play_cue(&"downed")
		downed_started.emit(self)
	return true


func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-6, -24), Vector2(12, 24))


func _tick_cooldowns() -> void:
	immunity_ticks = maxi(0, immunity_ticks - 1)
	special_cooldown_ticks = maxi(0, special_cooldown_ticks - 1)
	dash_cooldown_ticks = maxi(0, dash_cooldown_ticks - 1)
	_hurt_ticks = maxi(0, _hurt_ticks - 1)
	_revive_animation_ticks = maxi(0, _revive_animation_ticks - 1)
	_land_ticks = maxi(0, _land_ticks - 1)
	if _drop_ticks > 0:
		_drop_ticks -= 1
		if _drop_ticks == 0:
			_end_drop_through()
	if is_instance_valid(_sprite):
		if immunity_ticks > 0:
			_sprite.modulate.a = 0.65 if reduced_flash else (0.45 if immunity_ticks % 8 < 4 else 1.0)
		else:
			_sprite.modulate.a = 1.0


func _can_dash() -> bool:
	return _progress != null and _progress.has_flag("threadstep") and dash_cooldown_ticks == 0 and _air_dash_available


func _start_dash(move_axis: float) -> void:
	if not is_zero_approx(move_axis):
		facing = -1 if move_axis < 0.0 else 1
	_visual.scale.x = facing
	dash_ticks = DASH_TICKS
	dash_cooldown_ticks = DASH_COOLDOWN_TICKS
	_air_dash_available = false
	_coyote_ticks = 0
	_jump_buffer_ticks = 0
	AudioDirector.play_cue(&"dash")
	CombatQuery.effect(self, _catalog, "effect_dash_v1", global_position, facing)


func _start_attack(kind: String) -> void:
	_attack_kind = kind
	_attack_tick = 0
	_attack_id = CombatQuery.next_attack_id()
	_attack_facing = facing
	_hit_targets.clear()
	if kind != "slash":
		special_cooldown_ticks = 90 if kind == "ember_arc" else 75
	AudioDirector.play_cue(StringName(kind))


func _update_attack() -> void:
	if _attack_kind.is_empty():
		return
	_attack_tick += 1
	var windup := 6 if _attack_kind == "slash" else 12
	var active := 6 if _attack_kind == "slash" else 8
	var total := 24 if _attack_kind == "slash" else 36
	if _attack_kind == "spore_bolt":
		if _attack_tick == 8:
			var bolt := SporeBolt.new()
			bolt.source_slot = slot_index
			bolt.attack_id = _attack_id
			bolt.direction = _attack_facing
			bolt.catalog = _catalog
			get_parent().add_child(bolt)
			bolt.global_position = global_position + Vector2(_attack_facing * 10, -18)
		total = 20
	elif _attack_tick >= windup and _attack_tick < windup + active:
		var reach := 32.0 if _attack_kind == "slash" else 48.0
		var height := 30.0 if _attack_kind == "slash" else 40.0
		var rectangle := Rect2(global_position + Vector2(0.0 if _attack_facing > 0 else -reach, -height), Vector2(reach, height))
		if _attack_tick == windup:
			CombatQuery.effect(self, _catalog, "effect_slash_v1" if _attack_kind == "slash" else "effect_ember_arc_v1", global_position, _attack_facing)
		for enemy in CombatQuery.enemies_in(self, rectangle):
			var target_id := enemy.get_instance_id()
			if _hit_targets.has(target_id):
				continue
			_hit_targets[target_id] = true
			enemy.call("receive_hit", 1 if _attack_kind == "slash" else 2, slot_index, _attack_id, 1 if _attack_kind == "slash" else 3)
	if _attack_tick >= total:
		_attack_kind = ""


func _update_animation() -> void:
	if _hurt_ticks > 0:
		_set_animation("hurt")
	elif _revive_animation_ticks > 0:
		_set_animation("revive")
	elif not _attack_kind.is_empty():
		_set_animation("slash" if _attack_kind == "slash" else "special")
	elif not is_on_floor():
		_set_animation("jump_rise" if velocity.y < 0 else "fall")
	elif _land_ticks > 0:
		_set_animation("land")
	else:
		_set_animation("run" if absf(velocity.x) > 5.0 else "idle")


func _set_animation(state: String) -> void:
	if animation_state == state:
		return
	animation_state = state
	if _animator != null:
		_animator.call("play", state)


func _start_drop_through() -> bool:
	for index in get_slide_collision_count():
		var contact := get_slide_collision(index)
		var body := contact.get_collider() as PhysicsBody2D
		if body == null or body.name != "OneWayCollision" or contact.get_normal().y > -0.5:
			continue
		_drop_body = body
		_drop_ticks = 12
		add_collision_exception_with(body)
		global_position.y += 6.0
		velocity.y = 50.0
		_coyote_ticks = 0
		_jump_buffer_ticks = 0
		return true
	return false


func _end_drop_through() -> void:
	if is_instance_valid(_drop_body):
		remove_collision_exception_with(_drop_body)
	_drop_body = null
	_drop_ticks = 0


func _keep_in_room() -> void:
	if room_bounds.size.x <= 0.0 or room_bounds.size.y <= 0.0:
		return
	global_position.x = clampf(global_position.x, room_bounds.position.x + 6.0, room_bounds.end.x - 6.0)
	if global_position.y < room_bounds.position.y + 24.0:
		global_position.y = room_bounds.position.y + 24.0
		velocity.y = maxf(0.0, velocity.y)
	if global_position.y > room_bounds.end.y + 32.0:
		take_hit(1)
		reset_at(_last_safe_feet)
