extends Node
## Browser lifecycle only; combat and saves remain owned by the active mode.

var _focus_callback: JavaScriptObject


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		return
	_focus_callback = JavaScriptBridge.create_callback(_focus_lost)
	var shell := JavaScriptBridge.get_interface("GloamWeb")
	if shell != null:
		shell.onFocusLoss(_focus_callback)
	if not OS.is_userfs_persistent():
		warn_storage()


func set_mode(mode: String) -> void:
	if not OS.has_feature("web"):
		return
	get_window().content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	var shell := JavaScriptBridge.get_interface("GloamWeb")
	if shell != null:
		shell.setMode(mode)


func home() -> void:
	if OS.has_feature("web"):
		_focus_lost([])
		var shell := JavaScriptBridge.get_interface("GloamWeb")
		if shell != null:
			shell.home()


func fullscreen() -> void:
	if OS.has_feature("web"):
		var shell := JavaScriptBridge.get_interface("GloamWeb")
		if shell != null:
			shell.fullscreen()


func warn_storage() -> void:
	if not OS.has_feature("web"):
		return
	var shell := JavaScriptBridge.get_interface("GloamWeb")
	if shell != null:
		shell.storageWarning("Browser storage is unavailable. Play can continue, but saves may be lost. Download your fighters for backup.")


func _focus_lost(_arguments: Array) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("browser_focus_lost"):
		scene.call("browser_focus_lost")
	InputRouter.flush()
