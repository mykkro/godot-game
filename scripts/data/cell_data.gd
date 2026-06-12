class_name CellData

## Maximum number of objects that can occupy a single cell.
const MAX_OBJECTS := 16

## Terrain type (TerrainType.Type enum value).
var terrain_type: int = TerrainType.Type.GRASS

## Object types present in this cell (holds MapObject.Type int values).
var objects: Array = []

## True when actors cannot enter this cell at all (e.g. water).
## Derived from terrain on construction; can be overridden.
var is_obstacle: bool = false


func _init(p_terrain: int = TerrainType.Type.GRASS) -> void:
	terrain_type = p_terrain
	is_obstacle  = not TerrainType.is_passable(terrain_type)
	objects      = []


## Adds an object to this cell. Returns false when the cell is full.
func add_object(obj_type: int) -> bool:
	if objects.size() >= MAX_OBJECTS:
		return false
	objects.append(obj_type)
	return true


func to_dict() -> Dictionary:
	return {
		"terrain_type": terrain_type,
		"objects":      objects.duplicate(),
		"is_obstacle":  is_obstacle,
	}


static func from_dict(data: Dictionary) -> CellData:
	var cell := CellData.new(data.get("terrain_type", TerrainType.Type.GRASS))
	cell.is_obstacle = data.get("is_obstacle", false)
	cell.objects     = []
	for item in data.get("objects", []):
		cell.objects.append(int(item))
	return cell
