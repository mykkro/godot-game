class_name ChestLootUI
extends CanvasLayer

## Two-panel loot screen: left = player inventory, right = chest.
## Opened by Avatar when interacting with a ChestNode (E key).
## Closes on E or Escape; pauses game while open.

signal closed()

const INV_COLS   := 10
const INV_ROWS   := 5
const CHEST_COLS := 5
const CHEST_ROWS := 4
const SLOT_SIZE  := 52
const SLOT_PAD   := 4

var _inventory: Inventory = null
var _chest:     ChestNode = null

var _inv_icons:   Array = []
var _inv_labels:  Array = []
var _inv_badges:  Array = []

var _chest_icons:  Array = []
var _chest_labels: Array = []
var _chest_badges: Array = []

var _inv_count_lbl:   Label = null
var _chest_count_lbl: Label = null

var _snd_open:     AudioStreamPlayer = null
var _snd_take_all: AudioStreamPlayer = null


func _ready() -> void:
	layer        = 72
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible      = false

	_snd_open = AudioStreamPlayer.new()
	_snd_open.stream    = load("res://sounds/RPG Sound Pack/world/door.wav")
	_snd_open.volume_db = linear_to_db(0.7)
	_snd_open.bus       = AudioManager.SFX_BUS
	add_child(_snd_open)

	_snd_take_all = AudioStreamPlayer.new()
	_snd_take_all.stream    = load("res://sounds/RPG Sound Pack/inventory/metal-ringing.wav")
	_snd_take_all.volume_db = linear_to_db(0.6)
	_snd_take_all.bus       = AudioManager.SFX_BUS
	add_child(_snd_take_all)

	_build_ui()


func open(inventory: Inventory, chest: ChestNode) -> void:
	_inventory = inventory
	_chest     = chest
	visible    = true
	get_tree().paused = true
	_snd_open.play()
	_refresh()


func close() -> void:
	if not visible:
		return
	if _chest != null:
		_chest.flush_to_data()
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
	elif ke.keycode == KEY_A:
		_on_take_all()
		get_viewport().set_input_as_handled()


# ── UI Construction ────────────────────────────────────────────────────────────

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

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	center.add_child(hbox)

	hbox.add_child(_build_inv_panel())
	hbox.add_child(_build_chest_panel())


func _build_inv_panel() -> PanelContainer:
	var panel := _make_panel_container(Color(0.35, 0.40, 0.55, 0.85))
	var vbox  := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)
	header.add_child(_make_title_label("Your Inventory"))
	header.add_child(_make_button("Sort / Compact", _on_sort_inv))
	header.add_child(_make_button("Store All  ▶", _on_store_all))

	_inv_count_lbl = _make_count_label()
	vbox.add_child(_inv_count_lbl)

	var grid := GridContainer.new()
	grid.columns = INV_COLS
	grid.add_theme_constant_override("h_separation", SLOT_PAD)
	grid.add_theme_constant_override("v_separation", SLOT_PAD)
	vbox.add_child(grid)

	for idx in range(INV_COLS * INV_ROWS):
		var sd   := _make_slot()
		var slot := sd[2] as PanelContainer
		_inv_icons.append(sd[0]  as TextureRect)
		_inv_labels.append(sd[1] as Label)
		_inv_badges.append(sd[3] as Label)
		_setup_inv_slot(slot, idx)
		grid.add_child(slot)

	return panel


func _build_chest_panel() -> PanelContainer:
	var panel := _make_panel_container(Color(0.55, 0.45, 0.20, 0.85))
	var vbox  := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)
	header.add_child(_make_title_label("Chest"))
	header.add_child(_make_button("◀  Take All", _on_take_all))
	header.add_child(_make_button("Sort / Compact", _on_sort_chest))
	header.add_child(_make_button("✕", close))

	_chest_count_lbl = _make_count_label()
	vbox.add_child(_chest_count_lbl)

	var grid := GridContainer.new()
	grid.columns = CHEST_COLS
	grid.add_theme_constant_override("h_separation", SLOT_PAD)
	grid.add_theme_constant_override("v_separation", SLOT_PAD)
	vbox.add_child(grid)

	for idx in range(CHEST_COLS * CHEST_ROWS):
		var sd   := _make_slot()
		var slot := sd[2] as PanelContainer
		_chest_icons.append(sd[0]  as TextureRect)
		_chest_labels.append(sd[1] as Label)
		_chest_badges.append(sd[3] as Label)
		_setup_chest_slot(slot, idx)
		grid.add_child(slot)

	return panel


# ── Slot drag-and-drop ─────────────────────────────────────────────────────────

func _setup_inv_slot(slot: PanelContainer, idx: int) -> void:
	slot.set_drag_forwarding(
		func(_pos: Vector2) -> Variant:
			if _inventory == null or idx >= _inventory.count():
				return null
			var item_type := _inventory.get_type(idx)
			slot.set_drag_preview(_make_drag_preview(item_type))
			return {"loot_inv_slot": idx},

		func(_pos: Vector2, data: Variant) -> bool:
			if not (data is Dictionary):
				return false
			if data.has("loot_inv_slot"):
				return int(data["loot_inv_slot"]) != idx
			if data.has("loot_chest_slot"):
				return true
			return false,

		func(_pos: Vector2, data: Variant) -> void:
			if data.has("loot_inv_slot") and _inventory != null:
				var src: int = int(data["loot_inv_slot"])
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
			elif data.has("loot_chest_slot"):
				_move_chest_to_inv(int(data["loot_chest_slot"]), idx)
			_refresh()
	)


func _setup_chest_slot(slot: PanelContainer, idx: int) -> void:
	slot.set_drag_forwarding(
		func(_pos: Vector2) -> Variant:
			if _chest == null or idx >= _chest.contents.size():
				return null
			var entry: Dictionary = _chest.contents[idx]
			slot.set_drag_preview(_make_drag_preview(int(entry["type"])))
			return {"loot_chest_slot": idx},

		func(_pos: Vector2, data: Variant) -> bool:
			if not (data is Dictionary):
				return false
			if data.has("loot_chest_slot"):
				return int(data["loot_chest_slot"]) != idx
			if data.has("loot_inv_slot"):
				return true
			return false,

		func(_pos: Vector2, data: Variant) -> void:
			if data.has("loot_chest_slot"):
				var src: int = int(data["loot_chest_slot"])
				if _chest != null and src < _chest.contents.size() and src != idx:
					if idx < _chest.contents.size():
						var src_type: int = int(_chest.contents[src]["type"])
						if src_type == int(_chest.contents[idx]["type"]):
							var max_st := PickableItemDef.max_stack_size(src_type)
							if max_st > 1:
								var space := max_st - int(_chest.contents[idx]["count"])
								if space > 0:
									var move := mini(int(_chest.contents[src]["count"]), space)
									_chest.contents[idx]["count"] = int(_chest.contents[idx]["count"]) + move
									_chest.contents[src]["count"] = int(_chest.contents[src]["count"]) - move
									if int(_chest.contents[src]["count"]) <= 0:
										_chest.contents.remove_at(src)
									_refresh()
									return
					var entry := _chest.contents[src]
					_chest.contents.remove_at(src)
					_chest.contents.insert(mini(idx, _chest.contents.size()), entry)
			elif data.has("loot_inv_slot"):
				_move_inv_to_chest(int(data["loot_inv_slot"]), idx)
			_refresh()
	)


# ── Refresh ────────────────────────────────────────────────────────────────────

func _refresh() -> void:
	_refresh_inv()
	_refresh_chest()


func _refresh_inv() -> void:
	if _inventory == null:
		return
	_inv_count_lbl.text = "%d / %d slots" % [_inventory.count(), Inventory.MAX_ITEMS]
	for i in range(INV_COLS * INV_ROWS):
		var icon  := _inv_icons[i]  as TextureRect
		var label := _inv_labels[i] as Label
		var badge := _inv_badges[i] as Label
		if i < _inventory.count():
			var item_type:  int = _inventory.get_type(i)
			var item_count: int = _inventory.get_count(i)
			icon.texture = PickableItemDef.get_texture(item_type)
			label.text   = PickableItemDef.get_display_name(item_type)
			if item_count > 1:
				badge.text    = str(item_count)
				badge.visible = true
			else:
				badge.visible = false
		else:
			icon.texture  = null
			label.text    = ""
			badge.visible = false


func _refresh_chest() -> void:
	if _chest == null:
		return
	_chest_count_lbl.text = "%d / %d slots" % [_chest.contents.size(), ChestNode.CAPACITY]
	for i in range(CHEST_COLS * CHEST_ROWS):
		var icon  := _chest_icons[i]  as TextureRect
		var label := _chest_labels[i] as Label
		var badge := _chest_badges[i] as Label
		if i < _chest.contents.size():
			var entry: Dictionary = _chest.contents[i]
			var obj_type:  int    = int(entry["type"])
			var obj_count: int    = int(entry["count"])
			icon.texture = PickableItemDef.get_texture(obj_type)
			label.text   = PickableItemDef.get_display_name(obj_type)
			if obj_count > 1:
				badge.text    = str(obj_count)
				badge.visible = true
			else:
				badge.visible = false
		else:
			icon.texture  = null
			label.text    = ""
			badge.visible = false


# ── Button handlers ────────────────────────────────────────────────────────────

func _on_sort_inv() -> void:
	if _inventory == null:
		return
	_compact_items(_inventory.items)
	_inventory.items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return PickableItemDef.get_display_name(a["type"]) \
				< PickableItemDef.get_display_name(b["type"]))
	_refresh_inv()


func _on_sort_chest() -> void:
	if _chest == null:
		return
	_compact_items(_chest.contents)
	_chest.contents.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return PickableItemDef.get_display_name(a["type"]) \
				< PickableItemDef.get_display_name(b["type"]))
	_refresh_chest()


func _on_take_all() -> void:
	if _chest == null or _inventory == null:
		return
	var took := false
	var i := 0
	while i < _chest.contents.size():
		var entry: Dictionary = _chest.contents[i]
		var obj_type: int = int(entry["type"])
		var count:    int = int(entry["count"])
		var added := 0
		for _j in range(count):
			if not _inventory.add(obj_type):
				break
			added += 1
		if added > 0:
			took = true
		if added >= count:
			_chest.contents.remove_at(i)
		else:
			entry["count"] = count - added
			i += 1
	if took:
		_snd_take_all.play()
	_refresh()


func _on_store_all() -> void:
	if _chest == null or _inventory == null:
		return
	var i := 0
	while i < _inventory.count():
		var obj_type := _inventory.get_type(i)
		var count    := _inventory.get_count(i)
		var added    := 0
		for _j in range(count):
			if not _chest_has_room_for(obj_type):
				break
			_add_one_to_chest(obj_type)
			added += 1
		if added > 0:
			_inventory.remove_from_slot(i, added)
			if added < count:
				i += 1   # slot still has remaining items
		else:
			i += 1
	_refresh()


# ── Transfer helpers ───────────────────────────────────────────────────────────

## Move player inv slot inv_idx into chest slot chest_idx (merge / swap / append).
func _move_inv_to_chest(inv_idx: int, chest_idx: int) -> void:
	if _inventory == null or _chest == null:
		return
	if inv_idx < 0 or inv_idx >= _inventory.count():
		return
	var src_type:  int = _inventory.get_type(inv_idx)
	var src_count: int = _inventory.get_count(inv_idx)

	if chest_idx < _chest.contents.size():
		var dst: Dictionary = _chest.contents[chest_idx]
		var dst_type: int   = int(dst["type"])
		if dst_type == src_type:
			var max_st := PickableItemDef.max_stack_size(src_type)
			var space  := max_st - int(dst["count"])
			var move   := mini(src_count, space)
			if move <= 0:
				return
			dst["count"] = int(dst["count"]) + move
			_inventory.remove_from_slot(inv_idx, move)
		else:
			# Swap stacks.
			_chest.contents[chest_idx] = {"type": src_type, "count": src_count}
			_inventory.items[inv_idx]  = dst
	else:
		# Empty chest slot.
		if _chest.contents.size() < ChestNode.CAPACITY:
			_chest.contents.append({"type": src_type, "count": src_count})
			_inventory.remove_from_slot(inv_idx, src_count)


## Move chest slot chest_idx into player inv slot inv_idx (merge / swap / append).
func _move_chest_to_inv(chest_idx: int, inv_idx: int) -> void:
	if _inventory == null or _chest == null:
		return
	if chest_idx < 0 or chest_idx >= _chest.contents.size():
		return
	var src: Dictionary = _chest.contents[chest_idx]
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
			src["count"]                       = src_count - move
			if int(src["count"]) <= 0:
				_chest.contents.remove_at(chest_idx)
		else:
			# Swap stacks.
			var dst_entry := {"type": dst_type, "count": dst_count}
			_chest.contents[chest_idx] = dst_entry
			_inventory.items[inv_idx]  = src
	else:
		# Empty inv slot.
		if _inventory.count() < Inventory.MAX_ITEMS:
			_inventory.items.append({"type": src_type, "count": src_count})
			_chest.contents.remove_at(chest_idx)


func _chest_has_room_for(obj_type: int) -> bool:
	var max_st := PickableItemDef.max_stack_size(obj_type)
	if max_st > 1:
		for entry in _chest.contents:
			if int(entry["type"]) == obj_type and int(entry["count"]) < max_st:
				return true
	return _chest.contents.size() < ChestNode.CAPACITY


func _add_one_to_chest(obj_type: int) -> void:
	var max_st := PickableItemDef.max_stack_size(obj_type)
	if max_st > 1:
		for entry in _chest.contents:
			if int(entry["type"]) == obj_type and int(entry["count"]) < max_st:
				entry["count"] = int(entry["count"]) + 1
				return
	if _chest.contents.size() < ChestNode.CAPACITY:
		_chest.contents.append({"type": obj_type, "count": 1})


## Merge partial stacks of the same type together in-place.
func _compact_items(arr: Array) -> void:
	var i := 0
	while i < arr.size():
		var obj_type: int = int(arr[i]["type"])
		var max_st   := PickableItemDef.max_stack_size(obj_type)
		if max_st > 1:
			var j := i + 1
			while j < arr.size() and int(arr[i]["count"]) < max_st:
				if int(arr[j]["type"]) == obj_type:
					var space: int = max_st - int(arr[i]["count"])
					var take:  int = mini(int(arr[j]["count"]), space)
					arr[i]["count"] = int(arr[i]["count"]) + take
					arr[j]["count"] = int(arr[j]["count"]) - take
					if int(arr[j]["count"]) <= 0:
						arr.remove_at(j)
					else:
						j += 1
				else:
					j += 1
		i += 1


# ── Widget factories ───────────────────────────────────────────────────────────

func _make_panel_container(border_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.95)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 2)
	style.border_color = border_color
	for c in range(4):
		style.set_corner_radius(c, 6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_title_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


func _make_count_label() -> Label:
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	return lbl


func _make_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(callback)
	return btn


func _make_drag_preview(obj_type: int) -> TextureRect:
	var preview             := TextureRect.new()
	preview.texture          = PickableItemDef.get_texture(obj_type)
	preview.custom_minimum_size = Vector2(44, 44)
	preview.expand_mode      = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode     = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter   = CanvasItem.TEXTURE_FILTER_NEAREST
	return preview


## Returns [TextureRect icon, Label name_lbl, PanelContainer slot, Label badge].
func _make_slot() -> Array:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE + 16)

	var bg := StyleBoxFlat.new()
	bg.bg_color     = Color(0.12, 0.12, 0.18, 0.9)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		bg.set_border_width(side, 1)
	bg.border_color = Color(0.28, 0.28, 0.38, 0.7)
	slot.add_theme_stylebox_override("panel", bg)

	var vb := VBoxContainer.new()
	vb.alignment    = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(vb)

	var icon_wrap := Control.new()
	icon_wrap.custom_minimum_size = Vector2(SLOT_SIZE - 6, SLOT_SIZE - 6)
	icon_wrap.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	vb.add_child(icon_wrap)

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

	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	lbl.clip_text    = true
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(lbl)

	return [icon, lbl, slot, badge]
