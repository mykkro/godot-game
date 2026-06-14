class_name CharacterPerks

## Holds a character's perk levels.  Absent key = level 0 (no perk).
var _data: Dictionary = {}


func get_level(perk: PerkDef.ID) -> int:
	return _data.get(int(perk), 0)


func set_level(perk: PerkDef.ID, level: int) -> void:
	var key := int(perk)
	if level <= 0:
		_data.erase(key)
	else:
		_data[key] = clampi(level, 1, PerkDef.get_max_level(perk))


func to_dict() -> Dictionary:
	return _data.duplicate()


func from_dict(d: Dictionary) -> void:
	_data.clear()
	for k in d:
		var v := int(d[k])
		if v > 0:
			_data[int(k)] = v
