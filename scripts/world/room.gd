class_name Room
extends Node2D
## One collision tree and two render-only skins. Gameplay actors and interaction
## transactions remain owned by the session; this node only reflects their flags.

const ThemePainter = preload("res://scripts/presentation/theme_presenter.gd")
const Animator = preload("res://scripts/presentation/sprite_animator.gd")
const VISIBILITY_COMMON := 1
const VISIBILITY_EMBER := 2
const VISIBILITY_MOSS := 4
const EMBER_TINT := Color("#bc7852")
const MOSS_TINT := Color("#73965d")

var definition: RoomDefinition
var collision: StaticBody2D
var common: Node2D
var theme_ember: Node2D
var theme_moss: Node2D
var entities: Node2D
var draw_visuals: bool = true
var catalog: AssetCatalog
var progress: Dictionary = {}
var restored_bridges: Dictionary = {}
var _visuals: Dictionary = {}
var _animators: Dictionary = {}
var _decor: Array[Sprite2D] = []


static func build(room_definition: RoomDefinition, with_visuals: bool = true, asset_catalog: AssetCatalog = null, flags: Dictionary = {}) -> Room:
	var room := Room.new()
	room.name = "Room_%s" % room_definition.id
	room.definition = room_definition
	room.draw_visuals = with_visuals
	room.catalog = asset_catalog
	room._build_children()
	room.set_progress(flags)
	return room


func _build_children() -> void:
	collision = CollisionBuilder.build(definition)
	add_child(collision)
	common = Node2D.new()
	common.name = "Common"
	common.visibility_layer = VISIBILITY_COMMON
	add_child(common)
	theme_ember = _theme_root("ThemeEmber", VISIBILITY_EMBER, "ember", EMBER_TINT)
	theme_moss = _theme_root("ThemeMoss", VISIBILITY_MOSS, "moss", MOSS_TINT)
	entities = Node2D.new()
	entities.name = "Entities"
	common.add_child(entities)
	if draw_visuals and catalog != null:
		_build_decor()
		_build_entity_visuals()


func _theme_root(node_name: String, mask: int, theme_id: String, tint: Color) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.visibility_layer = mask
	if draw_visuals:
		if catalog != null:
			root.add_child(ThemePainter.build_terrain(definition, catalog, theme_id))
		else:
			root.add_child(GrayboxSkin.build_layer(definition, "Graybox", tint))
	add_child(root)
	return root


func _sprite(asset_id: String, frame: int, position: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = catalog.frame_texture(asset_id, frame)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var origin: Array = catalog.entries[asset_id].get("origin", [0, 0])
	sprite.offset = -Vector2(float(origin[0]), float(origin[1]))
	sprite.position = position
	return sprite


func _prop(prop_id: String, position: Vector2) -> Sprite2D:
	var ids: Array = catalog.entries["props_v1"]["prop_ids"]
	var sprite := _sprite("props_v1", ids.find(prop_id), position)
	sprite.set_meta("prop_id", prop_id)
	return sprite


func _build_decor() -> void:
	for item: Dictionary in definition.decor:
		var sprite := _sprite(item["asset_id"], int(item["frame"]), Vector2(item["position_px"][0], item["position_px"][1]))
		sprite.z_index = int(item["z"])
		sprite.set_meta("original_frame", int(item["frame"]))
		sprite.set_meta("asset_id", item["asset_id"])
		var parent: Node2D = common
		if item["theme"] == "ember":
			parent = theme_ember
		elif item["theme"] == "moss":
			parent = theme_moss
		parent.add_child(sprite)
		_decor.append(sprite)


func _build_entity_visuals() -> void:
	for item: Dictionary in definition.entities:
		var id: String = item["id"]
		match item["type"]:
			"npc":
				var sprite := _sprite("oru_v1", 0, _feet(item["tile"]))
				entities.add_child(sprite)
				var animator := Animator.new()
				sprite.add_child(animator)
				animator.configure(sprite, catalog, "oru_v1")
				animator.play("idle")
				_visuals[id] = sprite
				_animators[id] = animator
			"checkpoint", "secret":
				var prop := "checkpoint" if item["type"] == "checkpoint" else "lantern_lit"
				var sprite := _prop(prop, _feet(item["tile"]))
				entities.add_child(sprite)
				_visuals[id] = sprite
				_visuals[str(item.get("checkpoint_id", item.get("flag", id)))] = sprite
			"anchor_pair", "loom":
				var field := "anchors" if item["type"] == "anchor_pair" else "stations"
				var sprites: Array[Sprite2D] = []
				for point: Dictionary in item[field]:
					var sprite := _prop("anchor" if field == "anchors" else "loom", _feet(point["tile"]))
					entities.add_child(sprite)
					_visuals[point["id"]] = sprite
					sprites.append(sprite)
				_visuals[id] = sprites
				_visuals[item["flag"]] = sprites
			"exit":
				var rect: Array = item["rect"]
				var sprite := _prop("sign", Vector2((float(rect[0]) + float(rect[2]) * 0.5) * 16, (float(rect[1]) + float(rect[3]) - 1) * 16))
				entities.add_child(sprite)
				_visuals[id] = sprite


static func _feet(tile: Array) -> Vector2:
	return RoomDefinition.feet_position(Vector2i(int(tile[0]), int(tile[1])))


func restore_bridge(flag: String) -> bool:
	if restored_bridges.has(flag):
		return false
	for item: Dictionary in definition.entities:
		if item["type"] != "anchor_pair" or item["flag"] != flag:
			continue
		var data: Array = item["bridge_rect"]
		var rect := Rect2i(int(data[0]), int(data[1]), int(data[2]), int(data[3]))
		var shape := CollisionBuilder._rect_shape("Bridge_" + flag, rect, false)
		collision.add_child(shape)
		if draw_visuals:
			if catalog != null:
				theme_ember.add_child(ThemePainter.build_bridge(rect, catalog, "ember"))
				theme_moss.add_child(ThemePainter.build_bridge(rect, catalog, "moss"))
			else:
				for root: Node2D in [theme_ember, theme_moss]:
					var block := Polygon2D.new()
					var start := Vector2(rect.position) * 16
					var size := Vector2(rect.size) * 16
					block.polygon = PackedVector2Array([start, start + Vector2(size.x, 0), start + size, start + Vector2(0, size.y)])
					block.color = EMBER_TINT if root == theme_ember else MOSS_TINT
					root.add_child(block)
		restored_bridges[flag] = true
		progress[flag] = true
		set_entity_state(flag, "restored")
		return true
	return false


func set_progress(flags: Dictionary) -> void:
	progress = flags.duplicate(true)
	for item: Dictionary in definition.entities:
		var kind: String = item["type"]
		if kind == "anchor_pair" and progress.get(item["flag"], false):
			restore_bridge(item["flag"])
		elif kind == "loom" and progress.get("loom_restored", false):
			set_entity_state(item["id"], "restored")
		elif kind == "secret" and progress.get("lantern_charm", false):
			set_entity_state(item["id"], "hidden")
		elif kind == "exit":
			var open := true
			for requirement: String in item["requires_all"]:
				open = open and bool(progress.get(requirement, false))
			set_entity_state(item["id"], "open" if open else "locked")
	if definition.id == "r00" and catalog != null and progress.get("loom_restored", false):
		for sprite: Sprite2D in _decor:
			if sprite.get_meta("asset_id") == "props_v1":
				var original: int = int(sprite.get_meta("original_frame"))
				if original in [2, 6]:
					sprite.texture = catalog.frame_texture("props_v1", original + 1)


func set_entity_state(id: String, state: String) -> void:
	if not _visuals.has(id):
		return
	if _animators.has(id):
		_animators[id].play(state)
		return
	var targets: Array = _visuals[id] if _visuals[id] is Array else [_visuals[id]]
	for sprite: Sprite2D in targets:
		if state in ["hidden", "collected"]:
			sprite.visible = false
			continue
		sprite.visible = true
		if state in ["locked", "open"]:
			sprite.modulate = Color(0.5, 0.55, 0.65) if state == "locked" else Color.WHITE
			continue
		var base: String = str(sprite.get_meta("prop_id", ""))
		var lit: bool = state in ["latched", "active", "restored", "lit", "anchor_latched", "loom_lit", "checkpoint_lit", "lantern_lit"]
		var prop_id: String = {"anchor": "anchor_latched", "loom": "loom_lit", "checkpoint": "checkpoint_lit", "lantern": "lantern_lit"}.get(base, base) if lit else base
		var index: int = catalog.entries["props_v1"]["prop_ids"].find(prop_id)
		if index >= 0:
			sprite.texture = catalog.frame_texture("props_v1", index)


func bounds() -> Rect2:
	return definition.bounds()


func theme_gameplay_node_count() -> int:
	return _count_gameplay_nodes(theme_ember) + _count_gameplay_nodes(theme_moss)


static func _count_gameplay_nodes(node: Node) -> int:
	var count := 0
	for child: Node in node.get_children():
		if child is CollisionObject2D or child is CollisionShape2D or child is CollisionPolygon2D:
			count += 1
		count += _count_gameplay_nodes(child)
	return count
