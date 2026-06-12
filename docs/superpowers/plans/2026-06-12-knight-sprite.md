# Knight Sprite for Avatar — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the avatar's `_draw()` circle with an animated 8-directional knight sprite that plays Idle or Walk animation based on movement and facing direction.

**Architecture:** A new `KnightSprite` node (`scripts/actors/knight_sprite.gd`, extends `Sprite2D`) handles all texture loading, frame parsing, and animation logic. `Avatar` removes its `_draw()` method, instantiates `KnightSprite` in `_ready()`, and calls `_sprite.update_anim(is_moving, heading)` at the end of each `_physics_process`. The node uses `region_rect` on itself to show the current frame from the spritesheet.

**Tech Stack:** Godot 4.6 GDScript. No automated test framework — verification is manual.

---

## Files

| File | Change |
|---|---|
| `scripts/actors/knight_sprite.gd` | **Create** — animated 8-dir sprite node |
| `scripts/actors/avatar.gd` | Remove `_draw()` and `queue_redraw()`, add `KnightSprite` child, call `update_anim` |

---

## Asset Reference

Spritesheets are at `res://media/knight-basic/{Anim}/Knight_{Anim}_dir{N}.png`.  
JSON metadata at `res://media/knight-basic/{Anim}/Knight_{Anim}_dir{N}.json`.

**Animations used:** Idle (17 frames, 7 fps), Walk (11 frames, 10 fps)  
**Directions:** dir1=E, dir2=SE, dir3=S, dir4=SW, dir5=W, dir6=NW, dir7=N, dir8=NE  
**Frame size:** 256×256 px per frame

**JSON structure example (Idle/dir1):**
```json
{
  "frames": [
    {"frame": {"x": 0, "y": 0, "w": 256, "h": 256}, "duration": 143},
    ...
  ],
  "meta": {
    "frameAnimations": [{"name": "default", "fps": 7, "from": 0, "to": 16}]
  }
}
```

---

## Task 1: Create `KnightSprite` node

**Files:**
- Create: `scripts/actors/knight_sprite.gd`

- [ ] **Step 1: Create the file with class declaration and state variables**

Create `scripts/actors/knight_sprite.gd` with this content:

```gdscript
class_name KnightSprite
extends Sprite2D

const ANIMS    := ["Idle", "Walk"]
const DIR_COUNT := 8

var _textures:    Dictionary = {}  # "Idle_1" -> Texture2D
var _frame_rects: Dictionary = {}  # "Idle_1" -> Array[Rect2]
var _anim_fps:    Dictionary = {}  # "Idle_1" -> float

var _anim:      String = "Idle"
var _dir:       int    = 1
var _frame_idx: int    = 0
var _frame_acc: float  = 0.0
var _fps:       float  = 7.0
var _frames:    Array  = []
```

- [ ] **Step 2: Add `_ready` — load all textures and parse all JSON frame rects**

Append to the file:

```gdscript
func _ready() -> void:
	for anim in ANIMS:
		for dir in range(1, DIR_COUNT + 1):
			var key  := "%s_%d" % [anim, dir]
			var png  := "res://media/knight-basic/%s/Knight_%s_dir%d.png" % [anim, anim, dir]
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
			var raw := JSON.parse_string(f.get_as_text())
			f.close()
			if raw == null:
				push_error("KnightSprite: JSON parse failed: " + json_path)
				continue

			var rects: Array[Rect2] = []
			for entry in raw["frames"]:
				var fr: Dictionary = entry["frame"]
				rects.append(Rect2(fr["x"], fr["y"], fr["w"], fr["h"]))
			_frame_rects[key] = rects

			var fps_val: float = float(raw["meta"]["frameAnimations"][0]["fps"])
			_anim_fps[key] = fps_val

	_apply_anim()


func _apply_anim() -> void:
	var key := "%s_%d" % [_anim, _dir]
	if not _textures.has(key):
		return
	_frames    = _frame_rects[key]
	_fps       = _anim_fps[key]
	texture    = _textures[key]
	region_enabled = true
	region_rect    = _frames[_frame_idx]
```

- [ ] **Step 3: Add `update_anim` — called by Avatar each physics frame**

Append to the file:

```gdscript
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
```

- [ ] **Step 4: Add `_process` — advance frame timer**

Append to the file:

```gdscript
func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	_frame_acc += delta
	var spf := 1.0 / _fps
	while _frame_acc >= spf:
		_frame_acc -= spf
		_frame_idx  = (_frame_idx + 1) % _frames.size()
	region_rect = _frames[_frame_idx]
```

- [ ] **Step 5: Add the static direction helper**

Append to the file:

```gdscript
static func _heading_to_dir(heading: float) -> int:
	var deg := fposmod(rad_to_deg(heading), 360.0)
	var idx  := int(round(deg / 45.0)) % 8
	return idx + 1
```

- [ ] **Step 6: Verify the file parses without errors**

Open Godot editor. The script should appear in the FileSystem dock with no red error. No scene change yet — no behaviour change expected.

---

## Task 2: Wire `KnightSprite` into `Avatar`

**Files:**
- Modify: `scripts/actors/avatar.gd`

- [ ] **Step 1: Add the `_sprite` field declaration**

In `scripts/actors/avatar.gd`, after the `var _pickup_area: Area2D = null` line, add:

```gdscript
var _sprite: KnightSprite = null
```

- [ ] **Step 2: Instantiate and attach `KnightSprite` in `_ready`**

In `avatar.gd`, replace the existing `_ready` method:

```gdscript
func _ready() -> void:
	collision_radius = 14.0
	super._ready()
	_setup_pickup_area()

	_sprite = KnightSprite.new()
	_sprite.scale  = Vector2(0.35, 0.35)
	_sprite.offset = Vector2(0.0, -45.0)
	add_child(_sprite)
```

- [ ] **Step 3: Call `update_anim` and remove `queue_redraw` in `_physics_process`**

Replace the entire `_physics_process` method with:

```gdscript
func _physics_process(_delta: float) -> void:
	var dir := _read_input()

	if dir != Vector2.ZERO:
		dir      = dir.normalized()
		heading  = dir.angle()
		velocity = dir * MOVE_SPEED
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	if _world != null:
		_world.update_avatar_position(position)
	if _fog_manager != null:
		_fog_manager.update_avatar_position(position)

	if _sprite != null:
		_sprite.update_anim(velocity != Vector2.ZERO, heading)
```

- [ ] **Step 4: Remove `_draw`**

Delete the entire `_draw` method from `avatar.gd`:

```gdscript
func _draw() -> void:
	draw_circle(Vector2.ZERO, collision_radius, Color(0.20, 0.55, 1.00))
	var tip := Vector2(cos(heading), sin(heading)) * (collision_radius + 5.0)
	draw_line(Vector2.ZERO, tip, Color.WHITE, 2.5)
	draw_arc(Vector2.ZERO, collision_radius, 0.0, TAU, 24,
			 Color(0.10, 0.30, 0.70), 1.5)
```

- [ ] **Step 5: Verify in editor**

Open the Godot editor. Confirm both scripts have no parse errors in the editor output.

- [ ] **Step 6: Run the game (F5) and verify**

Run the game. Check:
- The player avatar now shows a knight sprite instead of a blue circle
- Standing still: Idle animation plays, loops smoothly
- Moving with arrow keys / WASD: Walk animation plays
- Facing direction updates when moving (sprite changes direction)
- Stopping: animation switches back to Idle
- No errors in the Output panel
- Picking up items and dropping via inventory still works

- [ ] **Step 7: Commit**

```
git add scripts/actors/knight_sprite.gd scripts/actors/avatar.gd
git commit -m "feat: replace avatar circle with animated 8-dir knight sprite"
```

---

## Done

Both tasks complete. The avatar displays an animated knight with directional Idle/Walk sprites. `_draw()` is gone; all visual logic lives in `KnightSprite`.
