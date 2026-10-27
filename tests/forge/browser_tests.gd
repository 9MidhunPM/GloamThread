extends SceneTree
## Browser transfer boundaries, exercised without network or model requests.

const Library = preload("res://scripts/forge/fighter_library.gd")
const Bridge = preload("res://scripts/forge/web_forge_bridge.gd")
class FakeRemote extends WebForgeBridge:
	var responses: Array[Dictionary] = []
	var calls: int = 0
	func _request(_endpoint: String, _method: int = HTTPClient.METHOD_GET, _payload: Dictionary = {}) -> Dictionary:
		calls += 1
		return responses.pop_front() if not responses.is_empty() else {"ok": false, "error": "Unexpected test request."}

class DelayedCancellation extends WebForgeBridge:
	var probe: Dictionary = {}
	func _request(endpoint: String, _method: int = HTTPClient.METHOD_GET, _payload: Dictionary = {}) -> Dictionary:
		probe["calls"] = int(probe.get("calls", 0)) + 1
		if not endpoint.ends_with("/cancel"):
			return {"ok": false, "error": "Unexpected test request."}
		var request := _make_request()
		probe["started"] = true
		probe["persistent_owner"] = request.get_parent().name == "BrowserRuntime"
		await request.get_tree().process_frame
		await request.get_tree().process_frame
		probe["completed"] = is_instance_valid(request) and request.is_inside_tree()
		request.queue_free()
		return {"ok": true}

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var library := Library.new()
	library.storage_root = "user://browser-test-fighters-%d" % Time.get_ticks_usec()
	var builtins := library.list_bundles()
	_check(not builtins.is_empty(), "public built-ins are available without an invitation")
	if builtins.is_empty():
		_finish()
		return
	var exported := library.export_bundle(builtins[0]["manifest_path"])
	_check(exported.get("ok", false), "admitted fighter exports to a six-file ZIP")
	if not exported.get("ok", false):
		_finish()
		return
	var bytes: PackedByteArray = exported["bytes"]
	_check(library._archive_error(bytes).is_empty(), "exported ZIP passes bounded directory preflight")
	var restored := library.import_archive(bytes)
	_check(restored.get("ok", false), "fighter ZIP round trip admits and installs all media")
	if restored.get("ok", false):
		_check(restored["bundle"]["files"] == builtins[0]["files"], "backup retains exact hashes and provenance")
		var manifest_path: String = restored["bundle"]["manifest_path"]
		var previous := FileAccess.get_sha256(manifest_path)
		var damaged := bytes.duplicate()
		damaged[0] = 0
		_check(not library.import_archive(damaged).get("ok", false), "bad local ZIP header rejected before decompression")
		_check(FileAccess.get_sha256(manifest_path) == previous, "rejected archive preserves accepted fighter")
	var bomb := bytes.duplicate()
	var central := _find_header(bomb, 0x02014b50)
	if central >= 0:
		bomb.encode_u32(central + 24, Library.MAX_FILE_BYTES + 1)
	_check(not library._archive_error(bomb).is_empty(), "oversized decompressed entry rejected before reading")
	var traversal := bytes.duplicate()
	if central >= 0:
		var name_length := traversal.decode_u16(central + 28)
		var bad := "../" + "x".repeat(maxi(0, name_length - 3))
		for offset in name_length:
			traversal[central + 46 + offset] = bad.to_utf8_buffer()[offset]
	_check(not library._archive_error(traversal).is_empty(), "archive traversal and unexpected files rejected")
	var linked := bytes.duplicate()
	if central >= 0:
		linked.encode_u32(central + 38, 0xa1ff0000)
	_check(not library._archive_error(linked).is_empty(), "archive symbolic links rejected")
	_check(not library.import_archive(PackedByteArray()).get("ok", false), "empty backup is rejected")

	var bridge := Bridge.new()
	bridge.job_root = "user://browser-test-jobs-%d" % Time.get_ticks_usec()
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(16, 16, 32, 32), Color.WHITE)
	var created := bridge.create_job(image, "Boundary fixture", "Fixture")
	_check(created.get("ok", false), "hosted adapter retains a browser-local drawing before upload")
	if created.get("ok", false):
		var path: String = created["path"]
		var source_hash := FileAccess.get_sha256(path.get_base_dir().path_join("source.png"))
		_check(not bridge.apply_snapshot(path, {"files": {"../escape": "eA=="}}).get("ok", false), "snapshot traversal is rejected")
		_check(not bridge.apply_snapshot(path, {"files": {"job.json": "e30="}}).get("ok", false), "server cannot supply filesystem paths through job.json")
		_check(not bridge.apply_snapshot(path, {"files": {}, "candidate_dir": "../outside"}).get("ok", false), "server candidate directory must be fixed and local")
		_check(not bridge.apply_snapshot(path, {"files": {"proposal.json": Marshalls.raw_to_base64("[]".to_utf8_buffer())}}).get("ok", false), "snapshot metadata must be a bounded object")
		var snapshot: Dictionary = {}
		for name: String in ["manifest.json"] + Library.FILENAMES:
			snapshot["candidate/" + name] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(str(builtins[0]["manifest_path"]).get_base_dir().path_join(name)))
		_check(bridge.apply_snapshot(path, {"files": snapshot, "candidate_dir": "candidate"}).get("ok", false), "fully admitted candidate is staged under the browser draft")
		var candidate_path := path.get_base_dir().path_join("candidate/manifest.json")
		var candidate_hash := FileAccess.get_sha256(candidate_path)
		snapshot["candidate/portrait.png"] = Marshalls.raw_to_base64("corrupt".to_utf8_buffer())
		_check(not bridge.apply_snapshot(path, {"files": snapshot, "candidate_dir": "candidate"}).get("ok", false), "invalid hosted candidate is rejected before replacement")
		_check(FileAccess.get_sha256(candidate_path) == candidate_hash, "invalid hosted result preserves the previous valid preview")
		_check(not bridge.apply_snapshot(path, {"files": {"candidate/portrait.png": snapshot["candidate/portrait.png"]}}).get("ok", false), "partial candidate cannot replace any previous preview file")
		_check(FileAccess.get_sha256(path.get_base_dir().path_join("source.png")) == source_hash, "transfer failures preserve the retained source")
		_check(not bridge.start("generate", path).get("ok", false), "generation requires an unlocked invite and sends no request here")
		var fake := FakeRemote.new()
		fake.job_root = bridge.job_root
		fake._active_path = path
		fake._running = true
		fake.write_json(path.get_base_dir().path_join("_remote.json"), {"job_id": "fixture-job-1234", "pending_action": "attempt-1234", "previous_operation_id": "old-operation"})
		fake.responses = [{"ok": true, "state": "draft", "operation_id": ""}]
		await fake._poll_remote(path)
		_check(not fake.is_running() and fake.read_json(path.get_base_dir().path_join("status.json")).get("state") == "failed" and fake.calls == 1, "lost POST with no accepted operation stops safely without retries or infinite waiting")
		fake._running = true
		fake.responses = [{"ok": true, "state": "generating", "operation_id": "new-operation"}]
		await fake._poll_remote(path)
		_check(fake.is_running() and not fake.read_json(path.get_base_dir().path_join("_remote.json")).has("pending_action"), "lost POST accepted by the server is recovered through read-only status")
		var clean_snapshot: Dictionary = {}
		for name: String in ["manifest.json"] + Library.FILENAMES:
			clean_snapshot["candidate/" + name] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(str(builtins[0]["manifest_path"]).get_base_dir().path_join(name)))
		fake.responses = [{"ok": true, "state": "complete", "operation_id": "new-operation"}, {"ok": true, "files": clean_snapshot, "candidate_dir": "candidate"}]
		await fake._poll_remote(path)
		var terminal_calls := fake.calls
		fake.status(path)
		await process_frame
		_check(not fake.is_running() and fake.calls == terminal_calls, "completed drafts do not repeatedly download snapshots")
		_check(bridge.apply_snapshot(path, {"files": {"proposal.json": Marshalls.raw_to_base64('{"name":"Fixture"}'.to_utf8_buffer())}, "candidate_dir": ""}).get("ok", false), "analysis snapshots without a candidate retain their proposal")
		var atomic_folder := path.get_base_dir()
		var atomic_staging := atomic_folder.path_join(".atomic-test")
		DirAccess.make_dir_recursive_absolute(atomic_staging)
		bridge.write_json(atomic_folder.path_join("atomic-a.json"), {"value": "old"})
		bridge.write_json(atomic_staging.path_join("atomic-a.json"), {"value": "new"})
		var install: Array[String] = ["atomic-a.json", "missing.json"]
		_check(not bridge._publish_snapshot(atomic_folder, atomic_staging, install).get("ok", false), "mid-publish failure is reported")
		_check(bridge.read_json(atomic_folder.path_join("atomic-a.json")).get("value") == "old", "mid-publish failure rolls earlier file replacements back")
		var view := Node.new()
		root.add_child(view)
		var closing: WebForgeBridge = DelayedCancellation.new()
		closing.job_root = bridge.job_root
		closing.attach(view)
		closing._active_path = path
		closing._running = true
		var probe: Dictionary = {}
		closing.probe = probe
		closing.write_json(path.get_base_dir().path_join("_remote.json"), {"job_id": "fixture-job-1234"})
		_check(closing.cancel(path) and probe.get("started", false), "leaving dispatches cancellation before the creator can be freed")
		view.queue_free()
		closing = null
		await process_frame
		await process_frame
		await process_frame
		_check(not is_instance_valid(view) and probe.get("persistent_owner", false) and probe.get("completed", false), "cancellation transport and bridge survive creator scene disposal")
		_check(probe.get("calls") == 1 and bridge.read_json(path.get_base_dir().path_join("status.json")).get("state") == "cancelled", "creator disposal completes one cancellation without a retry or further stage")
	var pricing := CharacterCreator.new()
	pricing.bridge = Bridge.new()
	pricing._cost = Label.new()
	pricing.add_child(pricing._cost)
	pricing._update_budget({"budget": {"limits_enabled": false, "total_limit_usd": null, "total_reserved_usd": 0.05, "required_usd": 0}, "request_estimates": {"analyse_usd": 0.05, "generate_usd": 0.20, "bake_usd": 0}})
	_check(pricing._cost.text.contains("Analyse $0.05"), "hosted drawing analysis estimate is explicit")
	_check(pricing._cost.text.contains("New artwork $0.20"), "hosted artwork estimate does not become zero between actions")
	_check(pricing._cost.text.contains("Saved conversion $0.00"), "cached conversion remains explicitly SDK-free")
	pricing._update_budget({"budget": {"limits_enabled": false, "total_limit_usd": null, "total_reserved_usd": 0.25, "required_usd": 0}})
	_check(pricing._cost.text.contains("recorded estimates $0.25") and pricing._cost.text.contains("New artwork $0.20"), "local phase reports retain named action estimates and update history")
	pricing.free()
	var refreshed := CharacterCreator.new()
	var refresh_bridge := FakeRemote.new()
	refreshed.bridge = refresh_bridge
	refreshed.candidate = {"id": "retained-preview"}
	for terminal: String in ["complete", "awaiting_approval"]:
		var report := {"state": terminal, "message": "Retained terminal state"}
		refreshed.state = terminal
		refreshed._last_status = JSON.stringify(report)
		refreshed._busy = true
		refresh_bridge._running = false
		refreshed._handle_status(report)
		_check(not refreshed._busy and refreshed.state == terminal, "identical " + terminal + " after hosted refresh releases the busy latch")
		refreshed._process(0.31)
		_check(refreshed.candidate.get("id") == "retained-preview" and not is_instance_valid(refreshed._layout_editor) and refresh_bridge.calls == 0, "identical " + terminal + " refresh preserves preview without requests or false correction modal")
	var old_terminal := {"state": "complete", "message": "Previous operation"}
	refreshed._last_status = JSON.stringify(old_terminal)
	refreshed._busy = true
	refresh_bridge._running = true
	refreshed._handle_status(old_terminal)
	_check(refreshed._busy and refresh_bridge.calls == 0, "cached terminal report cannot release a genuinely running operation")
	refreshed.free()
	_finish()


func _find_header(bytes: PackedByteArray, header: int) -> int:
	for offset in range(bytes.size() - 4):
		if bytes.decode_u32(offset) == header:
			return offset
	return -1


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	for message: String in failures:
		printerr("FAIL browser Forge: " + message)
	print("Browser Forge transfer checks: %d assertions, %d failures; no providers called." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
