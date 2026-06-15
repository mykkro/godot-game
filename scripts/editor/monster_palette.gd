class_name MonsterPalette
extends VBoxContainer

## Emitted when the user picks a monster species (or "" to deselect).
signal monster_selected(species: String)

const TILE_SIZE := 38

## Currently selected species. "" = nothing selected (don't paint monsters).
var _selected:         String = ""
var _selected_overlay: Panel  = null
var _style_overlay:    StyleBoxFlat = null


func _ready() -> void:
	_style_overlay = StyleBoxFlat.new()
	_style_overlay.bg_color     = Color(0, 0, 0, 0)
	_style_overlay.border_color = Color(0, 0.9, 0.9)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		_style_overlay.set_border_width(side, 3)
	for corner in range(4):
		_style_overlay.set_corner_radius(corner, 4)

	var grid := _make_grid()
	add_child(grid)

	# Deselect / clear button.
	grid.add_child(_make_monster_button("", null, "None (deselect)"))

	# One button per species, sorted alphabetically.
	var species_list: Array[String] = []
	for f in DirAccess.get_files_at("res://media/rpg-beings/"):
		if f.get_extension() == "png":
			species_list.append(f.get_basename())
	species_list.sort()

	for species in species_list:
		var tex := TextureCache.get_being_texture(species)
		grid.add_child(_make_monster_button(species, tex, species))


func get_selected() -> String:
	return _selected


# ── Private ───────────────────────────────────────────────────────────────────

func _make_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 3
	return g


func _make_monster_button(species: String, tex: Texture2D, tip: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(TILE_SIZE + 4, TILE_SIZE + 4)
	btn.clip_contents       = true
	btn.mouse_filter        = Control.MOUSE_FILTER_PASS
	btn.tooltip_text        = tip

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
	else:
		var lbl := Label.new()
		lbl.text                     = "✕"
		lbl.horizontal_alignment     = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
		lbl.mouse_filter             = Control.MOUSE_FILTER_IGNORE
		container.add_child(lbl)

	var overlay := Panel.new()
	overlay.add_theme_stylebox_override("panel", _style_overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible      = false
	btn.add_child(overlay)

	btn.pressed.connect(_on_pressed.bind(species, overlay))
	return btn


func _on_pressed(species: String, overlay: Panel) -> void:
	_selected = species
	_swap_overlay(overlay)
	monster_selected.emit(species)


func _swap_overlay(new_overlay: Panel) -> void:
	if _selected_overlay != null:
		_selected_overlay.visible = false
	_selected_overlay = new_overlay
	new_overlay.visible = true
