extends Scenario
## Controlled real-session fixture. Full ordinary-input runs are separate evidence.

const Presentation = preload("res://scripts/arena/arena_presentation.gd")
var world: ArenaRunSession
var presentation: Variant


func run() -> void:
	var catalog := ArenaCatalog.load_catalog()
	var bundles := FighterLibrary.new().list_bundles()
	assert_true(catalog.errors.is_empty() and bundles.size() >= 2, "real runtime content is admitted before world checks")
	if not catalog.errors.is_empty() or bundles.size() < 2:
		return
	AudioDirector.register_bundle(AssetCatalog.load_from_path("res://assets/manifest.json"))
	assert_true(ArenaAudio.register_original().is_empty(), "original arena audio is available")
	for slot in 2:
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
	world = ArenaRunSession.new()
	world.configure(catalog, [bundles[0], bundles[1]], 18427)
	presentation = Presentation.new()
	world.presentation = presentation
	presentation.setup(world)
	add_child(presentation)
	await ticks(2)
	assert_true(world.map != null and world.map.errors.is_empty(), "real session builds a valid generated map")
	if world.map == null or not world.map.errors.is_empty():
		return
	# Isolate transaction/catch-up boundaries from ordinary encounter damage. All
	# geometry, actors, physics queries and entry points below are production code.
	world.set_physics_process(false)
	for fighter: ArenaFighter in world.fighters:
		fighter.set_physics_process(false)
	await _check_expansion_and_shops()
	_check_shared_loot()
	await _check_spawns_and_pursuit()
	presentation.free()
	presentation = null


func _check_expansion_and_shops() -> void:
	assert_eq(world.map.chunks.size(), 4, "a new session begins with four explorable chunks")
	assert_eq(world.world_bounds(), Rect2(0, 0, 2560, 720), "initial world is four screens wide and two screens tall")
	var first_chunks: Array = world.map.chunks.duplicate(true)
	var original_bodies: Array[int] = []
	for body: Node in world.terrain_root.get_children():
		if body is StaticBody2D:
			original_bodies.append(body.get_instance_id())
	for slot in 2:
		world.fighters[slot].position = world.safe_position(Vector2(1100 + slot * 120, 320))
	var positions := [world.fighters[0].position, world.fighters[1].position]
	world._next_wave()
	assert_eq(world.fighters[0].position, positions[0], "next wave retains P1 exploration position beyond the old arena")
	assert_eq(world.fighters[1].position, positions[1], "next wave retains P2 exploration position beyond the old arena")
	assert_eq(world.map.chunks, first_chunks, "ordinary wave transition never replaces existing geometry")
	for gate in [5, 10, 15]:
		world.wave = gate
		world._open_shop()
		assert_eq(world.map.chunks.size(), (gate / 5 + 1) * 4, "clearing stage %d appends exactly four chunks" % (gate / 5))
		assert_eq(world.map.chunks.slice(0, 4), first_chunks, "stage expansion preserves all original chunk records")
		assert_eq(world.fighters[0].position, positions[0], "stage expansion never teleports P1")
		assert_eq(world.fighters[1].position, positions[1], "stage expansion never teleports P2")
	for identity in original_bodies:
		assert_true(is_instance_valid(instance_from_id(identity)), "old collision body survives append-only expansion")
	assert_eq(world.loot_nodes.size(), 24, "six unique discoveries per region are instantiated once")
	world._build_arena()
	assert_eq(world.loot_nodes.size(), 24, "reapplying chunk integration does not duplicate shared loot")
	assert_true(not world.movement_allowed(0) and not world.movement_allowed(1), "initial personal shop panels each freeze their own movement")
	world.set_shop_open(0, false)
	assert_true(world.movement_allowed(0) and not world.movement_allowed(1), "one player explores while the other shops")
	assert_true(not world.shop_ready[0], "closing a panel to explore is not a ready vote")
	world.toggle_ready(0)
	assert_true(world.shop_ready[0] and world.movement_allowed(0) and world.phase == "shop", "ready player can explore while waiting for their partner")
	world.set_shop_open(0, true)
	assert_true(not world.shop_ready[0] and not world.movement_allowed(0), "reopening a shop clears only that player's ready vote")
	world.set_shop_open(0, false)
	world.toggle_ready(0)
	var before := world.wave
	world.toggle_ready(1)
	assert_eq(world.wave, before + 1, "the final owned ready vote advances exactly one wave")
	assert_eq(world.phase, "countdown", "both ready leave the free intermission")
	world.toggle_ready(0)
	world.toggle_ready(1)
	assert_eq(world.wave, before + 1, "stale ready callbacks cannot advance again outside the intermission")
	assert_true(world.movement_allowed(0) and world.movement_allowed(1), "countdown allows both players to traverse")
	assert_eq(world.map.chunks.size(), 16, "later waves retain the expanded sixteen-chunk region")
	await ticks(2)


func _check_shared_loot() -> void:
	world.phase = "shop"
	world.shop_open = [false, false]
	var cache: Node2D
	var plant: Node2D
	for loot: Node2D in world.loot_nodes:
		if cache == null and loot.record.kind == "cache":
			cache = loot
		if plant == null and loot.record.kind == "plant":
			plant = loot
	assert_true(cache != null and plant != null, "region contains attackable cache and collector-heal plant")
	if cache == null or plant == null:
		return
	world.fighters[0].position = cache.position + Vector2(36, 0)
	var coins := [world.player_states[0].coins, world.player_states[1].coins]
	var hits := world.hit_enemies(cache.get_hurt_rect(), 12, 0, 73001, {})
	assert_eq(hits, 1, "an actual clear melee query opens a cache during exploration")
	assert_eq(world.player_states[0].coins, coins[0] + 3, "cache gives the attacker three coins")
	assert_eq(world.player_states[1].coins, coins[1] + 3, "same cache gives the partner three coins once")
	assert_true(world.collected.has(cache.record.id), "shared session commits stable cache identity")
	world.hit_enemies(cache.get_hurt_rect(), 12, 1, 73002, {})
	assert_eq(world.player_states[0].coins, coins[0] + 3, "repeated/partner attacks never duplicate cache reward")
	assert_eq(world.player_states[1].coins, coins[1] + 3, "the second wallet is also protected from duplicate cache reward")
	world.fighters[0].health = world.fighters[0].max_health
	assert_true(not world.collect_loot(str(plant.record.id), 0), "a full-health collector leaves a heal plant available")
	world.fighters[1].health = world.fighters[1].max_health * 0.4
	world.fighters[1].position = plant.position
	var health := [world.fighters[0].health, world.fighters[1].health]
	world._process_discoveries()
	assert_eq(world.fighters[1].health, health[1] + world.fighters[1].max_health * 0.2, "nearby injured collector receives exactly twenty percent maximum health")
	assert_eq(world.fighters[0].health, health[0], "collector heal does not heal the other player")
	world._process_discoveries()
	assert_eq(world.fighters[1].health, health[1] + world.fighters[1].max_health * 0.2, "collected plant cannot heal twice")
	assert_true(world.collected.has(plant.record.id), "plant reward shares one stable discovery state")
	world._build_arena()
	assert_true(cache.collected and plant.collected and world.loot_nodes.size() == 24, "chunk reintegration retains collected nodes without respawning rewards")


func _check_spawns_and_pursuit() -> void:
	_clear_enemies()
	world.phase = "combat"
	world.wave = 25
	world.wave_record = world.director.definition(world.wave)
	world.wave_record.interval_ticks = 1
	for slot in 2:
		world.fighters[slot].position = world.safe_position(Vector2(8200 + slot * 120, 320))
	presentation._snap = true
	presentation._update_cameras(0.0)
	await ticks(2)
	for number in 64:
		world.spawn_queue.append({"role": "chaser", "boss": "", "elite": false})
	world._spawn_ticks = 1
	var maximum := 0
	for tick in 220:
		world._process_spawns()
		for enemy: ArenaEnemy in world.enemies:
			enemy.set_physics_process(false)
		maximum = maxi(maximum, world.living_enemies() + _pending_spawns())
	assert_eq(world.living_enemies(), 32, "real director fills the single team-wide thirty-two enemy cap")
	assert_true(maximum <= 32, "pending telegraphs and live actors never exceed the team cap")
	var identities: Dictionary = {}
	for enemy: ArenaEnemy in world.enemies:
		identities[enemy.spawn_id] = true
		assert_true(enemy.position.x > 640, "world-relative spawn reaches the explored distant region")
		for fighter: ArenaFighter in world.fighters:
			assert_true(enemy.position.distance_to(fighter.position) >= 96, "arrived enemy keeps approved player spawn clearance")
	assert_eq(identities.size(), 32, "each arrival owns a unique gameplay identity across the shared views")
	var enemy: ArenaEnemy = world.enemies[0]
	enemy.position = world.safe_position(Vector2(1100, 320))
	assert_true(enemy.take_damage(7, 1, 73100, {"burn": 1, "freeze": 1}), "a damaged distant enemy keeps its real source/status data")
	var identity := enemy.get_instance_id()
	var spawn_id := enemy.spawn_id
	var health := enemy.health
	var burns: Dictionary = enemy._burns.duplicate(true)
	var freeze := enemy._freeze
	for tick in 179:
		world._process_pursuit()
	assert_eq(_pending_relocations(), 0, "ordinary pursuit waits all one hundred eighty unseen ticks")
	world._process_pursuit()
	assert_eq(_pending_relocations(), 1, "distant unseen enemy creates one relocation telegraph")
	for tick in 60:
		world._process_pursuit()
	assert_eq(_pending_relocations(), 1, "repeated pursuit scans cannot duplicate an enemy's warning")
	for tick in 42:
		world._process_spawns()
	assert_eq(enemy.get_instance_id(), identity, "catch-up moves the original node")
	assert_eq(enemy.spawn_id, spawn_id, "catch-up retains reward identity")
	assert_eq(enemy.health, health, "catch-up preserves remaining health")
	assert_eq(enemy._burns, burns, "catch-up preserves damage-over-time source ownership")
	assert_eq(enemy._freeze, freeze, "catch-up preserves status timers")
	assert_true(enemy.position.x > 640 and enemy.position.distance_to(world.fighters[0].position) < 900, "catch-up reaches a nearby valid anchor in the explored region")
	assert_eq(world.living_enemies(), 32, "relocation at the live cap does not create a thirty-third enemy")
	assert_true(not world._paid.has(spawn_id), "relocation does not pay a kill reward")
	world.spawn_queue.clear()
	world.telegraphs.clear()
	var wallet := [world.player_states[0].coins, world.player_states[1].coins]
	assert_true(enemy.take_damage(100000, 1, 73101), "relocated enemy can be killed normally")
	world._on_enemy_defeated(enemy, 0)
	assert_eq(world.player_states[1].coins, wallet[1] + 1, "relocated enemy pays the lethal slot exactly once")
	assert_eq(world.player_states[0].coins, wallet[0], "duplicate callback cannot pay the partner")
	_clear_enemies()
	# A player may move toward a telegraph while it is counting down. Admission
	# must enforce the same 96px rule again when the actual actor is created.
	var arrival := world.safe_position(Vector2(8400, 320))
	world.fighters[0].position = arrival + Vector2(80, 0)
	world.fighters[1].position = arrival + Vector2(500, 0)
	world.telegraphs.append({"role": "chaser", "boss": "", "elite": false, "position": arrival, "ticks": 1})
	world._process_spawns()
	assert_eq(world.living_enemies(), 0, "arrival is postponed when a player enters the ninety-six pixel clearance radius")
	world.telegraphs.clear()
	await _check_cancelled_pursuit()


func _check_cancelled_pursuit() -> void:
	world.fighters[0].position = world.safe_position(Vector2(8200, 320))
	world.fighters[1].position = world.safe_position(Vector2(8320, 320))
	presentation.force_split = false
	presentation._snap = true
	presentation._update_cameras(0.0)
	world._spawn_enemy({"role": "heavy", "boss": "warden", "elite": false, "position": world.safe_position(Vector2(1000, 320))})
	var boss: ArenaEnemy = world.enemies[0]
	boss.set_physics_process(false)
	for tick in 299:
		world._process_pursuit()
	assert_eq(_pending_relocations(), 0, "boss pursuit waits three hundred unseen ticks")
	world._process_pursuit()
	assert_eq(_pending_relocations(), 1, "boss receives one longer warning")
	assert_eq(int(world.telegraphs[0].duration), 90, "boss catch-up visibly warns for ninety ticks")
	var wallet: int = world.player_states[0].coins
	boss.set_physics_process(true)
	boss.take_damage(100000, 0, 73200)
	await ticks(30)
	assert_true(not is_instance_valid(boss), "normal death animation frees the boss before its longer warning would expire")
	for tick in 90:
		world._process_spawns()
	assert_eq(world.living_enemies(), 0, "a boss killed during its warning is never resurrected")
	assert_eq(_pending_relocations(), 0, "dead boss warning retires without creating another actor")
	assert_eq(world.player_states[0].coins, wallet + 15, "cancelled boss pursuit still has exactly one boss payout")
	_clear_enemies()
	world._spawn_enemy({"role": "chaser", "boss": "", "elite": false, "position": world.safe_position(Vector2(1000, 320))})
	var enemy: ArenaEnemy = world.enemies[0]
	enemy.set_physics_process(false)
	for tick in 180:
		world._process_pursuit()
	assert_eq(_pending_relocations(), 1, "ordinary unseen enemy has a warning before visibility cancellation")
	var original := enemy.position
	world.fighters[0].position = original + Vector2(60, 0)
	presentation.force_split = true
	await ticks(1)
	assert_true(world._enemy_visible(enemy), "one split camera can reveal an enemy while the other player stays distant")
	world._process_pursuit()
	assert_eq(_pending_relocations(), 0, "revealing a target immediately cancels its pending pursuit warning")
	world.fighters[0].position = world.safe_position(Vector2(8200, 320))
	presentation._snap = true
	presentation._update_cameras(0.0)
	for tick in 42:
		world._process_spawns()
		world._process_pursuit()
	assert_eq(enemy.position, original, "an enemy revealed during its warning is not teleported")
	assert_eq(world.living_enemies(), 1, "visibility cancellation retains only the original actor")
	assert_eq(_pending_relocations(), 0, "hiding again requires the full unseen interval before a new warning")
	world._unseen_ticks[enemy.spawn_id] = 179
	world._process_pursuit()
	assert_eq(_pending_relocations(), 1, "a fresh full interval may warn again")
	enemy.queue_free()
	await ticks(2)
	for tick in 42: world._process_spawns()
	assert_eq(_pending_relocations(), 0, "a freed weak target retires its warning without dereferencing a null actor")


func _pending_spawns() -> int:
	var count := 0
	for warning: Dictionary in world.telegraphs:
		if warning.get("kind", "spawn") == "spawn":
			count += 1
	return count


func _pending_relocations() -> int:
	var count := 0
	for warning: Dictionary in world.telegraphs:
		if warning.get("kind", "spawn") == "relocate":
			count += 1
	return count


func _clear_enemies() -> void:
	for enemy: ArenaEnemy in world.enemies:
		if is_instance_valid(enemy):
			enemy.free()
	world.enemies.clear()
	world.spawn_queue.clear()
	world.telegraphs.clear()
	world._unseen_ticks.clear()
