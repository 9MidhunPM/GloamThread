extends Scenario
## Controlled recovery fixture; the separate route driver supplies normal-play evidence.

class RecoveryWorld extends ArenaRunSession:
	# Keep the real session/revival physics while excluding encounter damage.
	# A long cadence no longer suppresses the empty-field catch-up spawn rule.
	func _process_spawns() -> void:
		pass


func run() -> void:
	var catalog := ArenaCatalog.load_catalog()
	var bundles := FighterLibrary.new().list_bundles()
	for slot in 2:
		InputRouter.assign(slot, DeviceSource.keyboard_left() if slot == 0 else DeviceSource.keyboard_right())
		InputRouter.set_test_input(slot, 0)
	var world := RecoveryWorld.new()
	world.configure(catalog, [bundles[0], bundles[1]], 55)
	add_child(world)
	await ticks(3)
	world.phase = "combat"
	# The authored queue still prevents an empty encounter from clearing.
	world.fighters[0].immunity_ticks = 0
	world.fighters[0].take_damage(10000, Vector2.ZERO)
	await ticks(790)
	assert_true(world.fighters[0].downed, "a downed partner does not revive on a wall-clock timeout")
	assert_eq(world.phase, "combat", "one surviving teammate can continue the wave beyond twelve seconds")
	world.fighters[1].position = world.fighters[0].position + Vector2(10, 0)
	world.fighters[1].velocity = Vector2.ZERO
	InputRouter.set_test_input(1, CommandSnapshot.Action.INTERACT)
	await ticks(60)
	assert_true(world.revive_fraction(0) > 0.5, "owned held interact builds shared-session revive progress")
	world.fighters[1].immunity_ticks = 0
	world.fighters[1].take_damage(5, Vector2.ZERO)
	await ticks(2)
	assert_true(world.revive_fraction(0) < 0.1, "damage to the rescuer interrupts accumulated progress")
	await ticks(100)
	assert_true(not world.fighters[0].downed, "ninety uninterrupted physics ticks revive the partner")
	assert_true(world.fighters[0].health >= world.fighters[0].max_health * 0.35, "revive restores bounded health")
	InputRouter.set_test_input(1, 0)
	for fighter: ArenaFighter in world.fighters:
		fighter.immunity_ticks = 0
		fighter.take_damage(10000, Vector2.ZERO)
	await ticks(2)
	assert_eq(world.phase, "defeat", "a true team wipe with a queued encounter ends the run")
	var elapsed := world.elapsed_ticks
	var positions := [world.fighters[0].position, world.fighters[1].position]
	await ticks(12)
	assert_eq(world.elapsed_ticks, elapsed, "defeat freezes encounter progression")
	assert_eq(world.fighters[0].position, positions[0], "defeated world stops corpse physics")
	assert_eq(world.fighters[1].position, positions[1], "both player views share the frozen outcome")
