# Forge Crafting Station — Design Spec
**Date:** 2026-06-13

---

## Overview

The Forge is a new impassable world object (like a chest) that the player can interact with to open a crafting UI. It has three inventories: a 3×3 input grid, a 1×5 output column, and the player's own inventory. Recipes are order-free (placement in the grid doesn't matter), defined in JSON, and matched against the input grid contents. Hitting Craft consumes the ingredients and places outputs. All three inventories support drag-and-drop between each other.

---

## 1. World Object — `ForgeNode`

**File:** `scripts/objects/forge_node.gd`  
**Type:** `StaticBody2D` — mirrors `ChestNode` exactly in structure.

- **Impassable:** Added to `MapObject.is_type_passable` blocklist alongside `ROCK` and `CHEST_SMALL`.
- **Non-pickable:** `MapObject.Type.FORGE` excluded from `PickableItemDef.is_pickable` (currently returns true for everything except ROCK/CHEST_SMALL — add FORGE to that exclusion list).
- **Sprite:** `items2/forge.png` via `PickableItemDef.get_texture(MapObject.Type.FORGE)`, scale `1.75` (standard items2 world scale).
- **Collision:** Same 20 px half-size rectangle as `ChestNode`.
- **Group:** Added to group `"forges"` so the player interaction script can locate it.
- **State:**
  - `input_contents: Array[Dictionary]` — up to 9 slots, each `{type: int, count: int}`.
  - `output_contents: Array[Dictionary]` — up to 5 slots, same format.
- **Initialize signature:**
  ```
  initialize(cx, cy, chunk_x, chunk_y, stored_input, stored_output)
  ```
  `stored_input` / `stored_output` are `null` (start empty) or Arrays loaded from `ChunkData`.
- **`flush_to_data()`:** Saves both arrays back to `ChunkData` — called by `ForgeUI` on close.

---

## 2. Persistence — `ChunkData` additions

**File:** `scripts/data/chunk_data.gd`

Two new dictionaries, parallel to `chest_contents`:

| Dict key | Type | Meaning |
|---|---|---|
| `forge_input` | `Dictionary` | cell-pos string → `Array` or `null` |
| `forge_output` | `Dictionary` | cell-pos string → `Array` or `null` |

Getters/setters follow the same pattern as `get_chest_contents` / `set_chest_contents`.

---

## 3. Map Spawning — `ChunkNode`

**File:** `scripts/world/chunk_node.gd`

Add a branch for `MapObject.Type.FORGE` alongside the existing `CHEST_SMALL` branch:
- Instantiate `ForgeNode`, call `initialize` with stored input/output from `ChunkData` (or `null`).
- Assign `_chunk_data` reference so `flush_to_data` works.

---

## 4. Map Editor

**File:** `scripts/editor/item_palette.gd` (and `chunk_editor_node.gd`)

- Forge appears in the **Objects** section of the palette (it's already registered as `MapObject.Type.FORGE = 145`).
- It is **not** draggable into the chest inventory editor (it's not pickable).
- In the editor canvas, it renders using `PickableItemDef.get_texture(FORGE)` at the standard items2 upscale.
- Placing/erasing a forge on a cell works identically to placing a rock.

---

## 5. Recipe System — `ForgeRecipeDef`

**File:** `scripts/objects/forge_recipe_def.gd`  
**Data file:** `res://data/forge_recipes.json`

### JSON format

```json
[
  {
    "name": "Iron Bar",
    "inputs":  [{"type": 12, "count": 2}, {"type": 49, "count": 1}],
    "outputs": [{"type": 16, "count": 2}]
  }
]
```

`type` values are `MapObject.Type` int constants.

### `ForgeRecipeDef` static class

```
static func _static_init() -> void   # GDScript 4 auto-called on first class reference; calls load_recipes()
load_recipes() -> void               # Parses forge_recipes.json into _recipes Array
get_all() -> Array              # Returns all loaded Recipe dicts
can_craft(recipe, input_contents) -> bool
    # True when every input ingredient is present in sufficient total quantity
    # across all input slots (order-free)
craft(recipe, input_contents, output_contents) -> bool
    # Returns false if can_craft is false OR output has insufficient free space.
    # On success: consumes ingredients from input_contents (mutates in place),
    #             appends/merges outputs into output_contents (mutates in place).
```

`can_craft` aggregates counts per type across all non-empty input slots, then checks each required ingredient. Stack size limits are respected when merging outputs (uses `PickableItemDef.max_stack_size`).

### Starter recipes (5)

| Name | Inputs | Outputs |
|---|---|---|
| Iron Bar | 2× Iron Ore + 1× Coal Ore | 2× Iron Bar |
| Copper Wire | 2× Copper Ore + 1× Glass Fiber | 3× Copper Wire |
| Bronze Axe | 2× Copper Bar + 1× Iron Bar + 1× Wooden Rod | 1× Bronze Axe |
| Glass Vial | 2× Glass + 1× Nails | 3× Glass Vial |
| Cloth Strip | 3× Leather + 1× Flax String | 2× Cloth |

---

## 6. Crafting UI — `ForgeUI`

**File:** `scripts/ui/forge_ui.gd`  
**Scene:** `scenes/ui/forge_ui.tscn`

### Layout — Top / Bottom split (Layout B)

```
┌─────────────────────────────────────────────────────┐
│  INPUT (3×3)  │ [CRAFT] →  │ OUTPUT (1×5) │ RECIPES │
├─────────────────────────────────────────────────────┤
│              PLAYER INVENTORY (10 cols)              │
└─────────────────────────────────────────────────────┘
```

### Panels

**Input (3×3)**
- 9 draggable slots in a `GridContainer`.
- Empty slots shown with dashed border.
- Occupied slots show icon + yellow count badge (if count > 1).

**Craft button**
- Green and enabled when `ForgeRecipeDef.can_craft(selected_recipe, input_contents)` is true.
- Grey/disabled otherwise.
- On press: calls `ForgeRecipeDef.craft(...)`, refreshes all three panels.

**Output (1×5)**
- 5 slots in a `VBoxContainer`.
- Occupied slots have green border.
- Items here can be dragged to player inventory or input.

**Recipe panel**
- Scrollable `VBoxContainer` of recipe rows.
- Each row shows:
  - Recipe name (bold).
  - Icon strip: ingredient icons left of `→`, output icons right.
  - **Stackable, qty > 1:** single icon + yellow count badge bottom-right.
  - **Count = 1:** icon only, no badge.
  - **Non-stackable, qty > 1:** icon repeated N times.
  - Output icons have green border.
- Selected recipe: green left-border, highlighted background.
- Clicking a row selects it and re-evaluates the Craft button.
- First recipe is auto-selected when the UI opens; Craft button is disabled if no recipe is selected.

**Player inventory**
- Full-width at bottom.
- Same slot rendering as `InventoryUI` / `ChestLootUI`.

### Drag & Drop

All three inventories participate in Godot's `set_drag_forwarding` DnD system (same pattern as `ChestLootUI` ↔ `InventoryUI`). Dragging between any pair of panels moves/merges the item stack, respecting `max_stack_size`.

### Open / Close

- Opened by player interaction (same trigger as `ChestLootUI`).
- Pauses the game while open.
- On close: `forge_node.flush_to_data()` is called.

---

## 7. Player Interaction

**File:** `scripts/actors/avatar.gd`

Add `get_interactable_forge() -> ForgeNode` alongside the existing `get_interactable_chest()`, using the same `INTERACT_DIST` + heading-angle check against group `"forges"`. The existing interact key handler calls `get_interactable_forge()` first; if non-null, opens `ForgeUI` instead of `ChestLootUI`.

---

## 8. Files to Create

| File | Purpose |
|---|---|
| `scripts/objects/forge_node.gd` | World object |
| `scripts/objects/forge_recipe_def.gd` | Recipe loader + craft logic |
| `scripts/ui/forge_ui.gd` | UI controller |
| `scenes/ui/forge_ui.tscn` | UI scene |
| `res://data/forge_recipes.json` | Recipe data |

## 9. Files to Modify

| File | Change |
|---|---|
| `scripts/objects/map_object.gd` | Add FORGE to `is_type_passable` blocklist |
| `scripts/objects/pickable_item_def.gd` | Exclude FORGE from `is_pickable`; `get_world_scale` returns 1.75 for it (via existing items2 path) |
| `scripts/editor/item_palette.gd` | Load texture for all types (not just pickable), so FORGE shows its icon in the palette |
| `scripts/data/chunk_data.gd` | Add `forge_input` / `forge_output` dicts + getters/setters |
| `scripts/world/chunk_node.gd` | Spawn ForgeNode when cell type is FORGE |
| `scripts/actors/avatar.gd` | Add `get_interactable_forge()` and hook into interact key handler |
