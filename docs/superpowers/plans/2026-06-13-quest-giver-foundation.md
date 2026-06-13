# Quest Giver Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a floating yellow `!` marker above every `NpcMelee`, show discovered quest givers as yellow dots on the minimap, and add a stub "Quest" dialog option.

**Architecture:** Three self-contained edits to existing files — `npc_melee.gd` gains a bobbing sprite child, `minimap_ui.gd` overlays quest-giver dots in `_refresh()`, and `npc_dialog.gd` adds a fourth menu option for melee NPCs. No new files, no new save data.

**Tech Stack:** Godot 4.6 GDScript — no test framework; verification is done by running the game and observing behavior.

---

### Task 1: Floating `!` marker on NpcMelee

**Files:**
- Modify: `scripts/actors/npc_melee.gd`

- [ ] **Step 1: Add constants and variables**

Open `scripts/actors/npc_melee.gd`. Add these constants and vars directly below the existing ones:

```gdscript
class_name NpcMelee
extends StaticBody2D

## Idle melee character — stands in place permanently, occasionally turns.

const COLL_RADIUS    := 18.75
const DIR_CHANGE_MIN := 3.0
const DIR_CHANGE_MAX := 8.0
const MARK_BASE_Y    := -90.0
const BOB_AMP        := 3.0
const BOB_PERIOD     := 1.2

var npc_id:     String   = ""
var heading:    float    = 0.0
var _sprite:    MeleeSprite = null
var _dir_timer: float    = 0.0
var _mark:      Sprite2D = null
var _mark_bob:  float    = 0.0
```

- [ ] **Step 2: Create the marker sprite in `_ready()`**

In `_ready()`, add these lines at the end (after `_update_dir()`):

```gdscript
func _ready() -> void:
	# Occupy the actor layer so player and NPCs can't walk through.
	collision_layer = 1   # Actor.ACTOR_LAYER
	collision_mask  = 0

	var col    := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = COLL_RADIUS
	col.shape     = circle
	add_child(col)

	_sprite        = MeleeSprite.new()
	_sprite.scale  = Vector2(0.56, 0.56)
	_sprite.offset = Vector2(0.0, -36.6)
	add_child(_sprite)

	heading    = randf() * TAU
	_dir_timer = randf_range(DIR_CHANGE_MIN, DIR_CHANGE_MAX)
	_update_dir()

	_mark          = Sprite2D.new()
	_mark.texture  = load("res://media/cursors/Outline/Default/mark_exclamation.png")
	_mark.modulate = Color(1.0, 0.85, 0.0)
	_mark.position = Vector2(0.0, MARK_BASE_Y)
	add_child(_mark)
```

- [ ] **Step 3: Animate the marker in `_process()`**

Replace `_process()` with:

```gdscript
func _process(delta: float) -> void:
	_dir_timer -= delta
	if _dir_timer <= 0.0:
		heading    = randf() * TAU
		_dir_timer = randf_range(DIR_CHANGE_MIN, DIR_CHANGE_MAX)
		_update_dir()

	_mark_bob        += delta
	_mark.position.y  = MARK_BASE_Y + sin(_mark_bob * TAU / BOB_PERIOD) * BOB_AMP
```

- [ ] **Step 4: Run the game and verify**

Launch the game (F5 in Godot or via `godot --path . scenes/menu.tscn`). Walk around until a melee NPC (stocky boxer sprite) comes into view. You should see a yellow `!` floating above their head, gently bobbing up and down (~3px over 1.2s). The marker should disappear under fog exactly like the NPC sprite does.

- [ ] **Step 5: Commit**

```bash
git add scripts/actors/npc_melee.gd
git commit -m "feat: floating yellow ! marker on quest-giver NPCs"
```

---

### Task 2: Yellow quest-giver dots on the minimap

**Files:**
- Modify: `scripts/ui/minimap_ui.gd`

- [ ] **Step 1: Add quest-giver dot rendering at the end of `_refresh()`**

Open `scripts/ui/minimap_ui.gd`. Find `_refresh()`. It currently ends with:

```gdscript
	# Player dot: 3×3 white at center
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_image.set_pixel(half + dx, half + dy, Color.WHITE)

	_texture.update(_image)
```

Insert the quest-giver loop between the player dot block and `_texture.update()`:

```gdscript
	# Player dot: 3×3 white at center
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_image.set_pixel(half + dx, half + dy, Color.WHITE)

	# Quest-giver dots: 3×3 yellow for each fog-revealed NpcMelee
	var q_color := Color(1.0, 0.85, 0.0)
	for child in _world.get_children():
		if not (child is NpcMelee):
			continue
		var gc  := _world_to_cell((child as NpcMelee).position)
		var px  := half + (gc.x - center.x)
		var py  := half + (gc.y - center.y)
		if px < 0 or px >= CELLS or py < 0 or py >= CELLS:
			continue
		var cs  := ChunkData.CHUNK_SIZE
		var cc  := Vector2i(
			int(floor(float(gc.x) / float(cs))),
			int(floor(float(gc.y) / float(cs)))
		)
		var lx  := gc.x - cc.x * cs
		var ly  := gc.y - cc.y * cs
		var fog := _fog_manager.get_fog_data(cc)
		if fog == null or fog.get_level(lx, ly) == FogData.UNEXPLORED:
			continue
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var ix := px + dx
				var iy := py + dy
				if ix >= 0 and ix < CELLS and iy >= 0 and iy < CELLS:
					_image.set_pixel(ix, iy, q_color)

	_texture.update(_image)
```

- [ ] **Step 2: Run the game and verify**

Launch the game. Open the minimap with `M`. Walk toward a melee NPC until the fog lifts around them. Close the minimap and re-open it — you should see a small yellow 3×3 dot at the NPC's position. Melee NPCs whose fog has not been revealed should not show a dot. The player dot (white) should still render on top of everything else.

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/minimap_ui.gd
git commit -m "feat: yellow minimap dots for fog-revealed quest givers"
```

---

### Task 3: "Quest" dialog option for NpcMelee

**Files:**
- Modify: `scripts/ui/npc_dialog.gd`

- [ ] **Step 1: Add the Quest button and renumber Goodbye in `_build_menu()`**

Open `scripts/ui/npc_dialog.gd`. Find the `if npc is NpcMelee:` block in `_build_menu()`:

```gdscript
	if npc is NpcMelee:
		_add_menu_btn("2.  What is thy wisdom, o wise one?", _on_wisdom, key)
		_add_menu_btn("3.  Goodbye", close, key)
	else:
		_add_menu_btn("2.  Goodbye", close, key)
```

Replace it with:

```gdscript
	if npc is NpcMelee:
		_add_menu_btn("2.  What is thy wisdom, o wise one?", _on_wisdom, key)
		_add_menu_btn("3.  Quest", _on_quest, key)
		_add_menu_btn("4.  Goodbye", close, key)
	else:
		_add_menu_btn("2.  Goodbye", close, key)
```

- [ ] **Step 2: Add the `_on_quest()` handler**

Add this method below `_on_wisdom()`:

```gdscript
func _on_quest() -> void:
	_show_speech("I have no quests for you at this time, traveler.")
```

- [ ] **Step 3: Run the game and verify**

Launch the game. Walk up to a melee NPC and press `E` to interact. The dialog should show four options: `1. Hello`, `2. What is thy wisdom, o wise one?`, `3. Quest`, `4. Goodbye`. Click `3. Quest` — the NPC should say "I have no quests for you at this time, traveler." Press Continue to return to the menu. The Quest option should be grayed out on revisit (visited-state tracking is automatic via `_add_menu_btn`).

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/npc_dialog.gd
git commit -m "feat: stub Quest dialog option for melee NPCs"
```
