class_name ItemPalette
extends VBoxContainer

signal item_selected(obj_type: int)

const TILE_SIZE := 48
const NONE_TYPE := -1

var _selected: int         = NONE_TYPE
var _buttons:  Array[Button] = []


func _ready() -> void:
	var lbl := Label.new()
	lbl.text = "Objects"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	add_child(lbl)

	var grid := GridContainer.new()
	grid.columns = 3
	add_child(grid)

	# "None / erase" entry.
	var none_btn := _make_button(NONE_TYPE, null, "None (erase)")
	grid.add_child(none_btn)

	for obj_type in MapObject.Type.values():
		var tex: Texture2D = null
		if PickableItemDef.is_pickable(obj_type):
			tex = TextureCache.get_object_texture(PickableItemDef.get_sprite(obj_type))
		var btn := _make_button(obj_type, tex, MapObject.get_display_name(obj_type))
		grid.add_child(btn)


func get_selected() -> int:
	return _selected


func _make_button(obj_type: int, tex: Texture2D, tip: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(TILE_SIZE + 4, TILE_SIZE + 4)
	btn.tooltip_text = tip
	btn.pressed.connect(_on_item_pressed.bind(obj_type, btn))
	_buttons.append(btn)

	var container := CenterContainer.new()
	container.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(container)

	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(tr)
	elif obj_type >= 0:
		# No sprite — draw a coloured circle placeholder matching in-world rendering.
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

	return btn


func _on_item_pressed(obj_type: int, btn: Button) -> void:
	_selected = obj_type
	for b in _buttons:
		b.button_pressed = false
	btn.button_pressed = true
	item_selected.emit(obj_type)
