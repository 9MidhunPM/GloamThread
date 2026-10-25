extends Scenario
## Fresh campaign driven only by owned commands and ordinary interaction edges.
## Waypoints choose inputs; they never reposition actors or mutate progression.

const APP := preload("res://scenes/app/boot.tscn")
const Action := CommandSnapshot.Action
var session: GameSession
var app: Control
var _visited: Array[String] = []
var _tick_count := 0
var _route_complete := false


func run() -> void:
	InputRouter.clear(0)
	InputRouter.clear(1)
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.assign(1, DeviceSource.keyboard_right())
	InputRouter.set_test_input(0, 0)
	InputRouter.set_test_input(1, 0)
	app = APP.instantiate() as Control
	var qa_root := "/tmp/gloamthread-campaign-route-%d" % Time.get_ticks_usec()
	app.saves.path = qa_root + "/team_save.json"
	app.settings_store.path = qa_root + "/settings.json"
	add_child(app)
	assert_eq(app.screen, "title", "fresh route starts at actual title")
	app._on_action("new")
	assert_eq(app.screen, "join", "fresh route passes explicit join")
	app._on_action("start")
	session = app.session
	session._focus_pause_enabled = false
	assert_true(session.session_ready, "fresh production campaign starts")
	if session.session_ready:
		await _route()
	assert_true(_route_complete,"the bounded route reaches its final completion assertions")
	# Let the real ending card reach a rendered frame before test teardown.
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)
	if is_instance_valid(app):
		app.free()
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
			break
		await get_tree().process_frame


func _route() -> void:
	_record_room()
	if not await _reach(0, Vector2(248, 320)): return
	await _press(0, Action.INTERACT)
	assert_eq(session.progress.checkpoint_id, "checkpoint_a", "checkpoint A activates through interaction")
	if not await _reach(0,Vector2(328,320)): return
	await _press(0,Action.INTERACT)
	assert_eq(session.dialogue_id,"oru_intro","ordinary interaction reaches Oru's introduction")
	_complete_dialogue_boundary()
	if not await _pair(Vector2(848, 320), Vector2(896, 320)): return
	if not await _exit("r01"): return
	if not await _pair(Vector2(1016, 352), Vector2(1048, 352)): return
	if not await _exit("r02"): return
	# Each courier takes a separate supported staircase to a different anchor.
	for point: Vector2 in [Vector2(232,352), Vector2(248,320), Vector2(280,320), Vector2(312,288), Vector2(368,288), Vector2(408,272), Vector2(504,272)]:
		if not await _reach(0, point, true): return
	for point: Vector2 in [Vector2(1048,352), Vector2(1048,320), Vector2(1032,320), Vector2(1000,288), Vector2(976,288), Vector2(936,272), Vector2(856,272)]:
		if not await _reach(1, point, true): return
	await _press(0, Action.INTERACT)
	assert_true(not session.progress.has_flag("bridge_spindle"), "one courier cannot restore a paired bridge")
	await _press(1, Action.INTERACT)
	assert_true(session.progress.has_flag("bridge_spindle"), "two distinct couriers restore Spindle Steps")
	if not await _pair(Vector2(920,272), Vector2(944,272)): return
	if not await _exit("r03"): return
	if not await _gallery(): return
	if not await _exit("r04"): return
	if not await _reach(0, Vector2(424,320)): return
	await _press(0, Action.INTERACT)
	assert_eq(session.progress.checkpoint_id, "checkpoint_b", "checkpoint B activates through interaction")
	if not await _pair(Vector2(760,320), Vector2(792,320)): return
	if not await _exit("r05"): return
	if not await _boss_fight(): return
	assert_true(session.progress.has_flag("threadstep"), "normal attacks unlock team Threadstep")
	if not await _pair(Vector2(1320,352), Vector2(1352,352)): return
	if not await _exit("r01"): return
	# The unlocked upper route has a ten-tile span; cross it with the actual
	# jump, coyote window and team dash, without falling to the lower stairs.
	for slot in 2:
		if not await _jump_dash_gap(slot,Vector2(672,256),714,858,"ATRIUM_TEN_TILE"): return
		if not await _reach(slot,Vector2(920 + slot * 24,256)): return
	if not await _exit("r06"): return
	for slot in 2:
		if not await _jump_dash_gap(slot,Vector2(408,352),442,570,"CAUSEWAY_NINE_TILE"): return
	# One courier uses each supported approach to the causeway bridge.
	for point: Vector2 in [Vector2(664,352),Vector2(680,320),Vector2(712,320),Vector2(744,288),Vector2(784,288),Vector2(824,272),Vector2(840,272)]:
		if not await _reach(0, point, true): return
	for point: Vector2 in [Vector2(1320,352),Vector2(1336,320),Vector2(1320,320),Vector2(1288,288),Vector2(1256,288),Vector2(1216,272),Vector2(1160,272)]:
		if not await _reach(1, point, true): return
	await _press(0, Action.INTERACT)
	await _press(1, Action.INTERACT)
	assert_true(session.progress.has_flag("bridge_causeway"), "causeway restores through both owned anchors")
	if not await _pair(Vector2(1192,272),Vector2(1240,272)): return
	if not await _exit("r07"): return
	for slot in 2:
		for point: Vector2 in [Vector2(296,352),Vector2(312,320),Vector2(328,320),Vector2(360,304),Vector2(408 + slot * 224,304)]:
			if not await _reach(slot, point, true): return
	await _press(0,Action.INTERACT)
	await _press(1,Action.INTERACT)
	assert_true(session.progress.has_flag("loom_restored"), "the paired Loom stations restore the kingdom")
	assert_eq(session.mode, "dialogue", "restoration opens the authored ending dialogue")
	assert_eq(session.dialogue_id, "ending", "the route reaches the ending sequence")
	_complete_dialogue_boundary()
	if not await _pair(Vector2(904,352),Vector2(952,352)): return
	if not await _exit("r00","ending"): return
	assert_eq(session.mode,"ending","ordinary return-home rally reaches the ending screen state")
	assert_eq(app.screen,"ending","actual app displays the ending card")
	assert_eq(_visited.size(), 8, "fresh normal inputs visit all eight rooms")
	assert_eq(session.recovery_count, 0, "the route does not rely on checkpoint teleports")
	var saved := session.save_repository.load_campaign()
	assert_eq(saved.status,"ok","the isolated campaign save remains valid after the ending")
	assert_true("loom_restored" in saved.data.get("world_flags",[]),"Loom completion survives the actual save boundary")
	print("CAMPAIGN_ROUTE " + JSON.stringify({"visited":_visited,"physics_ticks":_tick_count,"ending":session.mode,"flags":session.progress.flags,"hearts":[session.players[0].hearts,session.players[1].hearts],"dialogue_boundary":_dialogue_boundary_description(),"save_path":session.save_repository.path}))
	_route_complete = true


func _complete_dialogue_boundary() -> void:
	# Invoke the same intent as selecting Skip in the actual owned menu.
	# No actor, room or progression state is changed by the test.
	assert_eq(session.mode,"dialogue","only an active dialogue is completed by the UI boundary")
	app._on_action("skip")

func _dialogue_boundary_description() -> String:
	return "actual app Skip intent"


func _pair(a: Vector2, b: Vector2) -> bool:
	return await _reach(0,a) and await _reach(1,b)


func _reach(slot: int, target: Vector2, jump: bool = false, limit: int = 1000) -> bool:
	InputRouter.set_test_input(slot,0)
	await _ticks(2)
	var room_id := session.current_room_id
	for index in limit:
		var player := session.players[slot]
		if player.downed or session.current_room_id != room_id or session.mode != "playing":
			assert_true(false, "route interrupted in %s P%d at %s toward %s (%s)" % [room_id,slot,player.position,target,session.mode])
			return false
		var dx := target.x-player.position.x
		if absf(dx)<5 and absf(target.y-player.position.y)<2 and player.is_on_floor() and absf(player.velocity.x)<10:
			InputRouter.set_test_input(slot,0)
			return true
		var mask := 0
		if absf(dx)>2:
			mask = Action.RIGHT if dx>0 else Action.LEFT
		if jump and target.y < player.position.y-2 and (absf(dx)<46 or not player.is_on_floor()):
			if not player.is_on_floor() or index%2==0:
				mask |= Action.JUMP
		InputRouter.set_test_input(slot,mask)
		await _ticks(1)
	assert_true(false,"waypoint unreachable in %s P%d at %s toward %s" % [room_id,slot,session.players[slot].position,target])
	return false


func _press(slot: int, action: int) -> void:
	InputRouter.set_test_input(slot,0)
	await _ticks(2)
	InputRouter.set_test_input(slot,action)
	await _ticks(2)
	InputRouter.set_test_input(slot,0)
	await _ticks(2)


func _exit(expected: String, expected_mode: String = "playing") -> bool:
	await _press(0,Action.INTERACT)
	for index in 10:
		await get_tree().process_frame
		if session.current_room_id == expected and session.mode == expected_mode:
			_record_room()
			return true
	assert_true(false,"rally did not enter %s; stayed %s at %s / %s" % [expected,session.current_room_id,session.players[0].position,session.players[1].position])
	return false


func _gallery() -> bool:
	# Cooperate through the ground-level encounter with ordinary attacks.
	for index in 1800:
		if session.players[0].downed or session.players[1].downed:
			assert_true(false,"gallery route downed a courier before checkpoint B")
			return false
		var arrived := true
		for slot in 2:
			var player := session.players[slot]
			var goal := 1336.0 + slot*32
			var mask := Action.RIGHT if player.position.x < goal-3 else 0
			arrived = arrived and player.position.x >= goal-3
			var nearest: CombatEnemy
			var distance := 100.0
			for enemy: CombatEnemy in session.enemies:
				if is_instance_valid(enemy) and not enemy.dead:
					var gap := player.position.distance_to(enemy.position)
					if gap < distance:
						nearest = enemy
						distance = gap
			if nearest != null:
				mask = Action.RIGHT if nearest.position.x > player.position.x else Action.LEFT
				if distance < 38:
					mask |= Action.ATTACK if index%2==0 else 0
				if player.special_cooldown_ticks==0 and index%2==0:
					mask |= Action.SPECIAL
			InputRouter.set_test_input(slot,mask)
		if arrived:
			InputRouter.set_test_input(0,0)
			InputRouter.set_test_input(1,0)
			await _ticks(8)
			return true
		await _ticks(1)
	assert_true(false,"gallery encounter exceeded its bounded input route")
	return false


func _boss_fight() -> bool:
	for index in 2400:
		if session.progress.has_flag("boss_spoolwarden"):
			InputRouter.set_test_input(0,0)
			InputRouter.set_test_input(1,0)
			await _ticks(12)
			return true
		if session.players[0].downed or session.players[1].downed:
			assert_true(false,"ordinary-input boss route downed a courier")
			return false
		var boss := session.boss()
		if boss == null:
			assert_true(false,"boss disappeared before its reward transaction")
			return false
		for slot in 2:
			var player := session.players[slot]
			var dx := boss.position.x-player.position.x
			var mask := Action.RIGHT if dx>=0 else Action.LEFT
			if absf(dx)<38:
				mask |= Action.ATTACK if index%2==0 else 0
			if absf(dx)<70 and player.special_cooldown_ticks==0 and index%2==0:
				mask |= Action.SPECIAL
			InputRouter.set_test_input(slot,mask)
		await _ticks(1)
	assert_true(false,"boss combat exceeded its bounded input route")
	return false


func _jump_dash_gap(slot: int, approach: Vector2, launch_x: float, landing_x: float, label: String) -> bool:
	if not await _reach(slot,approach): return false
	InputRouter.set_test_input(slot,Action.RIGHT)
	for index in 60:
		await _ticks(1)
		if session.players[slot].position.x>=launch_x:
			break
	var launch := session.players[slot].position
	InputRouter.set_test_input(slot,Action.RIGHT|Action.JUMP)
	await _ticks(12)
	InputRouter.set_test_input(slot,Action.RIGHT|Action.JUMP|Action.DASH)
	await _ticks(1)
	InputRouter.set_test_input(slot,Action.RIGHT|Action.JUMP)
	for index in 70:
		await _ticks(1)
		var player := session.players[slot]
		if player.is_on_floor():
			InputRouter.set_test_input(slot,0)
			print(label + " " + JSON.stringify({"slot":slot,"launch":str(launch),"landing":str(player.position),"ticks":index+13}))
			if player.position.x>=landing_x and player.position.y<=approach.y+1:
				return true
			assert_true(false,"%s gap failed through ordinary jump+dash: %s -> %s" % [label,launch,player.position])
			return false
	assert_true(false,"causeway jump+dash did not reach a stable landing")
	return false


func _record_room() -> void:
	if session.current_room_id not in _visited:
		_visited.append(session.current_room_id)
	print("ROUTE_ROOM %s hearts %d/%d" % [session.current_room_id,session.players[0].hearts,session.players[1].hearts])


func _ticks(count: int) -> void:
	_tick_count += count
	await ticks(count)
