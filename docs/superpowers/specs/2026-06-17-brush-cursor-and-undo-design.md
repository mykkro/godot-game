# Map Editor: Brush Cursor Scaling & Undo

**Date:** 2026-06-17

## Overview

Two improvements to `map_editor.gd` and `chunk_editor_node.gd`:

1. The hover cursor highlights the full brush area (not always 1×1).
2. Ctrl+Z undoes the last paint or erase stroke.

---

## Feature 1 — Brush Cursor Scaling

### Goal

When the user hovers over the map with a brush size > 1, the yellow highlight rectangle should cover all cells that would be painted, including cells that cross into adjacent chunks.

### Changes

**`scripts/editor/chunk_editor_node.gd`**

- Replace `set_hover(local_cell: Vector2i)` with `set_hover(world_center: Vector2i, brush_size: int)`.
- Store both as `_hover_world_center` and `_hover_brush_size`.
- Sentinel: `world_center == Vector2i(-1, -1)` means no hover (draws nothing).
- In `_draw()`, replace the current single-cell highlight block with:
  - Compute `half = brush_size / 2`
  - Loop `dy` in `[-half, +half]`, `dx` in `[-half, +half]`
  - Convert each `(world_center.x + dx, world_center.y + dy)` to this chunk's local coords
  - Skip cells outside `[0, CHUNK_SIZE)` in either axis
  - Draw fill + border rect for each in-bounds cell

**`scripts/editor/map_editor.gd` — `_on_hover_cell(cc, lc)`**

- Compute `world_center = Vector2i(cc.x * CHUNK_SIZE + lc.x, cc.y * CHUNK_SIZE + lc.y)`
- Read `brush_size = _ui.get_brush_size()`
- Call `chunk_node.set_hover(world_center, brush_size)` on **every** loaded chunk (not just the one under the mouse), so cross-chunk brush areas are highlighted in all relevant chunks.
- Pass `Vector2i(-1, -1), 1` to chunks that are not near the cursor (or just always pass world_center — each chunk self-clips).

### No new files. Two methods changed.

---

## Feature 2 — Undo (Ctrl+Z, no redo)

### Goal

One Ctrl+Z undoes the last complete paint or erase stroke (all cells touched between LMB/RMB press and release). Stack capped at 50 records.

### Data structures (added to `map_editor.gd`)

```
_undo_stack: Array        # Array of undo records (oldest at front, newest at back)
_pending_record: Array    # Per-cell snapshots collected during current stroke
_stroke_cells_seen: Dictionary  # Set of "cc:lc" keys already snapshotted this stroke
_stroke_active: bool      # True while LMB or RMB is held
```

**Per-cell snapshot dictionary:**
```
{
  "cc": Vector2i,
  "lc": Vector2i,
  "terrain": String,
  "is_obstacle": bool,
  "objects": Array,         # duplicated
  "overlay": String,
  "chest_variant": int,
  "chest_contents": Array,  # duplicated
  "rock_variant": int,
  "monster": String,
}
```

### Flow

**LMB/RMB pressed** (detected in `EditorInput` via new signal `stroke_started` / `stroke_ended`, or handled directly in `map_editor._input`):
- Set `_stroke_active = true`
- Clear `_pending_record` and `_stroke_cells_seen`

**Before each `_paint_single_cell(cc, lc)` or erase call:**
- Compute key `"%d,%d:%d,%d" % [cc.x, cc.y, lc.x, lc.y]`
- If key not in `_stroke_cells_seen`: snapshot current cell state into `_pending_record`, add key to `_stroke_cells_seen`

**LMB/RMB released:**
- Set `_stroke_active = false`
- If `_pending_record` not empty: append to `_undo_stack`, cap stack at 50 (pop front if over limit)
- Clear `_pending_record` and `_stroke_cells_seen`

**Ctrl+Z (`_input` in `map_editor.gd`):**
- If `_undo_stack` is empty: no-op
- Pop last record from `_undo_stack`
- For each snapshot in record:
  - Get or ensure chunk node
  - Restore `CellData` (terrain, is_obstacle, objects)
  - Restore `ChunkData` overlay, chest_variant, chest_contents, rock_variant, monster
  - Call `chunk_node.set_cell(lc.x, lc.y, cell)` to trigger redraw
- Call `_mark_dirty()`

### Stroke boundary detection

`EditorInput` already tracks `_paint_held` and `_erase_held`. Add two new signals:
- `stroke_started` — emitted on first LMB/RMB press
- `stroke_ended` — emitted on LMB/RMB release

`map_editor.gd` connects these to start/end stroke bookkeeping.

### Stack cap

If `_undo_stack.size() > 50` after a push, remove the front element (`_undo_stack.pop_front()`).

### Keyboard shortcut

Handled in `map_editor.gd`'s `_input(event)`. Check for `InputEventKey` with `keycode == KEY_Z` and `ctrl_pressed == true` (and `pressed == true`, `echo == false`). Call `get_viewport().set_input_as_handled()` after processing.

### No new files. Changes in `editor_input.gd` (two signals) and `map_editor.gd` (undo logic).

---

## Files Changed

| File | Change |
|------|--------|
| `scripts/editor/chunk_editor_node.gd` | `set_hover()` signature + `_draw()` brush highlight loop |
| `scripts/editor/editor_input.gd` | Add `stroke_started` / `stroke_ended` signals |
| `scripts/editor/map_editor.gd` | Hover passes world_center+size; undo stack; Ctrl+Z handler |

No new files.
