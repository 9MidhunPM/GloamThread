extends Scenario
const MAP := preload("res://scripts/arena/arena_map.gd")
const CHUNK := preload("res://scripts/arena/arena_chunk.gd")

func run() -> void:
	var map: RefCounted = MAP.new();map.configure(18427)
	var chunk: Node2D = CHUNK.new();chunk.setup(map.chunks[0],FighterLibrary.new().list_bundles()[0]);add_child(chunk)
	await get_tree().process_frame
	assert_true(chunk.errors.is_empty(),"raw exported scenery PNGs admit with hashes/dimensions: "+str(chunk.errors))
	assert_true(chunk.find_children("*","CollisionObject2D",true,false).is_empty(),"shared scenery contains no gameplay collisions/triggers")
	assert_true(CHUNK._media.get("props") is Texture2D and CHUNK._media.get("landmarks") is Texture2D,"both authored atlas textures decoded without ResourceLoader")
	var saved: Dictionary = CHUNK._media.duplicate(true)
	assert_true(CHUNK._raw_texture("props.png",Vector2i(512,192),"0".repeat(64))==null,"bad raw scenery hash rejects before decoding")
	assert_true(not CHUNK.media_errors().is_empty(),"scenery admission failure remains visible to session")
	CHUNK._media=saved
	assert_true(not CHUNK._valid_record({"rect":[500,0,64,64],"origin":[32,56]},Vector2i(64,64)),"atlas rectangles cannot escape fixed image bounds")
