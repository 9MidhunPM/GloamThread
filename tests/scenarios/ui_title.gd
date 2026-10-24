extends Scenario
## Real menu layout and binding checks; no artwork or hardware acceptance claim.

const Action := CommandSnapshot.Action


func run() -> void:
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.assign(1, DeviceSource.keyboard_right())
	var menu: CanvasLayer = load("res://scripts/ui/game_menus.gd").new()
	menu.call("set_font", load("res://assets/generated/font/weft_5x7.fnt"))
	add_child(menu)
	var home_rows: Array[Dictionary] = [
			{"id": "new", "label": "New journey"},
			{"id": "continue", "label": "Continue", "enabled": false,
				"detail": "No readable campaign is available. ".repeat(20)},
			{"id": "settings", "label": "Settings and controls"},
			{"id": "quit", "label": "Quit"},
		]
	menu.call("show_menu", "title", "Gloamthread: Two Ends",
		"Two couriers. Two views. One road home.\nA local adventure for two players.", home_rows, 0)
	await _settle()
	var scroll := menu.find_child("Scroll", true, false) as ScrollContainer
	var scene := menu.find_child("TitleVignette", true, false) as Control
	var rows := menu.find_child("Rows", true, false) as VBoxContainer
	assert_true(scene.visible, "home illustration is present")
	assert_true(scroll.get_global_rect().end.x < scene.get_global_rect().position.x,
		"home action list does not cover the illustration")
	assert_eq(rows.get_child_count(), 4, "all real home actions remain present")
	for row: Node in rows.get_children():
		assert_true(scroll.get_global_rect().encloses((row as Control).get_global_rect()),
			"every home action fits without scrolling: %s %s inside %s (body %s)" % [row.name,
				(row as Control).get_global_rect(), scroll.get_global_rect(),
				(menu.find_child("Body", true, false) as Control).get_global_rect()])
	var p1 := scene.find_child("P1Guide", true, false) as Label
	var p2 := scene.find_child("P2Guide", true, false) as Label
	assert_true(p1.text.contains("[F] Slash") and p2.text.contains("[Comma] Slash"),
		"home guides distinguish both current attack bindings")
	assert_true(p1.text.begins_with("P1 IN GAME") and p2.text.begins_with("P2 IN GAME")
		and not p1.text.contains("Choose") and not p2.text.contains("Choose"),
		"both-player gameplay previews never promise partner menu confirmation")
	assert_true((menu.find_child("Footer", true, false) as Label).text.begins_with("P1 "),
		"only the owner footer offers menu confirmation controls")
	var bindings := Bindings.from_dict(InputRouter.bindings_of(0).to_dict())
	bindings.controls[Action.ATTACK] = [KEY_Q]
	InputRouter.set_bindings(0, bindings)
	await _settle()
	assert_true(p1.text.contains("[Q] Slash") and not p1.text.contains("[F] Slash"),
		"home guide follows actual remapping rather than advertising defaults")
	var setting_rows: Array[Dictionary] = [{"id": "back", "label": "Back"}]
	menu.call("show_menu", "settings", "Settings", "Choose a preference.", setting_rows, 1)
	await _settle()
	assert_true(not scene.visible, "illustration does not obstruct operational menus")
	assert_eq(scroll.size.x, 872.0, "other menus regain the full readable width")
	assert_true((menu.find_child("MenuOwner", true, false) as Label).text.begins_with("PLAYER 2"),
		"operational screen identifies its actual input owner")
	menu.call("hide_menu")
	menu.queue_free()
	await _settle()
	InputRouter.clear(0)
	InputRouter.clear(1)


func _settle() -> void:
	for _index in 4:
		await get_tree().physics_frame
		await get_tree().process_frame
