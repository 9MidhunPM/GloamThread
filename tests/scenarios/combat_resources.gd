extends Scenario
## Original manifest resources consumed by real actors; headless evidence only.

const PLAYER := preload("res://scenes/actors/player.tscn")
var _world: Node2D


func run() -> void:
	var catalog := AssetCatalog.load_from_path("res://assets/manifest.json")
	assert_true(catalog.errors.is_empty(), "combat asset manifest validates")
	if not catalog.errors.is_empty():
		return
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/profiles.json"))
	var progress := TeamProgress.new()
	_world = Node2D.new()
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	var players: Array[PlayerController] = []
	for slot in 2:
		InputRouter.clear(slot)
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
		var player := PLAYER.instantiate() as PlayerController
		player.slot_index = slot
		player.position = Vector2(100 + slot * 100, 200)
		player.configure(source["profiles"][slot], catalog, progress)
		_world.add_child(player)
		players.append(player)
		var sprite := player.get_node("Visual/Sprite2D") as Sprite2D
		assert_true(sprite.texture != null and sprite.texture.get_size() == Vector2(32, 48), "courier loads an actual authored atlas frame")
		assert_eq(sprite.offset, Vector2(-16, -43), "courier feet origin survives actor integration")
		assert_eq(player.max_hearts, 5 if slot == 0 else 4, "actor consumes the fixed profile health")
		player.set_physics_process(false)
		for direction in PlayerController.Facing.values():
			player.facing = direction
			for state: String in ContentCatalog.COURIER_CLIPS:
				player.call("_set_animation", state)
				var key := state + "_" + PlayerController.DIRECTION_NAMES[direction]
				var clip := catalog.animation(str(source["profiles"][slot]["visual_bundle_id"]), key)
				assert_true(not clip.is_empty(), "courier authored direction/state resolves: " + key)
				if not clip.is_empty():
					assert_true(sprite.texture == catalog.frame_texture(str(source["profiles"][slot]["visual_bundle_id"]), int(clip.frames[0])), "actor selects the first frame of " + key)
	for kind: String in ["spoolmite", "wickwing", "spoolwarden"]:
		var enemy := CombatEnemy.new()
		enemy.configure(kind, players, catalog, Rect2(0, 0, 1000, 400))
		enemy.position = Vector2(300, 200)
		_world.add_child(enemy)
		var sprite: Sprite2D = enemy.get("_sprite")
		assert_true(sprite.texture != null, kind + " loads its authored animation")
		assert_true(enemy.receive_hit(1, 0, CombatQuery.next_attack_id(), 1, 90), "production enemy produces hit effect")
		enemy.receive_hit(100, 1, CombatQuery.next_attack_id())
		assert_eq(str(enemy.get("_animator").get("state")), "defeat", kind + " plays defeat through the real animator")
	for id: String in ["effect_slash_v1", "effect_ember_arc_v1", "effect_spore_impact_v1", "effect_dash_v1", "effect_revive_v1", "effect_weave_v1"]:
		CombatQuery.effect(players[0], catalog, id, Vector2(400, 200))
	var effects := get_tree().get_nodes_in_group("combat_transients")
	assert_true(effects.size() >= 9, "combat creates original animated effects in the shared world")
	get_tree().paused = true
	await _steps(60)
	assert_eq(get_tree().get_nodes_in_group("combat_transients").size(), effects.size(), "pause freezes effect lifetimes")
	get_tree().paused = false
	await _steps(55)
	assert_true(get_tree().get_nodes_in_group("combat_transients").is_empty(), "effects release after their physics lifetime")
	assert_true(catalog.errors.is_empty(), "combat resources load without fallback: %s" % str(catalog.errors))
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)


func _steps(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame
		await get_tree().process_frame
