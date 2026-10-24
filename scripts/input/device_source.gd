class_name DeviceSource
extends RefCounted
## One physical input source a player slot can own.
##
## The keyboard is split into two named zones so two people can share it
## (optional mode with a rollover caveat, see MVP.md). A gamepad is identified
## by its GUID and name for persistence; the OS joypad index is only valid for
## the current connection and is never saved.

enum Kind { NONE, KEYBOARD_LEFT, KEYBOARD_RIGHT, GAMEPAD }

var kind: Kind = Kind.NONE
## Current OS joypad index; -1 for keyboards and disconnected pads.
var joy_id: int = -1
var guid: String = ""
var device_name: String = ""


static func keyboard_left() -> DeviceSource:
	var source := DeviceSource.new()
	source.kind = Kind.KEYBOARD_LEFT
	source.device_name = "Keyboard (left side: WASD)"
	return source


static func keyboard_right() -> DeviceSource:
	var source := DeviceSource.new()
	source.kind = Kind.KEYBOARD_RIGHT
	source.device_name = "Keyboard (right side: arrows)"
	return source


static func gamepad(id: int) -> DeviceSource:
	var source := DeviceSource.new()
	source.kind = Kind.GAMEPAD
	source.joy_id = id
	source.guid = Input.get_joy_guid(id)
	source.device_name = Input.get_joy_name(id)
	if source.device_name.is_empty():
		source.device_name = "Gamepad %d" % id
	return source


func is_gamepad() -> bool:
	return kind == Kind.GAMEPAD


func is_keyboard() -> bool:
	return kind == Kind.KEYBOARD_LEFT or kind == Kind.KEYBOARD_RIGHT


## Two sources conflict when a single physical device would drive both slots.
func conflicts_with(other: DeviceSource) -> bool:
	if other == null or kind == Kind.NONE or other.kind == Kind.NONE:
		return false
	if is_gamepad() and other.is_gamepad():
		return joy_id == other.joy_id
	return kind == other.kind


## Persistent identity used by settings; never includes the OS index.
func identity() -> Dictionary:
	return {"kind": Kind.keys()[kind], "guid": guid, "name": device_name}


func display_name() -> String:
	if is_gamepad():
		return "%s (pad %d)" % [device_name, joy_id]
	return device_name


func short_label() -> String:
	match kind:
		Kind.KEYBOARD_LEFT: return "KB-L"
		Kind.KEYBOARD_RIGHT: return "KB-R"
		Kind.GAMEPAD: return "PAD%d" % joy_id
	return "none"
