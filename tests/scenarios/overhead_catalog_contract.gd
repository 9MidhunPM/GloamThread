extends Scenario
## The actual authored media/profile/theme boundary, separate from room gameplay.
func run() -> void:
	var media := AssetCatalog.load_from_path("res://assets/manifest.json")
	assert_true(media.errors.is_empty(), "overhead manifest loads without fallback: %s" % media.errors)
	var bundle := ContentCatalog.new()
	bundle.assets = media
	bundle._validate_required_assets()
	bundle._load_profiles()
	bundle._load_themes()
	bundle._load_dialogue()
	bundle._load_resources()
	assert_true(bundle.errors.is_empty(), "overhead fixed media/profile/theme contract validates: %s" % bundle.errors)
	assert_eq(ContentCatalog.courier_clip_keys().size(), 36, "nine states in four directions")
	assert_eq(media.entries["fixed_tavi_v1"].frames.size(), 128, "actual Tavi atlas has four complete banks")
	assert_eq(media.entries["fixed_neri_v1"].frames.size(), 128, "actual Neri atlas has four complete banks")
	var original: Dictionary = media.entries["fixed_tavi_v1"].duplicate(true)
	for field: String in ["pivot", "count", "missing_direction", "wrong_bank", "timing", "loop"]:
		media.entries["fixed_tavi_v1"] = original.duplicate(true)
		var entry: Dictionary = media.entries["fixed_tavi_v1"]
		match field:
			"pivot": entry.origin = [16,42]
			"count": entry.frames.pop_back()
			"missing_direction": entry.animations.erase("roll_up")
			"wrong_bank": entry.animations.slash_up.frames[0] = 0
			"timing": entry.animations.special_down.ticks[0] = 40
			"loop": entry.animations.revive_left.loop = true
		var invalid := ContentCatalog.new()
		invalid.assets = media
		invalid._validate_required_assets()
		assert_true(not invalid.errors.is_empty(), "runtime admission rejects %s without silently substituting art" % field)
	media.entries["fixed_tavi_v1"] = original
