extends Scenario
## Controlled production-room placements isolate secret/progress transactions.
## This is not evidence of an ordinary-input route to the secret.

const SESSION := preload("res://scenes/session/session.tscn")
var _session: GameSession
var _directory: String


func run() -> void:
	_directory = "user://secret-progression-%d" % Time.get_ticks_usec()
	InputRouter.clear(0)
	InputRouter.clear(1)
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.assign(1, DeviceSource.keyboard_right())
	InputRouter.set_test_input(0, 0)
	InputRouter.set_test_input(1, 0)
	var catalog := ContentCatalog.load_bundle()
	var repository := SaveRepository.new()
	repository.path = _directory.path_join("team.json")
	_session = SESSION.instantiate() as GameSession
	_session.configure(catalog, TeamProgress.new(), repository)
	_session._focus_pause_enabled = false
	add_child(_session)
	assert_true(_session.session_ready, "production secret fixture starts: %s" % _session.startup_error)
	if not _session.session_ready:
		await _cleanup()
		return
	assert_true(_session._load_room("r03", "from_r02", true), "controlled placement loads actual secret room")
	_freeze_actors()
	var secret := _secret()
	var sprite: Sprite2D = _session.room._visuals[secret.id]
	assert_true(sprite.visible, "uncollected secret begins visible")
	var stats_before := _player_stats()
	var checkpoint_before := _session.progress.checkpoint_id
	var collision_before := _collision_ids(_session.room.collision)
	var sounds_before := int(AudioDirector.emission_counts.get(&"checkpoint", 0))
	var notices := []
	_session.notice.connect(func(message: String) -> void: notices.append(message))
	# Both players may reach the same collectible during one authoritative tick.
	_place_at_secret(secret)
	await _steps(1)
	assert_true(_session.progress.has_flag("lantern_charm"), "secret commits the one shared cosmetic flag")
	assert_eq(_session.progress.flags, {"lantern_charm": true}, "cosmetic reward grants no unrelated world or traversal flag")
	assert_eq(_session.progress.to_save().secret_flags, ["lantern_charm"], "secret reward is committed once")
	assert_eq(int(AudioDirector.emission_counts.get(&"checkpoint", 0)) - sounds_before, 1, "simultaneous collection emits one reward cue")
	assert_eq(notices.size(), 1, "simultaneous collection emits one shared reward notice")
	assert_true(not sprite.visible, "secret prop hides immediately after collection")
	assert_eq(_player_stats(), stats_before, "cosmetic secret changes no health, special, or team traversal")
	assert_eq(_session.progress.checkpoint_id, checkpoint_before, "secret does not move the safe checkpoint")
	assert_eq(_collision_ids(_session.room.collision), collision_before, "secret adds no traversal collision")
	_assert_charms()
	await _steps(3)
	assert_eq(int(AudioDirector.emission_counts.get(&"checkpoint", 0)) - sounds_before, 1, "remaining beside the secret never repeats its cue")
	var saved := repository.load_campaign()
	assert_eq(saved.status, "ok", "secret autosaves through actual serialization")
	var progress := TeamProgress.new()
	assert_true(progress.load_save(saved.data), "saved secret state passes the team boundary")
	_session.free()
	_session = SESSION.instantiate() as GameSession
	_session.configure(catalog, progress, repository, true)
	_session._focus_pause_enabled = false
	add_child(_session)
	assert_true(_session.session_ready and _session.current_room_id == "r00", "Continue loads the canonical checkpoint instead of arbitrary secret coordinates")
	_freeze_actors()
	assert_true(_session.progress.has_flag("lantern_charm"), "secret flag survives campaign reload")
	_assert_charms()
	assert_true(_session._load_room("r03", "from_r02", true), "revisit actual secret room after Continue")
	_freeze_actors()
	secret = _secret()
	sprite = _session.room._visuals[secret.id]
	assert_true(not sprite.visible, "collected secret stays hidden on room rebuild")
	sounds_before = int(AudioDirector.emission_counts.get(&"checkpoint", 0))
	_place_at_secret(secret)
	await _steps(2)
	assert_eq(int(AudioDirector.emission_counts.get(&"checkpoint", 0)), sounds_before, "revisited collected secret grants no duplicate reward")
	_assert_charms()
	var progress_before := _session.progress.to_save()
	stats_before = _player_stats()
	collision_before = _collision_ids(_session.room.collision)
	var actor_count := _session.presentation.actors.get_child_count()
	_session.presentation.set_themes(catalog.assets, "moss", "ember")
	await _steps(1)
	assert_eq(_session.presentation.viewport_a.canvas_cull_mask, 5, "first viewport can select Moss")
	assert_eq(_session.presentation.viewport_b.canvas_cull_mask, 3, "second viewport can select Ember")
	assert_eq(_player_stats(), stats_before, "theme swap cannot change player health, special, or traversal")
	assert_eq(_session.progress.to_save(), progress_before, "theme swap cannot change team progress")
	assert_eq(_collision_ids(_session.room.collision), collision_before, "theme swap retains the exact authoritative collision nodes")
	assert_eq(_session.presentation.actors.get_child_count(), actor_count, "theme swap creates no duplicate gameplay actors")
	assert_eq(_session.room.theme_gameplay_node_count(), 0, "both theme layers remain render-only")
	await _cleanup()


func _secret() -> Dictionary:
	for entity: Dictionary in _session.room.definition.entities:
		if entity.type == "secret":
			return entity
	assert_true(false, "production room contains the one authored secret")
	return {}


func _place_at_secret(secret: Dictionary) -> void:
	var centre := GameSession._centre(secret.tile)
	_session.players[0].reset_at(centre + Vector2(-8, 0))
	_session.players[1].reset_at(centre + Vector2(8, 0))


func _freeze_actors() -> void:
	for player: PlayerController in _session.players:
		player.set_physics_process(false)
	for enemy: CombatEnemy in _session.enemies:
		enemy.set_physics_process(false)


func _player_stats() -> Array:
	var stats := []
	for player: PlayerController in _session.players:
		stats.append([player.max_hearts, player.hearts, player.special_id, player.downed])
	stats.append(_session.progress.has_flag("threadstep"))
	return stats


func _assert_charms() -> void:
	for player: PlayerController in _session.players:
		var charms := 0
		for child: Node in player.get_children():
			if child.name == "LanternCharm":
				charms += 1
				assert_true(child is Sprite2D and child.texture != null, "shared charm has original cosmetic artwork")
		assert_eq(charms, 1, "each courier carries exactly one cosmetic charm")


func _collision_ids(node: Node) -> Array:
	var ids := []
	if node is CollisionObject2D or node is CollisionShape2D:
		ids.append(node.get_instance_id())
	for child: Node in node.get_children():
		ids.append_array(_collision_ids(child))
	return ids


func _steps(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _cleanup() -> void:
	if is_instance_valid(_session):
		_session.free()
	get_tree().paused = false
	InputRouter.clear_test_input()
	InputRouter.clear(0)
	InputRouter.clear(1)
	AudioDirector.stop_music()
	AudioDirector.stop_cues()
	for filename: String in DirAccess.get_files_at(_directory):
		DirAccess.remove_absolute(_directory.path_join(filename))
	DirAccess.remove_absolute(_directory)
	# Stopped playbacks retire on the audio thread, independently of fast tests.
	var deadline := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline:
		var active := false
		for node: Node in AudioDirector.get_children():
			if node is AudioStreamPlayer:
				active = active or node.has_stream_playback()
		if not active:
			return
		await get_tree().process_frame
	assert_true(false, "secret fixture retires stopped audio playback")
