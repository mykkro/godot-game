class_name SaveManager

## Central place for save-game path constants and wipe helpers.

const CHUNKS_DIR  := "user://chunks/"
const FOG_DIR     := "user://fog/"
const PLAYER_FILE := "user://player.json"


## Returns true when a previous game session exists (any saved chunk).
static func has_save() -> bool:
	var dir := DirAccess.open(CHUNKS_DIR)
	if dir == null:
		return false
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".json"):
			dir.list_dir_end()
			return true
		name = dir.get_next()
	dir.list_dir_end()
	return false


## Persist avatar position and heading.
static func save_player(pos: Vector2, heading: float) -> void:
	var file := FileAccess.open(PLAYER_FILE, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write player save (error %d)" \
				% FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({
		"x":       pos.x,
		"y":       pos.y,
		"heading": heading,
	}))
	file.close()


## Load avatar state.  Returns an empty dict when no save file exists.
static func load_player() -> Dictionary:
	if not FileAccess.file_exists(PLAYER_FILE):
		return {}
	var file := FileAccess.open(PLAYER_FILE, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("SaveManager: failed to parse player save")
		return {}
	return json.data as Dictionary


## Delete all persisted data, starting a clean slate.
static func wipe() -> void:
	_wipe_dir(CHUNKS_DIR)
	_wipe_dir(FOG_DIR)
	if FileAccess.file_exists(PLAYER_FILE):
		DirAccess.remove_absolute(PLAYER_FILE)


static func _wipe_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir():
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()
