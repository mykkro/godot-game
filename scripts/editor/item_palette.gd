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
		var fname := ""
		if PickableItemDef.is_pickable(obj_type):
			fname = PickableItemDef.get_sprite(obj_type)
		var tex := TextureCache.get_texture(fname) if fname != "" else null
		var btn := _make_button(obj_type, tex, MapObject.get_name(obj_type))
		grid.add_child(btn)


func get_selected() -> int:
	return _selected


func _make_button(obj_type: int, tex: Texture2D, tip: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(TILE_SIZE + 4, TILE_SIZE + 4)
	btn.tooltip_text = tip
	btn.pressed.connect(_on_item_pressed.bind(obj_type, btn))
	_buttons.append(btn)

	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(tr)
	else:
		var lbl := Label.new()
		lbl.text = tip
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lbl)

	return btn


func _on_item_pressed(obj_type: int, btn: Button) -> void:
	_selected = obj_type
	for b in _buttons:
		b.button_pressed = false
	btn.button_pressed = true
	item_selected.emit(obj_type)
