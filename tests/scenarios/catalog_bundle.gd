extends Scenario
## Production resources and their runtime consumers; no rendered/audio QA claim.

const Bundle = preload("res://scripts/presentation/content_catalog.gd")
const RoomData = preload("res://scripts/world/room_definition.gd")
const RoomView = preload("res://scripts/world/room.gd")
const Animator = preload("res://scripts/presentation/sprite_animator.gd")
const SharedAudio = preload("res://scripts/audio/audio_director.gd")
const Themes = preload("res://scripts/presentation/theme_presenter.gd")


func run() -> void:
	var bundle := Bundle.load_bundle()
	assert_true(bundle.errors.is_empty(), "full campaign validates: %s" % str(bundle.errors))
	assert_eq(bundle.rooms.size(), 8, "all eight production rooms load")
	assert_eq(bundle.profiles.size(), 2, "both fixed profiles load")
	assert_eq(bundle.themes.size(), 2, "both presentation themes load")
	if not bundle.errors.is_empty():
		return
	_check_room_boundaries(bundle)
	_check_assets(bundle.assets)
	if not bundle.assets.errors.is_empty():
		assert_true(false, "required production resources must be imported before consumer checks")
		return
	_check_room_skins(bundle)
	_check_bridge(bundle)
	await _check_animation(bundle.assets)
	await _check_audio(bundle.assets)
	assert_true(bundle.assets.errors.is_empty(), "all consumed resources resolve: %s" % str(bundle.assets.errors))


func _check_room_boundaries(bundle: Bundle) -> void:
	var start: RoomDefinition = bundle.room("r00")
	var previous_errors := start.errors.duplicate()
	assert_eq(start.spawn_positions("entrance_that_does_not_exist").size(), 0, "unknown entrance never falls back to start")
	assert_eq(start.errors, previous_errors, "entrance queries do not mutate validation results")
	var fractional := RoomData.load_from_path("res://tests/contracts/content_invalid_fractional_spawn.json")
	assert_true(not fractional.is_valid(), "fractional fixture coordinates are rejected")
	var unresolved := RoomData.load_from_path("res://tests/contracts/content_invalid_missing_entrance.json")
	assert_true(unresolved.is_valid(), "missing destination entrance is a cross-room reference failure")
	if not unresolved.is_valid():
		return
	var invalid_bundle := Bundle.new()
	invalid_bundle.assets = bundle.assets
	invalid_bundle.world = bundle.world
	invalid_bundle.rooms = bundle.rooms.duplicate()
	invalid_bundle.rooms["r00"] = unresolved
	invalid_bundle._validate_references()
	assert_true(invalid_bundle.errors.has("Unresolved/duplicate exit or gate: r00/to_atrium"), "bundle rejects the committed unresolved entrance fixture")
	assert_true(bundle.errors.is_empty(), "fixture validation leaves the loaded campaign unchanged")


func _check_assets(assets: AssetCatalog) -> void:
	for id: String in assets.entries:
		# BMFont import embeds the PNG page and deliberately marks it skip.
		if id == "font_texture_v1":
			continue
		if assets.entries[id]["kind"] in ["image", "sprite_atlas", "tile_atlas"]:
			assert_true(assets.texture(id) != null, "%s image imports at its declared dimensions" % id)
	for id: String in ["fixed_tavi_v1", "fixed_neri_v1"]:
		var texture := assets.texture(id)
		var frame := assets.frame_texture(id, 0)
		assert_true(texture != null, "%s atlas loads" % id)
		assert_true(frame != null, "%s frame loads" % id)
		assert_true(texture == assets.texture(id), "%s whole texture is cached" % id)
		assert_true(frame == assets.frame_texture(id, 0), "%s frame texture is cached" % id)
		if frame != null:
			assert_eq(frame.get_size(), Vector2(32, 48), "%s frame excludes atlas padding" % id)
		assert_eq(assets.entries[id]["frames"].size(), 32, "%s contains all 32 courier frames" % id)
		var clip_frames := 0
		for state: String in Bundle.COURIER_CLIPS:
			var clip := assets.animation(id, state)
			assert_true(not clip.is_empty(), "%s has %s animation" % [id, state])
			clip_frames += clip.get("frames", []).size()
		assert_eq(clip_frames, 32, "%s required clips expose all 32 authored frames" % id)
	var original_font := assets.font()
	assert_true(original_font != null and original_font == assets.font(), "original bitmap font loads and is cached")
	assert_eq(assets.sfx.size(), 18, "all eighteen semantic sound cues are mapped")
	assert_eq(assets.music.size(), 3, "all three music tracks are mapped")
	var audio_count := 0
	for mapping: Dictionary in [assets.sfx, assets.music]:
		for name: String in mapping:
			var id: String = mapping[name]
			var stream := assets.audio(id) as AudioStreamWAV
			assert_true(stream != null, "%s loads as a WAV stream" % name)
			if stream == null:
				continue
			audio_count += 1
			assert_true(stream == assets.audio(id), "%s stream is cached" % name)
			var record: Dictionary = assets.entries[id]
			assert_eq(stream.mix_rate, int(record["sample_rate"]), "%s uses its declared sample rate" % name)
			assert_eq(stream.stereo, int(record["channels"]) == 2, "%s uses its declared channel layout" % name)
			var duration: float = float(record["sample_frames"]) / float(record["sample_rate"])
			assert_true(absf(stream.get_length() - duration) < 1.0 / float(record["sample_rate"]), "%s duration matches actual sample frames" % name)
			if name in ["exploration", "boss"]:
				assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s loops in the actual loaded stream" % name)
				assert_eq(stream.loop_begin, int(record["loop_start"]), "%s loop begins at the declared sample" % name)
				assert_eq(stream.loop_end, int(record["loop_end"]), "%s loop ends at the declared exclusive sample" % name)
			else:
				assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s remains a non-looping stream" % name)
	assert_eq(audio_count, 21, "all twenty-one audio assets are usable")


func _check_room_skins(bundle: Bundle) -> void:
	for id: String in bundle.rooms:
		var room := RoomView.build(bundle.room(id), true, bundle.assets)
		assert_eq(room.theme_gameplay_node_count(), 0, "%s themes contain no gameplay collision" % id)
		var canonical_tiles := 0
		for row: String in room.definition.rows:
			for tile: String in row:
				if tile != ".":
					canonical_tiles += 1
		for theme: Node2D in [room.theme_ember, room.theme_moss]:
			var terrain := theme.get_node("Terrain") as TileMapLayer
			assert_eq(terrain.get_used_cells().size(), canonical_tiles, "%s/%s covers the canonical grid" % [id, theme.name])
		room.free()
	for theme: String in ["ember", "moss"]:
		var background := Themes.build_background(bundle.assets, theme)
		Themes.update_background(background, Vector2(4000, 4000), Rect2(0, 0, 1440, 480))
		assert_eq(background.get_child_count(), 4, "%s background contains a fill and three finite layers" % theme)
		for name: String in ["middle", "near"]:
			var layer := background.get_node(name) as Sprite2D
			assert_eq(layer.position, layer.position.round(), "%s/%s background pan stays pixel stable" % [theme, name])
		background.free()


func _check_bridge(bundle: Bundle) -> void:
	var room := RoomView.build(bundle.room("r02"), true, bundle.assets)
	room.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(room)
	var shape_count: int = room.collision.get_child_count()
	var ember_count: int = room.theme_ember.get_child_count()
	var moss_count: int = room.theme_moss.get_child_count()
	var anchors: Array = []
	for entity: Dictionary in room.definition.entities:
		if entity["type"] == "anchor_pair":
			anchors = entity["anchors"]
	room.set_entity_state(anchors[0]["id"], "anchor_latched")
	var first_anchor: Sprite2D = room._visuals[anchors[0]["id"]]
	var second_anchor: Sprite2D = room._visuals[anchors[1]["id"]]
	assert_true(first_anchor.texture == bundle.assets.frame_texture("props_v1", 1), "first participant lights its own anchor immediately")
	assert_true(second_anchor.texture == bundle.assets.frame_texture("props_v1", 0), "the other anchor remains unlatched until its player acts")
	assert_eq(room.collision.get_child_count(), shape_count, "one latched anchor never creates bridge collision")
	assert_true(room.restore_bridge("bridge_spindle"), "restoring the authored bridge succeeds once")
	assert_true(second_anchor.texture == bundle.assets.frame_texture("props_v1", 1), "restoration lights both anchor frames")
	assert_eq(room.collision.get_child_count(), shape_count + 1, "one shared bridge collision shape is added")
	assert_eq(room.theme_ember.get_child_count(), ember_count + 1, "Ember receives one bridge skin")
	assert_eq(room.theme_moss.get_child_count(), moss_count + 1, "Moss receives one bridge skin")
	for theme: Node2D in [room.theme_ember, room.theme_moss]:
		var bridge := theme.get_node_or_null("RestoredBridge") as TileMapLayer
		assert_true(bridge != null, "restored bridge skin exists in %s" % theme.name)
		if bridge != null:
			assert_eq(bridge.get_used_cells().size(), 10, "bridge skin covers the complete ten-tile span")
			assert_eq(bridge.tile_set.get_physics_layers_count(), 0, "bridge skin contains no duplicate collision")
	assert_true(not room.restore_bridge("bridge_spindle"), "repeating restoration is idempotent")
	room.set_progress({"bridge_spindle": true})
	assert_eq(room.collision.get_child_count(), shape_count + 1, "progress replay preserves a single bridge collider")
	assert_eq(room.theme_ember.get_child_count(), ember_count + 1, "progress replay preserves one Ember bridge")
	assert_eq(room.theme_moss.get_child_count(), moss_count + 1, "progress replay preserves one Moss bridge")


func _check_animation(assets: AssetCatalog) -> void:
	var sprite := Sprite2D.new()
	add_child(sprite)
	var animator := Animator.new()
	animator.process_mode = Node.PROCESS_MODE_PAUSABLE
	sprite.add_child(animator)
	animator.configure(sprite, assets, "fixed_tavi_v1")
	animator.play("idle")
	assert_eq(sprite.offset, Vector2(-16, -43), "courier art uses its authored feet origin")
	assert_true(not sprite.centered, "courier origin is independent of frame centering")
	var clip := assets.animation("fixed_tavi_v1", "idle")
	assert_true(sprite.texture == assets.frame_texture("fixed_tavi_v1", int(clip["frames"][0])), "animation begins at its authored first frame")
	await ticks(int(clip["ticks"][0]) + 1)
	await get_tree().process_frame
	assert_true(sprite.texture == assets.frame_texture("fixed_tavi_v1", int(clip["frames"][1])), "physics ticks advance the authored animation")
	get_tree().paused = true
	var frozen_frame := sprite.texture
	for index in 20:
		await get_tree().process_frame
	assert_true(sprite.texture == frozen_frame, "shared pause freezes presentation frames")
	get_tree().paused = false
	await ticks(9)
	await get_tree().process_frame
	assert_true(sprite.texture != frozen_frame, "animation resumes with physics after shared pause")


func _check_audio(assets: AssetCatalog) -> void:
	var director := SharedAudio.new()
	add_child(director)
	assert_true(director.register_bundle(assets), "shared audio accepts the full bundle: %s" % str(director.registration_errors))
	if not director.registration_errors.is_empty():
		return
	director.set_levels(0.0, 0.0, 0.0)
	director.play_music(&"exploration")
	director.play_cue(&"slash")
	assert_eq(director.emission_counts.get(&"slash", 0), 1, "one semantic cue produces one emission")
	assert_eq(director.current_track(), &"exploration", "one shared music track is selected")
	var voices: Array[AudioStreamPlayer] = []
	var music := director.get_node("Music") as AudioStreamPlayer
	for child: Node in director.get_children():
		if child is AudioStreamPlayer:
			assert_eq(child.volume_linear, 0.0, "zero settings produce true silence")
			if child != music:
				voices.append(child)
	assert_eq(voices.size(), 12, "sound effects use the bounded twelve-voice pool")
	var active_voices: Array[AudioStreamPlayer] = []
	for voice: AudioStreamPlayer in voices:
		if voice.playing:
			active_voices.append(voice)
	assert_eq(active_voices.size(), 1, "the cue starts exactly one voice")
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(music.stream_paused, "shared pause freezes the active music stream")
	for voice: AudioStreamPlayer in active_voices:
		assert_true(voice.stream_paused, "shared pause freezes transient voices")
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(not music.stream_paused, "music resumes with the shared world")
	for voice: AudioStreamPlayer in active_voices:
		assert_true(not voice.stream_paused, "transient voices leave pause with the world")
	var playbacks: Array[WeakRef] = []
	if music.playing:
		playbacks.append(weakref(music.get_stream_playback()))
	for voice: AudioStreamPlayer in active_voices:
		playbacks.append(weakref(voice.get_stream_playback()))
	assert_eq(playbacks.size(), 2, "both active playbacks participate in the retirement check")
	director.stop_music()
	director.stop_cues()
	director.set_levels(0.6, 0.6, 0.7)
	assert_true(is_equal_approx(music.volume_linear, 0.36), "master and music gains combine independently")
	for voice: AudioStreamPlayer in voices:
		assert_true(is_equal_approx(voice.volume_linear, 0.42), "master and effect gains combine independently")
	assert_eq(director.current_track(), &"", "test leaves music stopped")
	director.queue_free()
	await get_tree().process_frame
	# AudioServer retires stopped voices on its real mixing clock. Fixed-FPS
	# simulation frames alone can finish before that retirement has happened.
	var deadline := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline and not _playbacks_retired(playbacks):
		await get_tree().process_frame
	assert_true(_playbacks_retired(playbacks), "stopped music/effect playbacks release their references")


func _playbacks_retired(playbacks: Array[WeakRef]) -> bool:
	for playback: WeakRef in playbacks:
		if playback.get_ref() != null:
			return false
	return true
