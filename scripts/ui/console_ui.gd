class_name ConsoleUI
extends CanvasLayer

const MAX_LINES := 6

var _output: RichTextLabel = null
var _input:  LineEdit      = null
var _lines:  Array[String] = []

var _history:     Array[String] = []
var _history_idx: int           = -1
var _input_saved: String        = ""


func _ready() -> void:
	layer        = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible      = false
	_build_ui()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	style.border_color = Color(0.35, 0.35, 0.45, 0.8)
	for c in range(4):
		style.set_corner_radius(c, 6)
	style.set_content_margin_all(10)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left   =  180
	panel.offset_top    =    8
	panel.offset_right  = -180
	panel.offset_bottom =  210
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	_output = RichTextLabel.new()
	_output.bbcode_enabled         = false
	_output.scroll_active          = false
	_output.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	_output.add_theme_font_size_override("normal_font_size", 13)
	_output.add_theme_color_override("default_color", Color(0.80, 0.85, 0.80))
	vbox.add_child(_output)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	_input = LineEdit.new()
	_input.placeholder_text = "Enter command…  (/help for list)"
	_input.add_theme_font_size_override("font_size", 14)
	_input.add_theme_color_override("font_color",                Color(1.0, 1.0, 0.9))
	_input.add_theme_color_override("font_placeholder_color",    Color(0.5, 0.5, 0.45))
	_input.add_theme_color_override("caret_color",               Color(1.0, 1.0, 0.8))
	_input.process_mode = Node.PROCESS_MODE_ALWAYS
	_input.text_submitted.connect(_on_submitted)
	_input.gui_input.connect(_on_input_key)
	vbox.add_child(_input)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_QUOTELEFT:
		visible = not visible
		if visible:
			_input.grab_focus()
		get_viewport().set_input_as_handled()
	elif ke.keycode == KEY_ESCAPE and visible:
		visible = false
		get_viewport().set_input_as_handled()


func _on_submitted(text: String) -> void:
	_input.clear()
	_input.grab_focus()
	_history_idx = -1
	_input_saved = ""
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	if _history.is_empty() or _history.back() != trimmed:
		_history.append(trimmed)
	_execute(trimmed)


func _on_input_key(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed:
		return
	if ke.keycode == KEY_UP:
		if _history.is_empty():
			return
		if _history_idx == -1:
			_input_saved  = _input.text
			_history_idx  = _history.size() - 1
		elif _history_idx > 0:
			_history_idx -= 1
		_input.text          = _history[_history_idx]
		_input.caret_column  = _input.text.length()
		_input.accept_event()
	elif ke.keycode == KEY_DOWN:
		if _history_idx == -1:
			return
		_history_idx += 1
		if _history_idx >= _history.size():
			_history_idx        = -1
			_input.text         = _input_saved
		else:
			_input.text         = _history[_history_idx]
		_input.caret_column = _input.text.length()
		_input.accept_event()


# ── Command dispatch ──────────────────────────────────────────────────────────

func _execute(text: String) -> void:
	if not text.begins_with("/"):
		_print_line("[hint] Commands start with /  — type /help for list")
		return
	var parts := text.substr(1).split(" ", false)
	if parts.is_empty():
		return
	match parts[0].to_lower():
		"set_date": _cmd_set_date(parts)
		"set_time": _cmd_set_time(parts)
		"help":     _cmd_help()
		var unknown: _print_line("Unknown command: /" + unknown)


func _cmd_help() -> void:
	_print_line("/set_date MM/DD    — set month and day (month 1-12, day 1-30)")
	_print_line("/set_time HH:MM    — set time of day in 24-hour format")


func _cmd_set_date(parts: Array) -> void:
	if parts.size() < 2:
		_print_line("Usage: /set_date MM/DD")
		return
	var tokens := (parts[1] as String).split("/")
	if tokens.size() != 2:
		_print_line("Usage: /set_date MM/DD")
		return
	var month: int = int(tokens[0])
	var day:   int = int(tokens[1])
	if month < 1 or month > 12 or day < 1 or day > 30:
		_print_line("Invalid: month 1–12, day 1–30")
		return
	var dt      := GameClock.get_date_time()
	var hour24  := _hour24(dt["hour12"], dt["am_pm"])
	var new_s   := GameClock.to_seconds(dt["year"], month - 1, day, hour24, dt["minute"])
	GameClock.load_time(new_s)
	_print_line("Date → %d %s, Year %d" % [day, GameClock.MONTH_NAMES[month - 1], dt["year"]])


func _cmd_set_time(parts: Array) -> void:
	if parts.size() < 2:
		_print_line("Usage: /set_time HH:MM")
		return
	var tokens := (parts[1] as String).split(":")
	if tokens.size() != 2:
		_print_line("Usage: /set_time HH:MM")
		return
	var hour:   int = int(tokens[0])
	var minute: int = int(tokens[1])
	if hour < 0 or hour > 23 or minute < 0 or minute > 59:
		_print_line("Invalid: HH 0–23, MM 0–59")
		return
	var dt    := GameClock.get_date_time()
	var new_s := GameClock.to_seconds(dt["year"], dt["month_idx"], dt["day"], hour, minute)
	GameClock.load_time(new_s)
	_print_line("Time → %02d:%02d" % [hour, minute])


# ── Output ────────────────────────────────────────────────────────────────────

func _print_line(msg: String) -> void:
	_lines.append(msg)
	if _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	_output.text = "\n".join(_lines)


static func _hour24(h12: int, am_pm: String) -> int:
	if am_pm == "AM":
		return 0 if h12 == 12 else h12
	return 12 if h12 == 12 else h12 + 12
