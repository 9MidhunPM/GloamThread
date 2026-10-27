extends SceneTree
## Isolated creation-boundary checks. No image provider or Python worker called.

const Library = preload("res://scripts/forge/fighter_library.gd")
const Creator = preload("res://scripts/forge/character_creator.gd")
const Bridge = preload("res://scripts/forge/forge_bridge.gd")
const FakeBridge = preload("res://tests/forge/fake_bridge.gd")

class Capture extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _notify: bool, type: int, _trace: Array[ScriptBacktrace]) -> void:
		if type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file, line, code, rationale])

var failures: Array[String] = []
var checks: int = 0
var capture := Capture.new()


func _initialize() -> void:
	OS.add_logger(capture)
	call_deferred("_run")


func _run() -> void:
	var folder := "/tmp/gloamthread-forge-tests-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var source := folder.path_join("candidate")
	_make_bundle(source)
	var library := Library.new()
	library.storage_root = folder.path_join("accepted")
	var loaded := library.load_bundle(source.path_join("manifest.json"))
	_check(loaded["ok"], "valid original-sized fixture is accepted: " + loaded["error"])
	if not loaded["ok"]:
		_finish()
		return
	_check(loaded["bundle"]["atlas"] is Texture2D, "loader creates atlas texture")
	_check(loaded["bundle"]["background"].get_size() == Vector2(640, 360), "loader retains exact background dimensions")
	var long_theme := Bridge.new().read_json(source.path_join("manifest.json"))
	long_theme["theme"]["name"] = "t".repeat(61)
	Bridge.new().write_json(source.path_join("manifest.json"), long_theme)
	_check(not library.load_bundle(source.path_join("manifest.json"))["ok"], "loader matches worker's 60-character theme-name limit")
	long_theme["theme"]["name"] = "t".repeat(60)
	long_theme["theme"]["motif"] = "m".repeat(400)
	Bridge.new().write_json(source.path_join("manifest.json"), long_theme)
	_check(library.load_bundle(source.path_join("manifest.json"))["ok"], "loader accepts the worker's full 400-character motif")
	_make_bundle(source)
	var accepted := library.accept_candidate(source)
	_check(accepted["ok"], "candidate installs atomically")
	var listed := library.list_bundles()
	_check(listed.any(func(bundle: Dictionary) -> bool: return bundle["id"] == "fixture-fighter"), "accepted fighter is discoverable offline")
	if FileAccess.file_exists(Library.BUILTIN_INDEX):
		_check(library.errors.is_empty(), "shipped built-ins pass the same complete loader: " + str(library.errors))
		for id: String in ["cinderjack", "thistlepaw"]:
			_check(listed.any(func(bundle: Dictionary) -> bool: return bundle["id"] == id), "shipped " + id + " is playable offline")
	var installed_path: String = accepted["bundle"]["manifest_path"]
	var installed_hash := FileAccess.get_sha256(installed_path)
	var original := Bridge.new().read_json(source.path_join("manifest.json"))
	var mutations := [
		["schema_version", true], ["kind", "script"], ["id", "../escape"],
		["name", ""], ["rig_id", "arbitrary"], ["kit_id", "flight"]
	]
	for mutation: Array in mutations:
		var changed: Dictionary = original.duplicate(true)
		changed[mutation[0]] = mutation[1]
		Bridge.new().write_json(source.path_join("manifest.json"), changed)
		_check(not library.accept_candidate(source)["ok"], "reject invalid " + mutation[0])
		_check(FileAccess.get_sha256(installed_path) == installed_hash, "rejected " + mutation[0] + " preserves accepted fighter")
	var extra: Dictionary = original.duplicate(true)
	extra["script"] = "do-not-execute"
	Bridge.new().write_json(source.path_join("manifest.json"), extra)
	_check(not library.load_bundle(source.path_join("manifest.json"))["ok"], "reject executable/unknown manifest fields")
	var file_escape: Dictionary = original.duplicate(true)
	file_escape["files"]["../outside.png"] = file_escape["files"]["character.png"]
	Bridge.new().write_json(source.path_join("manifest.json"), file_escape)
	_check(not library.load_bundle(source.path_join("manifest.json"))["ok"], "reject alternate file paths")
	Bridge.new().write_json(source.path_join("manifest.json"), original)
	var wrong := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	wrong.fill(Color.WHITE)
	wrong.save_png(source.path_join("portrait.png"))
	_check(not library.load_bundle(source.path_join("manifest.json"))["ok"], "reject changed file hash")
	_rehash(source, "portrait.png")
	_check(not library.load_bundle(source.path_join("manifest.json"))["ok"], "reject wrong image dimensions even with matching hash")
	_make_bundle(source)
	var atlas := Image.load_from_file(source.path_join("character.png"))
	atlas.set_pixel(0, 0, Color.WHITE)
	atlas.save_png(source.path_join("character.png"))
	_rehash(source, "character.png")
	_check(not library.load_bundle(source.path_join("manifest.json"))["ok"], "reject opaque atlas gutters")
	_make_bundle(source)
	atlas = Image.load_from_file(source.path_join("character.png"))
	atlas.fill_rect(Rect2i(2, 2, 64, 64), Color.TRANSPARENT)
	atlas.save_png(source.path_join("character.png"))
	_rehash(source, "character.png")
	_check(not library.load_bundle(source.path_join("manifest.json"))["ok"], "reject empty animation frame")
	_make_bundle(source)
	var replacement := Bridge.new().read_json(source.path_join("manifest.json"))
	replacement["name"] = "Second edition"
	Bridge.new().write_json(source.path_join("manifest.json"), replacement)
	_check(library.accept_candidate(source)["ok"], "valid replacement installs")
	var directory := DirAccess.open(library.storage_root)
	directory.include_hidden = true
	directory.list_dir_begin()
	var retained_backup := false
	var entry := directory.get_next()
	while not entry.is_empty():
		retained_backup = retained_backup or entry.begins_with(".fixture-fighter.backup-")
		entry = directory.get_next()
	directory.list_dir_end()
	_check(retained_backup, "valid replacement retains original backup")
	var bridge := Bridge.new()
	bridge.job_root = folder.path_join("jobs")
	var round_trip := bridge._integer_json(JSON.parse_string('{"schema_version":1,"crop":[0,2,16,9],"budget_usd":0.5,"flag":true}')) as Dictionary
	_check(typeof(round_trip["schema_version"]) == TYPE_INT and typeof(round_trip["crop"][0]) == TYPE_INT and round_trip["budget_usd"] == 0.5 and typeof(round_trip["flag"]) == TYPE_BOOL, "JSON writer restores strict integer tokens after Godot parsing without changing fractional costs or booleans")
	_check(not bridge.trusted_job("/tmp/outside/job.json"), "worker rejects jobs outside trusted cache")
	_check(not bridge.start("arbitrary", "/tmp/outside/job.json")["ok"], "worker rejects untrusted command before process launch")
	var drawing := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	drawing.fill(Color.TRANSPARENT)
	_check(not bridge.create_job(drawing, "")["ok"], "empty drawing cannot create a paid job")
	drawing.fill_rect(Rect2i(10, 10, 20, 40), Color("#e4a85b"))
	var job := bridge.create_job(drawing, "Synthetic fixture; never send to a provider.")
	_check(job["ok"] and bridge.trusted_job(job["path"]), "drawing persists in trusted job directory")
	_check(str(job["path"]).begins_with(folder + "/jobs/"), "boundary test jobs stay outside the production user library")
	_check(bridge.cancel(job["path"]), "cancellation marker is retained")
	_check(FileAccess.file_exists(job["path"].get_base_dir().path_join("cancel")), "cancel never relies on killing a process")
	_check(bridge.candidate_path(job["path"], "/tmp/outside/candidate").is_empty(), "status cannot redirect candidate outside its trusted job")
	_check(bridge.candidate_path(job["path"], job["path"].get_base_dir().path_join("candidate-bake-2")).ends_with("candidate-bake-2"), "numbered local rebakes stay inside the job")
	var view := SubViewport.new()
	view.size = Vector2i(1920, 1080)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var creator := Creator.new()
	creator.bridge = FakeBridge.new()
	creator.setup(1, library)
	view.add_child(creator)
	await process_frame
	await process_frame
	_check(creator.size == Vector2(1920, 1080), "creation UI fills 1920x1080 logical viewport")
	creator._canvas.paint_at(Vector2(100, 100))
	_check(creator._canvas.has_drawing(), "drawing canvas paints real source pixels")
	creator._canvas.eraser = true
	creator._canvas.paint_at(Vector2(100, 100))
	_check(not creator._canvas.has_drawing(), "eraser removes source pixels")
	creator.import_source(source.path_join("portrait.png"))
	_check(creator._canvas.pixels.get_size() == Vector2i(128, 128), "import uses source image dimensions")
	creator._palette.text = "not-a-colour"
	_check(creator._proposal().is_empty(), "proposal rejects invalid palette before provider use")
	creator._palette.text = "#112233,#445566,#778899,#aabbcc"
	_check(not creator._proposal().is_empty(), "editable proposal carries selected rig and kit")
	creator.candidate = loaded["bundle"]
	creator._apply_proposal(loaded["bundle"])
	creator._update_controls()
	_check(not creator._accept.disabled, "validated candidate can be accepted")
	creator._name.text = "Changed after preview"
	creator._update_controls()
	_check(creator._accept.disabled, "unbaked proposal changes cannot silently alter the accepted build")
	creator._apply_proposal(loaded["bundle"])
	creator._edit_dirty = true
	creator._update_controls()
	_check(creator._accept.disabled, "unbaked mask edits cannot silently be accepted")
	creator._tabs.current_tab = 1
	await process_frame
	await process_frame
	_check(creator._mask_canvas.get_global_rect().end.x <= 1920, "right-hand correction panel fits 1080p width")
	_check(creator._accept.get_global_rect().end.y <= 1080, "accept action fits 1080p height")
	_check(creator._generate.get_global_rect().end.y <= creator._message.get_global_rect().position.y, "generate stays in the visible persistent action bar")
	_check(creator._cancel_job.get_global_rect().end.y <= creator._message.get_global_rect().position.y, "cancel remains visible without scrolling during a request")
	_check(creator._retry.get_global_rect().end.y <= creator._message.get_global_rect().position.y, "retry remains visible without scrolling")
	var mock := FakeBridge.new()
	creator.bridge = mock
	creator._canvas.set_image(drawing)
	creator.analyse_source()
	_check(mock.commands == ["analyse"], "analyse launches exactly the explicit local-worker command")
	var requested_name: String = mock.read_json(creator.job_path).get("preferred_name", "")
	creator._handle_status({"state": "awaiting_approval", "message": "Review the proposal", "proposal": {"name": "Original fox", "rig_id": "quadruped", "kit_id": "storm", "theme": {"name": "Storm grove", "palette": ["#112233", "#445566", "#778899", "#aabbcc"], "motif": "Copper leaves"}, "features": ["copper scarf"]}})
	_check(creator._name.text == requested_name and creator._rig.selected == 1 and creator._kit.selected == 3, "analysis preserves the explicit name and applies its physical identity to the suggested kit")
	creator._kit.select(2)
	creator._kit.item_selected.emit(2)
	_check(creator._proposal().get("kit_id") == "storm" and not creator._kit.disabled, "the suggested kit remains editable within its compatible attack category")
	_check(mock.commands.size() == 1, "analyse completion never automatically spends on generation")
	creator.generate_candidate()
	_check(mock.commands == ["analyse", "generate"], "generation requires its own explicit action")
	var job_folder := creator.job_path.get_base_dir()
	_make_bundle(job_folder.path_join("candidate"))
	for rig_id: String in Library.RIGS:
		_make_rig(job_folder, rig_id)
		var rig_bundle := mock.read_json(job_folder.path_join("candidate/manifest.json"))
		rig_bundle["rig_id"] = rig_id
		mock.write_json(job_folder.path_join("candidate/manifest.json"), rig_bundle)
		creator._handle_status({"state": "complete", "message": "Synthetic " + rig_id, "candidate_path": job_folder.path_join("candidate")})
		_check(creator._part_records.size() == Creator.PART_IDS[rig_id].size(), "preview exposes every editable " + rig_id + " part")
	creator._mask_canvas.eraser = true
	creator._mask_canvas.paint_at(Vector2(32, 32))
	creator._pivot_changed(Vector2(19, 23))
	creator.bake_edits()
	_check(mock.commands.back() == "bake", "mask and pivot corrections use local bake")
	var edits := mock.read_json(job_folder.path_join("rig_edits.json"))
	_check(edits["parts"]["torso"]["pivot"] == [19.0, 23.0], "edited pivot persists in worker contract")
	var retained_mask := Image.load_from_file(job_folder.path_join("masks/torso.png"))
	_check(retained_mask.get_pixel(32, 32).a == 0.0, "edited transparency persists as an alpha mask")
	_make_bundle(job_folder.path_join("candidate-bake-1"))
	var rebaked_manifest := mock.read_json(job_folder.path_join("candidate-bake-1/manifest.json"))
	rebaked_manifest["rig_id"] = "floating"
	mock.write_json(job_folder.path_join("candidate-bake-1/manifest.json"), rebaked_manifest)
	creator._handle_status({"state": "complete", "message": "Synthetic rebake", "candidate_path": job_folder.path_join("candidate-bake-1")})
	_check(creator.candidate["manifest_path"].contains("candidate-bake-1") and not creator._edit_dirty, "valid local rebake replaces preview and clears dirty state")
	var previous_path: String = creator.candidate["manifest_path"]
	creator._handle_status({"state": "complete", "message": "Invalid path", "candidate_path": "/tmp/outside/candidate"})
	_check(creator.candidate["manifest_path"] == previous_path, "bad worker path preserves previous valid preview")
	var observed: Dictionary = {"bundle": {}}
	creator.completed.connect(func(bundle: Dictionary) -> void: observed["bundle"] = bundle)
	creator.accept_preview()
	_check(not observed["bundle"].is_empty() and observed["bundle"]["manifest_path"].begins_with(library.storage_root), "accept signal carries installed bundle rather than temporary candidate")
	creator._name.text = "Changed after a candidate"
	creator.generate_candidate()
	_check(creator.job_path.get_base_dir() != job_folder, "changed proposal after a complete candidate gets a fresh job")
	_check(creator.candidate["manifest_path"] == previous_path, "new generation keeps the previous validated candidate visible")
	creator._handle_status({"state": "failed", "message": "Mock replacement failed"})
	var commands_before := mock.commands.size()
	creator.bake_edits()
	_check(mock.commands.size() == commands_before, "old preview parts cannot be baked into a newly created job")
	_check_proposal_revisions(view, library, loaded["bundle"], drawing)
	_check_preview_identity(view, library, drawing)
	_check_budget_resume(view, library, drawing)
	_check_layout_preflight(view)
	await _check_layout_correction(view, library, loaded["bundle"], drawing)
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--capture":
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(args[1])
	view.free()
	await process_frame
	_finish()


func _check_preview_identity(view: SubViewport, library: FighterLibrary, drawing: Image) -> void:
	var creator := Creator.new()
	var mock := FakeBridge.new()
	creator.bridge = mock
	creator.setup(0, library)
	view.add_child(creator)
	for identity: Array in [["Fixture fighter", "ember"], ["Old wizard", "frost"]]:
		var job := mock.create_job(drawing, "Synthetic preview identity fixture; no provider calls.")
		creator.job_path = job["path"]
		var folder := creator.job_path.get_base_dir()
		_make_bundle(folder.path_join("candidate"))
		var manifest := mock.read_json(folder.path_join("candidate/manifest.json"))
		manifest["name"] = identity[0]
		mock.write_json(folder.path_join("candidate/manifest.json"), manifest)
		creator._handle_status({"state": "complete", "message": "Preview " + identity[0], "candidate_path": folder.path_join("candidate")})
		_check(Creator.Library.KITS[creator._kit.selected] == identity[1] and not creator._accept.disabled, "preview preserves a compatible saved kit and admits legacy identity correction for " + identity[0])
	creator.free()


func _make_bundle(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for filename: String in Library.SIZES:
		var dimensions: Vector2i = Library.SIZES[filename]
		var image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
		image.fill(Color("#203344"))
		if filename == "character.png":
			image.fill(Color.TRANSPARENT)
			for frame in 32:
				image.fill_rect(Rect2i((frame % 8) * 68 + 18, (frame / 8) * 68 + 10, 26, 48), Color("#e4a85b"))
		image.save_png(folder.path_join(filename))
	Bridge.new().write_json(folder.path_join("provenance.json"), {"source": "synthetic boundary-test pixels; not production art"})
	var hashes: Dictionary = {}
	for filename: String in Library.FILENAMES:
		hashes[filename] = FileAccess.get_sha256(folder.path_join(filename))
	Bridge.new().write_json(folder.path_join("manifest.json"), {"schema_version": 1, "kind": "fighter-character", "id": "fixture-fighter", "name": "Fixture fighter", "rig_id": "upright", "kit_id": "ember", "theme": {"name": "Test", "palette": ["#112233", "#445566", "#778899", "#AABBCC"], "motif": "Synthetic fixture"}, "files": hashes})


func _check_proposal_revisions(view: SubViewport, library: FighterLibrary, previous: Dictionary, drawing: Image) -> void:
	var creator := Creator.new()
	creator.bridge = FakeBridge.new()
	creator.setup(0, library)
	view.add_child(creator)
	var mock := FakeBridge.new()
	creator.bridge = mock
	creator._canvas.set_image(drawing)
	creator.candidate = previous
	creator._apply_proposal(previous)
	_check(creator._theme_name.max_length == 60 and creator._motif.max_length == 400, "editable fields use the worker's exact text limits")
	creator._motif.text = "m".repeat(400)
	creator._features.clear()
	for index in 12:
		creator._features.append("f".repeat(160))
	_check(not creator._proposal().is_empty(), "UI preserves all 12 valid 160-character feature labels and a full motif")
	creator._features.append("extra")
	_check(creator._proposal().is_empty(), "UI rejects a thirteenth visual feature before launching")
	creator._features.clear()
	_check(not creator._proposal().is_empty(), "manual creation can submit an empty feature list")
	creator.analyse_source()
	var analysis_path := creator.job_path
	var suggested: Dictionary = {"name": "Suggested name", "rig_id": "upright", "kit_id": "ember", "theme": previous["theme"].duplicate(true), "features": []}
	mock.write_json(analysis_path.get_base_dir().path_join("provenance.json"), {"schema_version": 1, "requests": {"analyse": {"state": "received"}}})
	creator._handle_status({"state": "awaiting_approval", "message": "Mock analysis", "proposal": suggested})
	creator._name.text = "Corrected before generation"
	creator._rig.select(1)
	creator._kit.select(2)
	creator.generate_candidate()
	_check(creator.job_path == analysis_path, "name, body and kit can be corrected after analysis without a fresh job")
	_check(mock.read_json(analysis_path)["proposal"]["name"] == "Corrected before generation", "first generation stores the explicitly corrected proposal")
	creator._handle_status({"state": "failed", "message": "Mock request uncertainty"})
	var unchanged_path := creator.job_path
	creator.generate_candidate()
	_check(creator.job_path == unchanged_path, "unchanged approved settings retain the job for safe worker cache handling")
	creator._handle_status({"state": "failed", "message": "Mock request uncertainty again"})
	var previous_manifest: String = previous["manifest_path"]
	var previous_digest := FileAccess.get_sha256(previous_manifest)
	for field: String in ["name", "rig", "kit", "theme", "palette", "motif", "features"]:
		var old_job := creator.job_path
		var old_digest := FileAccess.get_sha256(old_job)
		match field:
			"name": creator._name.text = "A newly approved name"
			"rig": creator._rig.select((creator._rig.selected + 1) % 3)
			"kit": creator._kit.select((creator._kit.selected + 1) % 6)
			"theme": creator._theme_name.text = "A different arena"
			"palette": creator._palette.text = "#101010,#303030,#606060,#a0a0a0"
			"motif": creator._motif.text = "A different motif"
			"features": creator._features = ["a copper scarf"]
		creator.generate_candidate()
		_check(creator.job_path != old_job, "changed " + field + " starts a fresh job after generation was attempted")
		_check(FileAccess.get_sha256(old_job) == old_digest, "changed " + field + " cannot mutate the previous approved job")
		_check(creator.candidate["manifest_path"] == previous_manifest and FileAccess.get_sha256(previous_manifest) == previous_digest, "changed " + field + " preserves the previous valid preview and bundle")
		_check(mock.generation_proposal_hash(creator.job_path) == mock.proposal_hash(mock.read_json(creator.job_path)["proposal"]), "fresh " + field + " proposal is durably frozen")
		creator._handle_status({"state": "failed", "message": "Mock failed " + field})
	var reopened := mock.create_job(drawing, "")
	var reopened_path: String = reopened["path"]
	var reopened_job := mock.read_json(reopened_path)
	reopened_job["proposal"] = suggested
	mock.write_json(reopened_path, reopened_job)
	DirAccess.make_dir_absolute(reopened_path.get_base_dir().path_join("raw"))
	mock.write_json(reopened_path.get_base_dir().path_join("raw/parts.attempt.json"), {"state": "uncertain"})
	_check(mock.generation_proposal_hash(reopened_path) == mock.proposal_hash(suggested), "reopened paid attempt freezes its original proposal without a UI snapshot")
	mock.write_json(reopened_path.get_base_dir().path_join("status.json"), {"state": "failed", "message": "Retained mock attempt"})
	creator.resume_job(reopened_path)
	creator._name.text = "Revised after reopening"
	creator.generate_candidate()
	_check(creator.job_path != reopened_path, "reopened failed paid job also forks when the design changes")
	creator._handle_status({"state": "failed", "message": "No provider was called"})
	_check(creator.candidate["manifest_path"] == previous_manifest, "failed replacement still retains the original preview")
	var cached := mock.create_job(drawing, "")
	var cached_path: String = cached["path"]
	var cached_job := mock.read_json(cached_path)
	cached_job["proposal"] = suggested
	mock.write_json(cached_path, cached_job)
	_make_bundle(cached_path.get_base_dir().path_join("candidate"))
	_check(mock.generation_proposal_hash(cached_path) == mock.proposal_hash(suggested), "a retained candidate freezes its original approved proposal without attempt metadata")
	creator.free()


func _check_layout_preflight(view: SubViewport) -> void:
	# Reproduce Save/convert sending an empty crop to Python, then reopening the
	# same editor. The actual pixel/opacity boundary must stop that round trip.
	var parts := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	parts.fill(Color.WHITE)
	parts.fill_rect(Rect2i(341, 0, 341, 341), Color.TRANSPARENT)
	var theme := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	theme.fill(Color("#203344"))
	var context := {"ok": true, "rig_id": "upright", "parts": parts, "theme": theme, "raw_parts_sha256": "a".repeat(64), "raw_theme_sha256": "b".repeat(64)}
	context["layout"] = Bridge.new().default_source_layout(context)
	var editor := ForgeLayoutEditor.new()
	editor.setup(context, "Local edits are free")
	view.add_child(editor)
	var observed := {"conversions": 0}
	editor.apply_requested.connect(func(_layout: Dictionary) -> void: observed.conversions += 1)
	editor.save_button.pressed.emit()
	_check(observed.conversions == 0, "Save/convert keeps an empty generated head in the editor without starting conversion")
	_check(editor.notice.text.to_lower().contains("head"), "empty-part validation names the crop to fix instead of hiding the worker error")
	_check(editor.target.get_item_text(editor.target.selected) == "Head", "invalid part is selected so the next drag fixes the reported crop")
	var before := editor.canvas.crop
	var point := editor.canvas.image_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = point
		editor.canvas._gui_input(click)
	_check(editor.canvas.crop == before, "clicking without dragging never destroys an existing part crop")
	parts.fill_rect(Rect2i(341, 0, 341, 341), Color(1, 1, 1, 0.5))
	editor.save_button.pressed.emit()
	_check(observed.conversions == 0 and editor.notice.text.contains("opacity"), "translucent art below the threshold is rejected with opacity advice")
	editor.cutoff.value = 100
	editor.save_button.pressed.emit()
	_check(observed.conversions == 1, "lowering the cutoff for visible translucent art permits local conversion")
	parts.fill_rect(Rect2i(682, 682, 342, 342), Color.TRANSPARENT)
	editor.board_tabs.current_tab = 1
	editor.save_button.pressed.emit()
	_check(observed.conversions == 1 and editor.board_tabs.current_tab == 0 and editor.notice.text.contains("Master"), "an empty master crop blocks conversion and returns from the theme board to its target")
	editor.free()


func _check_layout_correction(view: SubViewport, library: FighterLibrary, previous: Dictionary, drawing: Image) -> void:
	var creator := Creator.new()
	creator.bridge = FakeBridge.new()
	creator.setup(0, library)
	view.add_child(creator)
	var mock := FakeBridge.new()
	creator.bridge = mock
	creator.candidate = previous
	creator._apply_proposal(previous)
	creator._canvas.set_image(drawing)
	creator._tabs.current_tab = 1
	var job := mock.create_job(drawing, "Synthetic cached conversion, never contact a provider.")
	var path: String = job["path"]
	var folder := path.get_base_dir()
	var original_job := mock.read_json(path)
	# This regression exercises retained limb-grid jobs. New create_job defaults
	# to the whole illustrated character, which deliberately ignores limb crops.
	original_job["art_mode"] = ""
	original_job["proposal"] = creator._proposal()
	mock.write_json(path, original_job)
	creator.job_path = path
	creator._handle_status({"state": "failed", "message": "Fixture without retained images"})
	_check(not is_instance_valid(creator._layout_editor), "generation failure without both raw images never opens correction UI")
	DirAccess.make_dir_recursive_absolute(folder.path_join("raw"))
	var board := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	board.fill(Color(0.4, 0.5, 0.6, 0.3))
	board.fill_rect(Rect2i(20, 30, 90, 150), Color("#e4a85b"))
	for index in range(1, 9):
		board.fill_rect(Rect2i(index % 3 * 341 + 20, index / 3 * 341 + 30, 90, 150), Color("#e4a85b"))
	board.save_png(folder.path_join("raw/parts.png"))
	board.fill(Color("#203344"))
	board.save_png(folder.path_join("raw/theme.png"))
	DirAccess.copy_absolute(folder.path_join("source.png"), folder.path_join("raw/source.png"))
	var source_hash := FileAccess.get_sha256(folder.path_join("source.png"))
	var provenance := {"schema_version": 1, "worker_version": "arena-forge-1", "approved_proposal": original_job["proposal"], "source": {"original_sha256": source_hash, "sha256": source_hash, "file": "raw/source.png"}, "requests": {}}
	for kind: String in ["parts", "theme"]:
		provenance["requests"][kind] = {"file": "raw/" + kind + ".png", "sha256": FileAccess.get_sha256(folder.path_join("raw/" + kind + ".png"))}
	mock.write_json(folder.path_join("provenance.json"), provenance)
	_make_rig(folder, "upright")
	mock.write_json(folder.path_join("rig_edits.json"), {"schema_version": 1, "parts": {"torso": {"pivot": [20, 21]}}})
	_make_bundle(folder.path_join("candidate"))
	var saved_original := FileAccess.get_sha256(path)
	var saved_provenance := FileAccess.get_sha256(folder.path_join("provenance.json"))
	var saved_edits := FileAccess.get_sha256(folder.path_join("rig_edits.json"))
	var saved_candidate := FileAccess.get_sha256(folder.path_join("candidate/manifest.json"))
	var raw := mock.raw_layout_context(path)
	_check(raw["ok"] and raw["rig_id"] == "upright", "fixed retained PNG boards expose their approved rig and image hashes")
	var layout: Dictionary = raw["layout"].duplicate(true)
	_check(layout["alpha_cutoff"] == 192 and layout["parts"]["torso"]["crop"] == [0, 0, 341, 341] and layout["master_crop"] == [682, 682, 342, 342], "correction defaults match strict grid slots and reviewed alpha cutoff")
	_check(mock.source_layout_error(layout, raw).is_empty(), "default complete layout passes boundary validation")
	var empty_crop := layout.duplicate(true)
	empty_crop["parts"]["head"]["crop"] = [150, 200, 30, 30]
	var draft_count := DirAccess.get_directories_at(mock.job_root).size()
	_check(not mock.save_source_layout(path, empty_crop)["ok"], "blank crop is blocked at annotation save, not only the UI")
	_check(not mock.create_layout_job(path, empty_crop)["ok"] and DirAccess.get_directories_at(mock.job_root).size() == draft_count, "blank crop cannot clone another doomed local draft")
	for mutation: Array in [["alpha_cutoff", true], ["alpha_cutoff", 0], ["alpha_cutoff", 256], ["alpha_cutoff", 1.5], ["master_crop", [-1, 0, 32, 32]], ["master_crop", [1000, 0, 25, 30]], ["background_crop", [0, 0, 0, 1]], ["background_crop", [0, 0, 24.5, 30]], ["material_crops", []], ["raw_parts_sha256", "wrong"], ["raw_theme_sha256", "wrong"], ["path", "../outside.png"]]:
		var bad := layout.duplicate(true)
		bad[mutation[0]] = mutation[1]
		_check(not mock.source_layout_error(bad, raw).is_empty(), "reject invalid source layout " + str(mutation))
	var missing_part := layout.duplicate(true)
	missing_part["parts"].erase("head")
	_check(not mock.source_layout_error(missing_part, raw).is_empty(), "layout requires every approved rig part")
	var extra_part := layout.duplicate(true)
	extra_part["parts"]["script"] = {"crop": [1, 2, 3, 4]}
	_check(not mock.source_layout_error(extra_part, raw).is_empty(), "layout rejects extra part names")
	var no_materials := layout.duplicate(true)
	no_materials.erase("material_crops")
	_check(mock.source_layout_error(no_materials, raw).is_empty(), "optional material crops can retain strict defaults")
	_check(not mock.raw_layout_context("/tmp/outside/job.json")["ok"], "raw correction cannot read arbitrary job paths")
	var requests_before_preview := mock.commands.size()
	creator._handle_status({"state": "complete", "message": "Fixture valid retained preview", "candidate_path": folder.path_join("candidate")})
	_check(creator._repair.visible and not creator._layout_context.is_empty() and creator._layout_job_path == path, "successful retained preview exposes cached layout correction")
	_check(not is_instance_valid(creator._layout_editor) and mock.commands.size() == requests_before_preview, "successful preview offers correction without opening its editor or starting any authoring request")
	creator._handle_status({"state": "failed", "message": "Fixture conversion rejected its grid", "reserved_usd": 0.25})
	await process_frame
	await process_frame
	var editor: ForgeLayoutEditor = creator._layout_editor
	_check(is_instance_valid(editor) and creator._repair.visible, "retained conversion failure opens a recoverable local correction modal")
	_check(editor.notice.text.contains("Fixture conversion rejected its grid"), "conversion failure remains visible inside the reopened correction editor")
	_check(creator._generate.focus_mode == Control.FOCUS_NONE and creator._name.focus_mode == Control.FOCUS_NONE, "correction modal removes underlying creator controls from keyboard focus")
	var confined := true
	for reverse: bool in [false, true]:
		editor.save_button.grab_focus()
		for step in 30:
			var tab := InputEventKey.new()
			tab.keycode = KEY_TAB
			tab.pressed = true
			tab.shift_pressed = reverse
			view.push_input(tab, true)
			await process_frame
			var focused := view.gui_get_focus_owner()
			confined = confined and is_instance_valid(focused) and editor.is_ancestor_of(focused)
	_check(confined, "repeated Tab and Shift-Tab remain inside the correction editor")
	_check(editor.save_button.get_global_rect().end.y <= 1080 and editor.canvas.get_global_rect().end.x <= 1920, "correction modal and local conversion action fit 1920 by 1080")
	_check(editor.target.item_count == 7, "upright parts board exposes six parts and whole-character master")
	_check(editor.canvas.source_point(Vector2(-200, -200)) == Vector2i.ZERO and editor.canvas.source_point(Vector2(10000, 10000)) == Vector2i(1023, 1023), "canvas coordinates clamp to raw bounds including letterbox edges")
	var rect := editor.canvas.image_rect()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = rect.position + Vector2(20.1, 30.1) / 1024.0 * rect.size
	editor.canvas._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = rect.position + Vector2(109.1, 179.1) / 1024.0 * rect.size
	editor.canvas._gui_input(release)
	_check(editor.layout["parts"]["torso"]["crop"] == [20, 30, 90, 150], "mouse drag assigns exact source pixels to the selected part")
	editor.board_tabs.current_tab = 1
	_check(editor.target.item_count == 5 and editor.canvas.lock_widescreen, "theme board exposes background and four materials with optional 16:9 drag")
	editor.canvas.select_between(Vector2i(0, 140), Vector2i(575, 463))
	var crop := editor.canvas.crop
	editor._crop_selected([crop.position.x, crop.position.y, crop.size.x, crop.size.y])
	_check(editor.layout["background_crop"] == [0, 140, 576, 324], "16:9 scenery crop can exclude a generated foreground character")
	editor.canvas.select_between(Vector2i(1023, 1023), Vector2i(1023, 1023))
	_check(editor.canvas.crop.end.x <= 1024 and editor.canvas.crop.end.y <= 1024 and editor.canvas.crop.size.x * 9 == editor.canvas.crop.size.y * 16, "edge drag keeps a nonempty bounded 16:9 crop")
	editor._target_changed(1)
	editor._crop_selected([10, 600, 128, 128])
	_check(editor.layout["material_crops"][0] == [10, 600, 128, 128], "theme material targets save independently of scenery crop")
	editor._coordinates[0].value = 1023
	_check(editor.layout["material_crops"][0][0] == 1020 and editor.layout["material_crops"][0][2] == 4, "numeric crop origin and width clamp to the converter's four-pixel minimum")
	editor.cutoff.value = 230
	_check(editor.layout["alpha_cutoff"] == 230, "opacity correction remains a bounded integer in the saved layout")
	creator._name.text = "Changed design"
	editor._apply()
	_check(mock.commands.is_empty() and creator.job_path == path, "layout correction cannot reuse cached art for a changed approved design")
	creator._apply_proposal(original_job["proposal"])
	creator._edit_dirty = true
	editor._apply()
	_check(mock.commands == ["bake"] and creator.job_path != path, "correction starts only local bake in a new trusted job")
	_check(creator._generate.focus_mode == Control.FOCUS_ALL and creator._name.focus_mode == Control.FOCUS_ALL, "closing correction restores the creator keyboard focus modes")
	var local_path := creator.job_path
	var local_folder := local_path.get_base_dir()
	_check(mock.trusted_job(local_path) and mock.read_json(local_path)["proposal"] == original_job["proposal"], "new local draft retains exactly the approved proposal")
	_check(FileAccess.get_file_as_string(local_path).contains('"schema_version": 1,') and FileAccess.get_file_as_string(local_folder.path_join("provenance.json")).contains('"schema_version": 1,'), "cloned job and provenance serialize schema versions as Python integer tokens")
	_check(mock.read_json(local_folder.path_join("source_layout.json"))["background_crop"] == [0.0, 140.0, 576.0, 324.0], "new draft retains the corrected hash-bound crop annotation")
	_check(FileAccess.get_sha256(path) == saved_original and FileAccess.get_sha256(folder.path_join("provenance.json")) == saved_provenance and FileAccess.get_sha256(folder.path_join("rig_edits.json")) == saved_edits and FileAccess.get_sha256(folder.path_join("candidate/manifest.json")) == saved_candidate, "local correction preserves old job, provenance, masks/pivots and candidate byte-for-byte")
	_check(not FileAccess.file_exists(local_folder.path_join("rig.json")) and not FileAccess.file_exists(local_folder.path_join("rig_edits.json")) and not DirAccess.dir_exists_absolute(local_folder.path_join("candidate")) and not FileAccess.file_exists(local_folder.path_join("budget.json")), "fresh correction excludes previous rig, edits, candidate and ledger")
	_check(creator.candidate["manifest_path"] == folder.path_join("candidate/manifest.json"), "local conversion keeps the latest successful preview until replacement validates")
	_make_bundle(local_folder.path_join("candidate"))
	creator._handle_status({"state": "complete", "message": "Synthetic local conversion", "candidate_path": local_folder.path_join("candidate")})
	_check(creator.candidate["manifest_path"] == local_folder.path_join("candidate/manifest.json") and not creator._edit_dirty, "valid local conversion replaces the preview and clears stale part edit state")
	var bad_provenance := provenance.duplicate(true)
	bad_provenance["requests"]["parts"]["sha256"] = "wrong"
	mock.write_json(folder.path_join("provenance.json"), bad_provenance)
	_check(not mock.create_layout_job(path, layout)["ok"], "local clone rejects a raw image inconsistent with request provenance")
	mock.write_json(folder.path_join("provenance.json"), provenance)
	board.set_pixel(0, 0, Color.WHITE)
	board.save_png(folder.path_join("raw/theme.png"))
	_check(not mock.save_source_layout(path, layout)["ok"] and not mock.create_layout_job(path, layout)["ok"], "raw hash change after opening blocks both annotation save and local cloning")
	_check(mock.commands == ["bake"], "all layout correction regressions perform no generation or analysis calls")
	creator.free()


func _check_budget_resume(view: SubViewport, library: FighterLibrary, drawing: Image) -> void:
	var creator := Creator.new()
	var mock := FakeBridge.new()
	creator.bridge = mock
	creator.setup(0, library)
	view.add_child(creator)
	creator._canvas.set_image(drawing)
	creator.generate_candidate()
	var blocked_path := creator.job_path
	var budget := {"total_limit_usd": 0.50, "total_reserved_usd": 0.35, "total_remaining_usd": 0.15, "job_limit_usd": 0.50, "job_reserved_usd": 0.0, "job_remaining_usd": 0.50, "required_usd": 0.20}
	creator._handle_status({"state": "failed", "message": "Fixture shared allowance is too small", "code": "shared_budget_exceeded", "retry_allowed": true, "reserved_usd": 0.0, "budget": budget})
	_check(creator._cost.text.contains("$0.35 / $0.50") and creator._cost.text.contains("$0.15 left") and creator._cost.text.contains("Need $0.20"), "budget UI distinguishes total reserved, remaining and required from character allowance")
	_check(creator._retry.text == "Resume blocked job", "a safe budget failure offers explicit resume instead of discarding its draft")
	creator._refresh_configuration()
	_check(creator._cost.text.contains("$0.35 / $2.00") and creator._cost.text.contains("$1.65 left"), "setup refresh reads the new configured total without a request")
	var no_cap := {"limits_enabled": false, "total_limit_usd": null, "total_remaining_usd": null, "job_limit_usd": null, "job_remaining_usd": null, "total_reserved_usd": 0.55, "required_usd": 0.20}
	creator._update_budget({"budget": no_cap})
	_check(creator._cost.text.contains("No local dollar cap") and creator._cost.text.contains("$0.55") and not creator._cost.text.contains("left"), "uncapped status displays recorded estimates without casting null caps or claiming billing")
	creator._retry_job()
	_check(creator.job_path == blocked_path and mock.commands == ["generate", "generate"], "explicit budget resume reuses the approved draft without another analysis")
	creator._handle_status({"state": "failed", "message": "The remaining shared or job budget cannot cover all missing image requests. No image request or new reservation was made.", "reserved_usd": 0.05})
	_check(creator._retry.text == "Resume blocked job", "legacy image preflight failure remains resumable after paid analysis")
	creator._retry_job()
	_check(creator.job_path == blocked_path and mock.commands == ["generate", "generate", "generate"], "legacy budget resume keeps the analysed draft and does not repeat analysis")
	creator._handle_status({"state": "failed", "message": "A prior paid attempt is uncertain", "reserved_usd": 0.1})
	_check(creator._retry.text == "New attempt", "an uncertain paid failure never offers an automatic same-job retry")
	creator.free()


func _rehash(folder: String, filename: String) -> void:
	var manifest := Bridge.new().read_json(folder.path_join("manifest.json"))
	manifest["files"][filename] = FileAccess.get_sha256(folder.path_join(filename))
	Bridge.new().write_json(folder.path_join("manifest.json"), manifest)


func _make_rig(folder: String, rig_id: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder.path_join("parts"))
	var parts: Array[Dictionary] = []
	for id: String in Creator.PART_IDS[rig_id]:
		var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		image.fill_rect(Rect2i(16, 16, 32, 32), Color("#e4a85b"))
		image.save_png(folder.path_join("parts/" + id + ".png"))
		parts.append({"id": id, "file": "parts/" + id + ".png", "pivot": [32, 32], "anchor": [32, 32]})
	Bridge.new().write_json(folder.path_join("rig.json"), {"schema_version": 1, "rig_id": rig_id, "parts": parts})


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	failures.append_array(capture.errors)
	for failure: String in failures:
		printerr("FAIL forge: " + failure)
	print("Forge boundary/UI checks: %d assertions, %d failures; no providers called." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
