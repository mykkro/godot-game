class_name SaveManager

## Central place for save-game path constants and wipe helpers.

const CHUNKS_DIR := "user://chunks/"
const FOG_DIR    := "user://fog/"


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


## Delete all persisted chunks and fog data, starting a clean slate.
static func wipe() -> void:
	_wipe_dir(CHUNKS_DIR)
	_wipe_dir(FOG_DIR)


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
