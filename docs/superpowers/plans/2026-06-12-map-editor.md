# Map Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a panned, tile-painting map editor accessible from the main menu that reads and writes the existing chunk save files.

**Architecture:** A new `MapEditor` Node2D scene built entirely in code. Phase 0 refactors `CellData.terrain_type` from an int enum to a String filename (e.g. `"grass.png"`), backed by a new `TileRegistry` autoload that reads `rpg-tiles/index.json`. Phase 1 adds the editor scene with Camera2D panning, a `ChunkEditorNode` per loaded chunk, a right-panel palette (terrain tiles + items), and save/autosave logic.

**Tech Stack:** Godot 4.6 GDScript, existing `ChunkPersistence`/`ChunkData`/`CellData` classes, `TextureCache`, `SaveManager`, `rpg-tiles/index.json` as the tile registry.

**Spec:** `docs/superpowers/specs/2026-06-12-map-editor-design.md`

---

## Phase 0 — Data model refactor

### Task 1: TileRegistry autoload

**Files:**
- Create: `scripts/editor/tile_registry.gd`
- Modify: `project.godot` (add `[autoload]` section)

- [ ] **Step 1: Create TileRegistry**

```
scripts/editor/tile_registry.gd
```

```gdscript
extends Node

const INDEX_PATH := "res://media/rpg-tiles/index.json"

var _tiles: Dictionary = {}


func _init() -> void:
	var file := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if file == null:
		push_error("TileRegistry: cannot open %s" % INDEX_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("TileRegistry: JSON parse error in index")
		return
	file.close()
	_tiles = (json.data as Dictionary).get("textures", {})


func get_all_tiles() -> Array:
	var result: Array = []
	for filename in _tiles:
		var entry: Dictionary = (_tiles[filename] as Dictionary).duplicate()
		entry["filename"] = filename
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ac: String = a.get("category", "")
		var bc: String = b.get("category", "")
		if ac != bc:
			return ac < bc
		return (a["filename"] as String) < (b["filename"] as String)
	)
	return result


func get_tile(filename: String) -> Dictionary:
	return (_tiles.get(filename, {}) as Dictionary).duplicate()


func get_categories() -> Array:
	var seen: Dictionary = {}
	for filename in _tiles:
		seen[(_tiles[filename] as Dictionary).get("category", "")] = true
	var cats := seen.keys()
	cats.sort()
	return cats


func is_passable(filename: String) -> bool:
	return bool((_tiles.get(filename, {"passable": true}) as Dictionary).get("passable", true))


func get_speed_modifier(filename: String) -> float:
	return float((_tiles.get(filename, {"speed_modifier": 1.0}) as Dictionary).get("speed_modifier", 1.0))
```

- [ ] **Step 2: Register TileRegistry as autoload in project.godot**

Add after the `[rendering]` section (or anywhere at the top level):

```ini
[autoload]

TileRegistry="*res://scripts/editor/tile_registry.gd"
```

- [ ] **Step 3: Verify TileRegistry loads**

Open the project in Godot, run it, check Output for any `TileRegistry:` errors. If `INDEX_PATH` prints an error, verify `res://media/rpg-tiles/index.json` exists (it does — confirmed in spec).

- [ ] **Step 4: Commit**

```bash
git add scripts/editor/tile_registry.gd project.godot
git commit -m "feat: add TileRegistry autoload (rpg-tiles/index.json)"
```

---

### Task 2: CellData terrain_type String + backward-compat migration

**Files:**
- Modify: `scripts/data/cell_data.gd`

The `terrain_type` field changes from `int` to `String`. `from_dict()` auto-migrates old int saves.

- [ ] **Step 1: Rewrite cell_data.gd**

Replace the full file content:

```gdscript
class_name CellData

const MAX_OBJECTS := 16

var terrain_type: String = "grass.png"
var objects: Array = []
var is_obstacle: bool = false


func _init(p_terrain: String = "grass.png") -> void:
	terrain_type = p_terrain
	is_obstacle  = not TileRegistry.is_passable(terrain_type)
	objects      = []


func add_object(obj_type: int) -> bool:
	if objects.size() >= MAX_OBJECTS:
		return false
	objects.append(obj_type)
	return true


func to_dict() -> Dictionary:
	return {
		"terrain_type": terrain_type,
		"objects":      objects.duplicate(),
		"is_obstacle":  is_obstacle,
	}


static func from_dict(data: Dictionary) -> CellData:
	var raw: Variant = data.get("terrain_type", "grass.png")
	var terrain: String
	if raw is int:
		terrain = _migrate_terrain(int(raw))
	else:
		terrain = str(raw)
	var cell := CellData.new(terrain)
	cell.is_obstacle = data.get("is_obstacle", not TileRegistry.is_passable(terrain))
	cell.objects = []
	for item in data.get("objects", []):
		cell.objects.append(int(item))
	return cell


static func _migrate_terrain(old_type: int) -> String:
	match old_type:
		0: return "grass.png"
		1: return "mud.png"
		2: return "granite floor.png"
		3: return "water.png"
		4: return "sand.png"
		5: return "swamp grass sep.png"
		6: return "snow.png"
		7: return "gravel.png"
		8: return "deepocean.png"
		9: return "path.png"
	return "grass.png"
```

- [ ] **Step 2: Commit**

```bash
git add scripts/data/cell_data.gd
git commit -m "refactor: CellData.terrain_type int→String with auto-migration"
```

---

### Task 3: Rewrite TerrainType.gd

**Files:**
- Modify: `scripts/data/terrain_type.gd`

The int-enum and its lookup functions are replaced. Two callers stay: `chunk_node.gd` (get_color fallback) and `world.gd` (if any). After this task, `chunk_node.gd` will no longer call `TerrainType.get_texture_filename` or `TerrainType.get_color`.

- [ ] **Step 1: Replace terrain_type.gd**

```gdscript
class_name TerrainType

## Thin wrapper kept for call-site compatibility during the refactor.
## Terrain is now identified by filename string; TileRegistry is authoritative.

static func is_passable(filename: String) -> bool:
	return TileRegistry.is_passable(filename)


static func blocks_projectile(_filename: String) -> bool:
	return false
```

- [ ] **Step 2: Commit**

```bash
git add scripts/data/terrain_type.gd
git commit -m "refactor: TerrainType — remove int enum, delegate to TileRegistry"
```

---

### Task 4: BiomeDef terrain_weights → String filenames

**Files:**
- Modify: `scripts/world/biome_def.gd`

Replace every `TerrainType.Type.X` weight entry with the corresponding filename string.

- [ ] **Step 1: Update terrain_weights() in biome_def.gd**

Replace only the `terrain_weights` function (leave `Type` enum, `get_display_name`, `get_icon_filename`, `rock_density` unchanged):

```gdscript
static func terrain_weights(biome: int) -> Array:
	match biome:
		Type.PLAINS:
			return [
				["grass.png",           60],
				["mud.png",             20],
				["granite floor.png",    4],
				["water.png",            4],
				["sand.png",             5],
				["swamp grass sep.png",  3],
				["gravel.png",           4],
			]
		Type.CAVES:
			return [
				["granite floor.png",   55],
				["gravel.png",          25],
				["mud.png",             10],
				["water.png",            8],
				["deepocean.png",        2],
			]
		Type.SEA:
			return [
				["deepocean.png",       45],
				["water.png",           40],
				["sand.png",            15],
			]
		Type.ROCKIES:
			return [
				["granite floor.png",   45],
				["gravel.png",          30],
				["mud.png",             10],
				["snow.png",             7],
				["path.png",             5],
				["sand.png",             3],
			]
		Type.SNOW:
			return [
				["snow.png",            65],
				["granite floor.png",   12],
				["gravel.png",           8],
				["water.png",            5],
				["mud.png",              5],
				["path.png",             5],
			]
		Type.FIELDS:
			return [
				["grass.png",           50],
				["mud.png",             30],
				["sand.png",             6],
				["water.png",            6],
				["swamp grass sep.png",  4],
				["path.png",             4],
			]
	return [["grass.png", 1]]
```

- [ ] **Step 2: Commit**

```bash
git add scripts/world/biome_def.gd
git commit -m "refactor: BiomeDef terrain weights use filename strings"
```

---

### Task 5: ChunkGenerator use String terrain

**Files:**
- Modify: `scripts/world/chunk_generator.gd`

`_pick_weighted` returns a `String` now (filename). Update type annotations.

- [ ] **Step 1: Update chunk_generator.gd**

Change `terrain_grid` element types and `_pick_weighted` return type. Find and replace these sections:

```gdscript
## Replace the terrain_grid and left/top neighbour variable declarations:

	var terrain_grid: Array = []   ## Array[Array[String]]
	var biome_grid:   Array = []
```

```gdscript
## In the left-neighbour blending block, change:
			var left_type: String = t_row[x - 1]
```

```gdscript
## In the top-neighbour blending block, change:
				var top_type: String = (terrain_grid[y - 1] as Array)[x]
```

```gdscript
## In second pass, change:
			var terrain: String = (terrain_grid[y] as Array)[x]
			var cell := CellData.new(terrain)
```

```gdscript
## Change _pick_weighted return type:
static func _pick_weighted(rng: RandomNumberGenerator, weights: Array) -> String:
	var total := 0
	for entry in weights:
		total += (entry as Array)[1]
	var roll := rng.randi_range(0, total - 1)
	var acc  := 0
	for entry in weights:
		acc += (entry as Array)[1]
		if roll < acc:
			return str((entry as Array)[0])
	return str((weights[0] as Array)[0])
```

- [ ] **Step 2: Commit**

```bash
git add scripts/world/chunk_generator.gd
git commit -m "refactor: ChunkGenerator terrain uses String filenames"
```

---

### Task 6: ChunkNode use String terrain in _draw()

**Files:**
- Modify: `scripts/world/chunk_node.gd`

`cell.terrain_type` is now a String filename. Call `TextureCache.get_texture()` directly, remove `TerrainType.get_texture_filename()` and `TerrainType.get_color()` calls.

- [ ] **Step 1: Update _draw() in chunk_node.gd**

Replace only the terrain drawing block inside `_draw()`:

```gdscript
			# Terrain fill: texture when available, fallback to flat colour.
			var tex := TextureCache.get_texture(cell.terrain_type)
			if tex != null:
				draw_texture_rect(tex, cell_rect, false)
			else:
				draw_rect(cell_rect, Color(0.22, 0.65, 0.18))
```

(The rest of `_draw()` — grid lines, object drawing — stays unchanged.)

- [ ] **Step 2: Commit**

```bash
git add scripts/world/chunk_node.gd
git commit -m "refactor: ChunkNode draws terrain from string filename via TextureCache"
```

---

### Task 7: Verify data model refactor

No code changes in this task — just run the game and confirm nothing is broken.

- [ ] **Step 1: Run game (new game)**

Open the project in Godot. Press F5 (or Run). Choose "New Game". Walk around — terrain should render exactly as before.

Expected: Grass, mud, water, etc. all display correct textures. No errors in Output.

- [ ] **Step 2: Verify old save migration (if a save exists)**

If `user://chunks/` has any `.json` files from before this refactor:
- Run the game and choose "Continue"
- Walk to a chunk that was previously saved
- Terrain should still render correctly (migration kicks in automatically in `CellData.from_dict()`)

Expected: No errors. Terrain looks correct.

- [ ] **Step 3: Commit checkpoint**

```bash
git commit --allow-empty -m "chore: data model refactor verified"
```

---

## Phase 1 — Map Editor

### Task 8: Main menu "Map Editor" button

**Files:**
- Modify: `scripts/ui/main_menu.gd`

Add a button programmatically in `_ready()`, inserted before the Quit button.

- [ ] **Step 1: Add constant and handler in main_menu.gd**

Add near the top, after the existing `MAIN_SCENE` constant:

```gdscript
const MAP_EDITOR_SCENE := "res://scenes/map_editor.tscn"
```

- [ ] **Step 2: Add button creation in _ready()**

Inside `_ready()`, after `_btn_quit.pressed.connect(_on_quit)` and before `_build_options_panel()`:

```gdscript
	var btn_editor := Button.new()
	btn_editor.text = "Map Editor"
	btn_editor.custom_minimum_size = Vector2(240, 52)
	btn_editor.add_theme_font_size_override("font_size", 20)
	btn_editor.disabled = not SaveManager.has_save()
	btn_editor.pressed.connect(_on_map_editor)
	_vbox.add_child(btn_editor)
	_vbox.move_child(btn_editor, _btn_quit.get_index())
```

- [ ] **Step 3: Add handler**

```gdscript
func _on_map_editor() -> void:
	get_tree().change_scene_to_file(MAP_EDITOR_SCENE)
```

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/main_menu.gd
git commit -m "feat: add Map Editor button to main menu"
```

---

### Task 9: EditorCamera

**Files:**
- Create: `scripts/editor/editor_camera.gd`

- [ ] **Step 1: Create editor_camera.gd**

```gdscript
class_name EditorCamera
extends Camera2D

const ZOOM_MIN  := 0.25
const ZOOM_MAX  := 4.0
const ZOOM_STEP := 0.15

var _dragging: bool = false


func _ready() -> void:
	zoom = Vector2.ONE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_MIDDLE:
				_dragging = mb.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom_by(ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom_by(-ZOOM_STEP)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		position -= mm.relative / zoom


func _zoom_by(delta: float) -> void:
	var z := clampf(zoom.x + delta, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(z, z)
```

- [ ] **Step 2: Commit**

```bash
git add scripts/editor/editor_camera.gd
git commit -m "feat: EditorCamera with middle-drag pan and scroll zoom"
```

---

### Task 10: ChunkEditorNode

**Files:**
- Create: `scripts/editor/chunk_editor_node.gd`

Renders one 16×16 chunk in the editor: terrain textures, object dots, hover highlight, chunk-border line. No collision or pickable spawning.

- [ ] **Step 1: Create chunk_editor_node.gd**

```gdscript
class_name ChunkEditorNode
extends Node2D

const CELL_SIZE  := ChunkData.CELL_SIZE
const CHUNK_SIZE := ChunkData.CHUNK_SIZE

var chunk_data: ChunkData = null
var _hover: Vector2i = Vector2i(-1, -1)


func initialize(data: ChunkData) -> void:
	chunk_data = data
	position   = Vector2(
		data.chunk_x * ChunkData.CHUNK_PIXEL_SIZE,
		data.chunk_y * ChunkData.CHUNK_PIXEL_SIZE
	)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func set_hovered_cell(lx: int, ly: int) -> void:
	var v := Vector2i(lx, ly)
	if v != _hover:
		_hover = v
		queue_redraw()


func clear_hover() -> void:
	if _hover != Vector2i(-1, -1):
		_hover = Vector2i(-1, -1)
		queue_redraw()


func redraw_cell(_x: int, _y: int) -> void:
	queue_redraw()


func _draw() -> void:
	if chunk_data == null:
		return
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var cell := chunk_data.get_cell(x, y)
			if cell == null:
				continue
			var px  := x * CELL_SIZE
			var py  := y * CELL_SIZE
			var rect := Rect2(px, py, CELL_SIZE, CELL_SIZE)

			var tex := TextureCache.get_texture(cell.terrain_type)
			if tex != null:
				draw_texture_rect(tex, rect, false)
			else:
				draw_rect(rect, Color(0.22, 0.65, 0.18))

			draw_rect(rect, Color(0, 0, 0, 0.07), false, 1.0)

			for obj_type in cell.objects:
				_draw_object_dot(obj_type, px, py)

			if Vector2i(x, y) == _hover:
				draw_rect(rect, Color(1, 1, 1, 0.45), false, 2.0)

	var chunk_px := CHUNK_SIZE * CELL_SIZE
	draw_rect(Rect2(0, 0, chunk_px, chunk_px), Color(1, 1, 0, 0.25), false, 1.5)


func _draw_object_dot(obj_type: int, px: int, py: int) -> void:
	var center := Vector2(px + CELL_SIZE * 0.5, py + CELL_SIZE * 0.5)
	var color  := Color.WHITE
	match obj_type:
		MapObject.Type.ROCK:    color = Color(0.50, 0.47, 0.42)
		MapObject.Type.HERB:    color = Color(0.20, 0.80, 0.20)
		MapObject.Type.CRYSTAL: color = Color(0.40, 0.60, 0.90)
		MapObject.Type.COIN:    color = Color(0.90, 0.80, 0.10)
		MapObject.Type.FEATHER: color = Color(0.90, 0.90, 0.90)
		MapObject.Type.POTION:  color = Color(0.80, 0.20, 0.80)
	draw_circle(center, CELL_SIZE * 0.18, color)
```

- [ ] **Step 2: Commit**

```bash
git add scripts/editor/chunk_editor_node.gd
git commit -m "feat: ChunkEditorNode renders terrain, objects, hover highlight"
```

---

### Task 11: TerrainPalette

**Files:**
- Create: `scripts/editor/terrain_palette.gd`

Right-panel terrain tab: scrollable grid of 40×40 tile thumbnails grouped by category, search filter, selection highlight.

- [ ] **Step 1: Create terrain_palette.gd**

```gdscript
class_name TerrainPalette
extends VBoxContainer

signal terrain_selected(filename: String)

var _selected: String = "grass.png"
var _selected_btn: TextureButton = null

var _search: LineEdit
var _scroll: ScrollContainer
var _grid_parent: VBoxContainer
var _info_label: Label


func _ready() -> void:
	_build_ui()
	_populate("")


func _build_ui() -> void:
	_search = LineEdit.new()
	_search.placeholder_text = "filter tiles..."
	_search.text_changed.connect(_on_search)
	add_child(_search)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)

	_grid_parent = VBoxContainer.new()
	_grid_parent.add_theme_constant_override("separation", 2)
	_scroll.add_child(_grid_parent)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 10)
	_info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_info_label.text = "grass.png · terrain · passable"
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_info_label)


func _populate(filter: String) -> void:
	for child in _grid_parent.get_children():
		child.queue_free()
	_selected_btn = null

	var tiles := TileRegistry.get_all_tiles()
	var current_group := ""
	var current_grid: GridContainer = null

	for tile_info in tiles:
		var filename: String = tile_info["filename"]
		if filter != "" and not filename.to_lower().contains(filter.to_lower()):
			continue

		var category: String = tile_info.get("category", "")
		var tags: Array   = tile_info.get("tags", [])
		var primary_tag: String = tags[0] if tags.size() > 0 else ""
		var group := category + " · " + primary_tag

		if group != current_group:
			current_group = group
			var header := Label.new()
			header.text = group
			header.add_theme_font_size_override("font_size", 10)
			header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.65))
			_grid_parent.add_child(header)
			current_grid = GridContainer.new()
			current_grid.columns = 4
			current_grid.add_theme_constant_override("h_separation", 3)
			current_grid.add_theme_constant_override("v_separation", 3)
			_grid_parent.add_child(current_grid)

		var btn := TextureButton.new()
		btn.custom_minimum_size = Vector2(44, 44)
		btn.stretch_mode        = TextureButton.STRETCH_SCALE
		btn.texture_filter      = CanvasItem.TEXTURE_FILTER_NEAREST
		var tex := TextureCache.get_texture(filename)
		if tex != null:
			btn.texture_normal = tex
		btn.tooltip_text = filename
		btn.pressed.connect(_on_tile_pressed.bind(filename, btn))
		current_grid.add_child(btn)

		if filename == _selected:
			_mark_selected(btn)


func _on_search(text: String) -> void:
	_populate(text)


func _on_tile_pressed(filename: String, btn: TextureButton) -> void:
	_selected = filename
	_mark_selected(btn)
	var meta := TileRegistry.get_tile(filename)
	var passable_str := "passable" if meta.get("passable", true) else "impassable"
	_info_label.text = "%s · %s · %s" % [filename, meta.get("category", ""), passable_str]
	emit_signal("terrain_selected", filename)


func _mark_selected(btn: TextureButton) -> void:
	if _selected_btn != null:
		_selected_btn.modulate = Color.WHITE
	_selected_btn = btn
	if btn != null:
		btn.modulate = Color(0.4, 0.9, 0.4)


func get_selected() -> String:
	return _selected
```

- [ ] **Step 2: Commit**

```bash
git add scripts/editor/terrain_palette.gd
git commit -m "feat: TerrainPalette with tile grid, search, selection"
```

---

### Task 12: ItemPalette

**Files:**
- Create: `scripts/editor/item_palette.gd`

Right-panel items tab: buttons for each of the 6 MapObject types.

- [ ] **Step 1: Create item_palette.gd**

```gdscript
class_name ItemPalette
extends VBoxContainer

signal item_selected(item_type: int)

const ITEM_TYPES := [
	MapObject.Type.ROCK,
	MapObject.Type.HERB,
	MapObject.Type.CRYSTAL,
	MapObject.Type.COIN,
	MapObject.Type.FEATHER,
	MapObject.Type.POTION,
]

var _selected: int = MapObject.Type.HERB
var _buttons: Dictionary = {}


func _ready() -> void:
	var hint := Label.new()
	hint.text  = "LMB: place item\nRMB: remove top item"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	add_child(hint)

	for item_type in ITEM_TYPES:
		var btn := Button.new()
		btn.text                  = MapObject.get_name(item_type)
		btn.alignment             = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size   = Vector2(0, 36)
		btn.pressed.connect(_on_item_pressed.bind(item_type))
		add_child(btn)
		_buttons[item_type] = btn

	_update_selection()


func _on_item_pressed(item_type: int) -> void:
	_selected = item_type
	_update_selection()
	emit_signal("item_selected", item_type)


func _update_selection() -> void:
	for item_type in _buttons:
		(_buttons[item_type] as Button).modulate = (
			Color(0.4, 0.9, 0.4) if item_type == _selected else Color.WHITE
		)


func get_selected() -> int:
	return _selected
```

- [ ] **Step 2: Commit**

```bash
git add scripts/editor/item_palette.gd
git commit -m "feat: ItemPalette with 6 object types"
```

---

### Task 13: EditorInput

**Files:**
- Create: `scripts/editor/editor_input.gd`

Translates mouse events to world coordinates and emits chunk+cell signals. Uses `_unhandled_input` so UI clicks are ignored.

- [ ] **Step 1: Create editor_input.gd**

```gdscript
class_name EditorInput
extends Node2D

signal paint_cell(chunk_x: int, chunk_y: int, cell_x: int, cell_y: int)
signal erase_cell(chunk_x: int, chunk_y: int, cell_x: int, cell_y: int)
signal hover_cell(chunk_x: int, chunk_y: int, cell_x: int, cell_y: int)

var _painting: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_painting = mb.pressed
			if mb.pressed:
				_emit_paint(get_global_mouse_position())
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_emit_erase(get_global_mouse_position())
	elif event is InputEventMouseMotion:
		var world_pos := get_global_mouse_position()
		_emit_hover(world_pos)
		if _painting:
			_emit_paint(world_pos)


func _emit_paint(world_pos: Vector2) -> void:
	var c := _world_to_cell(world_pos)
	emit_signal("paint_cell", c[0], c[1], c[2], c[3])


func _emit_erase(world_pos: Vector2) -> void:
	var c := _world_to_cell(world_pos)
	emit_signal("erase_cell", c[0], c[1], c[2], c[3])


func _emit_hover(world_pos: Vector2) -> void:
	var c := _world_to_cell(world_pos)
	emit_signal("hover_cell", c[0], c[1], c[2], c[3])


func _world_to_cell(world_pos: Vector2) -> Array:
	var chunk_x := int(floor(world_pos.x / ChunkData.CHUNK_PIXEL_SIZE))
	var chunk_y := int(floor(world_pos.y / ChunkData.CHUNK_PIXEL_SIZE))
	var lx      := world_pos.x - chunk_x * ChunkData.CHUNK_PIXEL_SIZE
	var ly      := world_pos.y - chunk_y * ChunkData.CHUNK_PIXEL_SIZE
	var cell_x  := clampi(int(floor(lx / ChunkData.CELL_SIZE)), 0, ChunkData.CHUNK_SIZE - 1)
	var cell_y  := clampi(int(floor(ly / ChunkData.CELL_SIZE)), 0, ChunkData.CHUNK_SIZE - 1)
	return [chunk_x, chunk_y, cell_x, cell_y]
```

- [ ] **Step 2: Commit**

```bash
git add scripts/editor/editor_input.gd
git commit -m "feat: EditorInput translates mouse to chunk+cell coordinates"
```

---

### Task 14: EditorUI

**Files:**
- Create: `scripts/editor/editor_ui.gd`

Builds the full editor UI (top bar + right palette panel + status bar) entirely in code.

- [ ] **Step 1: Create editor_ui.gd**

```gdscript
class_name EditorUI
extends Control

signal save_requested
signal autosave_toggled(enabled: bool)
signal back_requested

var autosave_enabled: bool = true

var _chunk_label:      Label
var _cell_label:       Label
var _unsaved_dot:      Label
var _last_saved_label: Label
var _chunks_label:     Label
var _autosave_btn:     Button

var terrain_palette: TerrainPalette
var item_palette:    ItemPalette


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_top_bar()
	_build_right_panel()
	_build_status_bar()


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.16)
	bar.add_theme_stylebox_override("panel", style)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, 40)
	add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	bar.add_child(hbox)

	var back_btn := Button.new()
	back_btn.text = "← Menu"
	back_btn.custom_minimum_size = Vector2(80, 0)
	back_btn.pressed.connect(func(): emit_signal("back_requested"))
	hbox.add_child(back_btn)

	var save_btn := Button.new()
	save_btn.text = "💾 Save"
	save_btn.custom_minimum_size = Vector2(90, 0)
	save_btn.pressed.connect(func(): emit_signal("save_requested"))
	hbox.add_child(save_btn)

	_autosave_btn = Button.new()
	_autosave_btn.custom_minimum_size = Vector2(130, 0)
	_autosave_btn.pressed.connect(_on_autosave_pressed)
	_update_autosave_btn()
	hbox.add_child(_autosave_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_chunk_label = _make_label("Chunk: —, —")
	_cell_label  = _make_label("Cell: —, —")
	hbox.add_child(_chunk_label)
	hbox.add_child(_cell_label)

	_unsaved_dot = _make_label("● unsaved")
	_unsaved_dot.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_unsaved_dot.visible = false
	hbox.add_child(_unsaved_dot)


func _build_right_panel() -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.15)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchor(SIDE_RIGHT,  1.0)
	panel.set_anchor(SIDE_LEFT,   1.0)
	panel.set_anchor(SIDE_TOP,    0.0)
	panel.set_anchor(SIDE_BOTTOM, 1.0)
	panel.offset_left   = -220
	panel.offset_top    = 40
	panel.offset_bottom = -24
	panel.offset_right  = 0
	add_child(panel)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(tabs)

	terrain_palette = TerrainPalette.new()
	terrain_palette.name = "Terrain"
	tabs.add_child(terrain_palette)

	item_palette = ItemPalette.new()
	item_palette.name = "Items"
	tabs.add_child(item_palette)


func _build_status_bar() -> void:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.10)
	bar.add_theme_stylebox_override("panel", style)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.custom_minimum_size = Vector2(0, 24)
	add_child(bar)

	var hbox := HBoxContainer.new()
	bar.add_child(hbox)

	_chunks_label     = _make_label("Chunks loaded: 0", 10)
	_last_saved_label = _make_label("Last saved: —",    10)
	_chunks_label.add_theme_color_override("font_color",      Color(0.5, 0.5, 0.6))
	_last_saved_label.add_theme_color_override("font_color",  Color(0.5, 0.5, 0.6))

	hbox.add_child(_chunks_label)
	var sep := Control.new()
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(sep)
	hbox.add_child(_last_saved_label)

	var hint := _make_label("LMB: paint  RMB: erase  Middle-drag: pan  Scroll: zoom", 10)
	hint.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
	hbox.add_child(hint)


func _make_label(text: String, size: int = 13) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	return lbl


func _on_autosave_pressed() -> void:
	autosave_enabled = not autosave_enabled
	_update_autosave_btn()
	emit_signal("autosave_toggled", autosave_enabled)


func _update_autosave_btn() -> void:
	_autosave_btn.text = "Autosave: %s" % ("ON" if autosave_enabled else "OFF")


# ── Public API ─────────────────────────────────────────────────────────────────

func set_chunk_coords(cx: int, cy: int) -> void:
	_chunk_label.text = "Chunk: %d, %d" % [cx, cy]


func set_cell_coords(x: int, y: int) -> void:
	_cell_label.text = "Cell: %d, %d" % [x, y]


func set_unsaved(dirty: bool) -> void:
	_unsaved_dot.visible = dirty


func set_last_saved(time_str: String) -> void:
	_last_saved_label.text = "Last saved: " + time_str


func set_chunks_loaded(count: int) -> void:
	_chunks_label.text = "Chunks loaded: %d" % count
```

- [ ] **Step 2: Commit**

```bash
git add scripts/editor/editor_ui.gd
git commit -m "feat: EditorUI builds toolbar, palette panel, and status bar"
```

---

### Task 15: MapEditor root controller + scene file

**Files:**
- Create: `scripts/editor/map_editor.gd`
- Create: `scenes/map_editor.tscn`

`map_editor.gd` builds the entire scene tree in `_ready()`. The `.tscn` is a minimal stub pointing to the script.

- [ ] **Step 1: Create scenes/map_editor.tscn**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/editor/map_editor.gd" id="1_editor"]

[node name="MapEditor" type="Node2D"]
script = ExtResource("1_editor")
```

- [ ] **Step 2: Create scripts/editor/map_editor.gd**

```gdscript
extends Node2D

const MENU_SCENE  := "res://scenes/menu.tscn"
const LOAD_RADIUS := 1   ## Loads a (2×LOAD_RADIUS+1)² grid = 3×3 = 9 chunks

var _chunks:      Dictionary = {}   ## "cx_cy" → ChunkData
var _chunk_nodes: Dictionary = {}   ## "cx_cy" → ChunkEditorNode
var _dirty:       Dictionary = {}   ## "cx_cy" → bool

var _active_tool:       String = "terrain"
var _selected_terrain:  String = "grass.png"
var _selected_item:     int    = MapObject.Type.HERB
var _last_hover_key:    String = ""

var _camera:          EditorCamera
var _chunk_container: Node2D
var _editor_input:    EditorInput
var _ui:              EditorUI
var _autosave_timer:  Timer
var _confirm_dialog:  ConfirmationDialog


func _ready() -> void:
	_build_scene_tree()
	_load_initial_chunks()
	_connect_signals()
	_ui.set_chunks_loaded(_chunks.size())


func _build_scene_tree() -> void:
	_camera = EditorCamera.new()
	add_child(_camera)
	_camera.make_current()

	_chunk_container = Node2D.new()
	add_child(_chunk_container)

	_editor_input = EditorInput.new()
	add_child(_editor_input)

	var canvas := CanvasLayer.new()
	add_child(canvas)

	_ui = EditorUI.new()
	canvas.add_child(_ui)

	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Unsaved Changes"
	_confirm_dialog.add_button("Stay in Editor", true, "stay")
	canvas.add_child(_confirm_dialog)

	_autosave_timer = Timer.new()
	_autosave_timer.wait_time  = 60.0
	_autosave_timer.autostart  = true
	add_child(_autosave_timer)


func _load_initial_chunks() -> void:
	var player := SaveManager.load_player()
	var px: float = float(player.get("x", 0.0))
	var py: float = float(player.get("y", 0.0))
	var ccx := int(floor(px / ChunkData.CHUNK_PIXEL_SIZE))
	var ccy := int(floor(py / ChunkData.CHUNK_PIXEL_SIZE))

	for dy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			_try_load_chunk(ccx + dx, ccy + dy)

	_camera.position = Vector2(px, py)


func _try_load_chunk(cx: int, cy: int) -> void:
	var key := "%d_%d" % [cx, cy]
	if _chunks.has(key):
		return
	var data := ChunkPersistence.load_chunk(cx, cy)
	if data == null:
		return
	_chunks[key] = data
	var node := ChunkEditorNode.new()
	_chunk_container.add_child(node)
	node.initialize(data)
	_chunk_nodes[key] = node


func _process(_delta: float) -> void:
	_check_visible_chunks()


func _check_visible_chunks() -> void:
	var vp_size := get_viewport_rect().size
	var half    := vp_size / (2.0 * _camera.zoom.x)
	var view    := Rect2(_camera.position - half, vp_size / _camera.zoom.x)
	var min_cx  := int(floor(view.position.x / ChunkData.CHUNK_PIXEL_SIZE)) - 1
	var min_cy  := int(floor(view.position.y / ChunkData.CHUNK_PIXEL_SIZE)) - 1
	var max_cx  := int(ceil(view.end.x       / ChunkData.CHUNK_PIXEL_SIZE)) + 1
	var max_cy  := int(ceil(view.end.y       / ChunkData.CHUNK_PIXEL_SIZE)) + 1
	for cy in range(min_cy, max_cy + 1):
		for cx in range(min_cx, max_cx + 1):
			_try_load_chunk(cx, cy)


func _connect_signals() -> void:
	_editor_input.paint_cell.connect(_on_paint_cell)
	_editor_input.erase_cell.connect(_on_erase_cell)
	_editor_input.hover_cell.connect(_on_hover_cell)

	_ui.terrain_palette.terrain_selected.connect(_on_terrain_selected)
	_ui.item_palette.item_selected.connect(_on_item_selected)
	_ui.save_requested.connect(_do_save)
	_ui.autosave_toggled.connect(_on_autosave_toggled)
	_ui.back_requested.connect(_on_back_requested)

	_autosave_timer.timeout.connect(_on_autosave_tick)
	_confirm_dialog.confirmed.connect(_on_exit_save)
	_confirm_dialog.canceled.connect(_on_exit_discard)
	_confirm_dialog.custom_action.connect(func(_action: String): _confirm_dialog.hide())


func _on_paint_cell(cx: int, cy: int, lx: int, ly: int) -> void:
	var key  := "%d_%d" % [cx, cy]
	var data := _chunks.get(key) as ChunkData
	if data == null:
		return
	var cell := data.get_cell(lx, ly)
	if cell == null:
		return
	if _active_tool == "terrain":
		cell.terrain_type = _selected_terrain
		cell.is_obstacle  = not TileRegistry.is_passable(_selected_terrain)
	else:
		cell.add_object(_selected_item)
	_mark_dirty(key)
	(_chunk_nodes[key] as ChunkEditorNode).redraw_cell(lx, ly)


func _on_erase_cell(cx: int, cy: int, lx: int, ly: int) -> void:
	var key  := "%d_%d" % [cx, cy]
	var data := _chunks.get(key) as ChunkData
	if data == null:
		return
	var cell := data.get_cell(lx, ly)
	if cell == null or cell.objects.is_empty():
		return
	cell.objects.pop_back()
	_mark_dirty(key)
	(_chunk_nodes[key] as ChunkEditorNode).redraw_cell(lx, ly)


func _on_hover_cell(cx: int, cy: int, lx: int, ly: int) -> void:
	var key := "%d_%d" % [cx, cy]
	if _last_hover_key != key and _last_hover_key != "":
		var prev := _chunk_nodes.get(_last_hover_key) as ChunkEditorNode
		if prev:
			prev.clear_hover()
	_last_hover_key = key
	var node := _chunk_nodes.get(key) as ChunkEditorNode
	if node:
		node.set_hovered_cell(lx, ly)
	_ui.set_chunk_coords(cx, cy)
	_ui.set_cell_coords(lx, ly)


func _on_terrain_selected(filename: String) -> void:
	_selected_terrain = filename
	_active_tool      = "terrain"


func _on_item_selected(item_type: int) -> void:
	_selected_item = item_type
	_active_tool   = "item"


func _on_autosave_toggled(enabled: bool) -> void:
	if enabled:
		_autosave_timer.start()
	else:
		_autosave_timer.stop()


func _on_autosave_tick() -> void:
	if not _dirty.is_empty():
		_do_save()


func _do_save() -> void:
	for key in _dirty:
		ChunkPersistence.save(_chunks[key])
	_dirty.clear()
	_ui.set_unsaved(false)
	var t := Time.get_time_dict_from_system()
	_ui.set_last_saved("%02d:%02d:%02d" % [t.hour, t.minute, t.second])
	_ui.set_chunks_loaded(_chunks.size())


func _mark_dirty(key: String) -> void:
	_dirty[key] = true
	_ui.set_unsaved(true)


func _on_back_requested() -> void:
	if _dirty.is_empty():
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	_confirm_dialog.dialog_text = "You have unsaved changes."
	_confirm_dialog.ok_button_text     = "Save & Leave"
	_confirm_dialog.cancel_button_text = "Leave without saving"
	_confirm_dialog.popup_centered()


func _on_exit_save() -> void:
	_do_save()
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_exit_discard() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
```

- [ ] **Step 3: Commit**

```bash
git add scripts/editor/map_editor.gd scenes/map_editor.tscn
git commit -m "feat: MapEditor scene — Camera2D, chunk loading, painting, save, exit guard"
```

---

### Task 16: End-to-end verification

No new code. Run the editor and check each feature manually.

- [ ] **Step 1: Open game, start a new game, save some terrain**

Press F5 → New Game. Walk around a few seconds so some chunks get generated and saved. Quit.

- [ ] **Step 2: Open Map Editor from main menu**

Press F5 → Main Menu → "Map Editor". Expected:
- Editor opens without errors
- Terrain from the game session is visible in the correct positions
- Chunk border lines (yellow) separate the grid squares
- Right panel shows Terrain / Items tabs

- [ ] **Step 3: Paint terrain**

- Click a tile in the Terrain palette (e.g. `sand.png`)
- Left-click-drag across several cells on the map
- Expected: cells change to sand texture immediately

- [ ] **Step 4: Place and remove items**

- Switch to Items tab, select "Herb"
- Left-click a passable cell
- Expected: green dot appears on that cell
- Right-click the same cell
- Expected: dot disappears

- [ ] **Step 5: Save and verify persistence**

- Press Save button; "Last saved: HH:MM:SS" updates; unsaved dot disappears
- Click "← Menu" (no warning — not dirty)
- Open Map Editor again
- Expected: the painted terrain and items are still there

- [ ] **Step 6: Test exit guard**

- Paint one cell (makes editor dirty)
- Click "← Menu"
- Expected: ConfirmationDialog appears with "Save & Leave" / "Leave without saving" / "Stay in Editor"
- Click "Stay in Editor" → remain in editor
- Click "← Menu" → "Leave without saving" → return to menu without saving

- [ ] **Step 7: Test autosave**

- Enable Autosave (ON by default)
- Paint a cell
- Wait 60 s (or temporarily change `wait_time = 5.0` in the timer during testing)
- Expected: "Last saved" timestamp updates automatically

- [ ] **Step 8: Test pan and zoom**

- Middle-drag to pan → camera moves, UI stays fixed
- Scroll to zoom in/out → terrain scales

- [ ] **Step 9: Final commit**

```bash
git commit --allow-empty -m "chore: map editor end-to-end verified"
```
