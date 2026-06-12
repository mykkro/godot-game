class_name TerrainPalette
extends VBoxContainer

signal terrain_selected(filename: String)

const TILE_SIZE    := 38
const GRID_COLUMNS := 4

const TAG_GROUPS := [
	"grass", "mud", "sand", "gravel", "path", "wood",
	"cave", "rock", "aquatic", "swamp", "highland",
	"arctic", "ice", "jungle", "volcanic", "constructed",
]

var _search:           LineEdit      = null
var _content:          VBoxContainer = null
var _selected:         String        = ""
var _selected_overlay: Panel         = null

var _style_overlay: StyleBoxFlat = null


func _ready() -> void:
	_style_overlay = StyleBoxFlat.new()
	_style_overlay.bg_color    = Color(0, 0, 0, 0)
	_style_overlay.border_color = Color(0, 0.9, 0.9)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		_style_overlay.set_border_width(side, 3)
	for corner in range(4):
		_style_overlay.set_corner_radius(corner, 4)

	_search = LineEdit.new()
	_search.placeholder_text = "Search tiles..."
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_on_search_changed)
	add_child(_search)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_content)

	_build_palette("")


func get_selected() -> String:
	return _selected


func _build_palette(filter: String) -> void:
	for child in _content.get_children():
		child.queue_free()
	_selected_overlay = null   # children freed above

	var all_tiles := TileRegistry.get_all_tiles()
	var terrain_tiles: Array[Dictionary] = []
	for tile in all_tiles:
		if (tile as Dictionary).get("category", "") != "terrain":
			continue
		var fname: String = (tile as Dictionary).get("filename", "")
		if filter != "" and not fname.to_lower().contains(filter.to_lower()):
			continue
		terrain_tiles.append(tile as Dictionary)

	var groups: Dictionary = {}
	for tile in terrain_tiles:
		var group := _primary_group(tile.get("tags", []) as Array)
		if not groups.has(group):
			groups[group] = []
		(groups[group] as Array).append(tile)

	for group_name in TAG_GROUPS:
		if not groups.has(group_name):
			continue
		_add_group(group_name.capitalize(), groups[group_name] as Array)

	for group_name in groups.keys():
		if group_name in TAG_GROUPS:
			continue
		_add_group(group_name.capitalize(), groups[group_name] as Array)


func _add_group(title: String, tiles: Array) -> void:
	if tiles.is_empty():
		return

	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	_content.add_child(lbl)

	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)

	for tile in tiles:
		var fname: String = (tile as Dictionary).get("filename", "")
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(TILE_SIZE + 4, TILE_SIZE + 4)
		btn.tooltip_text = fname
		grid.add_child(btn)

		var tex_rect := TextureRect.new()
		tex_rect.texture = TextureCache.get_texture(fname)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex_rect.mouse_filter   = Control.MOUSE_FILTER_IGNORE
		btn.add_child(tex_rect)

		# Cyan outline drawn on top of the icon when this tile is selected.
		var overlay := Panel.new()
		overlay.add_theme_stylebox_override("panel", _style_overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.visible = (fname == _selected)
		if fname == _selected:
			_selected_overlay = overlay
		btn.add_child(overlay)

		btn.pressed.connect(_on_tile_pressed.bind(fname, overlay))


func _on_tile_pressed(fname: String, overlay: Panel) -> void:
	_selected = fname
	if _selected_overlay != null:
		_selected_overlay.visible = false
	_selected_overlay = overlay
	overlay.visible = true
	terrain_selected.emit(fname)


func _on_search_changed(text: String) -> void:
	_build_palette(text)


static func _primary_group(tags: Array) -> String:
	for group in TAG_GROUPS:
		if tags.has(group):
			return group
	if not tags.is_empty():
		return (tags[0] as String)
	return "other"
