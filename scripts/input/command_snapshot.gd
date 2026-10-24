class_name CommandSnapshot
extends RefCounted
## Immutable per-physics-tick command state for one player slot.
##
## Gameplay code reads these snapshots and never touches Input directly, so one
## device can only ever drive one player (docs/ARCHITECTURE.md §6).

enum Action {
	LEFT = 1,
	RIGHT = 2,
	UP = 4,
	DOWN = 8,
	JUMP = 16,
	ATTACK = 32,
	SPECIAL = 64,
	INTERACT = 128,
	DASH = 256,
	PAUSE = 512,
	MAP = 1024,
}

const ALL_ACTIONS: Array[Action] = [
	Action.LEFT, Action.RIGHT, Action.UP, Action.DOWN, Action.JUMP, Action.ATTACK,
	Action.SPECIAL, Action.INTERACT, Action.DASH, Action.PAUSE, Action.MAP,
]

## Horizontal axis in [-1, 1]; digital bindings produce -1/0/1, sticks produce analogue values.
var move_x: float = 0.0
## Vertical axis in [-1, 1]; negative is up.
var move_y: float = 0.0
## Bitmask of actions held during this tick.
var held: int = 0
## Bitmask of actions that became held this tick.
var pressed: int = 0
## Bitmask of actions that stopped being held this tick.
var released: int = 0


static func empty() -> CommandSnapshot:
	return CommandSnapshot.new()


static func from_state(axis_x: float, axis_y: float, held_now: int, held_before: int) -> CommandSnapshot:
	var snapshot := CommandSnapshot.new()
	snapshot.move_x = clampf(axis_x, -1.0, 1.0)
	snapshot.move_y = clampf(axis_y, -1.0, 1.0)
	snapshot.held = held_now
	snapshot.pressed = held_now & ~held_before
	snapshot.released = held_before & ~held_now
	return snapshot


func is_held(action: Action) -> bool:
	return (held & action) != 0


func just_pressed(action: Action) -> bool:
	return (pressed & action) != 0


func just_released(action: Action) -> bool:
	return (released & action) != 0


func is_neutral() -> bool:
	return held == 0 and pressed == 0 and released == 0 and is_zero_approx(move_x) and is_zero_approx(move_y)


static func action_name(action: Action) -> String:
	match action:
		Action.LEFT: return "left"
		Action.RIGHT: return "right"
		Action.UP: return "up"
		Action.DOWN: return "down"
		Action.JUMP: return "jump"
		Action.ATTACK: return "attack"
		Action.SPECIAL: return "special"
		Action.INTERACT: return "interact"
		Action.DASH: return "dash"
		Action.PAUSE: return "pause"
		Action.MAP: return "map"
	return "unknown"


static func action_from_name(name: String) -> int:
	for action: Action in ALL_ACTIONS:
		if action_name(action) == name:
			return action
	return 0
