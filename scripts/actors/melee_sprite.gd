class_name MeleeSprite
extends Sprite2D

const FRAME_W := 126
const FRAME_H := 132
const COLS    := 6
const ROWS    := 6
const FPS     := 7.0

var _textures:  Array[Texture2D] = []
var _frames:    Array[Rect2]     = []
var _frame_idx: int              = 0
var _frame_acc: float            = 0.0
var _dir:       int              = 1


func _ready() -> void:
	for d in range(1, 9):
		var tex := load("res://media/melee/Idle1/Boxer__Idle1_dir%d.png" % d) as Texture2D
		if tex == null:
			push_error("MeleeSprite: missing dir%d texture" % d)
		_textures.append(tex)

	# Scan which rows/cols have visible content using the first direction's image.
	if not _textures.is_empty() and _textures[0] != null:
		var img := _textures[0].get_image()
		for row in range(ROWS):
			for col in range(COLS):
				var r := Rect2i(col * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
				if not _is_frame_empty(img, r):
					_frames.append(Rect2(r))

	if _frames.is_empty():
		_frames.append(Rect2(0, 0, FRAME_W, FRAME_H))

	region_enabled = true
	_apply()


func set_dir(d: int) -> void:
	if d == _dir:
		return
	_dir       = d
	_frame_idx = 0
	_frame_acc = 0.0
	_apply()


func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	_frame_acc += delta
	var spf := 1.0 / FPS
	while _frame_acc >= spf:
		_frame_acc -= spf
		_frame_idx  = (_frame_idx + 1) % _frames.size()
	region_rect = _frames[_frame_idx]


func _apply() -> void:
	var idx := clampi(_dir - 1, 0, _textures.size() - 1)
	if _textures[idx] != null:
		texture     = _textures[idx]
		region_rect = _frames[_frame_idx % _frames.size()]


# Checks center pixel of each quadrant — fast and reliable for these sprites.
static func _is_frame_empty(img: Image, r: Rect2i) -> bool:
	var qw := r.size.x / 4
	var qh := r.size.y / 4
	for qy: int in [1, 2]:
		for qx: int in [1, 2]:
			var x: int = r.position.x + qx * qw
			var y: int = r.position.y + qy * qh
			if img.get_pixel(x, y).a > 0.01:
				return false
	return true
