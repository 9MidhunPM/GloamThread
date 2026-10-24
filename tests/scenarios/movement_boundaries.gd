extends Scenario
## Every command is assigned before InputRouter's physics tick and sampled after
## both actors. No coroutine advances the command clock or skips a physics step.

const PLAYER := preload("res://scenes/actors/player.tscn")
const Action := CommandSnapshot.Action
const CASES := ["full_jump", "short_jump", "fall_baseline", "buffer_six", "buffer_seven", "coyote_five", "coyote_six", "coyote_seven", "one_way_up", "one_way_down", "corner", "replay"]

class TickObserver extends Node:
	var target: Node
	func _physics_process(_delta: float) -> void:
		target._after_tick()

var _players: Array[PlayerController] = []
var _progress := TeamProgress.new()
var _case_index := -1
var _case_tick := 0
var _active := false
var _done := false
var _apex := 320.0
var _full_rise := 0.0
var _short_rise := 0.0
var _landing_tick := 0
var _off_ticks := 0
var _pressed := false
var _jumped := false
var _coyote_before := -1
var _trace: Array = []
var _boundary_results := {}


func run() -> void:
	process_physics_priority = -1000
	var world := Node2D.new()
	add_child(world)
	_floor(world,"Floor",Vector2(1000,328),Vector2(2000,16),false)
	_floor(world,"Ledge",Vector2(128,248),Vector2(256,16),false)
	_floor(world,"OneWayCollision",Vector2(500,296),Vector2(200,16),true)
	_floor(world,"CornerWall",Vector2(908,288),Vector2(16,64),false)
	_progress.commit_flags(["boss_spoolwarden","threadstep","shortcut_bell"])
	for slot in 2:
		InputRouter.clear(slot)
		InputRouter.assign(slot,DeviceSource.keyboard_left() if slot==0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot,0)
		var player := PLAYER.instantiate() as PlayerController
		player.slot_index=slot
		player.configure({"id":"tavi_fixed" if slot==0 else "neri_fixed","max_hearts":5 if slot==0 else 4,"special_id":"ember_arc" if slot==0 else "spore_bolt"},null,_progress)
		player.room_bounds=Rect2(0,0,2000,500)
		world.add_child(player)
		_players.append(player)
	var observer := TickObserver.new()
	observer.target=self
	observer.process_physics_priority=1000
	add_child(observer)
	_next_case()
	while not _done:
		await get_tree().process_frame
	assert_eq(_trace.size(),600,"render-cap replay records exactly 600 physics steps")
	var fps := _render_cap()
	var result := {"render_cap":fps,"physics_hz":Engine.physics_ticks_per_second,"physics_ticks":_trace.size(),"trace":_trace,"health":[_players[0].hearts,_players[1].hearts],"unlocks":_progress.to_save().team_unlocks,"boundaries":_boundary_results}
	var output := "/tmp/gloamthread-render-cap-%d.json" % fps
	var file := FileAccess.open(output,FileAccess.WRITE)
	assert_true(file!=null,"render-cap evidence file opens")
	if file!=null:
		file.store_string(JSON.stringify(result))
		file.close()
	print("MOVEMENT_BOUNDARIES "+JSON.stringify({"render_cap":fps,"physics_ticks":_trace.size(),"full_jump_rise":_full_rise,"short_jump_rise":_short_rise,"boundaries":_boundary_results,"evidence":output}))
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)


func _next_case() -> void:
	_case_index+=1
	if _case_index>=CASES.size():
		_active=false
		_done=true
		return
	_case_tick=0
	_apex=320.0
	_off_ticks=0
	_pressed=false
	_jumped=false
	_coyote_before=-1
	for slot in 2:
		InputRouter.set_test_input(slot,0)
		_players[slot].restore(Vector2(700+slot*40,320))
	var label: String=CASES[_case_index]
	if label in ["fall_baseline","buffer_six","buffer_seven"]:
		_players[0].restore(Vector2(700,240))
	elif label.begins_with("coyote"):
		_players[0].restore(Vector2(240,240))
	elif label=="one_way_up":
		_players[0].restore(Vector2(500,320))
	elif label=="one_way_down":
		_players[0].restore(Vector2(480,288))
		_players[1].restore(Vector2(540,288))
	elif label=="corner":
		_players[0].restore(Vector2(870,320))
	elif label=="replay":
		_players[0].restore(Vector2(640,320))
		_players[1].restore(Vector2(720,320))
	_active=true


func _physics_process(_delta: float) -> void:
	if not _active:return
	_case_tick+=1
	var label: String=CASES[_case_index]
	var mask:=0
	match label:
		"full_jump":
			if _case_tick>=10 and _case_tick<=60:mask=Action.JUMP
		"short_jump":
			if _case_tick==10:mask=Action.JUMP
		"buffer_six","buffer_seven":
			var window:=6 if label=="buffer_six" else 7
			if _case_tick>=_landing_tick-window+1:mask=Action.JUMP
		"coyote_five","coyote_six","coyote_seven":
			mask=Action.RIGHT
			if not _players[0].is_on_floor() and _case_tick>2:
				_off_ticks+=1
			var window: int={"coyote_five":5,"coyote_six":6,"coyote_seven":7}[label]
			if _off_ticks>=window:
				mask|=Action.JUMP
				if not _pressed:
					_coyote_before=_players[0].get("_coyote_ticks")
					_pressed=true
		"one_way_up":
			if _case_tick>=10 and _case_tick<=60:mask=Action.JUMP
		"one_way_down":
			if _case_tick==10:mask=Action.DOWN|Action.JUMP
		"corner":
			mask=Action.RIGHT
			if _case_tick>=20 and _case_tick<45:mask|=Action.JUMP
		"replay":
			mask=_replay_mask(0,_case_tick)
	InputRouter.set_test_input(0,mask)
	InputRouter.set_test_input(1,_replay_mask(1,_case_tick) if label=="replay" else 0)


func _after_tick() -> void:
	if not _active or _case_tick==0:return
	var label: String=CASES[_case_index]
	var player:=_players[0]
	_apex=minf(_apex,player.position.y)
	if label=="fall_baseline" and player.is_on_floor() and _landing_tick==0:
		_landing_tick=_case_tick
	if label.begins_with("buffer") or (label.begins_with("coyote") and _pressed):
		_jumped=_jumped or player.velocity.y< -100.0
	if label=="corner":
		assert_true(player.position.x<=894.1,"solid corner blocks the entire moving courier body")
	if label=="replay":
		_trace.append([player.position.x,player.position.y,_players[1].position.x,_players[1].position.y])
	var duration:=600 if label=="replay" else 90
	if _case_tick<duration:return
	match label:
		"full_jump":
			_full_rise=320.0-_apex
			assert_true(_full_rise>40 and _full_rise<44,"full held jump reaches the authored physical envelope")
		"short_jump":
			_short_rise=320.0-_apex
			assert_true(_short_rise>5 and _short_rise<_full_rise*0.6,"releasing jump produces a distinctly shorter arc")
		"fall_baseline":
			assert_true(_landing_tick>7,"fall fixture leaves room to measure six/seven-tick buffers")
		"buffer_six":
			assert_true(_jumped,"a jump buffered six inclusive ticks before landing launches")
			_boundary_results[label]={"jumped":_jumped,"landing_tick":_landing_tick}
		"buffer_seven":
			assert_true(not _jumped,"a jump buffered seven inclusive ticks before landing expires")
			_boundary_results[label]={"jumped":_jumped,"landing_tick":_landing_tick}
		"coyote_five":
			assert_true(_jumped,"fifth airborne tick is a control inside the coyote window")
			_boundary_results[label]={"jumped":_jumped,"remaining_on_press":_coyote_before}
		"coyote_six":
			assert_true(_jumped,"jump remains available on the sixth airborne physics tick after a ledge")
			_boundary_results[label]={"jumped":_jumped,"remaining_on_press":_coyote_before}
		"coyote_seven":
			assert_true(not _jumped,"jump expires on the seventh airborne physics tick after a ledge")
			_boundary_results[label]={"jumped":_jumped,"remaining_on_press":_coyote_before}
		"one_way_up":
			assert_true(_apex<288 and player.is_on_floor() and absf(player.position.y-288)<0.1,"jump passes upward through a one-way and lands on top")
		"one_way_down":
			assert_true(player.is_on_floor() and absf(player.position.y-320)<0.1,"down-jump passes the one-way and keeps solid floor collision")
			assert_true(_players[1].is_on_floor() and absf(_players[1].position.y-288)<0.1,"partner's one-way collision remains intact")
		"corner":
			assert_true(player.is_on_floor() and absf(player.position.y-320)<0.1,"wall corner contact returns to the canonical floor")
	_next_case()


func _replay_mask(slot: int,tick: int) -> int:
	var phase:=posmod(tick-1,240)
	var right:=phase<120
	if slot==1:right=not right
	var mask:=Action.RIGHT if right else Action.LEFT
	if posmod(tick-1+slot*30,180)>=30 and posmod(tick-1+slot*30,180)<50:mask|=Action.JUMP
	if tick in ([90,270,450] if slot==0 else [150,330,510]):mask|=Action.DASH
	return mask


func _floor(parent: Node,name_text: String,position_value: Vector2,size_value: Vector2,one_way: bool) -> void:
	var body:=StaticBody2D.new()
	body.name=name_text
	body.position=position_value
	body.collision_layer=1
	body.collision_mask=0
	var shape:=CollisionShape2D.new()
	var rectangle:=RectangleShape2D.new()
	rectangle.size=size_value
	shape.shape=rectangle
	shape.one_way_collision=one_way
	shape.one_way_collision_margin=4
	body.add_child(shape)
	parent.add_child(body)


func _render_cap() -> int:
	# Godot consumes its --fixed-fps flag before exposing script arguments.
	return int(OS.get_environment("GLOAMTHREAD_RENDER_CAP"))
