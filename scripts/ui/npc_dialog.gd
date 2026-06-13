class_name NpcDialog
extends CanvasLayer

var _overlay:      Control       = null
var _title:        Label         = null
var _menu_box:     VBoxContainer = null
var _speech_box:   VBoxContainer = null
var _speech_label: Label         = null
var _open:         bool          = false
var _npc:          Node2D        = null
## Visited options per NPC: "x,y" position key → {label: true}
var _visited:      Dictionary    = {}


func _ready() -> void:
	layer        = 65
	process_mode = Node.PROCESS_MODE_ALWAYS

	var dim := ColorRect.new()
	dim.color        = Color(0, 0, 0, 0.50)
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	panel.process_mode        = Node.PROCESS_MODE_ALWAYS
	panel.add_theme_stylebox_override("panel", _make_style())
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(_title)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	vbox.add_child(sep)

	# Menu panel — buttons are rebuilt per NPC type on each open().
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_menu_box)

	# Speech panel — shown when NPC is "talking".
	_speech_box = VBoxContainer.new()
	_speech_box.add_theme_constant_override("separation", 12)
	_speech_box.visible = false
	vbox.add_child(_speech_box)

	_speech_label = Label.new()
	_speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_speech_label.custom_minimum_size = Vector2(352, 0)
	_speech_label.add_theme_font_size_override("font_size", 14)
	_speech_label.add_theme_color_override("font_color", Color(0.88, 0.92, 0.88))
	_speech_box.add_child(_speech_label)

	var continue_btn := _make_button("Continue...")
	continue_btn.pressed.connect(_show_menu)
	var italic_font := SystemFont.new()
	italic_font.font_italic = true
	continue_btn.add_theme_font_override("font", italic_font)
	continue_btn.add_theme_color_override("font_color",         Color(0.42, 0.58, 0.82))
	continue_btn.add_theme_color_override("font_hover_color",   Color(0.58, 0.72, 0.95))
	continue_btn.add_theme_color_override("font_pressed_color", Color(0.32, 0.46, 0.68))
	_speech_box.add_child(continue_btn)

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
	_npc              = npc
	_open             = true
	_title.text       = _npc_label(npc)
	_overlay.visible  = true
	get_tree().paused = true
	_build_menu(npc)
	_show_menu()


func close() -> void:
	_open             = false
	_overlay.visible  = false
	get_tree().paused = false


# ── Private ───────────────────────────────────────────────────────────────────

func get_visited_data() -> Dictionary:
	return _visited


func set_visited_data(data: Dictionary) -> void:
	_visited = data


func _build_menu(npc: Node2D) -> void:
	for child in _menu_box.get_children():
		child.queue_free()

	var _id: Variant = npc.get("npc_id")
	var key := str(_id) if _id != null else ""
	if key.is_empty():
		key = "%d,%d" % [roundi(npc.position.x), roundi(npc.position.y)]
	if not _visited.has(key):
		_visited[key] = {}

	_add_menu_btn("1.  Hello", _on_hello, key)

	if npc is NpcMelee:
		_add_menu_btn("2.  What is thy wisdom, o wise one?", _on_wisdom, key)
		_add_menu_btn("3.  Goodbye", close, key)
	else:
		_add_menu_btn("2.  Goodbye", close, key)


func _show_menu() -> void:
	_menu_box.visible   = true
	_speech_box.visible = false


func _show_speech(text: String) -> void:
	_speech_label.text  = text
	_menu_box.visible   = false
	_speech_box.visible = true


func _on_hello() -> void:
	var lines_melee := [
		"Ey! What d'ya want?",
		"Hmph. A visitor.",
		"Don't waste my time, traveler.",
		"Yeah? Speak.",
	]
	var lines_knight := [
		"Greetings, adventurer. May your path be clear.",
		"Well met, traveler.",
		"Hail! What brings you here?",
		"I stand guard. What do you need?",
	]
	if _npc is NpcMelee:
		_show_speech(lines_melee[randi() % lines_melee.size()])
	else:
		_show_speech(lines_knight[randi() % lines_knight.size()])


func _on_wisdom() -> void:
	_show_speech(FortuneLoader.get_random())


func _add_menu_btn(label: String, cb: Callable, npc_key: String) -> void:
	var btn := _make_button(label)
	if (_visited.get(npc_key, {}) as Dictionary).has(label):
		btn.add_theme_color_override("font_color", Color(0.45, 0.45, 0.50))
	btn.pressed.connect(func():
		(_visited[npc_key] as Dictionary)[label] = true
		btn.add_theme_color_override("font_color", Color(0.45, 0.45, 0.50))
		cb.call()
	)
	_menu_box.add_child(btn)


func _make_button(label: String) -> Button:
	var btn := Button.new()
	btn.text                = label
	btn.alignment           = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(352, 44)
	btn.add_theme_font_size_override("font_size", 16)
	btn.process_mode        = Node.PROCESS_MODE_ALWAYS
	return btn


static func _npc_label(npc: Node2D) -> String:
	if npc is NpcKnight:
		return "Knight"
	if npc is NpcMelee:
		return "Brawler"
	return "Stranger"


func _make_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color            = Color(0.06, 0.06, 0.10, 0.92)
	s.border_width_left   = 2; s.border_width_right  = 2
	s.border_width_top    = 2; s.border_width_bottom = 2
	s.border_color        = Color(0.4, 0.4, 0.5, 0.8)
	s.corner_radius_top_left    = 6; s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
	s.set_content_margin_all(24)
	return s
