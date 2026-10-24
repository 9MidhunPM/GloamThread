extends Scenario
## Actual overhead files, backup recovery and deterministic write boundaries.

var _folder: String


func run() -> void:
	_folder = "user://overhead-transactions-%d" % Time.get_ticks_usec()
	var team := TeamProgress.new()
	for flag: String in ["boss_spoolwarden", "threadstep", "shortcut_bell", "bridge_causeway", "loom_restored"]:
		var transaction: Array[String] = [flag]
		assert_true(not team.commit_flags(transaction), "incomplete permanent transaction is refused")
		assert_true(team.flags.is_empty(), "refused transaction changes no live team state")
	assert_true(team.commit_flags(["boss_spoolwarden", "threadstep", "shortcut_bell"]), "complete boss reward commits atomically")
	assert_true(TeamProgress.new().load_save(team.to_save()), "every accepted reward state is serializable")
	var repository := SaveRepository.new()
	repository.path = _folder.path_join("campaign.json")
	var first := TeamProgress.new().to_save()
	assert_true(repository.save_campaign(first).ok, "write first actual overhead file")
	var current := TeamProgress.new()
	current.commit_flags(["met_oru", "bridge_spindle"])
	assert_true(repository.save_campaign(current.to_save()).ok, "new progress rotates a valid backup")
	var future_backup := first.duplicate(true)
	future_backup.schema_version = TeamProgress.SAVE_SCHEMA_VERSION + 1
	for foreign_bytes: String in [JSON.stringify(future_backup), "{damaged-backup"]:
		_write(repository.path + ".bak", foreign_bytes)
		assert_true(repository.save_campaign(current.to_save()).ok, "ordinary save may rotate a foreign backup after preserving it")
		assert_true(_has_rejected(repository.path + ".bak", foreign_bytes), "rotation preserves unsupported/damaged backup bytes for recovery or diagnosis")
		assert_eq(repository._read(repository.path + ".bak").status, "ok", "rotation still installs a validated last-known-good backup")
	var active_bytes := FileAccess.get_file_as_string(repository.path)
	team.commit_flags(["met_oru", "bridge_spindle", "bridge_causeway", "lantern_charm", "loom_restored"])
	for stage: String in ["write", "verify", "rotate", "replace"]:
		repository.failure_stage = stage
		var result := repository.save_campaign(team.to_save())
		assert_true(not result.ok and not result.message.is_empty(), "%s failure reports durability failure" % stage)
		assert_eq(FileAccess.get_file_as_string(repository.path), active_bytes, "%s failure preserves active campaign bytes" % stage)
		assert_eq(repository.load_campaign().status, "ok", "%s failure leaves a loadable overhead campaign" % stage)
		assert_true(repository._read(repository.path + ".bak").status == "ok", "%s failure retains a validated backup" % stage)
	repository.failure_stage = ""
	_write(repository.path, "{truncated")
	var corrupt_bytes := FileAccess.get_file_as_string(repository.path)
	var backup_bytes := FileAccess.get_file_as_string(repository.path + ".bak")
	var offered := repository.load_campaign()
	assert_true(offered.status == "backup_available" and offered.primary_status == "corrupt", "damaged primary explicitly offers the validated overhead backup")
	for stage: String in ["write", "verify", "rotate", "replace"]:
		repository.failure_stage = stage
		assert_true(not repository.recover_backup().ok, "%s failed recovery never reports success" % stage)
		assert_eq(FileAccess.get_file_as_string(repository.path), corrupt_bytes, "%s failed recovery preserves original primary" % stage)
		assert_eq(FileAccess.get_file_as_string(repository.path + ".bak"), backup_bytes, "%s failed recovery preserves usable backup" % stage)
	repository.failure_stage = ""
	assert_true(repository.recover_backup().ok, "explicit recovery succeeds after storage recovers")
	assert_eq(repository.load_campaign().status, "ok", "recovered overhead progress loads")
	assert_true(_has_rejected(repository.path, corrupt_bytes), "corrupt original remains available for diagnosis")
	DirAccess.remove_absolute(repository.path)
	assert_eq(repository.load_campaign().status, "backup_available", "missing primary cannot hide its valid backup")
	assert_true(repository.recover_backup().ok, "orphan backup restores the canonical campaign")
	var old_backup := first.duplicate(true)
	old_backup.schema_version = 1
	old_backup.content_version = "phase1-v1"
	_write(repository.path, "[]")
	_write(repository.path + ".bak", JSON.stringify(old_backup))
	assert_eq(repository.load_campaign().status, "corrupt", "side-view backup is never offered as valid overhead progress")
	assert_true(not repository.recover_backup().ok, "explicit recovery also refuses an incompatible backup")
	assert_true(repository.save_campaign(current.to_save(), true).ok, "confirmed replacement restores a valid overhead campaign")
	var preferences := SettingsRepository.new()
	preferences.path = _folder.path_join("settings.json")
	var settings := preferences.defaults()
	settings.player_bindings[0].controls = {"jump": [KEY_Q]}
	settings.sources[0] = {"kind": "GAMEPAD", "guid": "fixture-model", "name": "Synthetic model", "joy_id": 27}
	settings.master_volume = 0.25
	settings.reduced_flash = true
	var campaign_bytes := FileAccess.get_file_as_string(repository.path)
	assert_true(preferences.save_settings(settings).ok, "settings persist separately from campaign")
	var loaded: Dictionary = preferences.load_settings().settings
	assert_eq(loaded.master_volume, 0.25, "volume survives actual settings serialization")
	assert_true(loaded.reduced_flash, "accessibility survives settings reload")
	assert_eq(Bindings.from_dict(loaded.player_bindings[0]).keys_for(CommandSnapshot.Action.ROLL), [KEY_Q], "legacy remapped control survives canonical settings serialization")
	assert_true(not loaded.sources[0].has("joy_id"), "volatile OS indices never enter durable device identity")
	assert_eq(FileAccess.get_file_as_string(repository.path), campaign_bytes, "settings changes cannot alter campaign bytes")
	for filename: String in DirAccess.get_files_at(_folder):
		DirAccess.remove_absolute(_folder.path_join(filename))
	DirAccess.remove_absolute(_folder)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "create actual persistence fixture")
	if file != null:
		file.store_string(text)
		file.close()


func _has_rejected(path: String, expected: String) -> bool:
	for filename: String in DirAccess.get_files_at(_folder):
		if filename.begins_with(path.get_file() + ".rejected-") and FileAccess.get_file_as_string(_folder.path_join(filename)) == expected:
			return true
	return false
