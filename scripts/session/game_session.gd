class_name GameSession
extends Node
## Session ownership, including pause, stays above the pausable world subtree.

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")

@export var room_path: String = "res://content/rooms/r00.json"
## Only engine scenarios opt in; normal startup never substitutes test content.
var fixture_mode: bool = false
var presentation: SplitPresentation
var room: Room
var players: Array[PlayerController] = []
var mover: DiagnosticMover
var startup_error: String = ""
var session_ready: bool = false
var pause_overlay: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	presentation = $Presentation as SplitPresentation
	var definition := RoomDefinition.load_from_path(room_path)
	if not definition.is_valid():
		startup_error = "\n".join(definition.errors)
		return
	var textures: Array[Texture2D] = []
	if not fixture_mode:
		var catalog := AssetCatalog.load_from_path("res://assets/manifest.json")
		if catalog.errors.is_empty():
			textures.append(catalog.frame_texture("fixed_tavi_v1"))
			textures.append(catalog.frame_texture("fixed_neri_v1"))
		if not catalog.errors.is_empty():
			startup_error = "\n".join(catalog.errors)
			return
		if not FileAccess.file_exists(GrayboxSkin.DIAG_TILES):
			startup_error = "Diagnostic terrain is missing"
			return
	room = Room.build(definition, not fixture_mode)
	presentation.room_slot.add_child(room)
	var positions := definition.spawn_positions("start")
	if positions.size() != 2:
		startup_error = "The start entrance must contain two safe spawns"
		return
	for index in 2:
		var player := PLAYER_SCENE.instantiate() as PlayerController
		player.name = "Tavi" if index == 0 else "Neri"
		player.slot_index = index
		player.profile_id = "tavi_fixed" if index == 0 else "neri_fixed"
		if not fixture_mode:
			player.sprite_texture = textures[index]
		player.position = positions[index]
		presentation.actors.add_child(player)
		players.append(player)
	for entity: Dictionary in definition.entities:
		if entity.get("type") == "diagnostic_mover":
			if mover != null:
				startup_error = "The tracer accepts exactly one diagnostic mover"
				return
			mover = DiagnosticMover.new()
			mover.name = str(entity["id"])
			mover.origin_position = RoomDefinition.feet_position(Vector2i(entity["tile"][0], entity["tile"][1]))
			mover.position = mover.origin_position
			mover.range_pixels = float(entity.get("range_tiles", 6)) * RoomDefinition.TILE
			if not fixture_mode:
				mover.sprite_texture = load("res://assets/generated/diagnostic/mover_diag.png") as Texture2D
			presentation.actors.add_child(mover)
	presentation.follow_players(players, room.bounds())
	_make_pause_overlay()
	session_ready = true


func _physics_process(_delta: float) -> void:
	if not session_ready:
		return
	if InputRouter.any_just_pressed(CommandSnapshot.Action.PAUSE):
		set_paused(not get_tree().paused)
	presentation.update_hud(players)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and session_ready:
		set_paused(true)


func set_paused(value: bool) -> void:
	get_tree().paused = value
	InputRouter.flush()
	if pause_overlay != null:
		pause_overlay.visible = value


func _make_pause_overlay() -> void:
	pause_overlay = CanvasLayer.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.layer = 10
	var shade := ColorRect.new()
	shade.size = Vector2(960, 360)
	shade.color = Color(0.04, 0.06, 0.09, 0.8)
	pause_overlay.add_child(shade)
	var label := Label.new()
	label.text = "Paused\nPress your pause key to resume"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(260, 150)
	label.size = Vector2(440, 60)
	pause_overlay.add_child(label)
	add_child(pause_overlay)
	pause_overlay.visible = false
