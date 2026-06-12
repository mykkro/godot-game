class_name TextureCache

const TILES_PATH   := "res://media/rpg-tiles/"
const OBJECTS_PATH := "res://media/raven-objects/"

## In-memory cache: full path → Texture2D (or null if load failed).
static var _cache: Dictionary = {}


## Terrain tile texture (from rpg-tiles/).
static func get_texture(filename: String) -> Texture2D:
	return _load_texture(TILES_PATH + filename)


## Object/item sprite (from raven-objects/).
static func get_object_texture(filename: String) -> Texture2D:
	return _load_texture(OBJECTS_PATH + filename)


## Discard cached textures (useful for hot-reload in editor).
static func clear() -> void:
	_cache.clear()


static func _load_texture(full_path: String) -> Texture2D:
	if _cache.has(full_path):
		return _cache[full_path]
	var tex := load(full_path) as Texture2D
	if tex == null:
		push_warning("TextureCache: failed to load '%s'" % full_path)
	_cache[full_path] = tex
	return tex
