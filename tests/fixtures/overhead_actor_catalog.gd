extends AssetCatalog
## In-memory labelled colour atlas for animation-state tests, never shipped art.

func _init() -> void:
	var states := {
		"idle": {"frames": [5], "ticks": [10], "loop": true},
		"run": {"frames": [5], "ticks": [5], "loop": true},
		"slash": {"frames": [0, 1, 2, 3, 4], "ticks": [3, 3, 3, 3, 6], "loop": false},
		"special": {"frames": [0, 1, 2, 3, 4], "ticks": [4, 4, 3, 4, 7], "loop": false},
		"roll": {"frames": [0, 1, 2, 3], "ticks": [3, 3, 3, 3], "loop": false},
		"dash": {"frames": [0, 1], "ticks": [6, 6], "loop": false},
		"hurt": {"frames": [0, 1], "ticks": [5, 7], "loop": false},
		"downed": {"frames": [0, 1], "ticks": [18, 18], "loop": true},
		"revive": {"frames": [0, 1], "ticks": [6, 10], "loop": false},
	}
	var clips := {}
	for direction: String in ["down", "left", "right", "up"]:
		for state: String in states:
			clips[state + "_" + direction] = states[state].duplicate(true)
	add_atlas("test_courier", Vector2i(32, 48), Vector2i(16, 43), 6, clips)


func add_atlas(asset_id: String, cell: Vector2i, origin: Vector2i, count: int, clips: Dictionary) -> void:
	var atlas := Image.create(cell.x * count, cell.y, false, Image.FORMAT_RGBA8)
	var frames: Array = []
	for index in count:
		atlas.fill_rect(Rect2i(index * cell.x, 0, cell.x, cell.y), Color.from_hsv(float(index) / count, 0.8, 0.9))
		frames.append([index * cell.x, 0, cell.x, cell.y])
	entries[asset_id] = {"kind": "sprite_atlas", "origin": [origin.x, origin.y], "frames": frames, "animations": clips}
	_textures[asset_id] = ImageTexture.create_from_image(atlas)


func font() -> Font:
	return ThemeDB.fallback_font
