class_name SettingsRepository
extends RefCounted

var path: String = "user://settings.json"

## Accessibility/assist choices are fixed steps so saved files cannot request
## arbitrary simulation rates or invulnerability.
const DAMAGE_TAKEN_STEPS := [1.0, 0.75, 0.5, 0.25]
const GAME_SPEED_STEPS := [1.0, 0.8, 0.6]


func defaults() -> Dictionary:
	return {"schema_version": 1, "master_volume": 0.7, "music_volume": 0.55,
		"sfx_volume": 0.7, "reduced_flash": false, "reduced_shake": false,
		"high_contrast": false, "narration": false, "damage_taken": 1.0,
		"game_speed": 1.0, "attack_toggle": [false, false],
		"player_bindings": [Bindings.defaults_for(DeviceSource.Kind.KEYBOARD_LEFT).to_dict(),
			Bindings.defaults_for(DeviceSource.Kind.KEYBOARD_RIGHT).to_dict()],
		"sources": [DeviceSource.keyboard_left().identity(), DeviceSource.keyboard_right().identity()]}


func load_settings() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"settings": defaults(), "message": ""}
	var parser := JSON.new()
	var parse_error := parser.parse(FileAccess.get_file_as_string(path))
	if parse_error != OK or not parser.data is Dictionary:
		return {"settings": defaults(), "message": "Settings could not load; defaults are active for this session."}
	var parsed: Dictionary = parser.data
	var version: Variant = parsed.get("schema_version")
	if not (version is int or version is float) or not is_finite(float(version)) or float(version) != 1.0:
		return {"settings": defaults(), "message": "Settings could not load; defaults are active for this session."}
	return {"settings": _normalise(parsed), "message": ""}


func save_settings(data: Dictionary) -> Dictionary:
	var settings := _normalise(data)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())) != OK:
		return {"ok": false, "message": "The settings directory is not writable."}
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Settings could not be written."}
	file.store_string(JSON.stringify(settings, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	var parser := JSON.new()
	if error != OK or parser.parse(FileAccess.get_file_as_string(path + ".tmp")) != OK or not parser.data is Dictionary:
		return {"ok": false, "message": "Settings could not be verified."}
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		return {"ok": false, "message": "Settings could not replace the previous file."}
	return {"ok": true, "message": ""}


func _normalise(data: Dictionary) -> Dictionary:
	var result := defaults()
	for key: String in ["master_volume", "music_volume", "sfx_volume"]:
		var value: Variant = data.get(key)
		if (value is int or value is float) and is_finite(float(value)):
			result[key] = clampf(float(value), 0.0, 1.0)
	for key: String in ["reduced_flash", "reduced_shake", "high_contrast", "narration"]:
		if data.get(key) is bool:
			result[key] = data[key]
	for pair: Array in [["damage_taken", DAMAGE_TAKEN_STEPS], ["game_speed", GAME_SPEED_STEPS]]:
		var value: Variant = data.get(pair[0])
		if (value is int or value is float) and float(value) in pair[1]:
			result[pair[0]] = float(value)
	var toggles: Variant = data.get("attack_toggle")
	if toggles is Array and toggles.size() == 2 and toggles.all(func(item: Variant) -> bool: return item is bool):
		result.attack_toggle = [toggles[0], toggles[1]]
	var bindings: Variant = data.get("player_bindings")
	if bindings is Array and bindings.size() == 2:
		for index in 2:
			if bindings[index] is Dictionary:
				result.player_bindings[index] = Bindings.from_dict(bindings[index]).to_dict()
	var sources: Variant = data.get("sources")
	if sources is Array and sources.size() == 2:
		for index in 2:
			var source: Variant = sources[index]
			if source is Dictionary and source.get("kind") in ["KEYBOARD_LEFT", "KEYBOARD_RIGHT", "GAMEPAD"]:
				if source.get("guid", "") is String and source.get("name", "") is String:
					result.sources[index] = {"kind": source.kind, "guid": source.get("guid", ""), "name": source.get("name", "")}
	return result
