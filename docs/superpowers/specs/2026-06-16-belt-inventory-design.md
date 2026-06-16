# Belt Inventory Design

**Date:** 2026-06-16
**Status:** Approved

## Overview

A 5-slot belt inventory always visible at the bottom center of the game screen. Slots are mapped to keys 1–5 for instant item use during play. Only useable items (health and mana potions) can be placed in the belt. Drag-and-drop from the main inventory (when open) populates belt slots. Using a potion consumes one from the stack and shows floating feedback text above the avatar.

---

## Section 1 — Item Types & Useability

### New Item Types

Two new entries in `MapObject.Type`:

| Constant | Effect on use | Stack size |
|---|---|---|
| `HEALTH_POTION` | +20 HP (capped at `max_hp`) | 16 |
| `MANA_POTION` | +20 Mana (capped at `max_mana`) | 16 |

The existing `POTION = 5` is left untouched to avoid breaking save files.

### Useability Gate

`PickableItemDef.is_useable(type: int) -> bool` — returns `true` for `HEALTH_POTION` and `MANA_POTION`. This is the single authoritative check used everywhere: belt drop validation, inventory context menu, and any future item with a use effect.

### Display Names & Textures

`get_display_name()` and `get_texture()` in `PickableItemDef` gain entries for both new types.

---

## Section 2 — Belt Data Class

**File:** `scripts/inventory/belt.gd`

Stores 5 slots as an `Array` of `{type: int, count: int}` dicts, with `null` for empty slots — identical shape to `Inventory` slots.

### API

| Method | Description |
|---|---|
| `set_slot(index, type, count)` | Write a slot directly |
| `clear_slot(index)` | Set slot to null |
| `get_type(index) -> int` | Item type at slot, or -1 if empty |
| `get_count(index) -> int` | Stack count at slot, or 0 if empty |
| `has_item(index) -> bool` | True if slot is not null |
| `consume(index) -> int` | Decrements count by 1, clears if 0; returns consumed type or -1 |
| `to_dict() -> Dictionary` | Serialization |
| `from_dict(d)` | Deserialization |

### Ownership & Serialization

`Avatar` owns `belt: Belt` (initialized in `_ready()`, alongside `inventory`).

`SaveManager` gains `save_belt(belt: Belt)` and `load_belt() -> Belt`, called at the same points as `save_inventory` / `load_inventory` in `main.gd`.

Belt emits `belt_changed` signal whenever any slot is modified.

---

## Section 3 — BeltUI Scene

**Scene:** `scenes/ui/belt_ui.tscn`
**Script:** `scripts/ui/belt_ui.gd`

### Layout

- Root node: `CanvasLayer` (always on top, camera-independent)
- Child: `HBoxContainer` of 5 `PanelContainer` slot nodes
- Anchored: bottom-center of viewport, always visible, no toggle
- Style: semi-transparent dark pill (dark background, rounded corners, 1px border `#555`)
- Slot size: 44×44 px, 6px gap between slots

### Per-Slot Contents

- **Item icon** — `TextureRect`, same atlas lookup as `InventoryUI`
- **Stack badge** — yellow `Label`, bottom-right corner, hidden when count ≤ 1
- **Key label** — small grey `Label` (`1`–`5`), top-left corner, always shown
- **Empty state** — dimmed dark background, only key label visible

### Refresh

BeltUI connects to `belt.belt_changed`. On signal, calls `_refresh()` which redraws all 5 slots from current Belt data. No polling.

### Wiring

Added as a child node in `main.tscn`. `main.gd` passes the avatar's `belt` reference to BeltUI after the avatar is ready.

---

## Section 4 — Inventory Integration

### Drag Belt Slots ↔ Inventory

When the inventory is open (`I` key), belt slots act as additional drag-and-drop targets alongside inventory slots. The BeltUI slot nodes use `set_drag_forwarding()` pointed at `InventoryUI`'s existing `_get_drag_data` / `_can_drop_data` / `_drop_data` handlers — no parallel drag system.

Drop rules for inventory → belt:
- `PickableItemDef.is_useable(type)` must return `true`; otherwise drop is rejected silently
- Same type already in slot → merge (stack)
- Different type in slot → swap (old belt item returns to source inventory slot)

Dragging from belt → inventory slot works identically to any inventory-to-inventory drag.

### Context Menu "Use"

Right-clicking a useable item in the inventory appends a **"Use"** option at the top of the existing context menu (above Split / Drop). Selecting it:

1. Removes 1 from that inventory slot (via `inventory.remove_from_slot`)
2. Calls `avatar.apply_item_effect(type)` to apply HP/mana restore
3. Calls `avatar.show_use_feedback(type)` for floating text
4. Does **not** require the item to be in the belt first

---

## Section 5 — Using Items (Keys 1–5) & Visual Feedback

### Key Input

In `avatar.gd` `_unhandled_input`, handle `KEY_1` through `KEY_5`. Guard: only active when inventory is **not** open and game is not paused.

Pressing key `n` calls `use_belt_slot(n - 1)`:
1. `belt.consume(index)` → returns consumed type or -1 (slot empty / no item)
2. If -1: no-op
3. `apply_item_effect(type)` — modifies `stats.current_hp` or `stats.current_mana`, clamped to max; emits `stats.changed` so HUD bars update
4. `belt.belt_changed` emitted automatically by `consume()`
5. `show_use_feedback(type)` triggers the FloatingText

### `apply_item_effect(type: int)`

```
HEALTH_POTION → stats.current_hp = min(stats.current_hp + 20, stats.max_hp)
MANA_POTION   → stats.current_mana = min(stats.current_mana + 20, stats.max_mana)
```

Emits `stats.changed` signal.

### FloatingText

A reusable `Label` node, child of Avatar (world-space). On trigger:
- Text: `"+20 HP"` (green `#4edb6a`) or `"+20 Mana"` (blue `#3498db`)
- Tween: moves up 30px over 0.7s, alpha 1 → 0
- On finish: node hidden, position reset

Single node, re-triggered on each use (previous animation cancelled if still running).

### Starting Items

In `avatar.gd _ready()`, after belt initialization, when **no save file exists**:

```
belt.set_slot(0, MapObject.Type.HEALTH_POTION, 2)
belt.set_slot(1, MapObject.Type.MANA_POTION, 2)
```

---

## Files Touched / Created

| File | Change |
|---|---|
| `scripts/objects/map_object.gd` | Add `HEALTH_POTION`, `MANA_POTION` to Type enum |
| `scripts/objects/pickable_item_def.gd` | Add `is_useable()`, display names, textures, stack sizes for new types |
| `scripts/inventory/belt.gd` | **New** — Belt data class |
| `scripts/actors/avatar.gd` | Add `belt`, `use_belt_slot()`, `apply_item_effect()`, `show_use_feedback()`, starting items |
| `scripts/data/hero_stats.gd` | Emit `changed` after HP/mana modify (if not already) |
| `scripts/ui/inventory_ui.gd` | Belt drag-drop forwarding, "Use" context menu option |
| `scripts/ui/belt_ui.gd` | **New** — BeltUI script |
| `scenes/ui/belt_ui.tscn` | **New** — BeltUI scene |
| `scripts/main.gd` | Wire BeltUI, save/load belt |
| `scenes/main.tscn` | Add BeltUI node |
| `scripts/world/save_manager.gd` | `save_belt()` / `load_belt()` |
