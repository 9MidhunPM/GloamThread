class_name Room
extends Node2D
## One instanced room: canonical collision, shared cues, two render-only theme
## roots and the gameplay entities declared in the room definition.
##
## Exactly one Room exists in the session at a time (docs/DECISIONS.md). The
## theme roots carry visibility layers 2 (Ember) and 4 (Moss) so each
## SubViewport's canvas_cull_mask shows only its own skin; everything the
## players must agree on lives under Common (layer 1).

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


static func build(room_definition: RoomDefinition) -> Room:
	var room := Room.new()
	room.name = "Room_%s" % room_definition.id
	room.definition = room_definition
	room._build_children()
	return room


func _build_children() -> void:
	collision = CollisionBuilder.build(definition)
	add_child(collision)

	common = Node2D.new()
	common.name = "Common"
	common.visibility_layer = VISIBILITY_COMMON
	add_child(common)

	theme_ember = Node2D.new()
	theme_ember.name = "ThemeEmber"
	theme_ember.visibility_layer = VISIBILITY_EMBER
	theme_ember.add_child(GrayboxSkin.build_layer(definition, "GrayboxEmber", EMBER_TINT))
	add_child(theme_ember)

	theme_moss = Node2D.new()
	theme_moss.name = "ThemeMoss"
	theme_moss.visibility_layer = VISIBILITY_MOSS
	theme_moss.add_child(GrayboxSkin.build_layer(definition, "GrayboxMoss", MOSS_TINT))
	add_child(theme_moss)

	entities = Node2D.new()
	entities.name = "Entities"
	add_child(entities)


func bounds() -> Rect2:
	return definition.bounds()


## Counts physics bodies/areas under the theme roots; must always be zero.
func theme_gameplay_node_count() -> int:
	var count := 0
	for root in [theme_ember, theme_moss]:
		count += _count_gameplay_nodes(root)
	return count


static func _count_gameplay_nodes(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is CollisionObject2D or child is CollisionShape2D or child is CollisionPolygon2D:
			count += 1
		count += _count_gameplay_nodes(child)
	return count
