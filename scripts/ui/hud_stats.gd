class_name HudStats
extends CanvasLayer

var _stats: HeroStats = null

var _hp_bar:  ProgressBar = null
var _mp_bar:  ProgressBar = null
var _xp_bar:  ProgressBar = null
var _hp_lbl:  Label       = null
var _mp_lbl:  Label       = null
var _xp_lbl:  Label       = null
var _lv_lbl:  Label       = null


func setup(stats: HeroStats) -> void:
	_stats = stats
	_stats.changed.connect(_refresh)
	_refresh()


func _ready() -> void:
	layer = 55
	_build_ui()


func _refresh() -> void:
	if _stats == null:
		return
	_hp_bar.max_value = _stats.max_hp
	_hp_bar.value     = _stats.current_hp
	_hp_lbl.text      = "%d/%d" % [_stats.current_hp, _stats.max_hp]

	_mp_bar.max_value = _stats.max_mana
	_mp_bar.value     = _stats.current_mana
	_mp_lbl.text      = "%d/%d" % [_stats.current_mana, _stats.max_mana]

	_xp_bar.max_value = _stats.xp_to_next()
	_xp_bar.value     = _stats.xp
	_xp_lbl.text      = "%d/%d XP" % [_stats.xp, _stats.xp_to_next()]

	_lv_lbl.text = "Lv.%d" % _stats.level


func _build_ui() -> void:
	var anchor := Control.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	anchor.offset_left = 10
	anchor.offset_top  = 10
	add_child(anchor)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	anchor.add_child(vbox)

	# HP row
	var hp_row := _make_row()
	vbox.add_child(hp_row)

	var hp_icon := Label.new()
	hp_icon.text = "HP"
	hp_icon.add_theme_font_size_override("font_size", 11)
	hp_icon.add_theme_color_override("font_color", Color(0.90, 0.35, 0.35))
	hp_icon.custom_minimum_size = Vector2(20, 0)
	hp_row.add_child(hp_icon)

	_hp_bar = _make_bar(Color(0.85, 0.20, 0.15), Color(0.18, 0.08, 0.08))
	hp_row.add_child(_hp_bar)

	_hp_lbl = _make_val_label()
	hp_row.add_child(_hp_lbl)

	# MP row
	var mp_row := _make_row()
	vbox.add_child(mp_row)

	var mp_icon := Label.new()
	mp_icon.text = "MP"
	mp_icon.add_theme_font_size_override("font_size", 11)
	mp_icon.add_theme_color_override("font_color", Color(0.35, 0.55, 0.95))
	mp_icon.custom_minimum_size = Vector2(20, 0)
	mp_row.add_child(mp_icon)

	_mp_bar = _make_bar(Color(0.20, 0.45, 0.90), Color(0.06, 0.10, 0.20))
	mp_row.add_child(_mp_bar)

	_mp_lbl = _make_val_label()
	mp_row.add_child(_mp_lbl)

	# XP row (wider, with level)
	var xp_row := _make_row()
	vbox.add_child(xp_row)

	_lv_lbl = Label.new()
	_lv_lbl.text = "Lv.1"
	_lv_lbl.add_theme_font_size_override("font_size", 11)
	_lv_lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.30))
	_lv_lbl.custom_minimum_size = Vector2(32, 0)
	xp_row.add_child(_lv_lbl)

	_xp_bar = _make_bar(Color(0.80, 0.70, 0.10), Color(0.12, 0.10, 0.03))
	xp_row.add_child(_xp_bar)

	_xp_lbl = _make_val_label()
	xp_row.add_child(_xp_lbl)


static func _make_row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("h_separation", 5)
	return h


static func _make_bar(fill_color: Color, bg_color: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(100, 12)
	pb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(2)
	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_color
	bg.border_color = Color(0, 0, 0, 0.50)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(2)
	pb.add_theme_stylebox_override("fill",       fill)
	pb.add_theme_stylebox_override("background", bg)
	return pb


static func _make_val_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color",       Color(0.85, 0.87, 0.85))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.custom_minimum_size = Vector2(52, 0)
	return l
