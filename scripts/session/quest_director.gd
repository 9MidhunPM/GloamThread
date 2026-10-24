class_name QuestDirector
extends RefCounted
## Pure campaign guidance. Queries never commit progress or create scene nodes.


static func describe(progress: TeamProgress, current_room: String, world: Dictionary) -> Dictionary:
	var stages: Array[Dictionary] = [
		{"target_flag": "met_oru", "id": "meet_oru", "title": "Find Oru", "text": "Meet Oru at Lantern Rest.", "destination_room": "r00", "target_kind": "npc"},
		{"target_flag": "bridge_spindle", "id": "restore_spindle", "title": "Take an end", "text": "Restore the paired anchors at Spindle Steps.", "destination_room": "r02", "target_kind": "anchor_pair"},
		{"target_flag": "boss_spoolwarden", "id": "free_warden", "title": "Free the bell", "text": "Release the thread held by Spoolwarden at Broken Bell.", "destination_room": "r05", "target_kind": "spoolwarden"},
		{"target_flag": "bridge_causeway", "id": "restore_causeway", "title": "Cross together", "text": "Use Threadstep to reach the paired Causeway anchors.", "destination_room": "r06", "target_kind": "anchor_pair"},
		{"target_flag": "loom_restored", "id": "restore_loom", "title": "Wake the Lantern Loom", "text": "Take one station each and restore the Loom.", "destination_room": "r07", "target_kind": "loom"},
	]
	var stage := {"target_flag": "loom_restored", "id": "return_home", "title": "Follow the light home", "text": "Return together to Lantern Rest.", "destination_room": "r00", "target_kind": "home"}
	if progress == null:
		stage = stages[0]
	else:
		for candidate: Dictionary in stages:
			if not progress.has_flag(candidate.target_flag):
				stage = candidate
				break
	var unlocked: Array[String] = []
	if progress != null:
		for flag: String in TeamProgress.FLAG_GROUPS:
			if progress.has_flag(flag):
				unlocked.append(flag)
	var route: Array[String] = []
	if progress != null:
		route = _route(current_room, stage.destination_room, world, unlocked)
	var reachable := not route.is_empty()
	var text: String = stage.text
	if not reachable:
		text = "No open route to %s. The route needs attention." % _room_name(stage.destination_room, world)
	elif stage.target_kind == "home" and current_room == stage.destination_room:
		text = "The Loom shines. You are home together."
	var description := stage.duplicate()
	description.text = text
	description.merge({"reachable": reachable, "route": route, "next_room": route[1] if route.size() > 1 else "", "unlocked_flags": unlocked})
	return description


static func local_targets(definition: RoomDefinition, description: Dictionary) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if definition == null or not description.get("reachable") is bool or not description.reachable:
		return targets
	var destination: String = str(description.get("destination_room", ""))
	var kind: String = str(description.get("target_kind", ""))
	var flag: String = str(description.get("target_flag", ""))
	if definition.id != destination:
		var next_room: String = str(description.get("next_room", ""))
		var unlocked: Array[String] = []
		var raw_flags: Variant = description.get("unlocked_flags")
		if not raw_flags is Array:
			return targets
		for value: Variant in raw_flags:
			if value is String:
				unlocked.append(value)
		for entity: Dictionary in definition.entities:
			if entity.get("type") == "exit" and entity.get("target_room") == next_room and _gate_open(entity.get("requires_all"), unlocked):
				var feet: Variant = _rally_feet(definition, entity.get("rect"))
				if feet is Vector2 and entity.get("id") is String:
					targets.append(_target(entity.id, entity.id, "exit", feet))
		return targets
	for entity: Dictionary in definition.entities:
		if entity.get("type") != kind:
			continue
		if kind == "npc" and entity.get("character_id") != "oru":
			continue
		if kind in ["anchor_pair", "loom"]:
			if entity.get("flag") != flag:
				continue
			var points: Variant = entity.get("anchors" if kind == "anchor_pair" else "stations")
			if not points is Array:
				continue
			for point: Variant in points:
				if point is Dictionary and point.get("id") is String:
					var feet: Variant = _feet(definition, point.get("tile"))
					if feet is Vector2:
						targets.append(_target(point.id, str(entity.get("id", "")), "anchor" if kind == "anchor_pair" else "station", feet))
		else:
			var feet: Variant = _feet(definition, entity.get("tile"))
			if feet is Vector2 and entity.get("id") is String:
				targets.append(_target(entity.id, entity.id, kind, feet))
	return targets


static func _target(id: String, parent_id: String, kind: String, feet: Vector2) -> Dictionary:
	return {"entity_id": id, "parent_id": parent_id, "kind": kind, "feet_position": feet}


static func _route(start: String, destination: String, world: Dictionary, unlocked: Array[String]) -> Array[String]:
	var names := _room_names(world)
	var empty: Array[String] = []
	if not names.has(start) or not names.has(destination):
		return empty
	var connections: Variant = world.get("connections")
	if not connections is Array:
		return empty
	var queue: Array[String] = [start]
	var previous := {start: ""}
	var index := 0
	while index < queue.size():
		var room_id := queue[index]
		index += 1
		if room_id == destination:
			var route: Array[String] = []
			var cursor := destination
			while not cursor.is_empty():
				route.push_front(cursor)
				cursor = previous[cursor]
			return route
		for link: Variant in connections:
			if not link is Dictionary or not link.get("a") is String or not link.get("b") is String or not _gate_open(link.get("requires_all"), unlocked):
				continue
			var neighbour: String = link.b if link.a == room_id else (link.a if link.b == room_id else "")
			if names.has(neighbour) and not previous.has(neighbour):
				previous[neighbour] = room_id
				queue.append(neighbour)
	return empty


static func _gate_open(required: Variant, unlocked: Array[String]) -> bool:
	if not required is Array:
		return false
	for flag: Variant in required:
		if not flag is String or flag not in unlocked:
			return false
	return true


static func _room_names(world: Dictionary) -> Dictionary:
	var names := {}
	var records: Variant = world.get("rooms")
	if records is Array:
		for record: Variant in records:
			if record is Dictionary and record.get("id") is String and record.id in TeamProgress.ROOM_IDS:
				names[record.id] = record.get("name", record.id)
	return names


static func _room_name(id: String, world: Dictionary) -> String:
	return str(_room_names(world).get(id, id))


static func _feet(definition: RoomDefinition, tile: Variant) -> Variant:
	if not tile is Array or tile.size() != 2 or not RoomDefinition._is_integer(tile[0]) or not RoomDefinition._is_integer(tile[1]):
		return null
	var cell := Vector2i(int(tile[0]), int(tile[1]))
	return RoomDefinition.feet_position(cell) if definition.in_bounds(cell) else null


static func _rally_feet(definition: RoomDefinition, rectangle: Variant) -> Variant:
	if not rectangle is Array or rectangle.size() != 4:
		return null
	for value: Variant in rectangle:
		if not RoomDefinition._is_integer(value):
			return null
	var rect := Rect2i(int(rectangle[0]), int(rectangle[1]), int(rectangle[2]), int(rectangle[3]))
	if not rect.has_area() or rect.position.x < 0 or rect.position.y < 0 or rect.end.x > definition.width or rect.end.y > definition.height:
		return null
	var nearest: Variant = null
	var distance := INF
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var tile := Vector2i(x, y)
			if definition.is_safe_spawn(tile):
				var feet := RoomDefinition.feet_position(tile)
				var candidate := feet.distance_squared_to((Vector2(rect.position) + Vector2(rect.size) * 0.5) * 16)
				if candidate < distance:
					distance = candidate
					nearest = feet
	return nearest
