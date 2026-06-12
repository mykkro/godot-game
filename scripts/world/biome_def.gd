class_name BiomeDef

enum Type {
	PLAINS  = 0,
	CAVES   = 1,
	SEA     = 2,
	ROCKIES = 3,
	SNOW    = 4,
	FIELDS  = 5,
}


static func get_display_name(biome: int) -> String:
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
## Each entry: [filename String, weight int].
static func terrain_weights(biome: int) -> Array:
	match biome:
		Type.PLAINS:
			return [
				["grass.png",           60],
				["mud.png",             20],
				["granite floor.png",    4],
				["water.png",            4],
				["sand.png",             5],
				["swamp grass sep.png",  3],
				["gravel.png",           4],
			]
		Type.CAVES:
			return [
				["granite floor.png",   55],
				["gravel.png",          25],
				["mud.png",             10],
				["water.png",            8],
				["deepocean.png",        2],
			]
		Type.SEA:
			return [
				["deepocean.png",       45],
				["water.png",           40],
				["sand.png",            15],
			]
		Type.ROCKIES:
			return [
				["granite floor.png",   45],
				["gravel.png",          30],
				["mud.png",             10],
				["snow.png",             7],
				["path.png",             5],
				["sand.png",             3],
			]
		Type.SNOW:
			return [
				["snow.png",            65],
				["granite floor.png",   12],
				["gravel.png",           8],
				["water.png",            5],
				["mud.png",              5],
				["path.png",             5],
			]
		Type.FIELDS:
			return [
				["grass.png",           50],
				["mud.png",             30],
				["sand.png",             6],
				["water.png",            6],
				["swamp grass sep.png",  4],
				["path.png",             4],
			]
	return [["grass.png", 1]]


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
