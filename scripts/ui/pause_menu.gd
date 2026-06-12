class_name PauseMenu
extends CanvasLayer

const MENU_SCENE := "res://scenes/menu.tscn"

var _fog_manager: FogManager = null
var _avatar:      Avatar     = null

var _panel:  PanelContainer = null
var _vbox:   VBoxContainer  = null


## Call from main._ready() after all other nodes are set up.
func setup(fog_manager: FogManager, avatar: Avatar) -> void:
	_fog_manager = fog_manager
	_avatar      = avatar


func _ready() -> void:
	layer = 50
	# Keep processing input even while the scene tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel = PanelContainer.new()
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	# Centre the panel on screen.
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(280, 0)

	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.06, 0.06, 0.10, 0.92)
	style.border_width_left          = 2
	style.border_width_right         = 2
	style.border_width_top           = 2
	style.border_width_bottom        = 2
	style.border_color               = Color(0.4, 0.4, 0.5, 0.8)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)

	add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(_vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	_vbox.add_child(title)

	_vbox.add_child(_make_separator())
	_add_button("Resume",        _on_resume)
	_add_button("Save & Exit",   _on_save_exit)
	_add_button("Main Menu",     _on_main_menu)
	_add_button("Exit",          _on_exit)

	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if ke.keycode == KEY_F10 and ke.pressed and not ke.echo:
		_set_paused(not _panel.visible)
		get_viewport().set_input_as_handled()
	elif ke.keycode == KEY_ESCAPE and ke.pressed and not ke.echo and _panel.visible:
		_set_paused(false)
		get_viewport().set_input_as_handled()


# ── Button callbacks ──────────────────────────────────────────────────────────

func _on_resume() -> void:
	_set_paused(false)


func _on_save_exit() -> void:
	_save_all()
	get_tree().quit()


func _on_main_menu() -> void:
	_save_all()
	_set_paused(false)
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_exit() -> void:
	get_tree().quit()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _set_paused(paused: bool) -> void:
	_panel.visible    = paused
	get_tree().paused = paused


## Save all persistent game state: fog, chunks (via world unload), player pos.
func _save_all() -> void:
	if _fog_manager != null:
		_fog_manager.save_all()
	if _avatar != null:
		SaveManager.save_player(_avatar.position, _avatar.heading)


func _add_button(label: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(232, 46)
	btn.add_theme_font_size_override("font_size", 18)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.pressed.connect(callback)
	_vbox.add_child(btn)


func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	return sep
