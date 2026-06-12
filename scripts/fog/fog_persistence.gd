class_name FogPersistence

const SAVE_DIR := "user://fog/"
const SAVE_EXT := ".json"


static func save(fog: FogData) -> void:
	_ensure_dir()
	var path := SAVE_DIR + _key(fog.chunk_x, fog.chunk_y) + SAVE_EXT
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("FogPersistence: cannot write '%s' (error %d)" \
				% [path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(fog.to_dict()))
	file.close()


## Returns null when no save file exists for this chunk.
static func load_fog(chunk_x: int, chunk_y: int) -> FogData:
	var path := SAVE_DIR + _key(chunk_x, chunk_y) + SAVE_EXT
	if not FileAccess.file_exists(path):
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("FogPersistence: cannot read '%s' (error %d)" \
				% [path, FileAccess.get_open_error()])
		return null

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("FogPersistence: JSON parse error in '%s': %s" \
				% [path, json.get_error_message()])
		return null

	return FogData.from_dict(json.data)


static func _key(cx: int, cy: int) -> String:
	return "%d_%d" % [cx, cy]


static func _ensure_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if not dir.dir_exists("fog"):
		dir.make_dir("fog")
