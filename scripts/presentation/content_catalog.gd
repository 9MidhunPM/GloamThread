class_name ContentCatalog
extends RefCounted
## Loads the complete fixed campaign once before creating any game actors.

const TERRAIN_IDS := ["floor_path_1", "floor_path_2", "floor_grass_1", "floor_grass_2", "wall_fill_1", "wall_fill_2", "wall_fill_3", "wall_fill_4", "wall_edge_north", "wall_edge_east", "wall_edge_south", "wall_edge_west", "wall_corner_outer_ne", "wall_corner_outer_se", "wall_corner_outer_sw", "wall_corner_outer_nw", "wall_corner_inner_ne", "wall_corner_inner_se", "wall_corner_inner_sw", "wall_corner_inner_nw", "water_fill_1", "water_fill_2", "water_fill_3", "water_fill_4", "water_edge_north", "water_edge_east", "water_edge_south", "water_edge_west", "water_corner_ne", "water_corner_se", "water_corner_sw", "water_corner_nw", "bridge_plank_1", "bridge_plank_2", "bridge_rail_north", "bridge_rail_south", "seam_rune_1", "seam_rune_2", "seam_rune_3", "seam_rune_4", "background_earth_1", "background_earth_2", "background_roots_1", "background_roots_2", "hazard_glass_1", "hazard_glass_2", "hazard_thread_1", "hazard_thread_2"]
const ROOM_IDS := ["r00", "r01", "r02", "r03", "r04", "r05", "r06", "r07"]
const LINKS := {
	"r00:r01": ["met_oru"], "r01:r02": [], "r02:r03": ["bridge_spindle"],
	"r03:r04": [], "r04:r05": [], "r01:r05": ["shortcut_bell"],
	"r01:r06": ["threadstep"], "r06:r07": ["bridge_causeway"],
	"r00:r07": ["loom_restored"],
}
const REWARDS := {"r02": ["bridge_spindle"], "r05": ["boss_spoolwarden", "threadstep", "shortcut_bell"], "r06": ["bridge_causeway"], "r07": ["loom_restored"]}
const COURIER_CLIPS := ["idle", "run", "slash", "special", "roll", "dash", "hurt", "downed", "revive"]
const COURIER_DIRECTIONS := ["down", "left", "right", "up"]
const COURIER_COUNTS := [4, 6, 5, 5, 4, 2, 2, 2, 2]
const COURIER_TICKS := [[10,10,10,10], [5,5,5,5,5,5], [3,3,3,3,6], [4,4,3,4,7], [3,3,3,3], [6,6], [5,7], [18,18], [6,10]]
const ROOM_NAMES := ["Lantern Rest", "Mossfoot Atrium", "Spindle Steps", "Glasswing Gallery", "Warden's Landing", "Broken Bell", "Severed Causeway", "Lantern Loom"]
const SFX_CUES := ["roll", "slash", "hit", "hurt", "dash", "ember_arc", "spore_bolt", "enemy_warning", "enemy_defeat", "boss_stagger", "cross_stitch", "anchor_latched", "bridge_restored", "checkpoint", "downed", "revive", "loom_restored"]
const PROP_IDS := ["anchor", "anchor_latched", "loom", "loom_lit", "bell", "bell_broken", "lantern", "lantern_lit", "sign", "checkpoint", "checkpoint_lit", "spindle", "cloth", "root", "glass", "home_bridge", "bobbin", "bench", "banner", "arch", "boat"]

var profiles: Dictionary = {}
var themes: Dictionary = {}
var world: Dictionary = {}
var dialogue: Dictionary = {}
var rooms: Dictionary = {}
var assets: AssetCatalog
var errors: PackedStringArray = PackedStringArray()


static func load_bundle() -> ContentCatalog:
	var catalog: ContentCatalog = load("res://scripts/presentation/content_catalog.gd").new()
	catalog.assets = AssetCatalog.load_from_path("res://assets/manifest.json")
	catalog.errors.append_array(catalog.assets.errors)
	if catalog.assets.stage != "full":
		catalog.errors.append("Campaign requires the full content bundle")
	catalog._validate_required_assets()
	catalog._load_profiles()
	catalog._load_themes()
	catalog._load_dialogue()
	catalog.world = catalog._json("res://content/world.json")
	for id: String in ROOM_IDS:
		var data := catalog._json("res://content/rooms/%s.json" % id, false)
		if not data.has("decor"):
			catalog.errors.append("Production room requires decor: %s" % id)
		var definition := RoomDefinition.new()
		definition.parse(data)
		if definition.id != id:
			catalog.errors.append("Room filename/id mismatch: %s" % id)
		for problem: String in definition.errors:
			catalog.errors.append("%s: %s" % [id, problem])
		catalog.rooms[id] = definition
	catalog._validate_world()
	catalog._validate_references()
	if catalog.errors.is_empty():
		catalog._load_resources()
	return catalog


func room(id: String) -> RoomDefinition:
	return rooms.get(id)


func _load_resources() -> void:
	# Resolve imported/exported resources before any authoritative world exists.
	# The AssetCatalog caches these objects for the room and actor consumers.
	for id: String in assets.entries:
		# BMFont import embeds its page and deliberately marks the PNG as skip.
		# Loading the imported Font below validates that page dependency.
		if id == "font_texture_v1":
			continue
		match assets.entries[id].kind:
			"image", "sprite_atlas", "tile_atlas": assets.texture(id)
			"sfx", "music": assets.audio(id)
	assets.font()
	errors.append_array(assets.errors)


func dialogue_sequence(id: String) -> Array:
	var sequences: Variant = dialogue.get("sequences", {})
	if not sequences is Dictionary:
		return []
	var lines: Variant = sequences.get(id, [])
	return lines.duplicate(true) if lines is Array else []


func _validate_required_assets() -> void:
	var clips := {
		"fixed_tavi_v1": courier_clip_keys(), "fixed_neri_v1": courier_clip_keys(),
		"oru_v1": ["idle", "talk", "acknowledge"],
		"spoolmite_v1": ["idle", "walk", "anticipation", "charge", "recovery", "defeat"],
		"wickwing_v1": ["flap", "anticipation", "dive", "recovery", "defeat"],
		"spoolwarden_v1": ["idle", "sweep_anticipation", "sweep_active", "sweep_recovery", "strike_anticipation", "strike_active", "strike_recovery", "charge_anticipation", "charge_active", "charge_recovery", "stagger", "defeat"],
	}
	for effect: String in ["dash", "ember_arc", "hit", "restoration", "revive", "slash", "spore_impact", "weave"]:
		clips["effect_%s_v1" % effect] = ["play"]
	for id: String in clips:
		if assets.entries.get(id, {}).get("kind") != "sprite_atlas":
			errors.append("Required sprite atlas is missing: %s" % id)
		for clip: String in clips[id]:
			if assets.animation(id, clip).is_empty():
				errors.append("Required presentation clip is missing: %s/%s" % [id, clip])
	_validate_courier_atlas("fixed_tavi_v1")
	_validate_courier_atlas("fixed_neri_v1")
	var props: Dictionary = assets.entries.get("props_v1", {})
	if props.get("kind") != "sprite_atlas" or not props.get("prop_ids") is Array or props.prop_ids != PROP_IDS or props.get("frames", []).size() != PROP_IDS.size():
		errors.append("Required prop frame mapping is incomplete")
	if assets.entries.get("ui_v1", {}).get("kind") != "sprite_atlas" or assets.entries.get("font_v1", {}).get("kind") != "font" or assets.entries.get("font_texture_v1", {}).get("kind") != "image":
		errors.append("Required original UI/font assets are missing")
	for cue: String in SFX_CUES:
		if not assets.sfx.has(cue):
			errors.append("Required sound cue is missing: %s" % cue)
	for track: String in ["exploration", "boss", "ending"]:
		if not assets.music.has(track):
			errors.append("Required music track is missing: %s" % track)


static func courier_clip_keys() -> Array[String]:
	var result: Array[String] = []
	for direction: String in COURIER_DIRECTIONS:
		for state: String in COURIER_CLIPS:
			result.append(state + "_" + direction)
	return result


func _validate_courier_atlas(id: String) -> void:
	var entry: Dictionary = assets.entries.get(id, {})
	var frames: Variant = entry.get("frames")
	if not frames is Array or frames.size() != 128 or not AssetCatalog.dimensions_match(entry.get("cell_size"), 32, 48) or not AssetCatalog.dimensions_match(entry.get("origin"), 16, 43):
		errors.append("Overhead courier requires 128 fixed-size frames and stable feet pivot: %s" % id)
		return
	var seen := {}
	for bank in COURIER_DIRECTIONS.size():
		for index in COURIER_CLIPS.size():
			var key: String = COURIER_CLIPS[index] + "_" + COURIER_DIRECTIONS[bank]
			var clip := assets.animation(id, key)
			var indices: Variant = clip.get("frames")
			var durations: Variant = clip.get("ticks")
			if not indices is Array or indices.size() != COURIER_COUNTS[index] or not durations is Array or durations.size() != COURIER_COUNTS[index]:
				errors.append("Overhead courier clip frame count differs: %s/%s" % [id,key])
				continue
			for offset in indices.size():
				if not RoomDefinition._is_integer(indices[offset]) or int(indices[offset]) < bank*32 or int(indices[offset]) >= (bank+1)*32 or seen.has(int(indices[offset])):
					errors.append("Courier frame repeats or leaves its direction bank: %s/%s" % [id,key])
				else:
					seen[int(indices[offset])] = true
				if not RoomDefinition._is_integer(durations[offset]) or int(durations[offset]) != COURIER_TICKS[index][offset]:
					errors.append("Courier clip timing differs from gameplay contract: %s/%s" % [id,key])
			var loops: bool = COURIER_CLIPS[index] in ["idle", "run", "downed"]
			if not clip.get("loop") is bool or clip.loop != loops:
				errors.append("Courier clip loop contract differs: %s/%s" % [id,key])
	if seen.size() != 128:
		errors.append("Courier clips must cover every authored directional frame: %s" % id)


func _json(path: String, content_version: bool = true) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("Content file missing: %s" % path)
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		errors.append("Content must be a JSON object: %s" % path)
		return {}
	var parsed: Dictionary = parser.data
	if not RoomDefinition._is_integer(parsed.get("schema_version")) or parsed.schema_version != 1 or (content_version and (not parsed.get("content_version") is String or parsed.content_version != "overhead-v1")):
		errors.append("Unsupported content version: %s" % path)
		return {}
	return parsed


func _load_profiles() -> void:
	var data := _json("res://content/profiles.json")
	if str(data.get("collider_contract")) != "courier_overhead_v1" or not data.get("required_team_unlocks_are_separate") is bool or not data.required_team_unlocks_are_separate:
		errors.append("Fixed profiles require the shared courier collider and separate team unlocks")
	var records: Variant = data.get("profiles")
	if not records is Array:
		errors.append("Profiles must be an array")
		return
	for raw: Variant in records:
		if not raw is Dictionary or raw.get("id") not in ["tavi_fixed", "neri_fixed"]:
			errors.append("Unknown fixed profile")
			continue
		var id: String = raw["id"]
		var tavi: bool = id == "tavi_fixed"
		if profiles.has(id):
			errors.append("Duplicate fixed profile: %s" % id)
		if str(raw.get("display_name")) != ("Tavi" if tavi else "Neri") or not RoomDefinition._is_integer(raw.get("max_hearts")) or raw.max_hearts != (5 if tavi else 4) or str(raw.get("special_id")) != ("ember_arc" if tavi else "spore_bolt") or str(raw.get("theme_id")) != ("ember" if tavi else "moss") or str(raw.get("visual_bundle_id")) != ("fixed_tavi_v1" if tavi else "fixed_neri_v1"):
			errors.append("Invalid fixed profile fields: %s" % id)
		profiles[id] = raw.duplicate(true)
		for clip: String in courier_clip_keys():
			if assets.animation(str(raw.get("visual_bundle_id", "")), clip).is_empty():
				errors.append("Profile animation missing: %s/%s" % [id, clip])
	if profiles.size() != 2:
		errors.append("Both fixed profiles are required")


func _load_themes() -> void:
	var data := _json("res://content/themes.json")
	var records: Variant = data.get("themes")
	if not records is Array or not AssetCatalog.dimensions_match(data.get("tile_size"), 16, 16) or str(data.get("geometry_source")) != "canonical_room_data":
		errors.append("Invalid canonical theme contract")
		return
	var required: Variant = data.get("required_tile_slots")
	if not required is Array or required != TERRAIN_IDS:
		errors.append("Themes require all 48 terrain slots")
		return
	for raw: Variant in records:
		if not raw is Dictionary or raw.get("id") not in ["ember", "moss"]:
			errors.append("Unknown theme")
			continue
		var id: String = raw["id"]
		if themes.has(id) or not RoomDefinition._is_integer(raw.get("visibility_bit")) or raw.visibility_bit != (2 if id == "ember" else 4):
			errors.append("Duplicate theme or invalid visibility bit: %s" % id)
		var terrain: Dictionary = assets.entries.get(raw.get("terrain_asset_id", ""), {})
		if terrain.get("kind") != "tile_atlas" or not terrain.get("tile_ids") is Array or terrain.tile_ids != required:
			errors.append("Theme terrain mapping is incomplete: %s" % id)
		var backgrounds: Variant = raw.get("background_asset_ids")
		if not backgrounds is Array or backgrounds.size() != 3:
			errors.append("Theme requires three background layers: %s" % id)
		else:
			for background: Variant in backgrounds:
				var record: Dictionary = assets.entries.get(background, {})
				if record.get("kind") != "image" or not AssetCatalog.dimensions_match(record.get("size"), 480, 360) or record.get("extent") != "finite":
					errors.append("Invalid finite background: %s" % str(background))
		themes[id] = raw.duplicate(true)
	if themes.size() != 2:
		errors.append("Both visual themes are required")


func _load_dialogue() -> void:
	dialogue = _json("res://content/dialogue.json")
	var sequences: Variant = dialogue.get("sequences")
	if not sequences is Dictionary:
		errors.append("Dialogue sequences must be an object")
		return
	for id: String in ["oru_intro", "oru_return", "bridge_spindle_complete", "boss_defeated", "ending"]:
		if not sequences.has(id):
			errors.append("Missing dialogue sequence: %s" % id)
	for id: Variant in sequences:
		var lines: Variant = sequences[id]
		if not lines is Array or lines.is_empty():
			errors.append("Empty/invalid dialogue sequence: %s" % str(id))
			continue
		for line: Variant in lines:
			if not line is Dictionary or line.get("speaker") not in ["", "Tavi", "Neri", "Oru"] or not line.get("text") is String or line["text"].is_empty() or line["text"].length() > 150:
				errors.append("Invalid dialogue line: %s" % str(id))
				continue
			for code in line["text"].length():
				var point: int = line["text"].unicode_at(code)
				if point < 32 or point > 126:
					errors.append("Unsupported dialogue glyph: %s" % str(id))


func _validate_world() -> void:
	if str(world.get("start_room")) != "r00" or not world.get("checkpoints") is Dictionary or world.checkpoints != {"checkpoint_a": "r00", "checkpoint_b": "r04"}:
		errors.append("World start/checkpoints differ from Phase 1")
	var records: Variant = world.get("rooms")
	var seen := {}
	if not records is Array:
		errors.append("World rooms must be an array")
	else:
		for record: Variant in records:
			if not record is Dictionary or record.get("id") not in ROOM_IDS:
				errors.append("Unknown world room")
				continue
			var id: String = record["id"]
			if seen.has(id) or not record.get("challenge_rewards") is Array or record.challenge_rewards != REWARDS.get(id, []):
				errors.append("Duplicate world room or incorrect rewards: %s" % id)
			if str(record.get("name")) != ROOM_NAMES[ROOM_IDS.find(id)] or rooms[id].display_name != str(record.get("name")):
				errors.append("Room names differ from the authored world: %s" % id)
			seen[id] = true
		if seen.size() != 8:
			errors.append("World requires exactly eight rooms")
	var links: Variant = world.get("connections")
	seen = {}
	if not links is Array:
		errors.append("World connections must be an array")
		return
	for link: Variant in links:
		if not link is Dictionary or link.get("a") not in ROOM_IDS or link.get("b") not in ROOM_IDS:
			errors.append("Invalid world connection")
			continue
		var key := _link_key(link["a"], link["b"])
		if not LINKS.has(key) or seen.has(key) or not link.get("requires_all") is Array or link.requires_all != LINKS.get(key):
			errors.append("Incorrect/duplicate world gate: %s" % key)
		seen[key] = true
	if seen.size() != 9:
		errors.append("World requires nine gated connections")


func _validate_references() -> void:
	var exits := {}
	var counts := {}
	var progress_ids := {}
	var gallery_enemies := {}
	var checkpoints: Variant = world.get("checkpoints", {})
	if not checkpoints is Dictionary:
		checkpoints = {}
	for id: String in rooms:
		var definition: RoomDefinition = rooms[id]
		if not definition.is_valid():
			continue
		for entity: Dictionary in definition.entities:
			var kind: String = entity["type"]
			counts[kind] = int(counts.get(kind, 0)) + 1
			if id == "r03" and kind in ["spoolmite", "wickwing"]:
				gallery_enemies[kind] = true
			if kind in ["checkpoint", "anchor_pair", "loom", "secret"]:
				var progress_id: String = entity.get("checkpoint_id", entity.get("flag", ""))
				if progress_ids.has(progress_id):
					errors.append("Duplicate progression entity: %s" % progress_id)
				progress_ids[progress_id] = true
			if kind == "diagnostic_mover":
				errors.append("Diagnostic mover is forbidden in production")
			elif kind == "exit":
				var target: String = entity["target_room"]
				var target_room: RoomDefinition = rooms.get(target)
				var key := "%s:%s" % [id, target]
				if target_room == null or not target_room.spawns.has(entity["target_entrance"]) or exits.has(key) or entity["requires_all"] != LINKS.get(_link_key(id, target), ["invalid"]):
					errors.append("Unresolved/duplicate exit or gate: %s/%s" % [id, entity["id"]])
				exits[key] = true
			elif kind == "checkpoint":
				if str(checkpoints.get(entity["checkpoint_id"])) != id:
					errors.append("Checkpoint in wrong room: %s" % id)
			elif kind == "anchor_pair":
				if entity["flag"] != {"r02": "bridge_spindle", "r06": "bridge_causeway"}.get(id, "invalid"):
					errors.append("Bridge in wrong room: %s" % id)
			elif (kind == "npc" and id != "r00") or (kind == "spoolwarden" and id != "r05") or (kind == "loom" and id != "r07") or (kind == "secret" and id != "r03"):
				errors.append("Unique entity in wrong room: %s/%s" % [id, kind])
		for decoration: Dictionary in definition.decor:
			var record: Dictionary = assets.entries.get(decoration["asset_id"], {})
			if record.get("kind") not in ["sprite_atlas", "tile_atlas"] or int(decoration["frame"]) >= record.get("frames", []).size():
				errors.append("Decoration frame is unresolved: %s" % id)
	if exits.size() != 18:
		errors.append("World requires eighteen directed exits")
	if gallery_enemies.size() != 2:
		errors.append("Glasswing Gallery requires both ordinary enemy lessons")
	for kind: String in ["checkpoint", "npc", "secret", "spoolwarden", "anchor_pair", "loom"]:
		var expected: int = 2 if kind in ["checkpoint", "anchor_pair"] else 1
		if counts.get(kind, 0) != expected:
			errors.append("Incorrect unique entity count: %s" % kind)


static func _link_key(a: String, b: String) -> String:
	return "%s:%s" % [a, b] if a < b else "%s:%s" % [b, a]
