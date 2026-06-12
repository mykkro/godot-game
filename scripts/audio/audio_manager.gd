class_name AudioManager

const MUSIC_BUS   := "Music"
const SFX_BUS     := "SFX"

const DEFAULT_MASTER_VOLUME  := 0.5
const DEFAULT_MUSIC_VOLUME   := 0.5
const DEFAULT_EFFECTS_VOLUME := 1.0


## Create Music and SFX buses as children of Master if they don't exist yet.
## Safe to call multiple times.
static func ensure_buses() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, MUSIC_BUS)
		AudioServer.set_bus_send(idx, "Master")

	if AudioServer.get_bus_index(SFX_BUS) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, SFX_BUS)
		AudioServer.set_bus_send(idx, "Master")


## Load saved volumes and apply them to all buses.
## Returns the settings dict so callers can initialise their sliders.
static func apply_saved_settings() -> Dictionary:
	ensure_buses()
	var s := SaveManager.load_settings()
	set_master_volume(float(s.get("master_volume",  DEFAULT_MASTER_VOLUME)))
	set_music_volume(float(s.get("music_volume",    DEFAULT_MUSIC_VOLUME)))
	set_effects_volume(float(s.get("effects_volume", DEFAULT_EFFECTS_VOLUME)))
	return s


static func set_master_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"), linear_to_db(linear))


static func set_music_volume(linear: float) -> void:
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


static func set_effects_volume(linear: float) -> void:
	var idx := AudioServer.get_bus_index(SFX_BUS)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))
