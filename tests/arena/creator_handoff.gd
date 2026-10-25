extends Scenario
## Actual acceptance signal, durable local install and production lobby handoff.

func run() -> void:
	var folder := "/tmp/gloamthread-creator-handoff-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var app := ArenaApp.new()
	app.library.storage_root = folder.path_join("fighters")
	app.settings_store.path = folder.path_join("settings.json")
	app.records.path = folder.path_join("records.json")
	add_child(app)
	await ticks(2)
	app._open_creator(0)
	var creator := app.creator
	creator.candidate = app.bundles[0]
	creator._apply_proposal(creator.candidate)
	creator._update_controls()
	assert_true(not creator._accept.disabled, "validated matching preview has an enabled acceptance action")
	var id: String = creator.candidate.id
	creator._accept.pressed.emit()
	await ticks(2)
	assert_eq(app.screen, "lobby", "accept from the title proceeds to the selected fighter lobby")
	assert_eq(app.selected[0].id, id, "accepted fighter remains selected for its player")
	assert_true(app.library.load_bundle(folder.path_join("fighters").path_join(id).path_join("manifest.json")).ok, "acceptance installs a fully loadable offline fighter")
	assert_true(app._message.text.contains("selected"), "the handoff confirms selection instead of silently returning to the old screen")
	app._begin_run(18427)
	await ticks(2)
	assert_true(is_instance_valid(app.session) and app.session.fighters[0]._appearance.id == id, "Start Run uses the accepted fighter in the authoritative world")
	app._show_title()
