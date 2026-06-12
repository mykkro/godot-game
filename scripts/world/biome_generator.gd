class_name BiomeGenerator

## World-space noise frequency — larger value = smaller biome blobs.
## At 0.0025, one noise period spans ~400 cells (~25 chunks).
const ALTITUDE_FREQUENCY := 0.0025
const TEMP_FREQUENCY     := 0.0030

## Arbitrary prime seeds for decorrelated noise layers.
const _ALTITUDE_SEED := 0x1A2B3C4D
const _TEMP_SEED     := 0x5E6F7081

static var _altitude: FastNoiseLite = null
static var _temp:     FastNoiseLite = null


## Returns the biome at any world-cell position.
## Operates at single-cell granularity — suitable for future sub-chunk
## blending by sampling multiple cells per chunk and mixing the results.
static func get_biome(cell_x: int, cell_y: int) -> BiomeDef.Type:
	_init_noise()
	var alt  := _altitude.get_noise_2d(float(cell_x), float(cell_y))
	var temp := _temp.get_noise_2d(float(cell_x), float(cell_y))
	return _classify(alt, temp)


## Convenience: returns the dominant biome for a chunk by sampling its centre.
static func get_chunk_biome(chunk_x: int, chunk_y: int) -> BiomeDef.Type:
	var cx := chunk_x * ChunkData.CHUNK_SIZE + ChunkData.CHUNK_SIZE / 2
	var cy := chunk_y * ChunkData.CHUNK_SIZE + ChunkData.CHUNK_SIZE / 2
	return get_biome(cx, cy)


# ── Private ──────────────────────────────────────────────────────────────────

static func _init_noise() -> void:
	if _altitude != null:
		return
	_altitude            = FastNoiseLite.new()
	_altitude.seed       = _ALTITUDE_SEED
	_altitude.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_altitude.frequency  = ALTITUDE_FREQUENCY

	_temp            = FastNoiseLite.new()
	_temp.seed       = _TEMP_SEED
	_temp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_temp.frequency  = TEMP_FREQUENCY


## Maps (altitude, temperature) noise values → biome type.
## Both inputs are FastNoiseLite output in roughly [-1, 1].
##
##   altitude < -0.35          → SEA      (low, flooded)
##   altitude >  0.50          → ROCKIES  (high, craggy)
##   temp     < -0.40          → SNOW     (cold anywhere above sea)
##   alt in (-0.35,-0.05)
##     + temp < 0.10           → CAVES    (shadowed, sunken land)
##   temp     >  0.30          → FIELDS   (warm, fertile)
##   otherwise                 → PLAINS
static func _classify(alt: float, temp: float) -> BiomeDef.Type:
	if alt < -0.35:
		return BiomeDef.Type.SEA
	if alt > 0.50:
		return BiomeDef.Type.ROCKIES
	if temp < -0.40:
		return BiomeDef.Type.SNOW
	if alt < -0.05 and temp < 0.10:
		return BiomeDef.Type.CAVES
	if temp > 0.30:
		return BiomeDef.Type.FIELDS
	return BiomeDef.Type.PLAINS
