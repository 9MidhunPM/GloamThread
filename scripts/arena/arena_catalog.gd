class_name ArenaCatalog
extends RefCounted
## Authored encounter and shop data. Mechanics remain bounded in game code.

const KITS := ["ember", "frost", "storm", "stone", "nature", "shadow"]
const ROLES := ["swarm", "chaser", "charger", "shooter", "flyer", "heavy"]
const BOSSES := ["warden", "artillery", "tempest", "loom"]
const STATS := ["damage", "attack_speed", "special_cooldown", "max_health", "move_speed", "crit", "magnet", "dodge_cooldown", "lifesteal", "thorns", "projectile_count", "area", "burn", "freeze", "chain", "stagger", "regen", "pierce"]
var kits: Dictionary = {}
var upgrades: Array[Dictionary] = []
var waves: Array[Dictionary] = []
var arenas: Array[Dictionary] = []
var errors: PackedStringArray = []


static func load_catalog(path: String = "res://content/arena/catalog.json") -> ArenaCatalog:
	var result := ArenaCatalog.new()
	if not FileAccess.file_exists(path):
		result.errors.append("Arena content is missing. Install a complete build.")
		return result
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw is Dictionary or raw.get("schema_version") != 1 or raw.get("content_version") != "arena-v1":
		result.errors.append("Arena catalog version is unsupported.")
		return result
	if not raw.get("kits") is Dictionary or not raw.get("upgrades") is Array or not raw.get("waves") is Array or not raw.get("arenas") is Array:
		result.errors.append("Arena catalog sections are missing.")
		return result
	for kit: String in KITS:
		var record: Variant = raw.kits.get(kit)
		if not record is Dictionary or not record.get("name") is String or not record.get("color") is String or not Color.html_is_valid(record.color):
			result.errors.append("Invalid fighter family: " + kit)
		else:
			result.kits[kit] = record.duplicate(true)
	var ids: Dictionary = {}
	for record: Variant in raw.upgrades:
		if not record is Dictionary or not record.get("id") is String or ids.has(record.id) or record.get("kit") not in KITS + ["any"] or record.get("stat") not in STATS or not _number(record.get("amount")) or not _integer(record.get("price"), 1, 1000) or not _integer(record.get("max_rank"), 1, 10) or not record.get("name") is String or not record.get("description") is String:
			result.errors.append("Invalid or duplicate upgrade record.")
			continue
		ids[record.id] = true
		result.upgrades.append(record.duplicate(true))
	if result.upgrades.size() != 30:
		result.errors.append("Arena requires 30 authored upgrades.")
	for i in raw.waves.size():
		var record: Variant = raw.waves[i]
		if not record is Dictionary or record.get("number") != i + 1 or not _integer(record.get("count"), 1, 300) or not _integer(record.get("interval_ticks"), 6, 600) or not record.get("enemies") is Array or record.enemies.is_empty() or not _integer(record.get("elite_every"), 0, 100) or record.get("boss") not in BOSSES + [""]:
			result.errors.append("Invalid wave %d." % (i + 1))
			continue
		var valid := true
		for role: Variant in record.enemies:
			valid = valid and role in ROLES
		if not valid or ((i + 1) % 5 == 0) != (record.boss != ""):
			result.errors.append("Wave roles/boss schedule differ from the contract.")
		else:
			result.waves.append(record.duplicate(true))
	if result.waves.size() != 20:
		result.errors.append("Arena requires 20 authored waves.")
	for record: Variant in raw.arenas:
		if not record is Dictionary or not record.get("id") is String or not record.get("name") is String or not record.get("platforms") is Array:
			result.errors.append("Invalid arena layout.")
			continue
		var valid := true
		for platform: Variant in record.platforms:
			valid = valid and platform is Array and platform.size() == 3
			if valid:
				valid = _number(platform[0]) and _number(platform[1]) and _number(platform[2]) and float(platform[0]) >= 32 and float(platform[0]) + float(platform[2]) <= 608 and float(platform[1]) in [256.0, 288.0] and float(platform[2]) >= 32
		if valid:
			result.arenas.append(record.duplicate(true))
		else:
			result.errors.append("Arena platforms are outside the playable bounds.")
	if result.arenas.size() != 4:
		result.errors.append("Arena requires four layouts.")
	return result


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= 10000


static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value) and float(value) == floorf(float(value)) and int(value) >= low and int(value) <= high
