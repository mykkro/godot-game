class_name ShopUI
extends CanvasLayer

const PLAYER_COLS      := 5
const PLAYER_ROWS      := 10
const NPC_COLS         := 5
const NPC_ROWS_VISIBLE := 10
const NPC_PANEL_MAX    := 100
const SLOT_SIZE        := 48
const SLOT_PAD         := 3
## NPC coin pool given at shop open (used for change / buying player items).
const NPC_COIN_POOL    := 1000

var _inventory: Inventory = null
var _npc_name:  String    = ""

## Working copies — only applied to real inventory on Trade.
var _player_work: Array = []
var _player_orig: Array = []
var _shop_work:   Array = []
var _shop_orig:   Array = []

## Cache of all pickable item types except COIN (built once at first open).
static var _all_pickable_types: Array = []
## Persistent shop state per NPC id — full item array saved on every Trade.
static var _npc_shop_states: Dictionary = {}

var _npc_id: String = ""

## UI node references.
var _player_icons:     Array  = []
var _player_badges:    Array  = []
var _npc_icons:        Array  = []
var _npc_badges:       Array  = []
var _npc_title_lbl:    Label  = null
var _npc_badge_lbl:    Label  = null
var _player_badge_lbl: Label  = null
var _player_count_lbl: Label  = null
var _npc_count_lbl:    Label  = null
var _balance_lbl:      Label  = null
var _trade_btn:        Button = null

var _npc_trader_level:    int = 0
var _player_trader_level: int = 0


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

	var win_style := StyleBoxFlat.new()
	win_style.bg_color = Color(0.06, 0.06, 0.10, 0.95)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		win_style.set_border_width(side, 1)
	win_style.border_color = Color(0.35, 0.35, 0.45, 0.8)
	for c in range(4):
		win_style.set_corner_radius(c, 8)
	win_style.set_content_margin_all(14)
	var window_panel := PanelContainer.new()
	window_panel.add_theme_stylebox_override("panel", win_style)
	center.add_child(window_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 10)
	window_panel.add_child(outer_vbox)

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
	header.add_child(_make_button("Compact", _on_compact_player))
	header.add_child(_make_button("Sort", _on_sort_player))

	_player_badge_lbl = Label.new()
	_player_badge_lbl.add_theme_font_size_override("font_size", 11)
	_player_badge_lbl.add_theme_color_override("font_color", Color(0.65, 0.78, 0.60))
	vbox.add_child(_player_badge_lbl)

	_player_count_lbl = _make_count_label()
	vbox.add_child(_player_count_lbl)

	var grid := GridContainer.new()
	grid.columns = PLAYER_COLS
	grid.add_theme_constant_override("h_separation", SLOT_PAD)
	grid.add_theme_constant_override("v_separation", SLOT_PAD)
	vbox.add_child(grid)

	for idx in range(PLAYER_COLS * PLAYER_ROWS):
		var sd   := _make_slot()
		var slot := sd[1] as PanelContainer
		_player_icons.append(sd[0]  as TextureRect)
		_player_badges.append(sd[2] as Label)
		_setup_player_slot(slot, idx)
		grid.add_child(slot)

	return panel


func _build_npc_panel() -> PanelContainer:
	var panel := _make_panel_container(Color(0.55, 0.40, 0.20, 0.85))
	var vbox  := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	_npc_title_lbl = _make_title_label("")
	header.add_child(_npc_title_lbl)
	header.add_child(_make_button("Compact", _on_compact_npc))
	header.add_child(_make_button("Sort", _on_sort_npc))

	_npc_badge_lbl = Label.new()
	_npc_badge_lbl.add_theme_font_size_override("font_size", 11)
	_npc_badge_lbl.add_theme_color_override("font_color", Color(0.85, 0.72, 0.35))
	_npc_badge_lbl.visible = false
	vbox.add_child(_npc_badge_lbl)

	_npc_count_lbl = _make_count_label()
	vbox.add_child(_npc_count_lbl)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size    = Vector2(0, NPC_ROWS_VISIBLE * (SLOT_SIZE + SLOT_PAD))
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = NPC_COLS
	grid.add_theme_constant_override("h_separation", SLOT_PAD)
	grid.add_theme_constant_override("v_separation", SLOT_PAD)
	scroll.add_child(grid)

	for idx in range(NPC_PANEL_MAX):
		var sd   := _make_slot()
		var slot := sd[1] as PanelContainer
		_npc_icons.append(sd[0]  as TextureRect)
		_npc_badges.append(sd[2] as Label)
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


## Returns [TextureRect icon, PanelContainer slot, Label badge].
func _make_slot() -> Array:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	var bg := StyleBoxFlat.new()
	bg.bg_color     = Color(0.12, 0.12, 0.18, 0.9)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		bg.set_border_width(side, 1)
	bg.border_color = Color(0.28, 0.28, 0.38, 0.7)
	slot.add_theme_stylebox_override("panel", bg)

	var icon_wrap := Control.new()
	icon_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	badge.offset_left   = -30
	badge.offset_top    = -14
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


func _setup_player_slot(slot: PanelContainer, idx: int) -> void:
	slot.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				if idx < _player_work.size():
					_auto_move_player_to_npc(idx)
					_refresh()
					get_viewport().set_input_as_handled()
	)

	slot.set_drag_forwarding(
		func(_pos: Vector2) -> Variant:
			if idx >= _player_work.size():
				return null
			var item_type  := int(_player_work[idx]["type"])
			var item_count := int(_player_work[idx]["count"])
			slot.set_drag_preview(_make_drag_preview(item_type))
			if item_count > 1 and Input.is_key_pressed(KEY_SHIFT):
				return {"shop_player_slot": idx, "move_count": max(1, item_count / 2)}
			return {"shop_player_slot": idx},

		func(_pos: Vector2, data: Variant) -> bool:
			if not (data is Dictionary):
				return false
			if data.has("shop_player_slot"):
				return int(data["shop_player_slot"]) != idx
			return data.has("shop_npc_slot"),

		func(_pos: Vector2, data: Variant) -> void:
			if data.has("shop_player_slot"):
				var src:       int  = int(data["shop_player_slot"])
				var is_split:  bool = data.has("move_count")
				if src < 0 or src >= _player_work.size():
					return
				var src_type:  int = int(_player_work[src]["type"])
				var src_count: int = int(_player_work[src]["count"])
				var take:      int = int(data["move_count"]) if is_split else src_count
				if idx < _player_work.size():
					if src_type == int(_player_work[idx]["type"]):
						var max_st := PickableItemDef.max_stack_size(src_type)
						if max_st > 1:
							var space := max_st - int(_player_work[idx]["count"])
							if space > 0:
								var add := mini(take, mini(src_count, space))
								_player_work[idx]["count"] = int(_player_work[idx]["count"]) + add
								_player_work[src]["count"] = src_count - add
								if int(_player_work[src]["count"]) <= 0:
									_player_work.remove_at(src)
								_refresh()
								return
					if not is_split:
						_move_player_to_player(src, idx)
				else:
					if is_split:
						var add := mini(take, src_count)
						if _player_work.size() < Inventory.MAX_ITEMS:
							_player_work.append({"type": src_type, "count": add})
							_player_work[src]["count"] = src_count - add
							if int(_player_work[src]["count"]) <= 0:
								_player_work.remove_at(src)
					else:
						_move_player_to_player(src, idx)
			elif data.has("shop_npc_slot"):
				var src:      int  = int(data["shop_npc_slot"])
				var is_split: bool = data.has("move_count")
				if is_split:
					_split_npc_to_player(src, idx, int(data["move_count"]))
				else:
					_move_npc_to_player(src, idx)
			_refresh()
	)


func _setup_npc_slot(slot: PanelContainer, idx: int) -> void:
	slot.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				if idx < _shop_work.size():
					_auto_move_npc_to_player(idx)
					_refresh()
					get_viewport().set_input_as_handled()
	)

	slot.set_drag_forwarding(
		func(_pos: Vector2) -> Variant:
			if idx >= _shop_work.size():
				return null
			var item_type  := int(_shop_work[idx]["type"])
			var item_count := int(_shop_work[idx]["count"])
			slot.set_drag_preview(_make_drag_preview(item_type))
			if item_count > 1 and Input.is_key_pressed(KEY_SHIFT):
				return {"shop_npc_slot": idx, "move_count": max(1, item_count / 2)}
			return {"shop_npc_slot": idx},

		func(_pos: Vector2, data: Variant) -> bool:
			if not (data is Dictionary):
				return false
			if data.has("shop_npc_slot"):
				return int(data["shop_npc_slot"]) != idx
			return data.has("shop_player_slot"),

		func(_pos: Vector2, data: Variant) -> void:
			if data.has("shop_npc_slot"):
				var src:       int  = int(data["shop_npc_slot"])
				var is_split:  bool = data.has("move_count")
				if src < 0 or src >= _shop_work.size():
					return
				var src_type:  int = int(_shop_work[src]["type"])
				var src_count: int = int(_shop_work[src]["count"])
				var take:      int = int(data["move_count"]) if is_split else src_count
				if idx < _shop_work.size():
					if src_type == int(_shop_work[idx]["type"]):
						var max_st := PickableItemDef.max_stack_size(src_type)
						if max_st > 1:
							var space := max_st - int(_shop_work[idx]["count"])
							if space > 0:
								var add := mini(take, mini(src_count, space))
								_shop_work[idx]["count"] = int(_shop_work[idx]["count"]) + add
								_shop_work[src]["count"] = src_count - add
								if int(_shop_work[src]["count"]) <= 0:
									_shop_work.remove_at(src)
								_refresh()
								return
					if not is_split:
						_move_npc_to_npc(src, idx)
				else:
					if is_split:
						var add := mini(take, src_count)
						if _shop_work.size() < NPC_PANEL_MAX:
							_shop_work.append({"type": src_type, "count": add})
							_shop_work[src]["count"] = src_count - add
							if int(_shop_work[src]["count"]) <= 0:
								_shop_work.remove_at(src)
					else:
						_move_npc_to_npc(src, idx)
			elif data.has("shop_player_slot"):
				var src:      int  = int(data["shop_player_slot"])
				var is_split: bool = data.has("move_count")
				if is_split:
					_split_player_to_npc(src, idx, int(data["move_count"]))
				else:
					_move_player_to_npc(src, idx)
			_refresh()
	)


func _on_reset_pressed() -> void:
	_shop_work   = _deep_copy_items(_shop_orig)
	_player_work = _deep_copy_items(_player_orig)
	_refresh()


func _on_trade_pressed() -> void:
	var bal := _adjusted_balance()
	if bal > 0:
		return
	if bal < 0:
		_pay_npc_coins_to_player(-bal)
	_npc_shop_states[_npc_id] = _deep_copy_items(_shop_work)
	assert(_player_work.size() <= Inventory.MAX_ITEMS, "shop produced oversized player_work")
	_inventory.items = _player_work
	close()


func _on_compact_player() -> void:
	_compact_items(_player_work)
	_refresh_player_panel()
	_refresh_balance()


func _on_compact_npc() -> void:
	_compact_items(_shop_work)
	_refresh_npc_panel()
	_refresh_balance()


func _on_sort_player() -> void:
	_compact_items(_player_work)
	_player_work.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return PickableItemDef.get_display_name(int(a["type"])) \
				< PickableItemDef.get_display_name(int(b["type"])))
	_refresh_player_panel()
	_refresh_balance()


func _on_sort_npc() -> void:
	_compact_items(_shop_work)
	_shop_work.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return PickableItemDef.get_display_name(int(a["type"])) \
				< PickableItemDef.get_display_name(int(b["type"])))
	_refresh_npc_panel()
	_refresh_balance()


## Move player item to first matching slot (merge) or end of NPC inventory.
func _auto_move_player_to_npc(player_idx: int) -> void:
	if player_idx < 0 or player_idx >= _player_work.size():
		return
	var src_type: int = int(_player_work[player_idx]["type"])
	for i in range(_shop_work.size()):
		if int(_shop_work[i]["type"]) == src_type:
			_move_player_to_npc(player_idx, i)
			return
	_move_player_to_npc(player_idx, _shop_work.size())


## Move NPC item to first matching slot (merge) or end of player inventory.
func _auto_move_npc_to_player(npc_idx: int) -> void:
	if npc_idx < 0 or npc_idx >= _shop_work.size():
		return
	var src_type: int = int(_shop_work[npc_idx]["type"])
	for i in range(_player_work.size()):
		if int(_player_work[i]["type"]) == src_type:
			_move_npc_to_player(npc_idx, i)
			return
	_move_npc_to_player(npc_idx, _player_work.size())


func open(inventory: Inventory, npc: NpcMelee, player_perks: CharacterPerks = null) -> void:
	_inventory          = inventory
	_npc_id             = npc.npc_id if not npc.npc_id.is_empty() else str(hash(npc))
	_npc_name           = npc.npc_name if not npc.npc_name.is_empty() else "Brawler"
	_npc_title_lbl.text = _npc_name + "'s Shop"

	_npc_trader_level    = npc.perks.get_level(PerkDef.ID.TRADER)
	_player_trader_level = player_perks.get_level(PerkDef.ID.TRADER) if player_perks != null else 0

	var npc_badge_name := PerkDef.get_level_name(PerkDef.ID.TRADER, _npc_trader_level)
	_npc_badge_lbl.text    = "⚖ " + (npc_badge_name if not npc_badge_name.is_empty() else "No trading perk")
	_npc_badge_lbl.visible = true

	var player_badge_name := PerkDef.get_level_name(PerkDef.ID.TRADER, _player_trader_level)
	_player_badge_lbl.text    = "⚖ " + (player_badge_name if not player_badge_name.is_empty() else "No trading perk")
	_player_badge_lbl.visible = true

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(npc.npc_id) if not npc.npc_id.is_empty() else randi()

	if _npc_shop_states.has(_npc_id):
		_shop_orig = _deep_copy_items(_npc_shop_states[_npc_id])
	else:
		_shop_orig = _generate_shop_items(rng)
	_player_orig = _deep_copy_items(inventory.items)
	_shop_work   = _deep_copy_items(_shop_orig)
	_player_work = _deep_copy_items(_player_orig)

	visible           = true
	get_tree().paused = true
	_refresh()


func close() -> void:
	if not visible:
		return
	visible           = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _generate_shop_items(rng: RandomNumberGenerator) -> Array:
	_ensure_types_cache()
	var pool  := _all_pickable_types.duplicate()
	var count := rng.randi_range(3, 8)
	var result: Array = []
	while result.size() < count and not pool.is_empty():
		var idx       := rng.randi_range(0, pool.size() - 1)
		var item_type: int = int(pool[idx])
		pool.remove_at(idx)
		var max_st := PickableItemDef.max_stack_size(item_type)
		var quantity: int
		match max_st:
			4:   quantity = rng.randi_range(1, 3)
			8:   quantity = rng.randi_range(1, 5)
			16:  quantity = rng.randi_range(2, 8)
			64:  quantity = rng.randi_range(3, 20)
			100: quantity = rng.randi_range(5, 50)
			_:   quantity = 1
		result.append({"type": item_type, "count": quantity})
	result.append({"type": MapObject.Type.COIN, "count": NPC_COIN_POOL})
	return result


static func _ensure_types_cache() -> void:
	if not _all_pickable_types.is_empty():
		return
	for val in MapObject.Type.values():
		if PickableItemDef.is_pickable(val) and val != MapObject.Type.COIN:
			_all_pickable_types.append(val)


func _refresh() -> void:
	_refresh_player_panel()
	_refresh_npc_panel()
	_refresh_balance()


func _refresh_player_panel() -> void:
	_player_count_lbl.text = "%d / %d items" % [_player_work.size(), Inventory.MAX_ITEMS]
	for i in range(PLAYER_COLS * PLAYER_ROWS):
		var icon  := _player_icons[i]  as TextureRect
		var badge := _player_badges[i] as Label
		if i < _player_work.size():
			var item_type:  int = int(_player_work[i]["type"])
			var item_count: int = int(_player_work[i]["count"])
			icon.texture  = PickableItemDef.get_texture(item_type)
			badge.visible = item_count > 1
			badge.text    = str(item_count) if item_count > 1 else ""
		else:
			icon.texture  = null
			badge.visible = false


func _refresh_npc_panel() -> void:
	_npc_count_lbl.text = "%d items" % _shop_work.size()
	for i in range(NPC_PANEL_MAX):
		var icon  := _npc_icons[i]  as TextureRect
		var badge := _npc_badges[i] as Label
		if i < _shop_work.size():
			var item_type:  int = int(_shop_work[i]["type"])
			var item_count: int = int(_shop_work[i]["count"])
			icon.texture  = PickableItemDef.get_texture(item_type)
			badge.visible = item_count > 1
			badge.text    = str(item_count) if item_count > 1 else ""
		else:
			icon.texture  = null
			badge.visible = false


func _refresh_balance() -> void:
	var bal := _adjusted_balance()
	if bal > 0:
		_balance_lbl.text = "Balance: +%d coins  (offer more)" % bal
		_balance_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		_trade_btn.disabled = true
	else:
		var npc_coins := _get_npc_coins()
		var will_pay  := mini(-bal, npc_coins)
		if bal == 0:
			_balance_lbl.text = "Balance: 0 coins"
		elif will_pay < -bal:
			_balance_lbl.text = "Balance: %d coins  (NPC pays %d, %d forfeit)" \
					% [bal, will_pay, -bal - will_pay]
		else:
			_balance_lbl.text = "Balance: %d coins  (NPC pays %d)" % [bal, will_pay]
		_balance_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		_trade_btn.disabled = false


## Raw balance before margin: positive = player owes NPC, negative = NPC owes player.
func _compute_balance() -> int:
	return _array_value(_shop_orig) - _array_value(_shop_work)


## Margin-adjusted balance used for all UI and trade execution.
func _adjusted_balance() -> int:
	var raw := _compute_balance()
	if raw == 0:
		return 0
	if raw < 0:
		# NPC pays player (player sold items) — margin reduces payout.
		var f := PerkDef.trader_sell_factor(_player_trader_level, _npc_trader_level)
		return -maxi(1, ceili(-raw * f))
	else:
		# Player pays NPC (player bought items) — margin increases cost.
		var f := PerkDef.trader_buy_factor(_player_trader_level, _npc_trader_level)
		return maxi(1, ceili(raw * f))


func _array_value(arr: Array) -> int:
	var total := 0
	for slot in arr:
		total += PickableItemDef.get_coin_value(int(slot["type"])) * int(slot["count"])
	return total


func _get_npc_coins() -> int:
	var total := 0
	for slot in _shop_work:
		if int(slot["type"]) == MapObject.Type.COIN:
			total += int(slot["count"])
	return total


static func _deep_copy_items(arr: Array) -> Array:
	var copy: Array = []
	for slot in arr:
		copy.append({"type": int(slot["type"]), "count": int(slot["count"])})
	return copy


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
	for k in range(arr.size() - 1, -1, -1):
		if int(arr[k]["count"]) <= 0:
			arr.remove_at(k)


func _pay_npc_coins_to_player(amount: int) -> void:
	var remaining := amount
	var i := 0
	while i < _shop_work.size() and remaining > 0:
		if int(_shop_work[i]["type"]) == MapObject.Type.COIN:
			var available: int = int(_shop_work[i]["count"])
			var take           := mini(remaining, available)
			_add_coins_to_player(take)
			_shop_work[i]["count"] = available - take
			remaining -= take
			if int(_shop_work[i]["count"]) <= 0:
				_shop_work.remove_at(i)
			else:
				i += 1
		else:
			i += 1


func _add_coins_to_player(amount: int) -> void:
	var remaining := amount
	var max_st    := PickableItemDef.max_stack_size(MapObject.Type.COIN)
	for i in range(_player_work.size()):
		if remaining <= 0:
			break
		if int(_player_work[i]["type"]) == MapObject.Type.COIN:
			var space := max_st - int(_player_work[i]["count"])
			var add   := mini(remaining, space)
			_player_work[i]["count"] = int(_player_work[i]["count"]) + add
			remaining -= add
	while remaining > 0 and _player_work.size() < Inventory.MAX_ITEMS:
		var add := mini(remaining, max_st)
		_player_work.append({"type": MapObject.Type.COIN, "count": add})
		remaining -= add


func _move_player_to_player(src: int, dst: int) -> void:
	if src == dst or src < 0 or src >= _player_work.size():
		return
	if dst < _player_work.size():
		var tmp: Dictionary = _player_work[src]
		_player_work[src]   = _player_work[dst]
		_player_work[dst]   = tmp
	else:
		var item: Dictionary = _player_work[src]
		_player_work.remove_at(src)
		_player_work.append(item)


func _move_npc_to_npc(src: int, dst: int) -> void:
	if src == dst or src < 0 or src >= _shop_work.size():
		return
	if dst < _shop_work.size():
		var tmp: Dictionary = _shop_work[src]
		_shop_work[src]     = _shop_work[dst]
		_shop_work[dst]     = tmp
	else:
		var item: Dictionary = _shop_work[src]
		_shop_work.remove_at(src)
		_shop_work.append(item)


## Move any item from player panel to NPC panel.
## Coins merge into NPC coin pile without cap; other items swap or append.
func _move_player_to_npc(player_idx: int, npc_idx: int) -> void:
	if player_idx < 0 or player_idx >= _player_work.size():
		return
	var src_type:  int = int(_player_work[player_idx]["type"])
	var src_count: int = int(_player_work[player_idx]["count"])

	if src_type == MapObject.Type.COIN:
		for i in range(_shop_work.size()):
			if int(_shop_work[i]["type"]) == MapObject.Type.COIN:
				_shop_work[i]["count"] = int(_shop_work[i]["count"]) + src_count
				_player_work.remove_at(player_idx)
				return
		if _shop_work.size() < NPC_PANEL_MAX:
			_shop_work.append({"type": MapObject.Type.COIN, "count": src_count})
			_player_work.remove_at(player_idx)
		return

	if npc_idx < _shop_work.size():
		var dst_type: int = int(_shop_work[npc_idx]["type"])
		if dst_type == src_type:
			_shop_work[npc_idx]["count"] = int(_shop_work[npc_idx]["count"]) + src_count
			_player_work.remove_at(player_idx)
		else:
			var dst: Dictionary      = _shop_work[npc_idx]
			_shop_work[npc_idx]      = {"type": src_type, "count": src_count}
			_player_work[player_idx] = dst
	else:
		if _shop_work.size() < NPC_PANEL_MAX:
			_shop_work.append({"type": src_type, "count": src_count})
			_player_work.remove_at(player_idx)


## Move NPC item/coins to player panel. Player-side stack limits apply.
func _move_npc_to_player(npc_idx: int, player_idx: int) -> void:
	if npc_idx < 0 or npc_idx >= _shop_work.size():
		return
	var src_type:  int = int(_shop_work[npc_idx]["type"])
	var src_count: int = int(_shop_work[npc_idx]["count"])

	if player_idx < _player_work.size():
		var dst_type: int = int(_player_work[player_idx]["type"])
		if dst_type == src_type:
			var max_st := PickableItemDef.max_stack_size(src_type)
			var space  := max_st - int(_player_work[player_idx]["count"])
			var move   := mini(src_count, space)
			if move <= 0:
				return
			_player_work[player_idx]["count"] = int(_player_work[player_idx]["count"]) + move
			_shop_work[npc_idx]["count"]      = src_count - move
			if int(_shop_work[npc_idx]["count"]) <= 0:
				_shop_work.remove_at(npc_idx)
		else:
			var dst: Dictionary      = _player_work[player_idx]
			_player_work[player_idx] = {"type": src_type, "count": src_count}
			_shop_work[npc_idx]      = dst
	else:
		if _player_work.size() < Inventory.MAX_ITEMS:
			var max_st    := PickableItemDef.max_stack_size(src_type)
			var add_count := mini(src_count, max_st)
			_player_work.append({"type": src_type, "count": add_count})
			_shop_work[npc_idx]["count"] = src_count - add_count
			if int(_shop_work[npc_idx]["count"]) <= 0:
				_shop_work.remove_at(npc_idx)


## Take `take` items from NPC slot and add them to a player slot (no swap).
func _split_npc_to_player(npc_idx: int, player_idx: int, take: int) -> void:
	if npc_idx < 0 or npc_idx >= _shop_work.size():
		return
	var src_type:  int = int(_shop_work[npc_idx]["type"])
	var src_count: int = int(_shop_work[npc_idx]["count"])
	take = mini(take, src_count)
	if take <= 0:
		return
	var max_st := PickableItemDef.max_stack_size(src_type)
	if player_idx < _player_work.size():
		if int(_player_work[player_idx]["type"]) != src_type:
			return
		var space := max_st - int(_player_work[player_idx]["count"])
		var add   := mini(take, space)
		if add <= 0:
			return
		_player_work[player_idx]["count"] = int(_player_work[player_idx]["count"]) + add
		_shop_work[npc_idx]["count"]      = src_count - add
		if int(_shop_work[npc_idx]["count"]) <= 0:
			_shop_work.remove_at(npc_idx)
	else:
		if _player_work.size() >= Inventory.MAX_ITEMS:
			return
		var add := mini(take, max_st)
		_player_work.append({"type": src_type, "count": add})
		_shop_work[npc_idx]["count"] = src_count - add
		if int(_shop_work[npc_idx]["count"]) <= 0:
			_shop_work.remove_at(npc_idx)


## Take `take` items from player slot and add them to NPC slot (no swap).
func _split_player_to_npc(player_idx: int, npc_idx: int, take: int) -> void:
	if player_idx < 0 or player_idx >= _player_work.size():
		return
	var src_type:  int = int(_player_work[player_idx]["type"])
	var src_count: int = int(_player_work[player_idx]["count"])
	take = mini(take, src_count)
	if take <= 0:
		return
	if npc_idx < _shop_work.size():
		if int(_shop_work[npc_idx]["type"]) != src_type:
			return
		_shop_work[npc_idx]["count"]      = int(_shop_work[npc_idx]["count"]) + take
		_player_work[player_idx]["count"] = src_count - take
		if int(_player_work[player_idx]["count"]) <= 0:
			_player_work.remove_at(player_idx)
	else:
		if _shop_work.size() >= NPC_PANEL_MAX:
			return
		_shop_work.append({"type": src_type, "count": take})
		_player_work[player_idx]["count"] = src_count - take
		if int(_player_work[player_idx]["count"]) <= 0:
			_player_work.remove_at(player_idx)


static func get_shop_states() -> Dictionary:
	return _npc_shop_states


static func set_shop_states(data: Dictionary) -> void:
	_npc_shop_states = data
