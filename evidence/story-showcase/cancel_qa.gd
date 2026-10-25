extends "res://tools/story_showcase.gd"

var stopped := false
func _process(delta: float) -> bool:
	super._process(delta)
	if not stopped and is_instance_valid(driver) and driver._tick_count > 100:
		stopped = true
		stop_tour()
	return false
