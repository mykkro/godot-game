class_name TerrainType

## Terrain types available on map cells.
enum Type {
	GRASS    = 0,
	DIRT     = 1,
	STONE    = 2,
	WATER    = 3,
	SAND     = 4,
	SWAMP    = 5,
	SNOW     = 6,
	GRAVEL   = 7,
	DEEP_WATER = 8,
	PATH     = 9,
}

## Debug/placeholder color for each terrain type.
static func get_color(type: int) -> Color:
	match type:
		Type.GRASS:      return Color(0.22, 0.65, 0.18)
		Type.DIRT:       return Color(0.62, 0.43, 0.22)
		Type.STONE:      return Color(0.52, 0.52, 0.52)
		Type.WATER:      return Color(0.15, 0.40, 0.78)
		Type.SAND:       return Color(0.85, 0.78, 0.45)
		Type.SWAMP:      return Color(0.28, 0.42, 0.18)
		Type.SNOW:       return Color(0.88, 0.92, 0.98)
		Type.GRAVEL:     return Color(0.50, 0.48, 0.44)
		Type.DEEP_WATER: return Color(0.05, 0.18, 0.55)
		Type.PATH:       return Color(0.70, 0.60, 0.42)
	return Color.MAGENTA

## Whether actors can walk on this terrain type.
static func is_passable(type: int) -> bool:
	match type:
		Type.WATER:      return false
		Type.DEEP_WATER: return false
	return true

## Filename (relative to res://media/rpg-tiles/) for the terrain tile texture.
static func get_texture_filename(type: int) -> String:
	match type:
		Type.GRASS:      return "grass.png"
		Type.DIRT:       return "mud.png"
		Type.STONE:      return "granite floor.png"
		Type.WATER:      return "water.png"
		Type.SAND:       return "sand.png"
		Type.SWAMP:      return "swamp grass sep.png"
		Type.SNOW:       return "snow.png"
		Type.GRAVEL:     return "gravel.png"
		Type.DEEP_WATER: return "deepocean.png"
		Type.PATH:       return "path.png"
	return "grass.png"
