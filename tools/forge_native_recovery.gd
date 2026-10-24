extends SceneTree
## Explicit native integration of retained real API output, never a new request.
var capture_errors: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := {"job": "", "layout": "", "output": "/tmp/gloamthread-real-forge-qa"}
	var args := OS.get_cmdline_user_args()
	for index in range(0, args.size() - 1, 2):
		var key := args[index].trim_prefix("--")
		if options.has(key):
			options[key] = args[index + 1]
	if str(options.job).is_empty() or str(options.layout).is_empty():
		printerr("Usage: -- --job /absolute/retained/job.json --layout /absolute/source_layout.json --output /tmp/captures")
		quit(2)
		return
	var folder := str(options.output)
	DirAccess.make_dir_recursive_absolute(folder)
	var bridge: RefCounted = load("res://scripts/forge/forge_bridge.gd").new()
	var original: Dictionary = bridge.read_json(options.job)
	var source_folder := str(options.job).get_base_dir()
	var trusted := ProjectSettings.globalize_path("user://forge_jobs").path_join("qa-real-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(trusted.path_join("raw"))
	# This source-only harness imports a retained CLI job into the UI's trusted
	# layout, preserving exact source/receipt bytes rather than reconstructing them.
	DirAccess.copy_absolute(original.source_image, trusted.path_join("source.png"))
	for name: String in ["raw/source.png", "raw/parts.png", "raw/theme.png", "provenance.json"]:
		DirAccess.copy_absolute(source_folder.path_join(name), trusted.path_join(name))
	original.source_image = trusted.path_join("source.png")
	var job_path := trusted.path_join("job.json")
	bridge.write_json(job_path, original)
	DirAccess.copy_absolute(options.layout, trusted.path_join("source_layout.json"))
	var library: RefCounted = load("res://scripts/forge/fighter_library.gd").new()
	library.storage_root = folder.path_join("accepted")
	var creator: Control = load("res://scripts/forge/character_creator.gd").new()
	creator.setup(0, library)
	root.add_child(creator)
	creator.import_source(trusted.path_join("source.png"))
	creator.job_path = job_path
	creator._apply_proposal(original.proposal)
	creator._tabs.current_tab = 1
	creator._handle_status({"state": "failed", "message": "Retained board requires explicit layout correction.", "reserved_usd": 0.20})
	await _capture(folder, "layout_modal")
	if not is_instance_valid(creator._layout_editor):
		printerr("Real retained cache did not open correction UI.")
		quit(1)
		return
	var ledger := ProjectSettings.globalize_path("res://build/forge/budget.json")
	var before := FileAccess.get_sha256(ledger)
	creator._layout_editor.save_button.pressed.emit()
	var deadline := Time.get_ticks_msec() + 30000
	while creator.state not in ["complete", "failed"] and Time.get_ticks_msec() < deadline:
		await process_frame
	# State may still be failed during the first queued worker poll.
	while creator._busy and Time.get_ticks_msec() < deadline:
		await process_frame
	var passed: bool = creator.state == "complete" and not creator.candidate.is_empty()
	if passed:
		await _capture(folder, "converted_preview")
		var accepted := {"id": ""}
		creator.completed.connect(func(bundle: Dictionary) -> void: accepted.id = bundle.id)
		creator.accept_preview()
		passed = accepted.id != ""
	var result := {"passed": passed, "state": creator.state, "message": creator._message.text, "ledger_unchanged": FileAccess.get_sha256(ledger) == before, "new_requests": 0, "network": "isolated user/network namespace", "display": DisplayServer.get_name(), "candidate": creator.candidate.get("id", ""), "source_job_preserved": FileAccess.file_exists(options.job), "source_pixels_sha256": FileAccess.get_sha256(source_folder.path_join("raw/source.png"))}
	var output := FileAccess.open(folder.path_join("result.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print("FORGE_REAL_RECOVERY ", JSON.stringify(result))
	creator.free()
	await process_frame
	quit(0 if passed and bool(result.ledger_unchanged) else 1)


func _capture(folder: String, name: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(folder.path_join(name + ".png"))
