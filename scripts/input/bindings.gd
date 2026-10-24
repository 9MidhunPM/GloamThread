class_name Bindings
extends RefCounted
## Action-to-physical-control mapping for one device kind.
##
## Keyboard bindings list physical keycodes (Key enum). Gamepad bindings list
## dictionaries of either {"button": JoyButton} or {"axis": JoyAxis, "sign": -1|1}.
## Everything is plain data so settings can persist and remap it (milestone M6).

const Action := CommandSnapshot.Action

var kind: DeviceSource.Kind
## Action (int) -> Array of controls.
var controls: Dictionary = {}
var deadzone: float = 0.3


static func defaults_for(device_kind: DeviceSource.Kind) -> Bindings:
	var bindings := Bindings.new()
	bindings.kind = device_kind
	match device_kind:
		DeviceSource.Kind.KEYBOARD_LEFT:
			bindings.controls = {
				Action.LEFT: [KEY_A],
				Action.RIGHT: [KEY_D],
				Action.UP: [KEY_W],
				Action.DOWN: [KEY_S],
				Action.JUMP: [KEY_SPACE],
				Action.ATTACK: [KEY_F],
				Action.SPECIAL: [KEY_G],
				Action.INTERACT: [KEY_E],
				Action.DASH: [KEY_SHIFT],
				Action.PAUSE: [KEY_ESCAPE],
				Action.MAP: [KEY_TAB],
			}
		DeviceSource.Kind.KEYBOARD_RIGHT:
			bindings.controls = {
				Action.LEFT: [KEY_LEFT],
				Action.RIGHT: [KEY_RIGHT],
				Action.UP: [KEY_UP],
				Action.DOWN: [KEY_DOWN],
				Action.JUMP: [KEY_PERIOD],
				Action.ATTACK: [KEY_COMMA],
				Action.SPECIAL: [KEY_SLASH],
				Action.INTERACT: [KEY_M],
				Action.DASH: [KEY_APOSTROPHE],
				Action.PAUSE: [KEY_ENTER],
				Action.MAP: [KEY_SEMICOLON],
			}
		DeviceSource.Kind.GAMEPAD:
			bindings.controls = {
				Action.LEFT: [{"button": JOY_BUTTON_DPAD_LEFT}, {"axis": JOY_AXIS_LEFT_X, "sign": -1}],
				Action.RIGHT: [{"button": JOY_BUTTON_DPAD_RIGHT}, {"axis": JOY_AXIS_LEFT_X, "sign": 1}],
				Action.UP: [{"button": JOY_BUTTON_DPAD_UP}, {"axis": JOY_AXIS_LEFT_Y, "sign": -1}],
				Action.DOWN: [{"button": JOY_BUTTON_DPAD_DOWN}, {"axis": JOY_AXIS_LEFT_Y, "sign": 1}],
				Action.JUMP: [{"button": JOY_BUTTON_A}],
				Action.ATTACK: [{"button": JOY_BUTTON_X}],
				Action.SPECIAL: [{"button": JOY_BUTTON_B}],
				Action.INTERACT: [{"button": JOY_BUTTON_Y}],
				Action.DASH: [{"button": JOY_BUTTON_RIGHT_SHOULDER}, {"axis": JOY_AXIS_TRIGGER_RIGHT, "sign": 1}],
				Action.PAUSE: [{"button": JOY_BUTTON_START}],
				Action.MAP: [{"button": JOY_BUTTON_BACK}],
			}
	return bindings


## Returns the physical keyboard keys bound to [param action]; empty for gamepads.
func keys_for(action: int) -> Array:
	if kind == DeviceSource.Kind.GAMEPAD:
		return []
	return controls.get(action, [])


## Returns the gamepad controls bound to [param action]; empty for keyboards.
func pad_controls_for(action: int) -> Array:
	if kind != DeviceSource.Kind.GAMEPAD:
		return []
	return controls.get(action, [])


## Human-readable label for the first control bound to [param action], for prompts.
func prompt_label(action: int) -> String:
	var list: Array = controls.get(action, [])
	if list.is_empty():
		return "?"
	var first: Variant = list[0]
	if first is int:
		return OS.get_keycode_string(first as Key)
	var control: Dictionary = first
	if control.has("button"):
		return _button_label(control["button"] as JoyButton)
	var axis: JoyAxis = control["axis"]
	return "Axis %d%s" % [axis, "+" if int(control.get("sign", 1)) > 0 else "-"]


static func _button_label(button: JoyButton) -> String:
	match button:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_BACK: return "Select"
		JOY_BUTTON_DPAD_LEFT: return "D-Left"
		JOY_BUTTON_DPAD_RIGHT: return "D-Right"
		JOY_BUTTON_DPAD_UP: return "D-Up"
		JOY_BUTTON_DPAD_DOWN: return "D-Down"
	return "Button %d" % button


func to_dict() -> Dictionary:
	var out := {}
	for action: int in controls:
		out[CommandSnapshot.action_name(action as Action)] = controls[action].duplicate(true)
	return {"kind": DeviceSource.Kind.keys()[kind], "deadzone": deadzone, "controls": out}


## Builds bindings from saved data, falling back to defaults for anything malformed.
static func from_dict(data: Dictionary) -> Bindings:
	var kind_name: String = str(data.get("kind", ""))
	var kind_index: int = DeviceSource.Kind.keys().find(kind_name)
	if kind_index <= DeviceSource.Kind.NONE:
		push_warning("Bindings: unknown device kind '%s'; using keyboard defaults" % kind_name)
		kind_index = DeviceSource.Kind.KEYBOARD_LEFT
	var bindings := defaults_for(kind_index as DeviceSource.Kind)
	var saved_deadzone: Variant = data.get("deadzone", bindings.deadzone)
	if (saved_deadzone is int or saved_deadzone is float) and is_finite(float(saved_deadzone)):
		bindings.deadzone = clampf(float(saved_deadzone), 0.05, 0.9)
	var saved: Variant = data.get("controls", {})
	if saved is Dictionary:
		for name: Variant in (saved as Dictionary):
			if not (name is String):
				continue
			var action := CommandSnapshot.action_from_name(name as String)
			if action == 0:
				continue
			var normalised: Variant = _normalise_controls((saved as Dictionary)[name], bindings.kind)
			if normalised is Array:
				bindings.controls[action] = normalised
			else:
				push_warning("Bindings: invalid controls for '%s'; retaining defaults" % name)
	return bindings


## Reject an entire malformed action, rather than installing a partially valid
## mapping. Empty arrays deliberately unbind an action. JSON numbers may arrive
## as floats, so accept only integral values and normalise them before polling.
static func _normalise_controls(raw: Variant, device_kind: DeviceSource.Kind) -> Variant:
	if not (raw is Array):
		return null
	var normalised: Array = []
	for control: Variant in (raw as Array):
		if device_kind != DeviceSource.Kind.GAMEPAD:
			if not _integer_in_range(control, KEY_SPACE, KEY_UNKNOWN - 1):
				return null
			var keycode: int = int(control)
			var label := OS.get_keycode_string(keycode as Key)
			if label.is_empty() or OS.find_keycode_from_string(label) != keycode:
				return null
			normalised.append(keycode)
		elif control is Dictionary:
			var item: Dictionary = control
			if item.size() == 1 and item.has("button"):
				if not _integer_in_range(item["button"], 0, JOY_BUTTON_MAX - 1):
					return null
				normalised.append({"button": int(item["button"])})
			elif item.size() == 2 and item.has("axis") and item.has("sign"):
				if not _integer_in_range(item["axis"], 0, JOY_AXIS_MAX - 1):
					return null
				if not _integer_in_range(item["sign"], -1, 1) or int(item["sign"]) == 0:
					return null
				normalised.append({"axis": int(item["axis"]), "sign": int(item["sign"])})
			else:
				return null
		else:
			return null
	return normalised


static func _integer_in_range(value: Variant, minimum: int, maximum: int) -> bool:
	if value is int:
		return value >= minimum and value <= maximum
	if value is float:
		return is_finite(value) and value == floorf(value) and value >= minimum and value <= maximum
	return false
