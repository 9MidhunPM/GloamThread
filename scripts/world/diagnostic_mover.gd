class_name DiagnosticMover
extends Node2D
## One renderable tracer object shared by both views. Its motion advances only
## with physics processing, so pausing the shared world freezes it in place.

const PERIOD_SECONDS := 4.0

var sprite_texture: Texture2D
## World-space centre of the horizontal motion; configured before entering tree.
var origin_position: Vector2 = Vector2.ZERO
## Maximum horizontal displacement from the origin in either direction.
var range_pixels: float = 96.0

var _elapsed: float = 0.0


func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = sprite_texture
	sprite.centered = false
	sprite.offset = Vector2(-16, -28)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	global_position = origin_position


func _physics_process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, PERIOD_SECONDS)
	var displacement := sin(TAU * _elapsed / PERIOD_SECONDS) * range_pixels
	global_position = origin_position + Vector2(displacement, 0.0)
