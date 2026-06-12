class_name CellData

const MAX_OBJECTS := 16

var terrain_type: String = "grass.png"
var objects: Array = []
var is_obstacle: bool = false


func _init(p_terrain: String = "grass.png") -> void:
	terrain_type = p_terrain
	is_obstacle  = not TileRegistry.is_passable(terrain_type)
	objects      = []


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
	var raw: Variant = data.get("terrain_type", "grass.png")
	var terrain: String
	if raw is int:
		terrain = _migrate_terrain(int(raw))
	else:
		terrain = str(raw)
	var cell := CellData.new(terrain)
	cell.is_obstacle = data.get("is_obstacle", not TileRegistry.is_passable(terrain))
	cell.objects = []
	for item in data.get("objects", []):
		cell.objects.append(int(item))
	return cell


static func _migrate_terrain(old_type: int) -> String:
	match old_type:
		0: return "grass.png"
		1: return "mud.png"
		2: return "granite floor.png"
		3: return "water.png"
		4: return "sand.png"
		5: return "swamp grass sep.png"
		6: return "snow.png"
		7: return "gravel.png"
		8: return "deepocean.png"
		9: return "path.png"
	return "grass.png"
