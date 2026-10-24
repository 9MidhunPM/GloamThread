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

var _players: Array[PlayerController] = []
var _catalog: AssetCatalog
var _bounds: Rect2
var _origin := Vector2.ZERO
var _state: String = "idle"
var _state_ticks: int = 45
var _age_ticks: int = 0
var _facing: int = -1
var _target_slot: int = 0
var _move_index: int = -1
var _move_name: String = "sweep"
var _attack_id: int = 0
var _hit_slots: Dictionary = {}
var _received_attacks: Dictionary = {}
var _stagger_slot: int = -1
var _cross_stitch_used: bool = false
var _dive_direction := Vector2.ZERO
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
	add_to_group("combat_enemies")
	collision_layer = 4
	collision_mask = 1
	_origin = global_position
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 50) if kind == "spoolwarden" else Vector2(20, 18)
	collision.shape = shape
	collision.position.y = -shape.size.y * 0.5
	add_child(collision)
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


func _physics_process(delta: float) -> void:
	_age_ticks += 1
	if dead:
		_state_ticks -= 1
		if _state_ticks <= 0:
			queue_free()
		return
	slow_ticks = maxi(0, slow_ticks - 1)
	slow_immune_ticks = maxi(0, slow_immune_ticks - 1)
	if _feedback != null:
		_feedback.text = "Resists slow" if slow_immune_ticks > 0 else ("Partner strike!" if _state == "stagger" and not _cross_stitch_used else "")
	var target := _target()
	if target == null:
		velocity.x = 0.0
		if kind != "wickwing":
			velocity.y = minf(velocity.y + 1400.0 * delta, 400.0)
			move_and_slide()
		return
	match kind:
		"spoolwarden": _boss_tick(target, delta)
		"wickwing": _wing_tick(target, delta)
		_: _mite_tick(target, delta)
	_keep_in_room()
	_visual.scale.x = _facing
	if _animator != null:
		_animator.call("play", animation_state)


func hurt_rect() -> Rect2:
	var size := Vector2(40, 50) if kind == "spoolwarden" else Vector2(20, 18)
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
	AudioDirector.play_cue(&"hit")
	CombatQuery.effect(self, _catalog, "effect_hit_v1", global_position)
	if health == 0:
		dead = true
		velocity = Vector2.ZERO
		_state_ticks = 90 if kind == "spoolwarden" else 30
		animation_state = "defeat"
		collision_layer = 0
		if _animator != null:
			_animator.call("play", "defeat")
		AudioDirector.play_cue(&"enemy_defeat")
		defeated.emit(self)
	return true


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
	velocity.y = minf(velocity.y + 1400.0 * delta, 400.0)
	if _state == "idle":
		animation_state = "walk"
		velocity.x = _facing * 32.0 * speed_scale
		if absf(global_position.x - _origin.x) > 64.0 or is_on_wall() or not _ground_ahead():
			_facing *= -1
		if global_position.distance_to(target.global_position) < 180.0 and absf(global_position.y - target.global_position.y) < 40.0:
			_facing = 1 if target.global_position.x >= global_position.x else -1
			_enter("anticipation", 30)
			AudioDirector.play_cue(&"enemy_warning")
	elif _state == "anticipation":
		animation_state = "anticipation"
		velocity.x = 0.0
		if _countdown(): _begin_active("charge", 24)
	elif _state == "charge":
		animation_state = "charge"
		velocity.x = _facing * 165.0 * speed_scale if _ground_ahead() else 0.0
		_hit_players(hurt_rect().grow(3.0))
		if _countdown() or is_on_wall(): _enter("recovery", 36)
	else:
		animation_state = "recovery"
		velocity.x = move_toward(velocity.x, 0.0, 1000.0 * delta)
		if _countdown(): _finish_attack()
	move_and_slide()


func _wing_tick(target: PlayerController, delta: float) -> void:
	var speed_scale := 0.5 if slow_ticks > 0 else 1.0
	if _state == "idle":
		animation_state = "flap"
		var hover := _origin + Vector2(sin(_age_ticks / 70.0) * 20.0, sin(_age_ticks / 18.0) * 8.0)
		velocity = (hover - global_position) * 3.0 * speed_scale
		if global_position.distance_to(target.global_position) < 260.0:
			_facing = 1 if target.global_position.x >= global_position.x else -1
			_dive_direction = (target.global_position + Vector2(0, -12) - global_position).normalized()
			_enter("anticipation", 36)
			AudioDirector.play_cue(&"enemy_warning")
	elif _state == "anticipation":
		animation_state = "anticipation"
		velocity = Vector2.ZERO
		if _countdown(): _begin_active("dive", 36)
	elif _state == "dive":
		animation_state = "dive"
		velocity = _dive_direction * 180.0 * speed_scale
		_hit_players(hurt_rect().grow(4.0))
		if _countdown() or is_on_floor() or is_on_wall(): _enter("recovery", 60)
	else:
		animation_state = "recovery"
		velocity = (_origin - global_position).limit_length(80.0) * speed_scale
		if _countdown(): _finish_attack()
	move_and_slide()


func _boss_tick(target: PlayerController, delta: float) -> void:
	velocity.y = minf(velocity.y + 1400.0 * delta, 400.0)
	if _state == "idle":
		animation_state = "idle"
		var gap := target.global_position.x - global_position.x
		_facing = 1 if gap >= 0.0 else -1
		velocity.x = _facing * 52.0 if absf(gap) > 96.0 and absf(gap) < 420.0 else 0.0
		if absf(gap) < 220.0 and _countdown():
			_move_index = (_move_index + 1) % 3
			_move_name = ["sweep", "strike", "charge"][_move_index]
			_enter("anticipation", 60 if _move_name == "strike" else 45)
			AudioDirector.play_cue(&"enemy_warning")
	elif _state == "anticipation":
		animation_state = _move_name + "_anticipation"
		velocity.x = 0.0
		if _countdown():
			_begin_active("active", 36 if _move_name == "charge" else 14)
	elif _state == "active":
		animation_state = _move_name + "_active"
		velocity.x = _facing * 250.0 if _move_name == "charge" else 0.0
		var rectangle: Rect2
		if _move_name == "charge":
			rectangle = hurt_rect().grow(4.0)
		elif _move_name == "strike":
			rectangle = Rect2(global_position + Vector2(-90, -18), Vector2(180, 18))
		else:
			rectangle = Rect2(global_position + Vector2(0 if _facing > 0 else -110, -48), Vector2(110, 48))
		_hit_players(rectangle)
		if _countdown() or (_move_name == "charge" and is_on_wall()):
			_enter("recovery", 60 if _move_name == "strike" else 48)
	elif _state == "stagger":
		animation_state = "stagger"
		velocity.x = 0.0
		if _countdown():
			_enter("recovery", 42)
	else:
		animation_state = _move_name + "_recovery"
		velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
		if _countdown(): _finish_attack()
	move_and_slide()


func _enter(state: String, ticks: int) -> void:
	_state = state
	_state_ticks = ticks


func _begin_active(state: String, ticks: int) -> void:
	_enter(state, ticks)
	_attack_id = CombatQuery.next_attack_id()
	_hit_slots.clear()


func _countdown() -> bool:
	_state_ticks -= 1
	return _state_ticks <= 0


func _finish_attack() -> void:
	_target_slot = 1 - _target_slot
	_enter("idle", 40)


func _hit_players(rectangle: Rect2) -> void:
	for player in _players:
		if not is_instance_valid(player) or player.downed or _hit_slots.has(player.slot_index):
			continue
		if rectangle.intersects(player.hurt_rect()) and CombatQuery.clear_line(self, hurt_rect().get_center(), player.hurt_rect().get_center()):
			_hit_slots[player.slot_index] = true
			player.take_hit(1, Vector2(_facing * 140.0, -130.0))


func _ground_ahead() -> bool:
	if not is_on_floor():
		return true
	var from := global_position + Vector2(_facing * 14.0, -4.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 28), 1)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _keep_in_room() -> void:
	if _bounds.size.x <= 0.0:
		return
	var margin := 22.0 if kind == "spoolwarden" else 12.0
	var before := global_position.x
	global_position.x = clampf(before, _bounds.position.x + margin, _bounds.end.x - margin)
	if global_position.x != before:
		_facing *= -1
	if global_position.y > _bounds.end.y + 64.0:
		global_position = _origin
		velocity = Vector2.ZERO
