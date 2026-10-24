extends Scenario
## Invalid JSON data is rejected as catalog errors, never a script exception.

var _path: String


func run() -> void:
	_path = "user://catalog-invalid-%d.json" % Time.get_ticks_usec()
	var content := ContentCatalog.new()
	for version: Variant in [true, false, "1", null, [], {}, 1.5, 2]:
		_write_json({"schema_version": version, "content_version": "overhead-v1"})
		content.errors.clear()
		assert_true(content._json(_path).is_empty(), "reject invalid content schema: %s" % str(version))
		assert_true(not content.errors.is_empty(), "content schema failure is explicit")
	for version: Variant in [true, 1, [], {}, null, "other"]:
		_write_json({"schema_version": 1, "content_version": version})
		content.errors.clear()
		assert_true(content._json(_path).is_empty() and not content.errors.is_empty(), "content version type is guarded")
	for text: String in ["{", "[]", "true", "null"]:
		_write(text)
		content.errors.clear()
		assert_true(content._json(_path).is_empty() and not content.errors.is_empty(), "malformed content reports a recoverable error")
		assert_true(not AssetCatalog.load_from_path(_path).errors.is_empty(), "malformed manifest reports a recoverable error")
	for version: Variant in [true, false, "1", null, [], {}, 1.5, 2]:
		var manifest := _manifest([])
		manifest.schema_version = version
		_write_json(manifest)
		assert_true(not AssetCatalog.load_from_path(_path).errors.is_empty(), "manifest schema type is guarded")
	var atlas := {"id": "fixture", "kind": "sprite_atlas", "path": "assets/generated/fixture.png", "diagnostic": false,
		"size": [16, 16], "cell_size": [16, 16], "origin": [0, 0], "frames": [[0, 0, 16, 16]],
		"animations": {"idle": {"frames": [0], "ticks": [6], "loop": true}}}
	for malformed: Variant in [[], true, "idle", {"idle": []}, {"idle": {"frames": [true], "ticks": [6], "loop": true}}]:
		var record := atlas.duplicate(true)
		record.animations = malformed
		_write_json(_manifest([record]))
		var assets := AssetCatalog.load_from_path(_path)
		assert_true(not assets.errors.is_empty() and not assets.entries.has("fixture"), "malformed animation record is rejected before resource consumers")
		assert_true(assets.animation("fixture", "idle").is_empty(), "rejected atlas has no executable animation data")
	# Defensive query access remains safe even when a caller supplies an invalid
	# dictionary directly rather than going through the file loader.
	var direct := AssetCatalog.new()
	direct.entries.fixture = {"animations": []}
	assert_true(direct.animation("fixture", "idle").is_empty() and not direct.errors.is_empty(), "direct array animations return a validation error")
	direct.entries.fixture = {"animations": {"idle": []}}
	direct.errors.clear()
	assert_true(direct.animation("fixture", "idle").is_empty() and not direct.errors.is_empty(), "direct array clip returns a validation error")
	var audio := {"id": "fixture_audio", "kind": "sfx", "path": "assets/generated/fixture.wav", "diagnostic": false,
		"sample_rate": 44100, "channels": 1, "sample_width_bytes": 2, "sample_frames": 4410, "loop_start": null, "loop_end": null}
	for field: String in ["sample_rate", "channels", "sample_width_bytes", "sample_frames", "loop_start"]:
		var record := audio.duplicate(true)
		record[field] = true
		_write_json(_manifest([record]))
		var assets := AssetCatalog.load_from_path(_path)
		assert_true(not assets.errors.is_empty() and not assets.entries.has("fixture_audio"), "boolean audio %s is rejected safely" % field)
	var valid_manifest := _manifest([atlas, audio])
	_write_json(valid_manifest)
	assert_true(AssetCatalog.load_from_path(_path).errors.is_empty(), "valid metadata remains accepted without loading fixture resources")
	_write_json({"schema_version": 1, "content_version": "overhead-v1"})
	content.errors.clear()
	assert_true(not content._json(_path).is_empty() and content.errors.is_empty(), "valid content version remains accepted")
	# Metadata validation alone cannot establish that an imported image exists
	# or matches its declaration. The campaign's final load gate resolves both.
	var real_font: Dictionary = AssetCatalog.load_from_path("res://assets/manifest.json").entries.font_v1
	for record: Dictionary in [
		{"id": "missing_image", "kind": "image", "path": "assets/generated/no-such-campaign-image.png", "diagnostic": false, "size": [16, 16]},
		{"id": "wrong_dimensions", "kind": "image", "path": "assets/generated/sprites/fixed_tavi_v1.png", "diagnostic": false, "size": [1, 1]},
	]:
		_write_json(_manifest([real_font, record]))
		var campaign := ContentCatalog.new()
		campaign.assets = AssetCatalog.load_from_path(_path)
		assert_true(campaign.assets.errors.is_empty(), "missing/dimension fixture passes metadata validation")
		campaign._load_resources()
		assert_true(not campaign.errors.is_empty(), "resource load gate blocks missing or wrong-sized image before startup")
	DirAccess.remove_absolute(_path)


func _manifest(records: Array) -> Dictionary:
	return {"schema_version": 1, "content_version": "overhead-v1", "stage": "full", "assets": records, "sfx": {}, "music": {}}


func _write_json(value: Variant) -> void:
	_write(JSON.stringify(value))


func _write(text: String) -> void:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	assert_true(file != null, "create isolated malformed JSON fixture")
	if file != null:
		file.store_string(text)
		file.close()
