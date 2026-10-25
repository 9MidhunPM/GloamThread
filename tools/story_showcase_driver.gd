extends "res://tests/scenarios/campaign_route.gd"
## The existing owned-input campaign route, kept alive for native viewing.
## Only smoke suppresses focus-loss pause. The wrapper owns dialogue and cleanup.

var temporary_dir: String = ""
var cancelled: bool = false
var smoke: bool = false


func run() -> void:
	for slot in 2:
		InputRouter.clear(slot)
		InputRouter.assign(slot,DeviceSource.keyboard_left() if slot==0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot,0)
	temporary_dir="/tmp/gloamthread-story-showcase-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	app=APP.instantiate() as Control
	app.saves.path=temporary_dir+"/team_save.json"
	app.settings_store.path=temporary_dir+"/settings.json"
	add_child(app)
	assert_eq(app.screen,"title","showcase starts at the production Story title")
	app._on_action("new")
	assert_eq(app.screen,"join","showcase selects a new campaign through the actual join screen")
	app._on_action("start")
	session=app.session
	assert_true(is_instance_valid(session) and session.session_ready,"showcase creates the production shared campaign")
	if not is_instance_valid(session) or not session.session_ready:return
	session._focus_pause_enabled=not smoke
	await _route()
	assert_true(_route_complete,"sequential showcase reaches every inherited completion assertion")
	# The wrapper retains the ending card, report and audio lifecycle. Never free
	# App here: viewers must be able to inspect the actual final campaign state.
	await get_tree().process_frame
	await get_tree().process_frame


func _complete_dialogue_boundary() -> void:
	assert_true(session.mode in ["dialogue", "playing"], "authored dialogue reaches its viewing boundary")
	# No Skip intent. The wrapper advances each authored line with the real Next
	# menu action; the route waits in _ticks while that dialogue pauses the world.


func _ticks(count: int) -> void:
	var completed:=0
	while completed<count:
		while cancelled or not is_instance_valid(session) or get_tree().paused:
			# Release the held interaction edge at a modal boundary. _reach waits
			# for every authored line; terminal ending must reach route assertions.
			if not cancelled and is_instance_valid(session) and session.mode in ["dialogue","ending"]:return
			await get_tree().process_frame
		await get_tree().physics_frame
		if cancelled or not is_instance_valid(session):continue
		if get_tree().paused:
			if session.mode in ["dialogue","ending"]:return
			continue
		_tick_count+=1
		completed+=1

func _reach(slot: int, target: Vector2, jump: bool = false, limit: int = 1000) -> bool:
	# Interaction edges may open dialogue during _press. Let that input finish,
	# then wait for every authored line before starting the next movement leg.
	while get_tree().paused or cancelled:
		await get_tree().process_frame
	return await super._reach(slot, target, jump, limit)

func _dialogue_boundary_description() -> String:
	return "actual App Next intent for every authored line"


func _gallery() -> bool:
	if not await super._gallery():return false
	# The base route reaches the exit without requiring every flyer to die.
	# Finish those foes with actual co-op attacks before leaving Neri unattended.
	if not await _clear_gallery():return false
	if not await _pair(Vector2(1336,352),Vector2(1368,352)):return false
	var stairs:Array[Vector2]=[Vector2(136,352),Vector2(176,320),Vector2(240,320),
		Vector2(272,288),Vector2(336,288),Vector2(368,256),Vector2(432,256),
		Vector2(464,224),Vector2(520,224),Vector2(568,208),Vector2(616,208)]
	for point:Vector2 in stairs:
		if not await _reach(0,point,true):return false
	assert_true(session.progress.has_flag("lantern_charm"),"ordinary staircase traversal collects the actual gallery secret")
	if not session.progress.has_flag("lantern_charm"):return false
	print("STORY_SHOWCASE_SECRET "+JSON.stringify({"room":session.current_room_id,"flag":"lantern_charm","position":str(session.players[0].position),"physics_ticks":_tick_count}))
	for index in range(stairs.size()-2,-1,-1):
		if not await _reach(0,stairs[index]):return false
	return await _pair(Vector2(1336,352),Vector2(1368,352))


func _clear_gallery() -> bool:
	for tick in 2400:
		var foes:Array[CombatEnemy]=[]
		for enemy:CombatEnemy in session.enemies:
			if is_instance_valid(enemy) and not enemy.dead:foes.append(enemy)
		if foes.is_empty() and not session.players[0].downed and not session.players[1].downed:
			InputRouter.set_test_input(0,0);InputRouter.set_test_input(1,0)
			await _ticks(8)
			print("STORY_GALLERY_CLEARED "+JSON.stringify({"physics_ticks":_tick_count,"hearts":[session.players[0].hearts,session.players[1].hearts]}))
			return true
		for slot in 2:
			var player:PlayerController=session.players[slot]
			if player.downed:
				InputRouter.set_test_input(slot,0)
				continue
			var nearest:CombatEnemy
			var distance:=INF
			for enemy:CombatEnemy in foes:
				var gap:=player.position.distance_to(enemy.position)
				if gap<distance:distance=gap;nearest=enemy
			var mask:=0
			if nearest!=null:
				var gap:Vector2=nearest.position-player.position
				if absf(gap.x)>18 or player.facing!=int(signf(gap.x)):
					mask=Action.RIGHT if gap.x>=0 else Action.LEFT
				if absf(gap.x)<70 and absf(gap.y)<80 and tick%2==0:
					mask|=Action.ATTACK
					if player.special_cooldown_ticks==0:mask|=Action.SPECIAL
				if nearest.kind=="wickwing" and gap.y<-28 and tick%40<25:mask|=Action.JUMP
			var partner:PlayerController=session.players[1-slot]
			if partner.downed:
				var dx:=partner.position.x-player.position.x
				if absf(dx)>24:mask=(mask&~(Action.LEFT|Action.RIGHT))|(Action.RIGHT if dx>0 else Action.LEFT)
				if player.position.distance_to(partner.position)<=36:mask|=Action.INTERACT
			InputRouter.set_test_input(slot,mask)
		await _ticks(1)
	assert_true(false,"gallery survivors exceeded the bounded ordinary-input cleanup")
	return false
