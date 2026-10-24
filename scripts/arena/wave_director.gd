class_name WaveDirector
extends RefCounted
## Expands finite authored waves into bounded endless encounter budgets.

var catalog: ArenaCatalog
var roster_size: int = 1


func definition(number: int) -> Dictionary:
	if catalog == null or catalog.waves.size() != 20 or number < 1:
		return {}
	var result: Dictionary = catalog.waves[(number - 1) % 20].duplicate(true)
	var cycle := (number - 1) / 20
	result.number = number
	result.count = mini(250, ceili(float(result.count) * (1.0 + 0.3 * cycle) * (1.45 if roster_size == 2 else 1.0)))
	result.interval_ticks = maxi(12, int(result.interval_ticks) - 2 * cycle)
	result.health_scale = (1.3 if roster_size == 2 else 1.0) * (1.0 + 0.18 * cycle)
	return result


func live_cap(number: int) -> int:
	return mini(32 if roster_size == 2 else 24, (8 if roster_size == 2 else 6) + number)
