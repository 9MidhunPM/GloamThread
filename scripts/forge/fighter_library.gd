class_name FighterLibrary
extends RefCounted
## One validated boundary for shipped and locally accepted character bundles.

const BUILTIN_INDEX := "res://assets/arena/builtin/index.json"
const FILENAMES := ["character.png", "portrait.png", "background.png", "materials.png", "provenance.json"]
const SIZES := {"character.png": Vector2i(544, 272), "portrait.png": Vector2i(128, 128), "background.png": Vector2i(640, 360), "materials.png": Vector2i(256, 256)}
const RIGS := ["upright", "quadruped", "floating"]
const KITS := ["ember", "frost", "storm", "stone", "nature", "shadow"]
const MAX_FILE_BYTES := 16 * 1024 * 1024
const MAX_ARCHIVE_BYTES := 32 * 1024 * 1024

var storage_root: String = "user://fighters"
var errors: Array[String] = []
var default_players: PackedStringArray = []


func list_bundles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	errors.clear()
	default_players.clear()
	if FileAccess.file_exists(BUILTIN_INDEX):
		var index: Variant = _read_json(BUILTIN_INDEX, 65536)
		if index is Dictionary and index.get("schema_version") == 1 and index.get("bundles") is Array:
			var preferred: Variant = index.get("default_players", [])
			if preferred is Array and preferred.size() <= 2:
				for id: Variant in preferred:
					if id is String and _slug(id):
						default_players.append(id)
			for directory: Variant in index["bundles"]:
				if directory is String and _slug(directory):
					_append_bundle(result, BUILTIN_INDEX.get_base_dir().path_join(directory).path_join("manifest.json"))
				else:
					errors.append("Built-in library contains an invalid directory name.")
		else:
			errors.append("Built-in fighter index is invalid.")
	if DirAccess.dir_exists_absolute(storage_root):
		var directories := DirAccess.get_directories_at(storage_root)
		directories.sort()
		for directory: String in directories:
			if _slug(directory):
				_append_bundle(result, storage_root.path_join(directory).path_join("manifest.json"))
	return result


func load_bundle(manifest_path: String) -> Dictionary:
	if not (manifest_path.begins_with("res://") or manifest_path.begins_with("user://") or manifest_path.is_absolute_path()):
		return _failure("Bundle path must be an absolute local manifest path.")
	if manifest_path.get_file() != "manifest.json":
		return _failure("Choose a bundle's manifest.json file.")
	var manifest: Variant = _read_json(manifest_path, 65536)
	if not manifest is Dictionary:
		return _failure("The fighter manifest is missing, too large, or invalid JSON.")
	var contract_error := _validate_manifest(manifest)
	if not contract_error.is_empty():
		return _failure(contract_error)
	var folder := manifest_path.get_base_dir()
	var directory := DirAccess.open(folder)
	if directory == null or directory.is_link("manifest.json"):
		return _failure("Bundle directory is unavailable or manifest is a symbolic link.")
	var images: Dictionary = {}
	for filename: String in FILENAMES:
		var path := folder.path_join(filename)
		if directory.is_link(filename):
			return _failure("Bundle files must be regular local files: " + filename)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return _failure("Missing bundle file: " + filename)
		if file.get_length() <= 0 or file.get_length() > MAX_FILE_BYTES:
			return _failure("Bundle file exceeds its size limit: " + filename)
		var bytes := file.get_buffer(file.get_length())
		file.close()
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(bytes)
		if digest.finish().hex_encode() != manifest["files"][filename]:
			return _failure("Hash mismatch: " + filename)
		if filename == "provenance.json":
			if bytes.size() > 1024 * 1024 or not JSON.parse_string(bytes.get_string_from_utf8()) is Dictionary:
				return _failure("Provenance must be a bounded JSON object.")
			continue
		var expected: Vector2i = SIZES[filename]
		if not _png_dimensions(bytes, expected):
			return _failure("Wrong PNG dimensions or format: %s (expected %s)." % [filename, expected])
		var image := Image.new()
		if image.load_png_from_buffer(bytes) != OK or image.get_size() != expected:
			return _failure("Could not decode bundle PNG: " + filename)
		image.convert(Image.FORMAT_RGBA8)
		if filename == "character.png":
			var atlas_error := _validate_atlas(image)
			if not atlas_error.is_empty():
				return _failure(atlas_error)
		images[filename] = ImageTexture.create_from_image(image)
	var bundle: Dictionary = manifest.duplicate(true)
	bundle["atlas"] = images["character.png"]
	bundle["portrait"] = images["portrait.png"]
	bundle["background"] = images["background.png"]
	bundle["materials"] = images["materials.png"]
	bundle["manifest_path"] = manifest_path
	return {"ok": true, "error": "", "bundle": bundle}


func accept_candidate(path: String) -> Dictionary:
	var source_path := path.path_join("manifest.json") if DirAccess.dir_exists_absolute(path) else path
	var checked := load_bundle(source_path)
	if not checked["ok"]:
		return checked
	var bundle: Dictionary = checked["bundle"]
	var root_path := ProjectSettings.globalize_path(storage_root)
	if DirAccess.make_dir_recursive_absolute(root_path) != OK:
		return _failure("Could not create the local fighter library.")
	var destination := root_path.path_join(bundle["id"])
	# Temporary and backup names cannot be discovered as accepted slug directories.
	var suffix := "%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	var staging := root_path.path_join("." + bundle["id"] + ".pending-" + suffix)
	if DirAccess.make_dir_absolute(staging) != OK:
		return _failure("Could not create an acceptance staging directory.")
	for filename: String in ["manifest.json"] + FILENAMES:
		if DirAccess.copy_absolute(source_path.get_base_dir().path_join(filename), staging.path_join(filename)) != OK:
			_remove_staging(staging)
			return _failure("Could not copy candidate file: " + filename)
	var staged := load_bundle(staging.path_join("manifest.json"))
	if not staged["ok"]:
		_remove_staging(staging)
		return _failure("Candidate changed during acceptance: " + staged["error"])
	var backup := root_path.path_join("." + bundle["id"] + ".backup-" + suffix)
	var had_previous := DirAccess.dir_exists_absolute(destination)
	if had_previous and DirAccess.rename_absolute(destination, backup) != OK:
		_remove_staging(staging)
		return _failure("Could not preserve the previously accepted fighter; it is unchanged.")
	if DirAccess.rename_absolute(staging, destination) != OK:
		if had_previous:
			DirAccess.rename_absolute(backup, destination)
		_remove_staging(staging)
		return _failure("Could not install the candidate; the previous fighter was preserved.")
	return load_bundle(destination.path_join("manifest.json"))


func export_bundle(manifest_path: String) -> Dictionary:
	var checked := load_bundle(manifest_path)
	if not checked["ok"]:
		return checked
	var temporary := "user://fighter-export-%d.zip" % Time.get_ticks_usec()
	var writer := ZIPPacker.new()
	if writer.open(temporary) != OK:
		return _failure("Could not create a fighter backup.")
	var okay := true
	for name: String in ["manifest.json"] + FILENAMES:
		var file := FileAccess.open(manifest_path.get_base_dir().path_join(name), FileAccess.READ)
		if file == null or writer.start_file(name) != OK:
			okay = false
			break
		okay = writer.write_file(file.get_buffer(file.get_length())) == OK and writer.close_file() == OK
		if not okay:
			break
	okay = writer.close() == OK and okay
	var bytes := FileAccess.get_file_as_bytes(temporary) if okay else PackedByteArray()
	DirAccess.remove_absolute(temporary)
	if bytes.is_empty():
		return _failure("Could not finish the fighter backup.")
	return {"ok": true, "bytes": bytes, "filename": str(checked["bundle"]["id"]) + ".zip"}


func import_archive(bytes: PackedByteArray) -> Dictionary:
	# Inspect the central directory before ZIPReader allocates decompressed files.
	# Archives contain exactly six fixed regular files, never paths or code.
	var archive_error := _archive_error(bytes)
	if not archive_error.is_empty():
		return _failure(archive_error)
	var folder := "user://fighter-import-%d" % Time.get_ticks_usec()
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return _failure("Could not stage the fighter backup.")
	var archive_path := folder.path_join("backup.zip")
	var archive := FileAccess.open(archive_path, FileAccess.WRITE)
	if archive == null:
		return _failure("Could not retain the fighter backup.")
	archive.store_buffer(bytes)
	archive.close()
	var reader := ZIPReader.new()
	if reader.open(archive_path) != OK:
		_cleanup_archive(folder)
		return _failure("The fighter ZIP could not be opened.")
	var names := reader.get_files()
	var okay := names.size() == 6
	for name: String in ["manifest.json"] + FILENAMES:
		if names.count(name) != 1:
			okay = false
			break
		var data := reader.read_file(name)
		if data.is_empty() or data.size() > MAX_FILE_BYTES:
			okay = false
			break
		var file := FileAccess.open(folder.path_join(name), FileAccess.WRITE)
		if file == null:
			okay = false
			break
		file.store_buffer(data)
		file.close()
	reader.close()
	var result := accept_candidate(folder.path_join("manifest.json")) if okay else _failure("The fighter ZIP has missing, duplicate or unreadable files.")
	_cleanup_archive(folder)
	return result


func _archive_error(bytes: PackedByteArray) -> String:
	if bytes.size() < 22 or bytes.size() > MAX_ARCHIVE_BYTES:
		return "Choose a fighter ZIP smaller than 32 MB."
	var end := -1
	for offset in range(bytes.size() - 22, maxi(-1, bytes.size() - 65558), -1):
		if bytes.decode_u32(offset) == 0x06054b50 and offset + 22 + bytes.decode_u16(offset + 20) == bytes.size():
			end = offset
			break
	if end < 0 or bytes.decode_u16(end + 4) != 0 or bytes.decode_u16(end + 6) != 0 or bytes.decode_u16(end + 8) != 6 or bytes.decode_u16(end + 10) != 6:
		return "A fighter ZIP must contain exactly six files on one disk."
	var cursor := int(bytes.decode_u32(end + 16))
	if cursor < 0 or cursor + int(bytes.decode_u32(end + 12)) != end:
		return "The fighter ZIP directory is invalid."
	var seen: Array[String] = []
	var total := 0
	for entry in 6:
		if cursor + 46 > end or bytes.decode_u32(cursor) != 0x02014b50:
			return "The fighter ZIP directory is invalid."
		var flags := bytes.decode_u16(cursor + 8)
		var method := bytes.decode_u16(cursor + 10)
		var compressed := int(bytes.decode_u32(cursor + 20))
		var size := int(bytes.decode_u32(cursor + 24))
		var length := int(bytes.decode_u16(cursor + 28))
		var next := cursor + 46 + length + int(bytes.decode_u16(cursor + 30)) + int(bytes.decode_u16(cursor + 32))
		if next > end or flags & 1 or method not in [0, 8] or compressed > MAX_ARCHIVE_BYTES or size <= 0 or size > MAX_FILE_BYTES:
			return "The fighter ZIP has unsafe compression or oversized files."
		var name := bytes.slice(cursor + 46, cursor + 46 + length).get_string_from_utf8()
		if name not in ["manifest.json"] + FILENAMES or name in seen or bytes.decode_u16(cursor + 34) != 0:
			return "The fighter ZIP has unexpected paths or duplicate files."
		var mode := int(bytes.decode_u32(cursor + 38)) >> 16
		if mode & 0xf000 not in [0, 0x8000]:
			return "The fighter ZIP must contain regular files."
		var local := int(bytes.decode_u32(cursor + 42))
		if local < 0 or local + 30 > cursor or bytes.decode_u32(local) != 0x04034b50:
			return "The fighter ZIP file header is invalid."
		var local_length := int(bytes.decode_u16(local + 26))
		var data_start := local + 30 + local_length + int(bytes.decode_u16(local + 28))
		if data_start + compressed > int(bytes.decode_u32(end + 16)) or bytes.slice(local + 30, local + 30 + local_length).get_string_from_utf8() != name:
			return "The fighter ZIP file header is invalid."
		if name == "manifest.json" and size > 65536 or name == "provenance.json" and size > 1024 * 1024:
			return "The fighter ZIP metadata exceeds its size limit."
		seen.append(name)
		total += size
		if total > MAX_ARCHIVE_BYTES:
			return "The expanded fighter ZIP exceeds 32 MB."
		cursor = next
	return "" if cursor == end else "The fighter ZIP has an invalid directory length."


func _cleanup_archive(folder: String) -> void:
	DirAccess.remove_absolute(folder.path_join("backup.zip"))
	_remove_staging(folder)


func _append_bundle(result: Array[Dictionary], path: String) -> void:
	var loaded := load_bundle(path)
	if loaded["ok"]:
		result.append(loaded["bundle"])
	else:
		errors.append(path + ": " + loaded["error"])


func _validate_manifest(manifest: Dictionary) -> String:
	var required := ["schema_version", "kind", "id", "name", "rig_id", "kit_id", "theme", "files"]
	if manifest.size() != required.size():
		return "Manifest fields do not match fighter schema 1."
	for key: String in required:
		if not manifest.has(key):
			return "Missing manifest field: " + key
	if typeof(manifest["schema_version"]) not in [TYPE_INT, TYPE_FLOAT] or manifest["schema_version"] != 1 or manifest["kind"] != "fighter-character":
		return "Unsupported fighter schema or kind."
	if not manifest["id"] is String or not _slug(manifest["id"]):
		return "Fighter ID must be a lowercase slug of 1–64 characters."
	if not _bounded_string(manifest["name"], 40):
		return "Fighter name must contain 1–40 characters."
	if manifest["rig_id"] not in RIGS or manifest["kit_id"] not in KITS:
		return "Unknown body rig or ability kit."
	var theme: Variant = manifest["theme"]
	if not theme is Dictionary or theme.size() != 3 or not theme.has_all(["name", "palette", "motif"]):
		return "Theme must contain name, palette and motif."
	if not _bounded_string(theme["name"], 60) or not _bounded_string(theme["motif"], 400):
		return "Theme name or motif is empty or too long."
	if not theme["palette"] is Array or theme["palette"].size() < 4 or theme["palette"].size() > 8:
		return "Theme requires 4–8 colours."
	for colour: Variant in theme["palette"]:
		if not colour is String or not _matches(colour, "^#[0-9A-Fa-f]{6}$"):
			return "Theme colours must use #RRGGBB."
	if not manifest["files"] is Dictionary or manifest["files"].size() != FILENAMES.size():
		return "Manifest must hash exactly the five fixed bundle files."
	for filename: String in FILENAMES:
		var value: Variant = manifest["files"].get(filename)
		if not value is String or not _matches(value, "^[0-9a-f]{64}$"):
			return "Missing or invalid SHA256 for " + filename
	return ""


func _validate_atlas(image: Image) -> String:
	var occupied: Array[bool] = []
	occupied.resize(32)
	occupied.fill(false)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.0:
				continue
			var local_x := x % 68
			var local_y := y % 68
			if local_x < 2 or local_x >= 66 or local_y < 2 or local_y >= 66:
				return "Character atlas must retain two transparent pixels around every frame."
			occupied[(y / 68) * 8 + x / 68] = true
	if occupied.has(false):
		return "Every character animation frame must contain visible artwork."
	return ""


func _png_dimensions(bytes: PackedByteArray, expected: Vector2i) -> bool:
	if bytes.size() < 33 or bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]) or bytes.slice(12, 16).get_string_from_ascii() != "IHDR":
		return false
	var width := 0
	var height := 0
	for index in 4:
		width = (width << 8) | bytes[16 + index]
		height = (height << 8) | bytes[20 + index]
	return width == expected.x and height == expected.y


func _read_json(path: String, limit: int) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > limit:
		return null
	return JSON.parse_string(file.get_as_text())


func _bounded_string(value: Variant, limit: int) -> bool:
	if not value is String or value.length() > limit or value.strip_edges().is_empty():
		return false
	for index in value.length():
		if value.unicode_at(index) < 32:
			return false
	return true


func _slug(value: String) -> bool:
	return _matches(value, "^[a-z0-9][a-z0-9_-]{0,63}$")


func _matches(value: String, expression: String) -> bool:
	var regex := RegEx.new()
	regex.compile(expression)
	return regex.search(value) != null


func _remove_staging(path: String) -> void:
	for filename: String in ["manifest.json"] + FILENAMES:
		if FileAccess.file_exists(path.path_join(filename)):
			DirAccess.remove_absolute(path.path_join(filename))
	DirAccess.remove_absolute(path)


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "bundle": {}}
