# Combat Perks & Level-Up Pick System

**Date:** 2026-06-15
**Status:** Approved

## Overview

Introduce eight new combat-focused perks and a level-up perk selection UI. On every level gain the player is offered 3 randomly drawn perk options (new perks or upgrades to already-owned perks) and must pick one. Perks have permanent stat effects (baked into HeroStats) or runtime effects checked during battle (queried from CharacterPerks).

---

## Perk Definitions

All new perks have max level 3. Each level stacks the base bonus.

| PerkDef.ID | Display Name | Effect per level | Application |
|---|---|---|---|
| STRONG | Strong | +1 Attack | Baked into HeroStats on pick |
| TOUGH | Tough | +5 Max HP | Baked into HeroStats on pick |
| WISE | Wise | +3 Max Mana | Baked into HeroStats on pick |
| ARMORED | Armored | +1 Defense | Baked into HeroStats on pick |
| SPELL_FOCUS | Spell Focus | +1 Magic | Baked into HeroStats on pick |
| VAMPIRIC | Vampiric | Heal N HP after killing monster | Queried in BattleDialog at WIN |
| EFFICIENT_CASTER | Efficient Caster | Spells cost N less mana (min 1) | Pickable now (tracked in CharacterPerks); runtime effect deferred until spell system |
| BERSERKER | Berserker | +3N Attack when below 30% HP | Queried in BattleDialog on attack |

Existing perks (TRADER, SWIFT_WALKER) are unchanged.

### New PerkDef helpers

```
static func get_stat_delta(perk: ID, level: int) -> Dictionary
  # Returns {attack, max_hp, max_mana, defense, magic} deltas for ONE level gain.
  # Only populated for stat perks; returns empty dict for runtime perks.

static func get_vampiric_heal(level: int) -> int   # level * 1
static func get_berserker_bonus(level: int) -> int  # level * 3
static func perk_description(perk: ID, level: int) -> String
  # Human-readable description of what the NEXT level gives.
```

---

## Level-Up Perk Pick UI (PerkPickUI)

New `CanvasLayer` (layer 80), built procedurally like all other UI nodes.

### Trigger

`main.gd` currently shows a text hint when `add_xp()` returns `true`. Replace that with:
```
if leveled:
    _perk_pick_ui.open(_avatar.stats, _avatar.perks)
```
The game remains paused (BattleDialog already paused it; PerkPickUI keeps it paused).

### Pool building

```
var pool: Array[PerkDef.ID] = []
for each perk_id in PerkDef.ID:
    if perks.get_level(perk_id) < PerkDef.get_max_level(perk_id):
        pool.append(perk_id)
pool.shuffle()
var choices := pool.slice(0, min(3, pool.size()))
```

If `choices` is empty (all perks maxed), skip the UI entirely.

### Layout

Dark dimmed overlay (same style as BattleDialog). Panel contains:
- Header: "LEVEL UP! — Choose a Perk" (gold text)
- Subheader: "Level N" 
- HBox with 2–3 perk cards side by side
- Keyboard hint: "1 / 2 / 3 — select"

Each perk card (PanelContainer, ~140×180 px):
- Perk name (large)
- Level indicator: "Level X → X+1" (or "NEW" if level 0)
- Description of what this level grants
- Highlighted on hover/focus

No cancel/escape — player must pick.

### On pick

```
func _apply_pick(perk_id: PerkDef.ID) -> void:
    var old_level := _perks.get_level(perk_id)
    var new_level := old_level + 1
    _perks.set_level(perk_id, new_level)
    var delta := PerkDef.get_stat_delta(perk_id, new_level)
    if delta.has("attack"):   _stats.attack   += delta.attack
    if delta.has("max_hp"):
        _stats.max_hp     += delta.max_hp
        _stats.current_hp  = mini(_stats.current_hp + delta.max_hp, _stats.max_hp)
    if delta.has("max_mana"):  _stats.max_mana  += delta.max_mana
    if delta.has("defense"):   _stats.defense   += delta.defense
    if delta.has("magic"):     _stats.magic     += delta.magic
    perk_picked.emit()
```

`main.gd` connects `perk_picked` to save stats + perks, then closes the UI.

---

## BattleDialog Changes

`open()` signature extends to:
```
func open(monster: MonsterNode, hero: HeroStats, perks: CharacterPerks) -> void
```

`main.gd` passes `_avatar.perks` in the `monster_fight_requested` connection.

### Berserker (in `_on_attack`)

```
var eff_atk := _hero.attack
var berk_lv := _perks.get_level(PerkDef.ID.BERSERKER)
if berk_lv > 0 and float(_hero.current_hp) / float(_hero.max_hp) < 0.30:
    var bonus := PerkDef.get_berserker_bonus(berk_lv)
    eff_atk += bonus
    _add_log("Berserker rage! +%d attack." % bonus)
var dmg := _calc_damage(eff_atk, _monster.defense)
```

### Vampiric (in `_finish(WIN)`, before result label)

```
var vamp_lv := _perks.get_level(PerkDef.ID.VAMPIRIC)
if vamp_lv > 0:
    var heal := PerkDef.get_vampiric_heal(vamp_lv)
    _hero.heal(heal)
    _add_log("You drain %d HP." % heal)
```

---

## Save / Load

`CharacterPerks` already serialises via `to_dict()` / `from_dict()`. No schema changes needed — the new perk IDs are just new integer keys. `HeroStats` already stores baked stats. No migration required.

---

## CharacterUI

No changes required. `_refresh_perks()` already iterates all `PerkDef.ID` values, so new perks appear automatically once they have a level > 0.

---

## Files Touched

| File | Change |
|---|---|
| `scripts/data/perk_def.gd` | Add 8 new IDs + helper functions |
| `scripts/ui/perk_pick_ui.gd` | New file |
| `scripts/main.gd` | Wire PerkPickUI; pass perks to BattleDialog |
| `scripts/ui/battle_dialog.gd` | Accept perks; Berserker + Vampiric logic |
