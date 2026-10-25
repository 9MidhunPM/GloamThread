class_name ArenaMap
extends RefCounted
## Append-only authored world. Navigation never moves or duplicates actors.
const CHUNK_WIDTH := 640
const WORLD_HEIGHT := 720
const CHUNKS_PER_REGION := 4
const MAX_REGIONS := 4
const ACTOR_HALF := 9.0
const ACTOR_HEIGHT := 38.0

var bounds := Rect2()
var chunks: Array[Dictionary] = []
var platforms: Array = []
var anchors: Array[Vector2] = []
var loot: Array[Dictionary] = []
var landmarks: Array[Dictionary] = []
var seed_value: int = 0
var regions: int = 0
var errors := PackedStringArray()
var _definitions: Dictionary = {}
var _solids: Array[Rect2] = []
var _surfaces: Array[Vector3] = []
var _nodes: Array[Vector2] = []
var _links: Array[PackedInt32Array] = []
var _node_keys: Dictionary = {}
var _path_cache: Dictionary = {}
var _node_buckets: Dictionary = {}
var _solid_buckets: Dictionary = {}
var _surface_buckets: Dictionary = {}


func configure(value: int) -> void:
	seed_value = value
	regions = 0
	bounds = Rect2()
	chunks.clear(); platforms.clear(); anchors.clear(); loot.clear(); landmarks.clear()
	_solids.clear(); _surfaces.clear(); _nodes.clear(); _links.clear(); _node_keys.clear(); _path_cache.clear(); _node_buckets.clear(); _node_buckets.clear(); _solid_buckets.clear(); _surface_buckets.clear(); errors.clear()
	var parser := JSON.new()
	var path := "res://content/arena/world.json"
	if not FileAccess.file_exists(path) or parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		errors.append("Scrolling world data is missing or invalid.")
		return
	_definitions = parser.data
	if _definitions.get("schema_version") != 1 or _definitions.get("content_version") != "scrolling-world-v1" or not _definitions.get("templates") is Array or _definitions.templates.size() != 4 or not _definitions.get("regions") is Array or _definitions.regions.size() != 4:
		errors.append("Scrolling world data requires four versioned templates and regions.")
		return
	expand_to(1)


func expand_to(requested_regions: int) -> Array[Dictionary]:
	var added: Array[Dictionary] = []
	if not errors.is_empty() or _definitions.is_empty():
		return added
	var wanted := clampi(requested_regions, 1, MAX_REGIONS)
	if wanted <= regions:
		return added
	for region in range(regions, wanted):
		for local in CHUNKS_PER_REGION:
			var identity := region * CHUNKS_PER_REGION + local
			var stream := _stream(identity,1)
			var variant := stream.randi_range(0,3)
			var mirrored := stream.randi_range(0,1)==1
			var definition: Dictionary = _definitions.templates[variant]
			var origin := Vector2(identity * CHUNK_WIDTH, 0)
			var data := _chunk(identity, region, origin, definition, mirrored)
			chunks.append(data)
			added.append(data.duplicate(true))
			for rect: Rect2 in data.solids:
				_solids.append(rect)
				_surfaces.append(Vector3(rect.position.x, rect.position.y, rect.size.x))
			for platform: Array in data.platforms:
				platforms.append(platform.duplicate())
				_surfaces.append(Vector3(float(platform[0]), float(platform[1]), float(platform[2])))
			for point: Vector2 in data.anchors:
				anchors.append(point)
		var region_record: Dictionary = _definitions.regions[region]
		var loot_stream := _stream(region,3)
		for number in region_record.loot.size():
			var item: Dictionary = region_record.loot[number]
			var chunk_id := region * 4 + int(item.chunk)
			var local := Vector2(float(item.position[0]),float(item.position[1]))
			if loot_stream.randi_range(0,1)==1:
				if local.y==224:local.x=336
				elif local.y==624:local.x=400 if item.kind=="cache" else 576
				else:local.x=560 if item.kind=="cache" else 240
			if bool(chunks[chunk_id].mirrored):local.x=640-local.x
			loot.append({"id":"r%d-%s-%d" % [region, str(item.kind), number], "kind":str(item.kind), "region":region,
				"position":chunks[chunk_id].origin + local})
		var landmark := {"id":"landmark-r%d" % region,"family":str(region_record.landmark),"region":region,"name":str(region_record.name),"position":Vector2((region * 4 + 2) * CHUNK_WIDTH + 320,320)}
		landmarks.append(landmark)
		chunks[region * 4 + 2]["landmark"] = landmark.duplicate(true)
		# Return the same final record that will be rendered, without sharing mutable arrays.
		for at in added.size():
			if int(added[at].id) == region * 4 + 2:
				added[at] = chunks[region * 4 + 2].duplicate(true)
	regions = wanted
	bounds = Rect2(0, 0, regions * CHUNKS_PER_REGION * CHUNK_WIDTH, WORLD_HEIGHT)
	_rebuild_navigation()
	return added


func _stream(identity: int,salt: int) -> RandomNumberGenerator:
	var stream := RandomNumberGenerator.new()
	stream.seed = seed_value ^ (identity * 104729) ^ (salt * 15485863)
	return stream


func _chunk(identity: int, region: int, origin: Vector2, definition: Dictionary,mirrored: bool) -> Dictionary:
	var solids: Array[Rect2] = []
	var steps: Array = []
	var points: Array[Vector2] = []
	var decorations: Array[Dictionary] = []
	for raw: Array in definition.solids:
		var x := 640-float(raw[0])-float(raw[2]) if mirrored else float(raw[0])
		solids.append(Rect2(origin + Vector2(x,float(raw[1])),Vector2(float(raw[2]),float(raw[3]))))
	for raw: Array in definition.platforms:
		var x := 640-float(raw[0])-float(raw[2]) if mirrored else float(raw[0])
		steps.append([origin.x + x,float(raw[1]),float(raw[2])])
	for raw: Array in definition.anchors:
		points.append(origin + Vector2(640-float(raw[0]) if mirrored else float(raw[0]),float(raw[1])))
	var decor_stream := _stream(identity,2)
	for raw: Dictionary in definition.decorations:
		var x := float(raw.position[0]) + decor_stream.randi_range(-10,10)
		if mirrored:x=640-x
		decorations.append({"prop":str(raw.prop),"position":origin + Vector2(x,float(raw.position[1])),"flip":bool(raw.get("flip",false)) != mirrored})
	decorations.append({"prop":"kiln_brazier","position":origin + Vector2(528,320),"flip":false})
	return {"id":identity,"region":region,"origin":origin,"template":str(definition.id),"mirrored":mirrored,"solids":solids,"platforms":steps,"anchors":points,"decorations":decorations,"landmark":{}}


func region_at(at: Vector2) -> int:
	return clampi(int(floor(at.x / float(CHUNK_WIDTH * CHUNKS_PER_REGION))),0,maxi(0,regions - 1))


func safe_position(at: Vector2) -> Vector2:
	if _surfaces.is_empty():
		return Vector2(270,320)
	var target := at if is_finite(at.x) and is_finite(at.y) else Vector2(270,320)
	var best := Vector2(270,320)
	var distance := INF
	for surface: Vector3 in _surfaces:
		if surface.z < ACTOR_HALF * 2 + 2:
			continue
		var x := clampf(target.x,surface.x + ACTOR_HALF + 2,surface.x + surface.z - ACTOR_HALF - 2)
		var point := Vector2(x,surface.y)
		if not _stand_clear(point):
			continue
		var candidate := target.distance_squared_to(point)
		if candidate < distance:
			distance = candidate
			best = point
	return best


func spawn_candidates(at: Vector2, radius: float = 720.0) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var maximum := maxf(0,radius) if is_finite(radius) else 720.0
	for point: Vector2 in anchors:
		if point.distance_squared_to(at) <= maximum * maximum and _stand_clear(point):
			result.append(point)
	result.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.distance_squared_to(at) < b.distance_squared_to(at))
	return result


func _stand_clear(point: Vector2) -> bool:
	if point.x < ACTOR_HALF or point.x > bounds.end.x - ACTOR_HALF:
		return false
	var actor := Rect2(point + Vector2(-ACTOR_HALF,-ACTOR_HEIGHT),Vector2(ACTOR_HALF * 2,ACTOR_HEIGHT - 0.1))
	for chunk_id in range(floori(actor.position.x/640),floori(actor.end.x/640)+1):
		for solid: Rect2 in _solid_buckets.get(chunk_id,[]):
			if actor.intersects(solid):return false
	return true


func _add_node(point: Vector2) -> void:
	var key := Vector2i(roundi(point.x),roundi(point.y))
	if _node_keys.has(key) or not _stand_clear(point):
		return
	_node_keys[key] = _nodes.size()
	_nodes.append(point)


func _rebuild_navigation() -> void:
	_nodes.clear(); _links.clear(); _node_keys.clear(); _path_cache.clear(); _node_buckets.clear(); _solid_buckets.clear(); _surface_buckets.clear()
	for chunk: Dictionary in chunks:_solid_buckets[int(chunk.id)]=chunk.solids
	for surface: Vector3 in _surfaces:
		var bucket := Vector2i(floori(surface.x/640),roundi(surface.y))
		if not _surface_buckets.has(bucket):_surface_buckets[bucket]=[]
		_surface_buckets[bucket].append(surface)
	for surface: Vector3 in _surfaces:
		var width := surface.z - 32
		var segments := maxi(1,ceili(width / 32.0))
		for part in segments + 1:
			_add_node(Vector2(surface.x + 16 + maxf(0,width) * part / segments,surface.y))
	for point: Vector2 in anchors:
		_add_node(point)
	for index in _nodes.size():
		var bucket := Vector2i(floori(_nodes[index].x/64),floori(_nodes[index].y/64))
		if not _node_buckets.has(bucket):_node_buckets[bucket]=PackedInt32Array()
		_node_buckets[bucket].append(index)
	_links.resize(_nodes.size())
	for a in _nodes.size():
		var neighbors := PackedInt32Array()
		var bucket := Vector2i(floori(_nodes[a].x/64),floori(_nodes[a].y/64))
		for x in range(-1,2):
			for y in range(-1,2):
				var candidates: PackedInt32Array = _node_buckets.get(bucket+Vector2i(x,y),PackedInt32Array())
				for b in candidates:
					if a != b and _can_travel(_nodes[a],_nodes[b]):neighbors.append(b)
		_links[a] = neighbors


func _can_travel(from: Vector2,to: Vector2) -> bool:
	var dx := absf(to.x - from.x)
	var dy := to.y - from.y
	if absf(dy) < 1.0:
		if dx > 56:
			return false
		var samples := maxi(1,ceili(dx / 12.0))
		for sample in samples + 1:
			if not _surface_at(from.lerp(to,float(sample) / samples)):
				return false
	elif dy < 0:
		if dy < -48.1 or dx > (32.0 if dy < -39 else 52.0):
			return false
	else:
		if dy > 64.1 or dx > 32:
			return false
	var sweep := Rect2(Vector2(minf(from.x,to.x) - ACTOR_HALF,minf(from.y,to.y) - ACTOR_HEIGHT),Vector2(dx + ACTOR_HALF * 2,absf(dy) + ACTOR_HEIGHT - 0.2))
	for chunk_id in range(floori(sweep.position.x/640),floori(sweep.end.x/640)+1):
		for solid: Rect2 in _solid_buckets.get(chunk_id,[]):
			if sweep.intersects(solid):return false
	return true


func _surface_at(point: Vector2) -> bool:
	var chunk_id := floori(point.x/640)
	for nearby in range(chunk_id-1,chunk_id+1):
		for surface: Vector3 in _surface_buckets.get(Vector2i(nearby,roundi(point.y)),[]):
			if absf(point.y-surface.y)<1 and point.x>=surface.x and point.x<=surface.x+surface.z:return true
	return false


func _nearest_node(at: Vector2) -> int:
	var point := Vector2(clampf(at.x,0,bounds.end.x),clampf(at.y,0,WORLD_HEIGHT))
	var bucket := Vector2i(floori(point.x/64),floori(point.y/64))
	var best := -1
	var distance := INF
	for radius in range(0,5):
		for x in range(-radius,radius+1):
			for y in range(-radius,radius+1):
				if maxi(absi(x),absi(y))!=radius:continue
				var candidates: PackedInt32Array = _node_buckets.get(bucket+Vector2i(x,y),PackedInt32Array())
				for index in candidates:
					var candidate := point.distance_squared_to(_nodes[index])
					if candidate < distance:
						distance=candidate;best=index
		if best>=0 and distance<=pow(maxi(0,radius-1)*64,2):return best
	if best>=0:return best
	for index in _nodes.size():
		var candidate := point.distance_squared_to(_nodes[index])
		if candidate<distance:distance=candidate;best=index
	return best


func navigation_step(from: Vector2,to: Vector2) -> Dictionary:
	if _nodes.is_empty():
		return {"point":from,"jump":false,"drop":false}
	var start := _nearest_node(from)
	var goal := _nearest_node(to)
	var key := Vector2i(start,goal)
	if not _path_cache.has(key):
		var previous := PackedInt32Array(); previous.resize(_nodes.size()); previous.fill(-1)
		var queue := PackedInt32Array([start]); previous[start] = start
		var read := 0
		while read < queue.size() and previous[goal] == -1:
			var current := queue[read]; read += 1
			for neighbor in _links[current]:
				if previous[neighbor] == -1:
					previous[neighbor] = current; queue.append(neighbor)
		var path := PackedInt32Array()
		if previous[goal] != -1:
			var cursor := goal; path.append(cursor)
			while cursor != start:
				cursor = previous[cursor]; path.append(cursor)
			path.reverse()
		if _path_cache.size() >= 256:
			_path_cache.erase(_path_cache.keys()[0])
		_path_cache[key] = path
	var route: PackedInt32Array = _path_cache[key]
	if route.is_empty():
		return {"point":safe_position(to),"jump":false,"drop":false}
	var point := _nodes[route[mini(1,route.size() - 1)]]
	if route.size() == 1:
		point = to if absf(to.y - from.y) < 24 else _nodes[goal]
	var horizontal := absf(point.x - from.x)
	return {"point":point,"jump":point.y < from.y - 10 and horizontal <= 40,"drop":point.y > from.y + 12 and horizontal <= 24}


func snapshot() -> Dictionary:
	return {"seed_value":seed_value,"regions":regions,"bounds":bounds,"chunks":chunks.duplicate(true),"platforms":platforms.duplicate(true),"anchors":anchors.duplicate(),"loot":loot.duplicate(true),"landmarks":landmarks.duplicate(true)}
