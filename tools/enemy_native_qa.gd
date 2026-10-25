extends SceneTree
## Actual native production render, controlled paired actor snapshots; no input route.
class Capture extends Logger:
	var errors: Array[String] = []
	func _log_error(_fn: String,file: String,line: int,code: String,reason: String,_notify: bool,type: int,_trace: Array[ScriptBacktrace]) -> void:
		if type != Logger.ERROR_TYPE_WARNING: errors.append("%s:%d %s" % [file,line,reason if reason!="" else code])

const SOURCES := ["tools/enemy_native_qa.gd","scripts/arena/arena_app.gd","scripts/arena/run_session.gd","scripts/arena/arena_map.gd","scripts/arena/arena_chunk.gd","scripts/arena/arena_presentation.gd","scripts/arena/arena_parallax.gd","scripts/arena/actors/arena_enemy.gd","scripts/arena/actors/arena_fighter.gd","scripts/arena/actors/arena_projectile.gd","assets/arena/enemies/index.json"]
var output := "/tmp/gloamthread-enemy-native"
var app: Node
var world: Node
var presentation: Node
var router: Node
var capture := Capture.new()
var cases: Array[Dictionary] = []

func _initialize() -> void:
	OS.add_logger(capture)
	call_deferred("_run")

func _run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==2 and args[0]=="--output" and args[1].begins_with("/tmp/"): output=args[1]
	elif not args.is_empty():
		printerr("Usage: -- --output /tmp/enemy-captures");quit(2);return
	if DisplayServer.get_name()=="headless":
		printerr("Native display required; this fixture is not a headless screenshot generator.");quit(2);return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:
		printerr("Cannot create fixture output directory.");quit(1);return
	var before:=_hashes()
	root.size=Vector2i(1920,1080)
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	router=root.get_node("InputRouter")
	app=load("res://scripts/arena/arena_app.gd").new()
	app.settings_store.path=output.path_join("fixture-settings.json")
	app.records.path=output.path_join("fixture-records.json")
	root.add_child(app)
	await process_frame
	app._show_lobby(1);app._begin_run(18427)
	world=app.session;presentation=app.presentation
	if not is_instance_valid(world) or world.phase=="error":
		printerr("Actual production session failed to start.");quit(1);return
	world.set_physics_process(false);presentation.set_physics_process(false)
	world.spawn_queue.clear();world.telegraphs.clear();world._set_phase("combat")
	world.fighters[0].set_physics_process(false)
	world.fighters[0].position=Vector2(300,320)
	world.fighters[0].immunity_ticks=10000
	router.set_test_input(0,0)
	for tick in 60: presentation._physics_process(1.0/60.0)
	presentation._snap=true;presentation._update_cameras(0)
	app._update_hud()
	var left:=_actor("charger",Vector2(168,320),"windup",36)
	var right:=_actor("charger",Vector2(485,320),"recover",52)
	await _capture("charge_tell_recovery","Left: locked112px charge lane. Right:52tick recovery. Two explicitly placed same-role actors.")
	_clear()
	left=_actor("heavy",Vector2(145,320),"approach",0)
	right=_actor("heavy",Vector2(465,320),"recover",48)
	await _capture("heavy_guard_counter","Left: guarded approach. Right: broken/recovering teal shield brackets; controlled recovery state, no claimed player counter input.")
	_clear()
	left=_actor("shooter",Vector2(160,320),"windup",32)
	right=_actor("shooter",Vector2(515,320),"windup",1)
	await _step(right,12)
	await _capture("shooter_aim_burst","Left: stationary locked-aim tell. Right: real burst advanced12manual60Hz actor/projectile ticks, two shots emitted. Fighter has fixture immunity.")
	_clear()
	left=_actor("flyer",Vector2(180,220),"windup",34)
	right=_actor("flyer",Vector2(420,220),"windup",1)
	await _step(right,11)
	await _capture("flyer_mark_dive","Left: announced fixed landing mark. Right: committed dive advanced11manual60Hz actor ticks. Same production shared world.")
	var report:Dictionary={"fixture":"Controlled paired role snapshots in actual production App/session. Explicit positions, states and manual60Hz stepping; frozen encounter/fighter, fixture immunity10000, temporary settings/records. Native offscreen force_draw; no normal-input, performance or human-playtest claim.","engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"renderer":RenderingServer.get_video_adapter_name(),"root_size":[root.size.x,root.size.y],"source_sha256":before,"source_changed":before!=_hashes(),"cases":cases,"errors":capture.errors}
	report.passed=capture.errors.is_empty() and not report.source_changed and cases.size()==4
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	if file==null: report.passed=false
	else: file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
	print("ENEMY_NATIVE_QA ",JSON.stringify(report))
	app.free();router.clear_test_input();router.clear(0)
	await _retire_audio()
	quit(0 if report.passed else 1)

func _actor(role: String,at: Vector2,state: String,ticks: int) -> Node:
	world._spawn_enemy({"role":role,"boss":"","elite":false,"position":at})
	var enemy:Node=world.enemies.back()
	enemy.set_physics_process(false)
	enemy._target_point=world.fighters[0].position
	enemy._attack_point=world.fighters[0].get_hurt_rect().get_center()
	enemy._aim=(enemy._attack_point-enemy.get_hurt_rect().get_center()).normalized()
	enemy._facing=1 if enemy._aim.x>=0 else -1
	enemy._enter(state,ticks);enemy._update_visual()
	return enemy

func _step(enemy: Node,count: int) -> void:
	for tick in count:
		paused=false
		if app.screen=="pause": app._resume()
		await physics_frame
		enemy._physics_process(1.0/60.0)
		for projectile: Node in get_nodes_in_group("arena_projectiles"):
			projectile.set_physics_process(false)
			projectile._physics_process(1.0/60.0)

func _clear() -> void:
	for enemy: Node in world.enemies: enemy.free()
	world.enemies.clear()
	for projectile: Node in get_nodes_in_group("arena_projectiles"): projectile.free()
	for effect: Node in world.effect_root.get_children(): effect.free()

func _capture(label: String,note: String) -> void:
	paused=false
	if app.screen=="pause": app._resume()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var image:=root.get_texture().get_image()
	var path:=output.path_join(label+".png")
	if image==null or image.is_empty() or image.get_size()!=Vector2i(1920,1080) or image.save_png(path)!=OK:
		capture.errors.append("Missing/invalid actual native image: "+label)
	var actors:Array[Dictionary]=[]
	for enemy:Node in world.enemies:
		actors.append({"role":enemy.role,"state":enemy._state,"ticks":enemy._state_ticks,"position":[enemy.position.x,enemy.position.y],"aim":[enemy._aim.x,enemy._aim.y],"mark":[enemy._target_point.x,enemy._target_point.y]})
	cases.append({"name":label,"note":note,"actors":actors,"projectiles":get_nodes_in_group("arena_projectiles").size(),"same_world":presentation.viewport_a.world_2d==presentation.viewport_b.world_2d,"sha256":FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""})

func _hashes() -> Dictionary:
	var result:Dictionary={}
	for path:String in SOURCES: result[path]=FileAccess.get_sha256("res://"+path)
	return result

func _retire_audio() -> void:
	var audio:=root.get_node("AudioDirector")
	var voices:Array[WeakRef]=[]
	for voice:Node in audio.get_children():
		if voice is AudioStreamPlayer and voice.has_stream_playback(): voices.append(weakref(voice.get_stream_playback()))
	audio.stop_music();audio.stop_cues()
	var deadline:=Time.get_ticks_msec()+1000
	while Time.get_ticks_msec()<deadline and voices.any(func(voice:WeakRef)->bool:return voice.get_ref()!=null): await process_frame
