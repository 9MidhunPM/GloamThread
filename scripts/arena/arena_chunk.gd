class_name ArenaChunk
extends Node2D
## Shared render-only chunk. Session builds collisions/loot from the same records.
const PROP_IDS := ["lantern_pole", "kiln_brazier", "thread_spool", "root_arch", "glass_fern", "hanging_bell", "broken_column", "ivy_pillar", "iron_gate", "seed_pod", "crystal_cluster", "woven_banner", "stone_stack", "hollow_log", "little_shrine", "water_pipe", "copper_cogs", "thorn_bush", "blue_mushrooms", "tomb_marker", "rope_coil", "wind_chimes", "cave_lantern", "old_crate"]
const LANDMARK_IDS := ["bell_oak", "glass_gate", "spool_tower", "crown_loom"]
static var _media: Dictionary = {}
var data: Dictionary = {}
var appearance: Dictionary = {}
var errors := PackedStringArray()

class AmbientGlow extends Node2D:
	var lights: Array[Vector2] = []
	var tint := Color("efcb91")
	var age: float = 0
	var clock: float = 0
	func _process(delta: float) -> void:
		age += delta
		clock += delta
		if clock >= 0.12:
			clock = 0
			queue_redraw()
	func _draw() -> void:
		for index in lights.size():
			var pulse := 0.10 + sin(age * 1.1 + index * 1.7) * 0.025
			draw_circle(lights[index],9,Color(tint,pulse))
			draw_circle(lights[index],3,Color(tint,0.18 + pulse))


func setup(record: Dictionary, bundle: Dictionary) -> void:
	data = record.duplicate(true)
	appearance = bundle
	position = data.get("origin",Vector2.ZERO)
	z_index = -10
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_media()
	errors = _media.get("errors",PackedStringArray()).duplicate()
	queue_redraw()


func _ready() -> void:
	_load_media()
	var glow := AmbientGlow.new()
	for record: Dictionary in data.get("decorations",[]):
		if str(record.get("prop","")) in ["lantern_pole","cave_lantern","kiln_brazier"]:
			glow.lights.append(record.position - position + Vector2(0,-28))
	add_child(glow)


static func _load_media() -> void:
	if not _media.is_empty():return
	_media={"errors":PackedStringArray()}
	var path := "res://assets/arena/scenery/index.json"
	if not FileAccess.file_exists(path):
		_media_error("Required scrolling scenery index is missing.");return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema_version")!=1 or parsed.get("content_version")!="scrolling-world-v1" or not parsed.get("files") is Dictionary or parsed.files.size()!=6 or not parsed.get("props") is Dictionary or parsed.props.size()!=24 or not parsed.get("landmarks") is Dictionary or parsed.landmarks.size()!=4:
		_media_error("Required scrolling scenery index is invalid.");return
	for file: String in ["props.png","landmarks.png","sky.png","far.png","canopy.png","foreground.png"]:
		if not parsed.files.has(file):_media_error("Required scenery filename is missing: "+file)
	for identity: String in PROP_IDS:
		if not parsed.props.has(identity):_media_error("Required scenery prop is missing: "+identity)
	for identity: String in LANDMARK_IDS:
		if not parsed.landmarks.has(identity):_media_error("Required landmark family is missing: "+identity)
	for key: String in ["props","landmarks"]:
		var size := Vector2i(512,192)
		var digest: Variant = parsed.files.get(key+".png")
		if not digest is String:
			_media_error("Required scrolling scenery hash is missing: "+key);continue
		_media[key]=_raw_texture(key+".png",size,digest)
		for record: Variant in parsed[key].values():
			if not _valid_record(record,Vector2i(64,64) if key=="props" else Vector2i(128,192)):
				_media_error("Scrolling scenery atlas rectangle is invalid.")
	_media["index"]=parsed


static func _valid_record(record: Variant,cell: Vector2i) -> bool:
	if not record is Dictionary or not record.get("rect") is Array or record.rect.size()!=4 or not record.get("origin") is Array or record.origin.size()!=2:return false
	for number: Variant in record.rect+record.origin:
		if not (number is int or number is float) or not is_finite(float(number)) or float(number)!=floor(float(number)):return false
	return record.rect[0]>=0 and record.rect[1]>=0 and record.rect[2]==cell.x and record.rect[3]==cell.y and record.rect[0]+cell.x<=512 and record.rect[1]+cell.y<=192 and record.origin[0]>=0 and record.origin[0]<=cell.x and record.origin[1]>=0 and record.origin[1]<=cell.y


static func _media_error(message: String) -> void:
	var values: PackedStringArray = _media.get("errors",PackedStringArray());values.append(message);_media["errors"]=values


static func _raw_texture(file: String,size: Vector2i,digest: String) -> Texture2D:
	var path := "res://assets/arena/scenery/"+file
	var handle := FileAccess.open(path,FileAccess.READ)
	if handle==null or handle.get_length()>8*1024*1024 or handle.get_length()<24:
		_media_error("Required scenery PNG is missing or oversized: "+file);return null
	var bytes := handle.get_buffer(handle.get_length())
	var hash := HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
	if hash.finish().hex_encode()!=digest:
		_media_error("Required scenery PNG hash differs: "+file);return null
	var width := (int(bytes[16])<<24)|(int(bytes[17])<<16)|(int(bytes[18])<<8)|int(bytes[19])
	var height := (int(bytes[20])<<24)|(int(bytes[21])<<16)|(int(bytes[22])<<8)|int(bytes[23])
	if width!=size.x or height!=size.y:
		_media_error("Required scenery PNG dimensions differ: "+file);return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes)!=OK or image.get_size()!=size:
		_media_error("Required scenery PNG cannot decode: "+file);return null
	return ImageTexture.create_from_image(image)


static func media_errors() -> PackedStringArray:
	_load_media();return _media.get("errors",PackedStringArray()).duplicate()


func _draw() -> void:
	if data.is_empty():
		return
	var palette: Array = appearance.get("theme",{}).get("palette",["#142432","#294951","#71958a","#e9c38a"])
	var accent := Color(str(palette[mini(2,palette.size() - 1)]))
	var region := int(data.get("region",0))
	# The cave is world scenery, not a separate room or alternate simulation.
	_cave_wall(accent)
	for rect: Rect2 in data.get("solids",[]):
		_surface(Rect2(rect.position - position,rect.size),region,accent)
	for raw: Array in data.get("platforms",[]):
		_surface(Rect2(float(raw[0]) - position.x,float(raw[1]),float(raw[2]),8),2 if float(raw[1]) < 320 else 1,accent)
	for record: Dictionary in data.get("decorations",[]):
		_prop(str(record.prop),record.position - position,bool(record.get("flip",false)))
	var landmark: Dictionary = data.get("landmark",{})
	if not landmark.is_empty():
		_landmark(str(landmark.family),landmark.position - position)


func _cave_wall(accent: Color) -> void:
	draw_rect(Rect2(0,352,640,272),Color("101d28"))
	var texture: Texture2D = appearance.get("materials")
	# Fifteen retained-material tiles, rather than noisy per-pixel detail. This
	# stays deliberately darker than every actor and the walkable stone lips.
	if texture != null:
		for x in range(0,640,128):
			for y in range(352,624,128):
				var height := minf(128,624-y)
				draw_texture_rect_region(texture,Rect2(x,y,128,height),Rect2(128,0,128,height),Color(0.42,0.60,0.64,0.16))
	var identity := int(data.get("id",0))
	for row in 3:
		var y := 392 + row * 78
		var offset := (identity * 7 + row * 11) % 17
		var contour := PackedVector2Array([Vector2(0,y+10),Vector2(64,y+3),Vector2(146,y+15+offset),Vector2(230,y+7),Vector2(328,y+21),Vector2(402,y+10),Vector2(514,y+16-offset),Vector2(590,y+2),Vector2(640,y+8)])
		var body := contour.duplicate()
		body.append(Vector2(640,y+52));body.append(Vector2(0,y+52))
		draw_colored_polygon(body,Color("152731") if row%2==0 else Color("13232d"))
		draw_polyline(contour,Color(accent,0.12),1)
		for seam in 3:
			var x := 62 + seam * 204 + ((identity+row)*19)%58
			var vein := PackedVector2Array([Vector2(x,y+12),Vector2(x+12,y+25),Vector2(x+7,y+36),Vector2(x+26,y+44)])
			draw_polyline(vein,Color("517477",0.24),1)
			draw_line(Vector2(x+12,y+25),Vector2(x+26,y+21),Color("71958a",0.16),1)
	# Roots hang from the main route's underside, leaving the two shafts clear.
	for index in 5:
		var x := 28 + index * 54 if index<2 else 202 + (index-2)*92
		var length := 26 + ((identity+index)*13)%31
		var root := PackedVector2Array([Vector2(x,352),Vector2(x+3,365),Vector2(x-2,375),Vector2(x+5,352+length)])
		draw_polyline(root,Color("263d3d"),2)
		draw_line(Vector2(x-2,375),Vector2(x-10,382),Color("304b46"),1)
	# Back rails and rope lashings explain the existing one-way shaft steps;
	# their positions come from real platforms, never a second geometry recipe.
	var shafts: Dictionary = {}
	for raw: Array in data.get("platforms",[]):
		var y := float(raw[1])-position.y
		if y<=320 or y>=624:
			continue
		var x := float(raw[0])-position.x
		var width := float(raw[2])
		if not shafts.has(x):
			shafts[x]=true
			for rail in [x+5,x+width-6]:
				draw_line(Vector2(rail,336),Vector2(rail,616),Color("263d42"),3)
				draw_line(Vector2(rail+1,336),Vector2(rail+1,616),Color("718277",0.33),1)
		draw_line(Vector2(x+5,y+4),Vector2(x+width-6,y+19),Color("52635b",0.33),2)
		for rail in [x+5,x+width-6]:
			draw_rect(Rect2(rail-2,y-3,5,3),Color("927b57",0.55))
	var cave_props := ["blue_mushrooms","stone_stack","crystal_cluster","rope_coil"]
	for index in 3:
		var x := 44 + index * 262
		_prop(cave_props[(identity+index)%4],Vector2(x,624),bool((identity+index)%2),Color(0.56,0.69,0.68,0.72))


func _surface(rect: Rect2,panel: int,accent: Color) -> void:
	draw_rect(rect,Color("162631"))
	var texture: Texture2D = appearance.get("materials")
	if texture != null:
		for x in range(int(rect.position.x),int(rect.end.x),16):
			for y in range(int(rect.position.y),int(rect.end.y),16):
				var size := Vector2(minf(16,rect.end.x - x),minf(16,rect.end.y - y))
				var source := Vector2((panel % 2) * 128 + posmod(x,128),(panel / 2) * 128 + posmod(y,128))
				draw_texture_rect_region(texture,Rect2(Vector2(x,y),size),Rect2(source,size),Color(0.5,0.6,0.65,1))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x,2)),accent.lightened(0.24))
	draw_line(rect.position + Vector2(0,2),Vector2(rect.end.x,rect.position.y + 2),Color("09141e"),1)


func _prop(identity: String,at: Vector2,flip: bool,tint: Color=Color.WHITE) -> void:
	var index: Dictionary = _media.get("index",{})
	var record: Dictionary = index.get("props",{}).get(identity,{})
	var texture: Texture2D = _media.get("props")
	if texture == null or record.is_empty():
		return
	var raw: Array = record.rect
	var origin: Array = record.origin
	var target := Rect2(at - Vector2(float(origin[0]),float(origin[1])),Vector2(float(raw[2]),float(raw[3])))
	if flip:
		draw_set_transform(at,0,Vector2(-1,1))
		target.position=-Vector2(float(origin[0]),float(origin[1]))
	draw_texture_rect_region(texture,target,Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3])),tint)
	if flip:draw_set_transform(Vector2.ZERO)


func _landmark(identity: String,at: Vector2) -> void:
	var index: Dictionary = _media.get("index",{})
	var record: Dictionary = index.get("landmarks",{}).get(identity,{})
	var texture: Texture2D = _media.get("landmarks")
	if texture == null or record.is_empty():
		return
	var raw: Array = record.rect
	var origin: Array = record.origin
	draw_texture_rect_region(texture,Rect2(at - Vector2(float(origin[0]),float(origin[1])),Vector2(float(raw[2]),float(raw[3]))),Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3])))
