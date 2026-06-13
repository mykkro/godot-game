class_name ChestInventoryEditor
extends CanvasLayer

## Floating panel for editing a placed chest's contents and variant.
## Open via open(chunk_data, lx, ly).  Emits closed() when dismissed and
## chest_removed() when the user clicks "Remove Chest".

signal closed()
signal chest_removed()

const COLS     := 5
const ROWS     := 4
const CAPACITY := ChestNode.CAPACITY   # 20
const SLOT_PX  := 52

var _chunk_data: ChunkData = null
var _lx:         int       = 0
var _ly:         int       = 0

var _contents: Array = []   # Array of {"type": int, "count": int}

var _slot_panels:   Array = []   # PanelContainer
var _slot_icons:    Array = []   # TextureRect
var _slot_labels:   Array = []   # Label
var _title_label:   Label = null

var _style_slot_empty:    StyleBoxFlat = null
var _style_slot_occupied: StyleBoxFlat = null
var _style_slot_hover:    StyleBoxFlat = null


func _ready() -> void:
	layer   = 9   # below EditorUI (10) so palette drag previews render above us
	visible = false
	_build_styles()
	_build_ui()


func get_lx() -> int: return _lx
func get_ly() -> int: return _ly


## Open for the given cell in chunk_data.
func open(chunk_data: ChunkData, lx: int, ly: int) -> void:
	_chunk_data = chunk_data
	_lx         = lx
	_ly         = ly

	var stored: Variant = chunk_data.get_chest_contents(lx, ly)
	if stored == null:
		# Not yet set — start with an empty editor (designer fills it intentionally).
		_contents = []
	else:
		_contents = (stored as Array).duplicate(true)

	var variant := chunk_data.get_chest_variant(lx, ly)
	if variant == 0:
		variant = ((lx * 7 + ly * 13) % ChestNode.CHEST_VARIANTS) + 1
	_title_label.text = "Chest  —  Variant %d  |  cell (%d, %d)" % [variant, lx, ly]

	_refresh()
	visible = true


func close() -> void:
	visible = false
	_flush()
	closed.emit()


# ── Private ───────────────────────────────────────────────────────────────────

func _build_styles() -> void:
	_style_slot_empty = StyleBoxFlat.new()
	_style_slot_empty.bg_color     = Color(0.10, 0.10, 0.15, 0.9)
	_style_slot_empty.border_color = Color(0.25, 0.25, 0.35, 0.7)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		_style_slot_empty.set_border_width(side, 1)

	_style_slot_occupied = _style_slot_empty.duplicate()
	(_style_slot_occupied as StyleBoxFlat).bg_color     = Color(0.14, 0.14, 0.22, 0.9)
	(_style_slot_occupied as StyleBoxFlat).border_color = Color(0.40, 0.40, 0.60, 0.8)

	_style_slot_hover = _style_slot_empty.duplicate()
	(_style_slot_hover as StyleBoxFlat).bg_color     = Color(0.20, 0.22, 0.32, 0.9)
	(_style_slot_hover as StyleBoxFlat).border_color = Color(0.50, 0.80, 0.50, 0.9)


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color        = Color(0, 0, 0, 0.45)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# IGNORE so mouse events fall through to the item palette in the layer below.
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	var ps    := StyleBoxFlat.new()
	ps.bg_color    = Color(0.07, 0.07, 0.12, 0.97)
	ps.border_color = Color(0.55, 0.45, 0.20, 0.9)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		ps.set_border_width(side, 2)
	for c in range(4):
		ps.set_corner_radius(c, 6)
	ps.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title + close button row.
	var header := HBoxContainer.new()
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Chest"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	header.add_child(_title_label)

	var btn_close := Button.new()
	btn_close.text = "✕  Close"
	btn_close.add_theme_font_size_override("font_size", 14)
	btn_close.pressed.connect(close)
	header.add_child(btn_close)

	var hint := Label.new()
	hint.text = "Drag items from palette  |  Right-click slot to remove"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	vbox.add_child(hint)

	# Slot grid.
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(grid)

	for idx in range(CAPACITY):
		var slot  := PanelContainer.new()
		slot.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX + 14)
		slot.add_theme_stylebox_override("panel", _style_slot_empty)

		var svb := VBoxContainer.new()
		svb.alignment  = BoxContainer.ALIGNMENT_CENTER
		svb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(svb)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(SLOT_PX - 8, SLOT_PX - 8)
		icon.expand_mode   = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		svb.add_child(icon)

		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		lbl.clip_text    = true
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		svb.add_child(lbl)

		# Drag-and-drop: drops from item palette + drag-to-move within grid.
		_setup_slot_dnd(slot, idx)
		slot.gui_input.connect(_on_slot_input.bind(idx))

		_slot_panels.append(slot)
		_slot_icons.append(icon)
		_slot_labels.append(lbl)
		grid.add_child(slot)

	# Bottom button row.
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	vbox.add_child(footer)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	var btn_remove := Button.new()
	btn_remove.text = "Remove Chest"
	btn_remove.add_theme_font_size_override("font_size", 14)
	btn_remove.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	btn_remove.pressed.connect(_on_remove_chest)
	footer.add_child(btn_remove)


func _setup_slot_dnd(slot: PanelContainer, idx: int) -> void:
	slot.set_drag_forwarding(
		# get_drag_data — drag from this slot to move it
		func(_pos: Vector2) -> Variant:
			if idx >= _contents.size():
				return null
			var entry: Dictionary = _contents[idx]
			var tex := TextureCache.get_object_texture(
					PickableItemDef.get_sprite(entry["type"]))
			var preview                 := TextureRect.new()
			preview.texture              = tex
			preview.custom_minimum_size  = Vector2(40, 40)
			preview.expand_mode          = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			preview.stretch_mode         = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			preview.texture_filter       = CanvasItem.TEXTURE_FILTER_NEAREST
			slot.set_drag_preview(preview)
			return {"chest_src_slot": idx, "entry": entry},

		# can_drop_data
		func(_pos: Vector2, data: Variant) -> bool:
			if not (data is Dictionary):
				return false
			# Accept palette drops on any slot as long as the item can be added.
			if data.has("palette_obj_type"):
				return _can_add_palette_item(int(data["palette_obj_type"]))
			# Accept drop from another chest slot (move within grid).
			if data.has("chest_src_slot") and data["chest_src_slot"] != idx:
				return true
			return false,

		# drop_data
		func(_pos: Vector2, data: Variant) -> void:
			if data.has("palette_obj_type"):
				_add_palette_item(int(data["palette_obj_type"]))
			elif data.has("chest_src_slot"):
				var src: int = data["chest_src_slot"]
				if src < _contents.size():
					var entry: Dictionary = _contents[src]
					_contents.remove_at(src)
					var insert_at := mini(idx, _contents.size())
					_contents.insert(insert_at, entry)
			_flush()
			_refresh()
	)


func _on_slot_input(event: InputEvent, idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		if idx < _contents.size():
			_contents.remove_at(idx)
			_flush()
			_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.keycode == KEY_ESCAPE and ke.pressed and not ke.echo:
			close()
			get_viewport().set_input_as_handled()


func _on_remove_chest() -> void:
	visible = false
	chest_removed.emit()


func _can_add_palette_item(obj_type: int) -> bool:
	var max_stack := PickableItemDef.max_stack_size(obj_type)
	if max_stack > 1:
		for entry in _contents:
			if entry["type"] == obj_type and entry["count"] < max_stack:
				return true
	return _contents.size() < CAPACITY


func _add_palette_item(obj_type: int) -> void:
	var max_stack := PickableItemDef.max_stack_size(obj_type)
	if max_stack > 1:
		for entry in _contents:
			if entry["type"] == obj_type and entry["count"] < max_stack:
				entry["count"] += 1
				return
	if _contents.size() < CAPACITY:
		_contents.append({"type": obj_type, "count": 1})


func _flush() -> void:
	if _chunk_data != null:
		_chunk_data.set_chest_contents(_lx, _ly, _contents.duplicate(true))


func _refresh() -> void:
	for idx in range(CAPACITY):
		var icon  := _slot_icons[idx]  as TextureRect
		var lbl   := _slot_labels[idx] as Label
		var panel := _slot_panels[idx] as PanelContainer
		if idx < _contents.size():
			var entry: Dictionary = _contents[idx]
			var obj_type: int     = entry["type"]
			var count: int        = entry["count"]
			icon.texture  = TextureCache.get_object_texture(
					PickableItemDef.get_sprite(obj_type))
			var name_str := PickableItemDef.get_display_name(obj_type)
			if PickableItemDef.max_stack_size(obj_type) > 1:
				lbl.text = "%s x%d" % [name_str, count]
			else:
				lbl.text = name_str
			panel.add_theme_stylebox_override("panel", _style_slot_occupied)
		else:
			icon.texture = null
			lbl.text     = ""
			panel.add_theme_stylebox_override("panel", _style_slot_empty)
