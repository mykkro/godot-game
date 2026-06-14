# Game Calendar & Time Design
**Date:** 2026-06-14

## Overview

A persistent in-game clock that runs at 72× real time (1 game day = 20 real minutes). A fantasy calendar with named months and weekdays drives a HUD widget in the top-right corner. Each `NpcMelee` records its creation timestamp for future use.

---

## Architecture

### New / changed files

| File | Change |
|---|---|
| `scripts/world/game_clock.gd` | New — autoload singleton; owns time state, calendar math, signals |
| `scripts/ui/clock_ui.gd` | New — CanvasLayer HUD widget; reads from GameClock |
| `scripts/actors/npc_melee.gd` | Add `birth_time: float`; persist in `to_dict` / `restore_from_dict` |
| `scripts/world/npc_manager.gd` | Assign `birth_time` at NPC creation |
| `scripts/utils/save_manager.gd` | Add `CLOCK_FILE`, `save_clock`, `load_clock`; add to `wipe()` |
| `scripts/ui/pause_menu.gd` | Call `SaveManager.save_clock` in `_save_all()` |
| `scripts/main.gd` | Instantiate `ClockUI`; call `GameClock.load_time` on load |
| `project.godot` | Register `GameClock` as autoload |

---

## GameClock Autoload

**Path:** `scripts/world/game_clock.gd`  
**Autoload name:** `GameClock`  
**Process mode:** default (pauses with the game tree — time freezes during shops, dialogs, etc.)

### Rate

```
SECS_PER_REAL_SEC := 86400.0 / 1200.0   # = 72.0
```

Every `_process(delta)`: `_game_time += delta * SECS_PER_REAL_SEC`

### Starting time

New games begin at **6:00 AM on Sunmorn, 1st Seedmoon, Year 1**:

```
DEFAULT_START_TIME := 6 * 3600.0   # = 21600.0
```

### Signal

```gdscript
signal time_changed   # emitted once per in-game minute
```

Tracked by comparing `int(_game_time / 60)` to `_last_minute: int` each frame.

### Public API

```gdscript
func get_game_time() -> float                  # raw seconds — use for NPC birth_time
func get_date_time() -> Dictionary             # current time as readable dict
func from_seconds(s: float) -> Dictionary      # convert any stored seconds to dict
func load_time(s: float) -> void               # called once on game load
```

### `get_date_time()` / `from_seconds()` return value

```gdscript
{
    "year":         int,    # 1-indexed
    "month_idx":    int,    # 0–11
    "month_name":   String, # e.g. "Seedmoon"
    "day":          int,    # 1–30
    "weekday_idx":  int,    # 0–6
    "weekday_name": String, # e.g. "Sunmorn"
    "hour12":       int,    # 1–12
    "minute":       int,    # 0–59
    "am_pm":        String, # "AM" or "PM"
}
```

### Calendar math (from raw seconds `s`)

```
total_minutes  = int(s / 60)
minute         = total_minutes % 60
total_hours    = int(s / 3600)
hour_24        = total_hours % 24
am_pm          = "AM" if hour_24 < 12 else "PM"
hour12         = hour_24 % 12  →  0 becomes 12
total_days     = int(s / 86400)           # 0-indexed
weekday_idx    = total_days % 7
day            = total_days % 30 + 1      # 1–30
month_idx      = (total_days / 30) % 12  # integer division
year           = total_days / 360 + 1    # integer division, 1-indexed
```

### Calendar constants

**Days of the week (index 0–6):**
Sunmorn · Moonday · Ashday · Ironday · Stormday · Goldday · Restday

**Months (index 0–11):**

| Season | Index | Name |
|--------|-------|------|
| Spring | 0 | Seedmoon |
| Spring | 1 | Bloomtide |
| Spring | 2 | Greenmere |
| Summer | 3 | Sunpeak |
| Summer | 4 | Hearthmonth |
| Summer | 5 | Goldveil |
| Autumn | 6 | Harvestmoon |
| Autumn | 7 | Embertide |
| Autumn | 8 | Ashfall |
| Winter | 9 | Frostmoon |
| Winter | 10 | Deepwinter |
| Winter | 11 | Coldend |

---

## ClockUI Widget

**Path:** `scripts/ui/clock_ui.gd`  
**Extends:** `CanvasLayer`, layer = 20 (HUD layer — above world, below all modal UIs)  
**Process mode:** `PROCESS_MODE_ALWAYS` (so the panel remains visible while game is paused)

### Layout

Anchored top-right, 8 px margin from screen edges. A dark semi-transparent `PanelContainer` (same `StyleBoxFlat` style as `NpcDialog`) with a `VBoxContainer` inside:

```
┌─────────────────────────────┐
│ Moonday, 15th Seedmoon, Yr 1│  ← 13 px, muted gold
│          6:00 AM            │  ← 16 px, bright white, centered
└─────────────────────────────┘
```

- Date line: `"{weekday_name}, {day}{suffix} {month_name}, Year {year}"` — 13 px font, color `Color(0.9, 0.85, 0.6)`
- Time line: `"{hour12}:{minute:02d} {am_pm}"` — 16 px font, color `Color(1, 1, 1)`, centered

**Ordinal suffix** helper (pure function):
- 1, 21 → "st" · 2, 22 → "nd" · 3, 23 → "rd" · 4–20, 24–30 → "th"

**Updates:** connects to `GameClock.time_changed` in `_ready()`. On signal: calls `GameClock.get_date_time()` and rewrites both labels. No per-frame update.

**Wired in `main.gd`:** `_clock_ui = ClockUI.new(); add_child(_clock_ui)` — no `setup()` call needed.

---

## NPC Birth Date

**Field:** `var birth_time: float = 0.0` on `NpcMelee` (raw game seconds).

**Set at creation:** `NpcManager` assigns `npc.birth_time = GameClock.get_game_time()` immediately after instantiating a new NPC. When restoring from a save dict, the stored value is loaded — `birth_time` is never reset on restore.

**Persistence:**
- `to_dict()` adds `"birth_time": birth_time`
- `restore_from_dict()` reads `float(data.get("birth_time", 0.0))`

**Readable any time:** `GameClock.from_seconds(npc.birth_time)` returns the full date/time dict.

---

## Save / Load

### SaveManager additions

```gdscript
const CLOCK_FILE := "user://clock.json"

static func save_clock(time: float) -> void   # writes {"time": time}
static func load_clock() -> float             # returns 21600.0 (6 AM day 1) if no file
```

`CLOCK_FILE` added to the path list in `wipe()`.

### Hooks

| Where | Call |
|---|---|
| `PauseMenu._save_all()` | `SaveManager.save_clock(GameClock.get_game_time())` |
| `main._ready()` (after other loads) | `GameClock.load_time(SaveManager.load_clock())` |

---

## Out of Scope

- Day/night visual cycle (sky colour, lighting changes)
- Time-gated events or shop opening hours
- Displaying birth date in NPC dialog
- Seasons affecting gameplay (weather, crops)
