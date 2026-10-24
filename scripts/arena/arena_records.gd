class_name ArenaRecords
extends RefCounted

var path: String = "user://arena_records.json"
var error: String = ""


func load_records() -> Array:
	for candidate: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if raw is Dictionary and raw.get("schema_version") == 1 and raw.get("runs") is Array:
			return raw.runs.slice(0, 20)
	return []


func record_run(summary: Dictionary) -> bool:
	error = ""
	var runs := load_records()
	var entry := summary.duplicate(true)
	entry.timestamp = Time.get_datetime_string_from_system()
	runs.push_front(entry)
	runs = runs.slice(0, 20)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "Run result could not be saved."
		return false
	file.store_string(JSON.stringify({"schema_version": 1, "runs": runs}))
	file.flush()
	var code := file.get_error()
	file.close()
	if code != OK or not JSON.parse_string(FileAccess.get_file_as_string(path + ".tmp")) is Dictionary:
		error = "Run result could not be verified."
		return false
	if FileAccess.file_exists(path) and DirAccess.copy_absolute(path, path + ".bak") != OK:
		error = "Run result backup could not be saved."
		return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		error = "Run result could not replace the previous file."
		return false
	return true
