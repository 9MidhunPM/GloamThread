class_name ArenaEnemy
extends CharacterBody2D
## Six bounded enemy roles and four explicit boss pattern sets, one shared body.
signal defeated(enemy: ArenaEnemy, source_slot: int)
const ROLE_DATA := {
	"swarm": [18.0, 90.0, 6.0, Vector2(14,18)], "chaser": [32.0, 76.0, 9.0, Vector2(20,30)],
	"charger": [42.0, 62.0, 12.0, Vector2(24,30)], "shooter": [26.0, 42.0, 8.0, Vector2(20,30)],
	"flyer": [24.0, 72.0, 8.0, Vector2(24,22)], "heavy": [70.0, 34.0, 16.0, Vector2(30,42)],
}
const ROLE_COLORS := {"swarm":Color("#d1a55f"),"chaser":Color("#d27a65"),"charger":Color("#e6a564"),"shooter":Color("#b9a5df"),"flyer":Color("#83c9d3"),"heavy":Color("#a4b79c")}
static var _reservations: Array[WeakRef] = []
var dead := false
var health := 32.0
var max_health := 32.0
var role := "chaser"
var boss_id := ""
var spawn_id := 0
var elite: bool:
	get:
		return _elite
var _world: Node
var _wave := 1
var _elite := false
var _speed := 76.0
var _damage := 9.0
var _size := Vector2(20,30)
var _state := "approach"
var _state_ticks := 0
var _age := 0
var _facing := -1
var _aim := Vector2.LEFT
var _target_slot := 0
var _pattern := -1
var _attack_id := 0
var _hit_slots: Dictionary = {}
var _received: Dictionary = {}
var _burns: Dictionary = {}
var _marks: Dictionary = {}
var _mark_ticks := 0
var _freeze := 0
var _slow := 0
var _stagger := 0
var _jump_cooldown := 0
var _drop_body: PhysicsBody2D
var _drop_ticks := 0
var _reserved := false
var _texture: Texture2D
var _last_source := -1
var _boss_meter := 0
var _target_point := Vector2.ZERO

func setup(enemy_role: String, world: Node, identity: int, wave: int, elite: bool = false, boss: String = "") -> void:
	role = enemy_role if ROLE_DATA.has(enemy_role) else "chaser"
	boss_id = boss if boss in ["warden", "artillery", "tempest", "loom"] else ""
	_world = world
	spawn_id = identity
	_wave = maxi(1, wave)
	_elite = elite
	_speed = float(ROLE_DATA[role][1])
	_damage = float(ROLE_DATA[role][2]) * (1.0 + 0.035 * (_wave - 1))
	_size = ROLE_DATA[role][3]
	var coop := 1.35 if ArenaCombat.actors(world, "fighters").size() > 1 else 1.0
	max_health = float(ROLE_DATA[role][0]) * (1.0 + 0.12 * (_wave - 1)) * (1.5 if elite else 1.0) * coop
	if not boss_id.is_empty():
		_size = Vector2(44,60)
		_speed = 48.0 if boss_id != "tempest" else 78.0
		_damage = (14.0 + _wave * 0.4)
		max_health = (250.0 + _wave * 28.0) * coop
	health = max_health
	_target_slot = spawn_id % maxi(1, ArenaCombat.actors(world, "fighters").size())
	var textures: Variant = world.get("enemy_textures")
	if textures is Dictionary:
		_texture = textures.get(boss_id if not boss_id.is_empty() else role) as Texture2D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	if role == "flyer" and boss_id.is_empty():
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		position.y = minf(position.y, 238.0)
	var shape := RectangleShape2D.new()
	shape.size = _size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position.y = -_size.y * 0.5
	add_child(collision)

func get_hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-_size.x * 0.5, -_size.y), _size)

func take_damage(amount: float, slot: int, attack_id: int, tags: Dictionary = {}) -> bool:
	if dead or amount <= 0.0 or not is_finite(amount) or _received.has(attack_id) or not ArenaCombat.playing(_world):
		return false
	_received[attack_id] = true
	if _received.size() > 256: _received.erase(_received.keys()[0])
	_last_source = slot
	var damage := amount
	if bool(tags.get("shatter", false)) and (_freeze > 0 or _slow > 0):
		damage *= 1.5
		_freeze = 0
		ArenaCombat.effect(_world, get_hurt_rect().get_center(), Color("#c0ecff"), "shatter")
	if bool(tags.get("consume_marks", false)):
		damage *= 1.0 + 0.35 * int(_marks.get(slot, 0))
		_marks.erase(slot)
	var dealt := minf(health, damage)
	health = maxf(0.0, health - damage)
	ArenaCombat.heal_source(_world, slot, dealt * clampf(float(tags.get("lifesteal", 0.0)), 0.0, 1.0))
	ArenaCombat.effect(_world, get_hurt_rect().get_center(), Color("#fff0ce"), "hit")
	if health <= 0.0:
		dead = true
		collision_layer = 0
		velocity = Vector2.ZERO
		_enter("defeat", 24)
		defeated.emit(self, slot)
	else:
		_apply_statuses(damage, slot, tags)
	if int(tags.get("chain", 0)) > 0:
		_chain(damage * 0.7, slot, attack_id, tags)
	queue_redraw()
	return true

func _apply_statuses(damage: float, slot: int, tags: Dictionary) -> void:
	if int(tags.get("mark", 0)) > 0:
		_marks[slot] = mini(3, int(_marks.get(slot, 0)) + int(tags.mark))
		_mark_ticks = 240
	var burn := clampi(int(tags.get("burn", 0)), 0, 12)
	if burn > 0 and not bool(tags.get("dot", false)):
		var previous: Dictionary = _burns.get(slot, {})
		_burns[slot] = {"ticks":180,"next":30,"power":maxf(float(previous.get("power", 0)), damage * 0.12 + burn * 1.2),"lifesteal":float(tags.get("lifesteal", 0.0))}
	var freeze := clampi(int(tags.get("freeze", 0)), 0, 12)
	if freeze > 0:
		if boss_id.is_empty():
			_freeze = maxi(_freeze, mini(90, 12 + freeze * 12))
			_enter("recover", 16)
		else:
			_slow = maxi(_slow, mini(90, 18 + freeze * 9))
	var stagger := clampi(int(tags.get("stagger", 0)), 0, 12)
	if stagger > 0:
		if boss_id.is_empty():
			_stagger = maxi(_stagger, mini(45, stagger * 6))
			_enter("recover", 16)
		else:
			_boss_meter += stagger
			if _boss_meter >= 8:
				_boss_meter = 0
				_enter("stagger", 48)

func _chain(damage: float, slot: int, attack_id: int, tags: Dictionary) -> void:
	var visited: Array = tags.get("visited", []).duplicate()
	visited.append(get_instance_id())
	var nearest: Node2D
	var distance := 130.0 * 130.0
	for enemy: Node2D in ArenaCombat.actors(_world, "enemies"):
		if not is_instance_valid(enemy) or enemy == self or enemy.dead or visited.has(enemy.get_instance_id()):
			continue
		var candidate := global_position.distance_squared_to(enemy.global_position)
		if candidate < distance and ArenaCombat.clear_line(self, get_hurt_rect().get_center(), enemy.get_hurt_rect().get_center()):
			nearest = enemy
			distance = candidate
	if nearest != null:
		var packet := tags.duplicate(true)
		packet.chain = mini(8, int(tags.chain)) - 1
		packet.visited = visited
		ArenaCombat.effect(_world, global_position.lerp(nearest.global_position, 0.5) + Vector2(0,-24), Color("#f4e78b"), "chain")
		nearest.take_damage(damage, slot, attack_id, packet)

func _physics_process(delta: float) -> void:
	if not ArenaCombat.playing(_world):
		return
	_age += 1
	if dead:
		_state_ticks -= 1
		queue_redraw()
		if _state_ticks <= 0: queue_free()
		return
	_tick_status()
	if dead: return
	var target := _target()
	if target == null:
		velocity.x = 0
		_release()
		return
	var flying := role == "flyer" and boss_id.is_empty()
	if _freeze > 0 or _stagger > 0:
		velocity.x = move_toward(velocity.x, 0, 1500 * delta)
		velocity.y = 0 if flying else minf(500, velocity.y + 1600 * delta)
		move_and_slide()
		queue_redraw()
		return
	if flying:
		_fly_tick(target)
	else:
		_ground_tick(target, delta)
		velocity.y = minf(500, velocity.y + 1600 * delta)
	move_and_slide()
	if _state == "active":
		_active_hits()
		if get_slide_collision_count() > 0 and ((role == "charger" and boss_id.is_empty()) or (not boss_id.is_empty() and _pattern == 2)) and is_on_wall():
			_enter("recover", 36)
	global_position.x = clampf(global_position.x, 16 + _size.x * 0.5, 624 - _size.x * 0.5)
	if global_position.y > 360:
		global_position.y = 320
		velocity.y = 0
	queue_redraw()

func _tick_status() -> void:
	_freeze = maxi(0, _freeze - 1)
	_slow = maxi(0, _slow - 1)
	_stagger = maxi(0, _stagger - 1)
	_jump_cooldown = maxi(0, _jump_cooldown - 1)
	_mark_ticks = maxi(0, _mark_ticks - 1)
	if _mark_ticks == 0: _marks.clear()
	if _drop_ticks > 0:
		_drop_ticks -= 1
		if _drop_ticks == 0: _end_drop()
	for slot: int in _burns.keys():
		var burn: Dictionary = _burns[slot]
		burn.ticks -= 1
		burn.next -= 1
		if int(burn.next) <= 0:
			burn.next = 30
			take_damage(float(burn.power), slot, ArenaCombat.next_id(), {"dot":true,"lifesteal":burn.lifesteal})
			if dead: return
		if int(burn.ticks) <= 0: _burns.erase(slot)

func _target() -> Node2D:
	var living: Array[Node2D] = []
	for fighter: Node2D in ArenaCombat.actors(_world, "fighters"):
		if is_instance_valid(fighter) and not fighter.downed:
			living.append(fighter)
	if living.is_empty(): return null
	return living[_target_slot % living.size()]

func _ground_tick(target: Node2D, delta: float) -> void:
	var gap := target.global_position.x - global_position.x
	var slow_scale := 0.55 if _slow > 0 else 1.0
	if _state == "approach":
		_facing = 1 if gap >= 0 else -1
		var reach := 210.0 if role == "shooter" or boss_id in ["artillery", "loom"] else (120.0 if not boss_id.is_empty() else 40.0)
		var movement := signf(gap) if absf(gap) > reach * 0.8 else 0.0
		if role == "shooter" and absf(gap) < 130.0: movement = -signf(gap)
		movement = _platform_approach(target, movement)
		velocity.x = move_toward(velocity.x, movement * _speed * slow_scale + _separation(), 900 * delta)
		if absf(gap) < reach and absf(target.global_position.y - global_position.y) < (160 if role == "shooter" else 55) and (role != "shooter" or absf(gap) >= 110.0) and _reserve():
			_aim = (target.get_hurt_rect().get_center() - get_hurt_rect().get_center()).normalized()
			_target_point = target.global_position
			_pattern = (_pattern + 1) % 3
			_enter("windup", _windup_ticks())
			velocity.x = 0
	elif _state == "windup":
		velocity.x = 0
		_state_ticks -= 1
		if _state_ticks <= 0:
			_enter("active", _active_ticks())
			_attack_id = ArenaCombat.next_id()
			_hit_slots.clear()
			_emit_ranged()
	elif _state == "active":
		velocity.x = _charge_speed() * _facing
		if boss_id == "tempest" and _pattern == 1 and _state_ticks == _active_ticks():
			velocity.y = -380
		_state_ticks -= 1
		if _state_ticks <= 0: _enter("recover", 36 if boss_id.is_empty() else 48)
	else:
		velocity.x = move_toward(velocity.x, 0, 1200 * delta)
		_state_ticks -= 1
		if _state_ticks <= 0:
			_target_slot += 1
			_enter("approach", 0)

func _fly_tick(target: Node2D) -> void:
	if _state == "approach":
		var hover := target.global_position + Vector2(-100 if spawn_id % 2 == 0 else 100, -95)
		velocity = (hover - global_position).limit_length(_speed)
		if global_position.distance_to(target.global_position) < 200 and _reserve():
			_aim = (target.get_hurt_rect().get_center() - get_hurt_rect().get_center()).normalized()
			_enter("windup", 30)
	elif _state == "windup":
		velocity = Vector2.ZERO
		_state_ticks -= 1
		if _state_ticks <= 0:
			_enter("active", 28)
			_attack_id = ArenaCombat.next_id()
			_hit_slots.clear()
	elif _state == "active":
		velocity = _aim * 210
		_state_ticks -= 1
		if _state_ticks <= 0 or is_on_wall(): _enter("recover", 42)
	else:
		velocity = Vector2(0,-65) if global_position.y > 215 else Vector2.ZERO
		_state_ticks -= 1
		if _state_ticks <= 0:
			_target_slot += 1
			_enter("approach", 0)

func _windup_ticks() -> int:
	if not boss_id.is_empty(): return 55 if _pattern == 1 else 40
	return {"swarm":16,"chaser":22,"charger":32,"shooter":28,"flyer":30,"heavy":42}[role]

func _active_ticks() -> int:
	if not boss_id.is_empty(): return 26 if _pattern == 2 else 16
	return 24 if role == "charger" else 8

func _charge_speed() -> float:
	if not boss_id.is_empty():
		if boss_id == "tempest": return 260.0 if _pattern != 0 else 0.0
		return 240.0 if boss_id == "warden" and _pattern == 2 else 0.0
	return 230.0 if role == "charger" else 0.0

func _emit_ranged() -> void:
	var origin := get_hurt_rect().get_center()
	if boss_id.is_empty():
		if role == "shooter": _shot(origin, _aim, _damage, 190)
		return
	match boss_id:
		"warden":
			if _pattern == 1:
				_shot(global_position + Vector2(0,-10), Vector2.LEFT, _damage, 180)
				_shot(global_position + Vector2(0,-10), Vector2.RIGHT, _damage, 180)
		"artillery":
			if _pattern == 0:
				for index in 3: _shot(origin, _aim.rotated((index-1)*0.16), _damage, 185)
			elif _pattern == 1:
				for index in 5: _shot(Vector2(clampf(_target_point.x+(index-2)*52,40,600),40), Vector2.DOWN, _damage, 165)
			else:
				for index in 3: _shot(origin, Vector2(_facing*0.7, -1).normalized().rotated((index-1)*0.12), _damage, 230, {"gravity":600})
		"tempest":
			if _pattern == 0:
				for index in 5: _shot(origin, _aim.rotated((index-2)*0.22), _damage*0.8, 220)
		"loom":
			if _pattern == 0:
				for index in 6:
					if index != spawn_id % 6: _shot(Vector2(70+index*100,64),Vector2.DOWN,_damage,145)
			elif _pattern == 1:
				_shot(Vector2(30,290),Vector2.RIGHT,_damage,165)
				_shot(Vector2(610,250),Vector2.LEFT,_damage,165)
			else:
				for index in 8: _shot(origin,Vector2.from_angle(index*TAU/8),_damage*0.75,140)

func _shot(at: Vector2, direction: Vector2, damage: float, speed: float, extra: Dictionary = {}) -> void:
	var tags := extra.duplicate()
	tags.hostile = true
	tags.speed = speed
	tags.life = 150
	tags.attack_id = ArenaCombat.next_id()
	_world.call("spawn_projectile",at,direction,damage,-1,tags)

func _active_hits() -> void:
	if role == "shooter" or boss_id in ["artillery","loom"]: return
	var rect := get_hurt_rect().grow(4)
	if role not in ["charger","flyer"] or not boss_id.is_empty():
		var reach := 105.0 if not boss_id.is_empty() else (64.0 if role == "heavy" else 35.0)
		rect = Rect2(global_position + Vector2(0 if _facing>0 else -reach, -45),Vector2(reach,45))
		if boss_id == "warden" and _pattern == 1: rect = Rect2(global_position+Vector2(-95,-24),Vector2(190,26))
	for fighter: Node2D in ArenaCombat.actors(_world,"fighters"):
		if not is_instance_valid(fighter) or fighter.downed or _hit_slots.has(fighter.slot_index): continue
		if rect.intersects(fighter.get_hurt_rect()) and ArenaCombat.clear_line(self,get_hurt_rect().get_center(),fighter.get_hurt_rect().get_center()):
			var before: float = fighter.health
			fighter.take_damage(_damage,global_position,-1)
			if fighter.health < before: _hit_slots[fighter.slot_index] = true

func _platform_approach(target: Node2D, movement: float) -> float:
	if not is_on_floor(): return movement
	if target.global_position.y > global_position.y + 25:
		_try_drop()
	if target.global_position.y < global_position.y - 24:
		var next := target.global_position
		var platforms: Variant = _world.get("platforms")
		if platforms is Array and target.global_position.y < global_position.y - 52:
			var best := INF
			for platform: Array in platforms:
				if platform.size()<3: continue
				var height := global_position.y-float(platform[1])
				var point := Vector2(float(platform[0])+float(platform[2])*0.5,float(platform[1]))
				if height > 8 and height < 52 and point.distance_to(global_position)<best:
					best = point.distance_to(global_position)
					next = point
		var gap := next.x-global_position.x
		if absf(gap)<70 and _jump_cooldown==0:
			velocity.y=-400
			_jump_cooldown=45
		return signf(gap) if absf(gap)>8 else 0.0
	if is_on_wall() and _jump_cooldown==0:
		velocity.y=-400
		_jump_cooldown=45
	return movement

func _separation() -> float:
	var push := 0.0
	for enemy: Node2D in ArenaCombat.actors(_world,"enemies"):
		if not is_instance_valid(enemy) or enemy==self or enemy.dead: continue
		var gap := global_position.x-enemy.global_position.x
		if absf(gap)<26 and absf(global_position.y-enemy.global_position.y)<24:
			push += (1.0 if gap>0 or (is_zero_approx(gap) and spawn_id>enemy.spawn_id) else -1.0)*(26-absf(gap))*1.5
	return clampf(push,-45,45)

func _reserve() -> bool:
	if _reserved: return true
	var valid: Array[WeakRef] = []
	var count := 0
	for reference in _reservations:
		var enemy: ArenaEnemy = reference.get_ref() as ArenaEnemy
		if enemy != null and not enemy.dead and enemy._reserved:
			valid.append(reference)
			if enemy._world==_world: count+=1
	_reservations=valid
	var cap:=3 if ArenaCombat.actors(_world,"fighters").size()>1 else 2
	if count>=cap: return false
	_reserved=true
	_reservations.append(weakref(self))
	return true

func _release() -> void:
	_reserved=false
	# The static registry owns WeakRef objects, so retire those handles as well
	# as their enemy claims when a wave, fixture, or encounter leaves the tree.
	for index in range(_reservations.size() - 1, -1, -1):
		var enemy := _reservations[index].get_ref() as ArenaEnemy
		if enemy == null or enemy == self or enemy.dead or not enemy._reserved:
			_reservations.remove_at(index)

func _enter(state: String, ticks: int) -> void:
	_state=state
	_state_ticks=ticks
	if state not in ["windup","active"]: _release()
	if state=="windup": ArenaCombat.effect(_world,get_hurt_rect().get_center(),Color("#ffe4a1"),"enemy_warning")

func _try_drop() -> void:
	for index in get_slide_collision_count():
		var collision:=get_slide_collision(index)
		var body:=collision.get_collider() as PhysicsBody2D
		if body!=null and body.is_in_group("arena_one_way") and collision.get_normal().y < -0.5:
			_drop_body=body
			_drop_ticks=12
			add_collision_exception_with(body)
			position.y+=3
			velocity.y=60
			return

func _end_drop() -> void:
	if is_instance_valid(_drop_body): remove_collision_exception_with(_drop_body)
	_drop_body=null
	_drop_ticks=0

func _exit_tree() -> void:
	_release()
	_end_drop()

func _draw() -> void:
	var color: Color = ROLE_COLORS[role]
	if not boss_id.is_empty(): color={"warden":Color("#d6ac75"),"artillery":Color("#d390b8"),"tempest":Color("#84d9df"),"loom":Color("#c9a0e5")}[boss_id]
	if _elite: color=color.lightened(0.18)
	if _freeze>0: color=Color("#b4e7ff")
	if _texture!=null:
		var frame:=(_age/8)%4
		if _state=="windup": frame=4+(_age/6)%4
		elif _state=="active": frame=8+(_age/4)%4
		elif _state in ["recover","stagger"]: frame=12+(_age/8)%2
		elif dead: frame=14+mini(1,(24-_state_ticks)/12)
		var cell:=64 if not boss_id.is_empty() else 32
		var size:=Vector2(64,64) if not boss_id.is_empty() or role == "heavy" else Vector2(32,32)
		draw_texture_rect_region(_texture,Rect2(Vector2(-size.x*0.5,-size.y),size),Rect2((frame%4)*cell,(frame/4)*cell,cell,cell),Color("#b4e7ff") if _freeze > 0 else Color.WHITE)
	else:
		_draw_silhouette(color)
	if _state=="windup":
		draw_line(Vector2(_facing*18,-_size.y-8),Vector2(_facing*32,-_size.y-8),Color("#ffe9a6"),3)
		draw_circle(Vector2(0,-_size.y-9),3,Color("#ffe9a6"))
	if not _burns.is_empty(): draw_circle(Vector2(0,-_size.y-5),3,Color("#ef884a"))
	if not _marks.is_empty(): draw_arc(Vector2(0,-_size.y*0.5),_size.x*0.7,0,TAU,16,Color("#d2a2f0"),1)
	if health < max_health and not dead:
		draw_rect(Rect2(-_size.x*0.5,-_size.y-5,_size.x,2),Color("#302c39"))
		draw_rect(Rect2(-_size.x*0.5,-_size.y-5,_size.x*health/max_health,2),Color("#e6ba85"))

func _draw_silhouette(color: Color) -> void:
	var centre:=Vector2(0,-_size.y*0.5)
	var outline:=Color("#282635")
	if role=="flyer" or boss_id=="tempest":
		draw_colored_polygon(PackedVector2Array([centre+Vector2(-4,0),centre+Vector2(-27,-16),centre+Vector2(-18,9)]),color)
		draw_colored_polygon(PackedVector2Array([centre+Vector2(4,0),centre+Vector2(27,-16),centre+Vector2(18,9)]),color)
	if role=="swarm":
		draw_circle(centre,_size.x*0.7,outline)
		draw_circle(centre,_size.x*0.5,color)
		for side in [-1,1]:
			for y in 3: draw_line(centre+Vector2(side*5,y*4-4),centre+Vector2(side*13,y*5-5),color,2)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-_size.x*0.5,0),Vector2(-_size.x*0.4,-_size.y+10),Vector2(0,-_size.y),Vector2(_size.x*0.4,-_size.y+10),Vector2(_size.x*0.5,0)]),outline)
		draw_colored_polygon(PackedVector2Array([Vector2(-_size.x*0.35,-3),Vector2(-_size.x*0.25,-_size.y+12),Vector2(0,-_size.y+4),Vector2(_size.x*0.25,-_size.y+12),Vector2(_size.x*0.35,-3)]),color)
		if role=="charger" or boss_id=="warden":
			for side in [-1,1]: draw_line(Vector2(side*5,-_size.y+10),Vector2(side*15,-_size.y-3),Color("#f3d39b"),4)
		if role=="shooter" or boss_id=="artillery": draw_line(centre,centre+Vector2(_facing*30,-2),color.lightened(0.2),7)
		if role=="heavy": draw_rect(Rect2(_facing*6-10,-31,20,28),color.darkened(0.25))
		if boss_id=="loom":
			for angle in 6: draw_line(centre,centre+Vector2.from_angle(angle*TAU/6)*34,color.lightened(0.2),2)
	for eye in [-1,1]: draw_circle(Vector2(eye*4,-_size.y+13),2,Color("#fff0c6"))
