class_name ItemPalette
extends VBoxContainer

signal item_selected(obj_type: int)

const TILE_SIZE := 38
const NONE_TYPE := -1

var _selected:               int   = NONE_TYPE
var _selected_chest_variant: int   = 0       # 0 = no chest selected, 1-12 specific
var _selected_overlay:       Panel = null

var _style_overlay: StyleBoxFlat = null


func _ready() -> void:
	_style_overlay = StyleBoxFlat.new()
	_style_overlay.bg_color     = Color(0, 0, 0, 0)
	_style_overlay.border_color = Color(0, 0.9, 0.9)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		_style_overlay.set_border_width(side, 3)
	for corner in range(4):
		_style_overlay.set_corner_radius(corner, 4)

	# ── Objects section ───────────────────────────────────────────────────────
	var lbl_obj := Label.new()
	lbl_obj.text = "Objects"
	lbl_obj.add_theme_font_size_override("font_size", 13)
	lbl_obj.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	add_child(lbl_obj)

	var grid_obj := GridContainer.new()
	grid_obj.columns = 3
	add_child(grid_obj)

	grid_obj.add_child(_make_obj_button(NONE_TYPE, null, "None (erase)"))

	for obj_type in MapObject.Type.values():
		if obj_type == MapObject.Type.CHEST_SMALL:
			continue  # shown separately in Chests section
		var tex: Texture2D = null
		if PickableItemDef.is_pickable(obj_type):
			tex = TextureCache.get_object_texture(PickableItemDef.get_sprite(obj_type))
		var btn := _make_obj_button(obj_type, tex, MapObject.get_display_name(obj_type))
		# Enable drag-and-drop for pickable items (used by chest inventory editor).
		if PickableItemDef.is_pickable(obj_type) and tex != null:
			_setup_palette_drag(btn, obj_type, tex)
		grid_obj.add_child(btn)

	# ── Chests section ────────────────────────────────────────────────────────
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.3, 0.3, 0.4))
	add_child(sep)

	var lbl_chests := Label.new()
	lbl_chests.text = "Chests"
	lbl_chests.add_theme_font_size_override("font_size", 13)
	lbl_chests.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	add_child(lbl_chests)

	var grid_chests := GridContainer.new()
	grid_chests.columns = 3
	add_child(grid_chests)

	for v in range(1, ChestNode.CHEST_VARIANTS + 1):
		grid_chests.add_child(
			_make_chest_button(v, TextureCache.get_chest_texture(v)))


func get_selected() -> int:
	return _selected


## Returns the selected chest variant (1-12), or 0 if no chest is selected.
func get_selected_chest_variant() -> int:
	return _selected_chest_variant


# ── Private ───────────────────────────────────────────────────────────────────

func _make_obj_button(obj_type: int, tex: Texture2D, tip: String) -> Button:
	var btn     := Button.new()
	var overlay := _build_button_body(btn, obj_type, tex, tip)
	btn.pressed.connect(_on_obj_pressed.bind(obj_type, overlay))
	return btn


func _make_chest_button(variant: int, tex: Texture2D) -> Button:
	var btn     := Button.new()
	var overlay := _build_button_body(
			btn, MapObject.Type.CHEST_SMALL, tex, "Chest variant %d" % variant)
	btn.pressed.connect(_on_chest_pressed.bind(variant, overlay))
	return btn


## Builds the visual body of a palette button and returns its selection overlay.
func _build_button_body(btn: Button, obj_type: int,
		tex: Texture2D, tip: String) -> Panel:
	btn.custom_minimum_size = Vector2(TILE_SIZE + 4, TILE_SIZE + 4)
	btn.clip_contents  = true
	btn.mouse_filter   = Control.MOUSE_FILTER_PASS
	btn.tooltip_text   = tip

	var container := CenterContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(container)

	if tex != null:
		var tr := TextureRect.new()
		tr.texture             = tex
		tr.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
		tr.texture_filter      = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		container.add_child(tr)
	elif obj_type >= 0:
		var cr := ColorRect.new()
		cr.color = ChunkEditorNode.OBJ_COLORS.get(obj_type, Color(0.7, 0.7, 0.7))
		cr.custom_minimum_size = Vector2(TILE_SIZE * 0.6, TILE_SIZE * 0.6)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(cr)
	else:
		var lbl := Label.new()
		lbl.text = "✕"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(lbl)

	var overlay := Panel.new()
	overlay.add_theme_stylebox_override("panel", _style_overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible      = false
	btn.add_child(overlay)
	return overlay


func _on_obj_pressed(obj_type: int, overlay: Panel) -> void:
	_selected               = obj_type
	_selected_chest_variant  = 0
	_swap_overlay(overlay)
	item_selected.emit(obj_type)


func _on_chest_pressed(variant: int, overlay: Panel) -> void:
	_selected               = MapObject.Type.CHEST_SMALL
	_selected_chest_variant  = variant
	_swap_overlay(overlay)
	item_selected.emit(MapObject.Type.CHEST_SMALL)


func _swap_overlay(new_overlay: Panel) -> void:
	if _selected_overlay != null:
		_selected_overlay.visible = false
	_selected_overlay = new_overlay
	new_overlay.visible = true


## Attach drag-and-drop to a palette button so it can be dragged into the
## chest inventory editor.  Only fires on drag (press + move); click still works.
func _setup_palette_drag(btn: Button, obj_type: int, tex: Texture2D) -> void:
	btn.set_drag_forwarding(
		func(_pos: Vector2) -> Variant:
			var preview                  := TextureRect.new()
			preview.texture               = tex
			preview.custom_minimum_size   = Vector2(40, 40)
			preview.expand_mode           = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			preview.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			preview.texture_filter        = CanvasItem.TEXTURE_FILTER_NEAREST
			btn.set_drag_preview(preview)
			return {"palette_obj_type": obj_type},
		func(_pos: Vector2, _data: Variant) -> bool: return false,
		func(_pos: Vector2, _data: Variant) -> void: pass
	)
