# Monster Encounters — Design Spec
**Date:** 2026-06-15

## Overview

Add static monster encounters to the world map. Monsters are persistent interactable entities drawn from the `media/rpg-beings/` sprite library, spawned once per chunk and saved between sessions. Interacting offers a Fight option that returns a placeholder response.

## Architecture

### New class: MonsterNode (`scripts/actors/monster_node.gd`)

- Extends `StaticBody2D`.
- On `_ready`, picks a random PNG from `res://media/rpg-beings/` and loads it into a `Sprite2D`. Scales the sprite so the image fits within a **48×48 px** box (75% of the 64 px cell size), centered at origin.
- Collision: `CollisionShape2D` with `CircleShape2D` radius **24 px** (75% of cell diameter ÷ 2), on Actor collision layer 1.
- Fields: `monster_id: String`, `species: String` (filename stem, e.g. `"Wolf"`).
- `to_dict()` / `restore_from_dict()` for save/load — persists position, monster_id, species.
- Added to group `"monsters"` so Avatar's interactable scan can find it.

### NpcManager changes

- New constants: `MONSTER_SPAWN_CHANCE := 0.60`, at most one monster per chunk.
- New state: `_monster_spawned: Dictionary` (Vector2i → true), `_next_monster_id: int`.
- `_on_chunk_loaded`: after existing knight/melee logic, spawn a MonsterNode if chunk not yet marked.
- `save()`: serialize monsters alongside existing NPC types (`type: "monster"`).
- `pre_mark_from_save()`: read `type: "monster"` entries, mark chunks, bump ID counter.
- `load_and_spawn()`: restore MonsterNode from saved dict via `restore_from_dict`.

### Avatar changes

- `get_interactable_npc()`: extend existing loop to also match `child is MonsterNode`.

### NpcDialog changes

- `_build_menu()`: add `MonsterNode` branch — buttons `"F.  Fight"` and `"2.  Goodbye"`.
- New `_on_fight()` handler: calls `_show_speech("No mood for fighting today.")`.
- `_npc_label()`: returns species name (e.g. `"Wolf"`) for MonsterNode.

## Sizing

| Measure | Value |
|---|---|
| Cell size | 64 px |
| Display box | 48×48 px (75% of cell) |
| Collision radius | 24 px (75% of cell ÷ 2) |

## Data Format (save)

```json
{ "type": "monster", "monster_id": "monster_001", "species": "Wolf", "x": 320.0, "y": 448.0 }
```

## Out of Scope

- Actual combat system
- Monster stats or HP
- Monster movement/AI
- Biome-specific monster pools
