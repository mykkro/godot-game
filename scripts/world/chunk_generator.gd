class_name ChunkGenerator

## Probability that a passable cell receives a rock.
const ROCK_DENSITY := 0.05

## Terrain distribution weights (must sum to 1.0).
const W_GRASS := 0.60
const W_DIRT  := 0.20
const W_STONE := 0.12
# remainder → WATER


## Generate a new ChunkData for the given grid coordinates.
## The result is deterministic: same (chunk_x, chunk_y) always yields the same chunk.
static func generate(chunk_x: int, chunk_y: int) -> ChunkData:
	var chunk := ChunkData.new(chunk_x, chunk_y)
	var rng   := RandomNumberGenerator.new()
	rng.seed  = _chunk_seed(chunk_x, chunk_y)

	for y in range(ChunkData.CHUNK_SIZE):
		for x in range(ChunkData.CHUNK_SIZE):
			chunk.set_cell(x, y, _generate_cell(rng))

	return chunk


static func _generate_cell(rng: RandomNumberGenerator) -> CellData:
	var roll: float = rng.randf()
	var terrain: int

	if roll < W_GRASS:
		terrain = TerrainType.Type.GRASS
	elif roll < W_GRASS + W_DIRT:
		terrain = TerrainType.Type.DIRT
	elif roll < W_GRASS + W_DIRT + W_STONE:
		terrain = TerrainType.Type.STONE
	else:
		terrain = TerrainType.Type.WATER

	var cell := CellData.new(terrain)

	# Only passable terrain can hold objects.
	if not cell.is_obstacle and rng.randf() < ROCK_DENSITY:
		cell.add_object(MapObject.Type.ROCK)

	return cell


## Deterministic FNV-1a-inspired seed from chunk grid coordinates.
static func _chunk_seed(cx: int, cy: int) -> int:
	return abs((cx * 73856093) ^ (cy * 19349663) ^ 83492791)
