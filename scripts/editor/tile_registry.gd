extends Node

const INDEX_PATH := "res://media/rpg-tiles/index.json"

var _tiles: Dictionary = {}


func _ready() -> void:
	var file := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if file == null:
		push_error("TileRegistry: cannot open %s" % INDEX_PATH)
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("TileRegistry: JSON parse error in index")
		return
	if json.data is not Dictionary:
		push_error("TileRegistry: unexpected JSON root type")
		return
	_tiles = (json.data as Dictionary).get("textures", {})


func get_all_tiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
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


func get_categories() -> Array[String]:
	var seen: Dictionary = {}
	for filename in _tiles:
		seen[(_tiles[filename] as Dictionary).get("category", "")] = true
	var cats: Array[String] = []
	for key in seen.keys():
		cats.append(key as String)
	cats.sort()
	return cats


func is_passable(filename: String) -> bool:
	var tile: Dictionary = _tiles.get(filename, {})
	return bool(tile.get("passable", true))


func get_speed_modifier(filename: String) -> float:
	var tile: Dictionary = _tiles.get(filename, {})
	return float(tile.get("speed_modifier", 1.0))
