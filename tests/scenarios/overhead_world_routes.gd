extends Scenario
## Authored route connectivity and actual water-only collision probes. This does
## not replace an ordinary-input campaign run with the integrated actor/session.

const Foundation = preload("res://tests/scenarios/overhead_world_foundation.gd")
var rooms: Dictionary = {}


func run() -> void:
	for index in 8:
		var id := "r%02d" % index
		var definition := RoomDefinition.load_from_path("res://content/rooms/%s.json" % id)
		assert_true(definition.is_valid(), "%s overhead geometry validates: %s" % [id,str(definition.errors)])
		if not definition.is_valid(): return
		rooms[id] = Room.build(definition,false)
		for pair: Array in definition.spawns.values():
			for tile: Vector2i in pair:
				assert_true(rooms[id].can_stand_at(RoomDefinition.feet_position(tile)),"%s paired entrance fits its entire footprint" % id)
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/world.json"))
	var edges := {}
	for edge: Dictionary in world.connections:
		edges[_edge_key(edge.a,edge.b)] = edge.requires_all
	var directed := {}
	for id: String in rooms:
		for entity: Dictionary in rooms[id].definition.entities:
			if entity.type != "exit": continue
			assert_true(rooms.has(entity.target_room),"exit target resolves")
			assert_true(rooms[entity.target_room].definition.spawns.has(entity.target_entrance),"cross-room entrance resolves without fallback")
			assert_eq(entity.requires_all,edges[_edge_key(id,entity.target_room)],"room exit gate matches canonical world graph")
			directed[id+":"+entity.target_room]=true
	assert_eq(directed.size(),18,"all nine story connections have both rally directions")
	var atrium: Room=rooms.r01
	var start: Vector2i=atrium.definition.spawns.from_r00[0]
	var closed := _reachable(atrium,start,false)
	var open := _reachable(atrium,start,true)
	assert_true(not _reaches_exit(atrium,closed,"causeway_gate"),"Atrium's remembered branch is physically beyond dry walking")
	assert_true(_reaches_exit(atrium,open,"causeway_gate"),"Threadstep opens the remembered Atrium branch")
	assert_true(_reaches_exit(atrium,closed,"to_steps"),"the initial route toward Spindle remains dry and readable")
	for id: String in ["r02","r06"]:
		var room: Room=rooms[id]
		var origin: Vector2i=room.definition.spawns["from_r01"][0]
		var before := _reachable(room,origin,id=="r06")
		var pair: Dictionary=room.definition.entities[0]
		for anchor: Dictionary in pair.anchors:
			assert_true(before.has(Vector2i(anchor.tile[0],anchor.tile[1])),"%s has an approach to each anchor before restoration" % id)
		var far_exit := "to_gallery" if id=="r02" else "to_loom"
		assert_true(not _reaches_exit(room,before,far_exit),"%s cannot bypass its four-tile repair with ordinary movement/dash" % id)
		assert_true(room.restore_bridge(pair.flag),"%s bridge repairs its actual blocker" % id)
		var after := _reachable(room,origin,id=="r06")
		assert_true(_reaches_exit(room,after,far_exit),"%s restored route reaches the shared rally" % id)
	var gallery: Room=rooms.r03
	var gallery_paths := _reachable(gallery,gallery.definition.spawns.from_r02[0],false)
	assert_true(gallery_paths.has(Vector2i(20,5)),"the optional lantern alcove has a visible dry approach")
	assert_true(_reaches_exit(gallery,gallery_paths,"to_landing"),"Gallery has a dry route around its hazard exhibit")
	var loom: Room=rooms.r07
	var loom_paths := _reachable(loom,loom.definition.spawns.from_r06[0],false)
	for station: Dictionary in loom.definition.entities[0].stations:
		assert_true(loom_paths.has(Vector2i(station.tile[0],station.tile[1])),"both Loom stations are independently approachable")
	await _probe_gap(rooms.r01,Vector2(620,109),Vector2.RIGHT)
	await _probe_gap(rooms.r01,Vector2(626,109),Vector2.RIGHT)
	await _probe_gap(rooms.r01,Vector2(632,109),Vector2.RIGHT)
	await _probe_gap(rooms.r06,Vector2(168,145),Vector2.DOWN)
	await _probe_gap(rooms.r06,Vector2(168,151),Vector2.DOWN)
	await _probe_gap(rooms.r06,Vector2(168,157),Vector2.DOWN)
	print("OVERHEAD_WORLD_ROUTE eight rooms, eighteen exits, two forgiving dash axes, paired repairs and Loom approaches")
	for room: Room in rooms.values():
		room.free()


func _reachable(room: Room,start: Vector2i,dash: bool) -> Dictionary:
	var found := {start:true}
	var pending: Array[Vector2i]=[start]
	var at:=0
	while at<pending.size():
		var tile:=pending[at]
		at+=1
		for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next:=tile+direction
			if room.can_stand_at(RoomDefinition.feet_position(next)) and not room.definition.is_hazard(next) and not found.has(next):
				found[next]=true
				pending.append(next)
			if dash:
				var from:=RoomDefinition.feet_position(tile)
				var to:=from+Vector2(direction)*60
				var landing:=Vector2i(floori(to.x/16),floori((to.y-5)/16))
				if not found.has(landing) and not room.definition.is_hazard(landing) and room.can_threadstep(from,to):
					found[landing]=true
					pending.append(landing)
	return found


func _reaches_exit(room: Room,reachable: Dictionary,id: String) -> bool:
	for entity: Dictionary in room.definition.entities:
		if entity.type=="exit" and entity.id==id:
			var rect:=Rect2i(entity.rect[0],entity.rect[1],entity.rect[2],entity.rect[3])
			for tile: Vector2i in reachable:
				if rect.has_point(tile):return true
	return false


func _probe_gap(room: Room,from: Vector2,direction: Vector2) -> void:
	add_child(room)
	assert_true(room.can_threadstep(from,from+direction*60),"required two-tile gap accepts a forgiving launch offset")
	var probe:=Foundation.Probe.new()
	probe.position=from
	# Keep each collision probe inside its own room's transform and world.
	room.add_child(probe)
	probe.add_collision_exception_with(room.water_body)
	probe.drive=direction*300
	for index in 12:
		await get_tree().physics_frame
		await get_tree().process_frame
	probe.drive=Vector2.ZERO
	probe.remove_collision_exception_with(room.water_body)
	assert_true(room.can_stand_at(probe.position),"real sixty-pixel water-only motion lands dry")
	assert_true(probe.position.distance_to(from+direction*60)<0.2,"actual crossing preserves the fixed dash distance")
	probe.free()
	remove_child(room)


static func _edge_key(a: String,b: String) -> String:
	return a+":"+b if a<b else b+":"+a
