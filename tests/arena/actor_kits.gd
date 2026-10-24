extends Scenario
const FIXTURE := preload("res://tests/arena/actor_fixture.gd")
const Action := CommandSnapshot.Action

func run() -> void:
	InputRouter.clear(0)
	InputRouter.assign(0,DeviceSource.keyboard_left())
	var outcomes: Dictionary={}
	for kit:String in ["ember","frost","storm","stone","nature","shadow"]:
		InputRouter.set_test_input(0,0)
		var world:Node2D=FIXTURE.new()
		add_child(world)
		world.floor_body()
		var fighter:=ArenaFighter.new()
		fighter.setup(0,kit,world,{})
		fighter.apply_stats({"crit":0.0})
		fighter.position=Vector2(200,320)
		world.add_child(fighter)
		world.fighters.append(fighter)
		await _steps(2)
		InputRouter.set_test_input(0,Action.ATTACK)
		await _steps(1)
		InputRouter.set_test_input(0,0)
		await _steps(35)
		var basic:Dictionary=world.shots[0] if kit in ["frost","nature"] else world.hits[0]
		assert_eq(basic.slot,0,kit+" basic keeps the owned source")
		match kit:
			"ember":assert_true(basic.tags.burn>0,"Ember cleave carries baseline burn")
			"frost":assert_true(basic.tags.freeze>0,"Frost basic is a freezing projectile")
			"storm":assert_true(float(basic.damage)<12,"Storm trades hit weight for its faster cadence")
			"stone":assert_true(float(basic.damage)>18 and basic.tags.stagger>=2,"Stone basic is heavy stagger damage")
			"nature":assert_true(basic.tags.pierce>=1,"Nature basic pierces as a thorn projectile")
			"shadow":assert_eq(basic.tags.mark,1,"Shadow basic creates source-owned marks")
		world.hits.clear()
		world.shots.clear()
		fighter.health=50
		InputRouter.set_test_input(0,Action.SPECIAL)
		await _steps(9)
		var special:Dictionary=world.shots[0] if kit in ["frost","shadow"] else world.hits[0]
		match kit:
			"ember":assert_true(special.tags.burn>=3 and special.rect.size.x>100,"Ember special is a wider sustained flame")
			"frost":assert_true(world.shots.size()==3 and special.tags.shatter,"Frost special is a three-bolt shatter fan")
			"storm":assert_true(special.tags.chain>=3,"Storm special carries a bounded lightning chain")
			"stone":assert_true(special.rect.size.x>=190 and special.tags.stagger>=4,"Stone special is a bilateral armoured slam")
			"nature":assert_true(special.tags.root and fighter.health>60,"Nature special roots nearby enemies and heals its owner")
			"shadow":assert_true(special.tags.consume_marks and special.tags.pierce>=3,"Shadow special consumes private marks along a piercing line")
		outcomes[kit]=fighter.special_ticks
		world.free()
	assert_eq(outcomes.size(),6,"all six families execute their distinct special")
	# Rigs share the exact collision and gravity contract despite different art.
	for rig:String in ["upright","quadruped","floating"]:
		InputRouter.set_test_input(0,0)
		var world:Node2D=FIXTURE.new()
		add_child(world)
		world.floor_body()
		var image:=Image.create(544,272,false,Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		var fighter:=ArenaFighter.new()
		fighter.setup(0,"ember",world,{"atlas":ImageTexture.create_from_image(image),"manifest":{"rig_id":rig}})
		fighter.position=Vector2(200,200)
		world.add_child(fighter)
		world.fighters.append(fighter)
		await _steps(40)
		assert_true(fighter.is_on_floor() and absf(fighter.position.y-320)<0.2,rig+" drawing cannot grant flight")
		assert_eq(fighter.get_hurt_rect().size,Vector2(18,38),rig+" uses the canonical hurtbox")
		var avatar:ArenaAvatar=fighter.get("_avatar")
		assert_eq(avatar.offset,Vector2(-32,-56),rig+" keeps the fixed feet pivot")
		assert_eq(avatar.texture.get_size(),Vector2(64,64),rig+" consumes one padded64px atlas frame")
		world.free()
	InputRouter.clear_test_input()
	InputRouter.clear(0)

func _steps(count:int)->void:
	for tick in count:
		await get_tree().physics_frame
		await get_tree().process_frame
