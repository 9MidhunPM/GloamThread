extends Scenario
## Controlled nearby placement isolates actual App dialogue/gate integration.
## The separate campaign route must navigate here with ordinary movement.
const App := preload("res://scripts/app/app_controller.gd")
const Action := CommandSnapshot.Action

func run() -> void:
	for finish: String in ["skip", "next", "cancel"]:
		var app := App.new()
		var folder := "user://overhead-intro-%s-%d" % [finish,Time.get_ticks_usec()]
		app.saves.path = folder + "/team.json"
		app.settings_store.path = folder + "/settings.json"
		add_child(app)
		assert_eq(app.screen,"title","actual overhead App validates all production data")
		app._on_action("new")
		app._on_action("start")
		assert_true(app.session != null and app.session.session_ready,"new overhead journey starts")
		if app.session == null or not app.session.session_ready:
			app.free()
			continue
		var session: GameSession = app.session
		session._focus_pause_enabled = false
		var oru: Dictionary = {}
		for entity: Dictionary in session.room.definition.entities:
			if entity.type == "npc": oru = entity
		assert_true(not oru.is_empty(),"authored Lantern Rest has Oru")
		session.players[0].reset_at(RoomDefinition.feet_position(Vector2i(int(oru.tile[0]),int(oru.tile[1]))) + Vector2(-24,0))
		InputRouter.set_test_input(0,0)
		InputRouter.set_test_input(1,0)
		await _steps(2)
		InputRouter.set_test_input(0,Action.INTERACT)
		await _steps(2)
		InputRouter.set_test_input(0,0)
		assert_eq(app.screen,"dialogue","owned nearby interaction opens the production dialogue screen")
		assert_true(not session.progress.has_flag("met_oru"),"introduction is pending while open")
		if finish == "next":
			for _line in app.catalog.dialogue_sequence("oru_intro").size(): app._on_action("next")
		else:
			app._on_action(finish)
		assert_eq(app.screen,"playing","%s completes the introduction without a softlock" % finish)
		assert_true(session.progress.has_flag("met_oru"),"%s commits shared introduction once" % finish)
		var saved := app.saves.load_campaign()
		assert_eq(saved.status,"ok","introduction is durable")
		assert_true("met_oru" in saved.data.get("world_flags",[]),"saved intro opens the first gate after Continue")
		assert_true(session.guidance().get("id") != "meet_oru","HUD advances to the next mission")
		app.free()
		get_tree().paused = false
		InputRouter.clear_test_input()
		InputRouter.clear(0)
		InputRouter.clear(1)
		await get_tree().process_frame

func _steps(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame
		await get_tree().process_frame
