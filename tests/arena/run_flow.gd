extends Scenario


func run() -> void:
	var catalog := ArenaCatalog.load_catalog()
	var bundles := FighterLibrary.new().list_bundles()
	if not catalog.errors.is_empty() or bundles.is_empty():
		assert_true(false, "run fixture requires valid shipped content")
		return
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.set_test_input(0, 0)
	var solo := ArenaRunSession.new()
	solo.configure(catalog, [bundles[0]], 1337)
	add_child(solo)
	await ticks(3)
	assert_eq(solo.fighters.size(), 1, "solo creates exactly one gameplay actor")
	assert_eq(solo.phase, "countdown", "fresh run begins with telegraphed countdown")
	var director := solo.director
	for number in 40:
		var definition := director.definition(number + 1)
		assert_eq(definition.boss != "", (number + 1) % 5 == 0, "boss schedule wave%d" % (number + 1))
		assert_true(director.live_cap(number + 1) <= 24, "solo live cap remains bounded in endless")
	solo.phase = "combat"
	solo.spawn_queue.clear()
	solo.telegraphs.clear()
	# A pending telegraph is still part of the wave, even before the actor exists.
	solo.telegraphs.append({"ticks": 100, "role": "chaser", "boss": "", "elite": false, "position": Vector2(44, 320)})
	await ticks(2)
	assert_eq(solo.phase, "combat", "pending telegraph prevents premature clear")
	var before := solo.elapsed_ticks
	get_tree().paused = true
	await ticks(4)
	assert_eq(solo.elapsed_ticks, before, "shared pause freezes run clocks")
	get_tree().paused = false
	solo.telegraphs.clear()
	solo.fighters[0].downed = true
	await ticks(2)
	assert_eq(solo.phase, "clear", "same-tick final-clear takes priority over wipe")
	solo.wave = 20
	solo.phase_ticks = 74
	await ticks(2)
	assert_eq(solo.phase, "victory", "wave20 completion reaches victory")
	solo.continue_endless()
	assert_eq(solo.phase, "shop", "endless starts with an upgrade opportunity")
	assert_true(solo.endless, "endless choice retained")
	solo.toggle_ready(0)
	assert_eq(solo.wave, 21, "endless advances into wave21")
	solo.phase = "combat"
	solo.fighters[0].immunity_ticks = 0
	solo.fighters[0].take_damage(10000, Vector2.ZERO)
	await ticks(2)
	assert_eq(solo.phase, "defeat", "solo lethal hit with queued enemies ends run")
