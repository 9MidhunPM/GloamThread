extends Scenario
## Actual join screen advertises only the selected player's live bindings.
const App := preload("res://scripts/app/app_controller.gd")
const Action := CommandSnapshot.Action

func run() -> void:
	var app := App.new()
	var folder := "user://overhead-controls-%d" % Time.get_ticks_usec()
	app.saves.path = folder + "/team.json"
	app.settings_store.path = folder + "/settings.json"
	add_child(app)
	app._on_action("new")
	var guide := app._join_control_guide(0)
	assert_true(guide.contains("[Space] Roll") and not guide.contains("jump"), "new journey teaches the overhead action")
	assert_true(guide.contains("Threadstep (locked)"), "new couriers do not have dash yet")
	var bindings := InputRouter.bindings_of(1)
	bindings.controls[Action.ROLL] = [KEY_J]
	bindings.controls[Action.INTERACT] = [KEY_N]
	InputRouter.set_bindings(1, bindings)
	app._show_join()
	var rows: Array = app.menus.get("_rows")
	assert_true(str(rows[1].detail).contains("[J] Roll") and str(rows[1].detail).contains("[N] Interact"), "source row follows selected slot remapping")
	assert_true(not str(rows[0].detail).contains("[J] Roll"), "partner mapping never leaks across slots")
	var progress := TeamProgress.new()
	progress.commit_flags(["boss_spoolwarden", "threadstep", "shortcut_bell"])
	app.saves.save_campaign(progress.to_save(), true)
	app._join_continue = true
	assert_true(not app._join_control_guide(0).contains("(locked)"), "Continue explains an already unlocked team move")
	app._join_continue = false
	assert_true(app._join_control_guide(0).contains("(locked)"), "New remains locked even with another saved campaign")
	app.free()
	InputRouter.clear(0)
	InputRouter.clear(1)
