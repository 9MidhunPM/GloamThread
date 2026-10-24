class_name PlayerController
extends CharacterBody2D
## Owned-input courier motor and attacks. Team down/revive timing and room
## transactions remain with GameSession; all timers here use physics ticks.

signal damage_received(player: PlayerController)
signal downed_started(player: PlayerController)

enum Facing { DOWN, LEFT, RIGHT, UP }
const FACING_VECTORS: Array[Vector2] = [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
const DIRECTION_NAMES: Array[String] = ["down", "left", "right", "up"]
const MAX_SPEED := 110.0
const MOVE_ACCEL := 900.0
const DASH_SPEED := 360.0
const DASH_TICKS := 12
const DASH_COOLDOWN_TICKS := 30
const ROLL_SPEED := 180.0
const ROLL_TICKS := 12
const ROLL_COOLDOWN_TICKS := 36
const ROLL_IMMUNITY_TICKS := 6
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
var facing: Facing = Facing.DOWN
var facing_vector: Vector2:
	get:
		return FACING_VECTORS[facing]
var animation_key: String = "idle_down"
var immunity_ticks: int = 0
var special_cooldown_ticks: int = 0
var dash_cooldown_ticks: int = 0
var dash_ticks: int = 0
var roll_ticks: int = 0
var roll_cooldown_ticks: int = 0
var _roll_immunity_ticks: int = 0
var special_id: String = "ember_arc"
var reduced_flash: bool = false
var sprite_texture: Texture2D:
	set(value):
		sprite_texture = value
		if is_node_ready():
			_sprite.texture = value

var _hurt_ticks: int = 0
var _revive_animation_ticks: int = 0
var _attack_kind: String = ""
var _attack_tick: int = 0
var _attack_id: int = 0
var _attack_facing: int = 1
var _hit_targets: Dictionary = {}
var _catalog: AssetCatalog
var _progress: TeamProgress
var _visual_id: String = ""
var _animator: Node
var _can_stand: Callable
var _can_threadstep: Callable
var _water_body: PhysicsBody2D
var _last_safe_feet := Vector2.ZERO

@onready var _visual: Node2D = $Visual
@onready var _sprite: Sprite2D = $Visual/Sprite2D


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
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
	_animator.call("play", animation_key)


## Room owns ground interpretation. Queries accept world-space feet positions.
func set_room_context(bounds: Rect2, can_stand: Callable, can_threadstep: Callable, water_body: PhysicsBody2D = null) -> void:
	room_bounds = bounds
	_can_stand = can_stand
	_can_threadstep = can_threadstep
	_water_body = water_body
	if _standable(global_position):
		_last_safe_feet = global_position


func _physics_process(delta: float) -> void:
	_tick_cooldowns()
	if downed:
		velocity = Vector2.ZERO
		_set_animation("downed")
		return
	var commands: CommandSnapshot = InputRouter.snapshot(slot_index)
	var movement := Vector2(commands.move_x, commands.move_y).limit_length(1.0)
	if _attack_kind.is_empty() and _hurt_ticks == 0 and dash_ticks == 0 and roll_ticks == 0:
		_update_facing(movement)
		if commands.just_pressed(Action.DASH) and _can_dash():
			_start_dash(movement)
		elif commands.just_pressed(Action.JUMP) and roll_cooldown_ticks == 0:
			_start_roll()
		elif commands.just_pressed(Action.SPECIAL) and special_cooldown_ticks == 0:
			_start_attack(special_id)
		elif commands.just_pressed(Action.ATTACK):
			_start_attack("slash")
	if dash_ticks > 0:
		velocity = facing_vector * DASH_SPEED
		move_and_slide()
		_keep_in_room()
		dash_ticks -= 1
		_set_animation("dash")
		return
	if roll_ticks > 0:
		velocity = facing_vector * ROLL_SPEED
		move_and_slide()
		_keep_in_room()
		roll_ticks -= 1
		_set_animation("roll")
		return
	if _hurt_ticks > 0:
		velocity = velocity.move_toward(Vector2.ZERO, MOVE_ACCEL * delta)
	else:
		var move_scale := 1.0 if _attack_kind.is_empty() else 0.4
		velocity = velocity.move_toward(movement * MAX_SPEED * move_scale, MOVE_ACCEL * delta)
	move_and_slide()
	_keep_in_room()
	if _standable(global_position):
		_last_safe_feet = global_position
	_update_attack()
	_update_animation()


func _update_facing(movement: Vector2) -> void:
	if movement.is_zero_approx():
		return
	var horizontal := absf(movement.x)
	var vertical := absf(movement.y)
	if is_equal_approx(horizontal, vertical) and movement.dot(facing_vector) > 0.0:
		return
	if horizontal > vertical:
		facing = Facing.RIGHT if movement.x > 0.0 else Facing.LEFT
	else:
		facing = Facing.DOWN if movement.y > 0.0 else Facing.UP


func reset_at(feet_position: Vector2) -> void:
	global_position = feet_position
	velocity = Vector2.ZERO
	_attack_kind = ""
	_hit_targets.clear()
	dash_ticks = 0
	roll_ticks = 0
	_roll_immunity_ticks = 0
	_hurt_ticks = 0
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
	roll_cooldown_ticks = 0
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
	if downed or immunity_ticks > 0 or _roll_immunity_ticks > 0 or amount <= 0:
		return false
	hearts = maxi(0, hearts - amount)
	immunity_ticks = DAMAGE_IMMUNITY_TICKS
	_hurt_ticks = 12
	_attack_kind = ""
	dash_ticks = 0
	roll_ticks = 0
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
	return Rect2(global_position + Vector2(-6, -10), Vector2(12, 10))


func _tick_cooldowns() -> void:
	immunity_ticks = maxi(0, immunity_ticks - 1)
	special_cooldown_ticks = maxi(0, special_cooldown_ticks - 1)
	dash_cooldown_ticks = maxi(0, dash_cooldown_ticks - 1)
	roll_cooldown_ticks = maxi(0, roll_cooldown_ticks - 1)
	_roll_immunity_ticks = maxi(0, _roll_immunity_ticks - 1)
	_hurt_ticks = maxi(0, _hurt_ticks - 1)
	_revive_animation_ticks = maxi(0, _revive_animation_ticks - 1)
	if is_instance_valid(_sprite):
		if immunity_ticks > 0:
			_sprite.modulate.a = 0.65 if reduced_flash else (0.45 if immunity_ticks % 8 < 4 else 1.0)
		else:
			_sprite.modulate.a = 1.0


func _start_roll() -> void:
	roll_ticks = ROLL_TICKS
	roll_cooldown_ticks = ROLL_COOLDOWN_TICKS
	_roll_immunity_ticks = ROLL_IMMUNITY_TICKS
	AudioDirector.play_cue(&"roll")


func _can_dash() -> bool:
	return _progress != null and _progress.has_flag("threadstep") and dash_cooldown_ticks == 0


func _start_dash(movement: Vector2) -> void:
	_update_facing(movement)
	dash_ticks = DASH_TICKS
	dash_cooldown_ticks = DASH_COOLDOWN_TICKS
	AudioDirector.play_cue(&"dash")
	CombatQuery.effect(self, _catalog, "effect_dash_v1", global_position, -1 if facing == Facing.LEFT else 1)


func _start_attack(kind: String) -> void:
	_attack_kind = kind
	_attack_tick = 0
	_attack_id = CombatQuery.next_attack_id()
	_attack_facing = -1 if facing == Facing.LEFT else 1
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
	else:
		_set_animation("run" if velocity.length() > 5.0 else "idle")


func _set_animation(state: String) -> void:
	var key: String = state + "_" + DIRECTION_NAMES[facing]
	if animation_key == key:
		return
	animation_state = state
	animation_key = key
	if _animator != null:
		_animator.call("play", animation_key)


func _standable(feet: Vector2) -> bool:
	if _can_stand.is_valid():
		return bool(_can_stand.call(feet))
	return room_bounds.size.is_zero_approx() or room_bounds.encloses(Rect2(feet + Vector2(-6, -10), Vector2(12, 10)))


func _keep_in_room() -> void:
	if room_bounds.size.x <= 0.0 or room_bounds.size.y <= 0.0:
		return
	var before := global_position
	global_position = Vector2(clampf(before.x, room_bounds.position.x + 6.0, room_bounds.end.x - 6.0), clampf(before.y, room_bounds.position.y + 10.0, room_bounds.end.y))
	if global_position.x != before.x:
		velocity.x = 0.0
	if global_position.y != before.y:
		velocity.y = 0.0
