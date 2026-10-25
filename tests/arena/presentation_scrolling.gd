extends Scenario
## Controlled camera fixture. No extra simulation, terrain or gameplay writes by views.

const Presentation = preload("res://scripts/arena/arena_presentation.gd")
const Parallax = preload("res://scripts/arena/arena_parallax.gd")

class Body extends Node2D:
	var downed := false

class World extends ArenaRunSession:
	func _ready() -> void:
		for index in 2:
			var body := Body.new()
			body.position = Vector2(270 + index * 100, 320)
			add_child(body)
			fighters.append(body)
	func _physics_process(_delta: float) -> void:
		pass
	func world_bounds() -> Rect2:
		return Rect2(0, 0, 10240, 720)
	func appearance_at(_at: Vector2) -> Dictionary:
		return {}


func run() -> void:
	_check_media_admission()
	var world := World.new()
	var presentation := Presentation.new()
	presentation.setup(world)
	add_child(presentation)
	await ticks(2)
	assert_true(presentation.viewport_a.world_2d == presentation.viewport_b.world_2d, "both render views share one World2D")
	assert_true(world.get_parent() == presentation.viewport_a, "only first viewport owns the session")
	assert_eq(world.fighters.size(), 2, "presentation does not duplicate fighter nodes")
	assert_eq(presentation.viewport_a.size, Vector2i(640, 360), "nearby players use full shared logical view")
	assert_eq(presentation.container_a.scale, Vector2(3, 3), "shared pixels remain exactly3x")
	assert_true(not presentation.viewport_a.audio_listener_enable_2d and not presentation.viewport_b.audio_listener_enable_2d, "render views cannot double shared audio")
	world.fighters[1].position.x = 950
	await ticks(7)
	assert_true(not presentation.split, "separation requires the complete eight-tick hold")
	await ticks(2)
	assert_true(presentation.split, "far partners get independent cameras")
	assert_eq(presentation.viewport_a.size, Vector2i(320, 360), "first half keeps native pixel scale")
	assert_eq(presentation.viewport_b.size, Vector2i(320, 360), "second half has matching native dimensions")
	assert_eq(presentation.container_b.position, Vector2(960, 0), "P2 remains the right half")
	var rectangles: Array[Rect2] = presentation.visible_world_rects()
	assert_eq(rectangles.size(), 2, "spawns receive both active unshaken world rectangles")
	assert_true(rectangles[0].has_point(world.fighters[0].position) and rectangles[1].has_point(world.fighters[1].position), "each split view follows its own player")
	world.fighters[1].downed = true
	world.fighters[0].position.x = 1800
	await ticks(50)
	assert_true(presentation.split, "a distant downed player keeps their own camera")
	world.fighters[1].position = world.fighters[0].position + Vector2(100, 0)
	await ticks(43)
	assert_true(presentation.split, "merge hysteresis prevents boundary flicker")
	await ticks(3)
	assert_true(not presentation.split, "nearby partners merge after forty-five ticks")
	presentation.force_split = true
	await ticks(1)
	assert_true(presentation.split, "an owned shop can force the two panel presentation")
	presentation.force_split = false
	world.fighters[0].position = Vector2(3000.3, 320.2)
	world.fighters[1].position = Vector2(3100.6, 320.4)
	await ticks(50)
	var origins: Array[Rect2] = presentation.visible_world_rects()
	assert_eq(origins[0].position, origins[0].position.round(), "unshaken camera origins are whole world pixels")
	presentation._snap = true
	presentation._update_cameras(0.0)
	world.shake_ticks = 20
	var before := presentation.visible_world_rects()[0].position
	await ticks(1)
	assert_eq(presentation.visible_world_rects()[0].position, before, "camera shake does not alter spawn rectangles")
	var frozen := presentation.visible_world_rects()[0]
	get_tree().paused = true
	world.fighters[0].position.x += 500
	for frame in 4:
		await get_tree().process_frame
	assert_eq(presentation.visible_world_rects()[0], frozen, "real pause freezes camera timers and follow")
	get_tree().paused = false
	world.fighters[0].position = Vector2(5, 320)
	world.fighters[1].position = Vector2(105, 320)
	await ticks(100)
	assert_true(presentation.visible_world_rects()[0].position.x >= 0, "camera clamps at the generated left boundary")
	world.fighters[0].position = Vector2(10135, 690)
	world.fighters[1].position = Vector2(10235, 690)
	await ticks(100)
	var edge: Rect2 = presentation.visible_world_rects()[0]
	assert_true(edge.end.x <= 10240 and edge.end.y <= 720, "camera clamps to distant generated right and bottom boundaries")
	var actor_id: int = world.fighters[0].get_instance_id()
	for cycle in 3:
		presentation.force_split = true
		await ticks(1)
		presentation.force_split = false
		await ticks(45)
	assert_eq(world.fighters[0].get_instance_id(), actor_id, "layout switches retain the same gameplay actor")
	assert_eq(world.get_children().size(), 2, "secondary viewport never adds gameplay nodes to the fixture world")
	presentation.free()
	assert_true(not is_instance_valid(world), "freeing presentation retires the single session and both views")
	var solo := World.new()
	var solo_view := Presentation.new()
	add_child(solo_view)
	solo_view.setup(solo)
	solo.fighters.pop_back().free()
	solo_view.force_split = true
	await ticks(2)
	assert_true(not solo_view.split and solo_view.viewport_a.size == Vector2i(640, 360), "solo remains fullscreen even when its shop requests force_split")
	assert_eq(solo_view.visible_world_rects().size(), 1, "solo supplies only one spawn/catch-up view rectangle")
	solo_view.free()


func _check_media_admission() -> void:
	assert_true(Parallax.media_errors().is_empty(), "all four shipped scenery layers pass runtime admission: " + str(Parallax.media_errors()))
	assert_eq(Parallax._media.size(), 4, "runtime loads the entire layer set atomically")
	var cache_ids: Array[int] = []
	for layer: Dictionary in Parallax._media:
		cache_ids.append(layer.texture.get_instance_id())
	var folder := "/tmp/gloamthread-scenery-check-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("index.json")
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Parallax.INDEX))
	var originals: Dictionary = {}
	for name: String in Parallax.FILES:
		originals[name] = FileAccess.get_file_as_bytes(Parallax.FOLDER.path_join(name))
		_write_scenery_bytes(folder.path_join(name), originals[name])
	_write_scenery_index(path, original)
	assert_true(Parallax.media_errors(path).is_empty(), "an isolated complete layer set passes without replacing runtime textures")
	assert_true(_has_media_error(Parallax.media_errors(folder.path_join("missing.json")), "index is missing"), "missing scenery index has a visible actionable error")
	DirAccess.remove_absolute(folder.path_join("far.png"))
	DirAccess.remove_absolute(folder.path_join("canopy.png"))
	var missing := Parallax.media_errors(path)
	assert_true(_has_media_error(missing, "far.png is missing") and _has_media_error(missing, "canopy.png is missing"), "admission reports every missing required image rather than accepting a partial set")
	_write_scenery_bytes(folder.path_join("far.png"), originals["far.png"])
	_write_scenery_bytes(folder.path_join("canopy.png"), originals["canopy.png"])
	var corrupted: PackedByteArray = originals["far.png"].duplicate()
	corrupted.append(1)
	_write_scenery_bytes(folder.path_join("far.png"), corrupted)
	assert_true(_has_media_error(Parallax.media_errors(path), "integrity hash"), "changed layer bytes fail integrity admission")
	_write_scenery_bytes(folder.path_join("far.png"), originals["far.png"])
	for mutation: Array in [["factor", -0.01], ["factor", 1.01], ["factor", "fast"], ["y_factor", true]]:
		var changed := original.duplicate(true)
		changed.layers[0][mutation[0]] = mutation[1]
		_write_scenery_index(path, changed)
		assert_true(_has_media_error(Parallax.media_errors(path), "parallax factor"), "reject malformed layer factor " + str(mutation))
	var wrong_size := original.duplicate(true)
	wrong_size.layers[1]["size"] = [320, 360]
	_write_scenery_index(path, wrong_size)
	assert_true(_has_media_error(Parallax.media_errors(path), "declare a 640 x 360"), "declared layer dimensions are strict")
	var tiny := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	tiny.fill(Color.WHITE)
	tiny.save_png(folder.path_join("sky.png"))
	var wrong_pixels := original.duplicate(true)
	wrong_pixels.layers[0].sha256 = FileAccess.get_sha256(folder.path_join("sky.png"))
	_write_scenery_index(path, wrong_pixels)
	assert_true(_has_media_error(Parallax.media_errors(path), "must be a 640 x 360 PNG"), "real PNG dimensions are rejected even when their replacement hash matches")
	_write_scenery_bytes(folder.path_join("sky.png"), originals["sky.png"])
	var missing_record := original.duplicate(true)
	missing_record.layers.pop_back()
	_write_scenery_index(path, missing_record)
	assert_true(_has_media_error(Parallax.media_errors(path), "foreground.png is missing from the index"), "an incomplete index cannot silently omit a required layer")
	var unsafe := original.duplicate(true)
	unsafe.layers[0].file = "../outside.png"
	_write_scenery_index(path, unsafe)
	assert_true(_has_media_error(Parallax.media_errors(path), "invalid identity, filename or hash"), "layer admission refuses non-fixed source paths")
	var version := original.duplicate(true)
	version.schema_version = true
	_write_scenery_index(path, version)
	assert_true(_has_media_error(Parallax.media_errors(path), "unsupported version"), "boolean schema versions cannot impersonate numeric version one")
	var after_ids: Array[int] = []
	for layer: Dictionary in Parallax._media:
		after_ids.append(layer.texture.get_instance_id())
	assert_eq(after_ids, cache_ids, "isolated corrupt/missing checks preserve every production texture instance")
	assert_true(Parallax.media_errors().is_empty(), "isolated failures do not poison production admission state")
	_write_scenery_index(path, original)
	assert_true(Parallax.media_errors(path).is_empty(), "restored isolated media validates without global cache resets")


func _has_media_error(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false


func _write_scenery_index(path: String, value: Dictionary) -> void:
	_write_scenery_bytes(path, JSON.stringify(value).to_utf8_buffer())


func _write_scenery_bytes(path: String, value: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_true(file != null, "isolated scenery fixture file can be written")
	if file != null:
		file.store_buffer(value)
		file.close()
