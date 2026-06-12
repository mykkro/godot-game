extends Control

const MAIN_SCENE := "res://scenes/main.tscn"

@onready var _vbox:         VBoxContainer = $VBox
@onready var _btn_continue: Button        = $VBox/BtnContinue
@onready var _btn_new:      Button        = $VBox/BtnNew
@onready var _btn_options:  Button        = $VBox/BtnOptions
@onready var _btn_quit:     Button        = $VBox/BtnQuit

var _options_panel:   PanelContainer = null
var _master_slider:   HSlider        = null
var _master_label:    Label          = null
var _music_slider:    HSlider        = null
var _music_label:     Label          = null
var _effects_slider:  HSlider        = null
var _effects_label:   Label          = null

# Current values kept in sync for SaveManager calls.
var _master_vol:  float = AudioManager.DEFAULT_MASTER_VOLUME
var _music_vol:   float = AudioManager.DEFAULT_MUSIC_VOLUME
var _effects_vol: float = AudioManager.DEFAULT_EFFECTS_VOLUME


func _ready() -> void:
	_btn_continue.disabled = not SaveManager.has_save()
	_btn_new.pressed.connect(_on_new_game)
	_btn_continue.pressed.connect(_on_continue)
	_btn_options.pressed.connect(_on_options)
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


func _on_quit() -> void:
	get_tree().quit()


func _on_master_changed(value: float) -> void:
	_master_vol = value / 100.0
	AudioManager.set_master_volume(_master_vol)
	_update_label(_master_label, "Master Volume", value)
	SaveManager.save_settings(_master_vol, _music_vol, _effects_vol)


func _on_music_changed(value: float) -> void:
	_music_vol = value / 100.0
	AudioManager.set_music_volume(_music_vol)
	_update_label(_music_label, "Music Volume", value)
	SaveManager.save_settings(_master_vol, _music_vol, _effects_vol)


func _on_effects_changed(value: float) -> void:
	_effects_vol = value / 100.0
	AudioManager.set_effects_volume(_effects_vol)
	_update_label(_effects_label, "Effects Volume", value)
	SaveManager.save_settings(_master_vol, _music_vol, _effects_vol)


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

	var section := Label.new()
	section.text = "Audio"
	section.add_theme_font_size_override("font_size", 22)
	section.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	vbox.add_child(section)

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
