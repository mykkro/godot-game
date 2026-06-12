extends Node

const INDEX_PATH := "res://media/rpg-tiles/index.json"

var _tiles: Dictionary = {}


func _init() -> void:
	var file := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if file == null:
		push_error("TileRegistry: cannot open %s" % INDEX_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("TileRegistry: JSON parse error in index")
		return
	file.close()
	_tiles = (json.data as Dictionary).get("textures", {})


func get_all_tiles() -> Array:
	var result: Array = []
	for filename in _tiles:
		var entry: Dictionary = (_tiles[filename] as Dictionary).duplicate()
		entry["filename"] = filename
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ac: String = a.get("category", "")
		var bc: String = b.get("category", "")
		if ac != bc:
			return ac < bc
		return (a["filename"] as String) < (b["filename"] as String)
	)
	return result


func get_tile(filename: String) -> Dictionary:
	return (_tiles.get(filename, {}) as Dictionary).duplicate()


func get_categories() -> Array:
	var seen: Dictionary = {}
	for filename in _tiles:
		seen[(_tiles[filename] as Dictionary).get("category", "")] = true
	var cats := seen.keys()
	cats.sort()
	return cats


func is_passable(filename: String) -> bool:
	return bool((_tiles.get(filename, {"passable": true}) as Dictionary).get("passable", true))


func get_speed_modifier(filename: String) -> float:
	return float((_tiles.get(filename, {"speed_modifier": 1.0}) as Dictionary).get("speed_modifier", 1.0))
