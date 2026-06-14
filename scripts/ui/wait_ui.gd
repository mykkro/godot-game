class_name WaitUI
extends CanvasLayer

## Real seconds over which the time-lapse animation plays.
const ANIM_DURATION := 4.0

var _pick_box:    Control      = null
var _anim_box:    Control      = null
var _hours_lbl:   Label        = null
var _anim_lbl:    Label        = null
var _progress:    ProgressBar  = null

var _hours:        int   = 8
var _anim_active:  bool  = false
var _anim_start:   float = 0.0
var _anim_end:     float = 0.0
var _anim_elapsed: float = 0.0


func _ready() -> void:
	layer        = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible      = false
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color        = Color(0.0, 0.0, 0.0, 0.35)
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
	win_style.set_content_margin_all(24)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", win_style)
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	panel.add_child(outer)

	var title := Label.new()
	title.text                 = "Wait"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	outer.add_child(title)

	# ── Picker view ──────────────────────────────────────────────────────────
	_pick_box = VBoxContainer.new()
	(_pick_box as VBoxContainer).add_theme_constant_override("separation", 14)
	outer.add_child(_pick_box)

	var prompt := Label.new()
	prompt.text                 = "Wait for how many hours?"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 15)
	prompt.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	(_pick_box as VBoxContainer).add_child(prompt)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	(_pick_box as VBoxContainer).add_child(row)

	var dec_btn := _make_btn("◄", func() -> void: _change_hours(-1))
	row.add_child(dec_btn)

	_hours_lbl = Label.new()
	_hours_lbl.custom_minimum_size      = Vector2(100, 0)
	_hours_lbl.horizontal_alignment      = HORIZONTAL_ALIGNMENT_CENTER
	_hours_lbl.add_theme_font_size_override("font_size", 22)
	_hours_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.85))
	row.add_child(_hours_lbl)

	var inc_btn := _make_btn("►", func() -> void: _change_hours(1))
	row.add_child(inc_btn)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 14)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	(_pick_box as VBoxContainer).add_child(btns)

	btns.add_child(_make_btn("Cancel", _on_cancel))
	btns.add_child(_make_btn("Wait",   _on_wait_pressed))

	# ── Animation view ───────────────────────────────────────────────────────
	_anim_box = VBoxContainer.new()
	(_anim_box as VBoxContainer).add_theme_constant_override("separation", 14)
	_anim_box.visible = false
	outer.add_child(_anim_box)

	_anim_lbl = Label.new()
	_anim_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anim_lbl.add_theme_font_size_override("font_size", 16)
	_anim_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	(_anim_box as VBoxContainer).add_child(_anim_lbl)

	_progress = ProgressBar.new()
	_progress.min_value            = 0.0
	_progress.max_value            = 100.0
	_progress.value                = 0.0
	_progress.custom_minimum_size  = Vector2(260, 20)
	_progress.show_percentage      = false
	(_anim_box as VBoxContainer).add_child(_progress)

	_update_hours_label()


func _process(delta: float) -> void:
	if not _anim_active:
		return
	_anim_elapsed += delta
	var t := clampf(_anim_elapsed / ANIM_DURATION, 0.0, 1.0)
	GameClock.load_time(lerpf(_anim_start, _anim_end, t))
	_progress.value = t * 100.0
	var dt          := GameClock.get_date_time()
	_anim_lbl.text  = "Waiting…   %d:%02d %s" % [dt["hour12"], dt["minute"], dt["am_pm"]]
	if t >= 1.0:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_T and not visible:
		if get_tree().paused:
			return   # shop / dialog / etc. already has the game paused
		_open()
		get_viewport().set_input_as_handled()
	elif ke.keycode == KEY_ESCAPE and visible and not _anim_active:
		_on_cancel()
		get_viewport().set_input_as_handled()


func _open() -> void:
	_hours         = 8
	_anim_active   = false
	_pick_box.visible = true
	_anim_box.visible = false
	_update_hours_label()
	visible           = true
	get_tree().paused = true


func _on_cancel() -> void:
	visible           = false
	get_tree().paused = false


func _on_wait_pressed() -> void:
	_anim_start   = GameClock.get_game_time()
	_anim_end     = _anim_start + _hours * 3600.0
	_anim_elapsed = 0.0
	_anim_active  = true
	_pick_box.visible = false
	_anim_box.visible = true
	_progress.value   = 0.0


func _finish() -> void:
	_anim_active      = false
	visible           = false
	get_tree().paused = false


func _change_hours(delta: int) -> void:
	_hours = clampi(_hours + delta, 1, 24)
	_update_hours_label()


func _update_hours_label() -> void:
	_hours_lbl.text = "%d hour%s" % [_hours, "s" if _hours != 1 else ""]


func _make_btn(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text         = text
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(cb)
	return btn
