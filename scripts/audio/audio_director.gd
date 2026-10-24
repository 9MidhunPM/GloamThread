extends Node
## Autoload: the single audio mix for the shared world.
##
## Gameplay emits semantic cues once (for example &"slash" or &"bridge_restored");
## this node resolves them to streams and plays them through a bounded voice
## pool. Two cameras never double a sound because nothing here is positional
## and no viewport listener is enabled (docs/ARCHITECTURE.md §11).
## Streams are registered from the asset manifest in milestone M4; until then
## unknown cues are counted and warned about once so tests can still assert
## single emission.

signal cue_played(cue_id: StringName)
signal music_changed(track_id: StringName)

const MAX_VOICES := 12

var music_volume_db: float = 0.0:
	set(value):
		music_volume_db = value
		_music_player.volume_db = value
var sfx_volume_db: float = 0.0

var _cues: Dictionary = {}
var _music: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _current_track: StringName = &""
var _missing_warned: Dictionary = {}
## Count of cue emissions by ID; scenario tests read this to prove one event → one sound.
var emission_counts: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	add_child(_music_player)
	for i in MAX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % i
		add_child(voice)
		_voices.append(voice)


func register_cue(cue_id: StringName, stream: AudioStream) -> void:
	_cues[cue_id] = stream


func register_music(track_id: StringName, stream: AudioStream) -> void:
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
	var voice := _free_voice()
	voice.stream = stream
	voice.volume_db = sfx_volume_db
	voice.play()


func play_music(track_id: StringName) -> void:
	if _current_track == track_id and _music_player.playing:
		return
	_current_track = track_id
	music_changed.emit(track_id)
	var stream: AudioStream = _music.get(track_id)
	if stream == null:
		_music_player.stop()
		return
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_current_track = &""
	_music_player.stop()


func current_track() -> StringName:
	return _current_track


func _free_voice() -> AudioStreamPlayer:
	for voice in _voices:
		if not voice.playing:
			return voice
	# Voice cap reached: steal the oldest voice (index 0) and rotate it to the back.
	var stolen: AudioStreamPlayer = _voices.pop_front()
	stolen.stop()
	_voices.append(stolen)
	return stolen
