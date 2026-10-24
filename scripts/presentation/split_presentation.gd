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
var _catalog: AssetCatalog
var _background_a: CanvasLayer
var _background_b: CanvasLayer
var _objective_a: Label
var _objective_b: Label
var _hearts_a: Array[TextureRect] = []
var _hearts_b: Array[TextureRect] = []
var room_title_ticks_left: int = 0
var _room_title_panels: Array[Control] = []
var _room_title_labels: Array[Label] = []


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
	actors.y_sort_enabled = true
	effects = _world_branch("Effects")
	effects.z_index = 5
	viewport_b = _make_view("ViewB", 480, 5)
	# Assign before either camera/CanvasItem enters viewport B's tree.
	viewport_b.world_2d = viewport_a.world_2d
	camera_a = FollowCamera.new()
	camera_a.name = "CameraA"
	viewport_a.add_child(camera_a)
	camera_b = FollowCamera.new()
	camera_b.name = "CameraB"
	viewport_b.add_child(camera_b)
	_hud_shade(0, 76)
	_hud_shade(326, 34)
	hud_a = _make_hud(8)
	hud_b = _make_hud(488)
	_objective_a = _make_objective(8)
	_objective_b = _make_objective(488)
	_make_room_title(0)
	_make_room_title(480)
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


func _hud_shade(y: int, height: int) -> void:
	var shade := ColorRect.new()
	shade.position = Vector2(0, y)
	shade.size = Vector2(960, height)
	shade.color = Color(0.04, 0.06, 0.09, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _make_hud(x: int) -> Label:
	var label := Label.new()
	label.position = Vector2(x, 25)
	label.size = Vector2(460, 48)
	label.add_theme_font_size_override("font_size", 8)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _make_objective(x: int) -> Label:
	var label := _make_hud(x)
	label.position.y = 330
	label.size.y = 28
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_room_title(view_x: int) -> void:
	var panel := Control.new()
	panel.name = "RoomTitleA" if view_x == 0 else "RoomTitleB"
	panel.position = Vector2(view_x + 80, 84)
	panel.size = Vector2(320, 34)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	add_child(panel)
	var shade := ColorRect.new()
	shade.size = panel.size
	shade.color = Color(0.04, 0.06, 0.09, 0.86)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(shade)
	var label := Label.new()
	label.position = Vector2(4, 3)
	label.size = Vector2(312, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("e3d6b3"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	var thread := ColorRect.new()
	thread.position = Vector2(104, 30)
	thread.size = Vector2(112, 1)
	thread.color = Color("ad945e")
	thread.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(thread)
	_room_title_panels.append(panel)
	_room_title_labels.append(label)


func show_room_entry(room_name: String) -> void:
	room_title_ticks_left = 120
	for index in _room_title_panels.size():
		_room_title_labels[index].text = room_name
		_room_title_panels[index].modulate.a = 1.0
		_room_title_panels[index].visible = true


func set_themes(catalog: AssetCatalog, theme_a: String, theme_b: String) -> void:
	_catalog = catalog
	viewport_a.canvas_cull_mask = 1 | (2 if theme_a == "ember" else 4)
	viewport_b.canvas_cull_mask = 1 | (2 if theme_b == "ember" else 4)
	if is_instance_valid(_background_a):
		_background_a.free()
	if is_instance_valid(_background_b):
		_background_b.free()
	_background_a = ThemePresenter.build_background(catalog, theme_a)
	_background_b = ThemePresenter.build_background(catalog, theme_b)
	viewport_a.add_child(_background_a)
	viewport_b.add_child(_background_b)
	for label in [hud_a, hud_b, _objective_a, _objective_b]:
		label.add_theme_font_override("font", catalog.font())
	for label: Label in _room_title_labels:
		label.add_theme_font_override("font", catalog.font())
	if _hearts_a.is_empty():
		for index in 6:
			_hearts_a.append(_make_heart(8 + index * 18))
			_hearts_b.append(_make_heart(488 + index * 18))


func _make_heart(x: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.position = Vector2(x, 6)
	icon.size = Vector2(16, 16)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	return icon


func _physics_process(_delta: float) -> void:
	if room_title_ticks_left > 0:
		room_title_ticks_left -= 1
		for panel: Control in _room_title_panels:
			panel.visible = room_title_ticks_left > 0
			panel.modulate.a = minf(1.0, room_title_ticks_left / 20.0)
	if _catalog != null and is_instance_valid(_background_a) and is_instance_valid(camera_a.target):
		ThemePresenter.update_background(_background_a, camera_a.position, camera_a.room_bounds)
		ThemePresenter.update_background(_background_b, camera_b.position, camera_b.room_bounds)


func follow_players(players: Array[PlayerController], bounds: Rect2) -> void:
	camera_a.configure(players[0], bounds)
	camera_b.configure(players[1], bounds)


func update_hud(players: Array[PlayerController], objective_text: String = "", hints: Array[String] = [], boss_actor: CombatEnemy = null, team: TeamProgress = null, targets_by_slot: Array = []) -> void:
	if players.size() != 2:
		return
	for index in 2:
		var source: DeviceSource = InputRouter.source_of(index)
		var device_name: String = source.short_label() if source != null else "Unassigned"
		var label: Label = hud_a if index == 0 else hud_b
		var player := players[index]
		var name_text := "Tavi" if player.profile_id == "tavi_fixed" else "Neri"
		var readiness := "Special ready" if player.special_cooldown_ticks == 0 else "Special %.1fs" % (player.special_cooldown_ticks / 60.0)
		if player.downed:
			readiness = "Downed %.1fs | Revive %d%%" % [maxf(0, 720 - player.downed_ticks) / 60.0, player.revive_progress_ticks * 100 / 90]
		label.text = "P%d %s | %s | %s" % [index + 1, name_text, device_name, readiness]
		var bindings := InputRouter.bindings_of(index)
		if bindings != null:
			var dash := "Dash locked" if team == null or not team.has_flag("threadstep") else "Dash %s" % bindings.prompt_label(CommandSnapshot.Action.DASH)
			label.text += "\nRoll %s  Slash %s  Special %s  Interact %s  %s" % [bindings.prompt_label(CommandSnapshot.Action.ROLL), bindings.prompt_label(CommandSnapshot.Action.ATTACK), bindings.prompt_label(CommandSnapshot.Action.SPECIAL), bindings.prompt_label(CommandSnapshot.Action.INTERACT), dash]
		if is_instance_valid(boss_actor):
			label.text += "\nSpoolwarden %d/%d | Phase %d" % [boss_actor.health, boss_actor.max_health, boss_actor.phase]
			var feedback := boss_actor.feedback_text().replace("\n", " / ")
			if not feedback.is_empty():
				label.text += " | " + feedback
		var objective_label: Label = _objective_a if index == 0 else _objective_b
		var hint: String = hints[index] if index < hints.size() else ""
		if player.downed:
			hint = "Your partner must reach you and hold their Interact to revive"
		elif players[1 - index].downed and hint.is_empty():
			hint = "Reach your partner before the thread fades"
		if bindings != null:
			hint = hint.replace("Interact", bindings.prompt_label(CommandSnapshot.Action.INTERACT)) if not player.downed else hint
		objective_label.text = hint if not hint.is_empty() else objective_text
		if hint.is_empty() and not player.downed:
			var targets: Array[Dictionary] = []
			if index < targets_by_slot.size() and targets_by_slot[index] is Array:
				targets.assign(targets_by_slot[index])
			var direction := _target_hint(player, targets)
			if not direction.is_empty():
				objective_label.text += "\n" + direction
		var hearts: Array[TextureRect] = _hearts_a if index == 0 else _hearts_b
		for heart_index in hearts.size():
			hearts[heart_index].visible = heart_index < player.max_hearts
			hearts[heart_index].texture = _catalog.frame_texture("ui_v1", 0 if heart_index < player.hearts else 1)


func _target_hint(player: PlayerController, targets: Array[Dictionary]) -> String:
	var nearest: Dictionary = {}
	var distance := INF
	for target: Dictionary in targets:
		var point: Variant = target.get("feet_position")
		if not point is Vector2:
			continue
		var candidate: float = player.global_position.distance_squared_to(point)
		if candidate < distance:
			distance = candidate
			nearest = target
	if nearest.is_empty():
		return ""
	var delta: Vector2 = nearest.feet_position - player.global_position
	var direction := ""
	if absf(delta.y) > 16.0:
		direction += "N" if delta.y < 0 else "S"
	if absf(delta.x) > 16.0:
		direction += "W" if delta.x < 0 else "E"
	if direction.is_empty():
		direction = "nearby"
	var name_text: String = {"npc": "Oru", "exit": "Next exit", "anchor": "Anchor", "station": "Loom station", "spoolwarden": "Spoolwarden"}.get(str(nearest.get("kind", "")), "Goal")
	return "%s: %s (%d tiles)" % [name_text, direction, ceili(sqrt(distance) / 16.0)]
