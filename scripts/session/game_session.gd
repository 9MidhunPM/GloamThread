class_name GameSession
extends Node
## The only owner of campaign transactions, room changes and recovery.

signal mode_changed(mode: String, owner_slot: int)
signal notice(message: String)
signal room_changed(room_id: String)

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const Action := CommandSnapshot.Action
const Quest := preload("res://scripts/session/quest_director.gd")
const DOWNED_TICKS := 720
const REVIVE_TICKS := 90

@export var room_path: String = "res://content/rooms/r00.json"
var fixture_mode: bool = false
var catalog: ContentCatalog
var progress: TeamProgress
var save_repository: SaveRepository
var continue_at_checkpoint: bool = false
var presentation: SplitPresentation
var room: Room
var players: Array[PlayerController] = []
var enemies: Array[CombatEnemy] = []
var mover: DiagnosticMover
var startup_error: String = ""
var last_save_error: String = ""
var session_ready: bool = false
var mode: String = "playing"
var owner_slot: int = 0
var dialogue_id: String = ""
var current_room_id: String = "r00"
var transition_count: int = 0
var recovery_count: int = 0
var pause_overlay: CanvasLayer
var interaction_hints: Array[String] = ["", ""]
var reduced_flash: bool = false
var reduced_shake: bool = false

var _transaction_pending: bool = false
var _latches: Dictionary = {}
var _damaged_slots: Dictionary = {}
var _hazards: Array[Rect2] = []
var _ending_presented: bool = false
var _focus_pause_enabled: bool = true


func configure(bundle: ContentCatalog, team: TeamProgress, saves: SaveRepository = null, continuing: bool = false) -> void:
	catalog = bundle
	progress = team
	save_repository = saves
	continue_at_checkpoint = continuing


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100
	presentation = $Presentation as SplitPresentation
	if progress == null:
		progress = TeamProgress.new()
	if not fixture_mode and catalog == null:
		catalog = ContentCatalog.load_bundle()
	if not fixture_mode and not catalog.errors.is_empty():
		startup_error = "\n".join(catalog.errors)
		return
	if not fixture_mode and not AudioDirector.register_bundle(catalog.assets):
		startup_error = "Audio data could not load."
		return
	var initial_room := "r00"
	var initial_entrance := "start"
	if continue_at_checkpoint and not fixture_mode:
		initial_room = str(catalog.world.checkpoints[progress.checkpoint_id])
		initial_entrance = progress.checkpoint_id
	if not _load_room(initial_room, initial_entrance, true):
		return
	InputRouter.device_lost.connect(_on_device_lost)
	session_ready = true
	request_mode("playing", 0)


func _physics_process(_delta: float) -> void:
	if not session_ready or _transaction_pending:
		return
	if mode == "playing":
		var pause_owner := InputRouter.who_just_pressed(Action.PAUSE)
		var map_owner := InputRouter.who_just_pressed(Action.MAP)
		if pause_owner >= 0:
			request_mode("pause", pause_owner)
		elif map_owner >= 0:
			request_mode("map", map_owner)
	if mode != "playing" or get_tree().paused:
		return
	_process_hazards()
	_process_revival()
	if _transaction_pending:
		return
	_process_interactions()
	_damaged_slots.clear()
	presentation.update_hud(players, objective(), interaction_hints, boss(), progress, local_targets())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and session_ready and _focus_pause_enabled and mode == "playing":
		request_mode("pause", owner_slot)


func request_mode(value: String, requester: int = 0) -> void:
	if value not in ["playing", "pause", "map", "dialogue", "reconnect", "ending", "transition", "recovery", "settings"]:
		return
	mode = value
	owner_slot = clampi(requester, 0, 1)
	get_tree().paused = value != "playing"
	InputRouter.flush()
	mode_changed.emit(mode, owner_slot)


## UI calls this only after the complete authored sequence has been shown.
func complete_dialogue() -> bool:
	if mode != "dialogue":
		return false
	if dialogue_id == "oru_intro":
		_commit_flags(["met_oru"])
	dialogue_id = ""
	request_mode("playing", owner_slot)
	_refresh_hud()
	return true


func set_paused(value: bool) -> void:
	request_mode("pause" if value else "playing", owner_slot)


func _on_device_lost(slot: int, _source: DeviceSource) -> void:
	if session_ready:
		request_mode("reconnect", 1 - slot)


func _load_room(room_id: String, entrance: String, restore_health: bool) -> bool:
	var definition: RoomDefinition
	if fixture_mode:
		definition = RoomDefinition.load_from_path(room_path)
	else:
		definition = catalog.room(room_id)
	if definition == null or not definition.is_valid():
		startup_error = "Room data could not load: %s" % room_id
		return false
	var positions := definition.spawn_positions(entrance)
	if positions.size() != 2:
		startup_error = "Missing paired room entrance: %s/%s" % [room_id, entrance]
		return false
	var next_room := Room.build(definition, not fixture_mode, catalog.assets if catalog != null else null, progress.flags)
	_clear_encounter()
	if is_instance_valid(room):
		if is_instance_valid(room.entity_visuals) and not room.is_ancestor_of(room.entity_visuals):
			room.entity_visuals.free()
		room.free()
	room = next_room
	presentation.room_slot.add_child(room)
	room.entity_visuals.reparent(presentation.actors)
	current_room_id = definition.id
	_latches.clear()
	_hazards.clear()
	for y in definition.height:
		for x in definition.width:
			if definition.is_hazard(Vector2i(x, y)):
				_hazards.append(Rect2(x * 16, y * 16, 16, 16))
	if players.is_empty():
		for index in 2:
			var player := PLAYER_SCENE.instantiate() as PlayerController
			player.name = "Courier%d" % (index + 1)
			player.slot_index = index
			var profile: Dictionary = {"id": progress.profile_ids[index], "max_hearts": 5 if index == 0 else 4,
				"special_id": "ember_arc" if index == 0 else "spore_bolt"}
			if catalog != null:
				profile = catalog.profiles[progress.profile_ids[index]]
			player.configure(profile, catalog.assets if catalog != null else null, progress)
			player.position = positions[index]
			player.room_bounds = room.bounds()
			player.reduced_flash = reduced_flash
			player.damage_received.connect(_on_player_damage)
			presentation.actors.add_child(player)
			players.append(player)
	for index in 2:
		players[index].set_room_context(room.bounds(), room.can_stand_at, room.can_threadstep, room.water_body)
		if restore_health:
			players[index].restore(positions[index])
		else:
			players[index].reset_at(positions[index])
	for entity: Dictionary in definition.entities:
		var type := str(entity.type)
		if type in ["spoolmite", "wickwing", "spoolwarden"]:
			if type == "spoolwarden" and progress.has_flag("boss_spoolwarden"):
				continue
			var enemy := CombatEnemy.new()
			enemy.name = str(entity.id)
			enemy.position = _feet(entity.tile)
			enemy.configure(type, players, catalog.assets if catalog != null else null, room.bounds())
			enemy.defeated.connect(_on_enemy_defeated)
			presentation.actors.add_child(enemy)
			enemy.set_room_context(room.bounds(), room.can_stand_at, room.can_threadstep, room.water_body)
			enemies.append(enemy)
		elif type == "checkpoint" and str(entity.checkpoint_id) == progress.checkpoint_id:
			room.set_entity_state(str(entity.id), "checkpoint_lit")
	presentation.follow_players(players, room.bounds())
	if catalog != null:
		presentation.set_themes(catalog.assets, str(catalog.profiles[progress.profile_ids[0]].theme_id), str(catalog.profiles[progress.profile_ids[1]].theme_id))
	progress.visit(current_room_id)
	if not fixture_mode:
		AudioDirector.play_music("ending" if progress.has_flag("loom_restored") else ("boss" if room_id == "r05" and not progress.has_flag("boss_spoolwarden") else "exploration"))
	_apply_charms()
	interaction_hints.assign(["", ""])
	_refresh_hud()
	room_changed.emit(current_room_id)
	return true


func _clear_encounter() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.free()
	enemies.clear()
	if is_instance_valid(mover):
		mover.free()
	mover = null
	for node in get_tree().get_nodes_in_group("combat_transients"):
		if is_ancestor_of(node):
			node.free()
	_damaged_slots.clear()


func _on_player_damage(player: PlayerController) -> void:
	_damaged_slots[player.slot_index] = true


func _process_hazards() -> void:
	for player in players:
		if player.downed:
			continue
		var body := player.hurt_rect()
		for hazard in _hazards:
			if body.intersects(hazard):
				var away := body.get_center() - hazard.get_center()
				if away.is_zero_approx():
					away = -player.facing_vector
				player.take_hit(1, away.normalized() * 60.0)
				break


func _process_revival() -> void:
	for index in 2:
		var downed_player := players[index]
		if not downed_player.downed:
			continue
		var rescuer := players[1 - index]
		var can_revive := not rescuer.downed and rescuer.global_position.distance_to(downed_player.global_position) <= 40.0
		can_revive = can_revive and InputRouter.snapshot(1 - index).is_held(Action.INTERACT) and not _damaged_slots.has(1 - index)
		if can_revive:
			downed_player.revive_progress_ticks += 1
		else:
			downed_player.revive_progress_ticks = 0
		if downed_player.revive_progress_ticks >= REVIVE_TICKS:
			downed_player.revive()
	for player in players:
		if player.downed:
			player.downed_ticks += 1
	if players[0].downed and players[1].downed:
		request_recovery("Both couriers are down")
		return
	for player in players:
		if player.downed and player.downed_ticks >= DOWNED_TICKS:
			request_recovery("The thread needs a checkpoint")
			return


func _process_interactions() -> void:
	interaction_hints.assign(["", ""])
	for entity: Dictionary in room.definition.entities:
		if entity.type == "secret" and not progress.has_flag(str(entity.flag)):
			for player in players:
				if not player.downed and player.position.distance_to(_feet(entity.tile)) < 28.0:
					if _commit_flags([str(entity.flag)]):
						AudioDirector.play_cue("checkpoint")
						notice.emit("Lantern charm found. Both couriers carry its light.")
						_apply_charms()
					break
	for slot in 2:
		var player := players[slot]
		if player.downed:
			continue
		var partner := players[1 - slot]
		if partner.downed and player.position.distance_to(partner.position) <= 40.0:
			interaction_hints[slot] = "Hold Interact to revive your partner"
			continue
		var pressed := InputRouter.snapshot(slot).just_pressed(Action.INTERACT)
		for entity: Dictionary in room.definition.entities:
			match str(entity.type):
				"exit":
					if _tile_rect(entity.rect).has_point(player.position):
						var open := true
						for flag: String in entity.requires_all:
							open = open and progress.has_flag(flag)
						if open:
							interaction_hints[slot] = "Both couriers: rally here, then Interact"
						else:
							interaction_hints[slot] = _locked_hint(entity.requires_all)
						if pressed:
							request_transition(str(entity.id), slot)
							return
				"checkpoint", "npc":
					if player.position.distance_to(_feet(entity.tile)) <= 40.0:
						interaction_hints[slot] = "Interact: checkpoint" if entity.type == "checkpoint" else "Interact: talk to Oru"
						if pressed:
							if entity.type == "checkpoint":
								_activate_checkpoint(entity)
							else:
								dialogue_id = str(entity.restored_dialogue_id if progress.has_flag("loom_restored") else entity.dialogue_id)
								request_mode("dialogue", slot)
							return
				"anchor_pair", "loom":
					var flag := str(entity.flag)
					if progress.has_flag(flag):
						continue
					var points: Array = entity.anchors if entity.type == "anchor_pair" else entity.stations
					for point: Dictionary in points:
						if player.position.distance_to(_feet(point.tile)) <= 36.0:
							var held: Dictionary = _latches.get(flag, {})
							interaction_hints[slot] = "Your end is held. Your partner takes the other." if held.has(point.id) else "Interact: hold this end; partner takes the other"
							if pressed:
								_latch(entity, point, slot)
								# Both owned edges may latch in one tick; do not discard P2.
								break


func _activate_checkpoint(entity: Dictionary) -> void:
	progress.set_checkpoint(str(entity.checkpoint_id))
	for player in players:
		player.restore(player.position)
	room.set_entity_state(str(entity.id), "checkpoint_lit")
	AudioDirector.play_cue("checkpoint")
	_save()
	notice.emit("Checkpoint lit. Both couriers are restored.")


func _latch(entity: Dictionary, point: Dictionary, slot: int) -> void:
	var flag := str(entity.flag)
	var latch: Dictionary = _latches.get(flag, {})
	if latch.has(point.id):
		return
	if slot in latch.values():
		notice.emit("Your partner must take the other end.")
		return
	latch[point.id] = slot
	_latches[flag] = latch
	room.set_entity_state(str(point.id), "anchor_latched" if entity.type == "anchor_pair" else "loom_lit")
	AudioDirector.play_cue("anchor_latched")
	if latch.size() == 2:
		_commit_flags([flag])
		room.set_progress(progress.flags)
		if entity.type == "anchor_pair":
			room.restore_bridge(flag)
			AudioDirector.play_cue("bridge_restored")
		else:
			AudioDirector.play_cue("loom_restored")
			AudioDirector.play_music("ending")
			dialogue_id = "ending"
			request_mode("dialogue", slot)


func request_transition(exit_id: String, requester: int = 0) -> bool:
	if _transaction_pending or mode != "playing":
		return false
	var exit: Dictionary = {}
	for entity: Dictionary in room.definition.entities:
		if entity.type == "exit" and entity.id == exit_id:
			exit = entity
	if exit.is_empty():
		return false
	for flag: String in exit.requires_all:
		if not progress.has_flag(flag):
			notice.emit("This path needs %s." % flag.replace("_", " "))
			return false
	for player in players:
		if player.downed or not _tile_rect(exit.rect).has_point(player.position):
			notice.emit("Both living couriers must rally at the exit.")
			return false
	if catalog == null:
		notice.emit("Fixture route: no campaign destination is loaded.")
		return false
	var destination := catalog.room(str(exit.target_room))
	if destination == null or not destination.is_valid() or destination.spawn_positions(str(exit.target_entrance)).size() != 2:
		notice.emit("The destination could not load. The current room is safe.")
		return false
	_transaction_pending = true
	request_mode("transition", requester)
	_perform_transition.call_deferred(str(exit.target_room), str(exit.target_entrance))
	return true


func _perform_transition(room_id: String, entrance: String) -> void:
	var loaded := _load_room(room_id, entrance, false)
	_transaction_pending = false
	if not loaded:
		notice.emit(startup_error)
		request_mode("pause", owner_slot)
		return
	transition_count += 1
	_save()
	_apply_charms()
	if room_id == "r00" and progress.has_flag("loom_restored") and not _ending_presented:
		_ending_presented = true
		request_mode("ending", owner_slot)
	else:
		request_mode("playing", owner_slot)


func request_recovery(reason: String = "Checkpoint recovery") -> void:
	if _transaction_pending:
		return
	_transaction_pending = true
	request_mode("recovery", owner_slot)
	_perform_recovery.call_deferred(reason)


func _perform_recovery(reason: String) -> void:
	var room_id := "r00" if fixture_mode else str(catalog.world.checkpoints[progress.checkpoint_id])
	var entrance := "start" if fixture_mode else progress.checkpoint_id
	var restored := _load_room(room_id, entrance, true)
	_transaction_pending = false
	recovery_count += 1
	request_mode("playing" if restored else "pause", owner_slot)
	notice.emit(reason if restored else startup_error)
	_apply_charms()


func _on_enemy_defeated(enemy: CombatEnemy) -> void:
	if enemy.kind == "spoolwarden":
		_commit_flags(["boss_spoolwarden", "threadstep", "shortcut_bell"])
		AudioDirector.play_music("exploration")
		notice.emit("Threadstep unlocked for both couriers. Dash opens the old path.")


func _commit_flags(flags: Array[String]) -> bool:
	if not progress.commit_flags(flags):
		return false
	if is_instance_valid(room):
		room.set_progress(progress.flags)
	_save()
	return true


func _save() -> void:
	if save_repository == null or fixture_mode:
		return
	var result := save_repository.save_campaign(progress.to_save())
	last_save_error = "" if result.ok else str(result.message)
	if not result.ok:
		notice.emit(last_save_error)


func save_now() -> void:
	if save_repository == null or fixture_mode:
		return
	var result := save_repository.save_campaign(progress.to_save())
	last_save_error = "" if result.ok else str(result.message)
	notice.emit("Checkpoint progress saved." if result.ok else last_save_error)


func _apply_charms() -> void:
	if catalog == null or not progress.has_flag("lantern_charm"):
		return
	for player in players:
		if player.has_node("LanternCharm"):
			continue
		var charm := Sprite2D.new()
		charm.name = "LanternCharm"
		charm.texture = catalog.assets.frame_texture("ui_v1", 16)
		charm.scale = Vector2(0.5, 0.5)
		charm.position = Vector2(8, -28)
		charm.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		player.add_child(charm)


func guidance() -> Dictionary:
	if catalog == null:
		return {"text": "Geometry fixture: campaign guidance unavailable", "reachable": false}
	return Quest.describe(progress, current_room_id, catalog.world)


func local_targets() -> Array[Dictionary]:
	if not is_instance_valid(room):
		return []
	return Quest.local_targets(room.definition, guidance())


func objective() -> String:
	return str(guidance().get("text", ""))


func _refresh_hud() -> void:
	if is_instance_valid(presentation):
		presentation.update_hud(players, objective(), interaction_hints, boss(), progress, local_targets())


func _locked_hint(required: Array) -> String:
	if "met_oru" in required and not progress.has_flag("met_oru"):
		return "Meet Oru before leaving Lantern Rest"
	if "threadstep" in required and not progress.has_flag("threadstep"):
		return "Threadstep locked: free the bell first"
	if "loom_restored" in required and not progress.has_flag("loom_restored"):
		return "Restore the Lantern Loom to open this path"
	if "shortcut_bell" in required and not progress.has_flag("shortcut_bell"):
		return "The bell shortcut is still sealed"
	return "Both anchors must be restored to open this path"


func boss() -> CombatEnemy:
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.kind == "spoolwarden" and not enemy.dead:
			return enemy
	return null


static func _feet(tile: Array) -> Vector2:
	return RoomDefinition.feet_position(Vector2i(int(tile[0]), int(tile[1])))


static func _centre(tile: Array) -> Vector2:
	return RoomDefinition.tile_center(Vector2i(int(tile[0]), int(tile[1])))


static func _tile_rect(rect: Array) -> Rect2:
	return Rect2(float(rect[0]) * 16, float(rect[1]) * 16, float(rect[2]) * 16, float(rect[3]) * 16)
