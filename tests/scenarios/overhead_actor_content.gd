extends Scenario
## Production profiles, atlas resources and room geometry with controlled starts.
## This verifies actor integration; it is not a normal-input campaign route.
const PLAYER := preload("res://scenes/actors/player.tscn")
const Action := CommandSnapshot.Action
var _catalog: ContentCatalog
var _progress := TeamProgress.new()
var _world: Node2D
var _room: Room
var _players: Array[PlayerController] = []

func run() -> void:
	_catalog = ContentCatalog.load_bundle()
	assert_true(_catalog.errors.is_empty(), "actual overhead content admits without asset fallback: %s" % _catalog.errors)
	if not _catalog.errors.is_empty():
		return
	assert_true(_progress.commit_flags(["boss_spoolwarden", "threadstep", "shortcut_bell"]), "traversal fixture uses a valid complete boss reward")
	for slot in 2:
		InputRouter.clear(slot)
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
	_open_room("r01", "from_r00")
	for start_x: float in [620.0, 626.0, 632.0]:
		await _cross(Vector2(start_x, 109), Vector2.RIGHT)
		await _cross(Vector2(start_x + 60.0, 109), Vector2.LEFT)
	await _roll_shore(Vector2(626, 109), Vector2.RIGHT)
	# The Atrium pillar is immutable terrain. Both real-profile couriers roll
	# into its western face, then respond immediately to moving away/attacking.
	await _reset_pair(Vector2(370, 245), Vector2(0, 16))
	for slot in 2:
		InputRouter.set_test_input(slot, Action.RIGHT | Action.ROLL)
	await _steps(12)
	for player in _players:
		assert_true(player.position.x < 378.1, "authored wall stops a real-profile roll")
		assert_true(_room.can_stand_at(player.position), "wall-stopped roll keeps a dry non-wall footprint")
	for slot in 2:
		InputRouter.set_test_input(slot, Action.UP | Action.ATTACK)
	await _steps(1)
	for player in _players:
		assert_eq(player.animation_key, "slash_up", "a completed blocked roll accepts a newly faced attack immediately")
	await _steps(18)
	for slot in 2:
		InputRouter.set_test_input(slot, Action.LEFT)
	await _steps(12)
	for player in _players:
		assert_true(player.position.x < 364.0, "motor recovers freely away from the contacted wall")
	_open_room("r06", "from_r01")
	for start_y: float in [145.0, 151.0, 157.0]:
		await _cross(Vector2(168, start_y), Vector2.DOWN)
		await _cross(Vector2(168, start_y + 60.0), Vector2.UP)
	await _roll_shore(Vector2(168, 151), Vector2.DOWN)
	await _shared_encounter()
	assert_true(_catalog.assets.errors.is_empty(), "runtime actor clips/effects resolve against the actual original packet: %s" % _catalog.assets.errors)
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)

func _open_room(id: String, entrance: String) -> void:
	if is_instance_valid(_world):
		_world.free()
	_players.clear()
	_world = Node2D.new()
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	_world.y_sort_enabled = true
	add_child(_world)
	_room = Room.build(_catalog.room(id), true, _catalog.assets)
	_world.add_child(_room)
	var spawns := _room.definition.spawn_positions(entrance)
	for slot in 2:
		InputRouter.set_test_input(slot, 0)
		var player := PLAYER.instantiate() as PlayerController
		player.slot_index = slot
		player.configure(_catalog.profiles["tavi_fixed" if slot == 0 else "neri_fixed"], _catalog.assets, _progress)
		player.position = spawns[slot]
		_world.add_child(player)
		player.set_room_context(_room.bounds(), _room.can_stand_at, _room.can_threadstep, _room.water_body)
		_players.append(player)

func _cross(start: Vector2, direction: Vector2) -> void:
	var separation := Vector2(0, 16) if direction.x != 0 else Vector2(16, 0)
	await _reset_pair(start, separation)
	for slot in 2:
		var player := _players[slot]
		assert_true(_room.can_threadstep(player.position, player.position + direction * 60), "authored shore accepts the complete launch corridor")
		InputRouter.set_test_input(slot, _bit(direction) | Action.DASH)
	await _steps(12)
	for slot in 2:
		var player := _players[slot]
		var target := start + separation * slot + direction * 60
		assert_true(player.position.distance_to(target) < 0.2, "actual profile crosses exactly sixty pixels on its owned axis")
		assert_true(_room.can_stand_at(player.position), "actual dash lands with the whole footprint dry")
		assert_true(not player.get_collision_exceptions().has(_room.water_body), "actual dash restores this room water collision")
		InputRouter.set_test_input(slot, 0)
	await _steps(3)
	for player in _players:
		assert_eq(player.animation_state, "idle", "landed dash returns to its authored idle bank")
		var sprite := player.get_node("Visual/Sprite2D") as Sprite2D
		assert_eq(sprite.texture.get_size(), Vector2(32, 48), "actual atlas frame preserves the courier art contract")
		assert_eq(sprite.offset, Vector2(-16, -43), "actual frame selection preserves the feet pivot")
		var visual_id: String = _catalog.profiles[player.profile_id].visual_bundle_id
		var clip := _catalog.assets.animation(visual_id, player.animation_key)
		assert_eq(sprite.texture, _catalog.assets.frame_texture(visual_id, int(clip.frames[0])), "idle recovery consumes the correct authored direction bank")

func _roll_shore(start: Vector2, direction: Vector2) -> void:
	await _reset_pair(start, Vector2(0, 16) if direction.x != 0 else Vector2(16, 0))
	for slot in 2:
		InputRouter.set_test_input(slot, _bit(direction) | Action.ROLL)
	await _steps(12)
	for player in _players:
		assert_true(_room.can_stand_at(player.position), "roll into authored shore remains completely dry")
		assert_true(not player.get_collision_exceptions().has(_room.water_body), "roll never adopts the dash water exception")
	var stopped := [_players[0].position, _players[1].position]
	for slot in 2:
		InputRouter.set_test_input(slot, 0)
	await _steps(3)
	for slot in 2:
		var settling: Vector2 = _players[slot].position - stopped[slot]
		# CharacterBody's 0.08px safe margin may settle away from contact on
		# the next ordinary move; it must not become coast into the water.
		assert_true(settling.length() < 0.1 and settling.dot(direction) <= 0.01, "blocked roll permits only collision-margin settling away from water")

func _shared_encounter() -> void:
	_open_room("r03", "from_r02")
	await _reset_pair(Vector2(232, 253), Vector2(0, 16))
	var enemies: Array[CombatEnemy] = []
	for entity: Dictionary in _room.definition.entities:
		if str(entity.type) not in ["spoolmite", "wickwing"]:
			continue
		var enemy := CombatEnemy.new()
		enemy.position = RoomDefinition.feet_position(Vector2i(entity.tile[0], entity.tile[1]))
		enemy.configure(entity.type, _players, _catalog.assets, _room.bounds())
		_world.add_child(enemy)
		enemy.set_room_context(_room.bounds(), _room.can_stand_at, _room.can_threadstep, _room.water_body)
		enemies.append(enemy)
	assert_eq(enemies.size(), 4, "Gallery keeps one instance of each of its four authored enemies")
	var first := enemies[0]
	var outcomes: Array[int] = []
	first.defeated.connect(func(_enemy: CombatEnemy) -> void: outcomes.append(1))
	for slot in 2:
		InputRouter.set_test_input(slot, Action.RIGHT | Action.ATTACK)
	await _steps(8)
	assert_eq(first.health, 1, "two real couriers each land one owned slash on the shared enemy")
	assert_true(first.get_node("AttackDirectionHint").visible, "authored warning resource is visible during the real enemy windup")
	var warning: Sprite2D = first.get("_warning_sprite")
	assert_eq(warning.texture.get_size(), Vector2(32, 32), "warning consumes the actual authored atlas size")
	for slot in 2:
		InputRouter.set_test_input(slot, 0)
	await _steps(10)
	InputRouter.set_test_input(0, Action.SPECIAL)
	InputRouter.set_test_input(1, Action.SPECIAL)
	await _steps(8)
	assert_true(first.dead, "actual Tavi special completes the shared enemy encounter")
	assert_eq(outcomes.size(), 1, "two active players cannot duplicate the defeat outcome")
	assert_true(not first.get_node("AttackDirectionHint").visible, "defeat clears the actual authored direction warning")

func _reset_pair(start: Vector2, separation: Vector2) -> void:
	for slot in 2:
		InputRouter.set_test_input(slot, 0)
		_players[slot].restore(start + separation * slot)
	await _steps(1)

func _bit(direction: Vector2) -> int:
	if direction.x > 0: return Action.RIGHT
	if direction.x < 0: return Action.LEFT
	return Action.DOWN if direction.y > 0 else Action.UP

func _steps(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
