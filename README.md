# 404: Dragon Not Found

A small rogue-like / top-down RPG engine built with **Godot 4.6** (GDScript, GL Compatibility renderer).

> **Status: work in progress, proof of concept.**
> This is a starter kit, not a finished game. Most of the systems a rogue-like
> needs are in place: an endless procedural world, fog of war, inventory, crafting,
> trading, quests, turn-based combat and levelling. They are not yet tied together
> into a real game loop. You can walk around, fight, trade and craft, but there is
> no goal, no ending and no real failure state yet.

![Title screen](docs/images/title-screen.png)

## Features

- **Endless procedural world.** The map is streamed in 16×16-cell chunks around the
  player. Six biomes (Plains, Fields, Caves, Sea, Rockies, Snow) come from
  altitude and temperature noise. Every chunk you visit is saved.
- **Fog of war** with unexplored, dim, partial and visible levels, kept between sessions.
- **Player avatar**: an animated 8-direction knight that you move with the keyboard
  or by clicking (A* pathfinding).
- **Inventory** with stacking, sorting and dropping, plus a **5-slot quick-use belt**
  for potions (keys 1–5).
- **About 240 item types**, chests, and a **forge** that crafts from shapeless
  recipes defined in [data/forge_recipes.json](data/forge_recipes.json).
- **NPCs**: wandering knights, and melee NPCs that run **shops** (coin-based buy and
  sell) and give **fetch quests** (quest journal, minimap tracking, weekly cooldown).
- **Turn-based combat** against **84 monster species**, with initiative, monsters
  that act more than once per turn, attack / defend / flee, and potions during battle.
- **Levelling and perks.** Each level-up offers 3 random perks to choose from (11
  perks such as Strong, Vampiric, Berserker, Quick and Trader).
- **Calendar and clock.** A day lasts 20 real minutes and the calendar is a fantasy
  one. A day/night tint changes with the seasons, and you can wait to pass time.
- **Map editor** (from the main menu): paint terrain on two layers, place objects,
  monsters and chests, set brush sizes, use an eyedropper, undo with Ctrl+Z, and autosave.
- **Developer tools**: an in-game console, an F3 debug overlay and an F4 collision view.
- Music, sound effects, minimap, monster bestiary, and NPC small talk drawn from fortune-cookie files.

## Getting started

1. Install [Godot 4.6](https://godotengine.org/download) (standard build; .NET is not needed).
2. Clone this repository and open `project.godot` in Godot.
3. Press **F5**. The game opens on the main menu (`scenes/menu.tscn`).

There is also a **Web** export preset that outputs to `export/index.html`.

## Controls

| Key | Action |
|---|---|
| WASD / arrows | Move |
| Left click | Walk to the clicked spot |
| E | Interact / pick up / talk / open |
| F | Fight a nearby monster |
| Ctrl | Fire a projectile (visual only for now) |
| 1–5 | Use a belt slot |
| I | Inventory |
| C | Character sheet |
| Q | Quest journal |
| M | Minimap |
| B | Monster book |
| T | Wait / pass time |
| F10 / Esc | Pause menu (save, main menu, exit) |
| ` (backtick) | Developer console (`/help` lists the commands) |
| F3 / F4 | Debug overlay / collision shapes |

## Project layout

```
scenes/            menu, main game and map editor scenes
scripts/
  actors/          avatar, NPCs, monsters, sprite animators
  world/           chunk streaming, generation, biomes, clock, pathfinding, NPC spawning
  fog/             fog-of-war data, rendering, persistence
  data/            plain data models (cells, chunks, stats, perks, monsters)
  objects/         map objects, items, chests, forge, recipes
  inventory/       inventory and belt models
  quest/           QuestManager autoload and quest instances
  ui/              all in-game windows and HUD (built in code)
  editor/          map editor
  utils/           save manager, texture cache
data/              JSON game data (forge recipes)
fortunes/          quote files used for NPC small talk
media/, sounds/    third-party art and audio
tools/             one-off editor scripts
docs/              design documentation
```

## Documentation

- [docs/DESIGN.md](docs/DESIGN.md): an overview of the architecture and systems, and the current state of the project.
- [docs/superpowers/specs/](docs/superpowers/specs/): detailed design specs for individual features.
- [docs/superpowers/plans/](docs/superpowers/plans/): implementation plans for those features.

## Save data

Game state is saved as JSON under Godot's `user://` directory. On Windows this is
`%APPDATA%\Godot\app_userdata\<project name>\`. Choosing **New Game** in the main menu
deletes the previous save.

## License

The **code, scenes, data and documentation** in this repository are released under the
[MIT License](LICENSE).

### Third-party assets

The art, audio and quote files under `media/`, `sounds/` and `fortunes/` are
**not** covered by the MIT license. They belong to their original authors and are
used under their own licenses. Every bundled pack is used by the game.

#### Identified sources

| Folder | Used for | Source and author | License |
|---|---|---|---|
| `media/rpg-tiles/` | Terrain tiles (`index.json` is ours) | [Seamless 64px RPG Tiles](https://opengameart.org/content/seamless-64px-rpg-tiles) by CodeSpree | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |
| `media/items2/` | Item icons | [154 Free RPG Items](https://opengameart.org/content/154-free-rpg-items) by CodeSpree | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |
| `media/rpg-beings/` | Monster sprites | [84 Free RPG Beings and Monsters](https://opengameart.org/content/84-free-rpg-beings-and-monsters) by CodeSpree. Some are based on [game-icons.net](https://game-icons.net) icons by Lorc and Delapouite | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |
| `media/cobbleset/` | Cobblestone terrain | [Cobblestone Tileset](https://opengameart.org/content/cobblestone-tileset): tileset by Cem Kalyoncu, textures by Lamoot and West | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| `media/hyptosis/` | Terrain tiles | [Lots of free 2d tiles and sprites by Hyptosis](https://opengameart.org/content/lots-of-free-2d-tiles-and-sprites-by-hyptosis) by Hyptosis (submitted by Zabin) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| `media/lpc_terrain/` | Terrain transition tiles | [LPC terrain extension](https://opengameart.org/content/lpc-terrain-extension) by Cem Kalyoncu, Connor Sherson, Daniel Eddeland, Johann Charlot, Jonas Klinger, Juan Rodriguez, Lanea Zimmerman, Mark Weyer and Skyler Robert Colladay (per-file credits in `COPYRIGHT`) | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) or [GPL 3.0](https://www.gnu.org/licenses/gpl-3.0.html) |
| `media/ravenmore/` | Weapon and armour icons | [Fantasy Icon Pack](https://opengameart.org/content/fantasy-icon-pack-by-ravenmore-0) by [Ravenmore](https://ravenmore.itch.io) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| `media/kyrise/` | Arrows, rings, keys and other small icons | [Kyrise's Free 16x16 RPG Icon Pack](https://opengameart.org/content/kyrises-free-16x16-rpg-icon-pack) by [Kyrise](https://kyrise.itch.io/) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `media/flare/` | Armour icons | [Armor Icons by Equipment Slot](https://opengameart.org/content/armor-icons-by-equipment-slot) by Clint Bellanger, Blarumyrran, crowline and Justin Nichol | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `sounds/RPG Sound Pack/` | Sound effects | [RPG Sound Pack](https://opengameart.org/content/rpg-sound-pack) by artisticdude | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `media/knight-basic/` | Player avatar animations | [8 Directional Knight Character](https://hormelz.itch.io/8-directional-knight) by Hormelz | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `media/knight-greatsword/` | Knight NPC animations | [8 Directional Greatsword Knight Character](https://hormelz.itch.io/8-directional-great-sword-knight-character) by Hormelz | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `media/melee/` | Villager NPC animations | [Free 8-Directional Melee Character](https://hormelz.itch.io/8-directional-melee-character) by Hormelz | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `media/cursors/` | Mouse cursor, quest marker | [Cursor Pack](https://kenney.nl/assets/cursor-pack) by Kenney | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `media/chests/` | Chest sprites | [PixelExplosive](https://pixelexplosive.itch.io) (12 Pixel Chest Sprites) | Custom (`LICENSE.txt`): free to use, **no redistribution** |

#### Not yet verified

| Folder | Used for | Notes |
|---|---|---|
| `media/raven-objects/` | Item and object icons (`fc*.png`) | Probably the free version of [Raven Fantasy Icons](https://clockworkraven.itch.io/raven-fantasy-icons) by Clockwork Raven. Its terms allow use in projects but **not redistribution as a separate asset pack** |
| `media/music/` | Background music | The filenames match Pixabay downloads (artists guilhermebernardes and composiia). Not confirmed |
| `media/materials/` | Crafting material icons | Source unknown |
| `media/rockz/` | Rock obstacle sprites | Source unknown |
| `media/title/` | Title screen art | Source unknown |
| `fortunes/` | NPC small-talk quotes | Source unknown |

Before you publish this repository or a build of it, confirm the sources marked as
unverified, and replace any asset that does not allow redistribution (chests, and
probably raven-objects). The CC BY and CC BY-SA licenses require you to credit the
authors listed above in the game itself, for example on a credits screen.
