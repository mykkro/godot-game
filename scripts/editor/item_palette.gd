class_name ItemPalette
extends VBoxContainer

signal item_selected(obj_type: int)

const TILE_SIZE := 38
const NONE_TYPE := -1

var _selected:         int   = NONE_TYPE
var _selected_overlay: Panel = null

var _style_overlay: StyleBoxFlat = null


func _ready() -> void:
	_style_overlay = StyleBoxFlat.new()
	_style_overlay.bg_color    = Color(0, 0, 0, 0)
	_style_overlay.border_color = Color(0, 0.9, 0.9)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		_style_overlay.set_border_width(side, 3)
	for corner in range(4):
		_style_overlay.set_corner_radius(corner, 4)

	var lbl := Label.new()
	lbl.text = "Objects"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	add_child(lbl)

	var grid := GridContainer.new()
	grid.columns = 3
	add_child(grid)

	grid.add_child(_make_button(NONE_TYPE, null, "None (erase)"))

	for obj_type in MapObject.Type.values():
		var tex: Texture2D = null
		if PickableItemDef.is_pickable(obj_type):
			tex = TextureCache.get_object_texture(PickableItemDef.get_sprite(obj_type))
		elif obj_type == MapObject.Type.CHEST_SMALL:
			tex = TextureCache.get_chest_texture(1)
		grid.add_child(_make_button(obj_type, tex, MapObject.get_display_name(obj_type)))


func get_selected() -> int:
	return _selected


func _make_button(obj_type: int, tex: Texture2D, tip: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(TILE_SIZE + 4, TILE_SIZE + 4)
	btn.clip_contents = true
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.tooltip_text = tip

	var container := CenterContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(container)

	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter   = Control.MOUSE_FILTER_IGNORE
		container.add_child(tr)
	elif obj_type >= 0:
		var cr := ColorRect.new()
		cr.color = ChunkEditorNode.OBJ_COLORS.get(obj_type, Color(0.7, 0.7, 0.7))
		cr.custom_minimum_size = Vector2(TILE_SIZE * 0.6, TILE_SIZE * 0.6)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(cr)
	else:
		var none_lbl := Label.new()
		none_lbl.text = "✕"
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_lbl.add_theme_font_size_override("font_size", 22)
		none_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
		none_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(none_lbl)

	# Cyan outline drawn on top of the icon when this object is selected.
	var overlay := Panel.new()
	overlay.add_theme_stylebox_override("panel", _style_overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	btn.add_child(overlay)

	btn.pressed.connect(_on_item_pressed.bind(obj_type, overlay))
	return btn


func _on_item_pressed(obj_type: int, overlay: Panel) -> void:
	_selected = obj_type
	if _selected_overlay != null:
		_selected_overlay.visible = false
	_selected_overlay = overlay
	overlay.visible = true
	item_selected.emit(obj_type)
