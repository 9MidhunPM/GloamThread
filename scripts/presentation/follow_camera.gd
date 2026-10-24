class_name FollowCamera
extends Camera2D
## Keep smooth following state in floating point while presenting whole pixels.
## Each instance belongs to its own SubViewport in the one shared World2D.

const HALF_VIEW := Vector2(240.0, 180.0)
const TARGET_OFFSET := Vector2(0.0, -24.0)
const FOLLOW_RATE := 10.0

var target: Node2D
var room_bounds := Rect2(Vector2.ZERO, HALF_VIEW * 2.0)
var _smoothed_position := Vector2.ZERO


func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false
	drag_horizontal_enabled = false
	drag_vertical_enabled = false
	ignore_rotation = true
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	process_physics_priority = 10
	_snap_to_target()
	make_current()


func configure(follow_target: Node2D, bounds: Rect2) -> void:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		push_error("FollowCamera: room bounds must have positive dimensions")
		return
	target = follow_target
	room_bounds = bounds
	# Expand the guard for a room smaller than the viewport so the native
	# Camera2D limits do not fight our centred-small-room policy.
	var centre := room_bounds.get_center()
	limit_left = floori(minf(room_bounds.position.x, centre.x - HALF_VIEW.x))
	limit_top = floori(minf(room_bounds.position.y, centre.y - HALF_VIEW.y))
	limit_right = ceili(maxf(room_bounds.end.x, centre.x + HALF_VIEW.x))
	limit_bottom = ceili(maxf(room_bounds.end.y, centre.y + HALF_VIEW.y))
	_snap_to_target()
	if is_inside_tree():
		reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var desired := _clamp_centre(target.global_position + TARGET_OFFSET)
	_smoothed_position = _smoothed_position.lerp(desired, 1.0 - exp(-FOLLOW_RATE * delta))
	global_position = _clamp_centre(_smoothed_position).round()


func _snap_to_target() -> void:
	var desired := room_bounds.get_center()
	if is_instance_valid(target):
		desired = target.global_position + TARGET_OFFSET
	_smoothed_position = _clamp_centre(desired)
	global_position = _smoothed_position.round()


func _clamp_centre(position_to_clamp: Vector2) -> Vector2:
	var centre := room_bounds.get_center()
	if room_bounds.size.x > HALF_VIEW.x * 2.0:
		centre.x = clampf(position_to_clamp.x, room_bounds.position.x + HALF_VIEW.x, room_bounds.end.x - HALF_VIEW.x)
	if room_bounds.size.y > HALF_VIEW.y * 2.0:
		centre.y = clampf(position_to_clamp.y, room_bounds.position.y + HALF_VIEW.y, room_bounds.end.y - HALF_VIEW.y)
	return centre
