class_name SpriteAnimator
extends Node
## Presentation only: one animation tick per physics callback, paused with world.

var state: String = ""
var finished: bool = false
var _sprite: Sprite2D
var _catalog: AssetCatalog
var _asset_id: String = ""
var _clip: Dictionary = {}
var _index: int = 0
var _remaining: int = 0


func configure(sprite: Sprite2D, catalog: AssetCatalog, id: String) -> void:
	_sprite = sprite
	_catalog = catalog
	_asset_id = id
	state = ""
	_clip = {}
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var origin: Array = catalog.entries.get(id, {}).get("origin", [0, 0])
	_sprite.offset = -Vector2(float(origin[0]), float(origin[1]))
	_sprite.texture = catalog.frame_texture(id)


func play(next_state: String) -> void:
	if next_state == state or _catalog == null or not is_instance_valid(_sprite):
		return
	var clip := _catalog.animation(_asset_id, next_state)
	if clip.is_empty():
		return
	state = next_state
	_clip = clip
	_index = 0
	finished = false
	_show_frame()


func _physics_process(_delta: float) -> void:
	if _clip.is_empty() or finished or not is_instance_valid(_sprite):
		return
	_remaining -= 1
	if _remaining > 0:
		return
	_index += 1
	if _index >= _clip["frames"].size():
		if not _clip["loop"]:
			finished = true
			return
		_index = 0
	_show_frame()


func _show_frame() -> void:
	_sprite.texture = _catalog.frame_texture(_asset_id, int(_clip["frames"][_index]))
	_remaining = int(_clip["ticks"][_index])
