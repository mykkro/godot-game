class_name InventoryUI
extends CanvasLayer

const COLS      := 5
const ROWS      := 10
const SLOT_SIZE := 54
const SLOT_PAD  := 5

var _visible_flag: bool      = false
var _inventory:    Inventory = null

var _panel:       PanelContainer = null
var _count_label: Label          = null
var _slot_icons:  Array          = []   # Array of TextureRect
var _slot_labels: Array          = []   # Array of Label


func setup(inventory: Inventory) -> void:
	_inventory = inventory


func _ready() -> void:
	layer = 70

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	var panel_w := COLS * (SLOT_SIZE + SLOT_PAD) + SLOT_PAD + 20
	_panel.custom_minimum_size = Vector2(panel_w, 0)

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
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "INVENTORY  (I to close)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(title)

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

	for _i in range(ROWS * COLS):
		var slot_data := _make_slot()
		_slot_icons.append(slot_data[0] as TextureRect)
		_slot_labels.append(slot_data[1] as Label)
		grid.add_child(slot_data[2] as Control)

	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_I:
		_visible_flag = not _visible_flag
		_panel.visible = _visible_flag
		if _visible_flag:
			_refresh()
		get_viewport().set_input_as_handled()
	elif ke.keycode == KEY_ESCAPE and _visible_flag:
		_visible_flag = false
		_panel.visible = false
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
			label.text   = PickableItemDef.get_name(item_type)
		else:
			icon.texture = null
			label.text   = ""


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
