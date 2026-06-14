# Game Calendar & Time Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent in-game clock (1 game day = 20 real minutes) with a fantasy calendar, a HUD widget in the top-right corner, NPC birth timestamps, and full save/load support.

**Architecture:** `GameClock` is a project-level autoload singleton that owns `_game_time: float` and ticks it in `_process`. `ClockUI` is a `CanvasLayer` that connects to `GameClock.time_changed` and renders two labels top-right. `NpcMelee` stores `birth_time: float` set at spawn; `SaveManager` handles persistence of the clock to `user://clock.json`.

**Tech Stack:** Godot 4, GDScript, existing `SaveManager` / `PauseMenu` / `NpcManager` patterns.

---

## File Map

| File | Action |
|---|---|
| `scripts/world/game_clock.gd` | **Create** — autoload singleton; owns time state, calendar math, `time_changed` signal |
| `project.godot` | **Modify** — register `GameClock` autoload |
| `scripts/ui/clock_ui.gd` | **Create** — CanvasLayer HUD widget; reads from `GameClock` autoload |
| `scripts/main.gd` | **Modify** — instantiate `ClockUI`; call `GameClock.load_time()` on game load |
| `scripts/actors/npc_melee.gd` | **Modify** — add `birth_time: float`; persist in `to_dict` / `restore_from_dict` |
| `scripts/world/npc_manager.gd` | **Modify** — assign `npc.birth_time = GameClock.get_game_time()` at melee NPC creation |
| `scripts/utils/save_manager.gd` | **Modify** — add `CLOCK_FILE`, `save_clock`, `load_clock`; add to `wipe()` |
| `scripts/ui/pause_menu.gd` | **Modify** — call `SaveManager.save_clock` in `_save_all()` |

---

### Task 1: GameClock autoload

**Files:**
- Create: `scripts/world/game_clock.gd`
- Modify: `project.godot` (lines 24–26)

- [ ] **Step 1: Create `scripts/world/game_clock.gd`**

```gdscript
class_name GameClock
extends Node

## 1 game day = 20 real minutes → 86400 game-sec ÷ 1200 real-sec = 72×
const SECS_PER_REAL_SEC := 86400.0 / 1200.0
const DEFAULT_START_TIME := 6.0 * 3600.0   # 6:00 AM, day 1

const DAY_NAMES: Array[String] = [
	"Sunmorn", "Moonday", "Ashday", "Ironday", "Stormday", "Goldday", "Restday"
]
const MONTH_NAMES: Array[String] = [
	"Seedmoon", "Bloomtide", "Greenmere",
	"Sunpeak", "Hearthmonth", "Goldveil",
	"Harvestmoon", "Embertide", "Ashfall",
	"Frostmoon", "Deepwinter", "Coldend"
]

signal time_changed

var _game_time:   float = DEFAULT_START_TIME
var _last_minute: int   = -1


func _process(delta: float) -> void:
	_game_time += delta * SECS_PER_REAL_SEC
	var current_minute := int(_game_time / 60)
	if current_minute != _last_minute:
		_last_minute = current_minute
		time_changed.emit()


func get_game_time() -> float:
	return _game_time


func load_time(s: float) -> void:
	_game_time   = s
	_last_minute = int(_game_time / 60)


func get_date_time() -> Dictionary:
	return from_seconds(_game_time)


func from_seconds(s: float) -> Dictionary:
	var total_minutes := int(s / 60)
	var minute        := total_minutes % 60
	var total_hours   := int(s / 3600)
	var hour_24       := total_hours % 24
	var am_pm         := "AM" if hour_24 < 12 else "PM"
	var hour12        := hour_24 % 12
	if hour12 == 0:
		hour12 = 12
	var total_days  := int(s / 86400)
	var weekday_idx := total_days % 7
	var day         := total_days % 30 + 1
	var month_idx   := (total_days / 30) % 12
	var year        := total_days / 360 + 1
	return {
		"year":         year,
		"month_idx":    month_idx,
		"month_name":   MONTH_NAMES[month_idx],
		"day":          day,
		"weekday_idx":  weekday_idx,
		"weekday_name": DAY_NAMES[weekday_idx],
		"hour12":       hour12,
		"minute":       minute,
		"am_pm":        am_pm,
	}
```

- [ ] **Step 2: Register `GameClock` as autoload in `project.godot`**

Find the `[autoload]` section (currently around line 24) and add one line:

```ini
[autoload]

TileRegistry="*res://scripts/editor/tile_registry.gd"
GameClock="*res://scripts/world/game_clock.gd"
```

- [ ] **Step 3: Verify in Godot editor**

Open the project in the Godot editor. In **Project → Project Settings → Autoloads** confirm `GameClock` appears with path `res://scripts/world/game_clock.gd`. Run the game; there should be no script errors in the Output panel related to `GameClock`.

- [ ] **Step 4: Commit**

```
git add scripts/world/game_clock.gd project.godot
git commit -m "feat: add GameClock autoload — 72× real-time fantasy calendar"
```

---

### Task 2: ClockUI HUD widget

**Files:**
- Create: `scripts/ui/clock_ui.gd`
- Modify: `scripts/main.gd`

- [ ] **Step 1: Create `scripts/ui/clock_ui.gd`**

```gdscript
class_name ClockUI
extends CanvasLayer

var _date_label: Label = null
var _time_label: Label = null


func _ready() -> void:
	layer        = 20
	process_mode = Node.PROCESS_MODE_ALWAYS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.82)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	style.border_color = Color(0.35, 0.35, 0.45, 0.8)
	for c in range(4):
		style.set_corner_radius(c, 5)
	style.set_content_margin_all(8)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left   = -224
	panel.offset_top    =    8
	panel.offset_right  =   -8
	panel.offset_bottom =   72
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	_date_label = Label.new()
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date_label.add_theme_font_size_override("font_size", 13)
	_date_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(_date_label)

	_time_label = Label.new()
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 16)
	_time_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	vbox.add_child(_time_label)

	GameClock.time_changed.connect(_on_time_changed)
	_on_time_changed()


func _on_time_changed() -> void:
	var dt := GameClock.get_date_time()
	_date_label.text = "%s, %d%s %s, Yr %d" % [
		dt["weekday_name"],
		dt["day"],
		_ordinal_suffix(dt["day"]),
		dt["month_name"],
		dt["year"],
	]
	_time_label.text = "%d:%02d %s" % [dt["hour12"], dt["minute"], dt["am_pm"]]


static func _ordinal_suffix(n: int) -> String:
	if n == 11 or n == 12 or n == 13:
		return "th"
	match n % 10:
		1: return "st"
		2: return "nd"
		3: return "rd"
	return "th"
```

- [ ] **Step 2: Add `ClockUI` to `scripts/main.gd`**

Add the instance variable after the existing UI vars (around line 21):
```gdscript
var _clock_ui: ClockUI = null
```

In `_ready()`, after the line `add_child(_shop_ui)` (around line 44), add:
```gdscript
_clock_ui = ClockUI.new()
add_child(_clock_ui)
```

- [ ] **Step 3: Verify in Godot**

Run the game. A dark panel should appear in the **top-right corner** showing two lines:
- `Sunmorn, 1st Seedmoon, Yr 1`
- `6:00 AM`

Wait ~20 real seconds; the time label should advance by ~24 game minutes. Confirm no errors in Output.

- [ ] **Step 4: Commit**

```
git add scripts/ui/clock_ui.gd scripts/main.gd
git commit -m "feat: add ClockUI HUD widget — top-right date/time display"
```

---

### Task 3: NPC birth timestamp

**Files:**
- Modify: `scripts/actors/npc_melee.gd`
- Modify: `scripts/world/npc_manager.gd`

- [ ] **Step 1: Add `birth_time` to `NpcMelee`**

In `scripts/actors/npc_melee.gd`, add the field after `var npc_name: String = ""` (around line 23):
```gdscript
var birth_time: float = 0.0
```

In `to_dict()`, add the new key inside the returned Dictionary (after `"npc_name": npc_name`):
```gdscript
func to_dict() -> Dictionary:
	return {
		"type":           "melee",
		"npc_id":         npc_id,
		"x":              position.x,
		"y":              position.y,
		"heading":        heading,
		"is_quest_giver": is_quest_giver,
		"npc_name":       npc_name,
		"birth_time":     birth_time,
	}
```

In `restore_from_dict()`, add after the `npc_name` line:
```gdscript
birth_time = float(data.get("birth_time", 0.0))
```

- [ ] **Step 2: Assign `birth_time` at NPC creation in `NpcManager`**

In `scripts/world/npc_manager.gd`, in `_on_chunk_loaded()`, find the melee NPC creation block (around line 67). After `npc.position = spawn` and before `_world.add_child(npc)`, add:
```gdscript
npc.birth_time = GameClock.get_game_time()
```

The block should now read:
```gdscript
var npc      := NpcMelee.new()
npc.npc_id    = "melee_%03d" % _next_melee_id
_next_melee_id += 1
npc.position  = spawn
npc.birth_time = GameClock.get_game_time()
_world.add_child(npc)
if randf() < QUEST_GIVER_CHANCE:
    npc.make_quest_giver(NpcMelee.NAMES[randi() % NpcMelee.NAMES.size()])
_melee_spawned[coord] = true
```

Note: NPCs restored from save via `restore_from_dict()` use their stored `birth_time` — no assignment needed there.

- [ ] **Step 3: Verify in Godot**

Run the game. In the Godot editor **Remote** tab (or add a temporary `print`), confirm a freshly spawned `NpcMelee` has a non-zero `birth_time`. Call `GameClock.from_seconds(npc.birth_time)` and print the result to confirm it returns a valid date dict. Remove any debug prints.

- [ ] **Step 4: Commit**

```
git add scripts/actors/npc_melee.gd scripts/world/npc_manager.gd
git commit -m "feat: NpcMelee stores birth_time (game seconds) at spawn"
```

---

### Task 4: Save / load clock state

**Files:**
- Modify: `scripts/utils/save_manager.gd`
- Modify: `scripts/ui/pause_menu.gd`
- Modify: `scripts/main.gd`

- [ ] **Step 1: Add `CLOCK_FILE`, `save_clock`, `load_clock` to `SaveManager`**

In `scripts/utils/save_manager.gd`, add the constant after `SHOPS_FILE` (around line 12):
```gdscript
const CLOCK_FILE     := "user://clock.json"
```

Add `CLOCK_FILE` to the `wipe()` path list:
```gdscript
for path in [PLAYER_FILE, INVENTORY_FILE, NPCS_FILE, DIALOG_FILE, SHOPS_FILE, CLOCK_FILE]:
```

Add the two new methods before `save_npcs` (or at the end of the file):
```gdscript
static func save_clock(time: float) -> void:
	var file := FileAccess.open(CLOCK_FILE, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write clock save (error %d)" \
				% FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({"time": time}))
	file.close()


static func load_clock() -> float:
	if not FileAccess.file_exists(CLOCK_FILE):
		return 21600.0   # default: 6:00 AM day 1
	var file := FileAccess.open(CLOCK_FILE, FileAccess.READ)
	if file == null:
		return 21600.0
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary and (parsed as Dictionary).has("time"):
		return float((parsed as Dictionary)["time"])
	return 21600.0
```

- [ ] **Step 2: Hook save into `PauseMenu._save_all()`**

In `scripts/ui/pause_menu.gd`, at the end of `_save_all()`, after the `save_shop_states` line:
```gdscript
SaveManager.save_clock(GameClock.get_game_time())
```

- [ ] **Step 3: Hook load into `main._ready()`**

In `scripts/main.gd`, after `ShopUI.set_shop_states(SaveManager.load_shop_states())`:
```gdscript
GameClock.load_time(SaveManager.load_clock())
```

- [ ] **Step 4: Verify save/load round-trip**

Run the game. Let it run for ~1 real minute (≈ 72 game minutes). Open the pause menu and **Save**. Quit the game. Relaunch. Confirm the ClockUI widget shows the time from where you left off — not 6:00 AM day 1.

Also verify **New Game / Wipe**: wipe the save (game's wipe functionality), reload — ClockUI should show 6:00 AM Sunmorn, 1st Seedmoon, Year 1.

- [ ] **Step 5: Commit**

```
git add scripts/utils/save_manager.gd scripts/ui/pause_menu.gd scripts/main.gd
git commit -m "feat: persist game clock to disk — save/load clock.json"
```
