# Combat Perks & Level-Up Pick System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 8 leveled combat perks and a 3-card level-up selection UI so players choose a perk (new or upgrade) on every level gain.

**Architecture:** Stat perks (Strong/Tough/Wise/Armored/Spell Focus) are baked directly into HeroStats on pick, matching the existing `_do_level_up()` pattern. Active perks (Vampiric, Berserker) are queried from CharacterPerks at battle-time. A new PerkPickUI CanvasLayer intercepts every level-up, keeps the game paused until the player picks, then emits a signal so main.gd can save and continue.

**Tech Stack:** Godot 4, GDScript — no external dependencies.

---

## File Map

| File | Change |
|---|---|
| `scripts/data/perk_def.gd` | Add 8 new IDs + 5 helper functions |
| `scripts/ui/perk_pick_ui.gd` | **New** — level-up card selection dialog |
| `scripts/ui/battle_dialog.gd` | Accept `CharacterPerks`; add Berserker + Vampiric logic |
| `scripts/main.gd` | Create PerkPickUI; pass perks to BattleDialog; update level-up handler |

---

### Task 1: Extend PerkDef

**Files:**
- Modify: `scripts/data/perk_def.gd`

- [ ] **Step 1: Replace the `enum ID` block**

In `scripts/data/perk_def.gd`, replace the entire `enum ID { ... }` block with:

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
}
```

- [ ] **Step 2: Replace `get_perk_name`**

```gdscript
static func get_perk_name(perk: ID) -> String:
    match perk:
        ID.TRADER:           return "Trader"
        ID.SWIFT_WALKER:     return "Swift Walker"
        ID.STRONG:           return "Strong"
        ID.TOUGH:            return "Tough"
        ID.WISE:             return "Wise"
        ID.ARMORED:          return "Armored"
        ID.SPELL_FOCUS:      return "Spell Focus"
        ID.VAMPIRIC:         return "Vampiric"
        ID.EFFICIENT_CASTER: return "Efficient Caster"
        ID.BERSERKER:        return "Berserker"
    return "Unknown"
```

- [ ] **Step 3: Replace `get_max_level`**

```gdscript
static func get_max_level(perk: ID) -> int:
    match perk:
        ID.TRADER:       return 4
        ID.SWIFT_WALKER: return 3
        ID.STRONG, ID.TOUGH, ID.WISE, ID.ARMORED, \
        ID.SPELL_FOCUS, ID.VAMPIRIC, \
        ID.EFFICIENT_CASTER, ID.BERSERKER: return 3
    return 0
```

- [ ] **Step 4: Replace `get_level_name`**

```gdscript
static func get_level_name(perk: ID, level: int) -> String:
    if level <= 0:
        return ""
    match perk:
        ID.TRADER:
            match level:
                1: return "Apprentice Trader"
                2: return "Journeyman Trader"
                3: return "Expert Trader"
                4: return "Master Trader"
        ID.SWIFT_WALKER:
            match level:
                1: return "Wayfarer"
                2: return "Strider"
                3: return "Windwalker"
        ID.STRONG:
            match level:
                1: return "Strengthened"
                2: return "Mighty"
                3: return "Titan"
        ID.TOUGH:
            match level:
                1: return "Hardy"
                2: return "Stalwart"
                3: return "Ironhide"
        ID.WISE:
            match level:
                1: return "Focused"
                2: return "Enlightened"
                3: return "Sage"
        ID.ARMORED:
            match level:
                1: return "Plated"
                2: return "Fortified"
                3: return "Bulwark"
        ID.SPELL_FOCUS:
            match level:
                1: return "Attuned"
                2: return "Channeler"
                3: return "Arcane Mastery"
        ID.VAMPIRIC:
            match level:
                1: return "Blood Drinker"
                2: return "Lifesteal"
                3: return "Soul Drain"
        ID.EFFICIENT_CASTER:
            match level:
                1: return "Conserving"
                2: return "Efficient"
                3: return "Arcane Efficiency"
        ID.BERSERKER:
            match level:
                1: return "Hot-Blooded"
                2: return "Frenzy"
                3: return "Berserker"
    return ""
```

- [ ] **Step 5: Add `get_stat_delta`**

Append after the existing `trader_buy_factor` function:

```gdscript
## Stat delta applied to HeroStats when picking one level of a stat perk.
## Runtime perks (Vampiric, Berserker, Efficient Caster) return {}.
static func get_stat_delta(perk: ID) -> Dictionary:
    match perk:
        ID.STRONG:      return {"attack":   1}
        ID.TOUGH:       return {"max_hp":   5}
        ID.WISE:        return {"max_mana": 3}
        ID.ARMORED:     return {"defense":  1}
        ID.SPELL_FOCUS: return {"magic":    1}
    return {}
```

- [ ] **Step 6: Add `get_vampiric_heal`, `get_berserker_bonus`, `perk_description`**

Append after `get_stat_delta`:

```gdscript
## HP healed after killing a monster (Vampiric perk).
static func get_vampiric_heal(level: int) -> int:
    return level  # 1 / 2 / 3


## Flat attack bonus when hero HP is below 30% (Berserker perk).
static func get_berserker_bonus(level: int) -> int:
    return level * 3  # 3 / 6 / 9


## Description of what the given NEW level of a perk grants.
## Used in the level-up card UI.
static func perk_description(perk: ID, new_level: int) -> String:
    match perk:
        ID.STRONG:           return "+1 Attack"
        ID.TOUGH:            return "+5 Max HP"
        ID.WISE:             return "+3 Max Mana"
        ID.ARMORED:          return "+1 Defense"
        ID.SPELL_FOCUS:      return "+1 Magic"
        ID.VAMPIRIC:         return "Heal %d HP after killing a monster" % new_level
        ID.EFFICIENT_CASTER: return "Spells cost %d less mana (min 1)" % new_level
        ID.BERSERKER:        return "+%d Attack when below 30%% HP" % (new_level * 3)
    return ""
```

- [ ] **Step 7: Commit**

```bash
git add scripts/data/perk_def.gd
git commit -m "feat: add 8 combat perks to PerkDef with level helpers"
```

---

### Task 2: Create PerkPickUI

**Files:**
- Create: `scripts/ui/perk_pick_ui.gd`

- [ ] **Step 1: Create the file with full content**

Create `scripts/ui/perk_pick_ui.gd`:

```gdscript
class_name PerkPickUI
extends CanvasLayer

signal perk_picked

var _stats:      HeroStats      = null
var _perks:      CharacterPerks = null
var _choices:    Array          = []   # Array[PerkDef.ID]

var _overlay:    Control       = null
var _header_lbl: Label         = null
var _cards_hbox: HBoxContainer = null


func _ready() -> void:
    layer        = 80
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_ui()


func open(stats: HeroStats, perks: CharacterPerks) -> void:
    _stats = stats
    _perks = perks

    var pool: Array = []
    for key in PerkDef.ID:
        var id: PerkDef.ID = PerkDef.ID[key]
        if perks.get_level(id) < PerkDef.get_max_level(id):
            pool.append(id)
    pool.shuffle()
    _choices = pool.slice(0, mini(3, pool.size()))

    if _choices.is_empty():
        perk_picked.emit()
        return

    _header_lbl.text = "LEVEL UP!  —  Choose a Perk"
    _build_cards()
    _overlay.visible  = true
    get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
    if not _overlay.visible:
        return
    if not (event is InputEventKey):
        return
    var ke := event as InputEventKey
    if ke.echo or not ke.pressed:
        return
    var idx := -1
    match ke.keycode:
        KEY_1: idx = 0
        KEY_2: idx = 1
        KEY_3: idx = 2
    if idx >= 0 and idx < _choices.size():
        _apply_pick(_choices[idx])
        get_viewport().set_input_as_handled()


func _apply_pick(perk_id: PerkDef.ID) -> void:
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
    _stats.changed.emit()

    _overlay.visible  = false
    get_tree().paused = false
    perk_picked.emit()


func _build_cards() -> void:
    for c in _cards_hbox.get_children():
        c.queue_free()
    for i in range(_choices.size()):
        var perk_id: PerkDef.ID = _choices[i]
        var cur_lv  := _perks.get_level(perk_id)
        _cards_hbox.add_child(_make_card(perk_id, cur_lv, cur_lv + 1, i + 1))
    if _cards_hbox.get_child_count() > 0:
        (_cards_hbox.get_child(0) as Button).grab_focus()


func _build_ui() -> void:
    _overlay = Control.new()
    _overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _overlay.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(_overlay)

    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.65)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.process_mode = Node.PROCESS_MODE_ALWAYS
    _overlay.add_child(dim)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.process_mode = Node.PROCESS_MODE_ALWAYS
    _overlay.add_child(center)

    var panel := _make_panel()
    center.add_child(panel)

    var vbox := VBoxContainer.new()
    vbox.custom_minimum_size = Vector2(520, 0)
    vbox.add_theme_constant_override("separation", 14)
    panel.add_child(vbox)

    _header_lbl = Label.new()
    _header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _header_lbl.add_theme_font_size_override("font_size", 22)
    _header_lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.30))
    vbox.add_child(_header_lbl)

    vbox.add_child(_hsep())

    _cards_hbox = HBoxContainer.new()
    _cards_hbox.add_theme_constant_override("h_separation", 14)
    _cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_child(_cards_hbox)

    var key_hint := Label.new()
    key_hint.text = "1 / 2 / 3  —  select"
    key_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    key_hint.add_theme_font_size_override("font_size", 11)
    key_hint.add_theme_color_override("font_color", Color(0.42, 0.42, 0.52))
    vbox.add_child(key_hint)

    _overlay.visible = false


func _make_card(perk_id: PerkDef.ID, cur_lv: int, new_lv: int, key_num: int) -> Button:
    var btn := Button.new()
    btn.custom_minimum_size = Vector2(148, 170)
    btn.process_mode = Node.PROCESS_MODE_ALWAYS

    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.08, 0.08, 0.14, 0.95)
    normal.border_color = Color(0.50, 0.42, 0.22, 0.85)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(8)
    normal.set_content_margin_all(12)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color     = Color(0.14, 0.14, 0.22, 0.95)
    hover.border_color = Color(0.92, 0.78, 0.30)
    btn.add_theme_stylebox_override("normal",  normal)
    btn.add_theme_stylebox_override("hover",   hover)
    btn.add_theme_stylebox_override("focus",   hover)
    btn.add_theme_stylebox_override("pressed", hover)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 6)
    vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    btn.add_child(vbox)

    var key_lbl := Label.new()
    key_lbl.text = "[%d]" % key_num
    key_lbl.add_theme_font_size_override("font_size", 11)
    key_lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.60))
    key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.add_child(key_lbl)

    var name_lbl := Label.new()
    name_lbl.text = PerkDef.get_perk_name(perk_id)
    name_lbl.add_theme_font_size_override("font_size", 17)
    name_lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.30))
    name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
    name_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
    vbox.add_child(name_lbl)

    var lvl_lbl := Label.new()
    if cur_lv == 0:
        lvl_lbl.text = "NEW"
        lvl_lbl.add_theme_color_override("font_color", Color(0.40, 0.90, 0.50))
    else:
        lvl_lbl.text = "Lv %d → %d" % [cur_lv, new_lv]
        lvl_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.95))
    lvl_lbl.add_theme_font_size_override("font_size", 13)
    lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.add_child(lvl_lbl)

    var sep := HSeparator.new()
    sep.add_theme_color_override("color", Color(0.30, 0.28, 0.42, 0.55))
    sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.add_child(sep)

    var desc_lbl := Label.new()
    desc_lbl.text = PerkDef.perk_description(perk_id, new_lv)
    desc_lbl.add_theme_font_size_override("font_size", 13)
    desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.90))
    desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
    desc_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
    vbox.add_child(desc_lbl)

    var id_captured := perk_id
    btn.pressed.connect(func() -> void: _apply_pick(id_captured))

    return btn


static func _make_panel() -> PanelContainer:
    var p := PanelContainer.new()
    var s := StyleBoxFlat.new()
    s.bg_color     = Color(0.06, 0.06, 0.11, 0.97)
    s.border_color = Color(0.50, 0.35, 0.20, 0.90)
    s.set_border_width_all(2)
    s.set_corner_radius_all(10)
    s.set_content_margin_all(20)
    p.add_theme_stylebox_override("panel", s)
    return p


static func _hsep() -> HSeparator:
    var s := HSeparator.new()
    s.add_theme_color_override("color", Color(0.30, 0.28, 0.42, 0.55))
    return s
```

- [ ] **Step 2: Verify the file parses cleanly**

Open the Godot editor. In the FileSystem panel, confirm `scripts/ui/perk_pick_ui.gd` shows no red error icon. Click it and check the Script editor shows no parse errors at the bottom.

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/perk_pick_ui.gd
git commit -m "feat: PerkPickUI — level-up perk selection dialog"
```

---

### Task 3: Update BattleDialog

**Files:**
- Modify: `scripts/ui/battle_dialog.gd`

- [ ] **Step 1: Add `_perks` field**

In `battle_dialog.gd`, add after `var _defend_bonus: bool = false`:

```gdscript
var _perks: CharacterPerks = null
```

- [ ] **Step 2: Update `open()` signature**

Replace:

```gdscript
func open(monster: MonsterNode, hero: HeroStats) -> void:
    _hero          = hero
    _monster       = monster
    _defend_bonus  = false
    _state         = _State.CHOOSING
```

With:

```gdscript
func open(monster: MonsterNode, hero: HeroStats, perks: CharacterPerks) -> void:
    _hero          = hero
    _monster       = monster
    _perks         = perks
    _defend_bonus  = false
    _state         = _State.CHOOSING
```

- [ ] **Step 3: Add Berserker logic to `_on_attack`**

Replace the entire `_on_attack` function:

```gdscript
func _on_attack() -> void:
    _set_action_ui(false)
    _defend_bonus = false
    var eff_atk := _hero.attack
    if _perks != null:
        var berk_lv := _perks.get_level(PerkDef.ID.BERSERKER)
        if berk_lv > 0 and float(_hero.current_hp) / float(_hero.max_hp) < 0.30:
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
    _monster_turn()
```

- [ ] **Step 4: Add Vampiric heal to `_finish`**

Replace the `_State.WIN` arm inside `_finish`:

```gdscript
        _State.WIN:
            if _perks != null:
                var vamp_lv := _perks.get_level(PerkDef.ID.VAMPIRIC)
                if vamp_lv > 0:
                    var heal := PerkDef.get_vampiric_heal(vamp_lv)
                    _hero.heal(heal)
                    _add_log("You drain %d HP." % heal)
            _result_lbl.text = "Victory!  +%d XP" % _monster.xp_reward
            _result_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.4))
```

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/battle_dialog.gd
git commit -m "feat: Berserker and Vampiric perk effects in BattleDialog"
```

---

### Task 4: Wire everything in main.gd

**Files:**
- Modify: `scripts/main.gd`

- [ ] **Step 1: Declare `_perk_pick_ui`**

In `main.gd`, add to the var block at the top (after `_monster_book`):

```gdscript
var _perk_pick_ui: PerkPickUI = null
```

- [ ] **Step 2: Create and register PerkPickUI**

In `_ready()`, after `add_child(_monster_book)`, add:

```gdscript
_perk_pick_ui = PerkPickUI.new()
add_child(_perk_pick_ui)
_perk_pick_ui.perk_picked.connect(_on_perk_picked)
```

- [ ] **Step 3: Pass perks to BattleDialog**

Find:

```gdscript
_avatar.monster_fight_requested.connect(
    func(m: MonsterNode) -> void:
        _battle_dialog.open(m, _avatar.stats)
)
```

Replace with:

```gdscript
_avatar.monster_fight_requested.connect(
    func(m: MonsterNode) -> void:
        _battle_dialog.open(m, _avatar.stats, _avatar.perks)
)
```

- [ ] **Step 4: Replace level-up hint with PerkPickUI**

Find:

```gdscript
_battle_dialog.battle_won.connect(func(m: MonsterNode) -> void:
    var leveled := _avatar.stats.add_xp(m.xp_reward)
    if leveled:
        _pickup_hint.show_message("Level up!  You are now level %d!" % _avatar.stats.level)
    m.queue_free()
    SaveManager.save_stats(_avatar.stats)
)
```

Replace with:

```gdscript
_battle_dialog.battle_won.connect(func(m: MonsterNode) -> void:
    var leveled := _avatar.stats.add_xp(m.xp_reward)
    m.queue_free()
    if leveled:
        _perk_pick_ui.open(_avatar.stats, _avatar.perks)
    else:
        SaveManager.save_stats(_avatar.stats)
)
```

- [ ] **Step 5: Add `_on_perk_picked` handler**

Append at the bottom of `main.gd`:

```gdscript
func _on_perk_picked() -> void:
    SaveManager.save_stats(_avatar.stats)
    SaveManager.save_perks(_avatar.perks)
```

- [ ] **Step 6: Commit**

```bash
git add scripts/main.gd
git commit -m "feat: wire PerkPickUI into level-up flow and battle dialog"
```

---

### Task 5: Manual Verification

- [ ] **Step 1: Set XP near level threshold via console**

Run the game (F5). Open the in-game console and run:

```
xp 18
```

(Level 1 needs 20 XP to advance, so 18 puts you 2 XP away from level 2.)

- [ ] **Step 2: Trigger a level-up**

Walk up to any monster and press F. Win the battle (attack until monster dies). The battle should give at least 2 XP.

**Expected:** After the OK button on the battle victory, PerkPickUI appears with 3 perk cards. The old "Level up!" text hint does NOT appear.

- [ ] **Step 3: Pick a stat perk and verify stat change**

Click the "Strong" card (or press 1/2/3 depending on its position). Then press C to open the Character screen.

**Expected:** Attack stat is one higher than it was before the fight (base 6 → 7 if Strong was the first stat perk picked).

- [ ] **Step 4: Verify perk appears in Character UI**

In the Character screen, check the "Active Perks" section.

**Expected:** "⚖  Strengthened" (level-name for STRONG level 1) appears.

- [ ] **Step 5: Test keyboard selection**

Level up again (console: `xp 38` to force level 2 → 3 threshold). When PerkPickUI appears, press 2 then 3 to check focus highlight moves, then press 1 to select.

**Expected:** Pressing 1/2/3 selects the corresponding card and closes the UI.

- [ ] **Step 6: Test Berserker**

Gain the Berserker perk via a level-up. Then start a fight. Use console `hp 5` (max HP 30 → 16.7%, below 30%) before starting combat.

**Expected:** When you attack, the combat log shows "Berserker rage!  +3 attack." and the damage dealt is higher than normal.

- [ ] **Step 7: Test Vampiric**

Gain the Vampiric perk via a level-up. Take some damage in a fight (use Defend a couple of turns). Then kill the monster.

**Expected:** Combat log shows "You drain 1 HP." and the HP bar ticks up by 1 before the Victory result appears.

- [ ] **Step 8: Test upgrade path**

Level up to a point where you already have one perk at level 1. Level up again.

**Expected:** The perk you already have appears as "Lv 1 → 2" in the card pool alongside "NEW" perks. Picking it updates the perk in CharacterUI to the level-2 name (e.g., "Mighty" for STRONG level 2).

- [ ] **Step 9: Verify saves persist across restart**

Pick a perk, then quit the game and relaunch. Open the Character screen.

**Expected:** The perk is still shown under Active Perks and the boosted stat (e.g., Attack) is still at the increased value.
