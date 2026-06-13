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
	for atlas_def in ((json.data as Dictionary).get("atlases", []) as Array):
		_expand_atlas(atlas_def as Dictionary)


func _expand_atlas(def: Dictionary) -> void:
	var file:   String = def.get("file", "")
	var prefix: String = def.get("prefix", "tile")
	var tw:     int    = int(def.get("tile_width", 64))
	var th:     int    = int(def.get("tile_height", 64))

	if file == "":
		push_error("TileRegistry: atlas entry missing 'file'")
		return

	var base_tex := load("res://" + file) as Texture2D
	if base_tex == null:
		push_error("TileRegistry: atlas source not found: res://%s" % file)
		return

	# Derive cols/rows from image size when not specified in JSON.
	var cols: int = int(def.get("cols", 0))
	var rows: int = int(def.get("rows", 0))
	if cols <= 0: cols = base_tex.get_width()  / tw
	if rows <= 0: rows = base_tex.get_height() / th

	# Load raw pixel data once for uniform-tile detection.
	var base_img: Image = base_tex.get_image()
	if base_img != null and base_img.is_compressed():
		base_img.decompress()

	var meta := {
		"category":       def.get("category", "terrain"),
		"passable":       bool(def.get("passable", true)),
		"speed_modifier": float(def.get("speed_modifier", 1.0)),
		"tags":           def.get("tags", []),
	}

	for row in range(rows):
		for col in range(cols):
			var region := Rect2i(col * tw, row * th, tw, th)
			if base_img != null and _is_uniform_region(base_img, region):
				continue
			var name := "%s_%s%d" % [prefix, _row_label(row), col + 1]
			var atlas := AtlasTexture.new()
			atlas.atlas  = base_tex
			atlas.region = Rect2(region)
			TextureCache.register_named(name, atlas)
			var entry := meta.duplicate()
			entry["atlas_source"] = file
			entry["atlas_row"]    = row
			entry["atlas_col"]    = col
			_tiles[name] = entry


# Row A–Z for rows 0–25; AA, AB, … for rows 26+.
func _row_label(row: int) -> String:
	const L := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	if row < 26:
		return L[row]
	return L[(row / 26) - 1] + L[row % 26]


func _is_uniform_region(img: Image, region: Rect2i) -> bool:
	var first := img.get_pixel(region.position.x, region.position.y)
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if img.get_pixel(x, y) != first:
				return false
	return true


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
