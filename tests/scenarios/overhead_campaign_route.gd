extends Scenario
## Fresh actual App campaign. Tick-indexed owned commands only; no actor warps,
## private room loads, direct damage, forced progression or synthetic save data.
const APP := preload("res://scenes/app/boot.tscn")
const Action := CommandSnapshot.Action
var app: Control
var session: GameSession
var _steps: Array[Dictionary] = []
var _step := 0
var _step_ticks := 0
var _physics_ticks := 0
var _running := false
var _complete := false
var _visited: Array[String] = []
var _paths: Array[Array] = [[], []]
var _masks: Array[int] = [0, 0]
var _dash_from: Array[Vector2] = []
var _fight_target_ids: Array[int] = [0, 0]


func run() -> void:
	process_physics_priority = -100 # Commands are ready before InputRouter's poll.
	for slot in 2:
		InputRouter.clear(slot)
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
	app = APP.instantiate() as Control
	var save_root := "/tmp/gloamthread-overhead-route-%d" % Time.get_ticks_usec()
	app.saves.path = save_root + "/campaign.json"
	app.settings_store.path = save_root + "/settings.json"
	add_child(app)
	assert_eq(app.screen, "title", "actual app opens at the title with a fresh save")
	if app.screen == "title":
		app._on_action("new")
		assert_eq(app.screen, "join", "New enters the actual two-player join screen")
		app._on_action("start")
		session = app.session
	assert_true(is_instance_valid(session) and session.session_ready, "actual New/Join starts the production overhead bundle")
	if is_instance_valid(session) and session.session_ready:
		session.set("_focus_pause_enabled", false)
		_build_steps()
		_running = true
		while _running:
			await get_tree().process_frame
	assert_true(_complete, "bounded ordinary-input route reaches the actual ending card")
	await get_tree().process_frame
	get_tree().paused = false
	for slot in 2:
		InputRouter.set_test_input(slot, 0)
		InputRouter.clear_test_input(slot)
		InputRouter.clear(slot)
	if is_instance_valid(app):
		app.free()
	AudioDirector.stop_music()
	AudioDirector.stop_cues()


func _build_steps() -> void:
	_walk(Vector2i(11,15), Vector2i(10,17)); _interact(0)
	_walk(Vector2i(15,11), Vector2i(12,12)); _interact(0); _dialogue("oru_intro")
	_walk(Vector2i(45,14), Vector2i(45,17)); _exit("r01")
	_walk(Vector2i(49,24), Vector2i(49,26)); _exit("r02")
	_walk(Vector2i(24,9), Vector2i(24,21)); _interact(0); _interact(1)
	_check("bridge_spindle")
	_walk(Vector2i(51,14), Vector2i(51,17)); _exit("r03")
	_steps.append({"kind":"fight"})
	_walk(Vector2i(20,5), Vector2i(21,5)); _check("lantern_charm")
	_walk(Vector2i(57,14), Vector2i(57,17)); _exit("r04")
	_walk(Vector2i(19,13), Vector2i(21,14)); _interact(0)
	_walk(Vector2i(37,12), Vector2i(37,15)); _exit("r05")
	_steps.append({"kind":"fight"}); _check("threadstep")
	_walk(Vector2i(53,14), Vector2i(53,17)); _exit("r01")
	_steps.append({"kind":"walk", "goals":[Vector2(626,109),Vector2(626,157)]})
	_steps.append({"kind":"dash", "direction":Vector2.RIGHT})
	_walk(Vector2i(48,6), Vector2i(48,9)); _exit("r06")
	_steps.append({"kind":"walk", "goals":[Vector2(168,151),Vector2(200,151)]})
	_steps.append({"kind":"dash", "direction":Vector2.DOWN})
	_walk(Vector2i(35,15), Vector2i(35,24)); _interact(0); _interact(1)
	_check("bridge_causeway")
	_walk(Vector2i(57,19), Vector2i(57,22)); _exit("r07")
	_walk(Vector2i(19,14), Vector2i(28,14)); _interact(0); _interact(1)
	_dialogue("ending"); _check("loom_restored")
	_walk(Vector2i(45,14), Vector2i(45,17)); _exit("r00")
	_steps.append({"kind":"finish"})


func _walk(a: Vector2i, b: Vector2i) -> void:
	_steps.append({"kind":"walk", "goals":[RoomDefinition.feet_position(a),RoomDefinition.feet_position(b)]})


func _interact(slot: int) -> void:
	_steps.append({"kind":"interact", "slot":slot})


func _dialogue(id: String) -> void:
	_steps.append({"kind":"dialogue", "id":id})


func _exit(id: String) -> void:
	_steps.append({"kind":"exit", "room":id})


func _check(flag: String) -> void:
	_steps.append({"kind":"check", "flag":flag})


func _physics_process(_delta: float) -> void:
	if not _running:
		return
	_physics_ticks += 1
	_masks.assign([0,0])
	if session.current_room_id not in _visited:
		_visited.append(session.current_room_id)
		print("OVERHEAD_ROUTE_ENTER %s tick=%d" % [session.current_room_id,_physics_ticks])
	if session.recovery_count != 0:
		_fail("ordinary route required checkpoint recovery")
	elif _physics_ticks > 40000 or _step_ticks > 6000:
		_fail("route exceeded its bounded physics-tick budget")
	else:
		var prior := _step
		_run_step(_steps[_step])
		if _step == prior:
			_step_ticks += 1
	for slot in 2:
		InputRouter.set_test_input(slot, _masks[slot] if _running else 0)


func _run_step(step: Dictionary) -> void:
	match str(step.kind):
		"walk":
			if session.mode != "playing":
				_fail("walking interrupted by " + session.mode)
				return
			if _step_ticks == 0:
				for slot in 2:
					_paths[slot] = _path(session.players[slot].position, step.goals[slot])
					if _paths[slot].is_empty():
						_fail("no safe walking route for P%d to %s" % [slot+1,step.goals[slot]])
						return
			var arrived := true
			for slot in 2:
				_masks[slot] = _follow(slot)
				arrived = arrived and _paths[slot].is_empty()
			if arrived: _advance()
		"interact":
			if _step_ticks == 0: _masks[int(step.slot)] = Action.INTERACT
			if _step_ticks >= 3: _advance()
		"dialogue":
			if session.mode != "dialogue" or session.dialogue_id != step.id:
				_fail("expected authored dialogue " + str(step.id))
				return
			app._on_action("skip") # Actual owned-menu intent; App completes the sequence.
			if session.mode != "playing":
				_fail("actual dialogue Skip did not resume play")
				return
			if step.id == "oru_intro" and not session.progress.has_flag("met_oru"):
				_fail("actual intro completion did not commit met_oru")
				return
			_advance()
		"exit":
			if session.current_room_id == step.room:
				_advance()
			elif _step_ticks == 0:
				_masks[0] = Action.INTERACT
			elif _step_ticks > 30:
				_fail("rally did not enter " + str(step.room))
		"check":
			if not session.progress.has_flag(str(step.flag)):
				_fail("ordinary play did not commit " + str(step.flag))
			else: _advance()
		"dash":
			_dash_step(step.direction)
		"fight":
			_fight_step()
		"finish":
			assert_eq(session.mode, "ending", "ordinary home rally reaches ending mode")
			assert_eq(app.screen, "ending", "actual App displays the ending card")
			assert_eq(_visited.size(), 8, "all eight authored rooms are visited")
			assert_eq(session.progress.checkpoint_id, "checkpoint_b", "ordinary interaction lit the second checkpoint")
			var loaded := session.save_repository.load_campaign()
			assert_eq(loaded.status, "ok", "real campaign save remains valid")
			assert_true("loom_restored" in loaded.data.get("world_flags",[]), "ending survives the actual save boundary")
			print("OVERHEAD_CAMPAIGN_ROUTE " + JSON.stringify({"visited":_visited,"physics_ticks":_physics_ticks,"flags":session.progress.flags,"hearts":[session.players[0].hearts,session.players[1].hearts],"ending":app.screen,"save_path":session.save_repository.path}))
			_complete = failures.is_empty()
			_running = false


func _dash_step(direction: Vector2) -> void:
	if _step_ticks == 0:
		_dash_from.assign([session.players[0].position,session.players[1].position])
		for slot in 2:
			if not session.room.can_threadstep(_dash_from[slot],_dash_from[slot]+direction*60):
				_fail("authored two-tile dash corridor is invalid for P%d" % (slot+1))
				return
	if _step_ticks < 12:
		for slot in 2:
			_masks[slot] = _direction_mask(direction) | (Action.DASH if _step_ticks == 0 else 0)
	else:
		for slot in 2:
			if session.players[slot].position.distance_to(_dash_from[slot]+direction*60) > 0.5 or not session.room.can_stand_at(session.players[slot].position):
				_fail("owned Threadstep failed its sixty-pixel dry landing")
				return
		print("OVERHEAD_ROUTE_DASH %s axis=%s" % [session.current_room_id,direction])
		_advance()


func _fight_step() -> void:
	var live: Array[CombatEnemy] = []
	for enemy in session.enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			live.append(enemy)
	if live.is_empty():
		_advance()
		return
	for slot in 2:
		var player := session.players[slot]
		if player.downed:
			continue
		var partner := session.players[1-slot]
		if partner.downed:
			if player.position.distance_to(partner.position) <= 36:
				_masks[slot] = Action.INTERACT
			else:
				if _step_ticks % 20 == 0 or _paths[slot].is_empty(): _paths[slot] = _path(player.position,partner.position)
				_masks[slot] = _follow(slot)
			continue
		var target := live[0]
		for candidate in live:
			if candidate.position.distance_squared_to(player.position) < target.position.distance_squared_to(player.position): target = candidate
		var aim := target.hurt_rect().get_center()-player.hurt_rect().get_center()
		var distance := aim.length()
		if target.kind == "spoolwarden" and target.animation_state.ends_with("_anticipation") and distance < 100:
			_masks[slot] = _direction_mask(-aim)
			if player.roll_cooldown_ticks == 0 and _step_ticks % 12 == 0: _masks[slot] |= Action.ROLL
			continue
		if distance > 28:
			if _step_ticks % 20 == 0 or _paths[slot].is_empty() or _fight_target_ids[slot] != target.get_instance_id():
				_paths[slot] = _path(player.position,_nearest_dry(target.hurt_rect().get_center()+Vector2(0,5)))
				_fight_target_ids[slot] = target.get_instance_id()
			_masks[slot] = _follow(slot)
		else:
			_masks[slot] = _direction_mask(aim)
		if player.special_cooldown_ticks == 0 and distance < (45 if slot == 0 else 160):
			_masks[slot] = _direction_mask(aim) | Action.SPECIAL
		elif distance < 38 and _step_ticks % 20 == 0:
			_masks[slot] = _direction_mask(aim) | Action.ATTACK


func _nearest_dry(point: Vector2) -> Vector2:
	var tile := Vector2i(floori(point.x/16),floori((point.y-5)/16))
	var nearest := point
	var distance := INF
	for y in range(tile.y-3,tile.y+4):
		for x in range(tile.x-3,tile.x+4):
			var feet := RoomDefinition.feet_position(Vector2i(x,y))
			if _safe(Vector2i(x,y)) and feet.distance_squared_to(point)<distance:
				distance = feet.distance_squared_to(point)
				nearest = feet
	return nearest


func _path(from: Vector2, to: Vector2) -> Array:
	var start := Vector2i(floori(from.x/16),floori((from.y-5)/16))
	var goal := Vector2i(floori(to.x/16),floori((to.y-5)/16))
	var pending: Array[Vector2i] = [start]
	var previous := {start:start}
	var at := 0
	while at < pending.size() and not previous.has(goal):
		var cell := pending[at]
		at += 1
		for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next := cell+direction
			if not previous.has(next) and _safe(next):
				previous[next] = cell
				pending.append(next)
	if not previous.has(goal): return []
	var result: Array = [to]
	var cursor := goal
	while cursor != start:
		result.push_front(RoomDefinition.feet_position(cursor))
		cursor = previous[cursor]
	return result


func _safe(tile: Vector2i) -> bool:
	return session.room.definition.in_bounds(tile) and not session.room.definition.is_hazard(tile) and session.room.can_stand_at(RoomDefinition.feet_position(tile))


func _follow(slot: int) -> int:
	var player := session.players[slot]
	while not _paths[slot].is_empty() and player.position.distance_to(_paths[slot][0]) <= 2.0:
		_paths[slot].pop_front()
	if _paths[slot].is_empty(): return 0
	return _direction_mask(_paths[slot][0]-player.position)


static func _direction_mask(delta: Vector2) -> int:
	var mask := 0
	if absf(delta.x)>1.0: mask |= Action.RIGHT if delta.x>0 else Action.LEFT
	if absf(delta.y)>1.0: mask |= Action.DOWN if delta.y>0 else Action.UP
	return mask


func _advance() -> void:
	_step += 1
	_step_ticks = 0
	_paths.assign([[],[]])
	_fight_target_ids.assign([0,0])


func _fail(reason: String) -> void:
	assert_true(false,"%s: room=%s step=%d/%s tick=%d positions=%s" % [reason,session.current_room_id,_step,_steps[_step].kind,_physics_ticks,[session.players[0].position,session.players[1].position]])
	_running = false
