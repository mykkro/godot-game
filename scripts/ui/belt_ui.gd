class_name BeltUI
extends Control

const SLOT_SIZE := 44
const SLOT_GAP  := 6

var _belt:      Belt      = null
var _inventory: Inventory = null
var _inventory_ui_ref: InventoryUI = null

var _slot_icons:  Array = []   # Array of TextureRect
var _slot_badges: Array = []   # Array of Label (stack count)
var _slots:       Array = []   # Array of PanelContainer — wired for drag in setup()


## Call from main after belt and inventory are loaded.
func setup(belt: Belt, inventory: Inventory, inv_ui: InventoryUI) -> void:
	_belt             = belt
	_inventory        = inventory
	_inventory_ui_ref = inv_ui
	belt.belt_changed.connect(_refresh)
	# Wire drag-and-drop here (not in _ready) and pass data as explicit params
	# so lambdas close over non-null local variables rather than instance vars.
	for i in _slots.size():
		_setup_slot_drag(_slots[i] as PanelContainer, i, belt, inventory, inv_ui)
	_refresh()


func _ready() -> void:
	# BeltUI lives inside InventoryUI's CanvasLayer so drag-and-drop between
	# belt slots and inventory slots works (same canvas layer = same event space).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Bottom strip — full width, fixed height above the screen edge.
	var bottom := Control.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top    = -(SLOT_SIZE + 20)
	bottom.offset_bottom = -8
	bottom.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)

	# CenterContainer centres the pill horizontally (and vertically) inside the strip.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(center)

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
	center.add_child(pill)

	var inner_hbox := HBoxContainer.new()
	inner_hbox.add_theme_constant_override("separation", SLOT_GAP)
	pill.add_child(inner_hbox)

	for i in Belt.SLOT_COUNT:
		var slot_data := _make_slot(i)
		_slot_icons.append(slot_data[1])
		_slot_badges.append(slot_data[2])
		_slots.append(slot_data[0])
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

	# Icon wrapper.
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


func _setup_slot_drag(
		slot: PanelContainer, index: int,
		belt: Belt, inventory: Inventory, inv_ui: InventoryUI) -> void:
	slot.set_drag_forwarding(
		# get_drag_data — start drag when belt slot has an item.
		func(_pos: Vector2) -> Variant:
			if not belt.has_item(index):
				return null
			var item_type := belt.get_type(index)
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
			if d.has("inv_src_slot"):
				var src: int = int(d["inv_src_slot"])
				if src >= inventory.count():
					return false
				return PickableItemDef.is_useable(inventory.get_type(src))
			return false,

		# drop_data — move inventory item into this belt slot.
		func(_pos: Vector2, data: Variant) -> void:
			var d := data as Dictionary
			if not d.has("inv_src_slot"):
				return
			var src: int = int(d["inv_src_slot"])
			if src >= inventory.count():
				return
			var item_type  := inventory.get_type(src)
			var item_count := inventory.get_count(src)
			if not PickableItemDef.is_useable(item_type):
				return
			# If same type already in belt slot: merge (capped at max stack).
			if belt.has_item(index) and belt.get_type(index) == item_type:
				var max_st   := PickableItemDef.max_stack_size(item_type)
				var existing := belt.get_count(index)
				var space    := max_st - existing
				if space <= 0:
					return
				var move := mini(item_count, space)
				belt.set_slot(index, item_type, existing + move)
				inventory.remove_from_slot(src, move)
			elif not belt.has_item(index):
				# Empty belt slot: move entire inventory stack.
				belt.set_slot(index, item_type, item_count)
				inventory.remove_from_slot(src, item_count)
			else:
				# Different item in belt slot: swap if belt item is also useable.
				var belt_type  := belt.get_type(index)
				var belt_count := belt.get_count(index)
				belt.set_slot(index, item_type, item_count)
				inventory.remove_from_slot(src, item_count)
				# Belt item goes back to inventory.
				inventory.items.append({"type": belt_type, "count": belt_count})
			inv_ui.notify_changed()
	)


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
