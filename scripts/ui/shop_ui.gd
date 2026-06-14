class_name ShopUI
extends CanvasLayer

const COLS          := 5
const ROWS          := 4
const SLOT_SIZE     := 52
const SLOT_PAD      := 4
## NPC coin pool given at shop open (used for change / buying player items).
const NPC_COIN_POOL := 1000
const NPC_PANEL_MAX := COLS * ROWS   # max distinct entries NPC panel holds

var _inventory: Inventory = null
var _npc_name:  String    = ""

## Working copies — only applied to real inventory on Trade.
var _player_work: Array = []
var _player_orig: Array = []
var _shop_work:   Array = []
var _shop_orig:   Array = []

## Cache of all pickable item types except COIN (built once at first open).
static var _all_pickable_types: Array = []

## UI node references.
var _player_icons:     Array  = []
var _player_labels:    Array  = []
var _player_badges:    Array  = []
var _npc_icons:        Array  = []
var _npc_labels:       Array  = []
var _npc_badges:       Array  = []
var _npc_title_lbl:    Label  = null
var _player_count_lbl: Label  = null
var _npc_count_lbl:    Label  = null
var _balance_lbl:      Label  = null
var _trade_btn:        Button = null


func _ready() -> void:
	layer        = 73
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible      = false
	_build_ui()


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

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 10)
	center.add_child(outer_vbox)

	var panels_hbox := HBoxContainer.new()
	panels_hbox.add_theme_constant_override("separation", 18)
	outer_vbox.add_child(panels_hbox)

	panels_hbox.add_child(_build_player_panel())
	panels_hbox.add_child(_build_npc_panel())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer_vbox.add_child(footer)

	_balance_lbl = Label.new()
	_balance_lbl.text = "Balance: 0 coins"
	_balance_lbl.add_theme_font_size_override("font_size", 15)
	_balance_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_balance_lbl)

	var reset_btn := _make_button("Reset", _on_reset_pressed)
	footer.add_child(reset_btn)

	_trade_btn          = _make_button("Trade", _on_trade_pressed)
	_trade_btn.disabled = true
	footer.add_child(_trade_btn)


func _build_player_panel() -> PanelContainer:
	var panel := _make_panel_container(Color(0.35, 0.40, 0.55, 0.85))
	var vbox  := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)
	header.add_child(_make_title_label("Your Inventory"))
	header.add_child(_make_button("Sort", _on_sort_player))

	_player_count_lbl = _make_count_label()
	vbox.add_child(_player_count_lbl)

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", SLOT_PAD)
	grid.add_theme_constant_override("v_separation", SLOT_PAD)
	vbox.add_child(grid)

	for idx in range(COLS * ROWS):
		var sd   := _make_slot()
		var slot := sd[2] as PanelContainer
		_player_icons.append(sd[0]  as TextureRect)
		_player_labels.append(sd[1] as Label)
		_player_badges.append(sd[3] as Label)
		_setup_player_slot(slot, idx)
		grid.add_child(slot)

	return panel


func _build_npc_panel() -> PanelContainer:
	var panel := _make_panel_container(Color(0.55, 0.40, 0.20, 0.85))
	var vbox  := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	_npc_title_lbl = _make_title_label("")
	header.add_child(_npc_title_lbl)

	_npc_count_lbl = _make_count_label()
	vbox.add_child(_npc_count_lbl)

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", SLOT_PAD)
	grid.add_theme_constant_override("v_separation", SLOT_PAD)
	vbox.add_child(grid)

	for idx in range(COLS * ROWS):
		var sd   := _make_slot()
		var slot := sd[2] as PanelContainer
		_npc_icons.append(sd[0]  as TextureRect)
		_npc_labels.append(sd[1] as Label)
		_npc_badges.append(sd[3] as Label)
		_setup_npc_slot(slot, idx)
		grid.add_child(slot)

	return panel


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
	btn.text         = text
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(callback)
	return btn


func _make_drag_preview(obj_type: int) -> TextureRect:
	var preview                := TextureRect.new()
	preview.texture             = PickableItemDef.get_texture(obj_type)
	preview.custom_minimum_size = Vector2(44, 44)
	preview.expand_mode         = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter      = CanvasItem.TEXTURE_FILTER_NEAREST
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


func _setup_player_slot(_slot: PanelContainer, _idx: int) -> void:
	pass


func _setup_npc_slot(_slot: PanelContainer, _idx: int) -> void:
	pass


func _on_reset_pressed() -> void:
	pass


func _on_trade_pressed() -> void:
	pass


func _on_sort_player() -> void:
	pass
