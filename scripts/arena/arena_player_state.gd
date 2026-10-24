class_name ArenaPlayerState
extends RefCounted
## Run-only power and wallet, separate from reusable character artwork.

var slot_index: int = 0
var kit_id: String = "ember"
var coins: int = 0
var kills: int = 0
var spent: int = 0
var levels: Dictionary = {}
var modifiers: Dictionary = {}


func stats() -> Dictionary:
	var values := {"damage": 12.0, "attack_speed": 1.0, "special_cooldown": 300.0,
		"max_health": 100.0, "move_speed": 145.0, "crit": 0.05, "magnet": 1.0,
		"dodge_cooldown": 48.0, "lifesteal": 0.0, "thorns": 0.0,
		"projectile_count": 1.0, "area": 1.0, "burn": 0.0, "freeze": 0.0,
		"chain": 0.0, "stagger": 0.0, "regen": 0.0, "pierce": 0.0}
	match kit_id:
		"frost": values.damage = 10.0; values.freeze = 1.0
		"storm": values.damage = 9.0; values.attack_speed = 1.25; values.chain = 1.0
		"stone": values.damage = 17.0; values.attack_speed = 0.8; values.max_health = 125.0; values.stagger = 1.0
		"nature": values.damage = 10.0; values.regen = 0.5
		"shadow": values.damage = 11.0; values.crit = 0.15; values.pierce = 1.0
		_: values.burn = 1.0
	for key: String in modifiers:
		if values.has(key):
			values[key] = float(values[key]) + float(modifiers[key])
	var bounds := {"damage": Vector2(1, 200), "attack_speed": Vector2(0.5, 3), "special_cooldown": Vector2(60, 600), "max_health": Vector2(50, 350), "move_speed": Vector2(90, 240), "crit": Vector2(0, 0.75), "magnet": Vector2(1, 4), "dodge_cooldown": Vector2(15, 120), "lifesteal": Vector2(0, 0.3), "thorns": Vector2(0, 1), "projectile_count": Vector2(1, 5), "area": Vector2(0.5, 2), "burn": Vector2(0, 4), "freeze": Vector2(0, 4), "chain": Vector2(0, 4), "stagger": Vector2(0, 4), "regen": Vector2(0, 5), "pierce": Vector2(0, 4)}
	for key: String in bounds:
		values[key] = clampf(float(values[key]), bounds[key].x, bounds[key].y)
	return values


func rank(id: String) -> int:
	return int(levels.get(id, 0))


func apply_upgrade(record: Dictionary) -> void:
	var id := str(record.id)
	levels[id] = rank(id) + 1
	var key := str(record.stat)
	modifiers[key] = float(modifiers.get(key, 0.0)) + float(record.amount)
