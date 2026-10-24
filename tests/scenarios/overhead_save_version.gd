extends Scenario
## Actual files prove overhead saves never silently adopt the side-view format.

var _folder: String


func run() -> void:
	_folder = "user://overhead-version-%d" % Time.get_ticks_usec()
	assert_eq(TeamProgress.SAVE_SCHEMA_VERSION, 2, "public save schema is overhead version 2")
	assert_eq(TeamProgress.CONTENT_VERSION, "overhead-v1", "campaign content has a distinct overhead version")
	var progress := TeamProgress.new()
	progress.profile_ids.assign(["neri_fixed", "tavi_fixed"])
	progress.set_checkpoint("checkpoint_b")
	progress.visit("r00")
	progress.visit("r04")
	assert_true(progress.commit_flags(["met_oru", "bridge_spindle", "lantern_charm"]), "introduction is explicit shared world progress")
	assert_true(not progress.commit_flags(["met_oru"]), "introduction can commit only once")
	var data := progress.to_save()
	assert_eq(data.schema_version, 2, "serialization writes the overhead schema")
	assert_true("met_oru" in data.world_flags, "introduction persists in world flags")
	assert_true(not data.has("position") and not data.has("player_bindings"), "campaign stores canonical checkpoint rather than live coordinates/settings")
	var loaded := TeamProgress.new()
	assert_true(loaded.load_save(JSON.parse_string(JSON.stringify(data))), "overhead state survives JSON serialization")
	assert_eq(loaded.to_save(), data, "checkpoint, fixed profiles and all shared flags survive")
	var before := loaded.to_save()
	for replacement: Dictionary in [{"schema_version": 1}, {"schema_version": true}, {"schema_version": 2.5}, {"schema_version": 3}, {"content_version": "phase1-v1"}]:
		var invalid := data.duplicate(true)
		invalid.merge(replacement, true)
		assert_true(not loaded.load_save(invalid), "reject incompatible version without mutating current state")
		assert_eq(loaded.to_save(), before, "rejected load leaves the current team intact")
	var partial := TeamProgress.new().to_save()
	partial.boss_flags = ["boss_spoolwarden"]
	assert_true(not loaded.load_save(partial), "boss without its atomic traversal/shortcut reward cannot load")
	var repository := SaveRepository.new()
	repository.path = _folder.path_join("team.json")
	assert_true(repository.save_campaign(data).ok, "write actual overhead campaign")
	assert_eq(repository.load_campaign().status, "ok", "schema2 is current rather than misclassified newer")
	var old := data.duplicate(true)
	old.schema_version = 1
	old.content_version = "phase1-v1"
	_write(repository.path, JSON.stringify(old))
	var old_bytes := FileAccess.get_file_as_string(repository.path)
	var incompatible := repository.load_campaign()
	assert_eq(incompatible.status, "incompatible", "side-view campaign is visibly incompatible")
	assert_true(incompatible.message.contains("overhead") and incompatible.message.contains("preserved"), "format failure explains separation and preservation")
	assert_true(not repository.save_campaign(data).ok, "autosave cannot replace an incompatible side-view file")
	assert_eq(FileAccess.get_file_as_string(repository.path), old_bytes, "side-view campaign bytes remain intact")
	assert_true(repository.save_campaign(data, true).ok, "explicit new journey may replace incompatible data")
	assert_true(_has_rejected(repository.path, old_bytes), "explicit replacement retains the original side-view bytes")
	var newer := data.duplicate(true)
	newer.schema_version = TeamProgress.SAVE_SCHEMA_VERSION + 1
	_write(repository.path, JSON.stringify(newer))
	var newer_bytes := FileAccess.get_file_as_string(repository.path)
	assert_eq(repository.load_campaign().status, "newer", "future overhead schema remains protected")
	assert_true(not repository.save_campaign(data).ok, "autosave cannot downgrade a newer campaign")
	assert_eq(FileAccess.get_file_as_string(repository.path), newer_bytes, "future-version bytes remain intact")
	for filename: String in DirAccess.get_files_at(_folder):
		DirAccess.remove_absolute(_folder.path_join(filename))
	DirAccess.remove_absolute(_folder)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "open actual campaign fixture")
	if file != null:
		file.store_string(text)
		file.close()


func _has_rejected(path: String, expected: String) -> bool:
	for filename: String in DirAccess.get_files_at(_folder):
		if filename.begins_with(path.get_file() + ".rejected-") and FileAccess.get_file_as_string(_folder.path_join(filename)) == expected:
			return true
	return false
