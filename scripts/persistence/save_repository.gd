class_name SaveRepository
extends RefCounted
## Linux atomic replacement with a validated previous-save backup.

var path: String = "user://save/team_save.json"
## Deterministic file-boundary failures used by the scenario suite only.
var failure_stage: String = ""


func load_campaign() -> Dictionary:
	var primary := _read(path)
	if primary.status == "ok":
		return primary
	var backup := _read(path + ".bak")
	if backup.status == "ok":
		return {"status": "backup_available", "primary_status": primary.status,
			"data": {}, "backup_data": backup.data,
			"message": primary.message + " A valid overhead backup is available."}
	return primary


func save_campaign(data: Dictionary, replace_incompatible: bool = false) -> Dictionary:
	if not _valid(data):
		return _failure("Campaign data failed validation; nothing was saved.")
	var directory := ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return _failure("The save directory could not be created.")
	var current := _read(path)
	if current.status not in ["ok", "missing"]:
		if not replace_incompatible:
			return _failure("The existing campaign is incompatible or damaged. Choose backup recovery or confirm New Game first.")
		if not _preserve_rejected(path):
			return _failure("The previous campaign could not be preserved; it was left untouched.")
	if failure_stage == "write":
		return _failure("Simulated save write failure.")
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _failure("The campaign could not be written. Current play can continue.")
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or failure_stage == "verify" or _read(temporary).status != "ok":
		return _failure("The temporary campaign could not be verified; the previous save is intact.")
	if failure_stage == "rotate":
		return _failure("Simulated backup rotation failure.")
	if current.status == "ok":
		var previous_backup := _read(path + ".bak")
		if previous_backup.status not in ["ok", "missing"] and not _preserve_rejected(path + ".bak"):
			return _failure("The incompatible or damaged backup could not be preserved; the previous save is intact.")
		var backup_temporary := path + ".bak.tmp"
		if DirAccess.copy_absolute(path, backup_temporary) != OK or _read(backup_temporary).status != "ok":
			return _failure("A valid previous-save backup could not be created.")
		if DirAccess.rename_absolute(backup_temporary, path + ".bak") != OK:
			return _failure("The previous-save backup could not be replaced.")
	if failure_stage == "replace" or DirAccess.rename_absolute(temporary, path) != OK:
		return _failure("The campaign could not replace the previous save. Current play can continue.")
	return {"ok": true, "message": ""}


func recover_backup() -> Dictionary:
	var backup := _read(path + ".bak")
	if backup.status != "ok":
		return _failure("No valid backup is available.")
	var result := save_campaign(backup.data, true)
	if result.ok:
		result["data"] = backup.data
	return result


func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"status": "missing", "data": {}, "message": "No saved campaign yet."}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"status": "corrupt", "data": {}, "message": "The campaign file could not be read."}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not parser.data is Dictionary:
		return {"status": "corrupt", "data": {}, "message": "The campaign file is damaged or incomplete."}
	var parsed: Dictionary = parser.data
	var version: Variant = parsed.get("schema_version")
	var integer_version := (version is int or version is float) and is_finite(float(version)) and float(version) == floorf(float(version))
	if integer_version and version > TeamProgress.SAVE_SCHEMA_VERSION:
		return {"status": "newer", "data": {}, "message": "This campaign belongs to a newer game version and has been preserved."}
	if not integer_version or version != TeamProgress.SAVE_SCHEMA_VERSION or not parsed.get("content_version") is String or parsed.content_version != TeamProgress.CONTENT_VERSION:
		return {"status": "incompatible", "data": {}, "message": "Campaign format is incompatible. The overhead adventure requires schema %d / %s; the file has been preserved." % [TeamProgress.SAVE_SCHEMA_VERSION, TeamProgress.CONTENT_VERSION]}
	if not _valid(parsed):
		return {"status": "incompatible", "data": {}, "message": "The campaign references unsupported profiles, checkpoints or progress."}
	return {"status": "ok", "data": parsed, "message": ""}


func _valid(data: Dictionary) -> bool:
	return TeamProgress.new().load_save(data)


func _preserve_rejected(file_path: String) -> bool:
	return DirAccess.copy_absolute(file_path, file_path + ".rejected-%d" % Time.get_ticks_usec()) == OK


func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
