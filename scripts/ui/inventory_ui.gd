class_name InventoryUI
extends CanvasLayer

const COLS             := 10
const ROWS             := 5
const SLOT_SIZE        := 54
const SLOT_PAD         := 5
const OPEN_SOUND_VOLUME := 0.3

var _visible_flag: bool              = false
var _inventory:    Inventory         = null
var _open_sound:   AudioStreamPlayer = null

var _center:      CenterContainer = null
var _panel:       PanelContainer  = null
var _count_label: Label           = null
var _slot_icons:        Array = []   # Array of TextureRect
var _slot_labels:       Array = []   # Array of Label
var _slot_count_badges: Array = []   # Array of Label (stack size overlays)

signal drop_requested(slot_index: int, count: int)

var _context_backdrop:    Button         = null
var _context_menu:        PanelContainer = null
var _context_slot_index:  int            = -1
var _cm_btn_split:        Button         = null
var _cm_btn_drop_1:       Button         = null
var _cm_btn_drop_half:    Button         = null
var _cm_btn_drop_all:     Button         = null


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
		_slot_icons.append(slot_data[0]        as TextureRect)
		_slot_labels.append(slot_data[1]       as Label)
		_slot_count_badges.append(slot_data[3] as Label)
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		grid.add_child(slot)

	# ── Context menu backdrop ─────────────────────────────────────────────────
	_context_backdrop = Button.new()
	_context_backdrop.flat = true
	_context_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_context_backdrop.focus_mode = Control.FOCUS_NONE
	_context_backdrop.pressed.connect(_close_context_menu)
	_context_backdrop.visible = false
	add_child(_context_backdrop)

	# ── Context menu ──────────────────────────────────────────────────────────
	_context_menu = PanelContainer.new()
	_context_menu.custom_minimum_size = Vector2(140, 0)

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

	_cm_btn_split     = _make_cm_button("Split",     _on_split_pressed)
	_cm_btn_drop_1    = _make_cm_button("Drop 1",    _on_drop_1_pressed)
	_cm_btn_drop_half = _make_cm_button("Drop Half", _on_drop_half_pressed)
	_cm_btn_drop_all  = _make_cm_button("Drop All",  _on_drop_all_pressed)
	cm_vbox.add_child(_cm_btn_split)
	cm_vbox.add_child(_cm_btn_drop_1)
	cm_vbox.add_child(_cm_btn_drop_half)
	cm_vbox.add_child(_cm_btn_drop_all)

	_context_menu.visible = false
	add_child(_context_menu)

	_open_sound = AudioStreamPlayer.new()
	_open_sound.stream    = load("res://sounds/RPG Sound Pack/interface/interface3.wav")
	_open_sound.volume_db = linear_to_db(OPEN_SOUND_VOLUME)
	add_child(_open_sound)

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
			if _open_sound != null:
				_open_sound.play()
		else:
			_close_context_menu()
		get_viewport().set_input_as_handled()


## Call after picking up or dropping an item to update the display if open.
func notify_changed() -> void:
	if _visible_flag:
		_refresh()


# ── Private ──────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if _inventory == null:
		return
	_count_label.text = "%d / %d" % [_inventory.count(), Inventory.MAX_ITEMS]

	for i in range(ROWS * COLS):
		var icon  := _slot_icons[i]        as TextureRect
		var label := _slot_labels[i]       as Label
		var badge := _slot_count_badges[i] as Label
		if i < _inventory.count():
			var item_type: int = _inventory.get_type(i)
			var item_count: int = _inventory.get_count(i)
			icon.texture = TextureCache.get_object_texture(
					PickableItemDef.get_sprite(item_type))
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


func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mbe := event as InputEventMouseButton
	if mbe.button_index == MOUSE_BUTTON_RIGHT and mbe.pressed:
		if _inventory == null or slot_index >= _inventory.count():
			return
		_context_slot_index = slot_index
		_show_context_menu(mbe.global_position)


func _show_context_menu(pos: Vector2) -> void:
	var item_count := _inventory.get_count(_context_slot_index) \
			if _context_slot_index < _inventory.count() else 1

	_cm_btn_split.disabled     = item_count < 2 or not _inventory.has_space()
	_cm_btn_drop_1.text        = "Drop" if item_count <= 1 else "Drop 1"
	_cm_btn_drop_half.visible  = item_count > 1
	_cm_btn_drop_all.text      = "Drop All" if item_count > 1 else "Drop"
	# When count == 1, "Drop 1" and "Drop All" are the same — hide the duplicate.
	_cm_btn_drop_1.visible     = item_count > 1
	_cm_btn_drop_all.visible   = true
	_cm_btn_split.visible      = item_count > 1

	const MENU_W := 140.0
	const MENU_H := 120.0
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


func _on_split_pressed() -> void:
	var idx := _context_slot_index
	_close_context_menu()
	if idx >= 0 and _inventory != null:
		_inventory.split_slot(idx)
		_refresh()


func _on_drop_1_pressed() -> void:
	var idx := _context_slot_index
	_close_context_menu()
	if idx >= 0:
		drop_requested.emit(idx, 1)


func _on_drop_half_pressed() -> void:
	var idx := _context_slot_index
	_close_context_menu()
	if idx >= 0 and _inventory != null:
		var half := maxi(1, _inventory.get_count(idx) / 2)
		drop_requested.emit(idx, half)


func _on_drop_all_pressed() -> void:
	var idx := _context_slot_index
	_close_context_menu()
	if idx >= 0 and _inventory != null:
		drop_requested.emit(idx, _inventory.get_count(idx))


func _on_sort_pressed() -> void:
	if _inventory == null:
		return
	_inventory.items.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return PickableItemDef.get_display_name(a["type"]) \
					< PickableItemDef.get_display_name(b["type"])
	)
	_refresh()


## Returns [TextureRect icon, Label name_label, PanelContainer slot, Label count_badge].
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

	# All non-interactive children must pass mouse events through to the slot.
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Icon wrapper holds the TextureRect + floating count badge.
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

	# Stack-size badge: bottom-right corner of the icon area.
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


func _make_cm_button(label: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(132, 28)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(callback)
	return btn
