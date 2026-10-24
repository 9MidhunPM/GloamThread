class_name SplitPresentation
extends Control
## Only viewport A contains gameplay. Viewport B shares its World2D.

var viewport_a: SubViewport
var viewport_b: SubViewport
var world_root: Node2D
var room_slot: Node2D
var actors: Node2D
var effects: Node2D
var camera_a: FollowCamera
var camera_b: FollowCamera
var hud_a: Label
var hud_b: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	position = Vector2.ZERO
	size = Vector2(960, 360)
	viewport_a = _make_view("ViewA", 0, 3)
	viewport_a.world_2d = World2D.new()
	world_root = Node2D.new()
	world_root.name = "WorldRoot"
	viewport_a.add_child(world_root)
	room_slot = _world_branch("RoomSlot")
	actors = _world_branch("Actors")
	effects = _world_branch("Effects")
	viewport_b = _make_view("ViewB", 480, 5)
	# Assign before either camera/CanvasItem enters viewport B's tree.
	viewport_b.world_2d = viewport_a.world_2d
	camera_a = FollowCamera.new()
	camera_a.name = "CameraA"
	viewport_a.add_child(camera_a)
	camera_b = FollowCamera.new()
	camera_b.name = "CameraB"
	viewport_b.add_child(camera_b)
	hud_a = _make_hud(8)
	hud_b = _make_hud(488)
	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.position = Vector2(479, 0)
	divider.size = Vector2(2, 360)
	divider.color = Color("#10141c")
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(divider)


func _make_view(view_name: String, x: int, mask: int) -> SubViewport:
	var container := SubViewportContainer.new()
	container.name = view_name
	container.position = Vector2(x, 0)
	container.size = Vector2(480, 360)
	container.stretch = false
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(container)
	var viewport := SubViewport.new()
	viewport.name = "Viewport"
	viewport.size = Vector2i(480, 360)
	viewport.canvas_cull_mask = mask
	viewport.audio_listener_enable_2d = false
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	return viewport


func _world_branch(branch_name: String) -> Node2D:
	var branch := Node2D.new()
	branch.name = branch_name
	world_root.add_child(branch)
	return branch


func _make_hud(x: int) -> Label:
	var label := Label.new()
	label.position = Vector2(x, 6)
	label.add_theme_font_size_override("font_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func follow_players(players: Array[PlayerController], bounds: Rect2) -> void:
	camera_a.configure(players[0], bounds)
	camera_b.configure(players[1], bounds)


func update_hud(players: Array[PlayerController]) -> void:
	if players.size() != 2:
		return
	for index in 2:
		var source: DeviceSource = InputRouter.source_of(index)
		var device_name: String = source.display_name() if source != null else "Unassigned"
		var label: Label = hud_a if index == 0 else hud_b
		label.text = "P%d %s | %s\nx %d y %d" % [index + 1, players[index].profile_id, device_name, players[index].position.x, players[index].position.y]
