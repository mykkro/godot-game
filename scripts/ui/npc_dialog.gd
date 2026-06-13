class_name NpcDialog
extends CanvasLayer

var _overlay: Control = null
var _title:   Label   = null
var _open:    bool    = false


func _ready() -> void:
	layer        = 65
	process_mode = Node.PROCESS_MODE_ALWAYS

	var dim := ColorRect.new()
	dim.color        = Color(0, 0, 0, 0.45)
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.process_mode        = Node.PROCESS_MODE_ALWAYS
	panel.add_theme_stylebox_override("panel", _make_style())
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(_title)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	vbox.add_child(sep)

	_add_option(vbox, "Hello", close)

	dim.visible = false
	_overlay    = dim


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_ESCAPE or ke.keycode == KEY_E:
		close()
		get_viewport().set_input_as_handled()


func open(npc: Node2D) -> void:
	_open            = true
	_title.text      = _npc_label(npc)
	_overlay.visible = true
	get_tree().paused = true


func close() -> void:
	_open             = false
	_overlay.visible  = false
	get_tree().paused = false


# ── Helpers ───────────────────────────────────────────────────────────────────

func _add_option(parent: VBoxContainer, label: String, cb: Callable) -> void:
	var btn := Button.new()
	btn.text                = label
	btn.custom_minimum_size = Vector2(276, 42)
	btn.add_theme_font_size_override("font_size", 17)
	btn.process_mode        = Node.PROCESS_MODE_ALWAYS
	btn.pressed.connect(cb)
	parent.add_child(btn)


static func _npc_label(npc: Node2D) -> String:
	if npc is NpcKnight:
		return "Knight"
	if npc is NpcMelee:
		return "Brawler"
	return "Stranger"


func _make_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	s.border_width_left   = 2; s.border_width_right  = 2
	s.border_width_top    = 2; s.border_width_bottom = 2
	s.border_color        = Color(0.4, 0.4, 0.5, 0.8)
	s.corner_radius_top_left    = 6; s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
	s.set_content_margin_all(24)
	return s
