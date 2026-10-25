extends Scenario
const MAP := preload("res://scripts/arena/arena_map.gd")

func run() -> void:
	for seed_value: int in [-19,0,18427]:
		var map: RefCounted = MAP.new()
		var started := Time.get_ticks_usec()
		map.configure(seed_value)
		var initial_usec := Time.get_ticks_usec()-started
		assert_true(map.errors.is_empty(),"versioned map loads for seed%d: %s" % [seed_value,str(map.errors)])
		assert_eq(map.chunks.size(),4,"initial world has four chunks")
		assert_eq(map.bounds,Rect2(0,0,2560,720),"initial world extent")
		assert_eq(map.loot.size(),6,"initial region has six unique loot records")
		assert_eq(map.safe_position(Vector2(270,320)),Vector2(270,320),"first fighter keeps original safe spawn")
		assert_eq(map.safe_position(Vector2(370,320)),Vector2(370,320),"second fighter keeps original safe spawn")
		var initial: Dictionary = map.snapshot()
		started = Time.get_ticks_usec()
		var added: Array = map.expand_to(4)
		var expand_usec := Time.get_ticks_usec()-started
		assert_eq(added.size(),12,"three regions append twelve chunks")
		assert_eq(map.bounds,Rect2(0,0,10240,720),"full world extent")
		for at in 4:
			assert_eq(map.chunks[at],initial.chunks[at],"expansion preserves original chunk%d" % at)
		assert_eq(map.loot.slice(0,6),initial.loot,"discovered loot identity/position never changes")
		assert_true(map.expand_to(4).is_empty() and map.expand_to(1).is_empty(),"expansion never duplicates or shrinks content")
		var ids: Dictionary = {}
		for region in 4:
			var caches := 0; var plants := 0
			for item: Dictionary in map.loot:
				assert_true(not ids.has(item.id) or ids[item.id]==item.position,"loot IDs remain stable")
				ids[item.id] = item.position
				if item.region == region:
					caches += int(item.kind=="cache"); plants += int(item.kind=="plant")
			assert_eq(caches,4,"four team caches in region%d" % region)
			assert_eq(plants,2,"two collector plants in region%d" % region)
		assert_eq(ids.size(),24,"all loot IDs unique")
		assert_eq(map.landmarks.size(),4,"one landmark per region")
		assert_eq(map.region_at(Vector2(3000,320)),1,"world coordinate selects region")
		assert_eq(map.region_at(Vector2(20000,624)),3,"outside query clamps to final region")
		var candidates: Array = map.spawn_candidates(Vector2(270,320),720)
		assert_true(not candidates.is_empty(),"nearby reachable spawn anchors exist")
		for point: Vector2 in candidates:
			assert_true(point.distance_to(Vector2(270,320))<=720,"spawn anchors obey radius")
			assert_eq(map.safe_position(point),point,"spawn anchor stands outside solids")
		var peer: RefCounted = MAP.new();peer.configure(seed_value);peer.expand_to(4)
		assert_eq(map.snapshot(),peer.snapshot(),"same seed reproduces geometry and identities")
		# All authored navigation nodes must be reachable, including caves/raised paths.
		var seen := {0:true};var queue: Array[int] = [0]
		while not queue.is_empty():
			var current: int = queue.pop_front()
			for next: int in map._links[current]:
				if not seen.has(next):seen[next]=true;queue.append(next)
		assert_eq(seen.size(),map._nodes.size(),"every route node connects across main/raised/cave paths")
		for target: Vector2 in [Vector2(304,224),Vector2(320,624),Vector2(10000,320),Vector2(9800,624)]:
			var step: Dictionary = map.navigation_step(Vector2(270,320),target)
			assert_true(step.point is Vector2 and step.jump is bool and step.drop is bool,"navigation returns bounded movement instructions")

		started = Time.get_ticks_usec()
		for query in 1000:
			map.navigation_step(map.anchors[query%map.anchors.size()],map.anchors[(query*13+query/7)%map.anchors.size()])
		var queries_usec := Time.get_ticks_usec()-started
		var repeat_from: Vector2 = map.anchors[0];var repeat_to: Vector2=map.anchors[map.anchors.size()-1]
		map.navigation_step(repeat_from,repeat_to);started=Time.get_ticks_usec()
		for query in 1000:map.navigation_step(repeat_from,repeat_to)
		var cached_usec := Time.get_ticks_usec()-started
		assert_true(map._path_cache.size()<=256,"navigation cache remains bounded")
		print("MAP_PROFILE ",JSON.stringify({"seed":seed_value,"initial_usec":initial_usec,"expand16_usec":expand_usec,"nodes":map._nodes.size(),"queries1000_usec":queries_usec,"cached1000_usec":cached_usec,"cache":map._path_cache.size()}))
	var patterns: Dictionary = {}
	for seed_value in 16:
		var sample: RefCounted = MAP.new();sample.configure(seed_value)
		var shape: Array = []
		for chunk: Dictionary in sample.chunks:shape.append([chunk.template,chunk.mirrored])
		patterns[hash(shape)]=true
	assert_true(patterns.size()>4,"independent chunk streams produce more than four repeating seed patterns")
