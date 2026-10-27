class_name WebForgeBridge
extends ForgeBridge
## Hosted operations mirror validated data into browser-local drafts. No keys.

signal configuration_updated(report: Dictionary)
signal report_updated(path: String, report: Dictionary)

const MAX_SNAPSHOT_BYTES := 64 * 1024 * 1024
const MAX_RESPONSE_BYTES := 90 * 1024 * 1024
var base_url: String = ""
var _owner: Node
var _configuration: Dictionary = {"ok": true, "authenticated": false, "key_present": false, "budget": {"limits_enabled": false, "total_reserved_usd": 0}}
var _configuration_pending: bool = false
var _running: bool = false
var _polling: bool = false
var _active_path: String = ""
var _cancel_requested: bool = false
var _submitting: bool = false
var _view_closed: bool = false


func attach(owner: Node) -> void:
	# A scene can close while cancellation is awaiting HTTPS. The autoload owns
	# transport nodes across mode changes; the creator owns only its visible UI.
	_owner = owner.get_tree().root.get_node_or_null("BrowserRuntime")
	if _owner == null:
		_owner = owner.get_tree().root
	_view_closed = false
	owner.tree_exiting.connect(_view_exiting, CONNECT_ONE_SHOT)
	if base_url.is_empty() and OS.has_feature("web"):
		base_url = str(JavaScriptBridge.eval("window.location.origin", true))


func is_running() -> bool:
	return _running


func configuration() -> Dictionary:
	if not _configuration_pending:
		_configuration_pending = true
		call_deferred("_refresh_configuration")
	return _configuration.duplicate(true)


func _refresh_configuration() -> void:
	var report: Dictionary = await _request("/configuration")
	_configuration_pending = false
	_configuration = report if report.get("ok", false) else {"ok": false, "authenticated": false, "key_present": false, "error": report.get("error", "The Forge service is unavailable.")}
	if not _view_closed:
		configuration_updated.emit(_configuration.duplicate(true))


func redeem_invite(code: String) -> void:
	var result: Dictionary = await _request("/session", HTTPClient.METHOD_POST, {"code": code.strip_edges()})
	if not result.get("ok", false):
		configuration_updated.emit({"ok": false, "authenticated": false, "error": result.get("error", "The invite could not be unlocked.")})
		return
	await _refresh_configuration()


func sign_out() -> void:
	await _request("/session", HTTPClient.METHOD_DELETE)
	_configuration = {"ok": true, "authenticated": false, "key_present": false, "budget": {"limits_enabled": false, "total_reserved_usd": 0}}
	configuration_updated.emit(_configuration.duplicate(true))


func start(command: String, path: String) -> Dictionary:
	if _view_closed:
		return {"ok": false, "error": "This creator screen has closed."}
	if command not in COMMANDS or not trusted_job(path):
		return {"ok": false, "error": "Invalid authoring action or draft."}
	if _running:
		return {"ok": false, "error": "The current operation is still finishing."}
	if not _configuration.get("authenticated", false):
		return {"ok": false, "error": "Enter your personal invite code to unlock fighter creation. Saved fighters remain playable."}
	if FileAccess.file_exists(path.get_base_dir().path_join("cancel")):
		return {"ok": false, "error": "This draft was cancelled. Start a new attempt."}
	_running = true
	_cancel_requested = false
	_active_path = path
	_submitting = true
	_publish(path, {"state": "queued", "message": "Uploading the approved creation action…"})
	call_deferred("_start_remote", command, path)
	return {"ok": true, "error": ""}


func _start_remote(command: String, path: String) -> void:
	var folder := path.get_base_dir()
	var job := read_json(path)
	var remote := read_json(folder.path_join("_remote.json"))
	if str(remote.get("job_id", "")).is_empty():
		var source := FileAccess.get_file_as_bytes(folder.path_join("source.png"))
		var payload := {"source_png": Marshalls.raw_to_base64(source), "description": job.get("description", ""), "preferred_name": job.get("preferred_name", ""), "art_mode": job.get("art_mode", "illustrated-master-v1")}
		if remote.has("parent_job_id"):
			payload["parent_job_id"] = remote["parent_job_id"]
		var created: Dictionary = await _request("/jobs", HTTPClient.METHOD_POST, payload)
		if not created.get("ok", false) or not _safe_id(str(created.get("job_id", ""))):
			_fail(path, str(created.get("error", "The hosted draft could not be created. No generation action was submitted.")))
			return
		remote["job_id"] = created["job_id"]
		if not write_json(folder.path_join("_remote.json"), remote):
			_fail(path, "Could not save the hosted draft identifier. No generation action was submitted.")
			return
	if _cancel_requested:
		await _cancel_remote(path)
		return
	var payload := {"command": command, "idempotency_key": "%s-%d-%d" % [command, Time.get_unix_time_from_system(), Time.get_ticks_usec()]}
	if job.get("proposal") is Dictionary:
		payload["proposal"] = job["proposal"]
	if command == "bake":
		var files: Dictionary = {}
		for name: String in ["source_layout.json", "rig_edits.json", "illustrated_master.png"]:
			if FileAccess.file_exists(folder.path_join(name)):
				files[name] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(folder.path_join(name)))
		if DirAccess.dir_exists_absolute(folder.path_join("masks")):
			for name: String in DirAccess.get_files_at(folder.path_join("masks")):
				if _safe_part(name):
					files["masks/" + name] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(folder.path_join("masks/" + name)))
		payload["files"] = files
	remote["pending_action"] = payload["idempotency_key"]
	remote["previous_operation_id"] = remote.get("operation_id", "")
	if not write_json(folder.path_join("_remote.json"), remote):
		_fail(path, "Could not save the action identifier. No request was sent.")
		return
	var submitted: Dictionary = await _request("/jobs/" + str(remote["job_id"]) + "/operations", HTTPClient.METHOD_POST, payload)
	_submitting = false
	if not submitted.get("ok", false):
		# A lost POST response is not retried. Read-only polling can discover whether
		# the server accepted it without risking another billable request.
		if submitted.get("network_error", false):
			_publish(path, {"state": "queued", "message": "Connection interrupted. Checking the existing draft; no action is retried."})
		else:
			_fail(path, str(submitted.get("error", "The creation action was rejected.")))
		return
	remote["operation_id"] = submitted.get("operation_id", "")
	remote.erase("pending_action")
	remote.erase("previous_operation_id")
	write_json(folder.path_join("_remote.json"), remote)
	await _poll_remote(path)


func status(path: String) -> Dictionary:
	if not _view_closed and _running and path == _active_path and trusted_job(path) and not _submitting and not _polling and not str(read_json(path.get_base_dir().path_join("_remote.json")).get("job_id", "")).is_empty():
		call_deferred("_poll_remote", path)
	return super.status(path)


func resume_tracking(path: String) -> void:
	if trusted_job(path):
		_active_path = path
		_running = true
		call_deferred("_poll_remote", path)


func _poll_remote(path: String) -> void:
	if _view_closed or _polling or not trusted_job(path):
		return
	var remote := read_json(path.get_base_dir().path_join("_remote.json"))
	var id := str(remote.get("job_id", ""))
	if not _safe_id(id):
		return
	_polling = true
	var report: Dictionary = await _request("/jobs/" + id)
	if _view_closed:
		_polling = false
		return
	if not report.get("ok", true) or report.has("error"):
		_polling = false
		if report.get("network_error", false):
			_publish(path, {"state": "queued", "message": "Connection interrupted. Your hosted draft is retained; checking its status sends no model request."})
		else:
			_fail(path, str(report.get("error", "Could not read this private draft.")))
		return
	var state := str(report.get("state", "queued"))
	if remote.has("pending_action"):
		var accepted_id := str(report.get("operation_id", ""))
		if accepted_id.is_empty() or accepted_id == str(remote.get("previous_operation_id", "")):
			_polling = false
			_fail(path, "The submitted action could not be confirmed. No retry was made. Reopen this retained draft to check before starting another attempt.")
			return
		remote["operation_id"] = accepted_id
		remote.erase("pending_action")
		remote.erase("previous_operation_id")
		write_json(path.get_base_dir().path_join("_remote.json"), remote)
	if state == "draft":
		_polling = false
		_running = false
		_publish(path, {"state": "awaiting_approval" if report.get("proposal") is Dictionary else "failed", "message": "The drawing is retained. Choose an explicit Analyse or Generate action to continue.", "proposal": report.get("proposal", {}), "retry_allowed": false})
		return
	if state in ["awaiting_approval", "complete", "failed", "cancelled", "interrupted", "uncertain"]:
		var snapshot: Dictionary = await _request("/jobs/" + id + "/snapshot")
		if snapshot.has("error"):
			_polling = false
			if snapshot.get("http_status", 0) == 409 and str(snapshot.get("error", "")).begins_with("Artwork is still changing"):
				_publish(path, {"state": "queued", "message": "Finalizing retained artwork…"})
			elif snapshot.get("network_error", false):
				_publish(path, {"state": "queued", "message": "Result retained on the server. Waiting to finish downloading it…"})
			else:
				_fail(path, str(snapshot.get("error", "Could not download the retained artwork.")))
			return
		var applied := apply_snapshot(path, snapshot)
		if not applied.get("ok", false):
			_polling = false
			_fail(path, str(applied.get("error", "The downloaded artwork was rejected.")))
			return
		if state == "complete":
			report["candidate_path"] = path.get_base_dir().path_join(str(snapshot.get("candidate_dir", "candidate")))
		if state in ["interrupted", "uncertain"]:
			report["state"] = "failed"
			report["retry_allowed"] = false
		_running = false
	else:
		_running = true
	_polling = false
	_publish(path, report)


func apply_snapshot(path: String, snapshot: Dictionary) -> Dictionary:
	if not trusted_job(path) or not snapshot.get("files") is Dictionary or snapshot["files"].size() > 80:
		return {"ok": false, "error": "The hosted draft snapshot is invalid."}
	var files: Dictionary = snapshot["files"]
	var candidate_dir := str(snapshot.get("candidate_dir", "candidate"))
	if candidate_dir.is_empty():
		candidate_dir = "candidate"
	if candidate_dir != "candidate" and not _matches(candidate_dir, "^candidate-bake-[1-9][0-9]{0,7}$"):
		return {"ok": false, "error": "The result directory is invalid."}
	var decoded: Dictionary = {}
	var total := 0
	var candidate_files := 0
	for name: Variant in files:
		if not name is String or not _snapshot_name(name, candidate_dir) or not files[name] is String or files[name].length() > 36 * 1024 * 1024:
			return {"ok": false, "error": "The hosted snapshot contains an unexpected or oversized file."}
		var bytes := Marshalls.base64_to_raw(files[name])
		total += bytes.size()
		if bytes.is_empty() or bytes.size() > 25 * 1024 * 1024 or total > MAX_SNAPSHOT_BYTES:
			return {"ok": false, "error": "The hosted snapshot exceeds its byte limit."}
		if name.ends_with(".json") and (bytes.size() > 1024 * 1024 or not JSON.parse_string(bytes.get_string_from_utf8()) is Dictionary):
			return {"ok": false, "error": "The hosted snapshot contains invalid metadata."}
		decoded[name] = bytes
		if name.begins_with(candidate_dir + "/"):
			candidate_files += 1
	if candidate_files > 0 and (candidate_files != 6 or not files.has(candidate_dir + "/manifest.json")):
		return {"ok": false, "error": "The hosted candidate is incomplete. Previous preview is preserved."}
	var folder := path.get_base_dir()
	var staging := folder.path_join(".download-%d" % Time.get_ticks_usec())
	for name: String in decoded:
		var destination := staging.path_join(name)
		if DirAccess.make_dir_recursive_absolute(destination.get_base_dir()) != OK:
			return {"ok": false, "error": "Could not stage the hosted artwork in browser storage."}
		var file := FileAccess.open(destination, FileAccess.WRITE)
		if file == null:
			return {"ok": false, "error": "Could not retain the hosted artwork in browser storage."}
		file.store_buffer(decoded[name])
		file.flush()
		var written := file.get_error() == OK
		file.close()
		if not written:
			return {"ok": false, "error": "Could not finish staging the hosted artwork. Previous draft and preview are preserved."}
	var has_candidate := files.has(candidate_dir + "/manifest.json")
	if has_candidate:
		var checked := FighterLibrary.new().load_bundle(staging.path_join(candidate_dir + "/manifest.json"))
		if not checked["ok"]:
			return {"ok": false, "error": "Candidate rejected; previous preview is preserved: " + str(checked["error"])}
	var install: Array[String] = []
	for name: String in decoded:
		if not name.begins_with(candidate_dir + "/"):
			install.append(name)
	if has_candidate:
		install.append(candidate_dir)
	if decoded.has("proposal.json"):
		var job := read_json(path)
		job["proposal"] = read_json(staging.path_join("proposal.json"))
		if not write_json(staging.path_join("job.json"), job):
			return {"ok": false, "error": "Could not stage the retained proposal. Previous draft is preserved."}
		install.append("job.json")
	return _publish_snapshot(folder, staging, install)


func _publish_snapshot(folder: String, staging: String, names: Array[String]) -> Dictionary:
	# Candidate directories move as one unit. Every replaced draft file has a
	# same-filesystem backup, allowing rollback on quota or I/O failure mid-publish.
	var backup := folder.path_join(".download-previous-%d" % Time.get_ticks_usec())
	var moves: Array[Dictionary] = []
	for name: String in names:
		var destination := folder.path_join(name)
		var source := staging.path_join(name)
		if not FileAccess.file_exists(source) and not DirAccess.dir_exists_absolute(source):
			_rollback_snapshot(moves)
			return {"ok": false, "error": "The staged download is incomplete. Previous draft and preview are preserved."}
		if FileAccess.file_exists(destination) and FileAccess.get_sha256(destination) == FileAccess.get_sha256(source):
			continue
		if DirAccess.dir_exists_absolute(destination) and FileAccess.get_sha256(destination.path_join("manifest.json")) == FileAccess.get_sha256(source.path_join("manifest.json")):
			continue
		var previous := backup.path_join(name)
		var move := {"destination": destination, "previous": previous, "backed": false, "installed": false}
		moves.append(move)
		if DirAccess.make_dir_recursive_absolute(destination.get_base_dir()) != OK or DirAccess.make_dir_recursive_absolute(previous.get_base_dir()) != OK:
			_rollback_snapshot(moves)
			return {"ok": false, "error": "Browser storage could not retain the new draft. Previous draft and preview are preserved."}
		if FileAccess.file_exists(destination) or DirAccess.dir_exists_absolute(destination):
			if DirAccess.rename_absolute(destination, previous) != OK:
				_rollback_snapshot(moves)
				return {"ok": false, "error": "Could not preserve the previous draft. It remains unchanged."}
			move["backed"] = true
		if DirAccess.rename_absolute(source, destination) != OK:
			_rollback_snapshot(moves)
			return {"ok": false, "error": "Browser storage could not publish the new draft. Previous draft and preview are preserved."}
		move["installed"] = true
	# Keep every rollback copy until all replacements have succeeded. Only these
	# two trees belong to this successful download; older recovery data stays put.
	_remove_download_tree(staging)
	_remove_download_tree(backup)
	return {"ok": true}


func _remove_download_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(filename))
	for name: String in directory.get_directories():
		var child := path.path_join(name)
		if directory.is_link(name):
			DirAccess.remove_absolute(child)
		else:
			_remove_download_tree(child)
	DirAccess.remove_absolute(path)


func _rollback_snapshot(moves: Array[Dictionary]) -> void:
	for index in range(moves.size() - 1, -1, -1):
		var move: Dictionary = moves[index]
		if move["installed"]:
			# Move the new data aside rather than deleting potentially useful art.
			DirAccess.rename_absolute(move["destination"], str(move["destination"]) + ".interrupted-%d" % Time.get_ticks_usec())
		if move["backed"]:
			DirAccess.rename_absolute(move["previous"], move["destination"])


func create_layout_job(path: String, layout: Dictionary, illustrated_bytes: PackedByteArray = PackedByteArray()) -> Dictionary:
	var created := super.create_layout_job(path, layout, illustrated_bytes)
	if created.get("ok", false):
		var parent := read_json(path.get_base_dir().path_join("_remote.json"))
		if not _safe_id(str(parent.get("job_id", ""))):
			return {"ok": false, "error": "This retained draft has no hosted source. New generation is not started."}
		write_json(str(created["path"]).get_base_dir().path_join("_remote.json"), {"parent_job_id": parent["job_id"]})
	return created


func cancel(path: String) -> bool:
	if not trusted_job(path):
		return false
	_cancel_requested = true
	super.cancel(path)
	# Start now, while this bridge still has a UI owner. Each persistent request
	# retains the bridge until its response, even if the creator is freed next.
	_cancel_remote(path)
	return true


func _view_exiting() -> void:
	if _running and not _cancel_requested and trusted_job(_active_path):
		cancel(_active_path)
	_view_closed = true
	_active_path = ""
	_running = false


func _cancel_remote(path: String) -> void:
	var remote := read_json(path.get_base_dir().path_join("_remote.json"))
	if _safe_id(str(remote.get("job_id", ""))):
		var result: Dictionary = await _request("/jobs/" + str(remote["job_id"]) + "/cancel", HTTPClient.METHOD_POST)
		if result.has("error"):
			_publish(path, {"state": "queued", "message": "Cancellation could not be confirmed. The existing request may finish; reconnect to check it."})
			return
	_running = false
	_publish(path, {"state": "cancelled", "message": "Cancellation requested. An in-flight model request may still finish and be billed."})


func _request(endpoint: String, method: int = HTTPClient.METHOD_GET, payload: Dictionary = {}) -> Dictionary:
	if not is_instance_valid(_owner) or not _owner.is_inside_tree() or base_url.is_empty():
		return {"ok": false, "network_error": true, "error": "The hosted Forge is unavailable in this environment."}
	var request := _make_request()
	var headers := PackedStringArray(["Content-Type: application/json", "X-Gloamthread-Request: 1"])
	var code := request.request(base_url + "/api/forge" + endpoint, headers, method, JSON.stringify(_integer_json(payload)) if method != HTTPClient.METHOD_GET else "")
	if code != OK:
		request.queue_free()
		return {"ok": false, "network_error": true, "error": "Could not connect to the Forge service. No action is automatically retried."}
	var response: Array = await request.request_completed
	request.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "network_error": true, "error": "The Forge connection was interrupted. No action is automatically retried."}
	var value: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if not value is Dictionary:
		return {"ok": false, "error": "The Forge service returned an invalid response."}
	if response[1] < 200 or response[1] >= 300:
		return {"ok": false, "http_status": response[1], "error": str(value.get("error", value.get("detail", "The Forge service rejected this action."))).left(1000)}
	return value


func _make_request() -> HTTPRequest:
	var request := HTTPRequest.new()
	request.timeout = 35.0
	request.body_size_limit = MAX_RESPONSE_BYTES
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	# This reference prevents an awaited RefCounted bridge from disappearing
	# when its creator scene is replaced before the network response arrives.
	request.set_meta("forge_transport", self)
	_owner.add_child(request)
	return request


func _publish(path: String, report: Dictionary) -> void:
	write_json(path.get_base_dir().path_join("status.json"), report)
	if not _view_closed:
		report_updated.emit(path, report)


func _fail(path: String, message: String) -> void:
	_running = false
	_submitting = false
	_publish(path, {"state": "failed", "message": message, "retry_allowed": false})


func _snapshot_name(name: String, candidate_dir: String) -> bool:
	if name in ["source.png", "proposal.json", "provenance.json", "rig.json", "rig_edits.json", "source_layout.json", "illustrated_master.png", "master.png", "theme_background.png", "theme_materials.png", "source_provenance.json", "creator_generation.json"]:
		return true
	if name in ["raw/source.png", "raw/parts.png", "raw/theme.png", "raw/proposal.json", "raw/analyse.attempt.json", "raw/parts.attempt.json", "raw/theme.attempt.json"]:
		return true
	if name.begins_with(candidate_dir + "/"):
		return name.trim_prefix(candidate_dir + "/") in ["manifest.json"] + FighterLibrary.FILENAMES
	return name.get_base_dir() in ["parts", "masks"] and _safe_part(name.get_file())


func _safe_part(name: String) -> bool:
	return _matches(name, "^(master|torso|head|arm_back|arm_front|leg_back|leg_front|leg_back_left|leg_back_right|leg_front_left|leg_front_right|tail)\\.png$")


func _safe_id(value: String) -> bool:
	return _matches(value, "^[A-Za-z0-9_-]{8,128}$")


func _matches(value: String, expression: String) -> bool:
	var regex := RegEx.new()
	regex.compile(expression)
	return regex.search(value) != null
