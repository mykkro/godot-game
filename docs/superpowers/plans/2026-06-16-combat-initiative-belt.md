# Combat Initiative, Multi-Actions & Belt Use — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-species initiative (1–10) that decides who goes first each fight, let strong monsters act 2–3 times per round, add a QUICK perk (+1 initiative/level, max 3), and show a useable belt strip inside BattleDialog.

**Architecture:** Data changes first (HeroStats, MonsterStats, MonsterNode, PerkDef) so each commit is self-contained; BattleDialog is then extended in two passes — core turn-flow logic, then the belt-strip UI and initiative labels.

**Tech Stack:** GDScript / Godot 4, no automated test framework — each task ends with a manual verification note.

**Spec:** `docs/superpowers/specs/2026-06-16-combat-initiative-belt-design.md`

---

## Task 1: HeroStats — `initiative` field

**Files:**
- Modify: `scripts/data/hero_stats.gd`

- [ ] **Step 1: Add the field and update `to_dict` / `from_dict`**

In `scripts/data/hero_stats.gd`, make the following changes:

Add the field after `defense`:
```gdscript
var defense:      int = 2
var initiative:   int = 5   # add this line
```

In `to_dict()`, add after `"defense"`:
```gdscript
"initiative":   initiative,
```

In `from_dict()`, add after `s.defense = ...`:
```gdscript
s.initiative = int(d.get("initiative", 5))
```

The full updated `to_dict` and `from_dict` after the change:
```gdscript
func to_dict() -> Dictionary:
    return {
        "level":        level,
        "xp":           xp,
        "max_hp":       max_hp,
        "current_hp":   current_hp,
        "max_mana":     max_mana,
        "current_mana": current_mana,
        "attack":       attack,
        "magic":        magic,
        "defense":      defense,
        "initiative":   initiative,
    }


static func from_dict(d: Dictionary) -> HeroStats:
    var s := HeroStats.new()
    s.level        = int(d.get("level",        1))
    s.xp           = int(d.get("xp",           0))
    s.max_hp       = int(d.get("max_hp",       30))
    s.current_hp   = int(d.get("current_hp",   30))
    s.max_mana     = int(d.get("max_mana",     10))
    s.current_mana = int(d.get("current_mana", 10))
    s.attack       = int(d.get("attack",        6))
    s.magic        = int(d.get("magic",         4))
    s.defense      = int(d.get("defense",       2))
    s.initiative   = int(d.get("initiative",    5))
    return s
```

- [ ] **Step 2: Commit**

```bash
git add scripts/data/hero_stats.gd
git commit -m "feat: add initiative field to HeroStats (default 5)"
```

---

## Task 2: MonsterStats + MonsterNode — `initiative` and `actions`

**Files:**
- Modify: `scripts/data/monster_stats.gd`
- Modify: `scripts/actors/monster_node.gd`

- [ ] **Step 1: Replace the `_table` dictionary in `scripts/data/monster_stats.gd`**

Replace the entire `static var _table` with:
```gdscript
static var _table: Dictionary = {
    # ── Tier 1: Critters / harmless ──────────────────────────────────
    "Mouse":              {hp=5,  attack=2, defense=0, magic=0, xp=3,  initiative=3, actions=1},
    "Rabbit":             {hp=7,  attack=2, defense=0, magic=0, xp=4,  initiative=4, actions=1},
    "Arctic hare":        {hp=8,  attack=2, defense=0, magic=0, xp=4,  initiative=4, actions=1},
    "Squirrel":           {hp=6,  attack=2, defense=0, magic=0, xp=3,  initiative=4, actions=1},
    "Squarrel":           {hp=6,  attack=2, defense=0, magic=0, xp=3,  initiative=4, actions=1},
    "Hedgehog":           {hp=8,  attack=2, defense=1, magic=0, xp=5,  initiative=2, actions=1},
    "Ant":                {hp=5,  attack=2, defense=0, magic=0, xp=3,  initiative=3, actions=1},
    "Bee":                {hp=5,  attack=3, defense=0, magic=0, xp=4,  initiative=4, actions=1},
    "Earthworm":          {hp=4,  attack=1, defense=0, magic=0, xp=2,  initiative=1, actions=1},
    "Slug":               {hp=6,  attack=1, defense=0, magic=0, xp=3,  initiative=1, actions=1},
    "Slime slug":         {hp=8,  attack=2, defense=0, magic=0, xp=5,  initiative=2, actions=1},
    "Pigeon":             {hp=6,  attack=2, defense=0, magic=0, xp=3,  initiative=3, actions=1},
    "Gray parrot":        {hp=7,  attack=2, defense=0, magic=0, xp=4,  initiative=3, actions=1},
    "Gull":               {hp=7,  attack=3, defense=0, magic=0, xp=4,  initiative=3, actions=1},
    "Mallard":            {hp=8,  attack=2, defense=0, magic=0, xp=4,  initiative=3, actions=1},
    "Swan":               {hp=9,  attack=3, defense=0, magic=0, xp=5,  initiative=3, actions=1},
    "Puffin":             {hp=7,  attack=2, defense=0, magic=0, xp=4,  initiative=3, actions=1},
    "Penguin":            {hp=9,  attack=2, defense=1, magic=0, xp=5,  initiative=2, actions=1},
    "Sheep":              {hp=8,  attack=2, defense=0, magic=0, xp=4,  initiative=2, actions=1},
    "Pig":                {hp=10, attack=3, defense=0, magic=0, xp=5,  initiative=2, actions=1},
    "Purple cat":         {hp=8,  attack=3, defense=0, magic=0, xp=5,  initiative=4, actions=1},
    "Lady beetle":        {hp=5,  attack=2, defense=0, magic=0, xp=3,  initiative=3, actions=1},
    "Common blue":        {hp=5,  attack=2, defense=0, magic=0, xp=3,  initiative=3, actions=1},
    "Chameleon":          {hp=9,  attack=3, defense=0, magic=0, xp=5,  initiative=3, actions=1},
    "Toad":               {hp=9,  attack=3, defense=0, magic=0, xp=5,  initiative=2, actions=1},
    "Salmon":             {hp=8,  attack=3, defense=0, magic=0, xp=4,  initiative=3, actions=1},
    "Shrimp":             {hp=6,  attack=2, defense=0, magic=0, xp=3,  initiative=2, actions=1},
    "Starfish":           {hp=7,  attack=2, defense=1, magic=0, xp=4,  initiative=2, actions=1},
    "Seahorse":           {hp=7,  attack=2, defense=0, magic=0, xp=4,  initiative=2, actions=1},
    # ── Tier 2: Notable threats ──────────────────────────────────────
    "Bat":                {hp=10, attack=4, defense=0, magic=0, xp=7,  initiative=6, actions=1},
    "Aurora bat":         {hp=11, attack=4, defense=0, magic=1, xp=9,  initiative=6, actions=1},
    "Crab":               {hp=12, attack=4, defense=2, magic=0, xp=9,  initiative=3, actions=1},
    "Jellyfish":          {hp=10, attack=3, defense=0, magic=2, xp=8,  initiative=3, actions=1},
    "Niptoad":            {hp=11, attack=4, defense=1, magic=0, xp=8,  initiative=4, actions=1},
    "Cockroach":          {hp=11, attack=3, defense=1, magic=0, xp=7,  initiative=5, actions=1},
    "Grasshopper":        {hp=10, attack=4, defense=0, magic=0, xp=7,  initiative=6, actions=1},
    "Cave fish":          {hp=10, attack=3, defense=0, magic=0, xp=7,  initiative=4, actions=1},
    "Dragonfly":          {hp=9,  attack=4, defense=0, magic=0, xp=7,  initiative=7, actions=1},
    "Blue dog":           {hp=12, attack=4, defense=0, magic=0, xp=8,  initiative=5, actions=1},
    "Gossip":             {hp=10, attack=3, defense=0, magic=2, xp=8,  initiative=4, actions=1},
    "Snowman":            {hp=14, attack=4, defense=2, magic=1, xp=10, initiative=3, actions=1},
    "Tumbleweed":         {hp=10, attack=4, defense=0, magic=0, xp=7,  initiative=4, actions=1},
    "Icewalker":          {hp=14, attack=5, defense=1, magic=1, xp=11, initiative=5, actions=1},
    "Stripe":             {hp=12, attack=4, defense=1, magic=0, xp=8,  initiative=5, actions=1},
    "Roman snail":        {hp=12, attack=2, defense=3, magic=0, xp=8,  initiative=1, actions=1},
    "Octopus":            {hp=13, attack=4, defense=1, magic=1, xp=10, initiative=4, actions=1},
    "Hyena":              {hp=14, attack=5, defense=1, magic=0, xp=11, initiative=7, actions=1},
    "Geogrub":            {hp=12, attack=4, defense=1, magic=0, xp=9,  initiative=3, actions=1},
    "Ling":               {hp=11, attack=3, defense=1, magic=1, xp=8,  initiative=4, actions=1},
    "Kuku":               {hp=10, attack=4, defense=0, magic=1, xp=8,  initiative=5, actions=1},
    "Jiong":              {hp=12, attack=4, defense=1, magic=0, xp=8,  initiative=4, actions=1},
    "Wild boar":          {hp=16, attack=6, defense=1, magic=0, xp=13, initiative=6, actions=1},
    # ── Tier 3: Dangerous ────────────────────────────────────────────
    "Cave spider":        {hp=14, attack=5, defense=1, magic=0, xp=12, initiative=6, actions=1},
    "White cave spider":  {hp=15, attack=5, defense=1, magic=0, xp=13, initiative=6, actions=1},
    "Coral spider":       {hp=14, attack=5, defense=1, magic=1, xp=13, initiative=6, actions=1},
    "Scorpion":           {hp=15, attack=6, defense=2, magic=0, xp=14, initiative=5, actions=1},
    "Wolf":               {hp=18, attack=6, defense=1, magic=0, xp=15, initiative=7, actions=1},
    "Fire salamander":    {hp=15, attack=5, defense=1, magic=2, xp=14, initiative=5, actions=1},
    "Brown bear":         {hp=22, attack=7, defense=2, magic=0, xp=18, initiative=4, actions=1},
    "Black bear":         {hp=20, attack=7, defense=1, magic=0, xp=17, initiative=5, actions=1},
    "Angry crab":         {hp=16, attack=6, defense=3, magic=0, xp=15, initiative=4, actions=1},
    "Stabbycrab":         {hp=16, attack=7, defense=2, magic=0, xp=16, initiative=5, actions=1},
    "Thorn dragon":       {hp=22, attack=8, defense=2, magic=3, xp=22, initiative=7, actions=2},
    "Electric eel":       {hp=16, attack=6, defense=1, magic=3, xp=16, initiative=6, actions=1},
    "Shark":              {hp=24, attack=8, defense=2, magic=0, xp=20, initiative=8, actions=2},
    "Spicatus":           {hp=18, attack=6, defense=2, magic=0, xp=15, initiative=5, actions=1},
    "Twentacle":          {hp=20, attack=6, defense=1, magic=2, xp=17, initiative=4, actions=1},
    "Whalkst":            {hp=22, attack=7, defense=2, magic=0, xp=18, initiative=5, actions=1},
    "Rhunst":             {hp=20, attack=7, defense=1, magic=1, xp=17, initiative=5, actions=1},
    "Geograb":            {hp=18, attack=6, defense=2, magic=0, xp=15, initiative=4, actions=1},
    "Staruss":            {hp=16, attack=6, defense=1, magic=2, xp=15, initiative=5, actions=1},
    "Coral monster":      {hp=20, attack=7, defense=2, magic=1, xp=18, initiative=5, actions=1},
    "Gust":               {hp=14, attack=5, defense=0, magic=3, xp=13, initiative=7, actions=1},
    "Pyrogust":           {hp=16, attack=6, defense=0, magic=4, xp=16, initiative=8, actions=1},
    "Electrogust":        {hp=16, attack=5, defense=0, magic=5, xp=17, initiative=9, actions=1},
    "Hydrogust":          {hp=18, attack=5, defense=1, magic=4, xp=17, initiative=7, actions=1},
    "Stellectric":        {hp=18, attack=6, defense=1, magic=4, xp=18, initiative=7, actions=1},
    "Starflake":          {hp=16, attack=5, defense=1, magic=3, xp=15, initiative=6, actions=1},
    "Equestion":          {hp=18, attack=7, defense=1, magic=2, xp=17, initiative=6, actions=1},
    "Circow":             {hp=20, attack=6, defense=2, magic=0, xp=16, initiative=4, actions=1},
    "Polar bear":         {hp=28, attack=8, defense=3, magic=0, xp=22, initiative=6, actions=2},
    # ── Tier 4: Boss ─────────────────────────────────────────────────
    "Sasquatch":          {hp=35, attack=9,  defense=3, magic=0, xp=35, initiative=8, actions=2},
    "Orca":               {hp=40, attack=11, defense=3, magic=0, xp=45, initiative=9, actions=2},
    "Blue whale":         {hp=50, attack=10, defense=3, magic=0, xp=50, initiative=6, actions=3},
}
```

- [ ] **Step 2: Update MonsterNode to read `initiative` and `actions`**

In `scripts/actors/monster_node.gd`, add two fields after `xp_reward`:
```gdscript
var xp_reward: int = 0
var initiative: int = 5
var actions:    int = 1
```

In `_init_stats()`, add two lines after `xp_reward = ...`:
```gdscript
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

- [ ] **Step 3: Commit**

```bash
git add scripts/data/monster_stats.gd scripts/actors/monster_node.gd
git commit -m "feat: add initiative and actions per species to MonsterStats; MonsterNode reads them"
```

---

## Task 3: QUICK perk — PerkDef + PerkPickUI

**Files:**
- Modify: `scripts/data/perk_def.gd`
- Modify: `scripts/ui/perk_pick_ui.gd`

- [ ] **Step 1: Add QUICK to PerkDef enum**

In `scripts/data/perk_def.gd`, add `QUICK` to the enum:
```gdscript
enum ID {
    TRADER           = 0,
    SWIFT_WALKER     = 1,
    STRONG           = 2,
    TOUGH            = 3,
    WISE             = 4,
    ARMORED          = 5,
    SPELL_FOCUS      = 6,
    VAMPIRIC         = 7,
    EFFICIENT_CASTER = 8,
    BERSERKER        = 9,
    QUICK            = 10,
}
```

- [ ] **Step 2: Add `get_perk_name` case**

In `get_perk_name()`, add before `return "Unknown"`:
```gdscript
ID.QUICK: return "Quick"
```

- [ ] **Step 3: Add `get_max_level` case**

In `get_max_level()`, add QUICK to the group that returns 3:
```gdscript
ID.STRONG, ID.TOUGH, ID.WISE, ID.ARMORED, \
ID.SPELL_FOCUS, ID.VAMPIRIC, \
ID.EFFICIENT_CASTER, ID.BERSERKER, ID.QUICK: return 3
```

- [ ] **Step 4: Add `get_level_name` case**

In `get_level_name()`, add after the BERSERKER block:
```gdscript
ID.QUICK:
    match level:
        1: return "Nimble"
        2: return "Swift"
        3: return "Lightning Reflexes"
```

- [ ] **Step 5: Add `get_stat_delta` case**

In `get_stat_delta()`, add after `ID.SPELL_FOCUS`:
```gdscript
ID.QUICK: return {"initiative": 1}
```

- [ ] **Step 6: Add `perk_description` case**

In `perk_description()`, add after the BERSERKER case:
```gdscript
ID.QUICK: return "+1 Initiative"
```

- [ ] **Step 7: Handle `initiative` delta in PerkPickUI**

In `scripts/ui/perk_pick_ui.gd`, inside `_apply_pick()`, add after the `magic` delta block:
```gdscript
if delta.has("initiative"):
    _stats.initiative = mini(10, _stats.initiative + delta["initiative"])
```

The full `_apply_pick()` after the change:
```gdscript
func _apply_pick(perk_id: PerkDef.ID) -> void:
    if _picking:
        return
    _picking = true
    var new_level := _perks.get_level(perk_id) + 1
    _perks.set_level(perk_id, new_level)

    var delta := PerkDef.get_stat_delta(perk_id)
    if delta.has("attack"):
        _stats.attack  += delta["attack"]
    if delta.has("max_hp"):
        _stats.max_hp    += delta["max_hp"]
        _stats.current_hp = mini(_stats.current_hp + delta["max_hp"], _stats.max_hp)
    if delta.has("max_mana"):
        _stats.max_mana += delta["max_mana"]
    if delta.has("defense"):
        _stats.defense += delta["defense"]
    if delta.has("magic"):
        _stats.magic   += delta["magic"]
    if delta.has("initiative"):
        _stats.initiative = mini(10, _stats.initiative + delta["initiative"])
    _stats.changed.emit()

    _overlay.visible  = false
    get_tree().paused = false
    perk_picked.emit()
    _picking = false
```

- [ ] **Step 8: Commit**

```bash
git add scripts/data/perk_def.gd scripts/ui/perk_pick_ui.gd
git commit -m "feat: add QUICK perk (+1 initiative/level, max 3); wire delta in PerkPickUI"
```

**Verify:** Level up in-game — the QUICK perk should appear in the perk pick UI. Picking it should not crash.

---

## Task 4: BattleDialog — turn order, multi-actions, `_after_hero_action()` + main.gd

**Files:**
- Modify: `scripts/ui/battle_dialog.gd`
- Modify: `scripts/main.gd`

- [ ] **Step 1: Add new state variables to BattleDialog**

In `scripts/ui/battle_dialog.gd`, add after `var _perks`:
```gdscript
var _perks:        CharacterPerks = null
var _belt:         Belt           = null
var _hero_goes_first: bool        = true
var _state:        _State         = _State.CHOOSING
```

(This replaces the existing `var _state` line — move `_belt` and `_hero_goes_first` before it.)

The full state var block should look like:
```gdscript
var _hero:            HeroStats      = null
var _monster:         MonsterNode    = null
var _defend_bonus:    bool           = false
var _perks:           CharacterPerks = null
var _belt:            Belt           = null
var _hero_goes_first: bool           = true
var _state:           _State         = _State.CHOOSING
```

- [ ] **Step 2: Update `open()` to accept `belt` and resolve initiative**

Replace the entire `open()` function:
```gdscript
func open(monster: MonsterNode, hero: HeroStats, perks: CharacterPerks, belt: Belt) -> void:
    _hero          = hero
    _monster       = monster
    _perks         = perks
    _belt          = belt
    _defend_bonus  = false
    _state         = _State.CHOOSING

    _mon_sprite.texture = TextureCache.get_being_texture(monster.species)
    _mon_name.text      = monster.species

    _mon_hp_bar.max_value = monster.max_hp
    _mon_hp_bar.value     = monster.current_hp

    _hero_hp_bar.max_value = hero.max_hp
    _hero_mp_bar.max_value = hero.max_mana

    _clear_log()
    _add_log("A %s appears!" % monster.species)

    _set_action_ui(false)
    _result_lbl.visible = false
    _ok_btn.visible     = false
    _refresh_bars()
    _overlay.visible    = true
    get_tree().paused   = true

    # Resolve initiative
    var hero_ini := mini(hero.initiative, 10)
    var mon_ini  := monster.initiative
    if hero_ini > mon_ini:
        _hero_goes_first = true
    elif mon_ini > hero_ini:
        _hero_goes_first = false
    else:
        _hero_goes_first = randf() < 0.5

    if _hero_goes_first:
        _add_log("You seize the initiative!  (⚡%d vs ⚡%d)" % [hero_ini, mon_ini])
        _set_action_ui(true)
    else:
        _add_log("%s strikes first!  (⚡%d vs ⚡%d)" % [monster.species, mon_ini, hero_ini])
        _monster_turn_sequence()
        if not _hero.is_dead():
            _set_action_ui(true)
```

- [ ] **Step 3: Add `_after_hero_action()` and `_monster_turn_sequence()`**

Add these two functions after `_on_flee()`:
```gdscript
func _after_hero_action() -> void:
    _monster_turn_sequence()
    if not _hero.is_dead():
        _set_action_ui(true)


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

- [ ] **Step 4: Update `_on_attack()` to call `_after_hero_action()`**

Replace the last two lines of `_on_attack()` (currently `_monster_turn()`):
```gdscript
func _on_attack() -> void:
    _set_action_ui(false)
    _defend_bonus = false
    var eff_atk := _hero.attack
    if _perks != null:
        var berk_lv := _perks.get_level(PerkDef.ID.BERSERKER)
        if berk_lv > 0 and _hero.max_hp > 0 and float(_hero.current_hp) / float(_hero.max_hp) < 0.30:
            var bonus := PerkDef.get_berserker_bonus(berk_lv)
            eff_atk += bonus
            _add_log("Berserker rage!  +%d attack." % bonus)
    var dmg := _calc_damage(eff_atk, _monster.defense)
    _monster.current_hp = maxi(0, _monster.current_hp - dmg)
    _add_log("You strike %s for %d damage." % [_monster.species, dmg])
    _refresh_bars()
    if _monster.current_hp <= 0:
        _finish(_State.WIN)
        return
    _after_hero_action()
```

- [ ] **Step 5: Update `_on_defend()` and `_on_flee()`**

Replace `_on_defend()`:
```gdscript
func _on_defend() -> void:
    _set_action_ui(false)
    _defend_bonus = true
    _add_log("You brace yourself.")
    _after_hero_action()
```

Replace `_on_flee()`:
```gdscript
func _on_flee() -> void:
    _set_action_ui(false)
    if randf() < FLEE_ODDS:
        _add_log("You flee successfully!")
        _finish(_State.FLED)
    else:
        _add_log("You can't escape!")
        _after_hero_action()
```

- [ ] **Step 6: Delete the old `_monster_turn()` function**

Remove this entire function from `battle_dialog.gd` (it's replaced by `_monster_turn_sequence()`):
```gdscript
func _monster_turn() -> void:
    var eff_def := _hero.defense * (2 if _defend_bonus else 1)
    var dmg     := _calc_damage(_monster.attack, eff_def)
    _hero.take_damage(dmg)
    _add_log("%s hits you for %d damage." % [_monster.species, dmg])
    _defend_bonus = false
    _refresh_bars()
    if _hero.is_dead():
        _finish(_State.LOSE)
    else:
        _set_action_ui(true)
```

- [ ] **Step 7: Update the call site in `main.gd`**

In `scripts/main.gd`, find the `monster_fight_requested` connection (line ~149–152):
```gdscript
_avatar.monster_fight_requested.connect(
    func(m: MonsterNode) -> void:
        _battle_dialog.open(m, _avatar.stats, _avatar.perks)
)
```

Change to:
```gdscript
_avatar.monster_fight_requested.connect(
    func(m: MonsterNode) -> void:
        _battle_dialog.open(m, _avatar.stats, _avatar.perks, _avatar.belt)
)
```

- [ ] **Step 8: Commit**

```bash
git add scripts/ui/battle_dialog.gd scripts/main.gd
git commit -m "feat: initiative turn order, multi-action monster sequence, _after_hero_action refactor"
```

**Verify:** Start a fight. The log should say "You seize the initiative! (⚡5 vs ⚡N)" or "[Monster] strikes first!". Defending should halve only the first hit of a multi-action monster. Bosses (Sasquatch, Orca, Blue whale) should attack 2–3 times per round.

---

## Task 5: BattleDialog — belt strip UI + item use

**Files:**
- Modify: `scripts/ui/battle_dialog.gd`

- [ ] **Step 1: Add belt strip state variables**

Add after the existing UI node declarations (near the top of the file, after `_ok_btn`):
```gdscript
var _ok_btn:        Button        = null

var _belt_slot_panels: Array = []   # 5 PanelContainers
var _belt_slot_icons:  Array = []   # 5 TextureRect
var _belt_slot_badges: Array = []   # 5 Label (count)
```

- [ ] **Step 2: Add `_build_belt_strip()` call inside `_build_ui()`**

In `_build_ui()`, find where the action buttons row is added:
```gdscript
# Action buttons
var btn_row := HBoxContainer.new()
```

Insert the belt strip and a separator **before** that line:
```gdscript
# Belt strip
_build_belt_strip(vbox)
vbox.add_child(_hsep())

# Action buttons
var btn_row := HBoxContainer.new()
```

- [ ] **Step 3: Add `_build_belt_strip()` method**

Add this new method after `_build_ui()`:
```gdscript
func _build_belt_strip(parent_vbox: VBoxContainer) -> void:
    var lbl := Label.new()
    lbl.text = "QUICK USE"
    lbl.add_theme_font_size_override("font_size", 11)
    lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.62))
    lbl.uppercase = true
    parent_vbox.add_child(lbl)

    var hbox := HBoxContainer.new()
    hbox.add_theme_constant_override("h_separation", 6)
    hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    parent_vbox.add_child(hbox)

    for i in 5:
        var panel := PanelContainer.new()
        panel.custom_minimum_size = Vector2(38, 38)
        panel.process_mode = Node.PROCESS_MODE_ALWAYS

        var bg := StyleBoxFlat.new()
        bg.bg_color     = Color(0.10, 0.10, 0.12, 0.90)
        bg.border_color = Color(0.26, 0.26, 0.28, 0.8)
        bg.set_border_width_all(1)
        bg.set_corner_radius_all(3)
        panel.add_theme_stylebox_override("panel", bg)
        hbox.add_child(panel)

        var icon := TextureRect.new()
        icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        icon.expand_mode    = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
        icon.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        icon.mouse_filter   = Control.MOUSE_FILTER_IGNORE
        panel.add_child(icon)

        var badge := Label.new()
        badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
        badge.offset_left   = -22; badge.offset_top    = -12
        badge.offset_right  = -1;  badge.offset_bottom = -1
        badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        badge.add_theme_font_size_override("font_size", 9)
        badge.add_theme_color_override("font_color", Color(1.0, 1.0, 0.65))
        badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
        badge.visible      = false
        panel.add_child(badge)

        var key_lbl := Label.new()
        key_lbl.text = str(i + 1)
        key_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
        key_lbl.offset_left   = 2;  key_lbl.offset_top    = 1
        key_lbl.offset_right  = 10; key_lbl.offset_bottom = 10
        key_lbl.add_theme_font_size_override("font_size", 8)
        key_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
        key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_child(key_lbl)

        var idx := i
        panel.gui_input.connect(func(event: InputEvent) -> void:
            if not (event is InputEventMouseButton):
                return
            var mb := event as InputEventMouseButton
            if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
                if _belt != null and _belt.has_item(idx) \
                        and PickableItemDef.is_useable(_belt.get_type(idx)) \
                        and _btn_attack.visible:
                    _on_use_belt_item(idx)
                panel.accept_event()
        )

        _belt_slot_panels.append(panel)
        _belt_slot_icons.append(icon)
        _belt_slot_badges.append(badge)
```

(`_btn_attack.visible` is true only when it is the hero's turn to pick an action.)

- [ ] **Step 4: Add `_refresh_belt_strip()` method**

Add after `_build_belt_strip()`:
```gdscript
func _refresh_belt_strip() -> void:
    if _belt == null:
        return
    for i in 5:
        var icon  := _belt_slot_icons[i]  as TextureRect
        var badge := _belt_slot_badges[i] as Label
        var panel := _belt_slot_panels[i] as PanelContainer

        if _belt.has_item(i) and PickableItemDef.is_useable(_belt.get_type(i)):
            icon.texture = PickableItemDef.get_texture(_belt.get_type(i))
            var cnt := _belt.get_count(i)
            badge.text    = str(cnt) if cnt > 1 else ""
            badge.visible = cnt > 1
            var bg := StyleBoxFlat.new()
            bg.bg_color     = Color(0.12, 0.12, 0.18, 0.95)
            bg.border_color = Color(0.65, 0.55, 0.20, 0.90)
            bg.set_border_width_all(1)
            bg.set_corner_radius_all(3)
            panel.add_theme_stylebox_override("panel", bg)
        else:
            icon.texture  = null
            badge.visible = false
            var bg := StyleBoxFlat.new()
            bg.bg_color     = Color(0.10, 0.10, 0.12, 0.90)
            bg.border_color = Color(0.20, 0.20, 0.22, 0.6)
            bg.set_border_width_all(1)
            bg.set_corner_radius_all(3)
            panel.add_theme_stylebox_override("panel", bg)
```

- [ ] **Step 5: Add `_on_use_belt_item()` method**

Add after `_refresh_belt_strip()`:
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

- [ ] **Step 6: Call `_refresh_belt_strip()` in `open()`**

In `open()`, after `_refresh_bars()` and before the initiative block, add:
```gdscript
_refresh_bars()
_refresh_belt_strip()
```

- [ ] **Step 7: Commit**

```bash
git add scripts/ui/battle_dialog.gd
git commit -m "feat: belt quick-use strip in BattleDialog; Health/Mana Potion useable in combat"
```

**Verify:** Open a fight while having potions in belt slots 1–2. The strip should appear above the action buttons showing the potion icons with golden borders. Clicking a potion slot should heal/restore mana, log the message, update the count badge, and then the monster attacks.

---

## Task 6: BattleDialog — initiative display labels (⚡)

**Files:**
- Modify: `scripts/ui/battle_dialog.gd`

- [ ] **Step 1: Add label state variables**

Add after the existing UI node declarations block:
```gdscript
var _ok_btn:        Button        = null
var _mon_ini_lbl:   Label         = null
var _hero_ini_lbl:  Label         = null
```

- [ ] **Step 2: Add monster initiative label in `_build_ui()`**

In `_build_ui()`, find where `_mon_name` is created and added to `mon_info`:
```gdscript
_mon_name = Label.new()
_mon_name.add_theme_font_size_override("font_size", 18)
_mon_name.add_theme_color_override("font_color", Color(1.0, 0.55, 0.40))
mon_info.add_child(_mon_name)
```

After `mon_info.add_child(_mon_name)`, add:
```gdscript
_mon_ini_lbl = Label.new()
_mon_ini_lbl.add_theme_font_size_override("font_size", 12)
_mon_ini_lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.30))
_mon_ini_lbl.text = ""
mon_info.add_child(_mon_ini_lbl)
```

- [ ] **Step 3: Add hero initiative label in `_build_ui()`**

In `_build_ui()`, find the hero_row section. After the MP column is added (after the second `_build_hero_bar_col` call), add a small VBox column for initiative:
```gdscript
_build_hero_bar_col(hero_row, "MP", Color(0.25, 0.55, 0.95),
        func() -> ProgressBar: return _hero_mp_bar,
        func() -> Label:       return _hero_mp_lbl,
        func(b: ProgressBar) -> void: _hero_mp_bar = b,
        func(l: Label)       -> void: _hero_mp_lbl = l)

# Initiative column
var ini_col := VBoxContainer.new()
ini_col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
ini_col.add_theme_constant_override("separation", 3)
hero_row.add_child(ini_col)

var ini_tag := Label.new()
ini_tag.text = "INI"
ini_tag.add_theme_font_size_override("font_size", 12)
ini_tag.add_theme_color_override("font_color", Color(0.60, 0.60, 0.72))
ini_col.add_child(ini_tag)

_hero_ini_lbl = Label.new()
_hero_ini_lbl.add_theme_font_size_override("font_size", 14)
_hero_ini_lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.30))
_hero_ini_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
_hero_ini_lbl.custom_minimum_size  = Vector2(32, 0)
_hero_ini_lbl.text = ""
ini_col.add_child(_hero_ini_lbl)
```

- [ ] **Step 4: Set label values in `open()`**

In `open()`, after computing `hero_ini` and `mon_ini` (just before the `if _hero_goes_first` block), set the labels:
```gdscript
var hero_ini := mini(hero.initiative, 10)
var mon_ini  := monster.initiative

_mon_ini_lbl.text  = "⚡ %d" % mon_ini
_hero_ini_lbl.text = "⚡ %d" % hero_ini
```

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/battle_dialog.gd
git commit -m "feat: show initiative (⚡) labels for hero and monster in BattleDialog"
```

**Verify:** Start a fight. Next to the monster name you should see "⚡ N" (e.g. "⚡ 7" for a Wolf). In the hero stats section there should be an INI column showing "⚡ 5" (or higher if QUICK perk was taken). Values match the initiative table in the spec.

---

## Self-Review Checklist (for executor)

After all tasks are done, verify:

- [ ] Hero stats screen (`CharacterUI`) shows QUICK perk once taken — it iterates all `PerkDef.ID`, so it appears automatically.
- [ ] QUICK perk caps initiative at 10 — confirmed in `PerkPickUI._apply_pick()` via `mini(10, ...)`.
- [ ] Old saves load without error — `HeroStats.from_dict` defaults initiative to 5; MonsterNode defaults to initiative=5, actions=1.
- [ ] Multi-action monsters (Thorn dragon, Shark, Polar bear, bosses) attack multiple times before hero can act.
- [ ] Defending reduces only the first monster hit in a multi-attack sequence (`_defend_bonus` resets to false after first iteration).
- [ ] Fleeing successfully does NOT trigger `_after_hero_action()`.
- [ ] Belt strip is hidden/disabled when it is not the hero's turn (guard: `_btn_attack.visible`).
- [ ] Using a belt item reduces the count and dims the slot if empty.
