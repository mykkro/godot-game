class_name ClockUI
extends CanvasLayer

var _date_label: Label = null
var _time_label: Label = null


func _ready() -> void:
	layer        = 20
	process_mode = Node.PROCESS_MODE_ALWAYS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.82)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	style.border_color = Color(0.35, 0.35, 0.45, 0.8)
	for c in range(4):
		style.set_corner_radius(c, 5)
	style.set_content_margin_all(8)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left   = -224
	panel.offset_top    =    8
	panel.offset_right  =   -8
	panel.offset_bottom =   72
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	_date_label = Label.new()
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date_label.add_theme_font_size_override("font_size", 13)
	_date_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(_date_label)

	_time_label = Label.new()
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 16)
	_time_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	vbox.add_child(_time_label)

	GameClock.time_changed.connect(_on_time_changed)
	_on_time_changed()


func _on_time_changed() -> void:
	var dt := GameClock.get_date_time()
	_date_label.text = "%s, %d%s %s, Yr %d" % [
		dt["weekday_name"],
		dt["day"],
		_ordinal_suffix(dt["day"]),
		dt["month_name"],
		dt["year"],
	]
	_time_label.text = "%d:%02d %s" % [dt["hour12"], dt["minute"], dt["am_pm"]]


static func _ordinal_suffix(n: int) -> String:
	if n == 11 or n == 12 or n == 13:
		return "th"
	match n % 10:
		1: return "st"
		2: return "nd"
		3: return "rd"
	return "th"
