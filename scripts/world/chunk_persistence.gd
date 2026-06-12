class_name ChunkPersistence

const SAVE_DIR  := "user://chunks/"
const SAVE_EXT  := ".json"


## Persist a chunk to disk.  Creates the save directory if needed.
static func save(chunk: ChunkData) -> void:
	_ensure_dir()
	var path := SAVE_DIR + chunk.get_key() + SAVE_EXT
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ChunkPersistence: cannot open '%s' for writing (error %d)" \
				% [path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(chunk.to_dict(), "\t"))
	file.close()


## Load a chunk from disk.  Returns null when no save file exists.
static func load_chunk(chunk_x: int, chunk_y: int) -> ChunkData:
	var path := _path_for(chunk_x, chunk_y)
	if not FileAccess.file_exists(path):
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ChunkPersistence: cannot open '%s' for reading (error %d)" \
				% [path, FileAccess.get_open_error()])
		return null

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("ChunkPersistence: JSON parse error in '%s': %s" \
				% [path, json.get_error_message()])
		return null

	return ChunkData.from_dict(json.data)


## Returns true when a save file exists for the given chunk coordinates.
static func exists(chunk_x: int, chunk_y: int) -> bool:
	return FileAccess.file_exists(_path_for(chunk_x, chunk_y))


# ── Private ──────────────────────────────────────────────────────────────────

static func _path_for(cx: int, cy: int) -> String:
	return SAVE_DIR + "%d_%d" % [cx, cy] + SAVE_EXT


static func _ensure_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("ChunkPersistence: cannot access user:// directory")
		return
	if not dir.dir_exists("chunks"):
		dir.make_dir("chunks")
