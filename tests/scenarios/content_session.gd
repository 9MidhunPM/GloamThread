extends Scenario
## Integrate the actual authored packet; this is not a rendered/device test.

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
	add_child(session)
	assert_true(session.session_ready, "authored r00 and manifest assets start the real session: %s" % session.startup_error)
	if not session.session_ready:
		_cleanup()
		return
	await ticks(20)
	assert_eq(session.room.definition.id, "r00", "the authored start room loads")
	assert_true(session.players[0].sprite_texture != null and session.players[1].sprite_texture != null, "both original courier frames resolve through the manifest")
	assert_eq(session.players[0].sprite_texture.get_size(), Vector2(32, 48), "courier frame size remains independent of atlas padding")
	assert_eq(session.room.theme_ember.get_child_count(), 1, "Ember diagnostic terrain is actually instantiated")
	assert_eq(session.room.theme_moss.get_child_count(), 1, "Moss diagnostic terrain is actually instantiated")
	assert_true(session.mover != null and session.mover.sprite_texture != null, "the authored mover has its original sprite")
	assert_true(session.players[0].is_on_floor() and session.players[1].is_on_floor(), "authored paired spawns stand on real collision")
	assert_true(AssetCatalog.safe_output_path("assets/generated/art/example.png"), "bundle-relative image path is allowed")
	for path: String in ["res://scripts/input/input_router.gd", "assets/generated/../secret.png", "/tmp/image.png", "https://example.invalid/image.png", "assets/generated/./image.png", "assets/generated/a\\b.png"]:
		assert_true(not AssetCatalog.safe_output_path(path), "unsafe content path is rejected: %s" % path)
	var measurements: Dictionary = await _measure_motor(session.players[0])
	assert_true(measurements["full_jump_rise_px"] > 32.0, "full jump clears a conservative two-tile rise")
	assert_true(measurements["running_jump_travel_px"] > 40.0, "running jump has a measurable same-height envelope")
	print("TRAVERSAL_METRICS " + JSON.stringify(measurements))
	_cleanup()


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
