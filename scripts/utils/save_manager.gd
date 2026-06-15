class_name SaveManager

## Central place for save-game path constants and wipe helpers.

const CHUNKS_DIR     := "user://chunks/"
const FOG_DIR        := "user://fog/"
const PLAYER_FILE    := "user://player.json"
const INVENTORY_FILE := "user://inventory.json"
const SETTINGS_FILE  := "user://settings.json"
const NPCS_FILE      := "user://npcs.json"
const DIALOG_FILE    := "user://dialog_visited.json"
const SHOPS_FILE     := "user://shops.json"
const CLOCK_FILE     := "user://clock.json"
const PERKS_FILE     := "user://player_perks.json"
const CHAR_FILE      := "user://character.json"
const QUESTS_FILE    := "user://quests.json"


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
	for path in [PLAYER_FILE, INVENTORY_FILE, NPCS_FILE, DIALOG_FILE, SHOPS_FILE, CLOCK_FILE, PERKS_FILE, CHAR_FILE, QUESTS_FILE]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Persist the player inventory.
static func save_inventory(inv: Inventory) -> void:
	var file := FileAccess.open(INVENTORY_FILE, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write inventory save (error %d)" \
				% FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(inv.to_dict()))
	file.close()


## Load inventory from disk.  Returns a new empty Inventory when no save exists.
static func load_inventory() -> Inventory:
	if not FileAccess.file_exists(INVENTORY_FILE):
		return Inventory.new()
	var file := FileAccess.open(INVENTORY_FILE, FileAccess.READ)
	if file == null:
		return Inventory.new()
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("SaveManager: failed to parse inventory save")
		return Inventory.new()
	return Inventory.from_dict(json.data as Dictionary)


static func save_settings(master_volume: float,
		music_volume: float = 0.5, effects_volume: float = 1.0,
		fullscreen: bool = false, resolution_index: int = 2) -> void:
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write settings (error %d)" \
				% FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({
		"master_volume":    master_volume,
		"music_volume":     music_volume,
		"effects_volume":   effects_volume,
		"fullscreen":       fullscreen,
		"resolution_index": resolution_index,
	}))
	file.close()


static func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_FILE):
		return {}
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data as Dictionary


## Persist NPC dialog visited options. Data: {npc_id: {label: true}}.
static func save_dialog_visited(data: Dictionary) -> void:
	var file := FileAccess.open(DIALOG_FILE, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write dialog visited (error %d)" \
				% FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data))
	file.close()


## Load NPC dialog visited options. Returns empty dict when no save exists.
static func load_dialog_visited() -> Dictionary:
	if not FileAccess.file_exists(DIALOG_FILE):
		return {}
	var file := FileAccess.open(DIALOG_FILE, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func save_shop_states(states: Dictionary) -> void:
	var file := FileAccess.open(SHOPS_FILE, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write shop states (error %d)" \
				% FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(states))
	file.close()


static func load_shop_states() -> Dictionary:
	if not FileAccess.file_exists(SHOPS_FILE):
		return {}
	var file := FileAccess.open(SHOPS_FILE, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func save_clock(time: float) -> void:
	var file := FileAccess.open(CLOCK_FILE, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write clock save (error %d)" \
				% FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({"time": time}))
	file.close()


static func load_clock() -> float:
	if not FileAccess.file_exists(CLOCK_FILE):
		return 21600.0   # default: 6:00 AM day 1
	var file := FileAccess.open(CLOCK_FILE, FileAccess.READ)
	if file == null:
		return 21600.0
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary and (parsed as Dictionary).has("time"):
		return float((parsed as Dictionary)["time"])
	return 21600.0


static func save_npcs(data: Array) -> void:
	var file := FileAccess.open(NPCS_FILE, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write npcs save (error %d)" \
				% FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data))
	file.close()


static func load_npcs() -> Array:
	if not FileAccess.file_exists(NPCS_FILE):
		return []
	var file := FileAccess.open(NPCS_FILE, FileAccess.READ)
	if file == null:
		return []
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("SaveManager: failed to parse npcs save")
		return []
	var result: Variant = json.data
	if result is Array:
		return result
	return []


static func save_perks(perks: CharacterPerks) -> void:
	var file := FileAccess.open(PERKS_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(perks.to_dict()))
	file.close()


static func load_perks() -> CharacterPerks:
	var p := CharacterPerks.new()
	if not FileAccess.file_exists(PERKS_FILE):
		return p
	var file := FileAccess.open(PERKS_FILE, FileAccess.READ)
	if file == null:
		return p
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		p.from_dict(parsed as Dictionary)
	return p


static func save_character(char_name: String, birth_time: float) -> void:
	var file := FileAccess.open(CHAR_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"name": char_name, "birth_time": birth_time}))
	file.close()


static func load_character() -> Dictionary:
	if not FileAccess.file_exists(CHAR_FILE):
		return {}
	var file := FileAccess.open(CHAR_FILE, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func save_quests(manager: QuestManager) -> void:
	var file := FileAccess.open(QUESTS_FILE, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write quests save (error %d)" \
				% FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(manager.to_dict()))
	file.close()


static func load_quests(manager: QuestManager) -> void:
	if not FileAccess.file_exists(QUESTS_FILE):
		return
	var file := FileAccess.open(QUESTS_FILE, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		manager.from_dict(parsed as Dictionary)


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
