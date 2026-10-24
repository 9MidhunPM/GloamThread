extends Scenario
## New overhead data and real collision probes; no side-view actor or art claim.

class Probe extends CharacterBody2D:
	var drive := Vector2.ZERO
	func _ready() -> void:
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		collision_layer = 2
		collision_mask = 1
		var collider := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(12,10)
		collider.shape = rectangle
		collider.position = Vector2(0,-5)
		add_child(collider)
	func _physics_process(_delta: float) -> void:
		velocity = drive
		move_and_slide()


func run() -> void:
	var home := RoomDefinition.load_from_path("res://content/rooms/r00.json")
	assert_true(home.is_valid(), "safe overhead Lantern Rest parses: %s" % str(home.errors))
	assert_eq(RoomDefinition.feet_position(Vector2i(7,15)), Vector2(120,253), "feet and collision centre use the overhead cell contract")
	assert_eq(home.spawn_positions("missing").size(), 0, "unknown entrance never invents a fallback")
	var home_room := Room.build(home,false)
	assert_true(home_room.entity_visuals.y_sort_enabled, "prop/NPC branch participates in shared feet sorting")
	for pair: Array in home.spawns.values():
		for tile: Vector2i in pair:
			assert_true(home_room.can_stand_at(RoomDefinition.feet_position(tile)), "every home entrance has a safe full footprint")
	home_room.free()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/overhead_world_room.json"))
	var definition := RoomDefinition.new()
	definition.parse(data)
	assert_true(definition.is_valid(), "overhead bridge fixture parses: %s" % str(definition.errors))
	for field: String in ["fractional", "legacy", "water"]:
		var invalid: Dictionary = data.duplicate(true)
		if field == "fractional": invalid.spawns.start[0][0] = 3.5
		elif field == "legacy": invalid.content_version = "phase1-v1"
		else: invalid.spawns.start[0] = [12,10]
		var rejected := RoomDefinition.new()
		rejected.parse(invalid)
		assert_true(not rejected.is_valid(), "parser rejects %s spawn/version data" % field)
	var room := Room.build(definition,true)
	add_child(room)
	assert_true(room.water_body != room.collision, "water has a separate exception target from immutable walls")
	assert_eq(room.theme_gameplay_node_count(), 0, "both opaque skins remain collision free")
	for theme: Node2D in [room.theme_ember,room.theme_moss]:
		var terrain := theme.get_node("Terrain") as TileMapLayer
		assert_eq(terrain.get_used_cells().size(),definition.width*definition.height,"opaque overhead terrain covers every floor/wall/water cell")
	assert_true(room.can_stand_at(RoomDefinition.feet_position(Vector2i(4,15))), "hazards are physically walkable")
	assert_true(not definition.is_safe_spawn(Vector2i(4,15)), "hazards cannot receive safe spawns")
	assert_true(not room.can_stand_at(Vector2(190,173)), "partial courier footprint in water is rejected")
	assert_true(not room.can_threadstep(Vector2(184,173),Vector2(244,173)), "a four-tile repair span cannot be replaced by a sixty-pixel dash")
	assert_true(not room.can_threadstep(RoomDefinition.feet_position(Vector2i(4,5)),RoomDefinition.feet_position(Vector2i(7,7))), "swept diagonal footprint cannot phase a wall corner")
	var probe := Probe.new()
	probe.position = Vector2(168,173)
	add_child(probe)
	await _drive(probe,Vector2(110,0),30)
	assert_true(probe.position.x <= 186 and probe.position.x >185,"ordinary movement stops at the water shore")
	assert_true(room.can_stand_at(probe.position),"the engine's shore safe margin remains a valid dry departure")
	var blocker := room.water_body.get_node("Bridge_bridge_spindle") as CollisionShape2D
	var wall_shapes := room.collision.get_child_count()
	assert_true(room.restore_bridge("bridge_spindle"),"the named bridge restores once")
	assert_true(blocker.disabled,"restoration disables only its named water blocker")
	assert_true(not room.restore_bridge("bridge_spindle"),"repeated bridge rewards are idempotent")
	assert_eq(room.collision.get_child_count(),wall_shapes,"restoration never changes wall collision")
	assert_true(room.can_stand_at(RoomDefinition.feet_position(Vector2i(13,10))),"restored cells become dry traversable floor")
	assert_true(not room.can_stand_at(RoomDefinition.feet_position(Vector2i(13,5))),"water outside the named span remains blocked")
	await _drive(probe,Vector2(110,0),65)
	assert_true(probe.position.x>280,"real body crosses the restored bridge without a water exception")
	probe.position = Vector2(313.925,109)
	probe.reset_physics_interpolation()
	assert_true(room.can_threadstep(probe.position,probe.position+Vector2(60,0)),"optional exact three-tile boundary tolerates engine shore margin")
	probe.add_collision_exception_with(room.water_body)
	await _drive(probe,Vector2(300,0),12)
	probe.remove_collision_exception_with(room.water_body)
	await _drive(probe,Vector2.ZERO,2)
	assert_true(room.can_stand_at(probe.position) and probe.position.x>373,"water-only exception reaches a dry landing")
	probe.position = Vector2(70,109)
	probe.add_collision_exception_with(room.water_body)
	await _drive(probe,Vector2(300,0),20)
	assert_true(probe.position.x<74.1,"water exception never bypasses the actual wall body")
	probe.remove_collision_exception_with(room.water_body)
	var replayed := Room.build(definition,false,null,{"bridge_spindle":true})
	assert_true(replayed.can_stand_at(RoomDefinition.feet_position(Vector2i(13,10))),"saved bridge flags rebuild identical traversability")
	replayed.free()


func _drive(probe: Probe, direction: Vector2, count: int) -> void:
	probe.drive = direction
	for index in count:
		await get_tree().physics_frame
		await get_tree().process_frame
	probe.drive = Vector2.ZERO
