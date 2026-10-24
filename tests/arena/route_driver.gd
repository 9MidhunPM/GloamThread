extends Node
## Ordinary-input bot observation, not a human playtest or a fixture win.
## App/menu intents are explicit; gameplay changes only through InputRouter.
const Action := CommandSnapshot.Action
var app: ArenaApp
var session: ArenaRunSession
var report: Dictionary = {}
var captures: Array[String] = []
var _jump_holds := [0, 0]
var _last_health := [100.0, 100.0]
var _was_downed := [false, false]
var _tick := 0
var _wave_start := 0
var _wave_seen := 0
var _clear_seen := 0
var _combat_capture_seen := 0
var _damage := [0.0, 0.0]
var _downs := [0, 0]
var _purchases: Array[Dictionary] = []

func run(players: int = 1, waves: int = 20, capture_path: String = "", fighter_index: int = 0) -> Dictionary:
	report = {"input":"Synthetic owned keyboard snapshots; no actor position, health, damage, currency, timer, or progression writes.","menu":"Production App title/lobby/start, actual shop offers and purchase/ready methods.","human_playtest":false,"players":players,"target_waves":waves,"waves":[],"captures":captures,"errors":[],"success":false}
	report.bot = "State-aware bot reads target positions and attack phases, then uses normal move/jump/attack/special/dodge/revive commands. Random critical hits and shop rolls remain enabled."
	report.source_hashes = {}
	for path: String in ["res://scripts/arena/actors/arena_fighter.gd","res://scripts/arena/actors/arena_enemy.gd","res://scripts/arena/actors/arena_projectile.gd","res://scripts/arena/run_session.gd","res://scripts/arena/arena_player_state.gd","res://content/arena/catalog.json","res://tests/arena/route_driver.gd"]:
		report.source_hashes[path] = FileAccess.get_sha256(path)
	app = ArenaApp.new()
	var stamp := str(Time.get_ticks_usec())
	app.settings_store.path = "user://arena-route-settings-" + stamp + ".json"
	app.records.path = "user://arena-route-records-" + stamp + ".json"
	add_child(app)
	await _step()
	if app.screen != "title":
		report.errors.append("Actual arena App did not reach title.")
		return report
	for slot in 2:
		InputRouter.clear(slot)
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
	app._show_lobby(players)
	for index in fighter_index:
		app._cycle_character(0)
	app._begin_run()
	session = app.session
	if not is_instance_valid(session):
		report.errors.append("Actual lobby could not start a run.")
		return report
	report.kits = []
	report.selected_fighters = []
	for appearance: Dictionary in app.selected.slice(0, players):
		report.selected_fighters.append({"id": appearance.id, "manifest_sha256": FileAccess.get_sha256(appearance.manifest_path)})
	for fighter: ArenaFighter in session.fighters:
		report.kits.append(fighter.kit_id)
		_last_health[fighter.slot_index] = fighter.health
	while _tick < 600_000:
		_tick += 1
		if session.wave != _wave_seen:
			_wave_seen = session.wave
			_wave_start = _tick
			_damage = [0.0, 0.0]
			print("ARENA_ROUTE_WAVE ", session.wave, " kits=", report.kits)
		for fighter: ArenaFighter in session.fighters:
			var slot := fighter.slot_index
			if fighter.health < _last_health[slot]: _damage[slot] += _last_health[slot] - fighter.health
			if fighter.downed and not _was_downed[slot]: _downs[slot] += 1
			_last_health[slot] = fighter.health
			_was_downed[slot] = fighter.downed
			InputRouter.set_test_input(slot, _commands(fighter) if session.phase == "combat" else 0)
		if not capture_path.is_empty() and session.phase == "combat" and session.phase_ticks >= 300 and _combat_capture_seen != session.wave and (session.wave == 1 or session.wave % 5 == 0):
			_combat_capture_seen = session.wave
			await _capture(capture_path, "wave_%02d_combat" % session.wave)
		if session.phase == "clear" and _clear_seen != session.wave:
			_clear_seen = session.wave
			var record := {"wave":session.wave,"ticks":_tick - _wave_start,"health":[],"observed_health_loss":_damage.duplicate(),"boss":session.wave_record.get("boss", ""),"summary":session.summary()}
			for fighter: ArenaFighter in session.fighters: record.health.append(fighter.health)
			report.waves.append(record)
			print("ARENA_ROUTE_CLEAR ", JSON.stringify(record))
			if not capture_path.is_empty() and (session.wave % 5 == 0 or session.wave == 1):
				await _capture(capture_path, "wave_%02d_clear" % session.wave)
			if session.wave >= waves and waves < 20:
				report.success = true
				break
		elif session.phase == "shop":
			_shop()
		elif session.phase == "victory":
			if not capture_path.is_empty(): await _capture(capture_path, "victory")
			if waves <= 20:
				report.success = true
				break
			session.continue_endless()
		elif session.phase in ["defeat", "error"]:
			report.errors.append("Ordinary-input bot ended in %s at wave %d." % [session.phase, session.wave])
			break
		if session.endless and _clear_seen >= waves:
			report.success = true
			break
		if _tick - _wave_start > 18_000:
			report.errors.append("Bot exceeded 300 simulated seconds in wave %d." % session.wave)
			break
		await _step()
	if _tick >= 600_000: report.errors.append("Route exceeded its total simulation tick bound.")
	report.ticks = _tick
	report.final_phase = session.phase
	report.final_summary = session.summary()
	report.downs = _downs
	report.purchases = _purchases
	report.final_actors = []
	for fighter: ArenaFighter in session.fighters:
		report.final_actors.append({"slot":fighter.slot_index,"health":fighter.health,"max_health":fighter.max_health,"position":[fighter.position.x,fighter.position.y],"stats":fighter.stats.duplicate()})
	for slot in 2: InputRouter.set_test_input(slot, 0)
	return report

func _commands(fighter: ArenaFighter) -> int:
	var slot := fighter.slot_index
	if fighter.downed: return 0
	var target: Node2D
	var revive_target: ArenaFighter
	for peer: ArenaFighter in session.fighters:
		if peer != fighter and peer.downed: revive_target = peer
	var nearest := INF
	for enemy: ArenaEnemy in session.enemies:
		if enemy.dead: continue
		var distance := fighter.position.distance_squared_to(enemy.position)
		if distance < nearest:
			nearest = distance
			target = enemy
	if revive_target != null: target = revive_target
	if target == null: return 0
	var gap := target.position - fighter.position
	var direction := -1 if gap.x < 0 else 1
	var ranged := fighter.kit_id in ["nature", "frost"]
	var desired := 150.0 if ranged else 34.0
	if revive_target != null: desired = 22.0
	var movement := 0
	if absf(gap.x) > desired: movement = direction
	elif ranged and absf(gap.x) < 80 and revive_target == null:
		movement = -direction
		if (fighter.position.x < 55 and movement < 0) or (fighter.position.x > 585 and movement > 0): movement = direction
	var mask := Action.LEFT if movement < 0 else (Action.RIGHT if movement > 0 else 0)
	# Face a changed target through normal movement before beginning another swing.
	if direction != fighter.facing:
		mask = Action.LEFT if direction < 0 else Action.RIGHT
	elif absf(gap.y) < 40 and (absf(gap.x) < (300 if ranged else 56 * float(fighter.stats.area))):
		mask |= Action.ATTACK
		if fighter.special_ticks == 0 and (not ranged or absf(gap.x) < 90 or fighter.kit_id == "frost"):
			mask |= Action.SPECIAL
	if revive_target != null and gap.length() < 45:
		mask = Action.INTERACT | Action.ATTACK
	# Reach platforms by jumping; step off a current one-way with owned down+jump.
	if fighter.is_on_floor() and _jump_holds[slot] == 0:
		if gap.y > 26 and fighter.position.y < 319 and absf(gap.x) < 60:
			mask |= Action.DOWN | Action.JUMP
		elif gap.y < -24 and absf(gap.x) < 95:
			_jump_holds[slot] = 16
		elif _near_attack(fighter) and _tick % 3 == 0:
			_jump_holds[slot] = 16
	if _jump_holds[slot] > 0:
		mask |= Action.JUMP
		_jump_holds[slot] -= 1
	if fighter.dodge_cooldown == 0 and _near_attack(fighter) and fighter.position.y > target.position.y - 30:
		mask |= Action.DASH
	return mask

func _near_attack(fighter: ArenaFighter) -> bool:
	for enemy: ArenaEnemy in session.enemies:
		if enemy.dead or absf(enemy.position.y - fighter.position.y) > 60: continue
		if absf(enemy.position.x - fighter.position.x) > (135 if enemy.boss_id != "" else 75): continue
		var state := str(enemy.get("_state"))
		if state == "active" or (state == "windup" and int(enemy.get("_state_ticks")) <= 7): return true
	return false

func _shop() -> void:
	for slot in session.fighters.size():
		var fighter: ArenaFighter = session.fighters[slot]
		while fighter.health < fighter.max_health * 0.82 and session.player_states[slot].coins >= 5:
			if not bool(session.try_purchase(slot, "heal").ok): break
			_purchases.append({"after_wave":session.wave,"slot":slot,"id":"heal"})
		var offers: Array = session.shop_offers[slot].duplicate(true)
		offers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _upgrade_score(a) > _upgrade_score(b))
		for offer: Dictionary in offers:
			if int(offer.price) <= session.player_states[slot].coins and bool(session.try_purchase(slot, offer.id).ok):
				_purchases.append({"after_wave":session.wave,"slot":slot,"id":offer.id})
	for slot in session.fighters.size(): session.toggle_ready(slot)

func _upgrade_score(offer: Dictionary) -> float:
	return float({"damage":10,"lifesteal":9,"regen":8,"attack_speed":7,"area":6,"freeze":6,"burn":5,"projectile_count":5,"max_health":4,"chain":4,"special_cooldown":3,"pierce":3,"crit":2}.get(offer.stat, 1)) / float(offer.price)

func _step() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame

func _capture(directory: String, label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		report.errors.append("Could not create requested capture directory.")
		return
	await RenderingServer.frame_post_draw
	var path := directory.path_join(label + ".png")
	if get_viewport().get_texture().get_image().save_png(path) == OK: captures.append(path)
	else: report.errors.append("Could not write actual viewport capture: " + path)
