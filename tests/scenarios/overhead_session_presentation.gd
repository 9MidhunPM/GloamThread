extends Scenario
## Controlled production-asset presentation gates; not ordinary route/balance evidence.
const SESSION := preload("res://scenes/session/session.tscn")
var _session: GameSession
var _tracks: Array[StringName] = []


func run() -> void:
	for slot in 2:
		InputRouter.clear(slot)
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
	AudioDirector.music_changed.connect(_on_track)
	_session = SESSION.instantiate() as GameSession
	_session.set("_focus_pause_enabled", false)
	add_child(_session)
	assert_true(_session.session_ready, "production presentation fixture starts: %s" % _session.startup_error)
	if _session.session_ready:
		await _entry_titles()
		await _boss_phase_music()
	get_tree().paused = false
	_session.free()
	AudioDirector.music_changed.disconnect(_on_track)
	for slot in 2:
		InputRouter.set_test_input(slot, 0)
		InputRouter.clear_test_input(slot)
		InputRouter.clear(slot)
	await _retire_audio()


func _entry_titles() -> void:
	var view := _session.presentation
	var labels: Array = view.get("_room_title_labels")
	var panels: Array = view.get("_room_title_panels")
	assert_eq(labels.size(),2,"both split views have a room title")
	for label: Label in labels:
		assert_eq(label.text,"Lantern Rest","entry uses the actual authored room name")
		assert_true(label.get_theme_font("font") == _session.catalog.assets.font(),"entry uses the retained original font")
	assert_eq(view.room_title_ticks_left,120,"room title begins with a two-second physics budget")
	await _ticks(20)
	var remaining := view.room_title_ticks_left
	_session.request_mode("pause",0)
	await _ticks(15)
	assert_eq(view.room_title_ticks_left,remaining,"shared pause freezes title duration")
	_session.request_mode("playing",0)
	await _ticks(remaining-10)
	for panel: Control in panels:
		assert_true(panel.visible and panel.modulate.a > 0.0 and panel.modulate.a < 1.0,"title has a restrained final fade in both views")
	await _ticks(10)
	assert_eq(view.room_title_ticks_left,0,"title expires after exactly 120 playing physics ticks")
	for panel: Control in panels:
		assert_true(not panel.visible,"expired title does not obstruct play")


func _boss_phase_music() -> void:
	assert_true(_session.call("_load_room","r05","from_r04",true),"controlled fixture enters actual Broken Bell")
	for label: Label in _session.presentation.get("_room_title_labels"):
		assert_eq(label.text,"Broken Bell","new room replaces both title names")
	assert_eq(_session.presentation.room_title_ticks_left,120,"room replacement restarts the title budget")
	var enemy := _session.boss()
	assert_true(enemy != null,"one live boss is available")
	if enemy == null:
		return
	for player in _session.players:
		player.set_physics_process(false)
	enemy.set_physics_process(false)
	assert_eq(AudioDirector.current_track(),&"boss","phase one uses the base boss track")
	enemy.receive_hit(15,0,CombatQuery.next_attack_id())
	await _ticks(1)
	assert_eq(enemy.phase,2,"controlled damage reaches the actual phase transition")
	assert_eq(AudioDirector.current_track(),&"boss_final","phase two switches to the optional aligned intensity track")
	assert_eq(_tracks.count(&"boss_final"),1,"phase transition emits exactly one music change")
	await _ticks(20)
	assert_eq(_tracks.count(&"boss_final"),1,"ordinary HUD refresh never restarts the phase track")
	AudioDirector.stop_music()
	await _ticks(2)
	assert_eq(_tracks.count(&"boss_final"),1,"phase latch does not reissue playback after an external stop")
	assert_eq(AudioDirector.current_track(),&"","stopped phase music remains stopped without a new encounter")
	enemy.receive_hit(100,1,CombatQuery.next_attack_id())
	assert_eq(AudioDirector.current_track(),&"exploration","boss defeat restores exploration once")
	await _ticks(2)
	assert_eq(_tracks.count(&"boss_final"),1,"defeated boss cannot restart its phase music")


func _on_track(track: StringName) -> void:
	_tracks.append(track)


func _ticks(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _retire_audio() -> void:
	var pending: Array[WeakRef] = []
	for node: Node in AudioDirector.get_children():
		if node is AudioStreamPlayer and node.has_stream_playback():
			pending.append(weakref(node.get_stream_playback()))
	AudioDirector.stop_music()
	AudioDirector.stop_cues()
	var deadline := Time.get_ticks_msec()+1000
	while Time.get_ticks_msec()<deadline:
		var alive := false
		for playback in pending:
			alive = alive or playback.get_ref()!=null
		if not alive: return
		await get_tree().process_frame
	assert_true(false,"presentation fixture audio retires after stopping")
