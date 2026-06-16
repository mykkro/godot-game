# Combat Initiative, Multi-Actions & Belt Use

**Date:** 2026-06-16
**Status:** Approved

## Overview

Three related combat extensions:

1. **Initiative system** — each combatant has an initiative value (1–10) that determines who acts first each fight.
2. **QUICK perk** — new perk granting +1 initiative per level (max 3).
3. **Monster multi-actions** — some monsters act 2 or 3 times per round.
4. **Belt use in combat** — always-visible belt strip inside `BattleDialog`; using an item costs the hero's full turn.

---

## 1. Initiative System

### HeroStats

Add one new field:

```gdscript
var initiative: int = 5
```

- Serialised in `to_dict()` / `from_dict()` with default `5`.
- Capped at `10` whenever written (perk application, load).

### MonsterStats

Each species entry gains two new keys: `initiative` (1–10) and `actions` (1–3).

**Tier 1 — Critters (initiative 1–4, actions 1)**

| Species | initiative | actions |
|---|---|---|
| Earthworm | 1 | 1 |
| Slug | 1 | 1 |
| Slime slug | 2 | 1 |
| Roman snail | 1 | 1 |
| Starfish | 2 | 1 |
| Seahorse | 2 | 1 |
| Shrimp | 2 | 1 |
| Mouse | 3 | 1 |
| Rabbit | 4 | 1 |
| Arctic hare | 4 | 1 |
| Pig | 2 | 1 |
| Sheep | 2 | 1 |
| Salmon | 3 | 1 |
| Toad | 2 | 1 |
| Chameleon | 3 | 1 |
| Ant | 3 | 1 |
| Bee | 4 | 1 |
| Hedgehog | 2 | 1 |
| Squirrel | 4 | 1 |
| Squarrel | 4 | 1 |
| Pigeon | 3 | 1 |
| Gray parrot | 3 | 1 |
| Gull | 3 | 1 |
| Mallard | 3 | 1 |
| Swan | 3 | 1 |
| Puffin | 3 | 1 |
| Penguin | 2 | 1 |
| Purple cat | 4 | 1 |
| Lady beetle | 3 | 1 |
| Common blue | 3 | 1 |

**Tier 2 — Notable threats (initiative 3–7, actions 1)**

| Species | initiative | actions |
|---|---|---|
| Bat | 6 | 1 |
| Aurora bat | 6 | 1 |
| Crab | 3 | 1 |
| Jellyfish | 3 | 1 |
| Niptoad | 4 | 1 |
| Cockroach | 5 | 1 |
| Grasshopper | 6 | 1 |
| Cave fish | 4 | 1 |
| Dragonfly | 7 | 1 |
| Blue dog | 5 | 1 |
| Gossip | 4 | 1 |
| Snowman | 3 | 1 |
| Tumbleweed | 4 | 1 |
| Icewalker | 5 | 1 |
| Stripe | 5 | 1 |
| Octopus | 4 | 1 |
| Hyena | 7 | 1 |
| Geogrub | 3 | 1 |
| Ling | 4 | 1 |
| Kuku | 5 | 1 |
| Jiong | 4 | 1 |
| Wild boar | 6 | 1 |

**Tier 3 — Dangerous (initiative 4–9, actions 1–2)**

| Species | initiative | actions |
|---|---|---|
| Cave spider | 6 | 1 |
| White cave spider | 6 | 1 |
| Coral spider | 6 | 1 |
| Scorpion | 5 | 1 |
| Wolf | 7 | 1 |
| Fire salamander | 5 | 1 |
| Brown bear | 4 | 1 |
| Black bear | 5 | 1 |
| Angry crab | 4 | 1 |
| Stabbycrab | 5 | 1 |
| Thorn dragon | 7 | 2 |
| Electric eel | 6 | 1 |
| Shark | 8 | 2 |
| Spicatus | 5 | 1 |
| Twentacle | 4 | 1 |
| Whalkst | 5 | 1 |
| Rhunst | 5 | 1 |
| Geograb | 4 | 1 |
| Staruss | 5 | 1 |
| Coral monster | 5 | 1 |
| Gust | 7 | 1 |
| Pyrogust | 8 | 1 |
| Electrogust | 9 | 1 |
| Hydrogust | 7 | 1 |
| Stellectric | 7 | 1 |
| Starflake | 6 | 1 |
| Equestion | 6 | 1 |
| Circow | 4 | 1 |
| Polar bear | 6 | 2 |

**Tier 4 — Bosses**

| Species | initiative | actions |
|---|---|---|
| Sasquatch | 8 | 2 |
| Orca | 9 | 2 |
| Blue whale | 6 | 3 |

### MonsterNode

Add two fields read from `MonsterStats` in `_init_stats()`:

```gdscript
var initiative: int = 5
var actions:    int = 1

func _init_stats() -> void:
    var s      := MonsterStats.for_species(species)
    max_hp     = int(s.get("hp",         10))
    current_hp = max_hp
    attack     = int(s.get("attack",      4))
    defense    = int(s.get("defense",     1))
    xp_reward  = int(s.get("xp",        10))
    initiative = int(s.get("initiative",  5))
    actions    = int(s.get("actions",     1))
```

Defaults (`initiative=5, actions=1`) keep existing saved monsters working without migration.

### BattleDialog — turn order

New state variables:

```gdscript
var _hero_goes_first: bool = true
var _belt: Belt = null
```

`open()` gains a `belt: Belt` parameter and resolves initiative:

```gdscript
func open(monster: MonsterNode, hero: HeroStats, perks: CharacterPerks, belt: Belt) -> void:
    ...
    _belt = belt
    var hero_ini := mini(hero.initiative, 10)
    var mon_ini  := monster.initiative
    if hero_ini > mon_ini:
        _hero_goes_first = true
    elif mon_ini > hero_ini:
        _hero_goes_first = false
    else:
        _hero_goes_first = randf() < 0.5

    if _hero_goes_first:
        _add_log("You seize the initiative! (⚡%d vs ⚡%d)" % [hero_ini, mon_ini])
        _set_action_ui(true)
    else:
        _add_log("%s strikes first! (⚡%d vs ⚡%d)" % [monster.species, mon_ini, hero_ini])
        _monster_turn_sequence()
        if not _hero.is_dead():
            _set_action_ui(true)
```

After resolving their action, `_on_attack`, `_on_defend`, and `_on_use_belt_item` call the shared tail:

```gdscript
func _after_hero_action() -> void:
    _monster_turn_sequence()
    if not _hero.is_dead():
        _set_action_ui(true)
```

`_on_flee()` is the exception: on **success** it calls `_finish(_State.FLED)` directly and skips `_after_hero_action()`; on **failure** it calls `_after_hero_action()` as normal.

### `_monster_turn_sequence()`

```gdscript
func _monster_turn_sequence() -> void:
    for i in _monster.actions:
        var eff_def := _hero.defense * (2 if _defend_bonus else 1)
        var dmg     := _calc_damage(_monster.attack, eff_def)
        _hero.take_damage(dmg)
        _add_log("%s hits you for %d damage." % [_monster.species, dmg])
        _defend_bonus = false
        _refresh_bars()
        if _hero.is_dead():
            _finish(_State.LOSE)
            return
```

---

## 2. QUICK Perk

New entry in `PerkDef.ID`:

```gdscript
QUICK = 10
```

| Level | Name | Bonus |
|---|---|---|
| 1 | Nimble | +1 Initiative |
| 2 | Swift | +1 Initiative |
| 3 | Lightning Reflexes | +1 Initiative |

Max level 3. Applied as a stat perk (baked into `HeroStats` on pick).

**`PerkDef` additions:**

```gdscript
# get_max_level — add QUICK to the group that returns 3
ID.QUICK: return 3

# get_level_name
ID.QUICK:
    match level:
        1: return "Nimble"
        2: return "Swift"
        3: return "Lightning Reflexes"

# get_stat_delta
ID.QUICK: return {"initiative": 1}

# perk_description
ID.QUICK: return "+1 Initiative (will be %d)" % (hero_current_initiative + 1)
```

**`PerkPickUI._apply_pick()`** gains:

```gdscript
if delta.has("initiative"):
    _stats.initiative = mini(10, _stats.initiative + delta["initiative"])
```

---

## 3. Belt Use in Combat

### BattleDialog changes

`_build_ui()` adds a belt strip between the hero stats row and the action buttons:

- `HBoxContainer` with 5 `TextureRect`-based slot panels (32×32 px each).
- Each slot has a small count `Label` badge (bottom-right).
- Slot panels that contain a useable item render as `Button`; empty/non-useable slots are dimmed `PanelContainer`.
- The strip is rebuilt/refreshed by `_refresh_belt_strip()` called after each `_belt` change.

### `_on_use_belt_item(index: int)`

```gdscript
func _on_use_belt_item(index: int) -> void:
    _set_action_ui(false)
    var item_type := _belt.consume(index)
    match item_type:
        MapObject.Type.HEALTH_POTION:
            var amt := 20
            _hero.heal(amt)
            _add_log("You drink a Health Potion.  +%d HP." % amt)
        MapObject.Type.MANA_POTION:
            var amt := 15
            _hero.current_mana = mini(_hero.max_mana, _hero.current_mana + amt)
            _hero.changed.emit()
            _add_log("You drink a Mana Potion.  +%d MP." % amt)
    _refresh_bars()
    _refresh_belt_strip()
    _after_hero_action()
```

### Initiative display

A small `⚡ N` label is placed:
- Next to the monster name (shows `monster.initiative`).
- In the hero stats row (shows `hero.initiative`).

Both update only on `open()` (initiative does not change mid-fight).

---

## 4. Files Touched

| File | Change |
|---|---|
| `scripts/data/hero_stats.gd` | Add `initiative` field; save/load |
| `scripts/data/monster_stats.gd` | Add `initiative` + `actions` to every species entry |
| `scripts/actors/monster_node.gd` | Add `initiative` + `actions` fields; read in `_init_stats()` |
| `scripts/data/perk_def.gd` | Add `QUICK = 10`; level names, stat delta, description |
| `scripts/ui/perk_pick_ui.gd` | Handle `initiative` delta in `_apply_pick()` |
| `scripts/ui/battle_dialog.gd` | Initiative resolution; `_monster_turn_sequence()`; belt strip UI; `_on_use_belt_item()`; `⚡` labels; `open()` gains `belt` param |
| `scripts/main.gd` | Pass `belt` to `BattleDialog.open()` |
