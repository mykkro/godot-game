extends Control

const MAIN_SCENE       := "res://scenes/main.tscn"
const MAP_EDITOR_SCENE := "res://scenes/map_editor.tscn"

const RESOLUTIONS := [
	Vector2i(1280,  720),
	Vector2i(1600,  900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

@onready var _vbox:           VBoxContainer = $VBox
@onready var _btn_continue:   Button        = $VBox/BtnContinue
@onready var _btn_new:        Button        = $VBox/BtnNew
@onready var _btn_options:    Button        = $VBox/BtnOptions
@onready var _btn_map_editor: Button        = $VBox/BtnMapEditor
@onready var _btn_quit:       Button        = $VBox/BtnQuit

var _options_panel:   PanelContainer = null
var _master_slider:   HSlider        = null
var _master_label:    Label          = null
var _music_slider:    HSlider        = null
var _music_label:     Label          = null
var _effects_slider:  HSlider        = null
var _effects_label:   Label          = null
var _fullscreen_btn:  CheckButton    = null
var _resolution_opt:  OptionButton   = null

var _master_vol:     float = AudioManager.DEFAULT_MASTER_VOLUME
var _music_vol:      float = AudioManager.DEFAULT_MUSIC_VOLUME
var _effects_vol:    float = AudioManager.DEFAULT_EFFECTS_VOLUME
var _fullscreen:     bool  = false
var _resolution_idx: int   = 2  # default 1920×1080


func _ready() -> void:
	_btn_continue.disabled = not SaveManager.has_save()
	_btn_new.pressed.connect(_on_new_game)
	_btn_continue.pressed.connect(_on_continue)
	_btn_options.pressed.connect(_on_options)
	_btn_map_editor.pressed.connect(_on_map_editor)
	_btn_quit.pressed.connect(_on_quit)

	_build_options_panel()
	_build_version_label()

	var settings := AudioManager.apply_saved_settings()
	_master_vol  = float(settings.get("master_volume",  AudioManager.DEFAULT_MASTER_VOLUME))
	_music_vol   = float(settings.get("music_volume",   AudioManager.DEFAULT_MUSIC_VOLUME))
	_effects_vol = float(settings.get("effects_volume", AudioManager.DEFAULT_EFFECTS_VOLUME))
	_master_slider.value  = _master_vol  * 100.0
	_music_slider.value   = _music_vol   * 100.0
	_effects_slider.value = _effects_vol * 100.0
	_update_label(_master_label,  "Master Volume",  _master_vol  * 100.0)
	_update_label(_music_label,   "Music Volume",   _music_vol   * 100.0)
	_update_label(_effects_label, "Effects Volume", _effects_vol * 100.0)

	_fullscreen     = bool(settings.get("fullscreen",      false))
	_resolution_idx = int(settings.get("resolution_index", 2))
	_fullscreen_btn.button_pressed = _fullscreen
	_resolution_opt.select(_resolution_idx)
	_resolution_opt.disabled = _fullscreen
	_apply_video_settings()


func _on_new_game() -> void:
	SaveManager.wipe()
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_continue() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_options() -> void:
	_vbox.visible          = false
	_options_panel.visible = true


func _on_options_back() -> void:
	_options_panel.visible = false
	_vbox.visible          = true


func _on_map_editor() -> void:
	get_tree().change_scene_to_file(MAP_EDITOR_SCENE)


func _on_quit() -> void:
	get_tree().quit()


func _on_master_changed(value: float) -> void:
	_master_vol = value / 100.0
	AudioManager.set_master_volume(_master_vol)
	_update_label(_master_label, "Master Volume", value)
	_save_settings()


func _on_music_changed(value: float) -> void:
	_music_vol = value / 100.0
	AudioManager.set_music_volume(_music_vol)
	_update_label(_music_label, "Music Volume", value)
	_save_settings()


func _on_effects_changed(value: float) -> void:
	_effects_vol = value / 100.0
	AudioManager.set_effects_volume(_effects_vol)
	_update_label(_effects_label, "Effects Volume", value)
	_save_settings()


func _on_fullscreen_toggled(pressed: bool) -> void:
	_fullscreen = pressed
	_resolution_opt.disabled = pressed
	_apply_video_settings()
	_save_settings()


func _on_resolution_changed(index: int) -> void:
	_resolution_idx = index
	if not _fullscreen:
		_apply_video_settings()
	_save_settings()


func _apply_video_settings() -> void:
	if _fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(RESOLUTIONS[_resolution_idx])


func _save_settings() -> void:
	SaveManager.save_settings(_master_vol, _music_vol, _effects_vol, _fullscreen, _resolution_idx)


func _update_label(lbl: Label, name: String, value: float) -> void:
	lbl.text = "%s:  %d%%" % [name, int(value)]


func _build_options_panel() -> void:
	_options_panel = PanelContainer.new()
	_options_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.07, 0.12, 1.0)
	_options_panel.add_theme_stylebox_override("panel", bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_options_panel.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(500, 0)
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(title)

	# ── Audio ──────────────────────────────────────────────────────────────────
	var audio_section := Label.new()
	audio_section.text = "Audio"
	audio_section.add_theme_font_size_override("font_size", 22)
	audio_section.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	vbox.add_child(audio_section)

	var sliders := [
		["Master Volume",  _on_master_changed],
		["Music Volume",   _on_music_changed],
		["Effects Volume", _on_effects_changed],
	]
	for entry in sliders:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		vbox.add_child(row)

		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(240, 0)
		lbl.add_theme_font_size_override("font_size", 18)
		row.add_child(lbl)

		var slider := HSlider.new()
		slider.min_value           = 0.0
		slider.max_value           = 100.0
		slider.step                = 1.0
		slider.custom_minimum_size = Vector2(220, 0)
		slider.value_changed.connect((entry as Array)[1] as Callable)
		row.add_child(slider)

		match (entry as Array)[0]:
			"Master Volume":  _master_label  = lbl; _master_slider  = slider
			"Music Volume":   _music_label   = lbl; _music_slider   = slider
			"Effects Volume": _effects_label = lbl; _effects_slider = slider

	# ── Video ──────────────────────────────────────────────────────────────────
	var video_section := Label.new()
	video_section.text = "Video"
	video_section.add_theme_font_size_override("font_size", 22)
	video_section.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	vbox.add_child(video_section)

	var fs_row := HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 16)
	vbox.add_child(fs_row)

	var fs_lbl := Label.new()
	fs_lbl.text = "Fullscreen"
	fs_lbl.custom_minimum_size = Vector2(240, 0)
	fs_lbl.add_theme_font_size_override("font_size", 18)
	fs_row.add_child(fs_lbl)

	_fullscreen_btn = CheckButton.new()
	_fullscreen_btn.toggled.connect(_on_fullscreen_toggled)
	fs_row.add_child(_fullscreen_btn)

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 16)
	vbox.add_child(res_row)

	var res_lbl := Label.new()
	res_lbl.text = "Resolution"
	res_lbl.custom_minimum_size = Vector2(240, 0)
	res_lbl.add_theme_font_size_override("font_size", 18)
	res_row.add_child(res_lbl)

	_resolution_opt = OptionButton.new()
	_resolution_opt.custom_minimum_size = Vector2(160, 0)
	_resolution_opt.add_theme_font_size_override("font_size", 17)
	for res in RESOLUTIONS:
		_resolution_opt.add_item("%d × %d" % [res.x, res.y])
	_resolution_opt.item_selected.connect(_on_resolution_changed)
	res_row.add_child(_resolution_opt)

	# ── Back ───────────────────────────────────────────────────────────────────
	var btn_back := Button.new()
	btn_back.text = "Back"
	btn_back.custom_minimum_size = Vector2(240, 52)
	btn_back.add_theme_font_size_override("font_size", 20)
	btn_back.pressed.connect(_on_options_back)
	vbox.add_child(btn_back)

	_options_panel.visible = false
	add_child(_options_panel)


func _build_version_label() -> void:
	var ver := "v?"
	var f := FileAccess.open("res://VERSION", FileAccess.READ)
	if f != null:
		ver = "v" + f.get_as_text().strip_edges()
		f.close()

	var lbl := Label.new()
	lbl.text = ver
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lbl.offset_left   = 10
	lbl.offset_top    = -28
	lbl.offset_right  = 80
	lbl.offset_bottom = -8
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	add_child(lbl)
