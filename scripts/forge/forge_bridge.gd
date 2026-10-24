class_name ForgeBridge
extends RefCounted
## Shell-free local authoring bridge. Credentials stay exclusively in Python.

const JOB_ROOT := "user://forge_jobs"
const WORKER := "res://tools/fighter_forge.py"
const COMMANDS := ["analyse", "generate", "bake"]
const APPROVAL_FILE := "creator_generation.json"
var pid: int = -1


func create_job(source: Image, description: String) -> Dictionary:
	if source == null or source.is_invisible() or description.length() > 2000:
		return {"ok": false, "error": "Draw or import a character first; descriptions are limited to 2,000 characters."}
	var folder := ProjectSettings.globalize_path(JOB_ROOT).path_join("job-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return {"ok": false, "error": "Could not create a local authoring job."}
	var source_path := folder.path_join("source.png")
	if source.save_png(source_path) != OK:
		return {"ok": false, "error": "Could not retain the source drawing."}
	var job := {"schema_version": 1, "source_image": source_path, "description": description.strip_edges(), "budget_usd": 0.50}
	var job_path := folder.path_join("job.json")
	if not write_json(job_path, job):
		return {"ok": false, "error": "Could not save the authoring job."}
	return {"ok": true, "error": "", "path": job_path}


func start(command: String, job_path: String) -> Dictionary:
	if command not in COMMANDS or not trusted_job(job_path):
		return {"ok": false, "error": "Invalid authoring command or job location."}
	if pid > 0 and OS.is_process_running(pid):
		return {"ok": false, "error": "The current request is still finishing. Its cost reservation remains in place."}
	var worker := ProjectSettings.globalize_path(WORKER)
	if OS.has_feature("standalone") or not FileAccess.file_exists(WORKER):
		worker = OS.get_executable_path().get_base_dir().path_join("authoring/tools/fighter_forge.py")
	if not FileAccess.file_exists(worker):
		return {"ok": false, "error": "Local authoring tools are unavailable. Saved and built-in fighters remain playable."}
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
	var authoring_root := worker.get_base_dir().get_base_dir()
	var interpreter := authoring_root.path_join(".venv/bin/python")
	if not FileAccess.file_exists(interpreter):
		interpreter = "python3"
	pid = OS.create_process(interpreter, PackedStringArray([worker, command, "--job", job_path]))
	if pid < 0:
		return {"ok": false, "error": "Could not launch Python authoring. Check the local authoring setup."}
	return {"ok": true, "error": "", "pid": pid}


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
	var root := ProjectSettings.globalize_path(JOB_ROOT).simplify_path().trim_suffix("/") + "/"
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
	file.store_string(JSON.stringify(value, "\t") + "\n")
	file.flush()
	var okay := file.get_error() == OK
	file.close()
	return okay and DirAccess.rename_absolute(temp, path) == OK
