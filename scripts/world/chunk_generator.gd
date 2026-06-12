class_name ChunkGenerator

## Probability that a passable cell receives a rock.
const ROCK_DENSITY := 0.05

## How strongly a cell inherits its left/top neighbour's terrain (0-1).
## Higher values = larger, smoother biome blobs.
const BLEND_FACTOR := 0.72

## Base terrain distribution: terrain type → base weight.
## Weights are normalised internally; they don't need to sum to 1.
const _BASE_WEIGHTS: Array = [
	# [TerrainType.Type value, base weight]
	[0,  35],  # GRASS
	[1,  15],  # DIRT
	[2,  10],  # STONE
	[3,   7],  # WATER
	[4,   8],  # SAND
	[5,   6],  # SWAMP
	[6,   6],  # SNOW
	[7,   7],  # GRAVEL
	[8,   3],  # DEEP_WATER
	[9,   3],  # PATH
]


## Generate a new ChunkData for the given grid coordinates.
## The result is deterministic: same (chunk_x, chunk_y) always yields the same chunk.
static func generate(chunk_x: int, chunk_y: int) -> ChunkData:
	var chunk    := ChunkData.new(chunk_x, chunk_y)
	var rng      := RandomNumberGenerator.new()
	rng.seed      = _chunk_seed(chunk_x, chunk_y)

	# First pass: raw terrain type per cell (stored as int grid).
	var terrain_grid: Array = []
	for y in range(ChunkData.CHUNK_SIZE):
		var row: Array = []
		for x in range(ChunkData.CHUNK_SIZE):
			# Build blended weight array from neighbours.
			var weights := _base_weights_array()

			# Left neighbour.
			if x > 0:
				var left_type: int = row[x - 1]
				for i in range(weights.size()):
					if (weights[i] as Array)[0] == left_type:
						(weights[i] as Array)[1] = int((weights[i] as Array)[1] * (1.0 + BLEND_FACTOR * 3.0))

			# Top neighbour.
			if y > 0:
				var top_type: int = (terrain_grid[y - 1] as Array)[x]
				for i in range(weights.size()):
					if (weights[i] as Array)[0] == top_type:
						(weights[i] as Array)[1] = int((weights[i] as Array)[1] * (1.0 + BLEND_FACTOR * 3.0))

			row.append(_pick_weighted(rng, weights))
		terrain_grid.append(row)

	# Second pass: build CellData from terrain grid, add objects.
	for y in range(ChunkData.CHUNK_SIZE):
		for x in range(ChunkData.CHUNK_SIZE):
			var terrain: int = (terrain_grid[y] as Array)[x]
			var cell := CellData.new(terrain)
			if not cell.is_obstacle and rng.randf() < ROCK_DENSITY:
				cell.add_object(MapObject.Type.ROCK)
			chunk.set_cell(x, y, cell)

	return chunk


## Returns a fresh mutable copy of the base weights array.
static func _base_weights_array() -> Array:
	var out: Array = []
	for entry in _BASE_WEIGHTS:
		out.append([(entry as Array)[0], (entry as Array)[1]])
	return out


## Weighted random pick: each entry is [type_int, weight_int].
static func _pick_weighted(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0
	for entry in weights:
		total += (entry as Array)[1]
	var roll := rng.randi_range(0, total - 1)
	var acc  := 0
	for entry in weights:
		acc += (entry as Array)[1]
		if roll < acc:
			return (entry as Array)[0]
	return (weights[0] as Array)[0]


## Deterministic FNV-1a-inspired seed from chunk grid coordinates.
static func _chunk_seed(cx: int, cy: int) -> int:
	return abs((cx * 73856093) ^ (cy * 19349663) ^ 83492791)
