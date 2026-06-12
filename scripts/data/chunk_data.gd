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
## Stack counts for pickable objects, keyed by x * CHUNK_SIZE + y.
var pickable_counts: Dictionary = {}
## Dominant biome for this chunk (BiomeDef.Type value).
var biome: int = BiomeDef.Type.PLAINS


func _init(p_cx: int = 0, p_cy: int = 0) -> void:
	chunk_x         = p_cx
	chunk_y         = p_cy
	cells           = []
	pickable_counts = {}
	biome           = BiomeDef.Type.PLAINS
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


func get_pickable_count(x: int, y: int) -> int:
	return pickable_counts.get(x * CHUNK_SIZE + y, 1)


func set_pickable_count(x: int, y: int, n: int) -> void:
	pickable_counts[x * CHUNK_SIZE + y] = n


func erase_pickable_count(x: int, y: int) -> void:
	pickable_counts.erase(x * CHUNK_SIZE + y)


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
	# Serialize pickable_counts as [[key, value], ...] (JSON keys must be strings,
	# but we want int keys internally; storing as pairs avoids string→int round-trip).
	var pc_pairs: Array = []
	for k in pickable_counts:
		pc_pairs.append([int(k), int(pickable_counts[k])])
	return {
		"chunk_x":         chunk_x,
		"chunk_y":         chunk_y,
		"biome":           biome,
		"cells":           rows,
		"pickable_counts": pc_pairs,
	}


static func from_dict(data: Dictionary) -> ChunkData:
	var chunk := ChunkData.new(data.get("chunk_x", 0), data.get("chunk_y", 0))
	chunk.biome = int(data.get("biome", BiomeDef.Type.PLAINS))
	var rows: Array = data.get("cells", [])
	for y in range(mini(rows.size(), CHUNK_SIZE)):
		var row: Array = rows[y]
		for x in range(mini(row.size(), CHUNK_SIZE)):
			chunk.cells[y][x] = CellData.from_dict(row[x])
	for pair in data.get("pickable_counts", []):
		chunk.pickable_counts[int((pair as Array)[0])] = int((pair as Array)[1])
	return chunk
