extends Scenario
## Real flight/collision regressions for previously stranded final enemies.

func run() -> void:
	AudioDirector.register_bundle(AssetCatalog.load_from_path("res://assets/manifest.json"))
	ArenaAudio.register_original()
	var world := ArenaRunSession.new()
	var bundles := FighterLibrary.new().list_bundles()
	world.configure(ArenaCatalog.load_catalog(), [bundles[0]], 1791860771)
	add_child(world)
	await ticks(2)
	world.map.expand_to(4)
	world._build_arena()
	world.set_physics_process(false)
	world.phase = "combat"
	world.spawn_queue.clear()
	var fighter := world.fighters[0] as ArenaFighter
	fighter.set_physics_process(false)
	fighter.immunity_ticks = 0
	for placement: Array in [[Vector2(6144.73,374.08),Vector2(6163.82,320)],[Vector2(9264,223.92),Vector2(9324,320)]]:
		fighter.position = placement[1]
		fighter.health = fighter.max_health
		fighter.immunity_ticks = 0
		world._spawn_enemy({"role":"flyer","boss":"","elite":false,"position":placement[0]})
		var flyer := world.enemies[0] as ArenaEnemy
		var initial: Vector2 = flyer.position
		var hit := false
		for tick in 2400:
			await ticks(1)
			if fighter.health < fighter.max_health:
				hit = true
				break
		assert_true(hit, "a flyer routes around real terrain and reaches the target from %s (ended %s)" % [str(initial),str(flyer.position)])
		if not hit:
			print("FLYER_STALL ", str({"position":flyer.position,"velocity":flyer.velocity,"state":flyer._state,"routing":flyer._flight_routing,"waypoint":flyer._flight_waypoint,"drop":flyer._drop_ticks,"los":ArenaCombat.clear_line(flyer,flyer.get_hurt_rect().get_center(),fighter.get_hurt_rect().get_center()),"nav":world.navigation_step(flyer.position,fighter.position)}))
		assert_eq(world.enemies.size(), 1, "flight navigation moves one original actor without duplicating it")
		flyer.free()
		world.enemies.clear()
