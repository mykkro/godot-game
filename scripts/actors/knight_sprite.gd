class_name KnightSprite
extends Sprite2D

const ANIMS          := ["Idle", "Walk"]
const DIR_COUNT      := 8
const WALK_FPS_MULT  := 2.0

var _textures:    Dictionary = {}
var _frame_rects: Dictionary = {}
var _anim_fps:    Dictionary = {}

var _anim:      String = "Idle"
var _dir:       int    = 1
var _frame_idx: int    = 0
var _frame_acc: float  = 0.0
var _fps:       float  = 7.0
var _frames:    Array  = []


func _ready() -> void:
	for anim in ANIMS:
		for dir in range(1, DIR_COUNT + 1):
			var key       := "%s_%d" % [anim, dir]
			var png       := "res://media/knight-basic/%s/Knight_%s_dir%d.png" % [anim, anim, dir]
			var json_path := "res://media/knight-basic/%s/Knight_%s_dir%d.json" % [anim, anim, dir]

			var tex := load(png) as Texture2D
			if tex == null:
				push_error("KnightSprite: texture not found: " + png)
				continue
			_textures[key] = tex

			var f := FileAccess.open(json_path, FileAccess.READ)
			if f == null:
				push_error("KnightSprite: JSON not found: " + json_path)
				continue
			var raw: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if raw == null:
				push_error("KnightSprite: JSON parse failed: " + json_path)
				continue

			var rects: Array[Rect2] = []
			for entry in raw["frames"]:
				var fr: Dictionary = entry["frame"]
				rects.append(Rect2(fr["x"], fr["y"], fr["w"], fr["h"]))
			_frame_rects[key] = rects

			_anim_fps[key] = float(raw["meta"]["frameAnimations"][0]["fps"])

	_apply_anim()


func _apply_anim() -> void:
	var key := "%s_%d" % [_anim, _dir]
	if not _textures.has(key):
		return
	_frames        = _frame_rects[key]
	_fps           = _anim_fps[key]
	texture        = _textures[key]
	region_enabled = true
	region_rect    = _frames[_frame_idx]


func update_anim(is_moving: bool, heading: float) -> void:
	var new_anim := "Walk" if is_moving else "Idle"
	var new_dir  := _heading_to_dir(heading)
	if new_anim == _anim and new_dir == _dir:
		return
	_anim      = new_anim
	_dir       = new_dir
	_frame_idx = 0
	_frame_acc = 0.0
	_apply_anim()


func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	_frame_acc += delta
	var effective_fps := _fps * (WALK_FPS_MULT if _anim == "Walk" else 1.0)
	var spf := 1.0 / effective_fps
	while _frame_acc >= spf:
		_frame_acc -= spf
		_frame_idx  = (_frame_idx + 1) % _frames.size()
	region_rect = _frames[_frame_idx]


static func _heading_to_dir(heading: float) -> int:
	# Asset mapping: dir1=SW, dir2=W, dir3=NW, dir4=N, dir5=NE, dir6=E, dir7=SE, dir8=S
	# +5 offset shifts so that East (0°, idx=0) maps to dir6.
	var deg := fposmod(rad_to_deg(heading), 360.0)
	var idx  := (int(round(deg / 45.0)) + 5) % 8
	return idx + 1
