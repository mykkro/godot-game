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
## Selected chest sprite variant (1-12) per cell, keyed by lx + ly*CHUNK_SIZE.
## 0 means "use default formula"; stored only for editor-placed chests.
var chest_variants: Dictionary = {}
## Editor-assigned chest contents per cell, keyed by lx + ly*CHUNK_SIZE.
## Stored only when the editor has explicitly set contents (even empty).
## Generated randomly on game spawn when absent.
var chest_contents: Dictionary = {}
## Forge input slot contents per cell.  key = lx + ly*CHUNK_SIZE → Array or absent.
var forge_input:  Dictionary = {}
## Forge output slot contents per cell. key = lx + ly*CHUNK_SIZE → Array or absent.
var forge_output: Dictionary = {}
## Editor-chosen rock sprite variant (1-40) per cell, keyed by lx + ly*CHUNK_SIZE.
## 0 means "position-hashed" (no override).
var rock_variants: Dictionary = {}
## Editor-placed monster species per cell. key = lx + ly*CHUNK_SIZE → species String.
## Empty string or absent = no placement (generate randomly on spawn).
var monster_placements: Dictionary = {}


func _init(p_cx: int = 0, p_cy: int = 0) -> void:
	chunk_x         = p_cx
	chunk_y         = p_cy
	cells           = []
	pickable_counts = {}
	biome           = BiomeDef.Type.PLAINS
	chest_variants  = {}
	chest_contents  = {}
	forge_input     = {}
	forge_output    = {}
	rock_variants   = {}
	monster_placements = {}
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


## Returns stored chest variant (1-12), or 0 if not set (use default formula).
func get_chest_variant(lx: int, ly: int) -> int:
	return int(chest_variants.get(lx + ly * CHUNK_SIZE, 0))


func set_chest_variant(lx: int, ly: int, variant: int) -> void:
	if variant == 0:
		chest_variants.erase(lx + ly * CHUNK_SIZE)
	else:
		chest_variants[lx + ly * CHUNK_SIZE] = variant


## Returns editor-set chest contents for this cell, or null when not set.
## null = generate deterministically; [] = intentionally empty.
func get_chest_contents(lx: int, ly: int) -> Variant:
	var key := lx + ly * CHUNK_SIZE
	if chest_contents.has(key):
		return chest_contents[key]
	return null


func set_chest_contents(lx: int, ly: int, arr: Array) -> void:
	chest_contents[lx + ly * CHUNK_SIZE] = arr


func get_forge_input(lx: int, ly: int) -> Variant:
	var key := lx + ly * CHUNK_SIZE
	return forge_input[key] if forge_input.has(key) else null


func set_forge_input(lx: int, ly: int, arr: Array) -> void:
	forge_input[lx + ly * CHUNK_SIZE] = arr


func get_forge_output(lx: int, ly: int) -> Variant:
	var key := lx + ly * CHUNK_SIZE
	return forge_output[key] if forge_output.has(key) else null


func set_forge_output(lx: int, ly: int, arr: Array) -> void:
	forge_output[lx + ly * CHUNK_SIZE] = arr


## Returns stored rock variant (1-40), or 0 if not set (use position hash).
func get_rock_variant(lx: int, ly: int) -> int:
	return int(rock_variants.get(lx + ly * CHUNK_SIZE, 0))


func set_rock_variant(lx: int, ly: int, variant: int) -> void:
	if variant == 0:
		rock_variants.erase(lx + ly * CHUNK_SIZE)
	else:
		rock_variants[lx + ly * CHUNK_SIZE] = variant


func get_monster_placement(lx: int, ly: int) -> String:
	return str(monster_placements.get(lx + ly * CHUNK_SIZE, ""))


func set_monster_placement(lx: int, ly: int, species: String) -> void:
	var key := lx + ly * CHUNK_SIZE
	if species.is_empty():
		monster_placements.erase(key)
	else:
		monster_placements[key] = species


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
	var cv_pairs: Array = []
	for k in chest_variants:
		cv_pairs.append([int(k), int(chest_variants[k])])
	var cc_pairs: Array = []
	for k in chest_contents:
		cc_pairs.append([int(k), (chest_contents[k] as Array).duplicate(true)])
	var fi_pairs: Array = []
	for k in forge_input:
		fi_pairs.append([int(k), (forge_input[k] as Array).duplicate(true)])
	var fo_pairs: Array = []
	for k in forge_output:
		fo_pairs.append([int(k), (forge_output[k] as Array).duplicate(true)])
	var rv_pairs: Array = []
	for k in rock_variants:
		rv_pairs.append([int(k), int(rock_variants[k])])
	var mp_pairs: Array = []
	for k in monster_placements:
		mp_pairs.append([int(k), str(monster_placements[k])])
	return {
		"chunk_x":         chunk_x,
		"chunk_y":         chunk_y,
		"biome":           biome,
		"cells":           rows,
		"pickable_counts": pc_pairs,
		"chest_variants":  cv_pairs,
		"chest_contents":  cc_pairs,
		"forge_input":     fi_pairs,
		"forge_output":    fo_pairs,
		"rock_variants":   rv_pairs,
		"monster_placements": mp_pairs,
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
	for pair in data.get("chest_variants", []):
		chunk.chest_variants[int((pair as Array)[0])] = int((pair as Array)[1])
	for pair in data.get("chest_contents", []):
		var key := int((pair as Array)[0])
		var raw_arr: Array = (pair as Array)[1]
		var arr: Array = []
		for entry in raw_arr:
			arr.append({"type": int(entry["type"]), "count": int(entry["count"])})
		chunk.chest_contents[key] = arr
	for pair in data.get("forge_input", []):
		var key := int((pair as Array)[0])
		var raw_arr: Array = (pair as Array)[1]
		var arr: Array = []
		for entry in raw_arr:
			arr.append({"type": int(entry["type"]), "count": int(entry["count"])})
		chunk.forge_input[key] = arr
	for pair in data.get("forge_output", []):
		var key := int((pair as Array)[0])
		var raw_arr: Array = (pair as Array)[1]
		var arr: Array = []
		for entry in raw_arr:
			arr.append({"type": int(entry["type"]), "count": int(entry["count"])})
		chunk.forge_output[key] = arr
	for pair in data.get("rock_variants", []):
		chunk.rock_variants[int((pair as Array)[0])] = int((pair as Array)[1])
	for pair in data.get("monster_placements", []):
		chunk.monster_placements[int((pair as Array)[0])] = str((pair as Array)[1])
	return chunk
