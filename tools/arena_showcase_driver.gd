extends "res://tests/arena/route_driver.gd"
## Watchable adapter. The ordinary route remains unchanged without staging.

var chapter: Dictionary = {}
var cancelled: bool = false
var peak_enemies: int = 0
var seen_roles: Dictionary = {}

func _prepare_session() -> void:
	if chapter.is_empty():
		return
	var start_wave := int(chapter.wave)
	var regions := mini(4, 1 + (start_wave - 1) / 5)
	session.map.expand_to(regions)
	if not session._build_arena():
		return
	# These are explicitly staged highlights, never normal-run test evidence.
	var ranks := mini(3, start_wave / 5)
	for slot in session.player_states.size():
		var state: ArenaPlayerState = session.player_states[slot]
		for upgrade: Dictionary in session.catalog.upgrades:
			if upgrade.kit not in ["any", state.kit_id] or upgrade.stat == "thorns":
				continue
			if upgrade.stat == "projectile_count" and state.kit_id not in ["nature", "frost", "shadow"]:
				continue
			for rank in mini(ranks, int(upgrade.max_rank)):
				state.apply_upgrade(upgrade)
		var fighter: ArenaFighter = session.fighters[slot]
		fighter.apply_stats(state.stats())
		fighter.position = session.safe_position(Vector2((regions - 1) * 2560 + 270 + 100 * slot, 320))
		fighter.health = fighter.max_health
	session.wave = start_wave - 1
	session.endless = start_wave > 20
	session._next_wave()
	app.presentation._snap = true
	app.presentation._update_cameras(0)
	if bool(chapter.get("crowd", false)):
		_seed_crowd()
	report.input = "Synthetic owned keyboard combat after explicitly staged wave, legal upgrade presets and starting positions; no invulnerability or combat health refills."
	report.staging = {"wave_jump": start_wave, "preset_upgrade_ranks": ranks, "crowd_fixture": bool(chapter.get("crowd", false)), "invulnerability": false}

func _seed_crowd() -> void:
	# Fill the regular32-enemy co-op cap through visible warning markers. Every
	# actor still runs production AI/combat/damage; no enlarged cap or god mode.
	var points: Array[Vector2] = []
	var centre: Vector2 = session.fighters[0].position
	for offset in range(-600, 721, 40):
		var point: Vector2 = session.safe_position(centre + Vector2(offset, 0))
		if absf(point.y - centre.y) <= 96 and session._spawn_clear(point, false):
			points.append(point)
	if points.is_empty():
		report.errors.append("Crowd fixture has no safe warning positions.")
		return
	var roles := ["swarm", "chaser", "charger", "shooter", "flyer", "heavy"]
	session.spawn_queue.clear()
	session.telegraphs.clear()
	session.wave_record.boss = ""
	session.wave_record.count = 64
	for index in 64:
		var role: String = roles[index % roles.size()]
		var record := {"role": role, "boss": "", "elite": index % 8 == 7}
		if index < session.director.live_cap(session.wave):
			var at := points[index % points.size()]
			if role == "flyer": at -= Vector2(0, 80)
			record.position = at
			record.ticks = 24 + (index / 6) * 6
			record.duration = record.ticks
			session.telegraphs.append(record)
		else:
			session.spawn_queue.append(record)

func _commands(fighter: ArenaFighter) -> int:
	var mask: int = super._commands(fighter)
	if bool(chapter.get("crowd", false)) and session.phase_ticks < 180:
		# Briefly dodge before attacking so the crowd can build on camera.
		mask &= ~(Action.ATTACK | Action.SPECIAL)
	return mask

func _shop() -> void:
	# Let viewers read the real personal panels before the standard bot buys.
	if session.phase_ticks < 150:
		return
	super._shop()

func _should_stop() -> bool:
	return cancelled

func _step() -> void:
	await super._step()
	while get_tree().paused and not cancelled:
		await get_tree().process_frame
	if is_instance_valid(session):
		peak_enemies = maxi(peak_enemies, session.living_enemies())
		for enemy: ArenaEnemy in session.enemies:
			if not enemy.dead: seen_roles[enemy.role] = true
