@tool
extends EditorExportPlugin
## The same hash-checked bytes must reach source and exported game loaders.


func _get_name() -> String:
	return "GloamthreadRawBundles"


func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	_add_json("res://assets/arena/builtin")
	_add_json("res://assets/arena/enemies")
	_add_json("res://assets/arena/audio")
	add_file("res://content/arena/catalog.json", FileAccess.get_file_as_bytes("res://content/arena/catalog.json"), false)


func _add_json(folder: String) -> void:
	for filename: String in DirAccess.get_files_at(folder):
		if filename.ends_with(".json"):
			var path := folder.path_join(filename)
			add_file(path, FileAccess.get_file_as_bytes(path), false)
	for directory: String in DirAccess.get_directories_at(folder):
		_add_json(folder.path_join(directory))


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if path.begins_with("res://assets/arena/") and not path.begins_with("res://assets/arena/source/") and path.get_extension() in ["png", "wav"]:
		skip()
		add_file(path, FileAccess.get_file_as_bytes(path), false)
