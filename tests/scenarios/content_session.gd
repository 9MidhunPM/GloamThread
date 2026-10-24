extends Scenario
## Integrate the full authored campaign; this is not a rendered/device test.

const SESSION := preload("res://scenes/session/session.tscn")
const Action := CommandSnapshot.Action


func run() -> void:
	InputRouter.clear(0)
	InputRouter.clear(1)
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.assign(1, DeviceSource.keyboard_right())
	InputRouter.set_test_input(0, 0)
	InputRouter.set_test_input(1, 0)
	var session := SESSION.instantiate() as GameSession
	session._focus_pause_enabled = false
	add_child(session)
	assert_true(session.session_ready, "authored r00 and manifest assets start the real session: %s" % session.startup_error)
	if not session.session_ready:
		_cleanup()
		return
	await ticks(20)
	assert_eq(session.room.definition.id, "r00", "the authored start room loads")
	assert_eq(session.catalog.assets.stage, "full", "production startup requires the full catalog")
	assert_true(not session.fixture_mode, "production startup keeps fixture mode separate")
	assert_eq(session.players.size(), 2, "the shared simulation contains two couriers")
	for index in 2:
		var player := session.players[index]
		var sprite := player.get_node("Visual/Sprite2D") as Sprite2D
		assert_true(sprite.texture != null and player._animator is SpriteAnimator, "courier %d uses the catalog-backed animator" % index)
		if sprite.texture != null:
			assert_eq(sprite.texture.get_size(), Vector2(32, 48), "courier frame size excludes atlas padding")
		assert_eq(sprite.offset, Vector2(-16, -43), "courier art uses the authored feet origin")
		assert_eq(player.position, session.room.definition.spawn_positions("start")[index], "courier %d starts at the authored paired entrance" % index)
	assert_true(session.presentation.viewport_a.world_2d == session.presentation.viewport_b.world_2d, "both cameras observe the same World2D")
	assert_eq(session.presentation.actors.get_child_count(), 2, "presentation creates one actor pair without duplicate simulation")
	assert_true(not session.presentation.viewport_a.audio_listener_enable_2d and not session.presentation.viewport_b.audio_listener_enable_2d, "viewport listeners cannot duplicate shared audio")
	assert_eq(session.presentation.viewport_a.canvas_cull_mask, 3, "Tavi sees common and Ember layers")
	assert_eq(session.presentation.viewport_b.canvas_cull_mask, 5, "Neri sees common and Moss layers")
	for theme: Node2D in [session.room.theme_ember, session.room.theme_moss]:
		var terrain := theme.get_node_or_null("Terrain") as TileMapLayer
		assert_true(terrain != null and terrain.get_used_cells().size() > 0, "production terrain is instantiated in %s" % theme.name)
	assert_eq(session.room.theme_gameplay_node_count(), 0, "theme skins carry no gameplay collision")
	assert_true(session.mover == null, "production r00 contains no diagnostic mover")
	assert_eq(session.enemies.size(), 0, "Lantern Rest begins without a combat encounter")
	var checkpoint := _entity(session.room.definition, "rest_lantern")
	var oru := _entity(session.room.definition, "oru")
	assert_eq(checkpoint.get("checkpoint_id"), "checkpoint_a", "the home lantern owns checkpoint A")
	assert_eq(checkpoint.get("entrance"), "checkpoint_a", "continue resolves the authored checkpoint entrance")
	assert_eq(oru.get("dialogue_id"), "oru_intro", "Oru begins with the authored introduction")
	assert_eq(oru.get("restored_dialogue_id"), "oru_return", "Oru has the restored-home response")
	session.room.set_entity_state("rest_lantern", "checkpoint_lit")
	var lantern: Sprite2D = session.room._visuals["rest_lantern"]
	assert_true(lantern.texture == session.catalog.assets.frame_texture("props_v1", 10), "checkpoint state shows its lit authored frame")
	assert_true(session.players[0].is_on_floor() and session.players[1].is_on_floor(), "authored paired spawns stand on real collision")
	assert_true(AssetCatalog.safe_output_path("assets/generated/art/example.png"), "bundle-relative image path is allowed")
	for path: String in ["res://scripts/input/input_router.gd", "assets/generated/../secret.png", "/tmp/image.png", "https://example.invalid/image.png", "assets/generated/./image.png", "assets/generated/a\\b.png"]:
		assert_true(not AssetCatalog.safe_output_path(path), "unsafe content path is rejected: %s" % path)
	var measurements: Dictionary = await _measure_motor(session.players[0])
	assert_true(measurements["full_jump_rise_px"] > 32.0, "full jump clears a conservative two-tile rise")
	assert_true(measurements["running_jump_travel_px"] > 40.0, "running jump has a measurable same-height envelope")
	print("TRAVERSAL_METRICS " + JSON.stringify(measurements))
	assert_true(session.catalog.assets.errors.is_empty(), "production session resolves all required resources")
	var invalid_bundle := ContentCatalog.load_bundle()
	invalid_bundle.rooms["r00"] = RoomDefinition.load_from_path("res://tests/contracts/content_invalid_missing_entrance.json")
	invalid_bundle._validate_references()
	assert_true(not invalid_bundle.errors.is_empty(), "unresolved authored entrances fail the content boundary")
	session.free()
	var rejected := SESSION.instantiate() as GameSession
	rejected.configure(invalid_bundle, TeamProgress.new())
	add_child(rejected)
	assert_true(not rejected.session_ready and not rejected.startup_error.is_empty(), "invalid production content stops startup visibly")
	assert_true(rejected.room == null and rejected.players.is_empty(), "invalid production content never creates a fallback simulation")
	rejected.free()
	_cleanup()
	await _retire_audio()


func _entity(definition: RoomDefinition, id: String) -> Dictionary:
	for entity: Dictionary in definition.entities:
		if entity["id"] == id:
			return entity
	return {}


func _measure_motor(player: PlayerController) -> Dictionary:
	InputRouter.set_test_input(0, 0)
	player.reset_at(Vector2(104, 320))
	await ticks(5)
	var floor_y := player.position.y
	var apex := floor_y
	InputRouter.set_test_input(0, Action.JUMP)
	for index in 60:
		await ticks(1)
		apex = minf(apex, player.position.y)
	InputRouter.set_test_input(0, 0)
	player.reset_at(Vector2(104, 320))
	await ticks(5)
	InputRouter.set_test_input(0, Action.RIGHT)
	await ticks(30)
	var launch_x := player.position.x
	var launch_y := player.position.y
	var landed_x := launch_x
	var airborne := false
	var airborne_ticks := 0
	InputRouter.set_test_input(0, Action.RIGHT | Action.JUMP)
	for index in 90:
		await ticks(1)
		if player.position.y < launch_y - 0.1:
			airborne = true
		if airborne:
			airborne_ticks += 1
		if airborne and player.is_on_floor():
			landed_x = player.position.x
			break
	InputRouter.set_test_input(0, 0)
	return {
		"full_jump_rise_px": snappedf(floor_y - apex, 0.01),
		"running_jump_travel_px": snappedf(landed_x - launch_x, 0.01),
		"airborne_ticks": airborne_ticks,
		"standing_collider_height_px": 24,
		"collider_width_px": 12,
		"full_jump_body_clearance_px": ceilf(floor_y - apex + 24.0),
		"physics_hz": 60,
		"dash_measured": false,
	}


func _cleanup() -> void:
	get_tree().paused = false
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)


func _retire_audio() -> void:
	var pending: Array[WeakRef] = []
	for node: Node in AudioDirector.get_children():
		if node is AudioStreamPlayer and node.has_stream_playback():
			pending.append(weakref(node.get_stream_playback()))
	AudioDirector.stop_music()
	AudioDirector.stop_cues()
	var deadline := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline:
		var alive := false
		for playback: WeakRef in pending:
			alive = alive or playback.get_ref() != null
		if not alive:
			return
		await get_tree().process_frame
	assert_true(false, "shared audio retires stopped campaign playbacks")
