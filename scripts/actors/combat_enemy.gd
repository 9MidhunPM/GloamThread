class_name CombatEnemy
extends CharacterBody2D
## Three explicit, bounded encounter state machines over one authoritative body.
## Animation follows gameplay states; it never schedules hits or rewards.

signal defeated(enemy: CombatEnemy)

var kind: String = "spoolmite"
var health: int = 3
var max_health: int = 3
var dead: bool = false
var animation_state: String = "idle"
var slow_ticks: int = 0
var slow_immune_ticks: int = 0
var stagger_meter: int = 0
var cross_stitch_count: int = 0
var phase: int = 1
var _phase_notice_ticks: int = 0
var _charge_speed := 250.0

var _players: Array[PlayerController] = []
var _catalog: AssetCatalog
var _bounds: Rect2
var _origin := Vector2.ZERO
var _state: String = "idle"
var _state_ticks: int = 45
var _age_ticks: int = 0
var _facing := Vector2.LEFT
var _attack_direction := Vector2.LEFT
var _patrol_direction := Vector2.LEFT
var _target_slot: int = 0
var _move_index: int = -1
var _move_name: String = "sweep"
var _attack_id: int = 0
var _hit_slots: Dictionary = {}
var _received_attacks: Dictionary = {}
var _stagger_slot: int = -1
var _cross_stitch_used: bool = false
var _dive_direction := Vector2.ZERO
var _recovery_point := Vector2.ZERO
var _can_stand: Callable
var _can_threadstep: Callable
var _water_body: PhysicsBody2D
var _ignoring_water := false
var _visual: Node2D
var _sprite: Sprite2D
var _animator: Node
var _feedback: Label


func configure(enemy_kind: String, players: Array[PlayerController], catalog: AssetCatalog, bounds: Rect2) -> void:
	kind = enemy_kind
	_players = players
	_catalog = catalog
	_bounds = bounds
	max_health = 30 if kind == "spoolwarden" else (2 if kind == "wickwing" else 3)
	health = max_health
	animation_state = "flap" if kind == "wickwing" else "idle"


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("combat_enemies")
	collision_layer = 4
	collision_mask = 1
	_origin = global_position
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = _footprint_size()
	collision.shape = shape
	collision.position.y = -shape.size.y * 0.5
	add_child(collision)
	_update_water_exception()
	_visual = Node2D.new()
	add_child(_visual)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_visual.add_child(_sprite)
	if _catalog != null:
		var animator_script: Script = load("res://scripts/presentation/sprite_animator.gd")
		_animator = animator_script.new()
		_visual.add_child(_animator)
		_animator.call("configure", _sprite, _catalog, kind + "_v1")
		_animator.call("play", animation_state)
		_feedback = Label.new()
		_feedback.position = Vector2(-48, -82)
		_feedback.add_theme_font_override("font", _catalog.call("font"))
		_feedback.add_theme_font_size_override("font_size", 16)
		_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_feedback)


## Same room seam as couriers. World queries own terrain interpretation.
func set_room_context(bounds: Rect2, can_stand: Callable, can_threadstep: Callable, water_body: PhysicsBody2D = null) -> void:
	if _ignoring_water and is_instance_valid(_water_body):
		remove_collision_exception_with(_water_body)
	_ignoring_water = false
	_bounds = bounds
	_can_stand = can_stand
	_can_threadstep = can_threadstep
	_water_body = water_body
	_update_water_exception()


func _update_water_exception() -> void:
	if kind == "wickwing" and is_inside_tree() and is_instance_valid(_water_body):
		add_collision_exception_with(_water_body)
		_ignoring_water = true


func _physics_process(delta: float) -> void:
	_age_ticks += 1
	if dead:
		_state_ticks -= 1
		if _state_ticks <= 0:
			queue_free()
		return
	slow_ticks = maxi(0, slow_ticks - 1)
	slow_immune_ticks = maxi(0, slow_immune_ticks - 1)
	_phase_notice_ticks = maxi(0, _phase_notice_ticks - 1)
	if _feedback != null:
		_feedback.text = feedback_text()
	var target := _target()
	if target == null:
		velocity = Vector2.ZERO
		return
	match kind:
		"spoolwarden": _boss_tick(target, delta)
		"wickwing": _wing_tick(target, delta)
		_: _mite_tick(target, delta)
	_keep_in_room()
	# Hover belongs to presentation; it cannot drag the hurtbox off the plane.
	_visual.position.y = -3.0 + sin(_age_ticks / 12.0) * 2.0 if kind == "wickwing" else 0.0
	if _animator != null:
		_animator.call("play", animation_state)


func _footprint_size() -> Vector2:
	return Vector2(32, 20) if kind == "spoolwarden" else (Vector2(14, 10) if kind == "wickwing" else Vector2(16, 12))


func hurt_rect() -> Rect2:
	var size := _footprint_size()
	return Rect2(global_position + Vector2(-size.x * 0.5, -size.y), size)


func receive_hit(damage: int, slot: int, attack_id: int, stagger: int = 1, applied_slow_ticks: int = 0) -> bool:
	if dead or damage <= 0 or slot < 0 or slot > 1 or _received_attacks.has(attack_id):
		return false
	_received_attacks[attack_id] = true
	if _received_attacks.size() > 128:
		_received_attacks.erase(_received_attacks.keys()[0])
	var total_damage := damage
	if kind == "spoolwarden":
		if applied_slow_ticks > 0:
			slow_immune_ticks = 36
		if _state == "stagger" and slot != _stagger_slot and not _cross_stitch_used:
			total_damage += 4
			_cross_stitch_used = true
			cross_stitch_count += 1
			AudioDirector.play_cue(&"cross_stitch")
			CombatQuery.effect(self, _catalog, "effect_weave_v1", global_position)
		elif _state != "stagger":
			stagger_meter += maxi(0, stagger)
			if stagger_meter >= 6:
				_stagger_slot = slot
				_cross_stitch_used = false
				stagger_meter = 0
				_enter("stagger", 90)
				animation_state = "stagger"
				AudioDirector.play_cue(&"boss_stagger")
	else:
		slow_ticks = maxi(slow_ticks, mini(applied_slow_ticks, 180))
	health = maxi(0, health - total_damage)
	if kind == "spoolwarden" and health > 0 and phase == 1 and health * 2 <= max_health:
		phase = 2
		_phase_notice_ticks = 120
	AudioDirector.play_cue(&"hit")
	CombatQuery.effect(self, _catalog, "effect_hit_v1", global_position)
	if health == 0:
		dead = true
		if _feedback != null:
			_feedback.text = ""
		velocity = Vector2.ZERO
		_state_ticks = 90 if kind == "spoolwarden" else 30
		animation_state = "defeat"
		collision_layer = 0
		if _animator != null:
			_animator.call("play", "defeat")
		AudioDirector.play_cue(&"enemy_defeat")
		defeated.emit(self)
	return true


## Shared feedback prioritizes the co-op opening without hiding slow immunity.
func feedback_text() -> String:
	if dead:
		return ""
	var notice := ""
	if _state == "stagger" and not _cross_stitch_used:
		notice = "Partner strike!"
	elif _phase_notice_ticks > 0:
		notice = "Seam ablaze!"
	if slow_immune_ticks > 0:
		notice += ("\n" if not notice.is_empty() else "") + "Resists slow"
	return notice


func _target() -> PlayerController:
	if _players.is_empty():
		return null
	# Alternate preferred slot after each attack, falling back to the closest
	# living player when that preference is too far away or downed.
	if _target_slot < _players.size():
		var preferred := _players[_target_slot]
		if is_instance_valid(preferred) and not preferred.downed and global_position.distance_to(preferred.global_position) < 300.0:
			return preferred
	var nearest: PlayerController
	var distance := INF
	for player in _players:
		if not is_instance_valid(player) or player.downed:
			continue
		var candidate := global_position.distance_squared_to(player.global_position)
		if candidate < distance:
			distance = candidate
			nearest = player
	return nearest


func _mite_tick(target: PlayerController, delta: float) -> void:
	var speed_scale := 0.5 if slow_ticks > 0 else 1.0
	if _state == "idle":
		animation_state = "walk"
		if global_position.distance_to(_origin) > 56.0:
			_patrol_direction = (_origin - global_position).normalized()
		elif get_slide_collision_count() > 0:
			_patrol_direction = _patrol_direction.rotated(PI * 0.5)
		velocity = _patrol_direction * 32.0 * speed_scale
		_facing = _patrol_direction
		if global_position.distance_to(target.global_position) < 180.0 and CombatQuery.clear_line(self, hurt_rect().get_center(), target.hurt_rect().get_center()):
			_attack_direction = _toward(target.hurt_rect().get_center())
			_facing = _attack_direction
			velocity = Vector2.ZERO
			_enter("anticipation", 30)
			AudioDirector.play_cue(&"enemy_warning")
	elif _state == "anticipation":
		animation_state = "anticipation"
		velocity = Vector2.ZERO
		if _countdown(): _begin_active("charge", 24)
	elif _state == "charge":
		animation_state = "charge"
		velocity = _attack_direction * 165.0 * speed_scale
	else:
		animation_state = "recovery"
		velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
		if _countdown(): _finish_attack()
	move_and_slide()
	if _state == "charge" and animation_state == "charge":
		_hit_players(hurt_rect().grow(3.0))
		if _countdown() or get_slide_collision_count() > 0:
			velocity = Vector2.ZERO
			_enter("recovery", 36)


func _wing_tick(target: PlayerController, _delta: float) -> void:
	var speed_scale := 0.5 if slow_ticks > 0 else 1.0
	if _state == "idle":
		animation_state = "flap"
		velocity = Vector2.ZERO
		if global_position.distance_to(target.global_position) < 260.0:
			_dive_direction = _toward(target.hurt_rect().get_center())
			_attack_direction = _dive_direction
			_facing = _dive_direction
			_recovery_point = _dry_approach(target)
			_enter("anticipation", 36)
			AudioDirector.play_cue(&"enemy_warning")
	elif _state == "anticipation":
		animation_state = "anticipation"
		velocity = Vector2.ZERO
		if _countdown(): _begin_active("dive", 36)
	elif _state == "dive":
		animation_state = "dive"
		velocity = _dive_direction * 180.0 * speed_scale
	else:
		animation_state = "recovery"
		_recovery_point = _dry_approach(target)
		velocity = (_recovery_point - global_position).limit_length(80.0) * speed_scale
		# Recovery lasts at least sixty ticks and keeps returning while over
		# water, giving the close-range courier a dry approach to the enemy.
		if _countdown() and _standable(global_position):
			_origin = global_position
			_finish_attack()
	move_and_slide()
	if _state == "dive" and animation_state == "dive":
		_hit_players(hurt_rect().grow(4.0))
		if _countdown() or get_slide_collision_count() > 0:
			velocity = Vector2.ZERO
			_enter("recovery", 60)


func _dry_approach(target: PlayerController) -> Vector2:
	var approach := target.global_position - _attack_direction * 24.0
	return approach if _standable(approach) else target.global_position


func _standable(feet: Vector2) -> bool:
	return not _can_stand.is_valid() or bool(_can_stand.call(feet))


func _toward(at: Vector2) -> Vector2:
	var direction := at - hurt_rect().get_center()
	return _facing if direction.is_zero_approx() else direction.normalized()


func _boss_tick(target: PlayerController, delta: float) -> void:
	if _state == "idle":
		animation_state = "idle"
		var offset := target.hurt_rect().get_center() - hurt_rect().get_center()
		_facing = _toward(target.hurt_rect().get_center())
		velocity = _facing * (62.0 if phase == 2 else 52.0) if offset.length() > 96.0 and offset.length() < 420.0 else Vector2.ZERO
		if offset.length() < 220.0 and _countdown():
			_move_index = (_move_index + 1) % 3
			_move_name = ["sweep", "strike", "charge"][_move_index]
			_attack_direction = _facing
			velocity = Vector2.ZERO
			_enter("anticipation", 60 if _move_name == "strike" else 45)
			AudioDirector.play_cue(&"enemy_warning")
	elif _state == "anticipation":
		animation_state = _move_name + "_anticipation"
		velocity = Vector2.ZERO
		if _countdown():
			_begin_active("active", 36 if _move_name == "charge" else 14)
	elif _state == "active":
		animation_state = _move_name + "_active"
		velocity = _attack_direction * _charge_speed if _move_name == "charge" else Vector2.ZERO
	elif _state == "stagger":
		animation_state = "stagger"
		velocity = Vector2.ZERO
		if _countdown(): _enter("recovery", 42)
	else:
		animation_state = _move_name + "_recovery"
		velocity = velocity.move_toward(Vector2.ZERO, 1400.0 * delta)
		if _countdown(): _finish_attack()
	move_and_slide()
	if _state == "active" and animation_state.ends_with("_active"):
		_boss_hit_players()
		if _countdown() or (_move_name == "charge" and get_slide_collision_count() > 0):
			velocity = Vector2.ZERO
			_enter("recovery", 60 if _move_name == "strike" else 48)


func _boss_hit_players() -> void:
	if _move_name == "charge":
		_hit_players(hurt_rect().grow(4.0))
		return
	var origin := hurt_rect().get_center()
	for player in _players:
		if not is_instance_valid(player) or player.downed or _hit_slots.has(player.slot_index):
			continue
		var box := player.hurt_rect()
		var point := Vector2(clampf(origin.x, box.position.x, box.end.x), clampf(origin.y, box.position.y, box.end.y))
		var offset := point - origin
		var in_range := offset.length() <= (66.0 if _move_name == "strike" else 74.0)
		var in_arc := _move_name == "strike" or offset.is_zero_approx() or offset.normalized().dot(_attack_direction) >= 0.35
		if in_range and in_arc and CombatQuery.clear_line(self, origin, box.get_center()):
			_damage_player(player)


func _enter(state: String, ticks: int) -> void:
	_state = state
	_state_ticks = ticks


func _begin_active(state: String, ticks: int) -> void:
	if kind == "spoolwarden" and _move_name == "charge":
		_charge_speed = 275.0 if phase == 2 else 250.0
	_enter(state, ticks)
	_attack_id = CombatQuery.next_attack_id()
	_hit_slots.clear()


func _countdown() -> bool:
	_state_ticks -= 1
	return _state_ticks <= 0


func _finish_attack() -> void:
	_target_slot = 1 - _target_slot
	_enter("idle", 28 if kind == "spoolwarden" and phase == 2 else 40)


func _hit_players(rectangle: Rect2) -> void:
	for player in _players:
		if not is_instance_valid(player) or player.downed or _hit_slots.has(player.slot_index):
			continue
		if rectangle.intersects(player.hurt_rect()) and CombatQuery.clear_line(self, hurt_rect().get_center(), player.hurt_rect().get_center()):
			_damage_player(player)


func _damage_player(player: PlayerController) -> void:
	_hit_slots[player.slot_index] = true
	var direction := (player.hurt_rect().get_center() - hurt_rect().get_center()).normalized()
	player.take_hit(1, direction * 140.0)


func _keep_in_room() -> void:
	if _bounds.size.x <= 0.0 or _bounds.size.y <= 0.0:
		return
	var size := _footprint_size()
	var before := global_position
	global_position = Vector2(clampf(before.x, _bounds.position.x + size.x * 0.5, _bounds.end.x - size.x * 0.5), clampf(before.y, _bounds.position.y + size.y, _bounds.end.y))
	if global_position != before:
		_patrol_direction = (_origin - global_position).normalized()
		velocity = Vector2.ZERO
