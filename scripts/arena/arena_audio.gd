class_name ArenaAudio
extends RefCounted
## Register the arena's original music and cues into the single shared mix.

static func register_original() -> PackedStringArray:
	var errors: PackedStringArray = []
	var folder := "res://assets/arena/audio"
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("index.json")))
	if not raw is Dictionary or raw.get("schema_version") != 1:
		errors.append("Arena audio index is missing or invalid.")
		return errors
	for section: String in ["sfx", "music"]:
		if not raw.get(section) is Dictionary:
			errors.append("Missing arena audio section: " + section)
			continue
		for id: String in raw[section]:
			var record: Dictionary = raw[section][id]
			var filename := str(record.get("file", ""))
			if filename.get_file() != filename or not filename.ends_with(".wav"):
				errors.append("Invalid arena sound filename.")
				continue
			var path := folder.path_join(filename)
			if FileAccess.get_sha256(path) != str(record.get("sha256", "")):
				errors.append("Arena audio hash mismatch: " + id)
				continue
			var stream := AudioStreamWAV.load_from_buffer(FileAccess.get_file_as_bytes(path))
			if stream == null:
				errors.append("Arena audio could not decode: " + id)
				continue
			if record.get("loop", false):
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				stream.loop_begin = 0
				stream.loop_end = int(record.get("frames", 0))
			if section == "music":
				AudioDirector.register_music(StringName(id), stream)
			else:
				AudioDirector.register_cue(StringName(id), stream)
	return errors
