extends Control

const MAIN_SCENE            := "res://scenes/main.tscn"
const DEFAULT_MASTER_VOLUME := 0.5

@onready var _vbox:         VBoxContainer = $VBox
@onready var _btn_continue: Button        = $VBox/BtnContinue
@onready var _btn_new:      Button        = $VBox/BtnNew
@onready var _btn_options:  Button        = $VBox/BtnOptions
@onready var _btn_quit:     Button        = $VBox/BtnQuit

var _options_panel: PanelContainer = null
var _volume_slider: HSlider        = null
var _volume_label:  Label          = null


func _ready() -> void:
	_btn_continue.disabled = not SaveManager.has_save()
	_btn_new.pressed.connect(_on_new_game)
	_btn_continue.pressed.connect(_on_continue)
	_btn_options.pressed.connect(_on_options)
	_btn_quit.pressed.connect(_on_quit)

	_build_options_panel()
	_build_version_label()

	var settings := SaveManager.load_settings()
	var vol      := float(settings.get("master_volume", DEFAULT_MASTER_VOLUME))
	_apply_master_volume(vol)
	_volume_slider.value = vol * 100.0
	_update_volume_label(vol * 100.0)


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


func _on_volume_changed(value: float) -> void:
	_update_volume_label(value)
	var vol := value / 100.0
	_apply_master_volume(vol)
	SaveManager.save_settings(vol)


func _update_volume_label(value: float) -> void:
	_volume_label.text = "Master Volume:  %d%%" % int(value)


func _apply_master_volume(linear: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(linear))


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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)

	_volume_label = Label.new()
	_volume_label.custom_minimum_size = Vector2(240, 0)
	_volume_label.add_theme_font_size_override("font_size", 18)
	row.add_child(_volume_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value           = 0.0
	_volume_slider.max_value           = 100.0
	_volume_slider.step                = 1.0
	_volume_slider.custom_minimum_size = Vector2(220, 0)
	_volume_slider.value_changed.connect(_on_volume_changed)
	row.add_child(_volume_slider)

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
