class_name TextureCache

const TILES_PATH   := "res://media/rpg-tiles/"
const OBJECTS_PATH := "res://media/raven-objects/"
const ITEMS2_PATH  := "res://media/items2/"

## In-memory cache: full path → Texture2D (or null if load failed).
static var _cache: Dictionary = {}
## Named overrides registered by TileRegistry for atlas tiles.
static var _named: Dictionary = {}


## Register a pre-built texture under a virtual name (used for atlas tiles).
static func register_named(name: String, tex: Texture2D) -> void:
	_named[name] = tex


## Terrain tile texture. Checks named atlas overrides first, then rpg-tiles/.
static func get_texture(filename: String) -> Texture2D:
	if _named.has(filename):
		return _named[filename]
	return _load_texture(TILES_PATH + filename)


## Object/item sprite (from raven-objects/).
static func get_object_texture(filename: String) -> Texture2D:
	return _load_texture(OBJECTS_PATH + filename)


## Chest sprite by 1-based variant number (chest_01.png … chest_12.png).
static func get_chest_texture(variant: int) -> Texture2D:
	return _load_texture("res://media/chests/chest_%02d.png" % variant)


## Item sprite from the items2 individual-PNG library (media/items2/).
static func get_items2_texture(filename: String) -> Texture2D:
	return _load_texture(ITEMS2_PATH + filename)


## One 32×32 region from the 4×4 materials atlas (media/materials/nails.png).
static func get_material_texture(col: int, row: int) -> Texture2D:
	const ATLAS := "res://media/materials/nails.png"
	var key := "mat:%d,%d" % [col, row]
	if _cache.has(key):
		return _cache[key]
	var base := _load_texture(ATLAS)
	if base == null:
		_cache[key] = null
		return null
	var at := AtlasTexture.new()
	at.atlas  = base
	at.region = Rect2(col * 32, row * 32, 32, 32)
	_cache[key] = at
	return at


## Discard cached textures (useful for hot-reload in editor).
static func clear() -> void:
	_cache.clear()
	_named.clear()


static func _load_texture(full_path: String) -> Texture2D:
	if _cache.has(full_path):
		return _cache[full_path]
	var tex := load(full_path) as Texture2D
	if tex == null:
		push_warning("TextureCache: failed to load '%s'" % full_path)
	_cache[full_path] = tex
	return tex
