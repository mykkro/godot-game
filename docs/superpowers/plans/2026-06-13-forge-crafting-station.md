# Forge Crafting Station Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an impassable Forge world object that opens a three-panel crafting UI (3×3 input, 1×5 output, player inventory) with order-free JSON-driven recipes and full drag-and-drop.

**Architecture:** ForgeNode mirrors ChestNode (StaticBody2D, persists via ChunkData). ForgeRecipeDef is a static class that loads recipes from `data/forge_recipes.json` and handles craft logic. ForgeUI mirrors ChestLootUI — built entirely in GDScript, no .tscn. Player interaction is wired via a new signal on Avatar, connected in main.gd.

**Tech Stack:** Godot 4 GDScript, JSON for recipe data, Godot built-in drag-and-drop (`set_drag_forwarding`).

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `data/forge_recipes.json` | **Create** | 5 starter recipes as JSON |
| `scripts/objects/forge_recipe_def.gd` | **Create** | Load recipes, `can_craft`, `craft` |
| `scripts/data/chunk_data.gd` | **Modify** | Add forge_input/forge_output persistence |
| `scripts/objects/map_object.gd` | **Modify** | FORGE impassable |
| `scripts/objects/pickable_item_def.gd` | **Modify** | FORGE non-pickable |
| `scripts/objects/forge_node.gd` | **Create** | World object (StaticBody2D) |
| `scripts/world/chunk_node.gd` | **Modify** | Spawn ForgeNode on FORGE cells |
| `scripts/editor/item_palette.gd` | **Modify** | Show FORGE texture in palette |
| `scripts/actors/avatar.gd` | **Modify** | `get_interactable_forge()`, signal |
| `scripts/main.gd` | **Modify** | Wire signal, instantiate ForgeUI, call load_recipes() |
| `scripts/ui/forge_ui.gd` | **Create** | Full crafting UI |

---

## Task 1: Recipe data + ForgeRecipeDef

**Files:**
- Create: `data/forge_recipes.json`
- Create: `scripts/objects/forge_recipe_def.gd`

Type int values from `MapObject.Type`: NAILS=7, WOODEN_ROD=9, CLOTH=10, COPPER_ORE=11, IRON_ORE=12, COPPER_BAR=15, IRON_BAR=16, LEATHER=21, BRONZE_AXE=24, COAL_ORE=49, COPPER_WIRE=62, GLASS=63, GLASS_FIBER=64, FLAX_STRING=88, GLASS_VIAL=95.

Stack sizes relevant to these recipes (from `PickableItemDef.max_stack_size`): all ores/bars/materials = 64, GLASS_VIAL = 8, BRONZE_AXE = 1 (non-stackable default).

- [ ] **Step 1: Create `data/forge_recipes.json`**

```json
[
  {
    "name": "Iron Bar",
    "inputs":  [{"type": 12, "count": 2}, {"type": 49, "count": 1}],
    "outputs": [{"type": 16, "count": 2}]
  },
  {
    "name": "Copper Wire",
    "inputs":  [{"type": 11, "count": 2}, {"type": 64, "count": 1}],
    "outputs": [{"type": 62, "count": 3}]
  },
  {
    "name": "Bronze Axe",
    "inputs":  [{"type": 15, "count": 2}, {"type": 16, "count": 1}, {"type": 9, "count": 1}],
    "outputs": [{"type": 24, "count": 1}]
  },
  {
    "name": "Glass Vial",
    "inputs":  [{"type": 63, "count": 2}, {"type": 7, "count": 1}],
    "outputs": [{"type": 95, "count": 3}]
  },
  {
    "name": "Cloth Strip",
    "inputs":  [{"type": 21, "count": 3}, {"type": 88, "count": 1}],
    "outputs": [{"type": 10, "count": 2}]
  }
]
```

- [ ] **Step 2: Create `scripts/objects/forge_recipe_def.gd`**

```gdscript
class_name ForgeRecipeDef

const OUTPUT_CAP := 5   # must match ForgeNode output slot count

static var _recipes: Array = []


static func load_recipes() -> void:
	_recipes.clear()
	var f := FileAccess.open("res://data/forge_recipes.json", FileAccess.READ)
	if f == null:
		push_error("ForgeRecipeDef: cannot open res://data/forge_recipes.json")
		return
	var parsed := JSON.parse_string(f.get_as_text())
	f.close()
	if parsed == null or not (parsed is Array):
		push_error("ForgeRecipeDef: invalid JSON")
		return
	_recipes = parsed as Array


static func get_all() -> Array:
	return _recipes


## Returns true when input_contents contains at least the required types+counts.
## Order-free: aggregates total count per type across all input slots.
static func can_craft(recipe: Dictionary, input_contents: Array) -> bool:
	var available: Dictionary = {}
	for slot in input_contents:
		var t: int = int(slot["type"])
		available[t] = available.get(t, 0) + int(slot["count"])
	for req in recipe["inputs"]:
		if available.get(int(req["type"]), 0) < int(req["count"]):
			return false
	return true


## Consumes ingredients and appends outputs. Returns false without mutating if
## can_craft is false or output has insufficient free slots.
static func craft(recipe: Dictionary, input_contents: Array, output_contents: Array) -> bool:
	if not can_craft(recipe, input_contents):
		return false
	if not _output_has_room(recipe, output_contents):
		return false
	_consume(recipe, input_contents)
	_place_outputs(recipe, output_contents)
	return true


static func _output_has_room(recipe: Dictionary, output_contents: Array) -> bool:
	var free_slots := OUTPUT_CAP - output_contents.size()
	for out_entry in recipe["outputs"]:
		var out_type:  int = int(out_entry["type"])
		var needed:    int = int(out_entry["count"])
		var max_st := PickableItemDef.max_stack_size(out_type)
		for slot in output_contents:
			if needed <= 0:
				break
			if int(slot["type"]) == out_type:
				needed -= (max_st - int(slot["count"]))
		if needed > 0:
			var extra := int(ceil(float(needed) / float(maxi(max_st, 1))))
			if extra > free_slots:
				return false
			free_slots -= extra
	return true


static func _consume(recipe: Dictionary, input_contents: Array) -> void:
	for req in recipe["inputs"]:
		var req_type:  int = int(req["type"])
		var remaining: int = int(req["count"])
		var i := 0
		while i < input_contents.size() and remaining > 0:
			var entry: Dictionary = input_contents[i]
			if int(entry["type"]) == req_type:
				var take := mini(int(entry["count"]), remaining)
				entry["count"] = int(entry["count"]) - take
				remaining -= take
				if int(entry["count"]) <= 0:
					input_contents.remove_at(i)
				else:
					i += 1
			else:
				i += 1


static func _place_outputs(recipe: Dictionary, output_contents: Array) -> void:
	for out_entry in recipe["outputs"]:
		var out_type:  int = int(out_entry["type"])
		var remaining: int = int(out_entry["count"])
		var max_st := PickableItemDef.max_stack_size(out_type)
		for slot in output_contents:
			if remaining <= 0:
				break
			if int(slot["type"]) == out_type:
				var space := max_st - int(slot["count"])
				if space > 0:
					var fill := mini(remaining, space)
					slot["count"] = int(slot["count"]) + fill
					remaining -= fill
		while remaining > 0:
			var amt := mini(remaining, maxi(max_st, 1))
			output_contents.append({"type": out_type, "count": amt})
			remaining -= amt
```

- [ ] **Step 3: Verify JSON is parseable**

Open Godot editor → Script tab → run this one-liner in the Script editor's Output panel to sanity-check before wiring:

```gdscript
# In any GDScript _ready():
var f := FileAccess.open("res://data/forge_recipes.json", FileAccess.READ)
print(JSON.parse_string(f.get_as_text()))
f.close()
```

Expected: Array of 5 Dictionaries printed in output. Remove the test code after.

- [ ] **Step 4: Commit**

```bash
git add data/forge_recipes.json scripts/objects/forge_recipe_def.gd
git commit -m "feat: ForgeRecipeDef — 5 starter recipes, can_craft, craft"
```

---

## Task 2: ChunkData — forge persistence fields

**Files:**
- Modify: `scripts/data/chunk_data.gd`

Pattern mirrors the existing `chest_contents` dictionary. Key = `lx + ly * CHUNK_SIZE`.

- [ ] **Step 1: Add the two new dict fields (after `chest_contents` on line ~26)**

```gdscript
## Forge input slot contents per cell.  key = lx + ly*CHUNK_SIZE → Array or absent.
var forge_input:  Dictionary = {}
## Forge output slot contents per cell. key = lx + ly*CHUNK_SIZE → Array or absent.
var forge_output: Dictionary = {}
```

- [ ] **Step 2: Add getters and setters (after `set_chest_contents` on line ~89)**

```gdscript
func get_forge_input(lx: int, ly: int) -> Variant:
	var key := lx + ly * CHUNK_SIZE
	return forge_input[key] if forge_input.has(key) else null

func set_forge_input(lx: int, ly: int, arr: Array) -> void:
	forge_input[lx + ly * CHUNK_SIZE] = arr

func get_forge_output(lx: int, ly: int) -> Variant:
	var key := lx + ly * CHUNK_SIZE
	return forge_output[key] if forge_output.has(key) else null

func set_forge_output(lx: int, ly: int, arr: Array) -> void:
	forge_output[lx + ly * CHUNK_SIZE] = arr
```

- [ ] **Step 3: Update `to_dict()` — add forge pairs after the `cc_pairs` block (around line 122)**

In `to_dict()`, find the `return {` block and add two new entries:

```gdscript
	# Existing serialization ...
	var fi_pairs: Array = []
	for k in forge_input:
		fi_pairs.append([int(k), (forge_input[k] as Array).duplicate(true)])
	var fo_pairs: Array = []
	for k in forge_output:
		fo_pairs.append([int(k), (forge_output[k] as Array).duplicate(true)])
	return {
		"chunk_x":         chunk_x,
		"chunk_y":         chunk_y,
		"biome":           biome,
		"cells":           rows,
		"pickable_counts": pc_pairs,
		"chest_variants":  cv_pairs,
		"chest_contents":  cc_pairs,
		"forge_input":     fi_pairs,
		"forge_output":    fo_pairs,
	}
```

- [ ] **Step 4: Update `from_dict()` — deserialize forge pairs (after the `chest_contents` loop, around line 144)**

```gdscript
	for pair in data.get("forge_input", []):
		var key := int((pair as Array)[0])
		var raw_arr: Array = (pair as Array)[1]
		var arr: Array = []
		for entry in raw_arr:
			arr.append({"type": int(entry["type"]), "count": int(entry["count"])})
		chunk.forge_input[key] = arr
	for pair in data.get("forge_output", []):
		var key := int((pair as Array)[0])
		var raw_arr: Array = (pair as Array)[1]
		var arr: Array = []
		for entry in raw_arr:
			arr.append({"type": int(entry["type"]), "count": int(entry["count"])})
		chunk.forge_output[key] = arr
```

- [ ] **Step 5: Commit**

```bash
git add scripts/data/chunk_data.gd
git commit -m "feat: ChunkData — forge_input/forge_output persistence fields"
```

---

## Task 3: MapObject + PickableItemDef — FORGE type rules

**Files:**
- Modify: `scripts/objects/map_object.gd`
- Modify: `scripts/objects/pickable_item_def.gd`

- [ ] **Step 1: Make FORGE impassable in `map_object.gd`**

Find `is_type_passable` (line ~194). Change:
```gdscript
# Before:
		Type.ROCK, Type.CHEST_SMALL: return false
# After:
		Type.ROCK, Type.CHEST_SMALL, Type.FORGE: return false
```

- [ ] **Step 2: Make FORGE non-pickable in `pickable_item_def.gd`**

Find `is_pickable` (line ~83). Change:
```gdscript
# Before:
static func is_pickable(obj_type: int) -> bool:
	return obj_type != MapObject.Type.ROCK and obj_type != MapObject.Type.CHEST_SMALL

# After:
static func is_pickable(obj_type: int) -> bool:
	return obj_type != MapObject.Type.ROCK \
		and obj_type != MapObject.Type.CHEST_SMALL \
		and obj_type != MapObject.Type.FORGE
```

- [ ] **Step 3: Commit**

```bash
git add scripts/objects/map_object.gd scripts/objects/pickable_item_def.gd
git commit -m "feat: FORGE is impassable and non-pickable"
```

---

## Task 4: ForgeNode world object

**Files:**
- Create: `scripts/objects/forge_node.gd`

Mirrors `ChestNode` exactly. No random contents generation — starts empty (or loads from ChunkData).

- [ ] **Step 1: Create `scripts/objects/forge_node.gd`**

```gdscript
class_name ForgeNode
extends StaticBody2D

## Impassable interactable forge. Registered in group "forges".
## input_contents:  up to 9 item stacks [{type, count}, ...]
## output_contents: up to 5 item stacks [{type, count}, ...]

const SPRITE_SCALE   := 1.75
const COLL_HALF      := 20.0
const INPUT_SLOTS    := 9
const OUTPUT_SLOTS   := 5

var _cell_x:     int       = 0
var _cell_y:     int       = 0
var _chunk_data: ChunkData = null   # set by ChunkNode after initialize

var input_contents:  Array[Dictionary] = []
var output_contents: Array[Dictionary] = []


func initialize(p_cx: int, p_cy: int,
		p_chunk_x: int = 0, p_chunk_y: int = 0,
		p_stored_input: Variant = null, p_stored_output: Variant = null) -> void:
	_cell_x = p_cx
	_cell_y = p_cy

	add_to_group("forges")

	collision_layer = 1
	collision_mask  = 0

	var col  := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(COLL_HALF * 2.0, COLL_HALF * 2.0)
	col.shape = rect
	add_child(col)

	var sprite               := Sprite2D.new()
	sprite.texture            = PickableItemDef.get_texture(MapObject.Type.FORGE)
	sprite.texture_filter     = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale              = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	add_child(sprite)

	if p_stored_input != null:
		for entry in (p_stored_input as Array):
			input_contents.append({"type": int(entry["type"]), "count": int(entry["count"])})
	if p_stored_output != null:
		for entry in (p_stored_output as Array):
			output_contents.append({"type": int(entry["type"]), "count": int(entry["count"])})


func flush_to_data() -> void:
	if _chunk_data == null:
		return
	_chunk_data.set_forge_input(_cell_x,  _cell_y, input_contents.duplicate(true))
	_chunk_data.set_forge_output(_cell_x, _cell_y, output_contents.duplicate(true))
```

- [ ] **Step 2: Commit**

```bash
git add scripts/objects/forge_node.gd
git commit -m "feat: ForgeNode — impassable StaticBody2D, persists via ChunkData"
```

---

## Task 5: Chunk spawning + editor palette

**Files:**
- Modify: `scripts/world/chunk_node.gd`
- Modify: `scripts/editor/item_palette.gd`

- [ ] **Step 1: Add `_spawn_forges()` to `chunk_node.gd` and call it from `initialize`**

After the `_spawn_chests()` method (around line 46), add:

```gdscript
## Spawn ForgeNodes for every FORGE object in the chunk.
func _spawn_forges() -> void:
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var cell := _data.get_cell(x, y)
			if cell == null:
				continue
			for obj_type in cell.objects:
				if obj_type == MapObject.Type.FORGE:
					var node := ForgeNode.new()
					node.position = Vector2(
						(x + 0.5) * CELL_SIZE,
						(y + 0.5) * CELL_SIZE
					)
					add_child(node)
					var stored_input:  Variant = _data.get_forge_input(x, y)
					var stored_output: Variant = _data.get_forge_output(x, y)
					node.initialize(x, y, _data.chunk_x, _data.chunk_y,
							stored_input, stored_output)
					node._chunk_data = _data
```

In `initialize()` (line ~18), add the call after `_spawn_chests()`:

```gdscript
func initialize(data: ChunkData) -> void:
	_data = data
	_rebuild_collision()
	_spawn_pickables()
	_spawn_chests()
	_spawn_forges()          # ← add this line
	queue_redraw()
```

- [ ] **Step 2: Fix item_palette.gd so FORGE shows its icon**

In `item_palette.gd`, find the objects loop (line ~38). The current code only loads the texture for pickable items, so FORGE (which is non-pickable) would show a coloured square. Fix by also loading the texture for FORGE:

```gdscript
	# Before:
	var tex: Texture2D = null
	if PickableItemDef.is_pickable(obj_type):
		tex = PickableItemDef.get_texture(obj_type)

	# After:
	var tex: Texture2D = null
	if PickableItemDef.is_pickable(obj_type) or obj_type == MapObject.Type.FORGE:
		tex = PickableItemDef.get_texture(obj_type)
```

- [ ] **Step 3: Launch Godot editor and verify**

- Open the map editor. The FORGE type (id 145) should appear in the Objects palette with its forge.png icon.
- Paint a FORGE tile on the map. The editor canvas should show the forge sprite.
- Right-click the FORGE tile: nothing should happen (no chest editor opens for forges).
- Play the game: standing on a FORGE cell should be blocked (impassable collision).

- [ ] **Step 4: Commit**

```bash
git add scripts/world/chunk_node.gd scripts/editor/item_palette.gd
git commit -m "feat: chunk spawning for ForgeNode, editor palette icon"
```

---

## Task 6: Avatar signal + main.gd wiring

**Files:**
- Modify: `scripts/actors/avatar.gd`
- Modify: `scripts/main.gd`

- [ ] **Step 1: Add `forge_interact_requested` signal to `avatar.gd`**

Near the top of `avatar.gd` where `chest_interact_requested` is declared (line ~21), add:

```gdscript
signal forge_interact_requested(forge: ForgeNode)
```

- [ ] **Step 2: Add `get_interactable_forge()` to `avatar.gd`**

After `get_interactable_chest()` (line ~338), add:

```gdscript
## Returns the nearest ForgeNode within INTERACT_DIST and roughly in front.
func get_interactable_forge() -> ForgeNode:
	var best:      ForgeNode = null
	var best_dist: float     = INF
	for node in get_tree().get_nodes_in_group("forges"):
		var forge := node as ForgeNode
		if forge == null:
			continue
		var d := global_position.distance_to(forge.global_position)
		if d > INTERACT_DIST:
			continue
		var to_forge := (forge.global_position - global_position).angle()
		var diff     := absf(wrapf(to_forge - heading, -PI, PI))
		if diff > PI * 0.75:
			continue
		if d < best_dist:
			best_dist = d
			best      = forge
	return best
```

- [ ] **Step 3: Hook forge into the E-key handler in `avatar.gd`**

Find the E-key block (line ~125):

```gdscript
# Before:
	if ke.keycode == KEY_E and ke.pressed and not ke.echo:
		var npc := get_interactable_npc()
		if npc != null:
			npc_interact_requested.emit(npc)
		elif get_interactable_chest() != null:
			chest_interact_requested.emit(get_interactable_chest())
		else:
			_try_pickup()
		get_viewport().set_input_as_handled()

# After:
	if ke.keycode == KEY_E and ke.pressed and not ke.echo:
		var npc := get_interactable_npc()
		if npc != null:
			npc_interact_requested.emit(npc)
		else:
			var forge := get_interactable_forge()
			if forge != null:
				forge_interact_requested.emit(forge)
			elif get_interactable_chest() != null:
				chest_interact_requested.emit(get_interactable_chest())
			else:
				_try_pickup()
		get_viewport().set_input_as_handled()
```

- [ ] **Step 4: Update `main.gd` — instantiate ForgeUI, call load_recipes(), wire signal**

In `main.gd`, add the field declaration near `_chest_loot_ui` (line ~19):

```gdscript
var _forge_ui: ForgeUI = null
```

In `_ready()`, after `_chest_loot_ui = ChestLootUI.new(); add_child(_chest_loot_ui)` (line ~35), add:

```gdscript
	ForgeRecipeDef.load_recipes()
	_forge_ui = ForgeUI.new()
	add_child(_forge_ui)
```

In `_ready()`, after `_avatar.chest_interact_requested.connect(...)` (line ~50), add:

```gdscript
	_avatar.forge_interact_requested.connect(
		func(forge: ForgeNode) -> void:
			_forge_ui.open(_avatar.inventory, forge)
	)
```

- [ ] **Step 5: Commit**

```bash
git add scripts/actors/avatar.gd scripts/main.gd
git commit -m "feat: avatar forge interaction signal, ForgeUI wired in main"
```

---

## Task 7: ForgeUI — crafting screen

**Files:**
- Create: `scripts/ui/forge_ui.gd`

Closely mirrors `ChestLootUI`. Three-panel top row (input 3×3 | craft button | output 1×5 | recipe list) plus full-width player inventory. All slots support drag-and-drop between each other.

- [ ] **Step 1: Create `scripts/ui/forge_ui.gd`**

```gdscript
class_name ForgeUI
extends CanvasLayer

## Three-panel crafting UI for the Forge world object.
## Opened by Avatar (E key near a ForgeNode). Pauses game while open.

signal closed()

const INPUT_SLOTS  := 9
const OUTPUT_SLOTS := 5
const INV_COLS     := 10
const INV_ROWS     := 5
const SLOT_SIZE    := 52
const SLOT_PAD     := 4

var _inventory: Inventory = null
var _forge:     ForgeNode = null

var _selected_recipe: Dictionary = {}

var _input_icons:   Array = []   # TextureRect × INPUT_SLOTS
var _input_badges:  Array = []   # Label        × INPUT_SLOTS
var _output_icons:  Array = []   # TextureRect × OUTPUT_SLOTS
var _output_badges: Array = []   # Label        × OUTPUT_SLOTS
var _inv_icons:     Array = []   # TextureRect × INV_COLS*INV_ROWS
var _inv_badges:    Array = []   # Label        × INV_COLS*INV_ROWS

var _craft_btn:   Button = null
var _recipe_rows: Array  = []   # PanelContainer per recipe


func _ready() -> void:
	layer        = 72
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible      = false
	_build_ui()


func open(inventory: Inventory, forge: ForgeNode) -> void:
	_inventory = inventory
	_forge     = forge
	visible    = true
	get_tree().paused = true
	var all := ForgeRecipeDef.get_all()
	if all.size() > 0:
		_select_recipe(all[0])
	else:
		_refresh_craft_btn()
	_refresh()


func close() -> void:
	if not visible:
		return
	if _forge != null:
		_forge.flush_to_data()
	visible           = false
	get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_ESCAPE or ke.keycode == KEY_E:
		close()
		get_viewport().set_input_as_handled()


# ── UI Construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color        = Color(0.0, 0.0, 0.0, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var outer := PanelContainer.new()
	var ostyle := StyleBoxFlat.new()
	ostyle.bg_color = Color(0.05, 0.05, 0.09, 0.97)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		ostyle.set_border_width(side, 2)
	ostyle.border_color = Color(0.55, 0.45, 0.20, 0.85)
	for c in range(4):
		ostyle.set_corner_radius(c, 8)
	ostyle.set_content_margin_all(14)
	outer.add_theme_stylebox_override("panel", ostyle)
	center.add_child(outer)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	outer.add_child(root_vbox)

	var title := Label.new()
	title.text = "Forge"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	root_vbox.add_child(title)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	root_vbox.add_child(top_row)

	top_row.add_child(_build_input_panel())
	top_row.add_child(_build_craft_area())
	top_row.add_child(_build_output_panel())
	top_row.add_child(_build_recipe_panel())

	root_vbox.add_child(_build_inv_panel())


func _build_input_panel() -> PanelContainer:
	var panel := _make_panel_container(Color(0.35, 0.40, 0.55, 0.85))
	var vbox  := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	vbox.add_child(_make_title_label("INPUT"))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", SLOT_PAD)
	grid.add_theme_constant_override("v_separation", SLOT_PAD)
	vbox.add_child(grid)

	for idx in range(INPUT_SLOTS):
		var sd   := _make_slot()
		_input_icons.append(sd[0]  as TextureRect)
		_input_badges.append(sd[2] as Label)
		_setup_input_slot(sd[1] as PanelContainer, idx)
		grid.add_child(sd[1] as PanelContainer)

	return panel


func _build_craft_area() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)

	_craft_btn = Button.new()
	_craft_btn.text     = "CRAFT"
	_craft_btn.disabled = true
	_craft_btn.add_theme_font_size_override("font_size", 13)
	_craft_btn.pressed.connect(_on_craft_pressed)
	vbox.add_child(_craft_btn)

	var arrow := Label.new()
	arrow.text = ">"
	arrow.add_theme_font_size_override("font_size", 20)
	arrow.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(arrow)

	return vbox


func _build_output_panel() -> PanelContainer:
	var panel := _make_panel_container(Color(0.20, 0.55, 0.30, 0.85))
	var vbox  := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	vbox.add_child(_make_title_label("OUTPUT"))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", SLOT_PAD)
	vbox.add_child(col)

	for idx in range(OUTPUT_SLOTS):
		var sd := _make_slot()
		_output_icons.append(sd[0]  as TextureRect)
		_output_badges.append(sd[2] as Label)
		_setup_output_slot(sd[1] as PanelContainer, idx)
		col.add_child(sd[1] as PanelContainer)

	return panel


func _build_recipe_panel() -> PanelContainer:
	var panel := _make_panel_container(Color(0.35, 0.40, 0.55, 0.85))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	vbox.add_child(_make_title_label("RECIPES"))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(180, 0)
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for recipe in ForgeRecipeDef.get_all():
		var row := _build_recipe_row(recipe)
		_recipe_rows.append(row)
		list.add_child(row)

	return panel


func _build_inv_panel() -> PanelContainer:
	var panel := _make_panel_container(Color(0.35, 0.40, 0.55, 0.85))
	var vbox  := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)
	header.add_child(_make_title_label("Your Inventory"))
	header.add_child(_make_button("Close  [E]", close))

	var grid := GridContainer.new()
	grid.columns = INV_COLS
	grid.add_theme_constant_override("h_separation", SLOT_PAD)
	grid.add_theme_constant_override("v_separation", SLOT_PAD)
	vbox.add_child(grid)

	for idx in range(INV_COLS * INV_ROWS):
		var sd := _make_slot()
		_inv_icons.append(sd[0]  as TextureRect)
		_inv_badges.append(sd[2] as Label)
		_setup_inv_slot(sd[1] as PanelContainer, idx)
		grid.add_child(sd[1] as PanelContainer)

	return panel


# ── Recipe row ───────────────────────────────────────────────────────────────

func _build_recipe_row(recipe: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.set_meta("recipe", recipe)

	var unsel := _recipe_row_style(false)
	row.add_theme_stylebox_override("panel", unsel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = recipe["name"]
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var icon_row := HBoxContainer.new()
	icon_row.add_theme_constant_override("separation", 2)
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_row)

	for entry in recipe["inputs"]:
		var typ: int = int(entry["type"])
		var cnt: int = int(entry["count"])
		if PickableItemDef.max_stack_size(typ) > 1:
			icon_row.add_child(_make_recipe_icon(typ, cnt, false))
		else:
			for _i in range(cnt):
				icon_row.add_child(_make_recipe_icon(typ, 1, false))

	var arr_lbl := Label.new()
	arr_lbl.text = ">"
	arr_lbl.add_theme_font_size_override("font_size", 10)
	arr_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	arr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.add_child(arr_lbl)

	for entry in recipe["outputs"]:
		var typ: int = int(entry["type"])
		var cnt: int = int(entry["count"])
		if PickableItemDef.max_stack_size(typ) > 1:
			icon_row.add_child(_make_recipe_icon(typ, cnt, true))
		else:
			for _i in range(cnt):
				icon_row.add_child(_make_recipe_icon(typ, 1, true))

	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_select_recipe(recipe)
				row.accept_event()
	)

	return row


func _make_recipe_icon(item_type: int, count: int, is_output: bool) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(26, 26)
	wrap.mouse_filter        = Control.MOUSE_FILTER_IGNORE

	var icon := TextureRect.new()
	icon.texture        = PickableItemDef.get_texture(item_type)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode    = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(icon)

	var border := Panel.new()
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color    = Color(0, 0, 0, 0)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		bs.set_border_width(side, 1)
	bs.border_color = Color(0.27, 0.70, 0.40) if is_output else Color(0.22, 0.22, 0.42)
	border.add_theme_stylebox_override("panel", bs)
	wrap.add_child(border)

	if count > 1:
		var badge := Label.new()
		badge.text = str(count)
		badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.offset_left   = -18
		badge.offset_top    = -11
		badge.offset_right  = -1
		badge.offset_bottom = -1
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.add_theme_font_size_override("font_size", 8)
		badge.add_theme_color_override("font_color",        Color(0.88, 0.75, 0.2))
		badge.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
		badge.add_theme_constant_override("shadow_offset_x", 1)
		badge.add_theme_constant_override("shadow_offset_y", 1)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(badge)

	return wrap


func _recipe_row_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.18, 0.30, 0.9) if selected else Color(0.07, 0.07, 0.12, 0.9)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	style.set_border_width(SIDE_LEFT, 3)
	style.border_color = Color(0.2, 0.8, 0.3) if selected else Color(0.18, 0.18, 0.32, 0.7)
	for c in range(4):
		style.set_corner_radius(c, 4)
	style.set_content_margin_all(5)
	return style


func _select_recipe(recipe: Dictionary) -> void:
	_selected_recipe = recipe
	for row in _recipe_rows:
		var pc := row as PanelContainer
		var r: Dictionary = pc.get_meta("recipe")
		pc.add_theme_stylebox_override("panel", _recipe_row_style(r["name"] == recipe["name"]))
	_refresh_craft_btn()


# ── Slot drag-and-drop ───────────────────────────────────────────────────────

func _setup_input_slot(slot: PanelContainer, idx: int) -> void:
	slot.set_drag_forwarding(
		func(_pos: Vector2) -> Variant:
			if _forge == null or idx >= _forge.input_contents.size():
				return null
			slot.set_drag_preview(_make_drag_preview(int(_forge.input_contents[idx]["type"])))
			return {"forge_input_slot": idx},

		func(_pos: Vector2, data: Variant) -> bool:
			if not (data is Dictionary):
				return false
			if data.has("forge_input_slot"):
				return int(data["forge_input_slot"]) != idx
			return data.has("forge_inv_slot") or data.has("forge_output_slot"),

		func(_pos: Vector2, data: Variant) -> void:
			if _forge == null:
				return
			if data.has("forge_input_slot"):
				var src: int = int(data["forge_input_slot"])
				if src < _forge.input_contents.size():
					if idx < _forge.input_contents.size():
						_merge_or_swap(_forge.input_contents, src,
								_forge.input_contents, idx)
					else:
						var entry := _forge.input_contents[src]
						_forge.input_contents.remove_at(src)
						_forge.input_contents.insert(
								mini(idx, _forge.input_contents.size()), entry)
			elif data.has("forge_inv_slot"):
				_move_inv_to_arr(int(data["forge_inv_slot"]),
						_forge.input_contents, idx, INPUT_SLOTS)
			elif data.has("forge_output_slot"):
				_move_arr_to_arr(_forge.output_contents, int(data["forge_output_slot"]),
						_forge.input_contents, idx, INPUT_SLOTS)
			_refresh()
	)


func _setup_output_slot(slot: PanelContainer, idx: int) -> void:
	slot.set_drag_forwarding(
		func(_pos: Vector2) -> Variant:
			if _forge == null or idx >= _forge.output_contents.size():
				return null
			slot.set_drag_preview(_make_drag_preview(int(_forge.output_contents[idx]["type"])))
			return {"forge_output_slot": idx},

		func(_pos: Vector2, data: Variant) -> bool:
			if not (data is Dictionary):
				return false
			if data.has("forge_output_slot"):
				return int(data["forge_output_slot"]) != idx
			return data.has("forge_inv_slot") or data.has("forge_input_slot"),

		func(_pos: Vector2, data: Variant) -> void:
			if _forge == null:
				return
			if data.has("forge_output_slot"):
				var src: int = int(data["forge_output_slot"])
				if src < _forge.output_contents.size():
					if idx < _forge.output_contents.size():
						_merge_or_swap(_forge.output_contents, src,
								_forge.output_contents, idx)
					else:
						var entry := _forge.output_contents[src]
						_forge.output_contents.remove_at(src)
						_forge.output_contents.insert(
								mini(idx, _forge.output_contents.size()), entry)
			elif data.has("forge_inv_slot"):
				_move_inv_to_arr(int(data["forge_inv_slot"]),
						_forge.output_contents, idx, OUTPUT_SLOTS)
			elif data.has("forge_input_slot"):
				_move_arr_to_arr(_forge.input_contents, int(data["forge_input_slot"]),
						_forge.output_contents, idx, OUTPUT_SLOTS)
			_refresh()
	)


func _setup_inv_slot(slot: PanelContainer, idx: int) -> void:
	slot.set_drag_forwarding(
		func(_pos: Vector2) -> Variant:
			if _inventory == null or idx >= _inventory.count():
				return null
			slot.set_drag_preview(_make_drag_preview(_inventory.get_type(idx)))
			return {"forge_inv_slot": idx},

		func(_pos: Vector2, data: Variant) -> bool:
			if not (data is Dictionary):
				return false
			if data.has("forge_inv_slot"):
				return int(data["forge_inv_slot"]) != idx
			return data.has("forge_input_slot") or data.has("forge_output_slot"),

		func(_pos: Vector2, data: Variant) -> void:
			if _inventory == null:
				return
			if data.has("forge_inv_slot"):
				var src: int = int(data["forge_inv_slot"])
				var dst: int = idx
				if src < _inventory.count() and dst < _inventory.count():
					var src_type := _inventory.get_type(src)
					if src_type == _inventory.get_type(dst):
						var max_st := PickableItemDef.max_stack_size(src_type)
						if max_st > 1:
							var space := max_st - _inventory.get_count(dst)
							if space > 0:
								var move := mini(_inventory.get_count(src), space)
								_inventory.items[dst]["count"] += move
								_inventory.remove_from_slot(src, move)
								_refresh()
								return
				_inventory.move_slot(src, dst)
			elif data.has("forge_input_slot") and _forge != null:
				_move_arr_to_inv(_forge.input_contents,
						int(data["forge_input_slot"]), idx)
			elif data.has("forge_output_slot") and _forge != null:
				_move_arr_to_inv(_forge.output_contents,
						int(data["forge_output_slot"]), idx)
			_refresh()
	)


# ── Transfer helpers ─────────────────────────────────────────────────────────

## Merge (same type) or swap (different type) two occupied Array slots.
## src_arr and dst_arr may be the same Array.
func _merge_or_swap(src_arr: Array, src_idx: int, dst_arr: Array, dst_idx: int) -> void:
	var src: Dictionary = src_arr[src_idx]
	var dst: Dictionary = dst_arr[dst_idx]
	var src_type: int = int(src["type"])
	if src_type == int(dst["type"]):
		var max_st := PickableItemDef.max_stack_size(src_type)
		var space  := max_st - int(dst["count"])
		var move   := mini(int(src["count"]), space)
		if move <= 0:
			return
		dst["count"] = int(dst["count"]) + move
		src["count"] = int(src["count"]) - move
		if int(src["count"]) <= 0:
			src_arr.remove_at(src_idx)
	else:
		src_arr[src_idx] = dst
		dst_arr[dst_idx] = src


## Move/merge an inventory slot into a forge Array slot.
func _move_inv_to_arr(inv_idx: int, dst_arr: Array, dst_idx: int, dst_cap: int) -> void:
	if _inventory == null or inv_idx < 0 or inv_idx >= _inventory.count():
		return
	var src_type:  int = _inventory.get_type(inv_idx)
	var src_count: int = _inventory.get_count(inv_idx)
	if dst_idx < dst_arr.size():
		var dst: Dictionary = dst_arr[dst_idx]
		if int(dst["type"]) == src_type:
			var max_st := PickableItemDef.max_stack_size(src_type)
			var space  := max_st - int(dst["count"])
			var move   := mini(src_count, space)
			if move <= 0:
				return
			dst["count"] = int(dst["count"]) + move
			_inventory.remove_from_slot(inv_idx, move)
		else:
			dst_arr[dst_idx] = {"type": src_type, "count": src_count}
			_inventory.items[inv_idx] = dst
	else:
		if dst_arr.size() < dst_cap:
			dst_arr.append({"type": src_type, "count": src_count})
			_inventory.remove_from_slot(inv_idx, src_count)


## Move/merge a forge Array slot into the player inventory.
func _move_arr_to_inv(src_arr: Array, src_idx: int, inv_idx: int) -> void:
	if _inventory == null or src_idx < 0 or src_idx >= src_arr.size():
		return
	var src: Dictionary = src_arr[src_idx]
	var src_type:  int  = int(src["type"])
	var src_count: int  = int(src["count"])
	if inv_idx < _inventory.count():
		var dst_type:  int = _inventory.get_type(inv_idx)
		var dst_count: int = _inventory.get_count(inv_idx)
		if dst_type == src_type:
			var max_st := PickableItemDef.max_stack_size(src_type)
			var space  := max_st - dst_count
			var move   := mini(src_count, space)
			if move <= 0:
				return
			_inventory.items[inv_idx]["count"] = dst_count + move
			src["count"] = src_count - move
			if int(src["count"]) <= 0:
				src_arr.remove_at(src_idx)
		else:
			var dst_entry := {"type": dst_type, "count": dst_count}
			src_arr[src_idx] = dst_entry
			_inventory.items[inv_idx] = src
	else:
		if _inventory.count() < Inventory.MAX_ITEMS:
			_inventory.items.append({"type": src_type, "count": src_count})
			src_arr.remove_at(src_idx)


## Move/merge between two different forge Arrays (input ↔ output).
func _move_arr_to_arr(src_arr: Array, src_idx: int,
		dst_arr: Array, dst_idx: int, dst_cap: int) -> void:
	if src_idx < 0 or src_idx >= src_arr.size():
		return
	if dst_idx < dst_arr.size():
		_merge_or_swap(src_arr, src_idx, dst_arr, dst_idx)
	else:
		if dst_arr.size() < dst_cap:
			var src: Dictionary = src_arr[src_idx]
			dst_arr.append({"type": int(src["type"]), "count": int(src["count"])})
			src_arr.remove_at(src_idx)


# ── Refresh ──────────────────────────────────────────────────────────────────

func _refresh() -> void:
	_refresh_input()
	_refresh_output()
	_refresh_inv()
	_refresh_craft_btn()


func _refresh_slot_arr(icons: Array, badges: Array, arr: Array) -> void:
	for i in range(icons.size()):
		var icon  := icons[i]  as TextureRect
		var badge := badges[i] as Label
		if i < arr.size():
			var t: int = int(arr[i]["type"])
			var c: int = int(arr[i]["count"])
			icon.texture = PickableItemDef.get_texture(t)
			badge.text    = str(c)
			badge.visible = c > 1
		else:
			icon.texture  = null
			badge.visible = false


func _refresh_input() -> void:
	if _forge != null:
		_refresh_slot_arr(_input_icons, _input_badges, _forge.input_contents)


func _refresh_output() -> void:
	if _forge != null:
		_refresh_slot_arr(_output_icons, _output_badges, _forge.output_contents)


func _refresh_inv() -> void:
	if _inventory == null:
		return
	for i in range(INV_COLS * INV_ROWS):
		var icon  := _inv_icons[i]  as TextureRect
		var badge := _inv_badges[i] as Label
		if i < _inventory.count():
			var t: int = _inventory.get_type(i)
			var c: int = _inventory.get_count(i)
			icon.texture  = PickableItemDef.get_texture(t)
			badge.text    = str(c)
			badge.visible = c > 1
		else:
			icon.texture  = null
			badge.visible = false


func _refresh_craft_btn() -> void:
	if _craft_btn == null:
		return
	if _selected_recipe.is_empty() or _forge == null:
		_craft_btn.disabled = true
		return
	_craft_btn.disabled = not ForgeRecipeDef.can_craft(
			_selected_recipe, _forge.input_contents)


# ── Craft ────────────────────────────────────────────────────────────────────

func _on_craft_pressed() -> void:
	if _forge == null or _selected_recipe.is_empty():
		return
	if ForgeRecipeDef.craft(_selected_recipe, _forge.input_contents,
			_forge.output_contents):
		_refresh()


# ── Widget factories ─────────────────────────────────────────────────────────

func _make_panel_container(border_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.95)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	style.border_color = border_color
	for c in range(4):
		style.set_corner_radius(c, 6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_title_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.47, 0.76, 0.86))
	return lbl


func _make_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(callback)
	return btn


func _make_drag_preview(item_type: int) -> TextureRect:
	var p             := TextureRect.new()
	p.texture          = PickableItemDef.get_texture(item_type)
	p.custom_minimum_size = Vector2(44, 44)
	p.expand_mode      = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	p.stretch_mode     = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.texture_filter   = CanvasItem.TEXTURE_FILTER_NEAREST
	return p


## Returns [TextureRect icon, PanelContainer slot, Label badge].
func _make_slot() -> Array:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	var bg := StyleBoxFlat.new()
	bg.bg_color     = Color(0.10, 0.10, 0.15, 0.9)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		bg.set_border_width(side, 1)
	bg.border_color = Color(0.25, 0.25, 0.38, 0.7)
	for c in range(4):
		bg.set_corner_radius(c, 3)
	slot.add_theme_stylebox_override("panel", bg)

	var icon_wrap := Control.new()
	icon_wrap.custom_minimum_size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
	icon_wrap.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon_wrap)

	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode    = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	icon_wrap.add_child(icon)

	var badge := Label.new()
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left   = -34
	badge.offset_top    = -15
	badge.offset_right  = -1
	badge.offset_bottom = -1
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color",        Color(1.0, 1.0, 0.65))
	badge.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	badge.add_theme_constant_override("shadow_offset_x", 1)
	badge.add_theme_constant_override("shadow_offset_y", 1)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible      = false
	icon_wrap.add_child(badge)

	return [icon, slot, badge]
```

- [ ] **Step 2: Launch the game and open a Forge**

Place a FORGE tile in the map editor, save, and play:

1. Walk up to the forge and press **E** — the ForgeUI should open (game pauses).
2. Press **E** or **Escape** — UI closes, game resumes.
3. Drag items from your inventory into the input grid — icons should appear.
4. Click the **Iron Bar** recipe — recipe row gets green left border.
5. Add 2× Iron Ore and 1× Coal Ore to the input grid — CRAFT button turns enabled.
6. Press CRAFT — Iron Ores and Coal vanish from input, 2× Iron Bar appear in output.
7. Drag the Iron Bar from output to inventory — it moves.
8. Walk away and back; open forge again — input/output contents should still be there.

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/forge_ui.gd
git commit -m "feat: ForgeUI — 3-panel crafting screen with full drag-and-drop"
```

---

## Task 8: Version bump and final commit

- [ ] **Step 1: Update `VERSION`**

```
1.3
```

- [ ] **Step 2: Commit**

```bash
git add VERSION
git commit -m "feat: v1.3 — Forge crafting station with recipe UI, persistence, drag-and-drop"
```
