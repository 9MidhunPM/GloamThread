extends Node
## Autoload: owns device-to-player assignment and produces one CommandSnapshot
## per joined slot per physics tick.
##
## Rules (docs/ARCHITECTURE.md §6, AGENTS.md): one device owns at most one slot,
## gameplay never reads Input directly, held actions are flushed when entering
## or leaving menus, and a lost device is reported so the session can pause.
## Scenario tests inject synthetic state through [method set_test_input].

signal slot_assigned(slot_index: int, source: DeviceSource)
signal slot_cleared(slot_index: int)
## An assigned gamepad disappeared; the session must pause and offer reassignment.
signal device_lost(slot_index: int, source: DeviceSource)
## A gamepad with the same identity as a lost assignment reconnected (resume stays deliberate).
signal device_returned(slot_index: int, source: DeviceSource)
signal joypad_list_changed()

const SLOT_COUNT := 2
const Action := CommandSnapshot.Action
## Actions suppressed by a flush until the player physically releases them.
const LATCHABLE_MASK: int = Action.LEFT | Action.RIGHT | Action.UP | Action.DOWN | Action.JUMP | Action.ATTACK | Action.SPECIAL | Action.INTERACT | Action.DASH | Action.PAUSE | Action.MAP


class PlayerSlot:
	var index: int
	var source: DeviceSource = null
	var bindings: Bindings = null
	var snapshot: CommandSnapshot = CommandSnapshot.empty()
	var held_before: int = 0
	var latched: int = 0
	## Set while an assigned gamepad is disconnected.
	var waiting_for_device: bool = false
	## Scenario override: {"held": int, "x": float, "y": float} or empty.
	var test_input: Dictionary = {}

	func _init(slot_index: int) -> void:
		index = slot_index

	func is_joined() -> bool:
		return source != null and source.kind != DeviceSource.Kind.NONE


var _slots: Array[PlayerSlot] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SLOT_COUNT:
		_slots.append(PlayerSlot.new(i))
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _physics_process(_delta: float) -> void:
	for slot in _slots:
		_poll_slot(slot)


# --- assignment -------------------------------------------------------------

func slot_count() -> int:
	return SLOT_COUNT


func is_joined(slot_index: int) -> bool:
	return _slots[slot_index].is_joined()


func joined_slots() -> Array[int]:
	var out: Array[int] = []
	for slot in _slots:
		if slot.is_joined():
			out.append(slot.index)
	return out


func source_of(slot_index: int) -> DeviceSource:
	return _slots[slot_index].source


func bindings_of(slot_index: int) -> Bindings:
	return _slots[slot_index].bindings


func is_waiting_for_device(slot_index: int) -> bool:
	return _slots[slot_index].waiting_for_device


## Claims [param source] for [param slot_index]. Fails if another slot already
## owns the same physical device, so one controller can never drive both players.
func assign(slot_index: int, source: DeviceSource, bindings: Bindings = null) -> Error:
	if slot_index < 0 or slot_index >= SLOT_COUNT or source == null or source.kind == DeviceSource.Kind.NONE:
		return ERR_INVALID_PARAMETER
	if bindings != null and bindings.kind != source.kind:
		return ERR_INVALID_PARAMETER
	for other in _slots:
		if other.index != slot_index and other.source != null and other.source.conflicts_with(source):
			push_warning("InputRouter: %s already belongs to player %d" % [source.display_name(), other.index + 1])
			return ERR_ALREADY_IN_USE
	var slot := _slots[slot_index]
	slot.source = source
	slot.bindings = bindings if bindings != null else Bindings.defaults_for(source.kind)
	slot.waiting_for_device = false
	flush(slot_index)
	slot_assigned.emit(slot_index, source)
	return OK


func clear(slot_index: int) -> void:
	var slot := _slots[slot_index]
	slot.source = null
	slot.bindings = null
	slot.waiting_for_device = false
	slot.snapshot = CommandSnapshot.empty()
	slot.held_before = 0
	slot.latched = 0
	slot_cleared.emit(slot_index)


func set_bindings(slot_index: int, bindings: Bindings) -> void:
	if bindings == null or _slots[slot_index].source == null or bindings.kind != _slots[slot_index].source.kind:
		push_warning("InputRouter: bindings must match the assigned device kind")
		return
	_slots[slot_index].bindings = bindings
	flush(slot_index)


## Lists sources that are not currently owned by another slot.
func available_sources(for_slot: int = -1) -> Array[DeviceSource]:
	var candidates: Array[DeviceSource] = [DeviceSource.keyboard_left(), DeviceSource.keyboard_right()]
	for id: int in Input.get_connected_joypads():
		candidates.append(DeviceSource.gamepad(id))
	var out: Array[DeviceSource] = []
	for candidate in candidates:
		var taken := false
		for slot in _slots:
			if slot.index != for_slot and slot.source != null and slot.source.conflicts_with(candidate):
				taken = true
		if not taken:
			out.append(candidate)
	return out


# --- snapshots --------------------------------------------------------------

## The snapshot produced for this physics tick (neutral for unjoined slots).
func snapshot(slot_index: int) -> CommandSnapshot:
	return _slots[slot_index].snapshot


## True when any joined slot just pressed [param action] this tick.
func any_just_pressed(action: Action) -> bool:
	for slot in _slots:
		if slot.is_joined() and slot.snapshot.just_pressed(action):
			return true
	return false


## Returns the first joined slot that just pressed [param action], or -1.
func who_just_pressed(action: Action) -> int:
	for slot in _slots:
		if slot.is_joined() and slot.snapshot.just_pressed(action):
			return slot.index
	return -1


## Drops stale edges and suppresses currently held buttons until released.
## Call when entering or leaving menus, pausing, or (re)assigning a device.
func flush(slot_index: int = -1) -> void:
	for slot in _slots:
		if slot_index != -1 and slot.index != slot_index:
			continue
		var raw := _raw_held(slot)
		slot.latched = raw & LATCHABLE_MASK
		slot.held_before = raw & ~slot.latched
		slot.snapshot = CommandSnapshot.empty()


# --- scenario seam ------------------------------------------------------------

## Overrides the physical device for [param slot_index] with synthetic state.
## [param held] is an Action bitmask; movement axes derive from LEFT/RIGHT/UP/DOWN
## unless explicit values are given. Pass [code]{}[/code] to remove the override.
func set_test_input(slot_index: int, held: int, move_x: float = NAN, move_y: float = NAN) -> void:
	var slot := _slots[slot_index]
	slot.test_input = {"held": held, "x": move_x, "y": move_y}


func clear_test_input(slot_index: int = -1) -> void:
	for slot in _slots:
		if slot_index == -1 or slot.index == slot_index:
			slot.test_input = {}


# --- polling ------------------------------------------------------------------

func _poll_slot(slot: PlayerSlot) -> void:
	if not slot.is_joined() or slot.waiting_for_device:
		slot.snapshot = CommandSnapshot.empty()
		slot.held_before = 0
		return
	var raw := _raw_held(slot)
	slot.latched &= raw
	var held := raw & ~slot.latched
	var axis := _axes(slot, held)
	slot.snapshot = CommandSnapshot.from_state(axis.x, axis.y, held, slot.held_before)
	slot.held_before = held


func _raw_held(slot: PlayerSlot) -> int:
	if slot.source == null or slot.bindings == null or slot.waiting_for_device:
		return 0
	if not slot.test_input.is_empty():
		return int(slot.test_input["held"])
	var held := 0
	if slot.source.is_gamepad():
		for action: Action in CommandSnapshot.ALL_ACTIONS:
			if _pad_action_held(slot, action):
				held |= action
	else:
		for action: Action in CommandSnapshot.ALL_ACTIONS:
			for key: Variant in slot.bindings.keys_for(action):
				if Input.is_physical_key_pressed(key as Key):
					held |= action
					break
	return held


func _pad_action_held(slot: PlayerSlot, action: Action) -> bool:
	return _pad_action_strength(slot, action) > 0.0


func _pad_action_strength(slot: PlayerSlot, action: Action) -> float:
	var id := slot.source.joy_id
	var strength := 0.0
	for control: Dictionary in slot.bindings.pad_controls_for(action):
		if control.has("button"):
			if Input.is_joy_button_pressed(id, control["button"] as JoyButton):
				return 1.0
		elif control.has("axis"):
			var value := Input.get_joy_axis(id, control["axis"] as JoyAxis)
			var sign := int(control.get("sign", 1))
			if value * sign > slot.bindings.deadzone:
				strength = maxf(strength, value * sign)
	return strength


func _axes(slot: PlayerSlot, held: int) -> Vector2:
	var axis := Vector2.ZERO
	if not slot.test_input.is_empty():
		var x: float = slot.test_input["x"]
		var y: float = slot.test_input["y"]
		axis.x = x if not is_nan(x) else _digital_axis(held, Action.LEFT, Action.RIGHT)
		axis.y = y if not is_nan(y) else _digital_axis(held, Action.UP, Action.DOWN)
		return axis
	if slot.source.is_gamepad() and not slot.waiting_for_device:
		# Held-axis input obeys the same release latch as digital controls.
		# Polling raw strengths here would bypass flush() on menu/reconnect.
		if held & Action.RIGHT:
			axis.x += _pad_action_strength(slot, Action.RIGHT)
		if held & Action.LEFT:
			axis.x -= _pad_action_strength(slot, Action.LEFT)
		if held & Action.DOWN:
			axis.y += _pad_action_strength(slot, Action.DOWN)
		if held & Action.UP:
			axis.y -= _pad_action_strength(slot, Action.UP)
		return axis.limit_length(1.0)
	axis.x = _digital_axis(held, Action.LEFT, Action.RIGHT)
	axis.y = _digital_axis(held, Action.UP, Action.DOWN)
	return axis


static func _digital_axis(held: int, negative: Action, positive: Action) -> float:
	var value := 0.0
	if held & negative:
		value -= 1.0
	if held & positive:
		value += 1.0
	return value


# --- hotplug -------------------------------------------------------------------

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	joypad_list_changed.emit()
	if connected:
		_reconnect_device(device, Input.get_joy_guid(device), Input.get_joy_name(device))
		return
	for slot in _slots:
		if slot.source == null or not slot.source.is_gamepad():
			continue
		if slot.source.joy_id == device and not slot.waiting_for_device:
			slot.waiting_for_device = true
			slot.source.joy_id = -1
			flush(slot.index)
			device_lost.emit(slot.index, slot.source)


func _reconnect_device(device: int, guid: String, device_name: String) -> void:
	# A repeated notification or a second identical pad must not steal an
	# already claimed OS index from the other player's live assignment.
	for owner in _slots:
		if owner.source != null and owner.source.is_gamepad() and not owner.waiting_for_device and owner.source.joy_id == device:
			return
	for slot in _slots:
		if slot.source == null or not slot.source.is_gamepad():
			continue
		if slot.waiting_for_device and guid == slot.source.guid and device_name == slot.source.device_name:
			slot.source.joy_id = device
			slot.waiting_for_device = false
			flush(slot.index)
			device_returned.emit(slot.index, slot.source)
			# GUID/name identify a model, not an individual controller. Claim
			# only one waiting slot; other identical pads remain disconnected.
			return
