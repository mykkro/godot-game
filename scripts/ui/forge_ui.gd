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
		var sd := _make_slot()
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

	row.add_theme_stylebox_override("panel", _recipe_row_style(false))

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


## Move/merge between two different forge Arrays (input <-> output).
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
			icon.texture  = PickableItemDef.get_texture(t)
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
