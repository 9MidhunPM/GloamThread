extends Scenario
## Real user:// serialization and atomic-replacement failure boundaries.

var _directory: String


func run() -> void:
	_directory = "user://scenario-persistence-%d-%d" % [Time.get_ticks_usec(), get_instance_id()]
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_directory)), OK, "create isolated save directory")
	_test_progress_validation()
	_test_campaign_files()
	_test_settings_files()
	_remove_directory(_directory)


func _test_progress_validation() -> void:
	var team := TeamProgress.new()
	team.profile_ids.assign(["neri_fixed", "tavi_fixed"])
	team.visit("r00")
	team.visit("r00")
	team.visit("r02")
	assert_eq(team.explored_rooms.size(), 2, "visiting the same room commits once")
	assert_true(team.commit_flags(["bridge_spindle", "lantern_charm"]), "commit permanent outcomes")
	assert_true(not team.commit_flags(["bridge_spindle"]), "a repeated reward does not commit twice")
	assert_true(team.set_checkpoint("checkpoint_b"), "set validated checkpoint")
	assert_true(not team.set_checkpoint("arbitrary_position"), "reject unknown checkpoint")
	var original := team.to_save()
	var loaded := TeamProgress.new()
	assert_true(loaded.load_save(JSON.parse_string(JSON.stringify(original))), "serialized progress loads")
	assert_true(loaded.to_save() == original, "all team progress and swapped profiles survive round trip")
	var invalid_cases: Array[Dictionary] = []
	for replacement: Dictionary in [
		{"schema_version": 2}, {"schema_version": true}, {"schema_version": 1.5},
		{"content_version": "other-content"}, {"profile_ids": ["tavi_fixed", "tavi_fixed"]},
		{"content_version": true}, {"profile_ids": [true, 1]}, {"profile_ids": [null, []]},
		{"profile_ids": ["tavi_fixed", "outside_profile"]}, {"checkpoint_id": "r07:unsafe"},
		{"checkpoint_id": false}, {"explored_rooms": false}, {"explored_rooms": [3]},
		{"explored_rooms": ["r00", "r00"]}, {"explored_rooms": ["r99"]},
		{"team_unlocks": ["threadstep"]}, {"boss_flags": ["boss_spoolwarden"]},
		{"restored_pairs": ["bridge_spindle", "bridge_spindle"]},
		{"restored_pairs": ["bridge_causeway"]}, {"world_flags": ["loom_restored"]},
		{"secret_flags": ["unknown_secret"]}, {"secret_flags": [true]}, {"team_unlocks": false},
		{"team_unlocks": ["boss_spoolwarden"]},
	]:
		var candidate := original.duplicate(true)
		candidate.merge(replacement, true)
		invalid_cases.append(candidate)
	for candidate: Dictionary in invalid_cases:
		assert_true(not loaded.load_save(candidate), "reject invalid progress: %s" % JSON.stringify(candidate))
		assert_true(loaded.to_save() == original, "rejected load leaves current team state intact")
	var completed := _completed_save()
	assert_true(loaded.load_save(completed), "complete internally consistent campaign loads")
	assert_true(loaded.has_flag("loom_restored") and loaded.has_flag("threadstep"), "permanent traversal and ending survive reload")


func _test_campaign_files() -> void:
	var repository := SaveRepository.new()
	repository.path = _directory.path_join("campaign/team.json")
	assert_eq(repository.load_campaign().status, "missing", "missing campaign is a clear new-game state")
	var first := TeamProgress.new().to_save()
	assert_true(repository.save_campaign(first).ok, "write first campaign")
	var first_bytes := FileAccess.get_file_as_string(repository.path)
	assert_eq(repository.load_campaign().status, "ok", "read first campaign")
	var second := _completed_save()
	assert_true(repository.save_campaign(second).ok, "replace campaign with completed progress")
	assert_true(repository.load_campaign().data == JSON.parse_string(JSON.stringify(second)), "load saved checkpoint and permanent rewards")
	assert_eq(FileAccess.get_file_as_string(repository.path + ".bak"), first_bytes, "backup contains previous validated campaign")
	var active_bytes := FileAccess.get_file_as_string(repository.path)
	for stage: String in ["write", "verify", "rotate", "replace"]:
		repository.failure_stage = stage
		var result := repository.save_campaign(first)
		assert_true(not result.ok and not result.message.is_empty(), "%s failure is visible" % stage)
		assert_eq(FileAccess.get_file_as_string(repository.path), active_bytes, "%s failure retains valid active bytes" % stage)
		assert_eq(repository.load_campaign().status, "ok", "%s failure leaves campaign loadable" % stage)
	repository.failure_stage = ""
	_write(repository.path, "{\"schema_version\":1,\"checkpoint_id\":")
	var corrupt_bytes := FileAccess.get_file_as_string(repository.path)
	var damaged := repository.load_campaign()
	assert_eq(damaged.status, "backup_available", "truncated primary offers valid backup explicitly")
	assert_eq(damaged.primary_status, "corrupt", "backup notice distinguishes corrupt active save")
	assert_true(not repository.save_campaign(first).ok, "autosave cannot overwrite corrupt campaign silently")
	assert_eq(FileAccess.get_file_as_string(repository.path), corrupt_bytes, "refused overwrite preserves corrupt bytes for diagnosis")
	var retained_backup := FileAccess.get_file_as_string(repository.path + ".bak")
	for stage: String in ["write", "verify", "rotate", "replace"]:
		repository.failure_stage = stage
		assert_true(not repository.recover_backup().ok, "%s failure refuses false backup recovery success" % stage)
		assert_eq(FileAccess.get_file_as_string(repository.path), corrupt_bytes, "%s recovery failure preserves rejected primary" % stage)
		assert_eq(FileAccess.get_file_as_string(repository.path + ".bak"), retained_backup, "%s recovery failure retains valid backup" % stage)
	repository.failure_stage = ""
	assert_true(repository.recover_backup().ok, "explicit backup recovery succeeds")
	assert_eq(repository.load_campaign().status, "ok", "recovered save loads")
	assert_true(_preserved_copy_exists(repository.path, corrupt_bytes), "recovery retains rejected corrupt primary")
	# A failed/crashed rename can leave only the backup. It must still be offered.
	assert_eq(DirAccess.remove_absolute(repository.path), OK, "remove active save to simulate interrupted deployment")
	assert_eq(repository.load_campaign().status, "backup_available", "orphaned valid backup is recoverable when active file is missing")
	assert_true(repository.recover_backup().ok, "recover orphaned backup")
	var newer := first.duplicate(true)
	newer.schema_version = 22
	_write(repository.path, JSON.stringify(newer))
	var newer_bytes := FileAccess.get_file_as_string(repository.path)
	assert_eq(repository.load_campaign().primary_status, "newer", "backup offer identifies unsupported newer active save")
	assert_true(not repository.save_campaign(second).ok, "autosave cannot downgrade newer campaign")
	assert_eq(FileAccess.get_file_as_string(repository.path), newer_bytes, "newer bytes remain unchanged")
	assert_true(repository.save_campaign(first, true).ok, "explicit new game may replace incompatible primary")
	assert_true(_preserved_copy_exists(repository.path, newer_bytes), "explicit new game retains newer original")
	# A path beneath a regular file is unwritable even under a privileged test user.
	_write(_directory.path_join("not-a-directory"), "block")
	var unwritable := SaveRepository.new()
	unwritable.path = _directory.path_join("not-a-directory/save.json")
	var retained_campaign := FileAccess.get_file_as_string(repository.path)
	assert_true(not unwritable.save_campaign(first).ok, "unwritable directory reports failure without claiming success")
	assert_eq(FileAccess.get_file_as_string(repository.path), retained_campaign, "independent failed path cannot modify campaign")
	var no_backup := SaveRepository.new()
	no_backup.path = _directory.path_join("unsupported.json")
	_write(no_backup.path, JSON.stringify(newer))
	assert_eq(no_backup.load_campaign().status, "newer", "unsupported newer save without backup remains visible")
	_write(no_backup.path, "[]")
	assert_eq(no_backup.load_campaign().status, "corrupt", "non-object JSON is rejected")
	assert_true(not no_backup.recover_backup().ok, "missing backup does not fabricate recovery")


func _test_settings_files() -> void:
	var repository := SettingsRepository.new()
	repository.path = _directory.path_join("preferences/settings.json")
	var defaults := repository.load_settings()
	assert_true(defaults.settings == repository.defaults(), "missing settings use complete defaults")
	var settings := repository.defaults()
	settings.master_volume = 2.5
	settings.music_volume = -0.5
	settings.sfx_volume = 0.25
	settings.reduced_flash = true
	settings.reduced_shake = true
	settings.player_bindings[0].controls.jump = [KEY_Q]
	settings.sources[0] = {"kind": "GAMEPAD", "guid": "fixture-guid", "name": "Fixture pad", "joy_id": 77, "device": 77}
	assert_true(repository.save_settings(settings).ok, "write separate device and accessibility settings")
	var loaded: Dictionary = repository.load_settings().settings
	assert_eq(loaded.master_volume, 1.0, "master volume clamps to maximum")
	assert_eq(loaded.music_volume, 0.0, "music volume clamps to minimum")
	assert_eq(loaded.sfx_volume, 0.25, "effect volume retains valid value")
	assert_true(loaded.reduced_flash and loaded.reduced_shake, "accessibility settings survive restart")
	var rebound := Bindings.from_dict(loaded.player_bindings[0])
	assert_eq(rebound.keys_for(CommandSnapshot.Action.JUMP), [KEY_Q], "slot-specific binding survives JSON")
	assert_true(not loaded.sources[0].has("joy_id") and not loaded.sources[0].has("device"), "persistent device identity excludes volatile OS indices")
	assert_eq(loaded.sources[0].guid, "fixture-guid", "gamepad model identity survives")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(repository.path))
	assert_true(not raw.has("checkpoint_id") and not raw.has("boss_flags"), "settings file contains no campaign progress")
	_write(repository.path, "{bad")
	var corrupt := repository.load_settings()
	assert_true(corrupt.settings == repository.defaults() and not corrupt.message.is_empty(), "corrupt settings expose fallback notice")
	_write(repository.path, "{\"schema_version\":99}")
	assert_true(not repository.load_settings().message.is_empty(), "unsupported settings expose fallback notice")
	_write(repository.path, "{\"schema_version\":true}")
	assert_true(not repository.load_settings().message.is_empty(), "boolean schema cannot crash settings loader")
	var malformed := repository.defaults()
	malformed.master_volume = NAN
	malformed.music_volume = "loud"
	malformed.reduced_flash = 1
	malformed.sources = [{"kind": "SCRIPT", "name": "arbitrary"}, {"kind": "GAMEPAD", "name": 123}]
	assert_true(repository.save_settings(malformed).ok, "malformed fields normalize safely")
	assert_true(repository.load_settings().settings == repository.defaults(), "invalid values retain deterministic defaults")


func _completed_save() -> Dictionary:
	var team := TeamProgress.new()
	team.profile_ids.assign(["neri_fixed", "tavi_fixed"])
	team.set_checkpoint("checkpoint_b")
	for room_id: String in ["r00", "r01", "r02", "r03", "r04", "r05", "r06", "r07"]:
		team.visit(room_id)
	team.commit_flags(["bridge_spindle", "boss_spoolwarden", "threadstep", "shortcut_bell", "bridge_causeway", "lantern_charm", "loom_restored"])
	return team.to_save()


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "open fixture file: " + path)
	if file != null:
		file.store_string(text)
		file.close()


func _preserved_copy_exists(path: String, expected: String) -> bool:
	for filename: String in DirAccess.get_files_at(path.get_base_dir()):
		if filename.begins_with(path.get_file() + ".rejected-") and FileAccess.get_file_as_string(path.get_base_dir().path_join(filename)) == expected:
			return true
	return false


func _remove_directory(path: String) -> void:
	for filename: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(filename))
	for directory: String in DirAccess.get_directories_at(path):
		_remove_directory(path.path_join(directory))
	DirAccess.remove_absolute(path)
