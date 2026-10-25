extends SceneTree
## Documentation captures from production UI and public retained artwork.
## Not a playthrough, automated acceptance suite or model-generation request.

var folder := "/tmp/gloamthread-player-guide"
var app: Node


func _initialize() -> void:
	call_deferred("_capture_guide")


func _capture_guide() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size() - 1:
		if args[index] == "--output":
			folder = args[index + 1]
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1920, 1080)
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	app = load("res://scenes/arena/boot.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	if args.has("--creator-only"):
		app._open_creator(0)
		app.creator._tabs.current_tab = 1
		await _capture("character-forge")
		app.free()
		root.get_node("AudioDirector").stop_music()
		root.get_node("AudioDirector").stop_cues()
		await create_timer(0.1).timeout
		quit()
		return
	await _capture("title")
	app._show_lobby(2)
	await _capture("arena-lobby")
	app._open_creator(0)
	app.creator._tabs.current_tab = 1
	await _capture("character-forge")
	var source := "res://assets/arena/source/generated_kiln_fox/"
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source + "source_layout.json"))
	var context := {"rig_id": "upright", "layout": layout,
		"parts": Image.load_from_file(ProjectSettings.globalize_path(source + "raw_parts.png")),
		"theme": Image.load_from_file(ProjectSettings.globalize_path(source + "raw_theme.png"))}
	var editor := ForgeLayoutEditor.new()
	editor.setup(context, "No local dollar cap. This example uses retained public artwork.\nLocal corrections make no model request.")
	root.add_child(editor)
	await _capture("layout-correction")
	editor.free()
	app.creator.cancelled.emit()
	app._show_title()
	await process_frame
	var story_button: Button
	for button: Button in app.menu_buttons:
		if "STORY" in button.text.to_upper():
			story_button = button
			break
	if story_button != null:
		story_button.pressed.emit()
		for frame in 5:
			await process_frame
		await _capture("story-title")
		var story: Node = current_scene
		if is_instance_valid(story) and story.has_method("_on_action"):
			story._on_action("new")
			if story.screen == "confirm_new":
				story._on_action("confirm_new")
			await _capture("story-join")
			story._on_action("start")
			for frame in 6:
				await physics_frame
			await _capture("story-play")
			print("STORY_GUIDE_STATE ", story.screen, " room=", story.session.current_room_id if is_instance_valid(story.session) else "no session")
			story._return_to_arena()
			for frame in 5:
				await process_frame
			await _capture("returned-arena")
	print("PLAYER_GUIDE_CAPTURES ", folder, " | production menus and retained art; no providers called")
	if is_instance_valid(current_scene):
		current_scene.free()
	root.get_node("AudioDirector").stop_music()
	root.get_node("AudioDirector").stop_cues()
	await create_timer(0.1).timeout
	quit()


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var captured := root.get_texture().get_image()
	if captured == null or captured.is_empty():
		printerr("No native image for ", name)
		quit(1)
		return
	var result := captured.save_png(folder.path_join(name + ".png"))
	if result != OK:
		printerr("Could not save ", name, ": ", result)
		quit(1)
