class_name TerrainType

## Terrain types available on map cells.
enum Type {
	GRASS = 0,
	DIRT  = 1,
	STONE = 2,
	WATER = 3,
}

## Debug/placeholder color for each terrain type.
static func get_color(type: int) -> Color:
	match type:
		Type.GRASS: return Color(0.22, 0.65, 0.18)
		Type.DIRT:  return Color(0.62, 0.43, 0.22)
		Type.STONE: return Color(0.52, 0.52, 0.52)
		Type.WATER: return Color(0.15, 0.40, 0.78)
	return Color.MAGENTA

## Whether actors can walk on this terrain type.
static func is_passable(type: int) -> bool:
	match type:
		Type.WATER: return false
	return true
