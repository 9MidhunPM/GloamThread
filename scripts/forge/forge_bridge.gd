class_name ForgeBridge
extends RefCounted
## Shell-free local authoring bridge. Credentials stay exclusively in Python.

const JOB_ROOT := "user://forge_jobs"
const WORKER := "res://tools/fighter_forge.py"
const COMMANDS := ["analyse", "generate", "bake"]
const APPROVAL_FILE := "creator_generation.json"
const LAYOUT_PARTS := {"upright": ["torso", "head", "arm_back", "arm_front", "leg_back", "leg_front"], "quadruped": ["torso", "head", "leg_back_left", "leg_back_right", "leg_front_left", "leg_front_right", "tail"], "floating": ["torso", "arm_back", "arm_front"]}
var pid: int = -1
var job_root: String = JOB_ROOT


func create_job(source: Image, description: String, preferred_name: String = "") -> Dictionary:
	if source == null or source.is_invisible() or description.length() > 2000:
		return {"ok": false, "error": "Draw or import a character first; descriptions are limited to 2,000 characters."}
	var folder := ProjectSettings.globalize_path(job_root).path_join("job-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return {"ok": false, "error": "Could not create a local authoring job."}
	var source_path := folder.path_join("source.png")
	if source.save_png(source_path) != OK:
		return {"ok": false, "error": "Could not retain the source drawing."}
	var job := {"schema_version": 1, "source_image": source_path, "description": description.strip_edges(), "art_mode": "illustrated-master-v1"}
	if not preferred_name.strip_edges().is_empty():
		job["preferred_name"] = preferred_name.strip_edges().left(40)
	var job_path := folder.path_join("job.json")
	if not write_json(job_path, job):
		return {"ok": false, "error": "Could not save the authoring job."}
	return {"ok": true, "error": "", "path": job_path}


func start(command: String, job_path: String) -> Dictionary:
	if command not in COMMANDS or not trusted_job(job_path):
		return {"ok": false, "error": "Invalid authoring command or job location."}
	if pid > 0 and OS.is_process_running(pid):
		return {"ok": false, "error": "The current request is still finishing. Its cost reservation remains in place."}
	var executable := _worker_command()
	if not executable["ok"]:
		return executable
	# A cancelled paid job is never silently resumed; Retry creates a fresh job.
	if FileAccess.file_exists(job_path.get_base_dir().path_join("cancel")):
		return {"ok": false, "error": "This job was cancelled. Start a new attempt to continue."}
	# Prevent an earlier successful bake from looking like this request's result.
	# Keep reservation fields; the worker's separate budget ledger is authoritative.
	var queued := status(job_path)
	queued["state"] = "queued"
	queued["message"] = "Starting " + command + "…"
	queued.erase("candidate_path")
	if not write_json(job_path.get_base_dir().path_join("status.json"), queued):
		return {"ok": false, "error": "Could not record the queued authoring request."}
	pid = OS.create_process(executable["interpreter"], PackedStringArray([executable["worker"], command, "--job", job_path]))
	if pid < 0:
		return {"ok": false, "error": "Could not launch Python authoring. Check the local authoring setup."}
	return {"ok": true, "error": "", "pid": pid}


func _worker_command() -> Dictionary:
	var worker := ProjectSettings.globalize_path(WORKER)
	if OS.has_feature("standalone") or not FileAccess.file_exists(WORKER):
		worker = OS.get_executable_path().get_base_dir().path_join("authoring/tools/fighter_forge.py")
	if not FileAccess.file_exists(worker):
		return {"ok": false, "error": "Local authoring tools are unavailable. Saved and built-in fighters remain playable."}
	var interpreter := worker.get_base_dir().get_base_dir().path_join(".venv/bin/python")
	if not FileAccess.file_exists(interpreter):
		interpreter = "python3"
	return {"ok": true, "worker": worker, "interpreter": interpreter}


func configuration() -> Dictionary:
	# The worker returns only safe metadata. Godot never opens the credential file.
	var executable := _worker_command()
	if not executable["ok"]:
		return executable
	var output: Array = []
	var code := OS.execute(executable["interpreter"], PackedStringArray([executable["worker"], "status"]), output, true)
	var parsed: Variant = JSON.parse_string("".join(output).strip_edges())
	if not parsed is Dictionary:
		return {"ok": false, "error": "Could not read local AI setup. Install the optional authoring dependencies."}
	if code != 0:
		return {"ok": false, "error": str(parsed.get("message", "Local AI setup is unavailable."))}
	parsed["ok"] = true
	return parsed


func candidate_path(job_path: String, reported: Variant = "") -> String:
	if not trusted_job(job_path):
		return ""
	var folder := job_path.get_base_dir()
	var expected := folder.path_join("candidate")
	if reported == "" or reported == null:
		return expected
	if not reported is String or not reported.is_absolute_path() or reported.simplify_path() != reported or reported.get_base_dir() != folder:
		return ""
	var name: String = reported.get_file()
	if name == "candidate" or (name.begins_with("candidate-bake-") and name.trim_prefix("candidate-bake-").is_valid_int() and int(name.trim_prefix("candidate-bake-")) >= 1):
		return reported
	return ""


func proposal_hash(proposal: Dictionary) -> String:
	var theme: Dictionary = proposal.get("theme", {}) if proposal.get("theme") is Dictionary else {}
	# Explicit order makes the fingerprint independent of dictionary insertion order.
	return JSON.stringify([proposal.get("name"), proposal.get("rig_id"), proposal.get("kit_id"), theme.get("name"), theme.get("palette"), theme.get("motif"), proposal.get("features", [])]).sha256_text()


func generation_proposal_hash(path: String) -> String:
	if not trusted_job(path):
		return ""
	var folder := path.get_base_dir()
	var approval := read_json(folder.path_join(APPROVAL_FILE))
	if approval.get("schema_version") == 1 and approval.get("proposal") is Dictionary:
		return proposal_hash(approval["proposal"])
	# Reopened worker-created jobs may predate the UI's approval snapshot. Analysis
	# alone is deliberately excluded: its suggestions are still freely editable.
	var provenance := read_json(folder.path_join("provenance.json"))
	var requests: Dictionary = provenance.get("requests", {}) if provenance.get("requests") is Dictionary else {}
	var attempted := requests.has("parts") or requests.has("theme") or FileAccess.file_exists(folder.path_join("raw/parts.attempt.json")) or FileAccess.file_exists(folder.path_join("raw/theme.attempt.json"))
	var candidate := candidate_path(path, status(path).get("candidate_path", ""))
	attempted = attempted or FileAccess.file_exists(folder.path_join("candidate/manifest.json")) or (not candidate.is_empty() and FileAccess.file_exists(candidate.path_join("manifest.json")))
	if not attempted:
		return ""
	var proposal: Variant = provenance.get("approved_proposal", read_json(path).get("proposal"))
	return proposal_hash(proposal) if proposal is Dictionary else "unknown-previous-approval"


func freeze_generation_proposal(path: String, proposal: Dictionary) -> bool:
	return trusted_job(path) and write_json(path.get_base_dir().path_join(APPROVAL_FILE), {"schema_version": 1, "proposal_sha256": proposal_hash(proposal), "proposal": proposal.duplicate(true)})


func status(job_path: String) -> Dictionary:
	if not trusted_job(job_path):
		return {}
	return read_json(job_path.get_base_dir().path_join("status.json"))


func raw_layout_context(path: String) -> Dictionary:
	if not trusted_job(path):
		return {"ok": false, "error": "Layout corrections require a retained local job."}
	var folder := path.get_base_dir()
	var proposal: Variant = read_json(path).get("proposal")
	if not proposal is Dictionary or proposal.get("rig_id") not in LAYOUT_PARTS:
		return {"ok": false, "error": "The retained job has no approved body shape."}
	var result := {"ok": true, "error": "", "rig_id": proposal["rig_id"], "art_mode": read_json(path).get("art_mode", "")}
	for board: String in ["parts", "theme"]:
		var file := FileAccess.open(folder.path_join("raw/" + board + ".png"), FileAccess.READ)
		if file == null or file.get_length() > 16 * 1024 * 1024:
			return {"ok": false, "error": "Both retained 1024 × 1024 PNG boards are required."}
		var bytes := file.get_buffer(file.get_length())
		# Check the fixed PNG dimensions before allocating a decoded image.
		if bytes.size() < 33 or bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]) or bytes.slice(16, 24) != PackedByteArray([0, 0, 4, 0, 0, 0, 4, 0]):
			return {"ok": false, "error": "Raw layout correction supports only 1024 × 1024 PNG boards."}
		var image := Image.new()
		if image.load_png_from_buffer(bytes) != OK:
			return {"ok": false, "error": "The retained " + board + " board could not be decoded."}
		image.convert(Image.FORMAT_RGBA8)
		result[board] = image
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(bytes)
		result["raw_" + board + "_sha256"] = digest.finish().hex_encode()
	var layout := default_source_layout(result)
	var retained := read_json(folder.path_join("source_layout.json"))
	if source_layout_error(retained, result).is_empty():
		layout = retained
	result["layout"] = layout
	if layout.has("master_file"):
		var master := _retained_master(path.get_base_dir(), layout)
		if not master["ok"]:
			return master
		result["illustrated_master"] = master["image"]
	return result


func default_source_layout(context: Dictionary) -> Dictionary:
	var parts: Dictionary = {}
	var ids: Array = LAYOUT_PARTS[context["rig_id"]]
	for index in ids.size():
		parts[ids[index]] = {"crop": _grid_crop(index)}
	return {"schema_version": 1, "raw_parts_sha256": context["raw_parts_sha256"], "raw_theme_sha256": context["raw_theme_sha256"], "alpha_cutoff": 192, "parts": parts, "master_crop": _grid_crop(8), "background_crop": [0, 0, 1024, 576], "material_crops": [[0, 576, 256, 448], [256, 576, 256, 448], [512, 576, 256, 448], [768, 576, 256, 448]]}


func _grid_crop(index: int) -> Array:
	var column := index % 3
	var row := index / 3
	var x := column * 1024 / 3
	var y := row * 1024 / 3
	return [x, y, (column + 1) * 1024 / 3 - x, (row + 1) * 1024 / 3 - y]


func source_layout_error(layout: Dictionary, context: Dictionary) -> String:
	var allowed := ["schema_version", "raw_parts_sha256", "raw_theme_sha256", "alpha_cutoff", "parts", "master_crop", "background_crop", "material_crops", "master_file", "illustrated_master_sha256"]
	for key: Variant in layout:
		if key not in allowed:
			return "Layout contains an unsupported field."
	if not context.get("ok", false) or layout.get("schema_version") != 1 or typeof(layout.get("schema_version")) == TYPE_BOOL:
		return "Layout schema is invalid."
	for board: String in ["parts", "theme"]:
		if layout.get("raw_" + board + "_sha256") != context.get("raw_" + board + "_sha256"):
			return "Raw artwork changed. Reopen the correction screen before saving."
	if not _layout_integer(layout.get("alpha_cutoff"), 1, 255):
		return "Alpha cutoff must be a whole number from 1 to 255."
	if layout.has("master_file") or layout.has("illustrated_master_sha256"):
		var hash: Variant = layout.get("illustrated_master_sha256")
		if layout.get("master_file") != "illustrated_master.png" or not hash is String or hash.length() != 64 or hash != hash.to_lower() or not hash.is_valid_hex_number(false):
			return "The illustrated character needs its fixed PNG filename and matching SHA-256."
	var parts: Variant = layout.get("parts")
	var ids: Array = LAYOUT_PARTS[context["rig_id"]]
	if not parts is Dictionary or parts.size() != ids.size():
		return "Assign one crop to every part of the approved body shape."
	for id: String in ids:
		var part: Variant = parts.get(id)
		if not part is Dictionary or part.size() != 1 or not _layout_crop(part.get("crop")):
			return "Invalid crop for " + id.replace("_", " ") + "."
	for field: String in ["master_crop", "background_crop"]:
		if not _layout_crop(layout.get(field)):
			return "A bounded crop is required for " + field.replace("_", " ") + "."
	if layout.has("material_crops"):
		var materials: Variant = layout["material_crops"]
		if not materials is Array or materials.size() != 4:
			return "Assign exactly four material crops."
		for crop: Variant in materials:
			if not _layout_crop(crop):
				return "Material crops must remain inside the theme board."
	return ""


func _layout_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum


func source_layout_pixel_issue(layout: Dictionary, context: Dictionary) -> Dictionary:
	# Match Python's alpha threshold before cloning a draft or starting a worker.
	# A bounded rectangle alone says nothing about whether it contains artwork.
	if layout.has("master_file") or context.get("art_mode") == "illustrated-master-v1":
		var image: Image = context.get("illustrated_master", context.get("parts"))
		var error := _master_pixel_error(image, int(layout["alpha_cutoff"]))
		return {} if error.is_empty() else {"target": "master", "error": error}
	var board: Image = context.get("parts")
	if board == null:
		return {"target": "torso", "error": "The retained parts image is unavailable. Reopen the correction editor."}
	var targets: Array = LAYOUT_PARTS[context["rig_id"]].duplicate()
	targets.append("master")
	for id: String in targets:
		var crop: Array = layout["master_crop"] if id == "master" else layout["parts"][id]["crop"]
		var pixels := board.get_region(Rect2i(crop[0], crop[1], crop[2], crop[3]))
		pixels.convert(Image.FORMAT_RGBA8)
		var bytes := pixels.get_data()
		var maximum := 0
		for index in range(3, bytes.size(), 4):
			maximum = maxi(maximum, bytes[index])
			if maximum >= int(layout["alpha_cutoff"]):
				break
		if maximum < int(layout["alpha_cutoff"]):
			var advice := "Drag around the visible artwork for this part." if maximum == 0 else "Enlarge its crop or lower the opacity cutoff if the artwork is translucent."
			return {"target": id, "error": "%s crop is empty at opacity %d. %s Nothing was converted or added yet." % [id.replace("_", " ").capitalize(), int(layout["alpha_cutoff"]), advice]}
	return {}


func _layout_crop(value: Variant) -> bool:
	return value is Array and value.size() == 4 and _layout_integer(value[0], 0, 1020) and _layout_integer(value[1], 0, 1020) and _layout_integer(value[2], 4, 1024) and _layout_integer(value[3], 4, 1024) and value[0] + value[2] <= 1024 and value[1] + value[3] <= 1024


func save_source_layout(path: String, layout: Dictionary) -> Dictionary:
	# Re-read/hash both originals immediately before saving; a stale modal cannot
	# attach its rectangles to replacement artwork. Python validates again at bake.
	var context := raw_layout_context(path)
	if not context["ok"]:
		return context
	var error := source_layout_error(layout, context)
	if not error.is_empty():
		return {"ok": false, "error": error}
	var issue := source_layout_pixel_issue(layout, context)
	if not issue.is_empty():
		return {"ok": false, "error": issue["error"]}
	if not write_json(path.get_base_dir().path_join("source_layout.json"), layout):
		return {"ok": false, "error": "Could not save layout corrections. No conversion was started."}
	return {"ok": true, "error": ""}


func create_layout_job(path: String, layout: Dictionary, illustrated_bytes: PackedByteArray = PackedByteArray()) -> Dictionary:
	var context := raw_layout_context(path)
	if not context["ok"]:
		return context
	if not illustrated_bytes.is_empty():
		var master := _decode_master(illustrated_bytes, int(layout.get("alpha_cutoff", 192)))
		if not master["ok"]:
			return master
		context["illustrated_master"] = master["image"]
	var error := source_layout_error(layout, context)
	if not error.is_empty():
		return {"ok": false, "error": error}
	var issue := source_layout_pixel_issue(layout, context)
	if not issue.is_empty():
		return {"ok": false, "error": issue["error"]}
	var folder := path.get_base_dir()
	var job := read_json(path)
	var provenance := read_json(folder.path_join("provenance.json"))
	var source: Variant = provenance.get("source")
	var requests: Variant = provenance.get("requests")
	if provenance.get("schema_version") != 1 or not source is Dictionary or not requests is Dictionary or not provenance.get("approved_proposal") is Dictionary or proposal_hash(provenance["approved_proposal"]) != proposal_hash(job["proposal"]) or job.get("source_image") != folder.path_join("source.png"):
		return {"ok": false, "error": "The retained approved design or source provenance is invalid. No new request was made."}
	var expected := {"source.png": source.get("original_sha256"), "raw/source.png": source.get("sha256"), "raw/parts.png": context["raw_parts_sha256"], "raw/theme.png": context["raw_theme_sha256"]}
	if layout.has("master_file"):
		expected["illustrated_master.png"] = layout["illustrated_master_sha256"]
	for board: String in ["parts", "theme"]:
		var record: Variant = requests.get(board)
		if not record is Dictionary or record.get("file") != "raw/" + board + ".png" or record.get("sha256") != context["raw_" + board + "_sha256"]:
			return {"ok": false, "error": "Retained " + board + " pixels do not match their request provenance."}
	var copies: Dictionary = {}
	for name: String in expected:
		var bytes := illustrated_bytes if name == "illustrated_master.png" and not illustrated_bytes.is_empty() else PackedByteArray()
		if bytes.is_empty():
			var directory := DirAccess.open(folder)
			var file := FileAccess.open(folder.path_join(name), FileAccess.READ)
			if directory == null or directory.is_link(name) or file == null or file.get_length() > 20 * 1024 * 1024:
				return {"ok": false, "error": "The retained source cache is missing or oversized."}
			bytes = file.get_buffer(file.get_length())
		if not expected[name] is String or expected[name].length() != 64:
			return {"ok": false, "error": "The retained source cache hash is invalid."}
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(bytes)
		if hash.finish().hex_encode() != expected[name]:
			return {"ok": false, "error": "The retained cache changed. Reopen the correction screen."}
		copies[name] = bytes
	var fresh := ProjectSettings.globalize_path(job_root).path_join("job-local-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(fresh.path_join("raw")) != OK:
		return {"ok": false, "error": "Could not create a fresh local correction draft."}
	for name: String in copies:
		var file := FileAccess.open(fresh.path_join(name), FileAccess.WRITE)
		if file == null:
			return {"ok": false, "error": "Could not retain the correction cache. Previous draft is preserved."}
		file.store_buffer(copies[name])
		file.flush()
		if file.get_error() != OK:
			return {"ok": false, "error": "Could not finish copying the correction cache."}
		file.close()
	# Receipt metadata is retained, but no budget ledger, edited rig or candidate is
	# copied. Python's shared ledger remains the only authority for paid requests.
	for kind: String in ["parts", "theme", "analyse"]:
		var name := "raw/" + kind + ".attempt.json"
		var attempt := read_json(folder.path_join(name))
		if not attempt.is_empty():
			write_json(fresh.path_join(name), attempt)
	job["source_image"] = fresh.path_join("source.png")
	var fresh_path := fresh.path_join("job.json")
	if not write_json(fresh_path, job) or not write_json(fresh.path_join("provenance.json"), provenance) or not write_json(fresh.path_join("proposal.json"), job["proposal"]) or not write_json(fresh.path_join("source_layout.json"), layout) or not freeze_generation_proposal(fresh_path, job["proposal"]):
		return {"ok": false, "error": "Could not finish the local correction draft. Previous draft is preserved."}
	return {"ok": true, "error": "", "path": fresh_path}


func create_illustrated_job(path: String, bytes: PackedByteArray) -> Dictionary:
	var context := raw_layout_context(path)
	if not context["ok"]:
		return context
	var layout: Dictionary = context["layout"].duplicate(true)
	# A new cutout starts with the normal haze/fringe threshold, independent of
	# the opacity used while correcting an older parts board.
	layout["alpha_cutoff"] = 192
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	layout["master_file"] = "illustrated_master.png"
	layout["illustrated_master_sha256"] = hash.finish().hex_encode()
	return create_layout_job(path, layout, bytes)


func _retained_master(folder: String, layout: Dictionary) -> Dictionary:
	var directory := DirAccess.open(folder)
	var path := folder.path_join("illustrated_master.png")
	if directory == null or directory.is_link("illustrated_master.png") or FileAccess.get_sha256(path) != layout["illustrated_master_sha256"]:
		return {"ok": false, "error": "The retained illustrated character is missing or its hash changed."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 8 * 1024 * 1024:
		return {"ok": false, "error": "The illustrated character PNG must be at most 8 MB."}
	return _decode_master(file.get_buffer(file.get_length()), int(layout["alpha_cutoff"]))


func _decode_master(bytes: PackedByteArray, cutoff: int) -> Dictionary:
	if bytes.size() < 33 or bytes.size() > 8 * 1024 * 1024 or bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]) or bytes[25] != 6:
		return {"ok": false, "error": "Choose an RGBA PNG cutout with genuine transparency, at most 8 MB."}
	var width := (int(bytes[16]) << 24) | (int(bytes[17]) << 16) | (int(bytes[18]) << 8) | int(bytes[19])
	var height := (int(bytes[20]) << 24) | (int(bytes[21]) << 16) | (int(bytes[22]) << 8) | int(bytes[23])
	if width < 32 or height < 32 or width > 2048 or height > 2048:
		return {"ok": false, "error": "The illustrated character must be between 32 and 2048 pixels on each side."}
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return {"ok": false, "error": "Could not decode the illustrated character PNG."}
	image.convert(Image.FORMAT_RGBA8)
	var error := _master_pixel_error(image, cutoff)
	return {"ok": true, "error": "", "image": image} if error.is_empty() else {"ok": false, "error": error}


func _master_pixel_error(image: Image, cutoff: int) -> String:
	if image == null:
		return "The illustrated character source is unavailable."
	var bytes := image.get_data()
	var width := image.get_width()
	var height := image.get_height()
	var visible := false
	for index in range(3, bytes.size(), 4):
		if bytes[index] >= cutoff:
			visible = true
			break
	if not visible:
		return "The full character is empty at this opacity. Lower the cutoff or choose the visible cutout."
	for x in width:
		if bytes[x * 4 + 3] >= cutoff or bytes[((height - 1) * width + x) * 4 + 3] >= cutoff:
			return "Leave a transparent margin around the whole character and weapon."
	for y in height:
		if bytes[(y * width) * 4 + 3] >= cutoff or bytes[(y * width + width - 1) * 4 + 3] >= cutoff:
			return "Leave a transparent margin around the whole character and weapon."
	return ""


func cancel(job_path: String) -> bool:
	if not trusted_job(job_path):
		return false
	var marker := FileAccess.open(job_path.get_base_dir().path_join("cancel"), FileAccess.WRITE)
	if marker == null:
		return false
	marker.store_string("Cancelled by creator. Any in-flight request may still be billed.\n")
	marker.flush()
	return marker.get_error() == OK


func trusted_job(path: String) -> bool:
	var root := ProjectSettings.globalize_path(job_root).simplify_path().trim_suffix("/") + "/"
	return path.is_absolute_path() and path.simplify_path() == path and path.begins_with(root) and path.get_file() == "job.json" and path.get_base_dir().get_base_dir() + "/" == root


func read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1024 * 1024:
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return value if value is Dictionary else {}


func write_json(path: String, value: Dictionary) -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	# Godot decodes every JSON number as float. Restore integral tokens when
	# re-saving schema versions, crop coordinates and rig pivots for Python's
	# strict integer validators; booleans remain booleans and costs retain fractions.
	file.store_string(JSON.stringify(_integer_json(value), "\t") + "\n")
	file.flush()
	var okay := file.get_error() == OK
	file.close()
	return okay and DirAccess.rename_absolute(temp, path) == OK


func _integer_json(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _integer_json(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_integer_json(item))
		return result
	if typeof(value) == TYPE_FLOAT and is_finite(value) and absf(value) <= 9007199254740991.0 and value == floor(value):
		return int(value)
	return value
