class_name CharacterUI
extends CanvasLayer

const COLS       := 10
const ROWS       := 5
const SLOT_SIZE  := 32
const SLOT_SEP   := 3

var _avatar:   Avatar = null
var _open_flag: bool  = false

var _panel:           PanelContainer = null
var _name_lbl:        Label          = null
var _time_lbl:        Label          = null
var _gold_lbl:        Label          = null
var _perks_vbox:      VBoxContainer  = null
var _stats_vbox:      VBoxContainer  = null
var _inv_grid:        GridContainer  = null
var _inv_icons:       Array          = []   # Array[TextureRect]
var _belt_icons:      Array          = []   # Array[TextureRect]
var _belt_badges:     Array          = []   # Array[Label]
var _knight:          KnightSprite   = null


func setup(avatar: Avatar) -> void:
	_avatar = avatar


func _ready() -> void:
	layer        = 76
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Dim backdrop.
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.60)
	root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	_panel = _make_outer_panel()
	center.add_child(_panel)

	_build_content()

	root.visible = false
	_open_flag   = false

	_knight.update_anim.call_deferred(true, PI / 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if ke.echo or not ke.pressed:
		return

	if _open_flag:
		if ke.keycode == KEY_C or ke.keycode == KEY_ESCAPE:
			_close()
		get_viewport().set_input_as_handled()
		return

	if ke.keycode == KEY_C and not get_tree().paused:
		_open()
		get_viewport().set_input_as_handled()


# ── Private ──────────────────────────────────────────────────────────────────

func _open() -> void:
	if _avatar == null:
		return
	_open_flag = true
	get_child(0).visible = true
	get_tree().paused    = true
	_refresh()


func _close() -> void:
	_open_flag = false
	get_child(0).visible = false
	get_tree().paused    = false


func _refresh() -> void:
	if _avatar == null:
		return

	_name_lbl.text = _avatar.char_name if not _avatar.char_name.is_empty() else "Unknown"
	_time_lbl.text = "Time in world:  " + _format_elapsed(
			GameClock.get_game_time() - _avatar.char_birth_time)
	_gold_lbl.text = "Gold:  %d coins" % _count_gold()

	_refresh_perks()
	_refresh_battle_stats()
	_refresh_inventory()
	_refresh_belt()


func _refresh_perks() -> void:
	for child in _perks_vbox.get_children():
		child.queue_free()

	var any_perk := false
	for key in PerkDef.ID:
		var id: PerkDef.ID = PerkDef.ID[key]
		var lv := _avatar.perks.get_level(id)
		if lv > 0:
			var lbl := Label.new()
			lbl.text = "⚖  " + PerkDef.get_level_name(id, lv)
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.add_theme_color_override("font_color", Color(0.85, 0.72, 0.35))
			_perks_vbox.add_child(lbl)
			any_perk = true

	if not any_perk:
		var lbl := Label.new()
		lbl.text = "None"
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
		_perks_vbox.add_child(lbl)


func _refresh_battle_stats() -> void:
	for c in _stats_vbox.get_children():
		c.queue_free()
	var s := _avatar.stats
	var entries: Array = [
		["Level",   str(s.level)],
		["XP",      "%d / %d" % [s.xp, s.xp_to_next()]],
		["HP",      "%d / %d" % [s.current_hp, s.max_hp]],
		["Mana",    "%d / %d" % [s.current_mana, s.max_mana]],
		["Attack",  str(s.attack)],
		["Magic",   str(s.magic)],
		["Defense", str(s.defense)],
	]
	for entry in entries:
		var lbl := Label.new()
		lbl.text = "%-10s %s" % [entry[0], entry[1]]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.90))
		_stats_vbox.add_child(lbl)


func _refresh_inventory() -> void:
	var inv := _avatar.inventory
	for i in range(ROWS * COLS):
		var icon := _inv_icons[i] as TextureRect
		if i < inv.count():
			icon.texture = PickableItemDef.get_texture(inv.get_type(i))
		else:
			icon.texture = null


func _refresh_belt() -> void:
	var belt := _avatar.belt
	for i in Belt.SLOT_COUNT:
		var icon  := _belt_icons[i]  as TextureRect
		var badge := _belt_badges[i] as Label
		if belt.has_item(i):
			icon.texture = PickableItemDef.get_texture(belt.get_type(i))
			var cnt := belt.get_count(i)
			if cnt > 1:
				badge.text    = str(cnt)
				badge.visible = true
			else:
				badge.visible = false
		else:
			icon.texture  = null
			badge.visible = false


func _count_gold() -> int:
	var total := 0
	var inv   := _avatar.inventory
	for i in range(inv.count()):
		if inv.get_type(i) == MapObject.Type.COIN:
			total += inv.get_count(i)
	return total


static func _format_elapsed(elapsed: float) -> String:
	if elapsed <= 0.0:
		return "just arrived"
	var mins  := int(elapsed / 60.0) % 60
	var hours := int(elapsed / 3600.0) % 24
	var days  := int(elapsed / 86400.0)
	if days >= 360:
		var years     := days / 360
		var rem_days  := days % 360
		return "%d year%s, %d day%s" % [
			years, "s" if years > 1 else "",
			rem_days, "s" if rem_days != 1 else ""]
	if days > 0:
		return "%d day%s, %dh %dm" % [days, "s" if days != 1 else "", hours, mins]
	if hours > 0:
		return "%dh %dm" % [hours, mins]
	return "%d minute%s" % [maxi(mins, 1), "s" if mins != 1 else ""]


# ── UI builders ──────────────────────────────────────────────────────────────

func _build_content() -> void:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	_panel.add_child(outer)

	# ── Character name header ──
	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 26)
	_name_lbl.add_theme_color_override("font_color", Color(0.92, 0.86, 0.68))
	_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(_name_lbl)

	outer.add_child(_hsep())

	# ── Avatar + stats row ──
	var mid_hbox := HBoxContainer.new()
	mid_hbox.add_theme_constant_override("h_separation", 24)
	outer.add_child(mid_hbox)

	mid_hbox.add_child(_build_avatar_column())
	mid_hbox.add_child(_build_stats_column())

	outer.add_child(_hsep())

	# ── Inventory ──
	var inv_lbl := _section_label("Inventory")
	outer.add_child(inv_lbl)

	_inv_grid = GridContainer.new()
	_inv_grid.columns = COLS
	_inv_grid.add_theme_constant_override("h_separation", SLOT_SEP)
	_inv_grid.add_theme_constant_override("v_separation", SLOT_SEP)
	outer.add_child(_inv_grid)

	for i in range(ROWS * COLS):
		_inv_grid.add_child(_make_inv_slot())

	# ── Belt ──
	outer.add_child(_section_label("Belt"))

	var belt_hbox := HBoxContainer.new()
	belt_hbox.add_theme_constant_override("separation", SLOT_SEP)
	outer.add_child(belt_hbox)

	for i in Belt.SLOT_COUNT:
		belt_hbox.add_child(_make_belt_slot(i))

	# ── Close hint ──
	var hint := Label.new()
	hint.text = "C  /  Escape  —  close"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.42, 0.42, 0.52))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(hint)


func _build_avatar_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(170, 0)

	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(160, 230)
	svc.stretch = true
	col.add_child(svc)

	var sv := SubViewport.new()
	sv.size           = Vector2i(160, 230)
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(sv)

	_knight = KnightSprite.new()
	_knight.position = Vector2(80, 175)
	_knight.scale    = Vector2(2.8, 2.8)
	sv.add_child(_knight)

	return col


func _build_stats_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_time_lbl = _stat_label("")
	_gold_lbl = _stat_label("")
	col.add_child(_time_lbl)
	col.add_child(_gold_lbl)

	col.add_child(_hsep())

	col.add_child(_section_label("Battle Stats"))
	_stats_vbox = VBoxContainer.new()
	_stats_vbox.add_theme_constant_override("separation", 3)
	col.add_child(_stats_vbox)

	col.add_child(_hsep())

	col.add_child(_section_label("Active Perks"))
	_perks_vbox = VBoxContainer.new()
	_perks_vbox.add_theme_constant_override("separation", 4)
	col.add_child(_perks_vbox)

	return col


func _make_belt_slot(index: int) -> PanelContainer:
	var slot := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.10, 0.10, 0.16, 0.88)
	style.border_width_left          = 1; style.border_width_right  = 1
	style.border_width_top           = 1; style.border_width_bottom = 1
	style.border_color               = Color(0.28, 0.28, 0.38, 0.55)
	style.corner_radius_top_left     = 3; style.corner_radius_top_right    = 3
	style.corner_radius_bottom_left  = 3; style.corner_radius_bottom_right = 3
	slot.add_theme_stylebox_override("panel", style)
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	wrap.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	slot.add_child(wrap)

	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode    = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(icon)
	_belt_icons.append(icon)

	var key_lbl := Label.new()
	key_lbl.text = str(index + 1)
	key_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	key_lbl.offset_left = 1; key_lbl.offset_top    = 1
	key_lbl.offset_right = 10; key_lbl.offset_bottom = 10
	key_lbl.add_theme_font_size_override("font_size", 7)
	key_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(key_lbl)

	var badge := Label.new()
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left   = -20; badge.offset_top    = -11
	badge.offset_right  = -1;  badge.offset_bottom = -1
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.add_theme_font_size_override("font_size", 8)
	badge.add_theme_color_override("font_color",        Color(1.0, 1.0, 0.65))
	badge.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	badge.add_theme_constant_override("shadow_offset_x", 1)
	badge.add_theme_constant_override("shadow_offset_y", 1)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	wrap.add_child(badge)
	_belt_badges.append(badge)

	return slot


func _make_inv_slot() -> PanelContainer:
	var slot := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color                    = Color(0.10, 0.10, 0.16, 0.88)
	style.border_width_left           = 1
	style.border_width_right          = 1
	style.border_width_top            = 1
	style.border_width_bottom         = 1
	style.border_color                = Color(0.28, 0.28, 0.38, 0.55)
	style.corner_radius_top_left      = 3
	style.corner_radius_top_right     = 3
	style.corner_radius_bottom_left   = 3
	style.corner_radius_bottom_right  = 3
	slot.add_theme_stylebox_override("panel", style)
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	var icon := TextureRect.new()
	icon.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(icon)
	_inv_icons.append(icon)

	return slot


# ── Style helpers ─────────────────────────────────────────────────────────────

static func _make_outer_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color                    = Color(0.07, 0.07, 0.12, 0.96)
	style.border_width_left           = 2
	style.border_width_right          = 2
	style.border_width_top            = 2
	style.border_width_bottom         = 2
	style.border_color                = Color(0.42, 0.38, 0.60, 0.85)
	style.corner_radius_top_left      = 10
	style.corner_radius_top_right     = 10
	style.corner_radius_bottom_left   = 10
	style.corner_radius_bottom_right  = 10
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	return panel


static func _hsep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_color_override("color", Color(0.35, 0.35, 0.48, 0.60))
	return s


static func _stat_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.90))
	return lbl


static func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.68))
	lbl.uppercase = true
	return lbl
