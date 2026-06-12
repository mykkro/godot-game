class_name BiomeDef

enum Type {
	PLAINS  = 0,
	CAVES   = 1,
	SEA     = 2,
	ROCKIES = 3,
	SNOW    = 4,
	FIELDS  = 5,
}


static func get_name(biome: int) -> String:
	match biome:
		Type.PLAINS:  return "Plains"
		Type.CAVES:   return "Caves"
		Type.SEA:     return "Sea"
		Type.ROCKIES: return "Rockies"
		Type.SNOW:    return "Snow"
		Type.FIELDS:  return "Fields"
	return "Unknown"


## Filename in res://media/rpg-tiles/ used as the biome icon.
static func get_icon_filename(biome: int) -> String:
	match biome:
		Type.PLAINS:  return "map tile grass.png"
		Type.CAVES:   return "cave wall.png"
		Type.SEA:     return "map tile ocean.png"
		Type.ROCKIES: return "map tile mountain.png"
		Type.SNOW:    return "permasnow.png"
		Type.FIELDS:  return "farmland.png"
	return "map tile grass.png"


## Terrain-type weights for chunk generation.
## Each entry: [TerrainType.Type value, weight int].
static func terrain_weights(biome: int) -> Array:
	match biome:
		Type.PLAINS:
			return [
				[TerrainType.Type.GRASS,       60],
				[TerrainType.Type.DIRT,        20],
				[TerrainType.Type.STONE,        4],
				[TerrainType.Type.WATER,        4],
				[TerrainType.Type.SAND,         5],
				[TerrainType.Type.SWAMP,        3],
				[TerrainType.Type.GRAVEL,       4],
			]
		Type.CAVES:
			return [
				[TerrainType.Type.STONE,       55],
				[TerrainType.Type.GRAVEL,      25],
				[TerrainType.Type.DIRT,        10],
				[TerrainType.Type.WATER,        8],
				[TerrainType.Type.DEEP_WATER,   2],
			]
		Type.SEA:
			return [
				[TerrainType.Type.DEEP_WATER,  45],
				[TerrainType.Type.WATER,       40],
				[TerrainType.Type.SAND,        15],
			]
		Type.ROCKIES:
			return [
				[TerrainType.Type.STONE,       45],
				[TerrainType.Type.GRAVEL,      30],
				[TerrainType.Type.DIRT,        10],
				[TerrainType.Type.SNOW,         7],
				[TerrainType.Type.PATH,         5],
				[TerrainType.Type.SAND,         3],
			]
		Type.SNOW:
			return [
				[TerrainType.Type.SNOW,        65],
				[TerrainType.Type.STONE,       12],
				[TerrainType.Type.GRAVEL,       8],
				[TerrainType.Type.WATER,        5],
				[TerrainType.Type.DIRT,         5],
				[TerrainType.Type.PATH,         5],
			]
		Type.FIELDS:
			return [
				[TerrainType.Type.GRASS,       50],
				[TerrainType.Type.DIRT,        30],
				[TerrainType.Type.SAND,         6],
				[TerrainType.Type.WATER,        6],
				[TerrainType.Type.SWAMP,        4],
				[TerrainType.Type.PATH,         4],
			]
	return [[TerrainType.Type.GRASS, 1]]


## Probability that a passable cell receives a rock obstacle.
static func rock_density(biome: int) -> float:
	match biome:
		Type.PLAINS:  return 0.04
		Type.CAVES:   return 0.18
		Type.SEA:     return 0.00
		Type.ROCKIES: return 0.22
		Type.SNOW:    return 0.04
		Type.FIELDS:  return 0.03
	return 0.05
