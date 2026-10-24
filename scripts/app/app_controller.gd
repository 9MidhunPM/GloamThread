extends Control
## Temporary M0 keyboard joins; M1 replaces this with the explicit join screen.

const SESSION_SCENE := preload("res://scenes/session/session.tscn")


func _ready() -> void:
	InputRouter.assign(0, DeviceSource.keyboard_left())
	InputRouter.assign(1, DeviceSource.keyboard_right())
	var session := SESSION_SCENE.instantiate() as GameSession
	add_child(session)
	if not session.session_ready:
		push_error("Startup failed: %s" % session.startup_error)
		session.queue_free()
		_show_startup_error()


func _show_startup_error() -> void:
	var panel := VBoxContainer.new()
	panel.position = Vector2(250, 110)
	panel.size = Vector2(460, 140)
	var title := Label.new()
	title.text = "Gloamthread: Two Ends"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var message := Label.new()
	message.text = "This copy is missing required game data.\nPlease install a complete build."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(message)
	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(get_tree().quit)
	panel.add_child(quit_button)
	add_child(panel)
	quit_button.grab_focus()
