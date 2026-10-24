extends Scenario
## Real water/wall bodies with full-footprint callback fixtures; no room JSON.
const PLAYER := preload("res://scenes/actors/player.tscn")
const Action := CommandSnapshot.Action
var _water_rect := Rect2(128, 0, 32, 300)
var _bounds := Rect2(0, 0, 500, 400)
var _walls: Array[Rect2] = []
var _water: StaticBody2D
var _players: Array[PlayerController] = []
var _progress := TeamProgress.new()
var _corridor_open := true
var _world: Node2D

func run() -> void:
	_world = Node2D.new()
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	_water = _body(_water_rect)
	for slot in 2:
		InputRouter.clear(slot)
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
		var player := PLAYER.instantiate() as PlayerController
		player.slot_index = slot
		player.position = Vector2(112, 100 + slot * 70)
		player.configure({}, null, _progress)
		_world.add_child(player)
		player.set_room_context(_bounds, _can_stand, _can_cross, _water)
		_players.append(player)
	var player := _players[0]
	await _steps(2)
	InputRouter.set_test_input(0, Action.RIGHT | Action.DASH)
	await _steps(1)
	assert_eq(player.dash_ticks, 0, "Threadstep cannot start before the team unlock")
	_progress.commit_flags(["threadstep"])
	await _reset(Vector2(112, 100))
	InputRouter.set_test_input(0, Action.RIGHT | Action.DASH)
	InputRouter.set_test_input(1, Action.RIGHT)
	await _steps(5)
	assert_true(not _can_stand(player.position), "active Threadstep crosses the water footprint")
	assert_true(player.get_collision_exceptions().has(_water), "only the dashing courier bypasses the known water body")
	assert_true(not _players[1].get_collision_exceptions().has(_water), "partner collision ownership remains independent")
	var frozen := player.position
	var ticks_left := player.dash_ticks
	get_tree().paused = true
	await _steps(12)
	assert_eq(player.position, frozen, "pause freezes a crossing over water")
	assert_eq(player.dash_ticks, ticks_left, "pause freezes dash duration")
	get_tree().paused = false
	InputRouter.set_test_input(0, 0)
	await _steps(7)
	assert_true(player.position.distance_to(Vector2(172, 100)) < 0.1, "twelve dash ticks land sixty pixels away")
	assert_eq(player.dash_ticks, 0, "dash ends on the twelfth movement tick")
	assert_true(not player.get_collision_exceptions().has(_water), "dry landing restores water collision")
	assert_true(_players[1].position.x < 122.1, "partner remains blocked by the same water body")
	await _steps(3)
	assert_true(player.position.distance_to(Vector2(172, 100)) < 0.1, "dash leaves no extra coast after landing")
	InputRouter.set_test_input(0, Action.DASH)
	await _steps(1)
	assert_eq(player.dash_ticks, 0, "dash cannot restart inside its forty-five-tick cooldown")
	# The landing centre alone is insufficient: its whole footprint must be dry.
	await _reset(Vector2(102, 100))
	InputRouter.set_test_input(0, Action.RIGHT | Action.DASH)
	await _steps(1)
	assert_eq(player.dash_ticks, 0, "partially wet landing footprint rejects the dash")
	# Damage over water returns to the recorded departure before normal movement.
	await _reset(Vector2(112, 100))
	InputRouter.set_test_input(0, Action.RIGHT | Action.DASH)
	await _steps(5)
	player.immunity_ticks = 0
	assert_true(player.take_hit(1), "Threadstep itself supplies no damage immunity")
	assert_eq(player.position, Vector2(112, 100), "interrupted crossing returns to its dry departure")
	assert_true(not player.get_collision_exceptions().has(_water), "damage clears the water exception")
	# Changed geometry invalidates an already-running corridor atomically.
	await _reset(Vector2(112, 100))
	InputRouter.set_test_input(0, Action.RIGHT | Action.DASH)
	await _steps(5)
	_corridor_open = false
	await _steps(1)
	assert_eq(player.position, Vector2(112, 100), "invalidated corridor returns to dry departure")
	assert_eq(player.dash_ticks, 0, "invalidated corridor cancels remaining dash ticks")
	_corridor_open = true
	await _reset(Vector2(112, 100))
	InputRouter.set_test_input(0, Action.RIGHT | Action.DASH)
	await _steps(5)
	player.reset_at(Vector2(300, 100))
	assert_eq(player.position, Vector2(300, 100), "room reset keeps its explicit new safe feet")
	assert_true(not player.get_collision_exceptions().has(_water), "room reset clears the old water exception")
	# Immutable solid walls retain their normal body, even beside water.
	_walls.append(Rect2(138, 50, 4, 100))
	_body(_walls[0])
	await _reset(Vector2(112, 100))
	InputRouter.set_test_input(0, Action.RIGHT | Action.DASH)
	await _steps(12)
	assert_eq(player.dash_ticks, 0, "a wall crossing rejects Threadstep")
	assert_true(player.position.x < 122.1, "wall rejection cannot accidentally disable water collision")
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)

func _reset(at: Vector2) -> void:
	InputRouter.set_test_input(0, 0)
	_players[0].restore(at)
	await _steps(1)

func _can_stand(feet: Vector2) -> bool:
	var footprint := Rect2(feet + Vector2(-6, -10), Vector2(12, 10))
	if not _bounds.encloses(footprint) or footprint.intersects(_water_rect):
		return false
	for wall in _walls:
		if footprint.intersects(wall):
			return false
	return true

func _can_cross(from: Vector2, to: Vector2) -> bool:
	if not _corridor_open or not _can_stand(from) or not _can_stand(to):
		return false
	var swept := Rect2(from + Vector2(-6, -10), Vector2(12, 10)).merge(Rect2(to + Vector2(-6, -10), Vector2(12, 10)))
	for wall in _walls:
		if swept.intersects(wall):
			return false
	return true

func _body(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	_world.add_child(body)
	return body

func _steps(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
