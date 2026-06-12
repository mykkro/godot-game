class_name ChunkGenerator

## Probability that a passable cell receives a rock.
const ROCK_DENSITY := 0.05

## Cumulative terrain distribution thresholds (must end at 1.0).
## Order matches the roll ranges below.
const T_GRASS      := 0.35
const T_DIRT       := 0.50  # +0.15
const T_STONE      := 0.60  # +0.10
const T_SAND       := 0.68  # +0.08
const T_SWAMP      := 0.74  # +0.06
const T_SNOW       := 0.80  # +0.06
const T_GRAVEL     := 0.87  # +0.07
const T_PATH       := 0.90  # +0.03
const T_WATER      := 0.97  # +0.07
# remainder (0.03) → DEEP_WATER


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

	if roll < T_GRASS:
		terrain = TerrainType.Type.GRASS
	elif roll < T_DIRT:
		terrain = TerrainType.Type.DIRT
	elif roll < T_STONE:
		terrain = TerrainType.Type.STONE
	elif roll < T_SAND:
		terrain = TerrainType.Type.SAND
	elif roll < T_SWAMP:
		terrain = TerrainType.Type.SWAMP
	elif roll < T_SNOW:
		terrain = TerrainType.Type.SNOW
	elif roll < T_GRAVEL:
		terrain = TerrainType.Type.GRAVEL
	elif roll < T_PATH:
		terrain = TerrainType.Type.PATH
	elif roll < T_WATER:
		terrain = TerrainType.Type.WATER
	else:
		terrain = TerrainType.Type.DEEP_WATER

	var cell := CellData.new(terrain)

	# Only passable terrain can hold objects.
	if not cell.is_obstacle and rng.randf() < ROCK_DENSITY:
		cell.add_object(MapObject.Type.ROCK)

	return cell


## Deterministic FNV-1a-inspired seed from chunk grid coordinates.
static func _chunk_seed(cx: int, cy: int) -> int:
	return abs((cx * 73856093) ^ (cy * 19349663) ^ 83492791)
