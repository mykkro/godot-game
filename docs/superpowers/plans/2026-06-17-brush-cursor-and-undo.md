# Brush Cursor Scaling & Undo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the map editor hover cursor match the active brush size, and add Ctrl+Z undo (per stroke, no redo, stack capped at 50).

**Architecture:** Two independent features. The cursor fix threads brush size from `EditorUI` through `map_editor.gd` down to `ChunkEditorNode._draw()`, which self-clips to its own bounds. Undo captures per-cell snapshots into a pending record that is pushed to a stack on mouse release; Ctrl+Z pops and restores. No new files.

**Tech Stack:** GDScript 4, Godot 4. No automated test runner — each task ends with a manual verification step and a commit.

---

## Files Modified

| File | What changes |
|------|-------------|
| `scripts/editor/chunk_editor_node.gd` | `set_hover()` signature; `_draw()` brush highlight loop |
| `scripts/editor/editor_input.gd` | Add `stroke_started` / `stroke_ended` signals |
| `scripts/editor/map_editor.gd` | Hover passes world center + brush size; undo stack; Ctrl+Z handler |

---

## Task 1: Update `ChunkEditorNode.set_hover()` for multi-cell brush highlighting

**Files:**
- Modify: `scripts/editor/chunk_editor_node.gd`

- [ ] **Step 1: Replace the `_hover_cell` field and `set_hover()` method**

In `chunk_editor_node.gd`, replace lines 14–26:

```gdscript
# OLD — remove these two lines:
var _hover_cell:  Vector2i  = Vector2i(-1, -1)

func set_hover(local_cell: Vector2i) -> void:
    if local_cell != _hover_cell:
        _hover_cell = local_cell
        queue_redraw()
```

with:

```gdscript
var _hover_world_center: Vector2i = Vector2i(-1, -1)
var _hover_brush_size:   int      = 1


func set_hover(world_center: Vector2i, brush_size: int) -> void:
    if world_center != _hover_world_center or brush_size != _hover_brush_size:
        _hover_world_center = world_center
        _hover_brush_size   = brush_size
        queue_redraw()
```

- [ ] **Step 2: Replace the hover highlight block inside `_draw()`**

In `_draw()`, find the existing hover highlight block (lines 78–86):

```gdscript
# Hover highlight.
if _hover_cell.x >= 0 and _hover_cell.x < CHUNK_SIZE \
        and _hover_cell.y >= 0 and _hover_cell.y < CHUNK_SIZE:
    var hx := _hover_cell.x * CELL_SIZE
    var hy := _hover_cell.y * CELL_SIZE
    draw_rect(Rect2(hx, hy, CELL_SIZE, CELL_SIZE),
            Color(1.0, 1.0, 0.5, 0.30), true)
    draw_rect(Rect2(hx, hy, CELL_SIZE, CELL_SIZE),
            Color(1.0, 1.0, 0.5, 0.80), false, 1.5)
```

Replace it with:

```gdscript
# Hover highlight — draw every cell of the brush that falls in this chunk.
if _hover_world_center.x >= 0:
    var half    := _hover_brush_size / 2
    var chunk_x := _data.chunk_x
    var chunk_y := _data.chunk_y
    for dy in range(-half, half + 1):
        for dx in range(-half, half + 1):
            var lx := (_hover_world_center.x + dx) - chunk_x * CHUNK_SIZE
            var ly := (_hover_world_center.y + dy) - chunk_y * CHUNK_SIZE
            if lx < 0 or lx >= CHUNK_SIZE or ly < 0 or ly >= CHUNK_SIZE:
                continue
            var hx := lx * CELL_SIZE
            var hy := ly * CELL_SIZE
            draw_rect(Rect2(hx, hy, CELL_SIZE, CELL_SIZE),
                    Color(1.0, 1.0, 0.5, 0.30), true)
            draw_rect(Rect2(hx, hy, CELL_SIZE, CELL_SIZE),
                    Color(1.0, 1.0, 0.5, 0.80), false, 1.5)
```

- [ ] **Step 3: Verify manually**

Open the project in Godot and run the map editor. Move the mouse over the map with brush size 1 — the highlight should still be a single cell. Check that there are no script errors in the Output panel.

- [ ] **Step 4: Commit**

```bash
git add scripts/editor/chunk_editor_node.gd
git commit -m "feat: chunk_editor_node set_hover takes world center + brush size"
```

---

## Task 2: Pass world center + brush size from `map_editor.gd`

**Files:**
- Modify: `scripts/editor/map_editor.gd`

- [ ] **Step 1: Update `_on_hover_cell` to call the new `set_hover` signature**

In `map_editor.gd`, replace the existing `_on_hover_cell` function (lines 271–282):

```gdscript
func _on_hover_cell(cc: Vector2i, lc: Vector2i) -> void:
    _ui.set_chunk_coords(cc)
    _ui.set_cell_coords(lc)
    _ui.set_world_coords(cc.x * ChunkData.CHUNK_SIZE + lc.x, cc.y * ChunkData.CHUNK_SIZE + lc.y)
    if _chunks.has(cc):
        var cell := (_chunks[cc] as ChunkEditorNode).get_data().get_cell(lc.x, lc.y)
        if cell != null:
            var overlay := (_chunks[cc] as ChunkEditorNode).get_data().get_terrain_overlay(lc.x, lc.y)
            _ui.set_hover_terrain(cell.terrain_type, overlay)
    for coord in _chunks.keys():
        (_chunks[coord] as ChunkEditorNode).set_hover(
                lc if coord == cc else Vector2i(-1, -1))
```

with:

```gdscript
func _on_hover_cell(cc: Vector2i, lc: Vector2i) -> void:
    _ui.set_chunk_coords(cc)
    _ui.set_cell_coords(lc)
    _ui.set_world_coords(cc.x * ChunkData.CHUNK_SIZE + lc.x, cc.y * ChunkData.CHUNK_SIZE + lc.y)
    if _chunks.has(cc):
        var cell := (_chunks[cc] as ChunkEditorNode).get_data().get_cell(lc.x, lc.y)
        if cell != null:
            var overlay := (_chunks[cc] as ChunkEditorNode).get_data().get_terrain_overlay(lc.x, lc.y)
            _ui.set_hover_terrain(cell.terrain_type, overlay)
    var world_center := Vector2i(cc.x * ChunkData.CHUNK_SIZE + lc.x,
                                 cc.y * ChunkData.CHUNK_SIZE + lc.y)
    var brush_size   := _ui.get_brush_size()
    for coord in _chunks.keys():
        (_chunks[coord] as ChunkEditorNode).set_hover(world_center, brush_size)
```

- [ ] **Step 2: Verify brush cursor scaling manually**

Run the map editor. Switch to brush size 3, 5, 7, and 9. For each size, the hover highlight should form an N×N square of cells centered on the mouse. At chunk edges, the highlight should extend into the adjacent chunk (visible because adjacent chunks are loaded). No script errors should appear.

- [ ] **Step 3: Commit**

```bash
git add scripts/editor/map_editor.gd
git commit -m "feat: brush cursor scales to active brush size, cross-chunk aware"
```

---

## Task 3: Add stroke boundary signals to `EditorInput`

**Files:**
- Modify: `scripts/editor/editor_input.gd`

- [ ] **Step 1: Add the two new signals**

At the top of `editor_input.gd`, after the existing signals (after line 6), add:

```gdscript
signal stroke_started
signal stroke_ended
```

- [ ] **Step 2: Emit the signals on mouse button press/release**

In `_unhandled_input`, replace the `InputEventMouseButton` handling block (lines 25–35):

```gdscript
if event is InputEventMouseButton:
    var mb := event as InputEventMouseButton
    match mb.button_index:
        MOUSE_BUTTON_LEFT:
            _paint_held = mb.pressed
            if mb.pressed:
                _emit_paint(mb.position)
        MOUSE_BUTTON_RIGHT:
            _erase_held = mb.pressed
            if mb.pressed:
                _emit_erase(mb.position)
```

with:

```gdscript
if event is InputEventMouseButton:
    var mb := event as InputEventMouseButton
    match mb.button_index:
        MOUSE_BUTTON_LEFT:
            _paint_held = mb.pressed
            if mb.pressed:
                stroke_started.emit()
                _emit_paint(mb.position)
            else:
                stroke_ended.emit()
        MOUSE_BUTTON_RIGHT:
            _erase_held = mb.pressed
            if mb.pressed:
                stroke_started.emit()
                _emit_erase(mb.position)
            else:
                stroke_ended.emit()
```

- [ ] **Step 3: Verify no regressions**

Run the map editor. Paint and erase still work normally. Check Output for errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/editor/editor_input.gd
git commit -m "feat: EditorInput emits stroke_started/stroke_ended on mouse press/release"
```

---

## Task 4: Add undo infrastructure to `map_editor.gd`

**Files:**
- Modify: `scripts/editor/map_editor.gd`

- [ ] **Step 1: Add undo state variables**

At the top of `map_editor.gd`, after the existing `var` block (after line 17), add:

```gdscript
const UNDO_MAX := 50

var _undo_stack:        Array      = []   # Array of Array[Dictionary] — per-stroke records
var _pending_record:    Array      = []   # Snapshots for the in-progress stroke
var _stroke_cells_seen: Dictionary = {}   # Keys already snapshotted this stroke
```

- [ ] **Step 2: Connect stroke signals in `_connect_signals()`**

In `_connect_signals()` (lines 96–103), add two lines after the existing `_input_node` connections:

```gdscript
func _connect_signals() -> void:
    _input_node.paint_cell.connect(_on_paint_cell)
    _input_node.erase_cell.connect(_on_right_click_cell)
    _input_node.hover_cell.connect(_on_hover_cell)
    _input_node.stroke_started.connect(_on_stroke_started)
    _input_node.stroke_ended.connect(_on_stroke_ended)

    _ui.save_pressed.connect(_on_save)
    _ui.menu_pressed.connect(_on_go_to_menu)
    _ui.autosave_toggled.connect(func(on: bool): _autosave = on)
```

- [ ] **Step 3: Add stroke start/end handlers**

Add these two functions anywhere in `map_editor.gd` (e.g. after `_mark_dirty()`):

```gdscript
func _on_stroke_started() -> void:
    _pending_record    = []
    _stroke_cells_seen = {}


func _on_stroke_ended() -> void:
    if _pending_record.is_empty():
        return
    _undo_stack.append(_pending_record)
    if _undo_stack.size() > UNDO_MAX:
        _undo_stack.pop_front()
    _pending_record    = []
    _stroke_cells_seen = {}
```

- [ ] **Step 4: Add the snapshot helper**

Add this function in `map_editor.gd`:

```gdscript
func _snapshot_cell(cc: Vector2i, lc: Vector2i) -> void:
    var key := "%d,%d:%d,%d" % [cc.x, cc.y, lc.x, lc.y]
    if _stroke_cells_seen.has(key):
        return
    if not _chunks.has(cc):
        return
    var data := (_chunks[cc] as ChunkEditorNode).get_data()
    var cell := data.get_cell(lc.x, lc.y)
    if cell == null:
        return
    _stroke_cells_seen[key] = true
    _pending_record.append({
        "cc":             cc,
        "lc":             lc,
        "terrain":        cell.terrain_type,
        "is_obstacle":    cell.is_obstacle,
        "objects":        cell.objects.duplicate(),
        "overlay":        data.get_terrain_overlay(lc.x, lc.y),
        "chest_variant":  data.get_chest_variant(lc.x, lc.y),
        "chest_contents": data.get_chest_contents(lc.x, lc.y),
        "rock_variant":   data.get_rock_variant(lc.x, lc.y),
        "monster":        data.get_monster_placement(lc.x, lc.y),
    })
```

Note: `get_chest_contents` can return `null` (key absent) or an `Array`. Both values are stored as-is so restore can distinguish "never set" from "set to empty".

- [ ] **Step 5: Verify no regressions**

Run the map editor. Paint and erase still work. No errors in Output.

- [ ] **Step 6: Commit**

```bash
git add scripts/editor/map_editor.gd
git commit -m "feat: undo stack infrastructure — stroke signals, snapshot helper, push/pop"
```

---

## Task 5: Hook `_snapshot_cell` into paint and erase

**Files:**
- Modify: `scripts/editor/map_editor.gd`

- [ ] **Step 1: Snapshot inside `_paint_single_cell`**

In `_paint_single_cell(cc, lc)`, add `_snapshot_cell(cc, lc)` as the very first line of the function (before any reads of `terrain_sel`, etc.):

```gdscript
func _paint_single_cell(cc: Vector2i, lc: Vector2i) -> void:
    _snapshot_cell(cc, lc)      # ← ADD THIS LINE
    if _chest_editor.visible:
        return
    # ... rest unchanged ...
```

- [ ] **Step 2: Snapshot inside `_on_right_click_cell`**

In `_on_right_click_cell(cc, lc)`, add `_snapshot_cell(cc, lc)` right after the early-return guards (after the `cell == null` check), before any mutation:

```gdscript
func _on_right_click_cell(cc: Vector2i, lc: Vector2i) -> void:
    if _chest_editor.visible:
        return
    if not _chunks.has(cc):
        return
    var chunk_node := _chunks[cc] as ChunkEditorNode
    var data       := chunk_node.get_data()
    var cell       := data.get_cell(lc.x, lc.y)
    if cell == null:
        return

    _snapshot_cell(cc, lc)      # ← ADD THIS LINE

    if cell.objects.has(MapObject.Type.CHEST_SMALL):
    # ... rest unchanged ...
```

- [ ] **Step 3: Verify no regressions**

Run the map editor. Paint and erase still work. No errors in Output.

- [ ] **Step 4: Commit**

```bash
git add scripts/editor/map_editor.gd
git commit -m "feat: snapshot cell state before each paint/erase for undo"
```

---

## Task 6: Add Ctrl+Z handler and undo restore logic

**Files:**
- Modify: `scripts/editor/map_editor.gd`

- [ ] **Step 1: Add the `_undo()` restore function**

Add this function in `map_editor.gd`:

```gdscript
func _undo() -> void:
    if _undo_stack.is_empty():
        return
    var record: Array = _undo_stack.pop_back()
    for snap in record:
        var cc: Vector2i = snap["cc"]
        var lc: Vector2i = snap["lc"]
        var chunk_node   := _ensure_chunk(cc)
        var data         := chunk_node.get_data()
        var cell         := data.get_cell(lc.x, lc.y)
        if cell == null:
            continue
        cell.terrain_type = snap["terrain"]
        cell.is_obstacle  = snap["is_obstacle"]
        cell.objects      = (snap["objects"] as Array).duplicate()
        data.set_terrain_overlay(lc.x, lc.y, snap["overlay"])
        data.set_chest_variant(lc.x, lc.y, snap["chest_variant"])
        var cc_val = snap["chest_contents"]
        if cc_val == null:
            data.chest_contents.erase(lc.x + lc.y * ChunkData.CHUNK_SIZE)
        else:
            data.set_chest_contents(lc.x, lc.y, (cc_val as Array).duplicate())
        data.set_rock_variant(lc.x, lc.y, snap["rock_variant"])
        data.set_monster_placement(lc.x, lc.y, snap["monster"])
        chunk_node.set_cell(lc.x, lc.y, cell)
    _mark_dirty()
```

Note: `set_terrain_overlay` with `""` calls `erase_terrain_overlay` internally (see `chunk_data.gd:158-162`), so passing the stored overlay string handles both "overlay present" and "no overlay" cases correctly.

- [ ] **Step 2: Handle Ctrl+Z in `_input()`**

The existing `_input()` in `map_editor.gd` only handles mouse wheel events. Extend it to also handle the key event:

```gdscript
func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        var ke := event as InputEventKey
        if ke.pressed and not ke.echo and ke.ctrl_pressed and ke.keycode == KEY_Z:
            _undo()
            get_viewport().set_input_as_handled()
            return

    if not (event is InputEventMouseButton):
        return
    var mb := event as InputEventMouseButton
    if mb.button_index != MOUSE_BUTTON_WHEEL_UP and mb.button_index != MOUSE_BUTTON_WHEEL_DOWN:
        return
    var vp_w := get_viewport().get_visible_rect().size.x
    if mb.position.x < vp_w - EditorUI.PANEL_WIDTH:
        return
    # Wheel over right panel: scroll the palette, never zoom the map.
    var scroll := _ui.get_palette_scroll()
    if scroll != null and mb.pressed:
        var delta := 64 * (1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
        scroll.scroll_vertical += delta
    get_viewport().set_input_as_handled()
```

- [ ] **Step 3: Verify undo manually**

Run the map editor.

1. Paint a few terrain tiles with brush size 1. Press Ctrl+Z — the last painted cell should revert to its previous terrain.
2. Select brush size 5, paint a large area in one drag stroke. Press Ctrl+Z once — the entire area from that stroke should revert at once.
3. Erase (RMB) an object. Press Ctrl+Z — the object should reappear.
4. Paint 51 strokes. Press Ctrl+Z 50 times — all 50 should undo. The 51st Ctrl+Z should do nothing (stack is empty).
5. Verify no console errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/editor/map_editor.gd
git commit -m "feat: Ctrl+Z undo — per-stroke, 50-record stack, full cell state restore"
```

---

## Self-Review Notes

- **Spec coverage:** All spec sections covered — cursor (Task 1+2), stroke signals (Task 3), undo infrastructure (Task 4), snapshot hookup (Task 5), Ctrl+Z restore (Task 6). ✓
- **No placeholders:** All steps have complete code. ✓
- **Type consistency:** `set_hover(world_center: Vector2i, brush_size: int)` used consistently in Task 1 (definition) and Task 2 (callsite). Snapshot dict keys (`"cc"`, `"lc"`, `"terrain"`, etc.) match restore accessors in Task 6. ✓
- **`set_terrain_overlay("")`** correctly erases per `chunk_data.gd:158-162`. ✓
- **`chest_contents` null case** handled explicitly in restore (Task 6, Step 1). ✓
