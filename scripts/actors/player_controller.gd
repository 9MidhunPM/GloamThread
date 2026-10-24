class_name PlayerController
extends CharacterBody2D
## Shared courier motor. Session code owns devices, pause and room transitions;
## this body consumes only its assigned player's physics-tick snapshot.

const GRAVITY := 1400.0
const JUMP_SPEED := -330.0
const MAX_SPEED := 110.0
const GROUND_ACCEL := 900.0
const AIR_ACCEL := 600.0
const MAX_FALL := 400.0
const JUMP_RELEASE_SPEED := -140.0
const COYOTE_TICKS := 6
const JUMP_BUFFER_TICKS := 6
const Action := CommandSnapshot.Action

var slot_index: int = 0
var profile_id: String = ""
var sprite_texture: Texture2D:
	set(value):
		sprite_texture = value
		if is_node_ready():
			_sprite.texture = value

var _coyote_ticks: int = 0
var _jump_buffer_ticks: int = 0

@onready var _visual: Node2D = $Visual
@onready var _sprite: Sprite2D = $Visual/Sprite2D


func _ready() -> void:
	_sprite.texture = sprite_texture


func _physics_process(delta: float) -> void:
	var commands: CommandSnapshot = InputRouter.snapshot(slot_index)
	# A buffered landing can already have queued upward velocity for this tick.
	var grounded := is_on_floor() and velocity.y >= 0.0
	if grounded:
		_coyote_ticks = COYOTE_TICKS
	if commands.just_pressed(Action.JUMP):
		_jump_buffer_ticks = JUMP_BUFFER_TICKS

	var acceleration := GROUND_ACCEL if grounded else AIR_ACCEL
	velocity.x = move_toward(velocity.x, commands.move_x * MAX_SPEED, acceleration * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	if not is_zero_approx(commands.move_x):
		_visual.scale.x = -1.0 if commands.move_x < 0.0 else 1.0

	if _jump_buffer_ticks > 0 and _coyote_ticks > 0:
		_start_jump()
	_cut_released_jump(commands)
	move_and_slide()

	# Consume a buffered press on the landing tick, before its grace expires.
	# Motion starts next tick; never run a second physics move in this frame.
	if not grounded and is_on_floor() and _jump_buffer_ticks > 0:
		_start_jump()
		_cut_released_jump(commands)
	_coyote_ticks = maxi(0, _coyote_ticks - 1)
	_jump_buffer_ticks = maxi(0, _jump_buffer_ticks - 1)


func _start_jump() -> void:
	velocity.y = JUMP_SPEED
	_coyote_ticks = 0
	_jump_buffer_ticks = 0


func _cut_released_jump(commands: CommandSnapshot) -> void:
	if not commands.is_held(Action.JUMP) and velocity.y < JUMP_RELEASE_SPEED:
		velocity.y = JUMP_RELEASE_SPEED


func reset_at(feet_position: Vector2) -> void:
	global_position = feet_position
	velocity = Vector2.ZERO
	_coyote_ticks = 0
	_jump_buffer_ticks = 0
	if is_inside_tree():
		reset_physics_interpolation()
