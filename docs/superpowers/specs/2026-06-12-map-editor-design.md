# Map Editor — Design Spec
**Date:** 2026-06-12  
**Project:** TopDown RPG (Godot 4.x)  
**Status:** Approved

---

## Overview

A companion map editor built inside the existing Godot project. Accessible from the main menu via a "Map Editor" button. Allows the developer to visually view and edit saved chunk data — painting terrain tiles and placing/removing objects — without running the game.

---

## Decisions summary

| Question | Decision |
|---|---|
| Where does it live? | Same Godot project, new scene `scenes/map_editor.tscn`, entry from main menu |
| Navigation | Panned multi-chunk view (Camera2D + CanvasLayer UI) |
| Tile set | All 80+ tiles from `res://media/rpg-tiles/index.json` |
| Save behaviour | Explicit Save button + autosave every 60 s (toggle on/off, always starts ON) |
| Unsaved exit | ConfirmationDialog: Save / Discard / Cancel |

---

## Section 1: Data model change (prerequisite)

### terrain_type: int → String

`CellData.terrain_type` changes from an integer (`TerrainType.Type` enum) to a String holding the texture filename (e.g. `"grass.png"`). This is required to support the full tile set from `rpg-tiles/index.json`.

`TileRegistry` (new autoload) loads `res://media/rpg-tiles/index.json` once at startup and becomes the authoritative source for tile passability and speed. It replaces the int-switch functions in `terrain_type.gd`.

### Backward compatibility

`CellData.from_dict()` detects an integer `terrain_type` value and migrates it using this table:

| Old int | New filename |
|---|---|
| 0 (GRASS) | `grass.png` |
| 1 (DIRT) | `mud.png` |
| 2 (STONE) | `granite floor.png` |
| 3 (WATER) | `water.png` |
| 4 (SAND) | `sand.png` |
| 5 (SWAMP) | `swamp grass sep.png` |
| 6 (SNOW) | `snow.png` |
| 7 (GRAVEL) | `gravel.png` |
| 8 (DEEP_WATER) | `deepocean.png` |
| 9 (PATH) | `path.png` |

Migration is silent and automatic on load. Old save files are immediately usable with no manual step.

### Files changed by this refactor

- `scripts/data/cell_data.gd` — `terrain_type: String = "grass.png"`
- `scripts/data/terrain_type.gd` — rewritten; enum removed; passability/speed delegated to `TileRegistry`
- `scripts/world/chunk_node.gd` — loads terrain texture via `terrain_type` string directly
- `scripts/world/chunk_generator.gd` — assigns string filenames for terrain
- `scripts/world/biome_def.gd` — terrain fields become string filenames
- `scripts/world/biome_generator.gd` — uses string filenames

---

## Section 2: Scene structure & new files

### New scene

`scenes/map_editor.tscn`

### New scripts — `scripts/editor/`

| Script | Responsibility |
|---|---|
| `map_editor.gd` | Root controller: startup chunk loading, dirty state, autosave timer, save/exit logic |
| `editor_camera.gd` | Camera2D subclass: middle-drag pan, scroll-wheel zoom |
| `editor_input.gd` | Converts mouse position to world → chunk + cell coords; dispatches paint/erase |
| `chunk_editor_node.gd` | Renders one 16×16 chunk (terrain sprites + object icons); redraws on cell change |
| `tile_registry.gd` | Autoload: loads `rpg-tiles/index.json`; exposes tile list, metadata, category groupings |
| `terrain_palette.gd` | Right-panel terrain tab: tile thumbnail grid grouped by tag, search filter |
| `item_palette.gd` | Right-panel items tab: Rock, Herb, Crystal, Coin, Feather, Potion |
| `editor_ui.gd` | Wires top toolbar and status bar; owns the autosave toggle bool |

### Modified files

- `scripts/ui/main_menu.gd` — add "Map Editor" button → `get_tree().change_scene_to_file("res://scenes/map_editor.tscn")`

### Node tree

```
MapEditor (Node2D)                [map_editor.gd]
├── Camera2D                      [editor_camera.gd]
├── ChunkContainer (Node2D)
│   └── ChunkEditorNode × N       [chunk_editor_node.gd]
├── EditorInput (Node2D)          [editor_input.gd]
└── CanvasLayer
    └── EditorUI (Control)        [editor_ui.gd]
        ├── TopBar (HBoxContainer)
        │   ├── SaveButton
        │   ├── AutosaveToggle
        │   ├── ChunkCoordLabel
        │   ├── CellCoordLabel
        │   └── UnsavedIndicator
        ├── RightPanel (VBoxContainer, anchored right, 220 px)
        │   ├── TabContainer
        │   │   ├── TerrainPalette  [terrain_palette.gd]
        │   │   └── ItemPalette     [item_palette.gd]
        │   └── SelectedInfo
        └── StatusBar (HBoxContainer)
```

---

## Section 3: Editing behaviour

### Startup

1. Read `user://player.json` for last saved position.
2. Compute the chunk coordinates the player was standing in.
3. Load all saved chunks within a 3×3 chunk grid (9 chunks: the player's chunk + 8 immediate neighbours) via `ChunkPersistence.load_chunk()`.
4. Instantiate one `ChunkEditorNode` per loaded chunk; skip coords where no save file exists.

### Camera & viewport

- **Pan:** Middle-mouse drag moves `Camera2D.position`.
- **Zoom:** Scroll wheel adjusts `Camera2D.zoom` (clamped to a sensible range, e.g. 0.25×–4×).
- **Dynamic chunk loading:** Whenever the camera position or zoom changes, recompute which chunk coords fall within the visible rect. For any coord not yet instantiated, attempt `ChunkPersistence.load_chunk()`. If a file exists, spawn a `ChunkEditorNode`. Coords with no save file are left blank.
- **Chunk borders:** A semi-transparent yellow line (1 px) is drawn along each chunk boundary so the grid structure is visible while editing.

### Painting

Holding left-click and dragging continuously paints cells as the cursor moves. Each affected cell is processed independently; the stroke does not span across chunk boundaries in a single atomic operation (each chunk saves separately).

Mouse world position is converted to chunk + cell indices each frame:

```
world_pos = get_global_mouse_position()
chunk_x = floor(world_pos.x / ChunkData.CHUNK_PIXEL_SIZE)
chunk_y = floor(world_pos.y / ChunkData.CHUNK_PIXEL_SIZE)
cell_x  = floor((world_pos.x mod ChunkData.CHUNK_PIXEL_SIZE) / ChunkData.CELL_SIZE)
cell_y  = floor((world_pos.y mod ChunkData.CHUNK_PIXEL_SIZE) / ChunkData.CELL_SIZE)
```

| Input | Terrain mode | Item mode |
|---|---|---|
| Left click | `cell.terrain_type = selected_filename`; mark chunk dirty; redraw cell | `cell.add_object(selected_type)`; mark chunk dirty; redraw cell |
| Right click | No effect | Remove last entry from `cell.objects` (pop); mark chunk dirty; redraw cell |
| Hover | White 1 px highlight border on hovered cell | Same |

Right-click never erases terrain — terrain is only changed by left-clicking a different tile. This avoids accidental terrain deletion.

### Dirty state

Each loaded `ChunkData` is tracked in a `Dictionary` keyed by `"cx_cy"`. A parallel `Set` (Dictionary with bool values) tracks which chunks are dirty. The unsaved indicator dot in the top bar is visible when any chunk is dirty.

### Save & autosave

- **Save button:** Iterate all dirty chunks → `ChunkPersistence.save(chunk)` → clear dirty set → update "last saved" label in status bar.
- **Autosave timer:** 60 s `Timer` node, autostart. On timeout, if autosave is ON, run the same save flow.
- **Autosave toggle:** Button in top bar toggles a bool. Label shows "Autosave: ON" / "Autosave: OFF". Starts ON every session (not persisted).

### Exit guard

When the user clicks "Back to Main Menu" (or equivalent):

1. If no dirty chunks → change scene immediately.
2. If dirty chunks → show `ConfirmationDialog`:  
   - **Save** → run save flow → change scene  
   - **Discard** → change scene without saving  
   - **Cancel** → dismiss dialog, stay in editor

---

## Section 4: Terrain palette detail

`TerrainPalette` reads all tiles from `TileRegistry`. Tiles are displayed as 40×40 thumbnail sprites (actual texture, not colour blocks) grouped by the primary tag from `index.json` (e.g. `outdoor · grass`, `outdoor · sand`, `cave`, `water`, `obstacle`).

A search `LineEdit` at the top filters tiles by filename substring. The selected tile is highlighted with a coloured border; the bottom strip shows the filename, category, and passability.

The palette is a `ScrollContainer` so all 80+ tiles are reachable by scrolling.

---

## Section 5: TileRegistry autoload

`TileRegistry` is registered as an autoload so both the game and the editor can use it.

```gdscript
# Public API
func get_all_tiles() -> Array[Dictionary]   # sorted: category, then filename
func get_tile(filename: String) -> Dictionary  # {passable, speed_modifier, tags, category}
func get_categories() -> Array[String]         # unique sorted list of categories
func is_passable(filename: String) -> bool
func get_speed_modifier(filename: String) -> float
```

This replaces `TerrainType.is_passable(int)` and `TerrainType.get_texture_filename(int)` throughout the game.

---

## Out of scope

- Fog-of-war editing
- NPC placement
- Undo/redo
- Creating new chunks from scratch (editor only edits existing saved chunks)
- Painting across chunk borders in a single drag stroke (each chunk is edited independently; the visual is seamless but saves are per-chunk)
