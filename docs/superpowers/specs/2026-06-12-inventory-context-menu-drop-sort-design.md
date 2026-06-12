# Inventory Context Menu, Drop & Sort — Design Document

**Date:** 2026-06-12  
**Depends on:** `2026-06-12-topdown-rpg-design.md`

---

## 1. Overview

Two related inventory features:

1. **Context menu** — right-clicking an occupied inventory slot shows a small popup with a "Drop" action.
2. **Drop** — removes the item from the inventory and places it on the nearest passable, empty cell adjacent to the player.
3. **Sort** — a button in the inventory header sorts all items A→Z by display name.

---

## 2. Interaction Model

| Input | Result |
|---|---|
| Right-click occupied slot | Show context menu at mouse position |
| Click "Drop" in menu | Remove item, place on ground near player |
| Click outside menu / ESC | Dismiss menu, no action |
| Click "Sort" button | Sort inventory A→Z, refresh display |

Right-click on an **empty** slot does nothing. Left-click is unchanged (no action currently).

---

## 3. Context Menu Widget

Built once in `InventoryUI._ready()`, reused for every slot interaction.

**Structure:**
```
PanelContainer  (_context_menu)       ← direct child of InventoryUI (CanvasLayer)
  VBoxContainer
    Button "Drop"
```

**Styling:** matches existing dark panel style (`bg_color = Color(0.06, 0.06, 0.10, 0.93)`, same border/corner as `_panel`).

**Positioning:** appears at the mouse click position, clamped so it doesn't overflow the viewport edges.

**State:** `_context_slot_index: int = -1` tracks which slot the menu was opened for. Set to `-1` when menu is hidden.

**Dismissal:** any of:
- "Drop" button pressed (after action)
- Mouse click outside the context menu (detected in `_unhandled_input` via `MOUSE_BUTTON_LEFT` / `MOUSE_BUTTON_RIGHT`)
- KEY_ESCAPE (already handled; extend existing ESC logic)

### Slot input wiring

Each slot `PanelContainer` gets its `gui_input` signal connected during construction:

```
slot.gui_input.connect(_on_slot_gui_input.bind(slot_index))
```

`_on_slot_gui_input(event, slot_index)`:
- Ignore if slot is empty (`slot_index >= inventory.items.size()`)
- On `MOUSE_BUTTON_RIGHT` pressed: store `_context_slot_index = slot_index`, position and show `_context_menu`, call `accept_event()`

---

## 4. Drop — Signal Flow

### Signal

`InventoryUI` declares:
```gdscript
signal drop_requested(slot_index: int)
```

Emitted when the "Drop" button is pressed. `InventoryUI` does not touch the world directly.

### Wiring (Main._ready)

```gdscript
_inventory_ui.drop_requested.connect(_avatar.drop_item)
```

### Avatar.drop_item(slot_index: int)

1. Guard: return if `slot_index` out of range or inventory empty at that index.
2. Read `item_type := inventory.items[slot_index]`.
3. Call `_world.drop_item_near(position, item_type)`.  
   - If the world returns `false` (no free cell found within search radius), abort — do **not** remove from inventory. (Item stays in bag if there is no room on the ground.)
4. Remove item from inventory: `inventory.items.remove_at(slot_index)`.
5. Call `_inventory_ui.notify_changed()`.

### World.drop_item_near(near: Vector2, item_type: int) → bool

Scans cells in an expanding square (Manhattan-distance order, max radius 8 cells) from the cell containing `near`:

- Cell must be passable (`!cell.is_obstacle`)
- Cell must have no existing objects (`cell.objects.is_empty()`) — keeps dropped items unambiguous
- On first match: `cell.add_object(item_type)`, then call `ChunkNode.spawn_pickable_at(item_type, lx, ly)`, return `true`
- If no cell found after full search: return `false`

`World` must expose the loaded `ChunkNode` for a coord:
```gdscript
func get_chunk_node(coord: Vector2i) -> ChunkNode:
    return _nodes.get(coord, null)
```

### ChunkNode.spawn_pickable_at(item_type: int, lx: int, ly: int)

```gdscript
func spawn_pickable_at(item_type: int, lx: int, ly: int) -> void:
    var node := PickableNode.new()
    node.position = Vector2((lx + 0.5) * CELL_SIZE, (ly + 0.5) * CELL_SIZE)
    add_child(node)
    node.initialize(item_type, lx, ly, _data)
```

Mirrors the logic already in `_spawn_pickables()`.

---

## 5. Sort

A `Button` ("Sort") added to the inventory header row, right-aligned next to the title.

On pressed:
```gdscript
inventory.items.sort_custom(
    func(a, b): return PickableItemDef.get_display_name(a) < PickableItemDef.get_display_name(b)
)
_refresh()
```

No persistence needed — sort order is not saved; items are always loaded in pickup order.

---

## 6. Files Changed

| File | Change |
|---|---|
| `scripts/ui/inventory_ui.gd` | Context menu widget, slot `gui_input` wiring, `drop_requested` signal, Sort button |
| `scripts/actors/avatar.gd` | `drop_item(slot_index)` method |
| `scripts/world/world.gd` | `drop_item_near(near, item_type) → bool`, `get_chunk_node(coord) → ChunkNode` |
| `scripts/world/chunk_node.gd` | `spawn_pickable_at(item_type, lx, ly)` method |
| `scripts/main.gd` | Wire `drop_requested` → `avatar.drop_item` |

---

## 7. Edge Cases

| Case | Behaviour |
|---|---|
| No free cell within 8-cell radius | Drop silently fails; item stays in inventory |
| Player standing in water / impassable terrain | Search still finds nearest land cell |
| Inventory open while context menu visible, then ESC pressed | Menu dismissed first; inventory closes on second ESC |
| Item dropped on chunk boundary | `drop_item_near` uses `world.get_cell_at` which handles cross-chunk lookup correctly |
