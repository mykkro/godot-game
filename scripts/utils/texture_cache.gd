class_name TextureCache

const BASE_PATH := "res://media/rpg-tiles/"

## In-memory cache: filename → Texture2D (or null if load failed).
static var _cache: Dictionary = {}


## Returns the Texture2D for the given filename (relative to BASE_PATH),
## loading and caching it on first access.  Returns null on failure.
static func get_texture(filename: String) -> Texture2D:
	if _cache.has(filename):
		return _cache[filename]

	var path  := BASE_PATH + filename
	var tex   := load(path) as Texture2D
	if tex == null:
		push_warning("TextureCache: failed to load '%s'" % path)

	_cache[filename] = tex
	return tex


## Discard cached textures (useful for hot-reload in editor).
static func clear() -> void:
	_cache.clear()
