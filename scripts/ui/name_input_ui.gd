class_name NameInputUI
extends CanvasLayer

signal name_confirmed(char_name: String)

var _input: LineEdit = null


func _ready() -> void:
	layer        = 98
	process_mode = Node.PROCESS_MODE_ALWAYS

	get_tree().paused = true

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := _make_panel()
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.custom_minimum_size = Vector2(380, 0)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Create Your Character"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.90, 0.85, 0.68))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Enter your name to begin:"
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.60, 0.60, 0.72))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	_input = LineEdit.new()
	_input.placeholder_text = "Your name..."
	_input.custom_minimum_size = Vector2(0, 44)
	_input.add_theme_font_size_override("font_size", 20)
	_input.max_length = 24
	_input.text_submitted.connect(_on_confirm)
	vbox.add_child(_input)

	var btn := Button.new()
	btn.text = "Begin Adventure"
	btn.custom_minimum_size = Vector2(0, 44)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(func() -> void: _on_confirm(_input.text))
	vbox.add_child(btn)

	_input.grab_focus.call_deferred()


func _on_confirm(text: String) -> void:
	var char_name := text.strip_edges()
	if char_name.is_empty():
		char_name = "Traveller"
	get_tree().paused = false
	name_confirmed.emit(char_name)
	queue_free()


static func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color              = Color(0.08, 0.08, 0.14, 0.97)
	style.border_width_left     = 2
	style.border_width_right    = 2
	style.border_width_top      = 2
	style.border_width_bottom   = 2
	style.border_color          = Color(0.50, 0.45, 0.72, 0.90)
	style.corner_radius_top_left     = 10
	style.corner_radius_top_right    = 10
	style.corner_radius_bottom_left  = 10
	style.corner_radius_bottom_right = 10
	style.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", style)
	return panel
