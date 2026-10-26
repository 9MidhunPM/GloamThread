extends SceneTree
## Visible tour of the arena accessibility options using the real ArenaApp.
## Uses temporary settings/records; personal saves are untouched.
## godot --path . --script tools/accessibility_tour.gd

const Action := CommandSnapshot.Action

class Errors extends Logger:
	var messages: Array[String] = []
	func _log_error(_fn: String, file: String, line: int, code: String, reason: String, _notify: bool, type: int, _trace: Array[ScriptBacktrace]) -> void:
		if type != Logger.ERROR_TYPE_WARNING:
			messages.append("%s:%d %s" % [file, line, reason if reason != "" else code])

var errors := Errors.new()
var app: Node
var caption: Label
var temporary: Array[String] = []


func _initialize() -> void:
	OS.add_logger(errors)
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("The accessibility tour needs a display.")
		quit(2)
		return
	root.size = Vector2i(1920, 1080)
	root.title = "Gloamthread / Accessibility Tour"
	var stamp := str(Time.get_ticks_usec())
	app = load("res://scripts/arena/arena_app.gd").new()
	app.settings_store.path = "user://accessibility-tour-settings-%s.json" % stamp
	app.records.path = "user://accessibility-tour-records-%s.json" % stamp
	temporary = [app.settings_store.path, app.records.path]
	root.add_child(app)
	_add_caption()
	await _hold(0.2)
	_say("ACCESSIBILITY TOUR  /  Every option is off by default and saved with your settings.")
	await _hold(3.0)
	app._show_settings()
	_say("SETTINGS  /  Up/Down move, Left/Right change values; each option explains itself.")
	for index in app.menu_buttons.size() - 1:
		app.menu_cursor = index
		app._focus_menu()
		await _hold(1.6)
	_say("ASSISTS  /  Damage taken 50%, game speed 80%, P1 press-to-toggle attack, high contrast on.")
	await _adjust_row(8, 1, 2)
	await _adjust_row(9, 1, 1)
	_press_row(10)
	await _hold(0.8)
	_press_row(6)
	await _hold(3.0)
	app._show_remap(0)
	_say("REMAP  /  Move any action to a new key or button. Clashes are refused.")
	await _hold(3.0)
	app.menu_cursor = 4
	app._focus_menu()
	app._begin_capture(0, Action.JUMP)
	await _hold(2.5)
	app.assign_control(0, Action.JUMP, KEY_K)
	app._end_capture()
	_say("REMAP  /  Jump moved to K; the lobby and settings show live bindings.")
	await _hold(3.0)
	app._reset_bindings(0)
	await _hold(1.5)
	app._show_title()
	app._show_lobby(1)
	await _hold(2.5)
	app._begin_run(18427)
	_say("IN A RUN  /  One press keeps attacking (HUD: AUTO-ATTACK). Half damage, 80% speed.")
	var input := root.get_node("InputRouter")
	await _hold(1.5)
	input.set_test_input(0, Action.ATTACK)
	await _hold(0.1)
	input.set_test_input(0, 0)
	var direction := Action.RIGHT
	for step in 10:
		input.set_test_input(0, direction)
		await _hold(0.9)
		direction = Action.LEFT if direction == Action.RIGHT else Action.RIGHT
	input.set_test_input(0, Action.JUMP)
	await _hold(0.3)
	input.clear_test_input()
	app._show_pause()
	_say("PAUSE  /  Settings stay reachable mid-run. Assisted runs are labelled in results.")
	await _hold(3.0)
	app._show_title()
	await _hold(1.0)
	_finish()


func _adjust_row(index: int, direction: int, times: int) -> void:
	app.menu_cursor = index
	app._focus_menu()
	for _step in times:
		await _hold(0.6)
		(app.menu_buttons[index].get_meta("adjust") as Callable).call(direction)
	await _hold(0.8)


func _press_row(index: int) -> void:
	app.menu_cursor = index
	app._focus_menu()
	app.menu_buttons[index].pressed.emit()


func _add_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.025, 0.045, 0.065, 0.94)
	panel.position = Vector2(0, 1010)
	panel.size = Vector2(1920, 70)
	layer.add_child(panel)
	caption = Label.new()
	caption.position = Vector2(40, 1022)
	caption.size = Vector2(1840, 50)
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_color_override("font_color", Color("f2e2b9"))
	if app.font != null:
		caption.add_theme_font_override("font", app.font)
	layer.add_child(caption)


func _say(text: String) -> void:
	caption.text = text
	print("TOUR ", text)


func _hold(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _finish() -> void:
	app.free()
	var router := root.get_node("InputRouter")
	router.clear_test_input()
	for slot in 2:
		router.clear(slot)
	Engine.time_scale = 1.0
	for path: String in temporary:
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("ACCESSIBILITY_TOUR ", JSON.stringify({"errors": errors.messages}))
	quit(0 if errors.messages.is_empty() else 1)
