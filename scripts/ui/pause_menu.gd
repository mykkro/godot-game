class_name PauseMenu
extends CanvasLayer

const MENU_SCENE := "res://scenes/menu.tscn"

var _fog_manager: FogManager = null
var _avatar:      Avatar     = null
var _npc_manager: NpcManager = null
var _npc_dialog:  NpcDialog  = null

var _center:          CenterContainer = null
var _panel:           PanelContainer  = null
var _vbox:            VBoxContainer   = null
var _confirm_overlay: Control         = null   # full-screen dim + dialog

## True once the player has clicked Save during this pause session.
var _saved: bool = false
## Action to run after confirmation (Main Menu or quit).
var _pending_action: Callable = Callable()


## Call from main._ready() after all other nodes are set up.
func setup(fog_manager: FogManager, avatar: Avatar,
		npc_manager: NpcManager, npc_dialog: NpcDialog) -> void:
	_fog_manager = fog_manager
	_avatar      = avatar
	_npc_manager = npc_manager
	_npc_dialog  = npc_dialog


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS

	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_center)

	_panel = PanelContainer.new()
	_panel.process_mode        = Node.PROCESS_MODE_ALWAYS
	_panel.custom_minimum_size = Vector2(280, 0)
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_center.add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(_vbox)

	var title := Label.new()
	title.text                 = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	_vbox.add_child(title)

	_vbox.add_child(_make_separator())
	_add_button("Resume",    _on_resume)
	_add_button("Save",      _on_save)
	_add_button("Main Menu", _on_main_menu)
	_add_button("Exit",      _on_exit)

	_center.visible = false

	_build_confirm_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_F10:
		if _confirm_overlay.visible:
			_hide_confirm()
		else:
			_set_paused(not _center.visible)
		get_viewport().set_input_as_handled()
	elif ke.keycode == KEY_ESCAPE and _center.visible:
		if _confirm_overlay.visible:
			_hide_confirm()
		else:
			_set_paused(false)
		get_viewport().set_input_as_handled()


# ── Button callbacks ──────────────────────────────────────────────────────────

func _on_resume() -> void:
	_set_paused(false)


func _on_save() -> void:
	_save_all()
	_saved = true


func _on_main_menu() -> void:
	if _saved:
		_do_main_menu()
	else:
		_pending_action = _do_main_menu
		_show_confirm()


func _on_exit() -> void:
	if _saved:
		_do_exit()
	else:
		_pending_action = _do_exit
		_show_confirm()


# ── Confirm dialog callbacks ──────────────────────────────────────────────────

func _on_confirm_save_and_go() -> void:
	_save_all()
	_saved = true
	_hide_confirm()
	_pending_action.call()
	_pending_action = Callable()


func _on_confirm_leave() -> void:
	_hide_confirm()
	_pending_action.call()
	_pending_action = Callable()


func _on_confirm_cancel() -> void:
	_hide_confirm()
	_pending_action = Callable()


# ── Actions ───────────────────────────────────────────────────────────────────

func _do_main_menu() -> void:
	_set_paused(false)
	get_tree().change_scene_to_file(MENU_SCENE)


func _do_exit() -> void:
	get_tree().quit()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _set_paused(paused: bool) -> void:
	_center.visible   = paused
	get_tree().paused = paused
	if paused:
		_saved = false   # reset each time menu opens so new progress requires re-save


func _show_confirm() -> void:
	_confirm_overlay.visible = true


func _hide_confirm() -> void:
	_confirm_overlay.visible = false


func _save_all() -> void:
	if _fog_manager != null:
		_fog_manager.save_all()
	if _avatar != null:
		SaveManager.save_player(_avatar.position, _avatar.heading)
		SaveManager.save_inventory(_avatar.inventory)
	if _npc_manager != null:
		_npc_manager.save()
	if _npc_dialog != null:
		SaveManager.save_dialog_visited(_npc_dialog.get_visited_data())
	SaveManager.save_shop_states(ShopUI.get_shop_states())
	SaveManager.save_clock(GameClock.get_game_time())


func _build_confirm_overlay() -> void:
	# Semi-transparent full-screen backdrop.
	var dim := ColorRect.new()
	dim.color        = Color(0, 0, 0, 0.55)
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.add_child(center)

	var dialog := PanelContainer.new()
	dialog.process_mode        = Node.PROCESS_MODE_ALWAYS
	dialog.custom_minimum_size = Vector2(300, 0)
	dialog.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	dialog.add_child(vbox)

	var msg := Label.new()
	msg.text                 = "Game not saved.\nSave before leaving?"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 17)
	msg.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
	vbox.add_child(msg)

	vbox.add_child(_make_separator())
	_add_confirm_button(vbox, "Save & Leave",         _on_confirm_save_and_go)
	_add_confirm_button(vbox, "Leave without saving",  _on_confirm_leave)
	_add_confirm_button(vbox, "Cancel",                _on_confirm_cancel)

	dim.visible      = false
	_confirm_overlay = dim


func _add_confirm_button(parent: VBoxContainer, label: String, cb: Callable) -> void:
	var btn := Button.new()
	btn.text                = label
	btn.custom_minimum_size = Vector2(256, 42)
	btn.add_theme_font_size_override("font_size", 17)
	btn.process_mode        = Node.PROCESS_MODE_ALWAYS
	btn.pressed.connect(cb)
	parent.add_child(btn)


func _add_button(label: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text                = label
	btn.custom_minimum_size = Vector2(232, 46)
	btn.add_theme_font_size_override("font_size", 18)
	btn.process_mode        = Node.PROCESS_MODE_ALWAYS
	btn.pressed.connect(callback)
	_vbox.add_child(btn)


func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	return sep


func _make_panel_style() -> StyleBoxFlat:
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
	return style
