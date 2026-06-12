class_name ChunkData

## Cells per chunk side (chunk is CHUNK_SIZE × CHUNK_SIZE cells).
const CHUNK_SIZE      := 16
## Pixels per cell side.
const CELL_SIZE       := 64
## Pixels per chunk side (= CHUNK_SIZE * CELL_SIZE).
const CHUNK_PIXEL_SIZE := CHUNK_SIZE * CELL_SIZE  # 1024

## Chunk grid coordinates (each unit = one chunk = 1024 px).
var chunk_x: int = 0
var chunk_y: int = 0

## 2-D grid of CellData, indexed as cells[y][x].
var cells: Array = []


func _init(p_cx: int = 0, p_cy: int = 0) -> void:
	chunk_x = p_cx
	chunk_y = p_cy
	cells   = []
	for _y in range(CHUNK_SIZE):
		var row: Array = []
		for _x in range(CHUNK_SIZE):
			row.append(CellData.new())
		cells.append(row)


## Returns the CellData at local cell (x, y), or null if out of range.
func get_cell(x: int, y: int) -> CellData:
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE:
		return null
	return cells[y][x] as CellData


func set_cell(x: int, y: int, cell: CellData) -> void:
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE:
		return
	cells[y][x] = cell


## Unique string key for this chunk (used for file naming).
func get_key() -> String:
	return "%d_%d" % [chunk_x, chunk_y]


func to_dict() -> Dictionary:
	var rows: Array = []
	for y in range(CHUNK_SIZE):
		var row: Array = []
		for x in range(CHUNK_SIZE):
			row.append((cells[y][x] as CellData).to_dict())
		rows.append(row)
	return {
		"chunk_x": chunk_x,
		"chunk_y": chunk_y,
		"cells":   rows,
	}


static func from_dict(data: Dictionary) -> ChunkData:
	var chunk := ChunkData.new(data.get("chunk_x", 0), data.get("chunk_y", 0))
	var rows: Array = data.get("cells", [])
	for y in range(mini(rows.size(), CHUNK_SIZE)):
		var row: Array = rows[y]
		for x in range(mini(row.size(), CHUNK_SIZE)):
			chunk.cells[y][x] = CellData.from_dict(row[x])
	return chunk
