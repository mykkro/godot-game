class_name ChunkEditorNode
extends Node2D

const CELL_SIZE  := ChunkData.CELL_SIZE
const CHUNK_SIZE := ChunkData.CHUNK_SIZE

# Fallback colours for objects without a sprite (keyed by MapObject.Type).
const OBJ_COLORS := {
	0: Color(0.55, 0.50, 0.45),  # ROCK
	6: Color(0.75, 0.55, 0.20),  # CHEST_SMALL
}

var _data:        ChunkData = null
var _hover_cell:  Vector2i  = Vector2i(-1, -1)


func initialize(data: ChunkData) -> void:
	_data = data
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func set_hover(local_cell: Vector2i) -> void:
	if local_cell != _hover_cell:
		_hover_cell = local_cell
		queue_redraw()


func get_data() -> ChunkData:
	return _data


func set_cell(lx: int, ly: int, cell: CellData) -> void:
	if _data == null:
		return
	_data.set_cell(lx, ly, cell)
	queue_redraw()


func _draw() -> void:
	if _data == null:
		return

	var chunk_px := CHUNK_SIZE * CELL_SIZE

	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var cell := _data.get_cell(x, y)
			if cell == null:
				continue
			var px := x * CELL_SIZE
			var py := y * CELL_SIZE
			var rect := Rect2(px, py, CELL_SIZE, CELL_SIZE)

			var tex := TextureCache.get_texture(cell.terrain_type)
			if tex != null:
				draw_texture_rect(tex, rect, false)
			else:
				draw_rect(rect, Color(0.22, 0.65, 0.18))

			draw_rect(rect, Color(0, 0, 0, 0.07), false, 1.0)

			for obj_type in cell.objects:
				_draw_object(obj_type, px, py)

			# Editor-placed monster overlay.
			var species := _data.get_monster_placement(x, y)
			if not species.is_empty():
				_draw_monster(species, px, py)

	# Hover highlight.
	if _hover_cell.x >= 0 and _hover_cell.x < CHUNK_SIZE \
			and _hover_cell.y >= 0 and _hover_cell.y < CHUNK_SIZE:
		var hx := _hover_cell.x * CELL_SIZE
		var hy := _hover_cell.y * CELL_SIZE
		draw_rect(Rect2(hx, hy, CELL_SIZE, CELL_SIZE),
				Color(1.0, 1.0, 0.5, 0.30), true)
		draw_rect(Rect2(hx, hy, CELL_SIZE, CELL_SIZE),
				Color(1.0, 1.0, 0.5, 0.80), false, 1.5)

	# Chunk border.
	draw_rect(Rect2(0, 0, chunk_px, chunk_px), Color(0.6, 0.6, 0.6, 0.5), false, 1.5)


func _draw_object(obj_type: int, px: int, py: int) -> void:
	if PickableItemDef.is_pickable(obj_type):
		var tex := PickableItemDef.get_texture(obj_type)
		if tex != null:
			var s  := float(CELL_SIZE) * 0.50
			var ox := px + (CELL_SIZE - s) * 0.5
			var oy := py + (CELL_SIZE - s) * 0.5
			draw_texture_rect(tex, Rect2(ox, oy, s, s), false)
			return
	if obj_type == MapObject.Type.CHEST_SMALL:
		var cx      := px / CELL_SIZE
		var cy      := py / CELL_SIZE
		var variant := _data.get_chest_variant(cx, cy)
		if variant == 0:
			variant = ((cx * 7 + cy * 13) % ChestNode.CHEST_VARIANTS) + 1
		var tex     := TextureCache.get_chest_texture(variant)
		if tex != null:
			var s  := float(CELL_SIZE) * 0.50
			var ox := px + (CELL_SIZE - s) * 0.5
			var oy := py + (CELL_SIZE - s) * 0.5
			draw_texture_rect(tex, Rect2(ox, oy, s, s), false)
			return
	if obj_type == MapObject.Type.FORGE:
		var tex := TextureCache.get_items2_texture("forge.png")
		if tex != null:
			var s  := float(CELL_SIZE) * 0.50
			var ox := px + (CELL_SIZE - s) * 0.5
			var oy := py + (CELL_SIZE - s) * 0.5
			draw_texture_rect(tex, Rect2(ox, oy, s, s), false)
			return
		draw_rect(Rect2(px + CELL_SIZE * 0.2, py + CELL_SIZE * 0.2,
				CELL_SIZE * 0.6, CELL_SIZE * 0.6), Color(0.80, 0.45, 0.10))
		return
	if obj_type == MapObject.Type.ROCK:
		var lx      := px / CELL_SIZE
		var ly      := py / CELL_SIZE
		var stored  := _data.get_rock_variant(lx, ly)
		var variant := (stored - 1) if stored > 0 \
				else absi(lx * 7 + ly * 13 + _data.chunk_x * 31 + _data.chunk_y * 97) % 40
		var tex     := TextureCache.get_rock_texture(variant)
		if tex != null:
			var s  := float(CELL_SIZE) * 0.92
			var ox := px + (CELL_SIZE - s) * 0.5
			var oy := py + (CELL_SIZE - s) * 0.5
			draw_texture_rect(tex, Rect2(ox, oy, s, s), false)
			return
	# Fallback: coloured square for unknown objects.
	var col: Color = OBJ_COLORS.get(obj_type, Color(0.7, 0.7, 0.7))
	var m := CELL_SIZE * 0.2
	draw_rect(Rect2(px + m, py + m, CELL_SIZE - m * 2, CELL_SIZE - m * 2), col)


func _draw_monster(species: String, px: int, py: int) -> void:
	var tex := TextureCache.get_being_texture(species)
	if tex == null:
		return
	var s  := float(CELL_SIZE) * 0.75
	var ox := px + (CELL_SIZE - s) * 0.5
	var oy := py + (CELL_SIZE - s) * 0.5
	draw_texture_rect(tex, Rect2(ox, oy, s, s), false)
