# 404: Dragon Not Found: Design Document

**Engine:** Godot 4.6, GDScript, GL Compatibility renderer, 1280×720
**Genre:** 2D top-down rogue-like RPG (engine / proof of concept)
**Status:** Work in progress. Most systems work, but there is no game loop yet.

This document gives an overview of the whole project: its vision, its architecture,
each system, and what is still missing. Detailed per-feature specs are in
[superpowers/specs/](superpowers/specs/). Note that the oldest one
([2026-06-12-topdown-rpg-design.md](superpowers/specs/2026-06-12-topdown-rpg-design.md))
describes the very first prototype and is now outdated in many places.

---

## 1. Vision

An endless top-down world in a rogue-like spirit. You explore procedurally generated
land, collect resources, fight monsters in short turn-based battles, trade with and
take quests from villagers, craft better gear, and grow your character through
perk choices.

Design pillars:

1. **Exploration first.** The world never ends, fog of war rewards moving forward,
   and the minimap remembers what you have seen.
2. **Short, readable fights.** Combat is turn-based in a dialog window, not real-time,
   so the game can stay keyboard-friendly and runs well on the web.
3. **Systems that feed each other.** Loot feeds crafting and trading, quests and
   trading earn coins, combat earns XP, XP earns perks, and perks change how
   combat and trading work.
4. **Data-driven and hand-tunable.** Items, monsters, perks and recipes are tables,
   and the built-in map editor can override procedural content.

## 2. Current state

| Area | State |
|---|---|
| Chunk streaming, procedural biomes, persistence | ✅ Working |
| Fog of war, minimap | ✅ Working |
| Avatar movement (keys + click-to-move pathfinding), animated knight sprite | ✅ Working |
| Items (~240 types), stacking inventory, belt, chests | ✅ Working |
| Forge crafting (JSON recipes) | ✅ Working, small recipe set |
| NPCs: knights (ambient), melee NPCs (shop, quests, small talk) | ✅ Working |
| Shops (coin economy) | ✅ Working |
| Quests | ⚠️ Fetch quests only |
| Turn-based combat, 84 monster species, initiative, multi-action monsters | ✅ Working |
| XP, levels, 11 perks with level-up pick | ✅ Working (Efficient Caster has no effect yet) |
| Calendar, day/night, seasons, waiting | ✅ Working |
| Map editor | ✅ Working |
| Audio (music + SFX, volume settings) | ✅ Working |
| Ranged attack (Ctrl projectile) | ⚠️ Visual only, deals no damage |
| Death / permadeath, run structure, win condition | ❌ Missing |
| Equipment (wearing weapons/armor), spells | ❌ Missing |
| Dungeons / multiple levels, real-time enemy AI | ❌ Missing |

**In short:** you can play every system on its own, but nothing yet pushes the
player forward. Losing a battle just shows a message, there is no goal, and items
cannot be equipped.

## 3. Architecture

### Scenes

| Scene | Role |
|---|---|
| `scenes/menu.tscn` | Main menu (Continue / New / Options / Map Editor / Quit). This is the entry scene. |
| `scenes/main.tscn` | The game. `scripts/main.gd` builds and wires up all systems. |
| `scenes/map_editor.tscn` | Standalone chunk editor. It uses the same data and persistence code as the game. |

Most UI is **built in code** (`CanvasLayer` subclasses with a `_build_ui()` method),
not in `.tscn` files. `main.gd` creates each UI, connects signals, and loads save data
in a fixed order. For example, `FogManager` and `NpcManager` connect to `World`
**before** `world.start()`, so they receive the first `chunk_loaded` signals.

### Autoloads

| Name | Script | Purpose |
|---|---|---|
| `TileRegistry` | `scripts/editor/tile_registry.gd` | Tile metadata (passability, speed) loaded from `media/rpg-tiles/index.json` |
| `GameClock` | `scripts/world/game_clock.gd` | Game time, calendar math, time signals |
| `QuestManager` | `scripts/quest/quest_manager.gd` | Quest lifecycle and persistence |

### Code conventions

- **Data vs. nodes.** Plain models (`ChunkData`, `CellData`, `Inventory`, `Belt`,
  `HeroStats`, `CharacterPerks`, `QuestInstance`) are `RefCounted` classes with
  `to_dict()` / `from_dict()` methods. Nodes display the data and change it.
- **Static definition tables.** `MapObject`, `PickableItemDef`, `MonsterStats`,
  `PerkDef`, `BiomeDef` and `TerrainType` are static lookups, the single source of truth
  for game content.
- **Signals for cross-system events** (`chunk_loaded`, `battle_won`,
  `quest_completed`, `time_changed`, and others). Systems do not hold references to
  each other's internals.
- **Pausing.** Modal windows (shop, battle, dialogs) pause the scene tree, and
  `GameClock` stops with it.

## 4. World

### Chunks

| Constant | Value |
|---|---|
| Cell | 64 px |
| Chunk | 16×16 cells (1024 px) |
| Load radius | 2 chunks (a 5×5 block around the player) |
| Preload radius | 3 chunks, with a 2 ms per-frame budget |

`World` follows the avatar. When the avatar enters a new chunk, `World` loads the
missing chunks, from disk if they exist (`ChunkPersistence`) or by generating them
(`ChunkGenerator`). It saves and frees chunks that fall out of range.

### Generation

- `BiomeGenerator` samples two layers of `FastNoiseLite` noise (altitude and
  temperature) per world cell and maps them to one of **Plains, Fields, Caves, Sea,
  Rockies, Snow**. One noise period is about 25 chunks wide, so biomes are large.
- `ChunkGenerator` is deterministic for each chunk coordinate. It picks a terrain tile
  for each cell weighted by biome. Neighbouring cells pull the choice towards their
  own tile (`BLEND_FACTOR = 0.72`), which forms smooth blobs. It then scatters
  objects (rocks, resources, chests) on passable cells.
- A cell has a **base terrain layer (L0)**, an optional **overlay layer (L1)**, a
  list of object IDs, and optional chest contents or a monster placement. Terrain is
  stored as a tile filename that `TileRegistry` looks up.

### Fog of war

There are four levels (unexplored → dim → partial → visible), based on distance
from the avatar (220 / 352 / 480 px). A cell's level only ever increases. Fog is
saved per chunk, and the minimap reads the same data.

### Time

`GameClock` runs at 72× real time, so one game day lasts 20 real minutes. It uses a
fantasy calendar with named weekdays and months. `DayNightCycle` (a `CanvasModulate`)
blends between time-of-day colour keyframes and adds a seasonal warm or cool shift.
The Wait window (T) skips time forward.

## 5. Actors

| Actor | Type | Behaviour |
|---|---|---|
| `Avatar` | `CharacterBody2D` | Player character. Moves with WASD or by click (A* `Pathfinder`, max 2000 steps). Picks up items, interacts within 46 px, uses the belt, fires projectiles. Animated by an 8-direction knight sprite sheet. |
| `NpcKnight` | Actor | Ambient wanderer (70% chance per chunk). |
| `NpcMelee` | Actor | Villager (50% chance per chunk, at most one). Offers small talk (random fortune quote), a shop, and quests. |
| `MonsterNode` | `StaticBody2D` | Stands still. Pressing F starts a battle. 60% chance per chunk, or placed in the editor. Random monsters respawn each session. Editor-placed ones are saved. |

`NpcManager` spawns actors when chunks load, and saves and restores NPCs to
`npcs.json`.

## 6. Items and inventory

- `MapObject.Type` lists about 240 object and item types (resources, bars, tools,
  potions, gems, food, and more). `PickableItemDef` gives each one a name, texture,
  coin value, stack size and whether it can be used.
- `Inventory` has 50 slots holding stacks of `{type, count}`. The UI supports drag and
  drop, a right-click menu (drop, use), and sorting.
- `Belt` has 5 quick slots (keys 1–5). Only items that can be used go there
  (currently health and mana potions, +20 each). The belt can also be used during battles.
- Chests hold up to 20 stacks and offer "Take all" (A). Their contents are saved
  with the chunk.

## 7. Crafting: the forge

The `ForgeNode` world object opens a window with a 3×3 input grid, a 5-slot output
column, and the player's inventory. Recipes in `data/forge_recipes.json` are
**shapeless**: only the item types and counts matter, not their positions. Craft
uses up the inputs and puts the results in the output column. Example recipes:
ore + coal → bars, bars + parts → tools, sand + … → glass vials.

## 8. Economy: shops

Every `NpcMelee` has a shop. The trade window works on **copies** of both inventories
and only applies them when you confirm the trade. Coins are the only currency. Each
NPC has a pool of 1000 coins, and if a sale is worth more than the NPC has, you
lose the difference. The **Trader** perk improves prices. NPC stock is generated
and saved in `shops.json`.

## 9. Quests

`QuestManager` currently creates **fetch quests**: bring N of an item from a
pool of items. The reward is at least 8 gold, or the item's value × count × 2 if that
is more. A quest goes through the states **offered → active → ready → completed**.
Each NPC can give one quest per in-game week. Quest-giving NPCs show a floating
`!` and a minimap dot. The journal (Q) can set one quest as tracked on the minimap.

New quest types are meant to be added by extending `QuestInstance.Type` and writing a
matching `generate_*` method.

## 10. Combat

Pressing F next to a monster opens `BattleDialog`, a turn-based battle that pauses
the game.

- **Turn order:** initiative (1–10). The hero starts at 5 and the **Quick** perk adds
  to it. Each species has its own initiative.
- **Hero actions:** Attack, Defend (doubles defense until the next hit), Flee
  (50% chance), or use a belt item (takes the whole turn).
- **Monsters** act 1–3 times per round, depending on species. The 84 species are
  grouped in tiers from critters (Earthworm, Slug) up to big threats. Their
  stats are in `MonsterStats`.
- **Damage:** comes from attack against defense. **Berserker** adds attack while
  HP is under 30%. **Vampiric** heals the hero after a win.
- **Results:** a win gives XP and removes the monster. A loss shows
  "You were defeated…" and the monster heals back to full. There is **no death
  penalty yet**.

The Monster Book (B) lists the species you have met.

## 11. Character progression

`HeroStats` tracks HP, mana, attack, defense, magic, initiative, XP and level. The
next level needs `20 × level` XP. Each level-up opens `PerkPickUI`, which offers
3 random perks you don't have yet, or upgrades to ones you do (max level 3):

| Perk | Effect per level |
|---|---|
| Strong / Tough / Wise / Armored / Spell Focus | +1 attack / +5 max HP / +3 max mana / +1 defense / +1 magic |
| Quick | +1 initiative |
| Vampiric | Heals after a win |
| Berserker | +3 attack below 30% HP |
| Efficient Caster | Cheaper spells (no effect until spells exist) |
| Trader | Better shop prices |
| Swift Walker | Faster movement |

## 12. Map editor

The editor is opened from the main menu. It shows a panned, zoomable view of the
saved chunks (it loads a 3×3 block of chunks).

- Palettes for terrain (all tiles in `TileRegistry`), objects, and monsters.
- Two terrain layers (L0 base, L1 overlay). Left mouse paints, right mouse erases,
  middle mouse pans, the scroll wheel zooms.
- Variable brush size with a hover preview that works across chunk borders, and an
  eyedropper.
- Chest contents editor.
- **Ctrl+Z undo**: each stroke is one undo step, with up to 50 records.
- An explicit Save button, autosave every 60 s (can be turned off), and a prompt
  about unsaved changes when leaving.

The editor writes the same chunk JSON as the game, so whatever you place shows up
in your current save.

## 13. Persistence

Everything is JSON under `user://`:

| File | Contents |
|---|---|
| `chunks/<cx>_<cy>.json` | Cell terrain, objects, chest contents, monster placements |
| `fog/<cx>_<cy>.json` | Fog levels for each cell |
| `player.json` | Position and heading |
| `character.json` | Name and birth time |
| `stats.json`, `player_perks.json` | Hero stats and perks |
| `inventory.json`, `belt.json` | Items |
| `npcs.json`, `shops.json`, `dialog_visited.json` | NPC state |
| `quests.json` | Quest state and cooldowns |
| `clock.json` | Game time |
| `settings.json` | Audio and video options |

Chunks and fog are saved when a chunk unloads. Player data is saved from the pause
menu, after battles, and after trades. New Game deletes everything (`SaveManager.wipe()`).

## 14. Developer tooling

- **Console** (`` ` ``): `/give`, `/coins`, `/items`, `/pos`, `/tp`, `/day`,
  `/night`, `/set_date`, `/set_time`, `/timescale`, `/perk`, `/name`, `/stats`, `/hp`,
  `/heal`, `/xp`, `/level`, `/stat`, `/monsters`, `/killall`, `/clear_inv`.
- **F3** debug overlay (position, chunk, biome, fog, FPS). **F4** shows collision shapes
  and actor reference markers.
- `tools/analyze_spritesheets.gd` is an editor script for inspecting sprite sheets.
- A new character currently starts with a test kit of crafting materials and potions,
  and a test forge is placed near spawn (`main.gd`). Remove both before
  real playtesting.

## 15. Roadmap: turning the engine into a game

Roughly in order of how much each step adds to the game:

1. **Core loop and stakes.** Add death with consequences (permadeath or losing
   loot), and a clear goal such as finding the dragon or descending a set number of levels.
2. **Equipment.** Let the player equip weapons and armour that change `HeroStats`,
   so crafting and shops matter for combat.
3. **Difficulty scaling.** Choose monster tiers by distance from the origin and by
   biome, so the world gets more dangerous further out.
4. **Spells and mana use.** Mana, Magic, Spell Focus and Efficient Caster already
   exist but do nothing yet.
5. **Projectiles that deal damage**, or remove the feature.
6. **More quest types** (kill, deliver, explore), and quest chains.
7. **Dungeons**, meaning separate chunk spaces you enter through stairs or holes, for the
   classic rogue-like descent.
8. **Content and polish.** More recipes, item descriptions, a tutorial, and replacing
   test starting items with a real starting kit.
9. **Asset licensing.** Check every bundled pack, and replace those that do not
   allow redistribution before any public release.
