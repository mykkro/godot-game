# TopDown RPG — Design Document

**Engine:** Godot 4.6 · GL Compatibility renderer  
**Viewport:** 1280 × 720  
**Genre:** 2D top-down RPG prototype  
**Date:** 2026-06-12

---

## 1. Project Overview

A 2D top-down RPG prototype featuring an infinite procedurally generated world, fog of war, item pickups, persistent inventory, and full save/load. The player explores a streaming tile world, collecting items scattered across varied terrain biomes.

### What Is Implemented

| System | Status |
|---|---|
| Chunk-streamed infinite world | Done |
| Procedural terrain generation | Done |
| Chunk + fog persistence (JSON) | Done |
| Fog of war (3 levels) | Done |
| Player movement + collision | Done |
| Pickable items (5 types) | Done |
| Inventory (50 slots) | Done |
| Save / load (position, inventory) | Done |
| Tile sprites from `media/rpg-tiles/` | Done |
| Item sprites from `media/raven-objects/` | Done |
| Pause menu + debug overlay | Done |

### What Is Not Yet Implemented

- Player sprite (currently a drawn circle)
- NPC / enemy actors
- Combat system
- Item use / effects (potions, etc.)
- Crafting
- Quest system
- Overworld / minimap
- Sound and music

---

## 2. Scene Hierarchy

```
Main (Node2D)              [scripts/main.gd]
├── World (Node2D)         [scripts/world/world.gd]
│   └── ChunkNode ×N      [scripts/world/chunk_node.gd]  (streamed in/out)
│       └── PickableNode ×N [scripts/world/pickable_node.gd]
├── FogManager (Node2D)   [scripts/fog/fog_manager.gd]
│   └── FogRenderer ×N    [scripts/fog/fog_renderer.gd]
├── Avatar (CharacterBody2D) [scripts/actors/avatar.gd]
├── DebugOverlay          [scripts/ui/debug_overlay.gd]
├── PauseMenu             [scripts/ui/pause_menu.gd]
├── InventoryUI           [scripts/ui/inventory_ui.gd]
└── PickupHint            [scripts/ui/pickup_hint.gd]
```

Entry scene is `scenes/menu.tscn` (main menu), which loads `scenes/main.tscn`.

---

## 3. World & Chunk System

### Constants

| Name | Value | Meaning |
|---|---|---|
| `CELL_SIZE` | 64 px | One tile in world space |
| `CHUNK_SIZE` | 16 cells | Cells per chunk side |
| `CHUNK_PIXEL_SIZE` | 1024 px | Pixels per chunk side |
| `LOAD_RADIUS` | 2 chunks | Chebyshev radius kept loaded |

A loaded zone is a 5 × 5 block of chunks (25 total) centred on the player's chunk.

### Chunk Lifecycle

1. `Avatar._physics_process` → `World.update_avatar_position(pos)`
2. `World` computes current chunk coord; on coord change calls `_update_chunks`
3. Missing chunks: `ChunkPersistence.exists` → load from JSON, else `ChunkGenerator.generate` then save
4. Out-of-range chunks: `ChunkPersistence.save` → emit `chunk_unloaded` → free `ChunkNode`
5. `chunk_loaded` / `chunk_unloaded` signals notify `FogManager`

### Data Model

```
ChunkData
  chunk_x, chunk_y : int
  cells[y][x]      : CellData
    terrain_type   : TerrainType.Type  (int)
    objects        : Array[int]        (MapObject.Type values)
    is_obstacle    : bool              (derived from terrain)
```

---

## 4. Procedural Generation (`ChunkGenerator`)

Generation is deterministic per `(chunk_x, chunk_y)` via FNV-1a seed.

**Two-pass algorithm:**

1. **Terrain pass** — each cell picks a weighted terrain type. Left and top neighbours boost their own type's weight by `1 + BLEND_FACTOR × 3` (BLEND_FACTOR = 0.72), creating large smooth biome blobs.
2. **Object pass** — passable cells roll for objects using a cumulative probability table:

| Object | Probability |
|---|---|
| ROCK (obstacle) | 5 % |
| HERB | 3 % |
| CRYSTAL | 2 % |
| COIN | 1.5 % |
| FEATHER | 1 % |
| POTION | 0.7 % |

### Terrain Types

| ID | Name | Passable | Tile file |
|---|---|---|---|
| 0 | GRASS | yes | `grass.png` |
| 1 | DIRT | yes | `mud.png` |
| 2 | STONE | yes | `granite floor.png` |
| 3 | WATER | **no** | `water.png` |
| 4 | SAND | yes | `sand.png` |
| 5 | SWAMP | yes | `swamp grass sep.png` |
| 6 | SNOW | yes | `snow.png` |
| 7 | GRAVEL | yes | `gravel.png` |
| 8 | DEEP_WATER | **no** | `deepocean.png` |
| 9 | PATH | yes | `path.png` |

---

## 5. Rendering

`ChunkNode._draw()` iterates all cells each redraw:
- Terrain: `TextureCache.get_texture(filename)` → `draw_texture_rect`; falls back to flat color
- Grid lines: 7 % black overlay per cell
- Non-pickable objects (ROCK): drawn as circle + arc directly in `_draw_object`
- Pickable objects: rendered by their own `PickableNode` (Sprite2D), not in `_draw`

`TextureCache` (`scripts/utils/texture_cache.gd`) caches loaded textures by filename to avoid repeated disk reads.

---

## 6. Fog of War

### Levels

| Level | Value | Overlay | Meaning |
|---|---|---|---|
| UNEXPLORED | 0 | 100 % black | Never seen |
| DIM | 1 | 60 % black | Seen, outside view |
| PARTIAL | 2 | 25 % black | Outer edge of view |
| VISIBLE | 3 | transparent | Fully in view radius |

### Radii (from avatar centre)

| Radius | px | Result |
|---|---|---|
| RADIUS_FULL | 220 | → VISIBLE |
| RADIUS_PARTIAL | 352 | → PARTIAL |
| RADIUS_DIM | 480 | → DIM |

Fog is **monotonically increasing** — cells never go back to a lower level. `FogManager` only processes chunks whose nearest point is within `RADIUS_DIM`. Fog state is saved per-chunk to `user://fog/<cx>_<cy>.json` and persisted on chunk unload.

`FogRenderer` (`scripts/fog/fog_renderer.gd`) draws a per-cell overlay quad on top of terrain based on level.

---

## 7. Actor System

### `Actor` (base class, `CharacterBody2D`)

- `heading: float` — facing angle in radians (0 = right)
- `collision_radius: float` — set before `super._ready()`, creates a `CircleShape2D`

### `Avatar` (player)

| Property | Value |
|---|---|
| Move speed | 200 px/s |
| Collision radius | 14 px |
| Pickup radius | 52 px |

Input: `ui_left/right/up/down` (arrow keys / WASD). Movement via `move_and_slide()`.

Visual: drawn with `_draw()` — blue circle + white direction arrow. No sprite yet.

Pickup: `_unhandled_input` → KEY_E → `_try_pickup()` → picks nearest item within `PICKUP_RADIUS`.

---

## 8. Pickable Items

### `PickableNode` (Area2D)

Spawned by `ChunkNode._spawn_pickables()` for every pickable object in chunk data.

- Collision layer 2 (distinct from physics layer 1)
- Sprite: `Sprite2D` from `media/raven-objects/`, scale 0.5, nearest-filter
- Detection area radius: 20 px

On `remove_from_world()`: removes item from `CellData.objects` and frees self, so re-saving the chunk does not re-spawn it.

### Item Types

| Type | Name | Sprite file |
|---|---|---|
| HERB | Herb | `fc100.png` |
| CRYSTAL | Crystal | `fc4.png` |
| COIN | Coin | `fc2.png` |
| FEATHER | Feather | `fc7.png` |
| POTION | Potion | `fc50.png` |

ROCK is the only impassable object type; all others are passable.

---

## 9. Inventory

`Inventory` — flat `Array[int]` of `MapObject.Type` values, max 50.

`InventoryUI` — `CanvasLayer` (layer 70), 10 × 5 slot grid (10 cols, 5 rows). Centered via a full-rect `CenterContainer`.
- Toggle: KEY_I
- Close: KEY_ESCAPE (when open)
- Each slot shows item sprite + name label

No item use, stacking, sorting, or dropping is implemented yet.

---

## 10. Save / Load

All save data lives in `user://` (OS-specific app data directory).

| Path | Contents |
|---|---|
| `user://player.json` | `{ x, y, heading }` |
| `user://inventory.json` | `{ items: [int, …] }` |
| `user://chunks/<cx>_<cy>.json` | Full `ChunkData` serialisation |
| `user://fog/<cx>_<cy>.json` | `FogData` per-cell visibility levels |

`SaveManager.wipe()` deletes all of the above (exposed via pause menu).

On startup:
1. Load inventory from disk (or fresh `Inventory`)
2. Load player position/heading (or scan for first passable cell in chunk 0,0)
3. World streams chunks; each triggers fog load

On chunk unload: chunk + fog are saved before the data is freed.

Player position is saved only when the player chooses **"Save & Exit"** or **"Main Menu"** from the pause menu (F10 / ESC). Plain **"Exit"** does **not** save. Position is lost on crash. (Gap: should auto-save periodically.)

---

## 11. UI Systems

| Node | Key | Purpose |
|---|---|---|
| `InventoryUI` | I | 5×10 item grid |
| `PauseMenu` | F10 (ESC closes) | Resume / Save & Exit / Main Menu / Exit |
| `PickupHint` | — | Floating label "Press E to pick up [item]" |
| `DebugOverlay` | — | Player pos, chunk coord, fog level, FPS |

---

## 12. Asset Layout

```
media/
  rpg-tiles/      — terrain tile PNGs (64×64 or similar)
  raven-objects/  — item/object sprite PNGs
```

`TextureCache` stores terrain textures under `res://media/rpg-tiles/<filename>` and object textures under `res://media/raven-objects/<filename>`. Both caches use a `Dictionary` keyed by filename.

---

## 13. Known Gaps & Next Steps

| Gap | Notes |
|---|---|
| Player sprite | Currently a `_draw()` circle. Needs `AnimatedSprite2D` with walk/idle animation |
| Player position auto-save | Lost on crash; should save on every pause or periodically |
| Item use | Potions collected but have no effect |
| NPC / enemy actors | `Actor` base class exists; no derived NPC type yet |
| Combat | No health, damage, or death |
| Overworld map | `media/rpg-tiles/map tile *.png` assets exist; no map scene yet |
| Sound | No AudioStreamPlayer nodes anywhere |
| Crafting / quests | Not started |
| Biome seed | All chunks use the same weight distribution regardless of distance from origin |
