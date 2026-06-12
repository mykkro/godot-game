# Knight Sprite for Avatar — Design Document

**Date:** 2026-06-12  
**Depends on:** `2026-06-12-topdown-rpg-design.md`

---

## 1. Overview

Replace the avatar's placeholder `_draw()` circle with an animated `KnightSprite` node driven by 8-directional sprite sheets and per-animation JSON metadata from `media/knight-basic/`.

---

## 2. Asset Format

Each animation has 8 direction variants. Each variant is:

| File | Content |
|---|---|
| `media/knight-basic/{Anim}/Knight_{Anim}_dir{N}.png` | Spritesheet; 256×256 px frames laid out in rows of up to 5 |
| `media/knight-basic/{Anim}/Knight_{Anim}_dir{N}.json` | Array of `{frame: {x,y,w,h}, duration}` entries + `meta.frameAnimations[0].fps` |

Available animations: **Idle** (17 frames, 7 fps), **Walk** (11 frames, 10 fps), Run, Attack, Die, Jump.  
Initial implementation uses **Idle** and **Walk** only.

### Direction mapping

Dirs are numbered 1–8, clockwise from East:

| dir | Compass | Godot heading (approx) |
|---|---|---|
| 1 | E | 0 |
| 2 | SE | π/4 |
| 3 | S | π/2 |
| 4 | SW | 3π/4 |
| 5 | W | π |
| 6 | NW | −3π/4 |
| 7 | N | −π/2 |
| 8 | NE | −π/4 |

---

## 3. Architecture

### New file: `scripts/actors/knight_sprite.gd`

`class_name KnightSprite extends Sprite2D`

Responsibilities:
- Load and cache all 16 textures (Idle×8 + Walk×8) on `_ready`
- Parse and cache all 16 frame-rect arrays from JSON
- Expose `update_anim(is_moving: bool, heading: float)` — called each physics frame by Avatar
- Advance frame index via `_process(delta)` using per-animation fps
- Switch spritesheet and reset frame when animation or direction changes

### Modified file: `scripts/actors/avatar.gd`

- Remove `_draw()` entirely
- In `_ready()`: instantiate `KnightSprite`, set scale, add as child
- In `_physics_process()`: after `move_and_slide()`, call `_sprite.update_anim(velocity != Vector2.ZERO, heading)`

---

## 4. Direction Snapping

Convert continuous `heading` (radians, Godot convention: 0 = right / East) to dir index 1–8:

```gdscript
static func _heading_to_dir(heading: float) -> int:
    var deg := fposmod(rad_to_deg(heading), 360.0)
    var idx  := int(round(deg / 45.0)) % 8   # 0-7, 0 = East
    return idx + 1                             # 1-8
```

`fposmod` ensures the result is always in [0, 360).

---

## 5. KnightSprite Internals

### State
```
_anim:      String   # "Idle" | "Walk"
_dir:       int      # 1–8
_frame_idx: int      # current frame within the animation
_frame_acc: float    # accumulated time (seconds)
_fps:       float    # from JSON meta
_frames:    Array    # Array of Rect2, for current anim+dir
_textures:  Dictionary  # "Idle_1" → Texture2D, "Walk_1" → Texture2D, …
_frame_rects: Dictionary  # "Idle_1" → Array[Rect2], …
```

### Texture/frame loading (in `_ready`)

For each `anim` in `["Idle", "Walk"]`, for `dir` in `1..8`:
1. Load PNG: `load("res://media/knight-basic/{anim}/Knight_{anim}_dir{dir}.png")`
2. Open and parse JSON: `FileAccess.open(…)` → `JSON.parse_string(…)`
3. Build `Array[Rect2]` from the `frames` array
4. Store fps from `meta.frameAnimations[0].fps`
5. Cache both under key `"{anim}_{dir}"`

### `update_anim(is_moving, heading)`

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
    var key    := "%s_%d" % [_anim, _dir]
    _frames    = _frame_rects[key]
    _fps       = _anim_fps[key]
    texture    = _textures[key]
    region_enabled = true
    region_rect    = _frames[0]
```

### `_process(delta)`

```gdscript
func _process(delta: float) -> void:
    _frame_acc += delta
    var spf := 1.0 / _fps
    while _frame_acc >= spf:
        _frame_acc -= spf
        _frame_idx  = (_frame_idx + 1) % _frames.size()
    region_rect = _frames[_frame_idx]
```

### Scale and offset

- `scale = Vector2(0.35, 0.35)` → 256 × 0.35 ≈ 90 px per frame (≈ 1.4 tiles)
- `offset = Vector2(0, -45)` → shift sprite up so feet align with the avatar's collision center rather than the sprite center

The avatar collision radius is 14 px; the sprite is purely visual and does not need to match pixel-precisely.

---

## 6. Files Changed

| File | Change |
|---|---|
| `scripts/actors/knight_sprite.gd` | **Create** — animated 8-dir sprite node |
| `scripts/actors/avatar.gd` | Remove `_draw()`, add `KnightSprite` child, call `update_anim` |

---

## 7. Edge Cases

| Case | Behaviour |
|---|---|
| JSON missing or malformed | `push_error`, fall back to first frame rect (no crash) |
| Texture file missing | Godot returns null; `push_error`, sprite stays invisible |
| `heading` exactly on boundary between two dirs | `round()` picks either neighbour deterministically |
| Avatar stops mid-diagonal | Direction retained from last movement heading; Idle animation plays |
