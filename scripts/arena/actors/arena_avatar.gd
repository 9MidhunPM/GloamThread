class_name ArenaAvatar
extends Sprite2D
## Fixed local animation contract shared by all accepted 64px rigs.
const CLIPS := {
	"idle": [[0,1,2,3], 10, true], "run": [[4,5,6,7,8,9], 5, true],
	"rise": [[10,11], 6, false], "fall": [[12,13], 6, true],
	"land": [[14,15], 4, false], "slash": [[16,17,18,19], 4, false],
	"special": [[20,21,22,23], 5, false], "hurt": [[24,25], 5, false],
	"dash": [[26,27], 5, false], "downed": [[28,29], 15, true],
	"revive": [[30,31], 6, false],
}
var state := ""
var _frames: Array[AtlasTexture] = []
var _frame := 0
var _ticks := 0
var _done := false

func setup(appearance: Dictionary) -> void:
	centered = false
	offset = Vector2(-32, -56)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var atlas: Texture2D = appearance.get("atlas") as Texture2D
	_frames.clear()
	if atlas == null:
		return
	for index in 32:
		var frame := AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2((index % 8) * 68 + 2, (index / 8) * 68 + 2, 64, 64)
		_frames.append(frame)
	play("idle", true)

func play(next: String, restart: bool = false) -> void:
	if not CLIPS.has(next) or (state == next and not restart):
		return
	state = next
	_frame = 0
	_ticks = int(CLIPS[state][1])
	_done = false
	_show()

func tick() -> void:
	if state.is_empty() or _done:
		return
	_ticks -= 1
	if _ticks > 0:
		return
	_frame += 1
	if _frame >= CLIPS[state][0].size():
		if not bool(CLIPS[state][2]):
			_frame -= 1
			_done = true
		else:
			_frame = 0
	_ticks = int(CLIPS[state][1])
	_show()

func _show() -> void:
	if not _frames.is_empty() and not state.is_empty():
		texture = _frames[int(CLIPS[state][0][_frame])]
