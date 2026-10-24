extends Scenario


func run() -> void:
	var catalog := ArenaCatalog.load_catalog()
	assert_true(catalog.errors.is_empty(), "complete authored catalog admitted: " + str(catalog.errors))
	var bundles := FighterLibrary.new().list_bundles()
	assert_true(bundles.size() >= 2, "two original bundles load through the runtime boundary")
	if not catalog.errors.is_empty() or bundles.size() < 2:
		return
	for slot in 2:
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
	var world := ArenaRunSession.new()
	world.configure(catalog, [bundles[0], bundles[1]], 18427)
	add_child(world)
	await ticks(3)
	world.phase = "combat"
	world.spawn_queue.clear()
	world.telegraphs.clear()
	world._spawn_enemy({"role": "chaser", "boss": "", "elite": false, "position": Vector2(100, 320)})
	var enemy: ArenaEnemy = world.enemies[0]
	assert_true(enemy.take_damage(10000, 1, 9001), "accepted lethal damage")
	assert_eq(world.player_states[0].coins, 0, "other player's wallet receives no last-hit credit")
	assert_eq(world.player_states[1].coins, 1, "lethal source owns the kill reward")
	assert_true(not enemy.take_damage(10000, 0, 9002), "dead actor rejects second lethal hit")
	world._on_enemy_defeated(enemy, 0)
	assert_eq(world.player_states[0].coins, 0, "duplicate death cannot pay another slot")
	assert_eq(world.player_states[1].kills, 1, "kill counted once")
	world._clear_wave()
	assert_true(world.player_states[0].coins >= 8 and world.player_states[1].coins >= 9, "clear bonus reaches both wallets")
	world._open_shop()
	world.player_states[0].coins = 100
	world.player_states[1].coins = 100
	var offer: Dictionary = world.shop_offers[0][0]
	var other_coins := world.player_states[1].coins
	var result := world.try_purchase(0, str(offer.id))
	assert_true(result.ok, "owned offer purchases atomically")
	assert_eq(world.player_states[0].coins, 100 - int(offer.price), "price debited exactly once")
	assert_eq(world.player_states[1].coins, other_coins, "purchase preserves other wallet")
	assert_eq(world.player_states[0].rank(offer.id), 1, "upgrade applied once")
	assert_true(not world.try_purchase(0, str(offer.id)).ok, "consumed offer cannot be purchased twice")
	world.player_states[0].coins = 0
	assert_true(not world.try_purchase(0, str(world.shop_offers[0][0].id)).ok, "insufficient funds cannot buy")
	assert_true(not world.try_purchase(-1, "heal").ok, "invalid source slot cannot buy")
	assert_true(world.reroll(0), "first reroll is free")
	assert_true(not world.reroll(0), "second reroll rejected")
	world.toggle_ready(0)
	assert_eq(world.phase, "shop", "one ready player cannot advance co-op")
	assert_true(not world.try_purchase(0, "heal").ok, "ready panel cannot mutate wallet")
	world.toggle_ready(1)
	assert_eq(world.phase, "countdown", "both ready advance once")
	assert_eq(world.wave, 2, "only one wave transition committed")
	assert_true(not world.try_purchase(1, "heal").ok, "combat cannot invoke shop purchases")
	var fresh := ArenaPlayerState.new()
	assert_eq(fresh.coins, 0, "new run resets wallet")
	assert_true(fresh.levels.is_empty(), "new run resets upgrades")
	for kit: String in ArenaCatalog.KITS:
		fresh.kit_id = kit
		fresh.modifiers = {"damage": 1000000, "special_cooldown": -1000000, "crit": 1000000}
		var stats := fresh.stats()
		assert_eq(stats.damage, 200.0, "damage bounded for " + kit)
		assert_eq(stats.special_cooldown, 60.0, "cooldown bounded for " + kit)
		assert_eq(stats.crit, 0.75, "crit bounded for " + kit)
