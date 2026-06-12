class_name ChunkEditorNode
extends Node2D

const CELL_SIZE  := ChunkData.CELL_SIZE
const CHUNK_SIZE := ChunkData.CHUNK_SIZE

# Object dot colours, keyed by MapObject.Type int value.
const OBJ_COLORS := {
	0: Color(0.55, 0.50, 0.45),  # ROCK
	1: Color(0.30, 0.70, 0.35),  # HERB
	2: Color(0.40, 0.70, 0.90),  # CRYSTAL
	3: Color(0.95, 0.85, 0.20),  # COIN
	4: Color(0.80, 0.75, 0.60),  # FEATHER
	5: Color(0.70, 0.30, 0.80),  # POTION
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
				var center := Vector2(px + CELL_SIZE * 0.5, py + CELL_SIZE * 0.5)
				var col: Color = OBJ_COLORS.get(obj_type, Color(1, 1, 1))
				draw_circle(center, CELL_SIZE * 0.22, col)

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
