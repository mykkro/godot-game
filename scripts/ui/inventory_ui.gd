class_name InventoryUI
extends CanvasLayer

const COLS      := 10
const ROWS      := 5
const SLOT_SIZE := 54
const SLOT_PAD  := 5

var _visible_flag: bool      = false
var _inventory:    Inventory = null

var _center:      CenterContainer = null
var _panel:       PanelContainer  = null
var _count_label: Label           = null
var _slot_icons:  Array           = []   # Array of TextureRect
var _slot_labels: Array           = []   # Array of Label

signal drop_requested(slot_index: int)

var _context_backdrop:   Button         = null
var _context_menu:       PanelContainer = null
var _context_slot_index: int            = -1


func setup(inventory: Inventory) -> void:
	_inventory = inventory


func _ready() -> void:
	layer = 70

	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)

	_panel = PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.06, 0.06, 0.10, 0.93)
	style.border_width_left          = 2
	style.border_width_right         = 2
	style.border_width_top           = 2
	style.border_width_bottom        = 2
	style.border_color               = Color(0.4, 0.4, 0.5, 0.8)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	_center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

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

	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", 12)
	_count_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	vbox.add_child(_count_label)

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", SLOT_PAD)
	grid.add_theme_constant_override("v_separation", SLOT_PAD)
	vbox.add_child(grid)

	for i in range(ROWS * COLS):
		var slot_data := _make_slot()
		var slot      := slot_data[2] as PanelContainer
		_slot_icons.append(slot_data[0] as TextureRect)
		_slot_labels.append(slot_data[1] as Label)
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		grid.add_child(slot)

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

	_center.visible = false


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
		else:
			_close_context_menu()
		get_viewport().set_input_as_handled()


## Call after picking up an item to update the display if open.
func notify_changed() -> void:
	if _visible_flag:
		_refresh()


# ── Private ──────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if _inventory == null:
		return
	_count_label.text = "%d / %d" % [_inventory.count(), Inventory.MAX_ITEMS]

	for i in range(ROWS * COLS):
		var icon  := _slot_icons[i]  as TextureRect
		var label := _slot_labels[i] as Label
		if i < _inventory.items.size():
			var item_type: int = _inventory.items[i]
			icon.texture = TextureCache.get_object_texture(
					PickableItemDef.get_sprite(item_type))
			label.text   = PickableItemDef.get_display_name(item_type)
		else:
			icon.texture = null
			label.text   = ""


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


func _on_sort_pressed() -> void:
	if _inventory == null:
		return
	_inventory.items.sort_custom(
		func(a: int, b: int) -> bool:
			return PickableItemDef.get_display_name(a) < PickableItemDef.get_display_name(b)
	)
	_refresh()


## Returns [TextureRect icon, Label name_label, PanelContainer slot].
func _make_slot() -> Array:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE + 16)

	var bg := StyleBoxFlat.new()
	bg.bg_color          = Color(0.12, 0.12, 0.18, 0.9)
	bg.border_width_left = 1;  bg.border_width_right  = 1
	bg.border_width_top  = 1;  bg.border_width_bottom = 1
	bg.border_color      = Color(0.28, 0.28, 0.38, 0.7)
	slot.add_theme_stylebox_override("panel", bg)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(vb)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(SLOT_SIZE - 6, SLOT_SIZE - 6)
	icon.expand_mode         = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter      = CanvasItem.TEXTURE_FILTER_NEAREST
	vb.add_child(icon)

	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	lbl.clip_text = true
	vb.add_child(lbl)

	return [icon, lbl, slot]
