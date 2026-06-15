# Monster Encounters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add persistent static monster encounters drawn from `media/rpg-beings/` that spawn randomly on the map, are interactable via E key, and offer a Fight option returning a placeholder dialog.

**Architecture:** `MonsterNode` (StaticBody2D) mirrors the NpcMelee pattern — collision on Actor layer, sprite loaded from a random PNG in `media/rpg-beings/`, serialised as `type: "monster"` entries in the shared `user://npcs.json` file. `NpcManager` handles chunk-based spawning, dedup, and save/load. `Avatar.get_interactable_npc()` and `NpcDialog._build_menu()` each get a one-line extension.

**Tech Stack:** Godot 4, GDScript. No external dependencies. Verification is done by running the game.

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| **Create** | `scripts/actors/monster_node.gd` | MonsterNode class — sprite, collision, serialisation |
| **Modify** | `scripts/world/npc_manager.gd` | Monster spawn/save/load/pre-mark |
| **Modify** | `scripts/actors/avatar.gd` | Include MonsterNode in interactable scan |
| **Modify** | `scripts/ui/npc_dialog.gd` | Monster menu branch, `_on_fight`, `_npc_label` |

---

## Task 1: MonsterNode class

**Files:**
- Create: `scripts/actors/monster_node.gd`

- [ ] **Step 1: Create the file**

`scripts/actors/monster_node.gd`:
```gdscript
class_name MonsterNode
extends StaticBody2D

const DISPLAY_SIZE := 48.0   # 75% of ChunkData.CELL_SIZE (64)
const COLL_RADIUS  := 24.0   # DISPLAY_SIZE / 2

var monster_id: String = ""
var species:    String = ""   # filename stem, e.g. "Wolf"

var _sprite: Sprite2D = null


func _ready() -> void:
	collision_layer = 1   # Actor.ACTOR_LAYER
	collision_mask  = 0
	add_to_group("monsters")

	var col    := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = COLL_RADIUS
	col.shape     = circle
	add_child(col)


## Call after add_child for new (non-restored) monsters to pick a random species.
func initialize() -> void:
	species = _pick_random_species()
	_load_sprite()


func to_dict() -> Dictionary:
	return {
		"type":       "monster",
		"monster_id": monster_id,
		"species":    species,
		"x":          position.x,
		"y":          position.y,
	}


func restore_from_dict(data: Dictionary) -> void:
	monster_id = str(data.get("monster_id", ""))
	species    = str(data.get("species", ""))
	position   = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	_load_sprite()


func _pick_random_species() -> String:
	var files := DirAccess.get_files_at("res://media/rpg-beings/")
	var pngs: Array[String] = []
	for f in files:
		if f.get_extension() == "png":
			pngs.append(f.get_basename())
	if pngs.is_empty():
		return "Unknown"
	return pngs[randi() % pngs.size()]


func _load_sprite() -> void:
	if _sprite != null:
		_sprite.queue_free()
		_sprite = null
	if species.is_empty():
		return
	var path := "res://media/rpg-beings/%s.png" % species
	var tex   := load(path) as Texture2D
	if tex == null:
		push_error("MonsterNode: texture not found at %s" % path)
		return
	_sprite         = Sprite2D.new()
	_sprite.texture = tex
	_sprite.scale   = Vector2(
		DISPLAY_SIZE / float(tex.get_width()),
		DISPLAY_SIZE / float(tex.get_height())
	)
	add_child(_sprite)
```

- [ ] **Step 2: Verify the file parses**

Open the Godot editor (or run `godot --headless --quit` from the project root). The script should have no parse errors. In the editor Output panel you should see no errors referencing `monster_node.gd`.

- [ ] **Step 3: Commit**

```bash
git add scripts/actors/monster_node.gd
git commit -m "feat: add MonsterNode class with random rpg-beings sprite"
```

---

## Task 2: Spawn and persist monsters in NpcManager

**Files:**
- Modify: `scripts/world/npc_manager.gd`

- [ ] **Step 1: Add monster constants and state variables**

In `scripts/world/npc_manager.gd`, add after the existing `const QUEST_GIVER_CHANCE` line:

```gdscript
const MONSTER_SPAWN_CHANCE := 0.60       # probability per chunk (at most 1)
```

Add after the existing `var _next_knight_id: int = 1` line:

```gdscript
var _monster_spawned: Dictionary = {}   # Vector2i → true for chunks that have a monster
var _next_monster_id: int        = 1
```

- [ ] **Step 2: Extend `save()` to include monsters**

Replace the existing `save()` function with:

```gdscript
func save() -> void:
	var data: Array = []
	for child in _world.get_children():
		if child is NpcKnight:
			data.append((child as NpcKnight).to_dict())
		elif child is NpcMelee:
			data.append((child as NpcMelee).to_dict())
		elif child is MonsterNode:
			data.append((child as MonsterNode).to_dict())
	SaveManager.save_npcs(data)
```

- [ ] **Step 3: Extend `pre_mark_from_save()` to mark monster chunks**

Replace the existing `pre_mark_from_save()` with:

```gdscript
func pre_mark_from_save() -> void:
	for entry in SaveManager.load_npcs():
		var d := entry as Dictionary
		if d.get("type", "") == "melee":
			var pos := Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
			_melee_spawned[_chunk_of(pos)] = true
			_bump_counter(str(d.get("npc_id", "")), "melee_", _next_melee_id)
		elif d.get("type", "") == "monster":
			var pos := Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
			_monster_spawned[_chunk_of(pos)] = true
			_bump_counter(str(d.get("monster_id", "")), "monster_", _next_monster_id)
```

- [ ] **Step 4: Extend `load_and_spawn()` to restore monsters**

Replace the existing `load_and_spawn()` with:

```gdscript
func load_and_spawn() -> void:
	for entry in SaveManager.load_npcs():
		var d := entry as Dictionary
		match d.get("type", "knight"):
			"melee":
				var npc := NpcMelee.new()
				_world.add_child(npc)
				npc.restore_from_dict(d)
				if not d.has("perks"):
					_roll_trader_perk(npc)
				_bump_counter(npc.npc_id, "melee_", _next_melee_id)
				var cc := _chunk_of(npc.position)
				_melee_spawned[cc] = true
			"monster":
				var monster := MonsterNode.new()
				_world.add_child(monster)
				monster.restore_from_dict(d)
				_bump_counter(monster.monster_id, "monster_", _next_monster_id)
				_monster_spawned[_chunk_of(monster.position)] = true
			_:
				var npc := NpcKnight.new()
				_world.add_child(npc)
				npc.restore_from_dict(d)
				_bump_counter(npc.npc_id, "knight_", _next_knight_id)
```

- [ ] **Step 5: Extend `_on_chunk_loaded()` to spawn monsters**

At the end of `_on_chunk_loaded()`, after the existing melee block, add:

```gdscript
	# Monster (permanent, at most 1 per chunk).
	if not _monster_spawned.has(coord) and randf() < MONSTER_SPAWN_CHANCE:
		var spawn := _find_spawn_pos(coord)
		if is_finite(spawn.x):
			var monster          := MonsterNode.new()
			monster.monster_id    = "monster_%03d" % _next_monster_id
			_next_monster_id     += 1
			monster.position      = spawn
			_world.add_child(monster)
			monster.initialize()
			_monster_spawned[coord] = true
```

- [ ] **Step 6: Extend `_bump_counter()` to handle monster IDs**

Replace the existing `_bump_counter()` with:

```gdscript
func _bump_counter(id: String, prefix: String, counter: int) -> void:
	if id.begins_with(prefix):
		var n := int(id.substr(prefix.length()))
		if n >= counter:
			if prefix == "melee_":
				_next_melee_id = n + 1
			elif prefix == "monster_":
				_next_monster_id = n + 1
			else:
				_next_knight_id = n + 1
```

- [ ] **Step 7: Run the game and verify monsters appear**

Launch the game. Walk around — you should see small square creature icons standing on the map in most chunks. Each chunk should have at most one. Open the Godot debugger (F4 in-game toggles collision shapes) to confirm each monster has a visible collision circle of ~24 px radius.

- [ ] **Step 8: Verify persistence**

Save (pause menu → Save) and quit. Relaunch. Monsters should reappear in the exact same positions. The `user://npcs.json` file should contain entries with `"type": "monster"`.

- [ ] **Step 9: Commit**

```bash
git add scripts/world/npc_manager.gd
git commit -m "feat: spawn and persist monsters via NpcManager"
```

---

## Task 3: Include MonsterNode in Avatar's interactable scan

**Files:**
- Modify: `scripts/actors/avatar.gd:375-394`

- [ ] **Step 1: Extend `get_interactable_npc()`**

In `scripts/actors/avatar.gd`, find `get_interactable_npc()`. Replace the type check line:

```gdscript
		if not (child is NpcKnight or child is NpcMelee):
```

with:

```gdscript
		if not (child is NpcKnight or child is NpcMelee or child is MonsterNode):
```

The full function after the change:

```gdscript
func get_interactable_npc() -> Node2D:
	if _world == null:
		return null
	var best:      Node2D = null
	var best_dist: float  = INF
	for child in _world.get_children():
		if not (child is NpcKnight or child is NpcMelee or child is MonsterNode):
			continue
		var npc := child as Node2D
		var d   := position.distance_to(npc.position)
		if d > INTERACT_DIST:
			continue
		var to_npc := (npc.position - position).angle()
		var diff   := absf(wrapf(to_npc - heading, -PI, PI))
		if diff > PI * 0.75:
			continue
		if d < best_dist:
			best_dist = d
			best      = npc
	return best
```

- [ ] **Step 2: Run the game and verify E-key registers near a monster**

Walk up to a monster until it's within ~46 px (roughly touching distance). Press E. The NPC dialog should open (even if it shows the wrong buttons at this stage — that's fixed in Task 4). If no dialog opens, check that the monster is within `INTERACT_DIST` (46 px) and within a 135° forward arc.

- [ ] **Step 3: Commit**

```bash
git add scripts/actors/avatar.gd
git commit -m "feat: include MonsterNode in avatar interactable NPC scan"
```

---

## Task 4: Add Monster dialog branch to NpcDialog

**Files:**
- Modify: `scripts/ui/npc_dialog.gd`

- [ ] **Step 1: Add `_on_fight()` handler**

In `scripts/ui/npc_dialog.gd`, add the following method after `_on_hello()`:

```gdscript
func _on_fight() -> void:
	_show_speech("No mood for fighting today.")
```

- [ ] **Step 2: Add MonsterNode branch in `_build_menu()`**

In `_build_menu()`, the current structure is:

```gdscript
	_add_menu_btn("1.  Hello", _on_hello, key)

	if npc is NpcMelee:
		...
	else:
		_add_menu_btn("2.  Goodbye", close, key)
```

Replace it with:

```gdscript
	if npc is MonsterNode:
		_add_menu_btn("F.  Fight",    _on_fight, key)
		_add_menu_btn("2.  Goodbye", close,     key)
	else:
		_add_menu_btn("1.  Hello", _on_hello, key)

		if npc is NpcMelee:
			_add_menu_btn("2.  What is thy wisdom, o wise one?", _on_wisdom, key)
			_add_menu_btn("3.  Shop", _on_shop, key)
			if (npc as NpcMelee).is_quest_giver:
				_add_menu_btn("4.  Quest",   _on_quest, key)
				_add_menu_btn("5.  Goodbye", close,     key)
			else:
				_add_menu_btn("4.  Goodbye", close, key)
		else:
			_add_menu_btn("2.  Goodbye", close, key)
```

- [ ] **Step 3: Add MonsterNode case to `_npc_label()`**

In `_npc_label()`, add the MonsterNode case before the existing checks:

```gdscript
static func _npc_label(npc: Node2D) -> String:
	if npc is MonsterNode:
		return (npc as MonsterNode).species
	if npc is NpcKnight:
		return "Knight"
	if npc is NpcMelee:
		var name := (npc as NpcMelee).npc_name
		return name if not name.is_empty() else "Brawler"
	return "Stranger"
```

- [ ] **Step 4: Run the game and verify full monster interaction**

1. Walk up to a monster and press E.
2. The dialog title should show the monster's species name (e.g. "Wolf").
3. The menu should show two buttons: **"F.  Fight"** and **"2.  Goodbye"**.
4. Clicking Fight should show the speech panel with: **"No mood for fighting today."**
5. Clicking "Continue..." should return to the menu.
6. Pressing Escape or E should close the dialog.
7. Interacting with a regular NpcMelee should still show the old menu unchanged.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/npc_dialog.gd
git commit -m "feat: add monster dialog branch with Fight placeholder"
```

---

## Self-Review Notes

- **Spec coverage:** All four spec components covered — MonsterNode (Task 1), NpcManager spawn/save/load (Task 2), Avatar scan (Task 3), NpcDialog (Task 4).
- **Sizing:** `DISPLAY_SIZE = 48.0` (75% of 64), `COLL_RADIUS = 24.0` (48/2). Correct per spec.
- **Persistence:** Monsters saved as `type: "monster"` in existing `user://npcs.json` via `SaveManager.save_npcs` / `load_npcs`. No new save files needed.
- **Type consistency:** `MonsterNode`, `monster_id`, `species`, `initialize()`, `restore_from_dict()`, `to_dict()` — names are consistent across all four tasks.
- **No placeholders found.**
