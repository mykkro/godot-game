class_name ChunkGenerator

## How strongly a cell inherits its left/top neighbour's terrain (0-1).
## Higher values = larger, smoother terrain blobs within a biome.
const BLEND_FACTOR := 0.72


## Generate a new ChunkData for the given grid coordinates.
## The result is deterministic: same (chunk_x, chunk_y) always yields the same chunk.
static func generate(chunk_x: int, chunk_y: int) -> ChunkData:
	var chunk   := ChunkData.new(chunk_x, chunk_y)
	# Dominant biome (chunk centre) — used for metadata/icons.
	chunk.biome  = BiomeGenerator.get_chunk_biome(chunk_x, chunk_y)

	var rng  := RandomNumberGenerator.new()
	rng.seed  = _chunk_seed(chunk_x, chunk_y)

	# Cache weight arrays so each biome's Array is allocated only once per chunk.
	var weights_cache: Dictionary = {}
	for bt in BiomeDef.Type.values():
		weights_cache[bt] = BiomeDef.terrain_weights(bt)

	# First pass: per-cell biome sampling → terrain type.
	# biome_grid[y][x] stores the BiomeDef.Type for each cell.
	var terrain_grid: Array = []
	var biome_grid:   Array = []
	for y in range(ChunkData.CHUNK_SIZE):
		var t_row: Array = []
		var b_row: Array = []
		for x in range(ChunkData.CHUNK_SIZE):
			# Sample biome at the global cell position.
			var gx := chunk_x * ChunkData.CHUNK_SIZE + x
			var gy := chunk_y * ChunkData.CHUNK_SIZE + y
			var cell_biome := BiomeGenerator.get_biome(gx, gy)
			b_row.append(cell_biome)

			# Start with a mutable copy of this cell's biome weights.
			var weights := _copy_weights(weights_cache[cell_biome])

			# Left neighbour boosts its terrain type (smooths within-biome patches).
			if x > 0:
				var left_type: int = t_row[x - 1]
				for i in range(weights.size()):
					if (weights[i] as Array)[0] == left_type:
						(weights[i] as Array)[1] = int((weights[i] as Array)[1] * (1.0 + BLEND_FACTOR * 3.0))

			# Top neighbour boosts its terrain type.
			if y > 0:
				var top_type: int = (terrain_grid[y - 1] as Array)[x]
				for i in range(weights.size()):
					if (weights[i] as Array)[0] == top_type:
						(weights[i] as Array)[1] = int((weights[i] as Array)[1] * (1.0 + BLEND_FACTOR * 3.0))

			t_row.append(_pick_weighted(rng, weights))
		terrain_grid.append(t_row)
		biome_grid.append(b_row)

	# Second pass: build CellData, place objects using each cell's own biome.
	for y in range(ChunkData.CHUNK_SIZE):
		for x in range(ChunkData.CHUNK_SIZE):
			var terrain:    int = (terrain_grid[y] as Array)[x]
			var cell_biome: int = (biome_grid[y]   as Array)[x]
			var cell := CellData.new(terrain)
			if not cell.is_obstacle:
				_place_objects(rng, cell, BiomeDef.rock_density(cell_biome))
				if cell.objects.has(MapObject.Type.COIN):
					chunk.set_pickable_count(x, y, _coin_stack_count(rng))
			chunk.set_cell(x, y, cell)

	return chunk


## Randomly place objects in a passable cell.
static func _place_objects(rng: RandomNumberGenerator, cell: CellData,
		rock_density: float) -> void:
	var roll := rng.randf()
	if roll < rock_density:
		cell.add_object(MapObject.Type.ROCK)
	elif roll < rock_density + 0.030:
		cell.add_object(MapObject.Type.HERB)
	elif roll < rock_density + 0.050:
		cell.add_object(MapObject.Type.CRYSTAL)
	elif roll < rock_density + 0.065:
		cell.add_object(MapObject.Type.COIN)
	elif roll < rock_density + 0.075:
		cell.add_object(MapObject.Type.FEATHER)
	elif roll < rock_density + 0.082:
		cell.add_object(MapObject.Type.POTION)


## Returns a fresh mutable copy of a weights array (so blending doesn't mutate the source).
static func _copy_weights(source: Array) -> Array:
	var out: Array = []
	for entry in source:
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


## Random coin stack size 1-30, heavily weighted toward lower values.
static func _coin_stack_count(rng: RandomNumberGenerator) -> int:
	return int(rng.randf() * rng.randf() * 29.0) + 1


## Deterministic FNV-1a-inspired seed from chunk grid coordinates.
static func _chunk_seed(cx: int, cy: int) -> int:
	return abs((cx * 73856093) ^ (cy * 19349663) ^ 83492791)
