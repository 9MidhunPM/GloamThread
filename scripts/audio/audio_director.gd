extends Node
## Autoload: the single audio mix for the shared world.
##
## Gameplay emits semantic cues once (for example &"slash" or &"bridge_restored");
## this node resolves them to streams and plays them through a bounded voice
## pool. Two cameras never double a sound because nothing here is positional
## and no viewport listener is enabled (docs/ARCHITECTURE.md §11).
## AssetCatalog owns validated stream loading and WAV loop metadata. The mix
## applies independent master/music/effects gains without per-viewport listeners.

signal cue_played(cue_id: StringName)
signal music_changed(track_id: StringName)

const MAX_VOICES := 12

var music_volume_db: float = 0.0:
	set(value):
		music_volume_db = value
		_apply_levels()
var sfx_volume_db: float = 0.0:
	set(value):
		sfx_volume_db = value
		_apply_levels()

var _cues: Dictionary = {}
var _music: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _current_track: StringName = &""
var _missing_warned: Dictionary = {}
var _master_level: float = 1.0
var _world_paused: bool = false
var registration_errors: PackedStringArray = PackedStringArray()
## Count of cue emissions by ID; scenario tests read this to prove one event → one sound.
var emission_counts: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_music_player)
	for i in MAX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % i
		voice.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(voice)
		_voices.append(voice)
	_apply_levels()
	_sync_pause()


func _process(_delta: float) -> void:
	if get_tree().paused != _world_paused:
		_sync_pause()


## Preserve the previous usable bundle if any required stream fails to load.
func register_bundle(catalog: AssetCatalog) -> bool:
	registration_errors.clear()
	if catalog == null:
		registration_errors.append("Audio bundle requires an AssetCatalog")
		return false
	var cues: Dictionary = {}
	var tracks: Dictionary = {}
	for cue: String in catalog.sfx:
		var stream: AudioStream = catalog.audio(str(catalog.sfx[cue]))
		if stream == null:
			registration_errors.append("Audio cue could not load: %s" % cue)
		else:
			cues[StringName(cue)] = stream
	for track: String in catalog.music:
		var stream: AudioStream = catalog.audio(str(catalog.music[track]))
		if stream == null:
			registration_errors.append("Music track could not load: %s" % track)
		else:
			tracks[StringName(track)] = stream
	if not registration_errors.is_empty():
		return false
	stop_cues()
	stop_music()
	_cues = cues
	_music = tracks
	_missing_warned.clear()
	return true


## Settings use linear 0..1 values; zero remains true silence.
func set_levels(master: float, music: float, sfx: float) -> void:
	_master_level = _unit_level(master)
	music_volume_db = linear_to_db(_unit_level(music))
	sfx_volume_db = linear_to_db(_unit_level(sfx))
	_apply_levels()


static func _unit_level(value: float) -> float:
	return clampf(value, 0.0, 1.0) if is_finite(value) else 0.0


static func _linear_gain(value_db: float) -> float:
	return db_to_linear(value_db) if is_finite(value_db) else 0.0


func _apply_levels() -> void:
	if is_instance_valid(_music_player):
		_music_player.volume_linear = _master_level * _linear_gain(music_volume_db)
	for voice: AudioStreamPlayer in _voices:
		voice.volume_linear = _master_level * _linear_gain(sfx_volume_db)


func _sync_pause() -> void:
	_world_paused = is_inside_tree() and get_tree().paused
	if is_instance_valid(_music_player):
		_music_player.stream_paused = _world_paused
	for voice: AudioStreamPlayer in _voices:
		voice.stream_paused = _world_paused


func register_cue(cue_id: StringName, stream: AudioStream) -> void:
	if stream == null:
		push_error("AudioDirector: cue '%s' has no stream" % cue_id)
		return
	_cues[cue_id] = stream


func register_music(track_id: StringName, stream: AudioStream) -> void:
	if stream == null:
		push_error("AudioDirector: music '%s' has no stream" % track_id)
		return
	_music[track_id] = stream


## Plays one semantic cue exactly once.
func play_cue(cue_id: StringName) -> void:
	emission_counts[cue_id] = int(emission_counts.get(cue_id, 0)) + 1
	cue_played.emit(cue_id)
	var stream: AudioStream = _cues.get(cue_id)
	if stream == null:
		if not _missing_warned.has(cue_id):
			_missing_warned[cue_id] = true
			if OS.is_debug_build():
				print_verbose("AudioDirector: no stream registered for cue '%s'" % cue_id)
		return
	if _voices.is_empty():
		push_error("AudioDirector: cannot play a cue before entering the tree")
		return
	var voice := _free_voice()
	voice.stream = stream
	voice.volume_linear = _master_level * _linear_gain(sfx_volume_db)
	voice.play()
	voice.stream_paused = get_tree().paused


func play_music(track_id: StringName) -> void:
	if not is_instance_valid(_music_player):
		push_error("AudioDirector: cannot play music before entering the tree")
		return
	if _current_track == track_id and _music_player.playing:
		return
	var stream: AudioStream = _music.get(track_id)
	if stream == null:
		push_warning("AudioDirector: no stream registered for music '%s'" % track_id)
		stop_music()
		return
	_current_track = track_id
	music_changed.emit(track_id)
	_music_player.stream = stream
	_music_player.play()
	_music_player.stream_paused = get_tree().paused


func stop_music() -> void:
	_current_track = &""
	if is_instance_valid(_music_player):
		_music_player.stop()


## Recovery/room replacement can discard old combat sounds before resuming.
func stop_cues() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()


func current_track() -> StringName:
	return _current_track


func _free_voice() -> AudioStreamPlayer:
	for index in _voices.size():
		var voice: AudioStreamPlayer = _voices[index]
		if not voice.playing:
			_voices.remove_at(index)
			_voices.append(voice)
			return voice
	# Voice cap reached: steal the oldest voice (index 0) and rotate it to the back.
	var stolen: AudioStreamPlayer = _voices.pop_front()
	stolen.stop()
	_voices.append(stolen)
	return stolen
