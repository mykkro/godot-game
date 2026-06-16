# Belt Inventory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 5-slot always-visible belt inventory at the bottom of the screen, mapped to keys 1–5, supporting health and mana potions with floating heal/mana feedback.

**Architecture:** A new `Belt` data class (mirroring `Inventory`) lives on Avatar alongside the existing inventory. `BeltUI` is a always-visible `CanvasLayer` anchored bottom-centre. Keys 1–5 call `use_belt_slot()` on Avatar, which consumes from Belt and emits `belt_changed` so BeltUI refreshes. When the inventory is open, belt slots also act as drag-and-drop targets (restricted to useable items). Two new item types — `HEALTH_POTION` and `MANA_POTION` — are added, with ravenmore sprites and a new `PickableItemDef.is_useable()` gate.

**Tech Stack:** Godot 4 (GDScript), existing TextureCache / PickableItemDef / SaveManager patterns.

---

## File Map

| Action | File |
|---|---|
| Modify | `scripts/objects/map_object.gd` |
| Modify | `scripts/objects/pickable_item_def.gd` |
| **Create** | `scripts/inventory/belt.gd` |
| Modify | `scripts/utils/save_manager.gd` |
| Modify | `scripts/actors/avatar.gd` |
| **Create** | `scripts/ui/belt_ui.gd` |
| Modify | `scripts/ui/inventory_ui.gd` |
| Modify | `scripts/main.gd` |

*(No `.tscn` file needed — BeltUI builds itself in code like every other UI in this project.)*

---

## Task 1: Add HEALTH_POTION and MANA_POTION item types

**Files:**
- Modify: `scripts/objects/map_object.gd`
- Modify: `scripts/objects/pickable_item_def.gd`

- [ ] **Step 1: Add the two new enum values to MapObject.Type**

  Open `scripts/objects/map_object.gd`. The last enum value is `MAGIC_CRYSTAL = 237`. Append immediately after it (before the closing `}`):

  ```gdscript
  ## Potions — useable consumables.
  HEALTH_POTION = 238,
  MANA_POTION   = 239,
  ```

- [ ] **Step 2: Add display names in MapObject.get_display_name()**

  In `scripts/objects/map_object.gd`, find the `get_display_name` match block and add before the closing `_: return "Unknown"` or at the end of the match body:

  ```gdscript
  Type.HEALTH_POTION: return "Health Potion"
  Type.MANA_POTION:   return "Mana Potion"
  ```

- [ ] **Step 3: Add ravenmore textures in PickableItemDef._ravenmore_file()**

  Open `scripts/objects/pickable_item_def.gd`. In `_ravenmore_file()`, add two cases before `return ""`:

  ```gdscript
  MapObject.Type.HEALTH_POTION: return "potionRed.png"
  MapObject.Type.MANA_POTION:   return "potionBlue.png"
  ```

- [ ] **Step 4: Add stack size in PickableItemDef.max_stack_size()**

  In `max_stack_size()`, in the `# Stack 16` branch (the one with `MapObject.Type.FEATHER`), append to the line continuation:

  ```gdscript
  MapObject.Type.HEALTH_POTION, MapObject.Type.MANA_POTION, \
  ```

  Place it immediately before the `: return 16` line.

- [ ] **Step 5: Add is_useable() static method to PickableItemDef**

  Append this method to `scripts/objects/pickable_item_def.gd` (after `is_pickable`):

  ```gdscript
  ## Returns true when an item can be placed in the belt and used directly.
  static func is_useable(obj_type: int) -> bool:
  	return obj_type == MapObject.Type.HEALTH_POTION \
  		or obj_type == MapObject.Type.MANA_POTION
  ```

- [ ] **Step 6: Verify in-editor**

  Run the game. Open the console or add a temp print to confirm:
  - `PickableItemDef.get_display_name(238)` → `"Health Potion"`
  - `PickableItemDef.get_display_name(239)` → `"Mana Potion"`
  - `PickableItemDef.is_useable(238)` → `true`
  - `PickableItemDef.is_useable(5)` (POTION) → `false`

- [ ] **Step 7: Commit**

  ```bash
  git add scripts/objects/map_object.gd scripts/objects/pickable_item_def.gd
  git commit -m "feat: add HEALTH_POTION and MANA_POTION item types with is_useable gate"
  ```

---

## Task 2: Belt data class

**Files:**
- Create: `scripts/inventory/belt.gd`

- [ ] **Step 1: Create the file**

  Create `scripts/inventory/belt.gd` with this content:

  ```gdscript
  class_name Belt

  const SLOT_COUNT := 5

  ## Each element: { "type": int, "count": int } or null for empty.
  var slots: Array = []

  signal belt_changed


  func _init() -> void:
  	slots.resize(SLOT_COUNT)
  	for i in SLOT_COUNT:
  		slots[i] = null


  func has_item(index: int) -> bool:
  	return slots[index] != null


  func get_type(index: int) -> int:
  	if slots[index] == null:
  		return -1
  	return int(slots[index]["type"])


  func get_count(index: int) -> int:
  	if slots[index] == null:
  		return 0
  	return int(slots[index]["count"])


  func set_slot(index: int, item_type: int, count: int) -> void:
  	slots[index] = {"type": item_type, "count": count}
  	belt_changed.emit()


  func clear_slot(index: int) -> void:
  	slots[index] = null
  	belt_changed.emit()


  ## Consume one item from slot. Returns the item type consumed, or -1 if empty.
  func consume(index: int) -> int:
  	if slots[index] == null:
  		return -1
  	var item_type: int = int(slots[index]["type"])
  	slots[index]["count"] = int(slots[index]["count"]) - 1
  	if int(slots[index]["count"]) <= 0:
  		slots[index] = null
  	belt_changed.emit()
  	return item_type


  func to_dict() -> Dictionary:
  	var arr: Array = []
  	for s in slots:
  		if s == null:
  			arr.append(null)
  		else:
  			arr.append({"type": int(s["type"]), "count": int(s["count"])})
  	return {"slots": arr}


  static func from_dict(data: Dictionary) -> Belt:
  	var b := Belt.new()
  	var arr: Array = data.get("slots", [])
  	for i in mini(arr.size(), Belt.SLOT_COUNT):
  		var v: Variant = arr[i]
  		if v is Dictionary:
  			b.slots[i] = {
  				"type":  int((v as Dictionary).get("type",  0)),
  				"count": int((v as Dictionary).get("count", 1)),
  			}
  	return b
  ```

- [ ] **Step 2: Verify parsing with a quick sanity check**

  In `main.gd` `_ready()` temporarily add (remove after):
  ```gdscript
  var b := Belt.new()
  b.set_slot(0, MapObject.Type.HEALTH_POTION, 2)
  print(b.get_display_name_test())  # can't call, just do:
  print(b.get_type(0), " count=", b.get_count(0))
  var d := b.to_dict()
  var b2 := Belt.from_dict(d)
  print(b2.get_type(0), " count=", b2.get_count(0))
  ```
  Expected output: `238 count=2` twice. Remove the temp code.

- [ ] **Step 3: Commit**

  ```bash
  git add scripts/inventory/belt.gd
  git commit -m "feat: add Belt data class with 5 fixed slots and serialisation"
  ```

---

## Task 3: Belt save/load

**Files:**
- Modify: `scripts/utils/save_manager.gd`

- [ ] **Step 1: Add belt file constant**

  In `scripts/utils/save_manager.gd`, after `const STATS_FILE := "user://stats.json"` add:

  ```gdscript
  const BELT_FILE := "user://belt.json"
  ```

- [ ] **Step 2: Add save_belt and load_belt methods**

  Append to `scripts/utils/save_manager.gd`:

  ```gdscript
  static func save_belt(belt: Belt) -> void:
  	var file := FileAccess.open(BELT_FILE, FileAccess.WRITE)
  	if file == null:
  		push_error("SaveManager: cannot write belt save (error %d)" \
  				% FileAccess.get_open_error())
  		return
  	file.store_string(JSON.stringify(belt.to_dict()))
  	file.close()


  static func load_belt() -> Belt:
  	if not FileAccess.file_exists(BELT_FILE):
  		return Belt.new()
  	var file := FileAccess.open(BELT_FILE, FileAccess.READ)
  	if file == null:
  		return Belt.new()
  	var text := file.get_as_text()
  	file.close()
  	var json := JSON.new()
  	if json.parse(text) != OK:
  		push_error("SaveManager: failed to parse belt save")
  		return Belt.new()
  	return Belt.from_dict(json.data as Dictionary)
  ```

- [ ] **Step 3: Include BELT_FILE in wipe()**

  In the `wipe()` method, find the line with the file path list:
  ```gdscript
  for path in [PLAYER_FILE, INVENTORY_FILE, NPCS_FILE, ...]:
  ```
  Add `BELT_FILE` to the array.

- [ ] **Step 4: Commit**

  ```bash
  git add scripts/utils/save_manager.gd
  git commit -m "feat: add belt save/load to SaveManager"
  ```

---

## Task 4: Avatar belt, key input, and item effects

**Files:**
- Modify: `scripts/actors/avatar.gd`

- [ ] **Step 1: Add belt field**

  In `scripts/actors/avatar.gd`, after `var inventory: Inventory = Inventory.new()` add:

  ```gdscript
  var belt: Belt = Belt.new()
  ```

- [ ] **Step 2: Add apply_item_effect() method**

  Append to `avatar.gd`:

  ```gdscript
  func apply_item_effect(item_type: int) -> void:
  	match item_type:
  		MapObject.Type.HEALTH_POTION:
  			stats.heal(20)
  		MapObject.Type.MANA_POTION:
  			stats.current_mana = mini(stats.max_mana, stats.current_mana + 20)
  			stats.changed.emit()
  ```

- [ ] **Step 3: Add use_belt_slot() method**

  Append to `avatar.gd`:

  ```gdscript
  func use_belt_slot(index: int) -> void:
  	var item_type := belt.consume(index)
  	if item_type < 0:
  		return
  	apply_item_effect(item_type)
  	_show_use_feedback(item_type)
  ```

- [ ] **Step 4: Wire keys 1–5 in _unhandled_input**

  In `_unhandled_input`, after the existing `KEY_CTRL` branch, add:

  ```gdscript
  elif ke.keycode >= KEY_1 and ke.keycode <= KEY_5 and ke.pressed and not ke.echo:
  	if not get_tree().paused:
  		use_belt_slot(ke.keycode - KEY_1)
  		get_viewport().set_input_as_handled()
  ```

- [ ] **Step 5: Add starting belt items (new characters only)**

  This code goes in `main.gd` (Task 9), not in avatar._ready(), because main.gd controls the "is this a new game?" guard. Skip here — handled in Task 9.

- [ ] **Step 6: Verify key input works (smoke test)**

  Run the game. Temporarily add `belt.set_slot(0, MapObject.Type.HEALTH_POTION, 2)` in main after loading belt, then press key `1`. Add a print in `use_belt_slot` to confirm it fires. Remove temp code after.

- [ ] **Step 7: Commit**

  ```bash
  git add scripts/actors/avatar.gd
  git commit -m "feat: add belt field, use_belt_slot(), apply_item_effect(), key 1-5 input to Avatar"
  ```

---

## Task 5: FloatingText feedback

**Files:**
- Modify: `scripts/actors/avatar.gd`

- [ ] **Step 1: Add _floating_text Label child in _ready()**

  In `avatar.gd` class body, add a field:

  ```gdscript
  var _floating_text: Label = null
  ```

  In `_ready()`, after the sound players are added, append:

  ```gdscript
  _floating_text = Label.new()
  _floating_text.z_index = 10
  _floating_text.visible = false
  _floating_text.add_theme_font_size_override("font_size", 14)
  _floating_text.add_theme_constant_override("shadow_offset_x", 1)
  _floating_text.add_theme_constant_override("shadow_offset_y", 1)
  _floating_text.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
  add_child(_floating_text)
  ```

- [ ] **Step 2: Add _show_use_feedback() method**

  Append to `avatar.gd`:

  ```gdscript
  func _show_use_feedback(item_type: int) -> void:
  	if _floating_text == null:
  		return
  	match item_type:
  		MapObject.Type.HEALTH_POTION:
  			_floating_text.text = "+20 HP"
  			_floating_text.add_theme_color_override("font_color", Color(0.306, 0.858, 0.416))
  		MapObject.Type.MANA_POTION:
  			_floating_text.text = "+20 Mana"
  			_floating_text.add_theme_color_override("font_color", Color(0.204, 0.596, 0.859))
  		_:
  			return
  	_floating_text.position = Vector2(-20.0, -60.0)
  	_floating_text.modulate = Color(1, 1, 1, 1)
  	_floating_text.visible  = true

  	var tw := create_tween()
  	tw.set_parallel(true)
  	tw.tween_property(_floating_text, "position:y", -90.0, 0.7)
  	tw.tween_property(_floating_text, "modulate:a",  0.0,  0.7)
  	tw.finished.connect(func() -> void: _floating_text.visible = false, CONNECT_ONE_SHOT)
  ```

- [ ] **Step 3: Verify feedback**

  Run the game. With a health potion in belt slot 0, press `1`. "+20 HP" should rise from the avatar in green and fade over ~0.7 seconds. HP bar in HUD should also update.

- [ ] **Step 4: Commit**

  ```bash
  git add scripts/actors/avatar.gd
  git commit -m "feat: add FloatingText feedback for belt item use"
  ```

---

## Task 6: BeltUI

**Files:**
- Create: `scripts/ui/belt_ui.gd`

- [ ] **Step 1: Create belt_ui.gd**

  Create `scripts/ui/belt_ui.gd`:

  ```gdscript
  class_name BeltUI
  extends CanvasLayer

  const SLOT_SIZE := 44
  const SLOT_GAP  := 6

  var _belt:      Belt      = null
  var _inventory: Inventory = null

  var _slot_panels: Array = []   # Array of PanelContainer
  var _slot_icons:  Array = []   # Array of TextureRect
  var _slot_badges: Array = []   # Array of Label (stack count)


  ## Call from main after belt and inventory are loaded.
  func setup(belt: Belt, inventory: Inventory) -> void:
  	_belt      = belt
  	_inventory = inventory
  	belt.belt_changed.connect(_refresh)
  	_refresh()


  func _ready() -> void:
  	layer = 60   # below InventoryUI (layer 70) so inventory draws on top

  	var anchor := Control.new()
  	anchor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
  	anchor.custom_minimum_size = Vector2(0, SLOT_SIZE + 16)
  	add_child(anchor)

  	var hbox := HBoxContainer.new()
  	hbox.add_theme_constant_override("separation", SLOT_GAP)
  	hbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
  	hbox.offset_top    = -(SLOT_SIZE + 20)
  	hbox.offset_bottom = -8
  	anchor.add_child(hbox)

  	# Outer pill background.
  	var pill := PanelContainer.new()
  	var pill_style := StyleBoxFlat.new()
  	pill_style.bg_color                   = Color(0.0, 0.0, 0.0, 0.70)
  	pill_style.border_width_left          = 1
  	pill_style.border_width_right         = 1
  	pill_style.border_width_top           = 1
  	pill_style.border_width_bottom        = 1
  	pill_style.border_color               = Color(0.33, 0.33, 0.33, 0.9)
  	pill_style.corner_radius_top_left     = 8
  	pill_style.corner_radius_top_right    = 8
  	pill_style.corner_radius_bottom_left  = 8
  	pill_style.corner_radius_bottom_right = 8
  	pill_style.set_content_margin_all(6)
  	pill.add_theme_stylebox_override("panel", pill_style)
  	hbox.add_child(pill)

  	var inner_hbox := HBoxContainer.new()
  	inner_hbox.add_theme_constant_override("separation", SLOT_GAP)
  	pill.add_child(inner_hbox)

  	for i in Belt.SLOT_COUNT:
  		var slot_data := _make_slot(i)
  		_slot_panels.append(slot_data[0])
  		_slot_icons.append(slot_data[1])
  		_slot_badges.append(slot_data[2])
  		inner_hbox.add_child(slot_data[0])


  func _make_slot(index: int) -> Array:
  	var slot := PanelContainer.new()
  	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

  	var bg := StyleBoxFlat.new()
  	bg.bg_color          = Color(0.10, 0.10, 0.10, 0.90)
  	bg.border_width_left = 1;  bg.border_width_right  = 1
  	bg.border_width_top  = 1;  bg.border_width_bottom = 1
  	bg.border_color      = Color(0.26, 0.26, 0.26, 0.8)
  	bg.corner_radius_top_left     = 3
  	bg.corner_radius_top_right    = 3
  	bg.corner_radius_bottom_left  = 3
  	bg.corner_radius_bottom_right = 3
  	slot.add_theme_stylebox_override("panel", bg)

  	# Icon.
  	var icon_wrap := Control.new()
  	icon_wrap.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
  	icon_wrap.mouse_filter        = Control.MOUSE_FILTER_IGNORE
  	slot.add_child(icon_wrap)

  	var icon := TextureRect.new()
  	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  	icon.expand_mode    = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
  	icon.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
  	icon.mouse_filter   = Control.MOUSE_FILTER_IGNORE
  	icon_wrap.add_child(icon)

  	# Key label (top-left).
  	var key_lbl := Label.new()
  	key_lbl.text = str(index + 1)
  	key_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
  	key_lbl.offset_left   = 2
  	key_lbl.offset_top    = 1
  	key_lbl.offset_right  = 14
  	key_lbl.offset_bottom = 12
  	key_lbl.add_theme_font_size_override("font_size", 9)
  	key_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
  	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
  	icon_wrap.add_child(key_lbl)

  	# Stack count badge (bottom-right).
  	var badge := Label.new()
  	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
  	badge.offset_left   = -28
  	badge.offset_top    = -13
  	badge.offset_right  = -2
  	badge.offset_bottom = -1
  	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
  	badge.add_theme_font_size_override("font_size", 10)
  	badge.add_theme_color_override("font_color",        Color(1.0, 1.0, 0.65))
  	badge.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
  	badge.add_theme_constant_override("shadow_offset_x", 1)
  	badge.add_theme_constant_override("shadow_offset_y", 1)
  	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
  	badge.visible = false
  	icon_wrap.add_child(badge)

  	return [slot, icon, badge]


  func _refresh() -> void:
  	if _belt == null:
  		return
  	for i in Belt.SLOT_COUNT:
  		var icon  := _slot_icons[i]  as TextureRect
  		var badge := _slot_badges[i] as Label
  		if _belt.has_item(i):
  			icon.texture = PickableItemDef.get_texture(_belt.get_type(i))
  			var cnt := _belt.get_count(i)
  			if cnt > 1:
  				badge.text    = str(cnt)
  				badge.visible = true
  			else:
  				badge.visible = false
  		else:
  			icon.texture  = null
  			badge.visible = false
  ```

- [ ] **Step 2: Commit skeleton (before drag wiring)**

  ```bash
  git add scripts/ui/belt_ui.gd
  git commit -m "feat: add BeltUI always-visible 5-slot belt at bottom of screen"
  ```

---

## Task 7: Inventory drag ↔ belt

**Files:**
- Modify: `scripts/ui/inventory_ui.gd`
- Modify: `scripts/ui/belt_ui.gd`

### Part A — Inventory → Belt (drag from inventory onto a belt slot)

- [ ] **Step 1: Give BeltUI a reference to InventoryUI's inventory and set up belt slot drag forwarding**

  In `belt_ui.gd`, modify `_make_slot` to call a new `_setup_slot_drag` after building the slot. Add `_setup_slot_drag` below `_make_slot`:

  ```gdscript
  func _setup_slot_drag(slot: PanelContainer, index: int) -> void:
  	slot.set_drag_forwarding(
  		# get_drag_data — start drag when belt slot has an item.
  		func(_pos: Vector2) -> Variant:
  			if _belt == null or not _belt.has_item(index):
  				return null
  			var item_type := _belt.get_type(index)
  			var preview := TextureRect.new()
  			preview.texture             = PickableItemDef.get_texture(item_type)
  			preview.custom_minimum_size = Vector2(44, 44)
  			preview.expand_mode         = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
  			preview.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  			preview.texture_filter      = CanvasItem.TEXTURE_FILTER_NEAREST
  			slot.set_drag_preview(preview)
  			return {"belt_src_slot": index},

  		# can_drop_data — accept inventory items that are useable.
  		func(_pos: Vector2, data: Variant) -> bool:
  			if not (data is Dictionary):
  				return false
  			var d := data as Dictionary
  			if d.has("inv_src_slot") and _inventory != null:
  				var src: int = int(d["inv_src_slot"])
  				if src >= _inventory.count():
  					return false
  				return PickableItemDef.is_useable(_inventory.get_type(src))
  			return false,

  		# drop_data — move inventory item into this belt slot.
  		func(_pos: Vector2, data: Variant) -> void:
  			if _belt == null or _inventory == null:
  				return
  			var d := data as Dictionary
  			if not d.has("inv_src_slot"):
  				return
  			var src: int = int(d["inv_src_slot"])
  			if src >= _inventory.count():
  				return
  			var item_type  := _inventory.get_type(src)
  			var item_count := _inventory.get_count(src)
  			if not PickableItemDef.is_useable(item_type):
  				return
  			# If same type already in belt slot: merge (capped at max stack).
  			if _belt.has_item(index) and _belt.get_type(index) == item_type:
  				var max_st   := PickableItemDef.max_stack_size(item_type)
  				var existing := _belt.get_count(index)
  				var space    := max_st - existing
  				if space <= 0:
  					return
  				var move := mini(item_count, space)
  				_belt.set_slot(index, item_type, existing + move)
  				_inventory.remove_from_slot(src, move)
  			elif not _belt.has_item(index):
  				# Empty belt slot: move entire inventory stack.
  				_belt.set_slot(index, item_type, item_count)
  				_inventory.remove_from_slot(src, item_count)
  			else:
  				# Different item in belt slot: swap if belt item is also useable.
  				var belt_type  := _belt.get_type(index)
  				var belt_count := _belt.get_count(index)
  				_belt.set_slot(index, item_type, item_count)
  				_inventory.remove_from_slot(src, item_count)
  				# Belt item goes back to inventory.
  				for _i in range(belt_count):
  					_inventory.add(belt_type)
  			_inventory_ui_ref.notify_changed()
  	)
  ```

  Also add a field at the top of `belt_ui.gd`:

  ```gdscript
  var _inventory_ui_ref: InventoryUI = null
  ```

  And update `setup()` to accept it and call `_setup_slot_drag`:

  ```gdscript
  func setup(belt: Belt, inventory: Inventory, inv_ui: InventoryUI) -> void:
  	_belt             = belt
  	_inventory        = inventory
  	_inventory_ui_ref = inv_ui
  	belt.belt_changed.connect(_refresh)
  	_refresh()
  ```

  Finally, at the end of `_make_slot`, before `return [slot, icon, badge]`, add:

  ```gdscript
  _setup_slot_drag(slot, index)
  ```

  But since `_setup_slot_drag` is defined after `_make_slot`, and `_make_slot` is called from `_ready`, this is fine.

  > **Note:** Move the `_setup_slot_drag` call to after the slot is added to the tree (put it in _ready after `inner_hbox.add_child(slot_data[0])`):

  In `_ready()`, change the loop to:

  ```gdscript
  for i in Belt.SLOT_COUNT:
  	var slot_data := _make_slot(i)
  	_slot_panels.append(slot_data[0])
  	_slot_icons.append(slot_data[1])
  	_slot_badges.append(slot_data[2])
  	inner_hbox.add_child(slot_data[0])
  	_setup_slot_drag(slot_data[0] as PanelContainer, i)
  ```

### Part B — Belt → Inventory (drag from belt slot into an inventory slot)

- [ ] **Step 2: Accept belt_src_slot in InventoryUI's existing drag handlers**

  In `scripts/ui/inventory_ui.gd`, add a field at the top:

  ```gdscript
  var _belt: Belt = null
  ```

  Add a method:

  ```gdscript
  func setup_belt(belt: Belt) -> void:
  	_belt = belt
  ```

  In `_setup_slot_drag`, the `can_drop_data` lambda currently returns:

  ```gdscript
  return src != slot_index
  ```

  Replace the full `can_drop_data` lambda with:

  ```gdscript
  func(_pos: Vector2, data: Variant) -> bool:
  	if not (data is Dictionary):
  		return false
  	var d := data as Dictionary
  	if d.has("inv_src_slot"):
  		return int(d["inv_src_slot"]) != slot_index
  	if d.has("belt_src_slot"):
  		return _belt != null and _belt.has_item(int(d["belt_src_slot"]))
  	return false,
  ```

  Then in the `drop_data` lambda, before the existing inventory move logic, add handling for belt source. Replace the entire `drop_data` lambda with:

  ```gdscript
  func(_pos: Vector2, data: Variant) -> void:
  	if _inventory == null:
  		return
  	var d := data as Dictionary

  	# ── Belt → Inventory ──────────────────────────────────────────
  	if d.has("belt_src_slot") and _belt != null:
  		var belt_idx   := int(d["belt_src_slot"])
  		var item_type  := _belt.get_type(belt_idx)
  		var item_count := _belt.get_count(belt_idx)
  		var dst: int   := slot_index
  		if dst < _inventory.count():
  			var dst_type  := _inventory.get_type(dst)
  			var dst_count := _inventory.get_count(dst)
  			if dst_type == item_type:
  				# Merge same type.
  				var max_st := PickableItemDef.max_stack_size(item_type)
  				var space  := max_st - dst_count
  				var move   := mini(item_count, space)
  				if move > 0:
  					_inventory.items[dst]["count"] += move
  					if move >= item_count:
  						_belt.clear_slot(belt_idx)
  					else:
  						_belt.set_slot(belt_idx, item_type, item_count - move)
  			elif PickableItemDef.is_useable(dst_type):
  				# Swap: put inv item into belt, belt item into inv slot.
  				_inventory.items[dst] = {"type": item_type, "count": item_count}
  				_belt.set_slot(belt_idx, dst_type, dst_count)
  			else:
  				# Non-useable inv item can't go into belt — move belt to end of inv.
  				for _i in range(item_count):
  					_inventory.add(item_type)
  				_belt.clear_slot(belt_idx)
  		else:
  			# Drop into empty slot at end of inventory.
  			for _i in range(item_count):
  				_inventory.add(item_type)
  			_belt.clear_slot(belt_idx)
  		_refresh()
  		return

  	# ── Inventory → Inventory (existing logic) ────────────────────
  	var src: int = int(d["inv_src_slot"])
  	var dst: int = slot_index
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
  	_refresh()
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add scripts/ui/belt_ui.gd scripts/ui/inventory_ui.gd
  git commit -m "feat: wire drag-and-drop between belt and inventory (useable-only filter)"
  ```

---

## Task 8: Inventory context menu "Use"

**Files:**
- Modify: `scripts/ui/inventory_ui.gd`

- [ ] **Step 1: Add _belt reference for use action**

  Already added in Task 7. Nothing extra needed.

- [ ] **Step 2: Add _cm_btn_use Button field**

  In `inventory_ui.gd` class body, after the existing `_cm_btn_drop_all` field, add:

  ```gdscript
  var _cm_btn_use: Button = null
  ```

- [ ] **Step 3: Create and insert the "Use" button in _ready()**

  In `_ready()`, find where `_cm_btn_split` is created:

  ```gdscript
  _cm_btn_split     = _make_cm_button("Split",     _on_split_pressed)
  ```

  Before that line, add:

  ```gdscript
  _cm_btn_use = _make_cm_button("Use", _on_use_pressed)
  cm_vbox.add_child(_cm_btn_use)
  ```

- [ ] **Step 4: Show/hide "Use" in _show_context_menu()**

  In `_show_context_menu()`, after the line `_cm_btn_split.visible = item_count > 1`, add:

  ```gdscript
  var item_type := _inventory.get_type(_context_slot_index) \
  		if _context_slot_index < _inventory.count() else -1
  _cm_btn_use.visible = PickableItemDef.is_useable(item_type)
  ```

- [ ] **Step 5: Add _on_use_pressed handler**

  Append to `inventory_ui.gd`:

  ```gdscript
  func _on_use_pressed() -> void:
  	var idx := _context_slot_index
  	_close_context_menu()
  	if idx < 0 or _inventory == null:
  		return
  	if idx >= _inventory.count():
  		return
  	var item_type := _inventory.get_type(idx)
  	if not PickableItemDef.is_useable(item_type):
  		return
  	_inventory.remove_from_slot(idx, 1)
  	use_from_inventory.emit(item_type)
  	_refresh()
  ```

- [ ] **Step 6: Add use_from_inventory signal**

  At the top of `inventory_ui.gd`, after `signal drop_requested(...)`, add:

  ```gdscript
  signal use_from_inventory(item_type: int)
  ```

- [ ] **Step 7: Commit**

  ```bash
  git add scripts/ui/inventory_ui.gd
  git commit -m "feat: add 'Use' context menu option in InventoryUI for useable items"
  ```

---

## Task 9: Wire everything in main

**Files:**
- Modify: `scripts/main.gd`

- [ ] **Step 1: Declare _belt_ui field**

  In `scripts/main.gd`, after `var _perk_pick_ui: PerkPickUI = null` add:

  ```gdscript
  var _belt_ui: BeltUI = null
  ```

- [ ] **Step 2: Load belt from save in _ready()**

  In `_ready()`, find:

  ```gdscript
  _avatar.inventory = SaveManager.load_inventory()
  _avatar.perks     = SaveManager.load_perks()
  _avatar.stats     = SaveManager.load_stats()
  ```

  Add after:

  ```gdscript
  _avatar.belt = SaveManager.load_belt()
  ```

- [ ] **Step 3: Add starting belt items for new characters**

  Find the existing new-game inventory initialisation block:

  ```gdscript
  if _avatar.inventory.count() == 0:
  	for entry in [
  		...
  	]:
  		_avatar.inventory.items.append({"type": entry[0], "count": entry[1]})
  ```

  Immediately after the closing `]` of that block, add:

  ```gdscript
  if not _avatar.belt.has_item(0) and not _avatar.belt.has_item(1):
  	_avatar.belt.set_slot(0, MapObject.Type.HEALTH_POTION, 2)
  	_avatar.belt.set_slot(1, MapObject.Type.MANA_POTION,   2)
  ```

- [ ] **Step 4: Create and set up BeltUI**

  In `_ready()`, after `_perk_pick_ui.perk_picked.connect(_on_perk_picked)`, add:

  ```gdscript
  _belt_ui = BeltUI.new()
  add_child(_belt_ui)
  ```

- [ ] **Step 5: Call setup on BeltUI and InventoryUI after avatar is wired**

  Find:

  ```gdscript
  _inventory_ui.setup(_avatar.inventory)
  ```

  Replace with:

  ```gdscript
  _inventory_ui.setup(_avatar.inventory)
  _inventory_ui.setup_belt(_avatar.belt)
  _belt_ui.setup(_avatar.belt, _avatar.inventory, _inventory_ui)
  ```

- [ ] **Step 6: Wire use_from_inventory signal**

  After `_inventory_ui.drop_requested.connect(_avatar.drop_item)`, add:

  ```gdscript
  _inventory_ui.use_from_inventory.connect(func(item_type: int) -> void:
  	_avatar.apply_item_effect(item_type)
  	_avatar._show_use_feedback(item_type)
  )
  ```

  > **Note:** `_show_use_feedback` is a private method on Avatar — change it to `show_use_feedback` (remove the leading underscore) in `avatar.gd` so it can be called from main.

- [ ] **Step 7: Save belt on quit / autosave**

  Search `main.gd` for all calls to `SaveManager.save_inventory`. For each one, add a matching `SaveManager.save_belt(_avatar.belt)` call directly after it. This ensures belt is saved whenever inventory is saved.

- [ ] **Step 8: Verify full flow**

  Run the game:
  1. Belt shows at bottom with 2 health potions in slot 1 and 2 mana potions in slot 2.
  2. Press `1` — "+20 HP" floats up in green, HP bar updates, potion count drops to 1.
  3. Press `2` — "+20 Mana" floats up in blue, mana bar updates.
  4. Open inventory (I). Right-click a Health Potion if one is in inventory — "Use" appears at top of context menu. Click Use — effect applies.
  5. Drag a Health Potion from inventory onto belt slot 3 — it appears there.
  6. Drag a non-useable item (e.g., Iron Bar) onto belt slot 4 — drag is rejected.
  7. Drag a belt item back to inventory — it moves correctly.
  8. Save and reload — belt contents are restored.

- [ ] **Step 9: Commit**

  ```bash
  git add scripts/main.gd
  git commit -m "feat: wire BeltUI, belt save/load, starting potions, and use_from_inventory into main"
  ```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|---|---|
| 5-slot belt, always visible, bottom of screen | Task 6 |
| Keys 1–5 use items | Task 4 |
| Only useable items can be placed in belt | Task 7 (drag filter) |
| Health potion: +20 HP | Task 4 `apply_item_effect` |
| Mana potion: +20 Mana | Task 4 `apply_item_effect` |
| Potions stackable, use consumes 1 | Task 2 `consume()` + Task 1 stack size |
| "Use" in inventory context menu | Task 8 |
| Starting items: 2 health + 2 mana | Task 9 |
| Floating "+20 HP"/"+20 Mana" text | Task 5 |
| Belt persisted in save | Task 3 + Task 9 |
| Drag from inventory to belt (when I open) | Task 7 |
| Drag from belt back to inventory | Task 7 Part B |
| HEALTH_POTION and MANA_POTION item types | Task 1 |
| is_useable() gate | Task 1 |

All spec requirements covered. ✓

**Type/method consistency check:**
- `Belt.consume()` returns `int` (item type or -1) — matches `use_belt_slot()` usage ✓
- `Belt.set_slot()` signature: `(index, item_type, count)` — consistent across Tasks 2, 4, 7, 9 ✓
- `apply_item_effect(item_type: int)` called from `use_belt_slot()` and the `use_from_inventory` signal handler ✓
- `show_use_feedback` renamed from `_show_use_feedback` in Task 9 step 6 — must apply that rename in Task 5 ✓

**Rename reminder:** In Task 5, name the method `show_use_feedback` (no underscore) so it can be called from `main.gd` in Task 9 Step 6. The call in `use_belt_slot()` should also use `show_use_feedback`.
