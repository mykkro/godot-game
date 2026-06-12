class_name EditorUI
extends CanvasLayer

signal save_pressed
signal menu_pressed
signal autosave_toggled(enabled: bool)

const PANEL_WIDTH := 260

var _lbl_chunk:     Label            = null
var _lbl_cell:      Label            = null
var _lbl_terrain:   Label            = null
var _lbl_saved:     Label            = null
var _lbl_status:    Label            = null
var _chk_autosave:  CheckButton      = null
var _terrain_pal:   TerrainPalette   = null
var _item_pal:      ItemPalette      = null
var _confirm_dialog: ConfirmationDialog = null

# Unsaved exit guard callback — set by map_editor.gd.
var _exit_guard: Callable = Callable()


func _ready() -> void:
	layer = 10
	_build_top_bar()
	_build_right_panel()
	_build_status_bar()
	_build_exit_dialog()


# ── Public API ────────────────────────────────────────────────────────────────

func get_terrain_palette() -> TerrainPalette:
	return _terrain_pal


func get_item_palette() -> ItemPalette:
	return _item_pal


func set_chunk_coords(cc: Vector2i) -> void:
	if _lbl_chunk != null:
		_lbl_chunk.text = "Chunk: (%d, %d)" % [cc.x, cc.y]


func set_cell_coords(lc: Vector2i) -> void:
	if _lbl_cell != null:
		_lbl_cell.text = "Cell: (%d, %d)" % [lc.x, lc.y]


func set_hover_terrain(terrain: String) -> void:
	if _lbl_terrain != null:
		_lbl_terrain.text = "Terrain: %s" % terrain


func set_unsaved(dirty: bool) -> void:
	if _lbl_status != null:
		_lbl_status.text = "* Unsaved changes" if dirty else ""
		_lbl_status.add_theme_color_override("font_color",
				Color(1.0, 0.6, 0.2) if dirty else Color(0.6, 0.9, 0.5))


func set_last_saved(timestamp: String) -> void:
	if _lbl_saved != null:
		_lbl_saved.text = "Saved: %s" % timestamp


func set_chunks_loaded(count: int) -> void:
	if _lbl_chunk != null:
		_lbl_chunk.text = "%d chunk(s) loaded" % count


func show_exit_dialog() -> void:
	if _confirm_dialog != null:
		_confirm_dialog.popup_centered()


# ── Layout builders ───────────────────────────────────────────────────────────

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 44
	bar.offset_right  = -PANEL_WIDTH

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.10, 0.15, 0.92)
	bar.add_theme_stylebox_override("panel", bg)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left  = 8
	hbox.offset_right = -8
	bar.add_child(hbox)

	var btn_menu := Button.new()
	btn_menu.text = "< Menu"
	btn_menu.add_theme_font_size_override("font_size", 16)
	btn_menu.pressed.connect(_on_menu_pressed)
	hbox.add_child(btn_menu)

	var btn_save := Button.new()
	btn_save.text = "Save"
	btn_save.add_theme_font_size_override("font_size", 16)
	btn_save.pressed.connect(func(): save_pressed.emit())
	hbox.add_child(btn_save)

	_chk_autosave = CheckButton.new()
	_chk_autosave.text = "Autosave"
	_chk_autosave.button_pressed = true
	_chk_autosave.add_theme_font_size_override("font_size", 14)
	_chk_autosave.toggled.connect(func(on: bool): autosave_toggled.emit(on))
	hbox.add_child(_chk_autosave)

	_lbl_status = Label.new()
	_lbl_status.text = ""
	_lbl_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_status.add_theme_font_size_override("font_size", 14)
	hbox.add_child(_lbl_status)

	_lbl_saved = Label.new()
	_lbl_saved.text = ""
	_lbl_saved.add_theme_font_size_override("font_size", 13)
	_lbl_saved.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hbox.add_child(_lbl_saved)

	add_child(bar)


func _build_right_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -PANEL_WIDTH

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.13, 0.95)
	panel.add_theme_stylebox_override("panel", bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	vbox.offset_left  = 4
	vbox.offset_right = -4
	scroll.add_child(vbox)

	# Coordinates display.
	_lbl_chunk = Label.new()
	_lbl_chunk.text = "Chunk: —"
	_lbl_chunk.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_lbl_chunk)

	_lbl_cell = Label.new()
	_lbl_cell.text = "Cell: —"
	_lbl_cell.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_lbl_cell)

	_lbl_terrain = Label.new()
	_lbl_terrain.text = "Terrain: —"
	_lbl_terrain.add_theme_font_size_override("font_size", 12)
	_lbl_terrain.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
	vbox.add_child(_lbl_terrain)

	_add_separator(vbox)

	var lbl_terrain := Label.new()
	lbl_terrain.text = "TERRAIN"
	lbl_terrain.add_theme_font_size_override("font_size", 15)
	lbl_terrain.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(lbl_terrain)

	_terrain_pal = TerrainPalette.new()
	_terrain_pal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_terrain_pal.custom_minimum_size   = Vector2(PANEL_WIDTH - 16, 0)
	vbox.add_child(_terrain_pal)

	_add_separator(vbox)

	var lbl_items := Label.new()
	lbl_items.text = "OBJECTS"
	lbl_items.add_theme_font_size_override("font_size", 15)
	lbl_items.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(lbl_items)

	_item_pal = ItemPalette.new()
	_item_pal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_item_pal)

	add_child(panel)


func _build_status_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top   = -28
	bar.offset_right = -PANEL_WIDTH

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.07, 0.12, 0.88)
	bar.add_theme_stylebox_override("panel", bg)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left  = 8
	hbox.offset_right = -8
	bar.add_child(hbox)

	var lbl_hint := Label.new()
	lbl_hint.text = "LMB: paint  |  RMB: remove object  |  MMB: pan  |  Scroll: zoom"
	lbl_hint.add_theme_font_size_override("font_size", 12)
	lbl_hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	hbox.add_child(lbl_hint)

	add_child(bar)


func _build_exit_dialog() -> void:
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Unsaved Changes"
	_confirm_dialog.dialog_text = "You have unsaved changes. What would you like to do?"
	_confirm_dialog.ok_button_text      = "Save & Leave"
	_confirm_dialog.cancel_button_text  = "Leave without saving"

	var btn_stay := _confirm_dialog.add_button("Stay in Editor", true, "stay")
	btn_stay.pressed.connect(func(): _confirm_dialog.hide())

	_confirm_dialog.confirmed.connect(_on_exit_save_and_leave)
	_confirm_dialog.canceled.connect(_on_exit_without_saving)
	add_child(_confirm_dialog)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.3, 0.3, 0.4))
	parent.add_child(sep)


func _on_menu_pressed() -> void:
	if not _exit_guard.is_null() and _exit_guard.call():
		show_exit_dialog()
	else:
		menu_pressed.emit()


func _on_exit_save_and_leave() -> void:
	save_pressed.emit()
	menu_pressed.emit()


func _on_exit_without_saving() -> void:
	menu_pressed.emit()


func set_exit_guard(guard: Callable) -> void:
	_exit_guard = guard
