# Quest Giver Foundation — Design Document

**Date:** 2026-06-13  
**Scope:** Visual quest-giver markers (world + minimap) and dialog stub for future quest system

---

## Overview

All `NpcMelee` characters become quest givers. This feature adds three things:

1. A floating `!` marker above each melee NPC in world space
2. A yellow dot on the minimap for each melee NPC whose position has been fog-revealed
3. A `Quest` dialog option that currently replies with a "no quests" stub

No new classes or save data are added. Everything hooks into existing systems.

---

## 1. World-Space `!` Marker

**File:** `scripts/actors/npc_melee.gd`

**Asset:** `res://media/cursors/Outline/Default/mark_exclamation.png`

In `_ready()`, create a `Sprite2D` child with:
- `texture` = the exclamation mark PNG
- `modulate` = `Color(1.0, 0.85, 0.0)` (yellow)
- `position.y` = `-90` (above the boxer sprite's head; sprite offset is -36.6 at 0.56 scale ≈ -20px, plus sprite height ≈ 37px, giving ~-73px to top — marker sits ~17px above that)

**Bob animation:** A `_mark_bob: float` accumulator advances each `_process(delta)`. Marker y is:
```
_mark_base_y + sin(_mark_bob * TAU / 1.2) * 3.0
```
Period 1.2s, amplitude 3px. Subtle and standard for quest indicators.

The marker is a child node in world space, so it is naturally covered by the fog renderer — no special visibility logic needed.

---

## 2. Minimap Quest Giver Dots

**File:** `scripts/ui/minimap_ui.gd`

At the end of `_refresh()`, after the player dot, iterate `_world.get_children()`:

```
for each NpcMelee child:
    gc = _world_to_cell(npc.position)
    px = half + (gc.x - center.x)
    py = half + (gc.y - center.y)
    skip if out of [0, CELLS) bounds
    check fog level at gc — skip if UNEXPLORED
    draw 3×3 yellow dot at (px, py)
```

Yellow: `Color(1.0, 0.85, 0.0)` — matches the world marker color.  
Size: 3×3 pixels (same as player dot, which is white).  
"Discovered" = fog level is not `FogData.UNEXPLORED` at the NPC's cell.

No new state or signal needed — the minimap already holds references to `_world` and `_fog_manager`.

---

## 3. Quest Dialog Option

**File:** `scripts/ui/npc_dialog.gd`

In `_build_menu()`, for `NpcMelee` the menu becomes:

```
1.  Hello
2.  What is thy wisdom, o wise one?
3.  Quest
4.  Goodbye
```

Handler `_on_quest()` calls:
```gdscript
_show_speech("I have no quests for you at this time, traveler.")
```

This is a pure stub — no quest data, no state change. The option is numbered and visited-state tracked the same as other options (grayed after first click).

---

## What Is Not In Scope

- Quest data structures, quest state, quest tracking
- Multiple quest types or branching
- Save/load of quest progress
- Distinguishing "has quest" vs "no quest" visually (all melee NPCs show `!` for now)

These belong in a future "Quest System" spec.
