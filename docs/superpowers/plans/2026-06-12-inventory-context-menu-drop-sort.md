# Inventory Context Menu, Drop & Sort — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Right-clicking an inventory slot shows a "Drop" context menu that removes the item from inventory and places it on the nearest free cell near the player; a Sort button sorts items A→Z by display name.

**Architecture:** The drop action flows through a new `drop_requested` signal from `InventoryUI` → `Avatar.drop_item` (wired in `Main`). Avatar delegates world placement to `World.drop_item_near`, which scans outward for the first passable empty cell and calls `ChunkNode.spawn_pickable_at` to materialise the item. The context menu is a single reusable `PanelContainer` built once in `_ready` and repositioned on each right-click.

**Tech Stack:** Godot 4.6 GDScript. No automated test framework — verification is manual (run the game).

---

## Files

| File | Change |
|---|---|
| `scripts/world/chunk_node.gd` | Add `spawn_pickable_at(item_type, lx, ly)` |
| `scripts/world/world.gd` | Add `get_chunk_node(coord)`, `drop_item_near(near, item_type)` |
| `scripts/actors/avatar.gd` | Add `drop_item(slot_index)` |
| `scripts/ui/inventory_ui.gd` | Add `drop_requested` signal, context menu, Sort button, slot `gui_input` wiring |
| `scripts/main.gd` | Connect `drop_requested` → `avatar.drop_item` |

---

## Task 1: ChunkNode — `spawn_pickable_at`

**Files:**
- Modify: `scripts/world/chunk_node.gd`

- [ ] **Step 1: Add the method**

Open `scripts/world/chunk_node.gd`. Add this method after `_spawn_pickables`:

```gdscript
## Spawn a single PickableNode for an item already added to _data.
## Called by World.drop_item_near after mutating the ChunkData.
func spawn_pickable_at(item_type: int, lx: int, ly: int) -> void:
	var node := PickableNode.new()
	node.position = Vector2((lx + 0.5) * CELL_SIZE, (ly + 0.5) * CELL_SIZE)
	add_child(node)
	node.initialize(item_type, lx, ly, _data)
```

- [ ] **Step 2: Verify the game still launches without errors**

Run the game (F5 in Godot editor). Walk around, open inventory with I. Confirm no errors in the Output panel. No behaviour change yet.

- [ ] **Step 3: Commit**

```
git add scripts/world/chunk_node.gd
git commit -m "feat: add ChunkNode.spawn_pickable_at for runtime item placement"
```

---

## Task 2: World — `get_chunk_node` and `drop_item_near`

**Files:**
- Modify: `scripts/world/world.gd`

- [ ] **Step 1: Add `get_chunk_node`**

In `scripts/world/world.gd`, add after the existing `get_cell_at` method:

```gdscript
## Returns the live ChunkNode for a loaded chunk, or null.
func get_chunk_node(coord: Vector2i) -> ChunkNode:
	return _nodes.get(coord, null)
```

- [ ] **Step 2: Add `drop_item_near`**

Add directly after `get_chunk_node`:

```gdscript
## Find the nearest passable, object-free cell within MAX_RADIUS of `near`,
## add item_type to its CellData, spawn a PickableNode, and return true.
## Returns false when no suitable cell is found.
func drop_item_near(near: Vector2, item_type: int) -> bool:
	const MAX_RADIUS := 8
	var origin := world_to_cell_coords(near)

	for radius in range(MAX_RADIUS + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				# Only check the outer ring at each radius step.
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var gc  := origin + Vector2i(dx, dy)
				var cc  := Vector2i(
					int(floor(float(gc.x) / CHUNK_SIZE)),
					int(floor(float(gc.y) / CHUNK_SIZE))
				)
				var chunk := get_chunk(cc)
				if chunk == null:
					continue
				var lx   := gc.x - cc.x * CHUNK_SIZE
				var ly   := gc.y - cc.y * CHUNK_SIZE
				var cell := chunk.get_cell(lx, ly)
				if cell == null or cell.is_obstacle or not cell.objects.is_empty():
					continue
				cell.add_object(item_type)
				var node := get_chunk_node(cc)
				if node != null:
					node.spawn_pickable_at(item_type, lx, ly)
				return true

	return false
```

- [ ] **Step 3: Verify the game launches without errors**

Run the game. Walk around. No errors in Output. No behaviour change yet.

- [ ] **Step 4: Commit**

```
git add scripts/world/world.gd
git commit -m "feat: add World.drop_item_near and get_chunk_node"
```

---

## Task 3: Avatar — `drop_item`

**Files:**
- Modify: `scripts/actors/avatar.gd`

- [ ] **Step 1: Add the method**

In `scripts/actors/avatar.gd`, add after `_try_pickup`:

```gdscript
## Called by Main when InventoryUI emits drop_requested(slot_index).
func drop_item(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= inventory.items.size():
		return
	var item_type := inventory.items[slot_index]
	if not _world.drop_item_near(position, item_type):
		return  # No free cell found; item stays in inventory.
	inventory.items.remove_at(slot_index)
	if _inventory_ui != null:
		_inventory_ui.notify_changed()
```

- [ ] **Step 2: Verify the game launches without errors**

Run the game. Open inventory. No errors. No behaviour change yet (signal not wired).

- [ ] **Step 3: Commit**

```
git add scripts/actors/avatar.gd
git commit -m "feat: add Avatar.drop_item"
```

---

## Task 4: InventoryUI — signal, context menu, Sort button

**Files:**
- Modify: `scripts/ui/inventory_ui.gd`

This task updates the UI in several steps. Keep the game runnable after each step.

**Pattern used for dismissal:** A fullscreen transparent `Button` backdrop sits between the inventory panel and the context menu in the CanvasLayer child order. When visible it catches any click that misses the context menu, calling `_close_context_menu`. This is the standard Godot pattern for popup dismissal and correctly handles clicks on the inventory panel itself (which would otherwise be absorbed by `MOUSE_FILTER_STOP` before reaching `_unhandled_input`).

### Step 4a — Declare signal and state fields

- [ ] **Step 1: Add signal and context-menu fields**

At the top of `scripts/ui/inventory_ui.gd`, after the existing `var _slot_labels` line, add:

```gdscript
signal drop_requested(slot_index: int)

var _context_backdrop:   Button         = null
var _context_menu:       PanelContainer = null
var _context_slot_index: int            = -1
```

- [ ] **Step 2: Verify (run game, no errors)**

### Step 4b — Build backdrop and context menu widget in `_ready`

- [ ] **Step 3: Append backdrop + context-menu construction at the end of `_ready`, just before the final `_center.visible = false` line**

```gdscript
	# ── Context menu backdrop (catches outside clicks) ────────────────────────
	_context_backdrop = Button.new()
	_context_backdrop.flat = true
	_context_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_context_backdrop.focus_mode = Control.FOCUS_NONE
	_context_backdrop.pressed.connect(_close_context_menu)
	_context_backdrop.visible = false
	add_child(_context_backdrop)   # added before _context_menu so it renders behind it

	# ── Context menu ──────────────────────────────────────────────────────────
	_context_menu = PanelContainer.new()
	_context_menu.custom_minimum_size = Vector2(120, 0)

	var cm_style := StyleBoxFlat.new()
	cm_style.bg_color                   = Color(0.08, 0.08, 0.13, 0.97)
	cm_style.border_width_left          = 1
	cm_style.border_width_right         = 1
	cm_style.border_width_top           = 1
	cm_style.border_width_bottom        = 1
	cm_style.border_color               = Color(0.40, 0.40, 0.55, 0.90)
	cm_style.corner_radius_top_left     = 4
	cm_style.corner_radius_top_right    = 4
	cm_style.corner_radius_bottom_left  = 4
	cm_style.corner_radius_bottom_right = 4
	cm_style.set_content_margin_all(4)
	_context_menu.add_theme_stylebox_override("panel", cm_style)

	var cm_vbox := VBoxContainer.new()
	cm_vbox.add_theme_constant_override("separation", 2)
	_context_menu.add_child(cm_vbox)

	var drop_btn := Button.new()
	drop_btn.text = "Drop"
	drop_btn.custom_minimum_size = Vector2(112, 28)
	drop_btn.add_theme_font_size_override("font_size", 13)
	drop_btn.pressed.connect(_on_drop_pressed)
	cm_vbox.add_child(drop_btn)

	_context_menu.visible = false
	add_child(_context_menu)   # added after backdrop so it renders in front
```

- [ ] **Step 4: Verify (run game, open inventory with I, no errors)**

### Step 4c — Wire slot `gui_input` and add helper methods

- [ ] **Step 5: Replace the slot-creation loop in `_ready`**

Find:
```gdscript
	for _i in range(ROWS * COLS):
		var slot_data := _make_slot()
		_slot_icons.append(slot_data[0] as TextureRect)
		_slot_labels.append(slot_data[1] as Label)
		grid.add_child(slot_data[2] as Control)
```

Replace with:
```gdscript
	for i in range(ROWS * COLS):
		var slot_data := _make_slot()
		var slot      := slot_data[2] as PanelContainer
		_slot_icons.append(slot_data[0] as TextureRect)
		_slot_labels.append(slot_data[1] as Label)
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		grid.add_child(slot)
```

- [ ] **Step 6: Add the four helper methods at the bottom of the file (before or after `_make_slot`)**

```gdscript
func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mbe := event as InputEventMouseButton
	if mbe.button_index == MOUSE_BUTTON_RIGHT and mbe.pressed:
		if _inventory == null or slot_index >= _inventory.items.size():
			return
		_context_slot_index = slot_index
		_show_context_menu(mbe.global_position)


func _show_context_menu(pos: Vector2) -> void:
	const MENU_W := 120.0
	const MENU_H :=  40.0
	var vp := get_viewport().get_visible_rect().size
	_context_menu.position = Vector2(
		clamp(pos.x, 0.0, vp.x - MENU_W),
		clamp(pos.y, 0.0, vp.y - MENU_H)
	)
	_context_backdrop.visible = true
	_context_menu.visible     = true


func _close_context_menu() -> void:
	_context_backdrop.visible = false
	_context_menu.visible     = false
	_context_slot_index       = -1


func _on_drop_pressed() -> void:
	var idx := _context_slot_index
	_close_context_menu()
	if idx >= 0:
		drop_requested.emit(idx)
```

- [ ] **Step 7: Update `_unhandled_input` to handle ESC for context menu**

Replace the entire `_unhandled_input` method with:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return

	if ke.keycode == KEY_ESCAPE:
		if _context_menu.visible:
			_close_context_menu()
			get_viewport().set_input_as_handled()
			return
		if _visible_flag:
			_visible_flag = false
			_center.visible = false
			get_viewport().set_input_as_handled()
	elif ke.keycode == KEY_I:
		_visible_flag = not _visible_flag
		_center.visible = _visible_flag
		if _visible_flag:
			_refresh()
		get_viewport().set_input_as_handled()
```

- [ ] **Step 8: Verify context menu**

Run the game. Pick up some items. Open inventory (I). Right-click a filled slot — a small "Drop" panel appears at the cursor. Right-click an empty slot — nothing happens. Click anywhere outside the "Drop" panel (including on another slot or on the inventory background) — menu dismisses. Press ESC with menu open — menu dismisses; press ESC again — inventory closes.

### Step 4d — Add Sort button to the header

- [ ] **Step 9: Replace the title label block in `_ready` with an HBox containing title + Sort**

Find:
```gdscript
	var title := Label.new()
	title.text = "INVENTORY  (I to close)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(title)
```

Replace with:
```gdscript
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "INVENTORY  (I to close)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var sort_btn := Button.new()
	sort_btn.text = "Sort"
	sort_btn.custom_minimum_size = Vector2(56, 0)
	sort_btn.add_theme_font_size_override("font_size", 13)
	sort_btn.pressed.connect(_on_sort_pressed)
	header.add_child(sort_btn)
```

- [ ] **Step 10: Add `_on_sort_pressed` method**

```gdscript
func _on_sort_pressed() -> void:
	if _inventory == null:
		return
	_inventory.items.sort_custom(
		func(a: int, b: int) -> bool:
			return PickableItemDef.get_display_name(a) < PickableItemDef.get_display_name(b)
	)
	_refresh()
```

- [ ] **Step 11: Verify Sort**

Run the game. Pick up several different item types. Open inventory. Click Sort — items should reorder A→Z: Coin, Crystal, Feather, Herb, Potion. Click Sort again — order unchanged. No errors.

- [ ] **Step 12: Commit**

```
git add scripts/ui/inventory_ui.gd
git commit -m "feat: inventory context menu with Drop action and Sort button"
```

---

## Task 5: Main — wire `drop_requested` signal

**Files:**
- Modify: `scripts/main.gd`

- [ ] **Step 1: Connect the signal in `_ready`**

In `scripts/main.gd`, inside `_ready`, add this line immediately after `_avatar.setup(...)`:

```gdscript
	_inventory_ui.drop_requested.connect(_avatar.drop_item)
```

The full `_ready` setup block should now look like:

```gdscript
func _ready() -> void:
	_fog_manager.setup(_world)
	_avatar.inventory = SaveManager.load_inventory()
	_avatar.setup(_world, _fog_manager, _inventory_ui)
	_inventory_ui.drop_requested.connect(_avatar.drop_item)   # ← new
	_debug.setup(_world, _fog_manager, _avatar)
	_pause_menu.setup(_fog_manager, _avatar)
	_inventory_ui.setup(_avatar.inventory)
	_pickup_hint.setup(_avatar)
	_world.start()
	# ... rest unchanged
```

- [ ] **Step 2: Full end-to-end verification**

Run the game. Walk around and pick up items. Open inventory (I). Right-click a Herb slot. Click "Drop". The item should:
  1. Disappear from the inventory slot
  2. Appear on the ground near the player as a sprite
  3. Be pick-up-able again with E

Also verify: dropping when standing on water still works (item lands on nearest land cell). Inventory count decrements by 1 after drop.

- [ ] **Step 3: Final commit**

```
git add scripts/main.gd
git commit -m "feat: wire inventory drop_requested signal to avatar"
```

---

## Done

All five tasks complete. The feature is fully functional:
- Right-click occupied slot → context menu with Drop
- Drop places item on nearest free ground cell
- Sort button sorts A→Z
