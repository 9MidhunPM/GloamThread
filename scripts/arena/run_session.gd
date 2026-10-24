class_name ArenaRunSession
extends Node2D
## The only owner of wave transitions, wallets, purchases and run outcomes.

signal phase_changed(value: String)
signal changed
signal notice(message: String)
signal enemy_paid(slot: int, amount: int)

var catalog: ArenaCatalog
var appearances: Array[Dictionary] = []
var player_states: Array[ArenaPlayerState] = []
var fighters: Array = []
var enemies: Array = []
var enemy_textures: Dictionary = {}
var platforms: Array = []
var combat_root: Node2D
var effect_root: Node2D
var terrain_root: Node2D
var backdrop: ArenaBackdrop
var phase: String = "loading"
var wave: int = 0
var stage: int = 0
var phase_ticks: int = 0
var elapsed_ticks: int = 0
var combo: int = 0
var combo_ticks: int = 0
var best_combo: int = 0
var shake_ticks: int = 0
var reduced_flash: bool = false
var reduced_shake: bool = false
var endless: bool = false
var shop_offers: Array[Array] = []
var shop_ready: Array[bool] = []
var rerolled: Array[bool] = []
var purchase_message: String = ""
var wave_record: Dictionary = {}
var spawn_queue: Array[Dictionary] = []
var telegraphs: Array[Dictionary] = []
var director := WaveDirector.new()
var rng := RandomNumberGenerator.new()
var font: Font
var _paid: Dictionary = {}
var _spawn_serial: int = 0
var _spawn_ticks: int = 0
var _revive_ticks: Dictionary = {}
var _damaged: Dictionary = {}


func configure(data: ArenaCatalog, bundles: Array[Dictionary], seed_value: int = 0) -> void:
	catalog = data
	appearances = bundles.duplicate()
	rng.seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	director.catalog = catalog
	director.roster_size = appearances.size()
	for i in appearances.size():
		var state := ArenaPlayerState.new()
		state.slot_index = i
		state.kit_id = str(appearances[i].get("kit_id", "ember"))
		player_states.append(state)
		shop_offers.append([])
		shop_ready.append(false)
		rerolled.append(false)


func _ready() -> void:
	process_physics_priority = 100
	if catalog == null or not catalog.errors.is_empty() or appearances.size() not in [1, 2]:
		_set_phase("error")
		return
	backdrop = ArenaBackdrop.new()
	add_child(backdrop)
	terrain_root = Node2D.new()
	terrain_root.name = "Terrain"
	add_child(terrain_root)
	combat_root = Node2D.new()
	combat_root.name = "Combat"
	add_child(combat_root)
	effect_root = Node2D.new()
	effect_root.name = "Effects"
	effect_root.z_index = 20
	add_child(effect_root)
	for slot in appearances.size():
		var fighter := ArenaFighter.new()
		fighter.name = "Player%d" % (slot + 1)
		fighter.position = Vector2(270 + 100 * slot, 320)
		fighter.setup(slot, player_states[slot].kit_id, self, appearances[slot])
		combat_root.add_child(fighter)
		fighters.append(fighter)
		fighter.apply_stats(player_states[slot].stats())
		fighter.health = fighter.max_health
	_load_enemy_art()
	_next_wave()


func _set_phase(value: String) -> void:
	phase = value
	phase_ticks = 0
	InputRouter.flush()
	phase_changed.emit(value)
	changed.emit()


func _physics_process(_delta: float) -> void:
	phase_ticks += 1
	shake_ticks = maxi(0, shake_ticks - 1)
	if phase == "countdown":
		if phase_ticks >= 150:
			_set_phase("combat")
		return
	if phase == "clear":
		if phase_ticks >= 75:
			if wave == 20 and not endless:
				_set_phase("victory")
			else:
				_open_shop()
		return
	if phase != "combat":
		return
	elapsed_ticks += 1
	combo_ticks = maxi(0, combo_ticks - 1)
	if combo_ticks == 0:
		combo = 0
	_process_spawns()
	_process_revives()
	# Actors update at priority0. Resolve completion after all accepted damage.
	if spawn_queue.is_empty() and telegraphs.is_empty() and living_enemies() == 0:
		_clear_wave()
	elif not fighters.any(func(f: Node) -> bool: return is_instance_valid(f) and not f.downed):
		_set_phase("defeat")
	_damaged.clear()
	queue_redraw()


func _next_wave() -> void:
	wave += 1
	stage = ((wave - 1) / 5) % 4
	wave_record = director.definition(wave)
	for slot in fighters.size():
		fighters[slot].reset_for_wave(Vector2(270 + slot * 100, 320))
	_build_arena()
	spawn_queue.clear()
	telegraphs.clear()
	_paid.clear()
	for enemy: Node in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	for child: Node in combat_root.get_children():
		if child not in fighters:
			child.queue_free()
	if wave_record.get("boss", "") != "":
		spawn_queue.append({"role": "heavy", "boss": wave_record.boss, "elite": false})
	var roles: Array = wave_record.get("enemies", ["chaser"])
	for i in int(wave_record.get("count", 8)):
		spawn_queue.append({"role": roles[i % roles.size()], "boss": "", "elite": int(wave_record.get("elite_every", 0)) > 0 and (i + 1) % int(wave_record.elite_every) == 0})
	_spawn_ticks = 1
	_revive_ticks.clear()
	_set_phase("countdown")
	AudioDirector.play_music("arena_boss" if wave_record.get("boss", "") != "" else "arena")


func _build_arena() -> void:
	for child in terrain_root.get_children():
		child.free()
	var arena: Dictionary = catalog.arenas[stage]
	platforms = arena.platforms
	backdrop.appearance = appearances[stage % appearances.size()]
	backdrop.platforms = arena.platforms
	backdrop.stage = stage
	backdrop.queue_redraw()
	_body(Rect2(16, 320, 608, 80))
	_body(Rect2(-24, -64, 40, 464))
	_body(Rect2(624, -64, 40, 464))
	for platform: Array in arena.platforms:
		_body(Rect2(float(platform[0]), float(platform[1]), float(platform[2]), 8), true)


func _body(rect: Rect2, one_way: bool = false) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.one_way_collision = one_way
	shape.one_way_collision_margin = 3.0
	body.add_child(shape)
	if one_way:
		body.add_to_group("arena_one_way")
	terrain_root.add_child(body)


func _process_spawns() -> void:
	for i in range(telegraphs.size() - 1, -1, -1):
		telegraphs[i].ticks = int(telegraphs[i].ticks) - 1
		if int(telegraphs[i].ticks) <= 0:
			_spawn_enemy(telegraphs[i])
			telegraphs.remove_at(i)
	_spawn_ticks -= 1
	if _spawn_ticks > 0 or spawn_queue.is_empty() or living_enemies() + telegraphs.size() >= director.live_cap(wave):
		return
	var record: Dictionary = spawn_queue.pop_front()
	var x := 44.0 if (_spawn_serial + telegraphs.size()) % 2 == 0 else 596.0
	# Prefer the farther gate when one player is camping an entrance.
	var left_distance := INF
	var right_distance := INF
	for fighter: Node2D in fighters:
		if not fighter.downed:
			left_distance = minf(left_distance, absf(fighter.position.x - 44))
			right_distance = minf(right_distance, absf(fighter.position.x - 596))
	if (left_distance < 70 and x == 44) or (right_distance < 70 and x == 596):
		x = 596 if x == 44 else 44
	record.position = Vector2(x, 200 if record.role == "flyer" else 320)
	record.ticks = 42
	telegraphs.append(record)
	_spawn_ticks = int(wave_record.get("interval_ticks", 30))


func _spawn_enemy(record: Dictionary) -> void:
	_spawn_serial += 1
	var enemy := ArenaEnemy.new()
	enemy.name = "Enemy%d" % _spawn_serial
	enemy.position = record.position
	enemy.setup(str(record.role), self, _spawn_serial, wave, bool(record.elite), str(record.boss))
	enemy.defeated.connect(_on_enemy_defeated)
	combat_root.add_child(enemy)
	enemies.append(enemy)


func living_enemies() -> int:
	var count := 0
	for enemy: Node in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			count += 1
	return count


func _on_enemy_defeated(enemy: Node2D, source_slot: int) -> void:
	enemies.erase(enemy)
	if phase != "combat" or _paid.has(enemy.spawn_id):
		return
	_paid[enemy.spawn_id] = true
	if source_slot >= 0 and source_slot < player_states.size():
		var amount := 15 if not str(enemy.boss_id).is_empty() else (4 if bool(enemy.get("elite")) else 1)
		player_states[source_slot].coins += amount
		player_states[source_slot].kills += 1
		combo += 1
		combo_ticks = 150
		best_combo = maxi(best_combo, combo)
		var payout := effect(enemy.position - Vector2(0, 28), Color("ffd985"), "coin")
		if payout != null:
			payout.text_value = "+%d" % amount
		var trail := effect(enemy.position - Vector2(0, 15), Color("ffd985"), "trail")
		if trail != null:
			trail.target = fighters[source_slot].position - Vector2(0, 30)
		enemy_paid.emit(source_slot, amount)
		AudioDirector.play_cue(&"coin")
		if combo > 0 and combo % 10 == 0:
			AudioDirector.play_cue(&"combo")
	shake_ticks = 3 if not reduced_shake else 0
	changed.emit()


func hit_enemies(rect: Rect2, damage: float, slot: int, attack_id: int, tags: Dictionary) -> int:
	if phase != "combat" or slot < 0 or slot >= fighters.size():
		return 0
	var count := 0
	for enemy: Node2D in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead or not rect.intersects(enemy.get_hurt_rect()):
			continue
		var query := PhysicsRayQueryParameters2D.create(fighters[slot].get_hurt_rect().get_center(), enemy.get_hurt_rect().get_center(), 1)
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			continue
		var value := damage
		var accepted: bool = enemy.take_damage(value, slot, attack_id, tags)
		if accepted:
			count += 1
			var pop := effect(enemy.position - Vector2(rng.randf_range(-5, 5), 28), Color("fff0c2"), "damage")
			if pop != null:
				pop.text_value = str(roundi(value))
	if count > 0:
		AudioDirector.play_cue(&"hit")
		shake_ticks = maxi(shake_ticks, 2 if not reduced_shake else 0)
	return count


func spawn_projectile(at: Vector2, direction: Vector2, damage: float, slot: int, tags: Dictionary) -> void:
	if phase != "combat" or not is_instance_valid(combat_root):
		return
	var count := 0
	for child: Node in combat_root.get_children():
		if child is ArenaProjectile:
			count += 1
	if count >= 100:
		return
	var projectile := ArenaProjectile.new()
	projectile.setup(self, at, direction, damage, slot, tags)
	combat_root.add_child(projectile)


func effect(at: Vector2, color: Color, kind: String = "burst") -> ArenaEffect:
	if not is_instance_valid(effect_root) or effect_root.get_child_count() >= 100:
		return null
	var spark := ArenaEffect.new()
	spark.position = at
	spark.tint = color
	spark.kind = kind
	if kind.contains("_special") or kind.contains("_strike"):
		var nearest_distance := INF
		for fighter: Node2D in fighters:
			if kind.begins_with(str(fighter.kit_id) + "_") and fighter.position.distance_squared_to(at) < nearest_distance:
				nearest_distance = fighter.position.distance_squared_to(at)
				spark.direction = float(fighter.facing)
	spark.font = font
	spark.reduced_flash = reduced_flash
	spark.lifetime = 42 if kind in ["coin", "damage", "trail"] else 20
	effect_root.add_child(spark)
	return spark


func on_fighter_hit(slot: int) -> void:
	_damaged[slot] = true
	shake_ticks = 8 if not reduced_shake else 0
	AudioDirector.play_cue(&"hurt")
	changed.emit()


func _process_revives() -> void:
	if fighters.size() != 2:
		return
	for slot in fighters.size():
		var downed: Node2D = fighters[slot]
		var rescuer: Node2D = fighters[1 - slot]
		if not downed.downed:
			_revive_ticks[slot] = 0
			continue
		var can: bool = not rescuer.downed and rescuer.position.distance_to(downed.position) < 55 and not _damaged.has(1 - slot) and InputRouter.snapshot(1 - slot).is_held(CommandSnapshot.Action.INTERACT)
		_revive_ticks[slot] = int(_revive_ticks.get(slot, 0)) + 1 if can else 0
		if int(_revive_ticks[slot]) >= 90:
			downed.revive()
			effect(downed.position - Vector2(0, 20), Color("9cf5bd"), "special")
			AudioDirector.play_cue(&"revive")
			_revive_ticks[slot] = 0
			changed.emit()


func revive_fraction(slot: int) -> float:
	return float(_revive_ticks.get(slot, 0)) / 90.0


func _clear_wave() -> void:
	var bonus := 8 + 2 * ((wave - 1) / 5)
	for slot in player_states.size():
		player_states[slot].coins += bonus
		if fighters[slot].downed:
			fighters[slot].revive()
		fighters[slot].health = minf(fighters[slot].max_health, fighters[slot].health + fighters[slot].max_health * 0.08)
	_set_phase("clear")
	AudioDirector.play_cue(&"wave_clear")


func _open_shop() -> void:
	for slot in player_states.size():
		shop_ready[slot] = false
		rerolled[slot] = false
		shop_offers[slot] = _roll_offers(slot)
	_set_phase("shop")
	AudioDirector.play_music("shop")


func _roll_offers(slot: int) -> Array:
	var result: Array = []
	var state := player_states[slot]
	for family: String in [state.kit_id, "any"]:
		var candidates: Array[Dictionary] = []
		for record: Dictionary in catalog.upgrades:
			if record.stat == "projectile_count" and state.kit_id not in ["frost", "nature", "shadow"]:
				continue
			if record.kit == family and state.rank(record.id) < int(record.max_rank):
				candidates.append(record)
		for _i in 2:
			if candidates.is_empty():
				break
			var chosen := rng.randi_range(0, candidates.size() - 1)
			var offer: Dictionary = candidates[chosen].duplicate(true)
			offer.price = int(offer.price) * (state.rank(offer.id) + 1)
			offer.rank = state.rank(offer.id) + 1
			result.append(offer)
			candidates.remove_at(chosen)
	return result


func try_purchase(slot: int, offer_id: String) -> Dictionary:
	purchase_message = ""
	if phase != "shop" or slot < 0 or slot >= player_states.size() or shop_ready[slot]:
		return {"ok": false, "message": "Unready your panel before shopping."}
	var state := player_states[slot]
	if offer_id == "heal":
		if state.coins < 5 or fighters[slot].health >= fighters[slot].max_health:
			return {"ok": false, "message": "Healing needs 5 coins and missing health."}
		state.coins -= 5
		state.spent += 5
		fighters[slot].health = minf(fighters[slot].max_health, fighters[slot].health + fighters[slot].max_health * 0.35)
	else:
		var selected := -1
		for i in shop_offers[slot].size():
			if shop_offers[slot][i].id == offer_id:
				selected = i
		if selected < 0:
			return {"ok": false, "message": "That offer is no longer available."}
		var record: Dictionary = shop_offers[slot][selected]
		if state.coins < int(record.price) or state.rank(record.id) >= int(record.max_rank):
			return {"ok": false, "message": "Not enough coins, or upgrade already mastered."}
		var old_max: float = fighters[slot].max_health
		state.coins -= int(record.price)
		state.spent += int(record.price)
		state.apply_upgrade(record)
		fighters[slot].apply_stats(state.stats(), maxf(0, float(state.stats().max_health) - old_max))
		shop_offers[slot].remove_at(selected)
	AudioDirector.play_cue(&"purchase")
	changed.emit()
	return {"ok": true, "message": "Upgrade woven."}


func reroll(slot: int) -> bool:
	if phase != "shop" or slot < 0 or slot >= player_states.size() or rerolled[slot] or shop_ready[slot]:
		return false
	rerolled[slot] = true
	shop_offers[slot] = _roll_offers(slot)
	changed.emit()
	return true


func toggle_ready(slot: int) -> void:
	if phase != "shop" or slot < 0 or slot >= shop_ready.size():
		return
	shop_ready[slot] = not shop_ready[slot]
	AudioDirector.play_cue(&"ready")
	changed.emit()
	if not shop_ready.has(false):
		_next_wave()


func continue_endless() -> void:
	if phase == "victory":
		endless = true
		_open_shop()


func summary() -> Dictionary:
	var records: Array = []
	for state in player_states:
		records.append({"kit": state.kit_id, "kills": state.kills, "coins": state.coins, "spent": state.spent, "upgrades": state.levels.duplicate()})
	return {"wave": wave, "won": phase == "victory", "endless": endless, "seconds": roundi(elapsed_ticks / 60.0), "best_combo": best_combo, "players": records}


func _load_enemy_art() -> void:
	var path := "res://assets/arena/enemies/index.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return
	var mapping: Dictionary = parsed.get("assets", {})
	for role: String in mapping:
		var record: Variant = mapping[role]
		if record is Dictionary and role in ArenaCatalog.ROLES + ArenaCatalog.BOSSES and record.get("file") is String and str(record.file).get_file() == str(record.file):
			var image_path := path.get_base_dir().path_join(str(record.file))
			if FileAccess.get_sha256(image_path) != str(record.get("sha256", "")):
				continue
			var image := Image.new()
			if image.load_png_from_buffer(FileAccess.get_file_as_bytes(image_path)) == OK and not image.is_empty():
				enemy_textures[role] = ImageTexture.create_from_image(image)


func _draw() -> void:
	for spawn: Dictionary in telegraphs:
		var at: Vector2 = spawn.position
		var color := Color("ffd080") if spawn.boss == "" else Color("ff7d91")
		draw_arc(at - Vector2(0, 4), 12 + (42 - int(spawn.ticks)) * 0.15, PI, TAU, 12, Color(color, 0.8), 2)
		draw_line(at - Vector2(0, 12), at - Vector2(0, 44), Color(color, 0.6), 1)
