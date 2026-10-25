class_name ArenaPresentation
extends Control
## One simulation, with a merged view or two cameras into that same World2D.

const Parallax = preload("res://scripts/arena/arena_parallax.gd")
const FULL_SIZE := Vector2i(640, 360)
const HALF_SIZE := Vector2i(320, 360)
const PLAYER_COLORS := [Color("ffd184"), Color("85d9e7")]

var viewport_a: SubViewport
var viewport_b: SubViewport
var container_a: SubViewportContainer
var container_b: SubViewportContainer
var camera_a: Camera2D
var camera_b: Camera2D
var split: bool = false
var force_split: bool = false

var _world: ArenaRunSession
var _parallax_a: Node2D
var _parallax_b: Node2D
var _centres: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _origins: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _split_ticks: int = 0
var _merge_ticks: int = 0
var _ticks: int = 0
var _snap: bool = true


func setup(world: ArenaRunSession) -> void:
	if _world != null:
		return
	_world = world
	if is_inside_tree():
		_build_views()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 150
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _world != null:
		_build_views()


func _build_views() -> void:
	if viewport_a != null:
		return
	var shared := World2D.new()
	container_a = _container("ViewA", Vector2.ZERO)
	viewport_a = _viewport(container_a, shared)
	viewport_a.add_child(_world)
	container_b = _container("ViewB", Vector2(960, 0))
	viewport_b = _viewport(container_b, shared)
	# B already shares the exact world before either camera/CanvasItem is added.
	camera_a = _camera(viewport_a, "CameraA")
	camera_b = _camera(viewport_b, "CameraB")
	_parallax_a = _background(viewport_a)
	_parallax_b = _background(viewport_b)
	_apply_layout(false)
	_update_cameras(0.0)
	queue_redraw()


func _container(label: String, at: Vector2) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.name = label
	container.position = at
	container.scale = Vector2(3, 3)
	container.z_index = -1
	container.size = Vector2(FULL_SIZE)
	container.stretch = false
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(container)
	return container


func _viewport(container: SubViewportContainer, shared: World2D) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = FULL_SIZE
	viewport.world_2d = shared
	viewport.handle_input_locally = false
	viewport.audio_listener_enable_2d = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	return viewport


func _camera(viewport: SubViewport, label: String) -> Camera2D:
	var camera := Camera2D.new()
	camera.name = label
	camera.position_smoothing_enabled = false
	camera.rotation_smoothing_enabled = false
	camera.ignore_rotation = true
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	viewport.add_child(camera)
	camera.make_current()
	return camera


func _background(viewport: SubViewport) -> Node2D:
	var layer := CanvasLayer.new()
	layer.name = "ViewScenery"
	layer.layer = -100
	viewport.add_child(layer)
	var background: Node2D = Parallax.new()
	layer.add_child(background)
	return background


func _physics_process(delta: float) -> void:
	if viewport_a == null or not is_instance_valid(_world):
		return
	_ticks += 1
	var desired := split
	if _world.fighters.size() < 2:
		desired = false
		_split_ticks = 0
		_merge_ticks = 0
	elif force_split:
		desired = true
		_split_ticks = 0
		_merge_ticks = 0
	else:
		var gap: Vector2 = (_world.fighters[0] as Node2D).global_position - (_world.fighters[1] as Node2D).global_position
		_split_ticks = _split_ticks + 1 if absf(gap.x) > 480 or absf(gap.y) > 192 else 0
		_merge_ticks = _merge_ticks + 1 if absf(gap.x) < 360 and absf(gap.y) < 128 else 0
		if not split and _split_ticks >= 8:
			desired = true
		elif split and _merge_ticks >= 45:
			desired = false
	if desired != split:
		_apply_layout(desired)
	_update_cameras(delta)
	if _ticks % 6 == 0:
		queue_redraw()


func _apply_layout(separate: bool) -> void:
	split = separate
	viewport_a.size = HALF_SIZE if split else FULL_SIZE
	container_a.size = Vector2(viewport_a.size)
	viewport_b.size = HALF_SIZE
	container_b.size = Vector2(HALF_SIZE)
	container_b.visible = split
	viewport_b.render_target_update_mode = SubViewport.UPDATE_ALWAYS if split else SubViewport.UPDATE_DISABLED
	_parallax_b.set_physics_process(split)
	_snap = true
	_split_ticks = 0
	_merge_ticks = 0
	queue_redraw()


func _bounds() -> Rect2:
	if _world.has_method("world_bounds"):
		var result: Variant = _world.call("world_bounds")
		if result is Rect2 and result.size.x > 0 and result.size.y > 0:
			return result
	return Rect2(0, 0, 640, 360)


func _appearance(at: Vector2) -> Dictionary:
	if _world.has_method("appearance_at"):
		var result: Variant = _world.call("appearance_at", at)
		if result is Dictionary:
			return result
	return _world.appearances[0] if not _world.appearances.is_empty() else {}


func _update_cameras(delta: float) -> void:
	var targets: Array[Node2D] = []
	for fighter: Node2D in _world.fighters:
		if is_instance_valid(fighter):
			targets.append(fighter)
	if targets.is_empty():
		return
	var bounds := _bounds()
	for index in 2 if split else 1:
		var dimensions := HALF_SIZE if split else FULL_SIZE
		var half := Vector2(dimensions) * 0.5
		var target := targets[mini(index, targets.size() - 1)].global_position - Vector2(0, 100)
		if not split and targets.size() == 2:
			var a := targets[0].global_position
			var b := targets[1].global_position
			target = (a + b) * 0.5 - Vector2(0, 100)
			# Keep both complete hurtboxes inside the unobscured view while the
			# shared camera changes its vertical composition across raised paths.
			var lower := maxf(a.y, b.y) + half.y - 330.0
			var upper := minf(a.y, b.y) - 38.0 + half.y - 64.0
			if lower <= upper:
				target.y = clampf(target.y, lower, upper)
		target = _clamp_centre(target, bounds, half)
		_centres[index] = target if _snap else _centres[index].lerp(target, 1.0 - exp(-10.0 * delta))
		var centre := _clamp_centre(_centres[index], bounds, half).round()
		_origins[index] = centre - half
		var camera := camera_a if index == 0 else camera_b
		camera.position = centre
		# Native limits are widened for small fixture maps; our centre clamp
		# owns letterboxing, including a world smaller than a single viewport.
		camera.limit_left = floori(minf(bounds.position.x, bounds.get_center().x - half.x))
		camera.limit_top = floori(minf(bounds.position.y, bounds.get_center().y - half.y))
		camera.limit_right = ceili(maxf(bounds.end.x, bounds.get_center().x + half.x))
		camera.limit_bottom = ceili(maxf(bounds.end.y, bounds.get_center().y + half.y))
		camera.offset = Vector2((1 if _ticks % 2 == 0 else -1), 0) if _world.shake_ticks > 0 and not _world.reduced_shake else Vector2.ZERO
		if _snap:
			camera.reset_physics_interpolation()
		camera.force_update_scroll()
		var backdrop := _parallax_a if index == 0 else _parallax_b
		backdrop.call("update_view", _origins[index], dimensions, _appearance(centre))
	_snap = false


func _clamp_centre(at: Vector2, bounds: Rect2, half: Vector2) -> Vector2:
	return Vector2(clampf(at.x, bounds.position.x + half.x, bounds.end.x - half.x) if bounds.size.x >= half.x * 2 else bounds.get_center().x, clampf(at.y, bounds.position.y + half.y, bounds.end.y - half.y) if bounds.size.y >= half.y * 2 else bounds.get_center().y)


func visible_world_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	if viewport_a == null:
		return result
	result.append(Rect2(_origins[0], Vector2(viewport_a.size)))
	if split:
		result.append(Rect2(_origins[1], Vector2(HALF_SIZE)))
	return result


func _draw() -> void:
	if viewport_a == null or not is_instance_valid(_world):
		return
	if split:
		draw_rect(Rect2(957, 0, 6, 1080), Color("101a24"))
		draw_rect(Rect2(959, 0, 2, 1080), Color("5d7c84"))
	_draw_minimap()
	_draw_cues()


func _draw_minimap() -> void:
	if _world.shop_open.has(true):
		return
	var map_data: Variant = _world.get("map")
	if map_data == null:
		return
	var panel := Rect2(730, 939, 460, 87)
	var region := Rect2(panel.position + Vector2(12, 17), panel.size - Vector2(24, 29))
	draw_rect(panel, Color(0.04, 0.08, 0.12, 0.88))
	draw_rect(panel, Color("4c6c75"), false, 2)
	var bounds := _bounds()
	var discovered: Variant = _world.get("discovered")
	var collected: Variant = _world.get("collected")
	var chunks: Variant = map_data.get("chunks")
	if chunks is Array:
		for chunk: Dictionary in chunks:
			var known: bool = discovered is Dictionary and discovered.get(chunk.get("id"), false)
			var at := _map_point(chunk.get("origin", Vector2.ZERO), bounds, region)
			var width := 640.0 / bounds.size.x * region.size.x
			draw_rect(Rect2(at.x, region.position.y, width - 1, region.size.y), Color("34545b") if known else Color("172b35"))
	var loot: Variant = map_data.get("loot")
	if loot is Array:
		for record: Dictionary in loot:
			if collected is Dictionary and collected.get(record.get("id"), false):
				continue
			var at: Vector2 = record.get("position", Vector2.ZERO)
			var chunk_id := int(floorf((at.x - bounds.position.x) / 640.0))
			if not discovered is Dictionary or not discovered.get(chunk_id, false):
				continue
			draw_circle(_map_point(at, bounds, region), 2, Color("b9e79d") if record.get("kind") == "plant" else Color("f2c477"))
	var landmarks: Variant = map_data.get("landmarks")
	if landmarks is Array:
		for landmark: Dictionary in landmarks:
			var at: Vector2 = landmark.get("position", Vector2.ZERO)
			var chunk_id := int(floorf((at.x - bounds.position.x) / 640.0))
			if discovered is Dictionary and discovered.get(chunk_id, false):
				var point := _map_point(at, bounds, region)
				draw_colored_polygon(PackedVector2Array([point + Vector2(0, -5), point + Vector2(4, 0), point + Vector2(0, 5), point + Vector2(-4, 0)]), Color("a8b4df"))
	for index in _world.fighters.size():
		var fighter: Node2D = _world.fighters[index]
		var dot := _map_point(fighter.global_position, bounds, region)
		draw_circle(dot, 4, PLAYER_COLORS[mini(index, 1)])
		if bool(fighter.get("downed")):
			draw_line(dot - Vector2(5, 0), dot + Vector2(5, 0), Color("f18983"), 2)
			draw_line(dot - Vector2(0, 5), dot + Vector2(0, 5), Color("f18983"), 2)
	var rects := visible_world_rects()
	for index in rects.size():
		var rect := rects[index]
		var at := _map_point(rect.position, bounds, region)
		var end := _map_point(rect.end, bounds, region)
		draw_rect(Rect2(at, end - at), Color(PLAYER_COLORS[index], 0.65), false, 1)


func _map_point(at: Vector2, bounds: Rect2, drawing: Rect2) -> Vector2:
	return (drawing.position + (at - bounds.position) / bounds.size * drawing.size).clamp(drawing.position, drawing.end).round()


func _draw_cues() -> void:
	var rects := visible_world_rects()
	var living: Array[Node2D] = []
	var boss: Node2D
	for enemy: Node2D in _world.enemies:
		if not is_instance_valid(enemy) or bool(enemy.get("dead")):
			continue
		living.append(enemy)
		if str(enemy.get("boss_id")) != "":
			boss = enemy
	for view in rects.size():
		if _world.fighters.size() == 2:
			for slot in 2:
				if split and slot == view:
					continue
				var other: Node2D = _world.fighters[slot]
				_edge_cue(other.global_position - Vector2(0, 19), "REVIVE P%d" % (slot + 1) if bool(other.get("downed")) else "P%d" % (slot + 1), PLAYER_COLORS[slot], view, rects[view])
		if boss != null:
			_edge_cue(boss.global_position - Vector2(0, 28), str(boss.get("boss_id")).to_upper(), Color("efa5b2"), view, rects[view])
		elif living.size() == 1:
			_edge_cue(living[0].global_position - Vector2(0, 18), "LAST FOE", Color("efa66e"), view, rects[view])


func _edge_cue(at: Vector2, label: String, color: Color, view: int, rect: Rect2) -> void:
	if rect.has_point(at):
		return
	var screen_origin := Vector2(960 * view if split else 0, 0)
	var width := 960.0 if split else 1920.0
	var safe := Rect2(screen_origin + Vector2(36, 250), Vector2(width - 72, 645))
	var centre := safe.get_center()
	var direction := (screen_origin + (at - rect.position) * 3 - centre).normalized()
	if direction.is_zero_approx():
		return
	var ray_length := minf(safe.size.x * 0.5 / maxf(absf(direction.x), 0.001), safe.size.y * 0.5 / maxf(absf(direction.y), 0.001))
	var point := (centre + direction * ray_length).round()
	var side := direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([point + direction * 12, point - direction * 8 + side * 9, point - direction * 8 - side * 9]), color)
	var font: Font = _world.font if _world.font != null else ThemeDB.fallback_font
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	var text_at := point - direction * 27 - text_size * Vector2(0.5, 0) + Vector2(0, 6)
	text_at.x = clampf(text_at.x, safe.position.x, safe.end.x - text_size.x)
	draw_string(font, text_at.round(), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
