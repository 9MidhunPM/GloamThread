extends "res://tools/story_showcase.gd"

var checked := false
var pause_frames := 0
var frozen_tick := 0
var shots: Dictionary = {}

func _process(delta: float) -> bool:
	super._process(delta)
	if not is_instance_valid(driver) or not is_instance_valid(driver.session): return false
	if not checked and driver._tick_count > 100 and driver.session.mode == "playing":
		checked = true
		_key(KEY_SPACE)
		frozen_tick = driver._tick_count
	if checked and pause_frames < 8:
		pause_frames += 1
		if pause_frames == 7:
			print("STORY_NATIVE_CONTROLS ",JSON.stringify({"pause":viewer_paused,"frozen":frozen_tick==driver._tick_count}))
			_key(KEY_4)
			_key(KEY_SPACE)
			print("STORY_NATIVE_RESUME ",JSON.stringify({"resumed":not viewer_paused,"speed":options.speed}))
	var label := ""
	if driver.session.progress.has_flag("lantern_charm") and driver.session.current_room_id == "r03":label="secret"
	if driver.session.current_room_id == "r05" and is_instance_valid(driver.session.boss()) and driver.session.boss().animation_state.ends_with("_active"):label="boss"
	if driver.session.mode == "ending":label="ending"
	if label != "" and not shots.has(label):
		shots[label]=true
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("/tmp/gloamthread-story-"+label+".png")
		print("STORY_NATIVE_CAPTURE ",label)
	return false

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	overlay._input(event)
