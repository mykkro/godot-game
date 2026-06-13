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


## One rock sprite from the two 4×5 rockz spritesheets (rockz.png + rockz2.png).
## variant 0-19 → rockz.png, variant 20-39 → rockz2.png  (wraps at 40).
## Grid boundaries are inferred from the image content (gap-detection algorithm).
static var _rock_grids: Dictionary = {}   # path → {"x": Array[float], "y": Array[float]}

static func get_rock_texture(variant: int) -> Texture2D:
	const COLS := 4
	const ROWS := 5
	var sheets  := ["res://media/rockz/rockz.png", "res://media/rockz/rockz2.png"]
	const PER   := COLS * ROWS
	var total     := PER * sheets.size()
	var v         := variant % total
	var sheet_idx := v / PER
	var within    := v % PER
	var col       := within % COLS
	var row       := within / COLS
	var key       := "rockz:%d" % v
	if _cache.has(key):
		return _cache[key]

	var path := sheets[sheet_idx] as String
	var base := _load_texture(path)
	if base == null:
		_cache[key] = null
		return null

	var grid   := _get_rock_grid(path, COLS, ROWS)
	var xc     := grid.get("x", []) as Array
	var yc     := grid.get("y", []) as Array
	var img_w  := float(base.get_width())
	var img_h  := float(base.get_height())

	var left   := 0.0   if col == 0        else float(xc[col - 1])
	var right  := img_w if col == COLS - 1 else float(xc[col])
	var top    := 0.0   if row == 0        else float(yc[row - 1])
	var bottom := img_h if row == ROWS - 1 else float(yc[row])

	var at    := AtlasTexture.new()
	at.atlas   = base
	at.region  = Rect2(left, top, right - left, bottom - top)
	_cache[key] = at
	return at


## Analyses a spritesheet image to find the cut positions between `cols` columns
## and `rows` rows.  Results are cached per path.
## Checks for a pre-computed _grid.json sidecar before doing pixel analysis.
static func _get_rock_grid(path: String, cols: int, rows: int) -> Dictionary:
	if _rock_grids.has(path):
		return _rock_grids[path]

	# Fast path: load pre-computed sidecar written by tools/analyze_spritesheets.gd.
	var json_path := path.get_basename() + "_grid.json"
	var f := FileAccess.open(json_path, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			var xc := (parsed as Dictionary).get("x_cuts", []) as Array
			var yc := (parsed as Dictionary).get("y_cuts", []) as Array
			if xc.size() >= cols - 1 and yc.size() >= rows - 1:
				var cached := {"x": xc, "y": yc}
				_rock_grids[path] = cached
				return cached

	# Slow path: pixel-level gap analysis (used when sidecar does not exist yet).
	var base := _load_texture(path)
	if base == null:
		_rock_grids[path] = {}
		return {}
	var img := base.get_image()
	if img == null:
		_rock_grids[path] = {}
		return {}
	img.convert(Image.FORMAT_RGBA8)

	var W    := img.get_width()
	var H    := img.get_height()
	var data := img.get_data()   # PackedByteArray, row-major RGBA8

	# OR-collapse: mark each column/row as "has content" in one pass.
	var prof_x := PackedByteArray(); prof_x.resize(W); prof_x.fill(0)
	var prof_y := PackedByteArray(); prof_y.resize(H); prof_y.fill(0)
	for y in range(H):
		var rb := y * W * 4
		for x in range(W):
			if prof_x[x] == 1 and prof_y[y] == 1:
				continue
			var i := rb + x * 4
			# content = opaque AND not near-white background
			if int(data[i + 3]) > 20 and (int(data[i]) + int(data[i+1]) + int(data[i+2])) < 720:
				prof_x[x] = 1
				prof_y[y] = 1

	var result := {
		"x": _profile_to_cuts(prof_x, W, cols),
		"y": _profile_to_cuts(prof_y, H, rows),
	}
	_rock_grids[path] = result
	return result


## Converts a binary content profile into (count-1) cut positions (gap centres).
static func _profile_to_cuts(profile: PackedByteArray, dim: int, count: int) -> Array[float]:
	# Find all contiguous gap runs (profile == 0).
	var gaps: Array[Dictionary] = []
	var gs := -1
	for i in range(dim):
		if profile[i] == 0:
			if gs < 0:
				gs = i
		else:
			if gs >= 0:
				gaps.append({"s": gs, "e": i - 1})
				gs = -1
	if gs >= 0:
		gaps.append({"s": gs, "e": dim - 1})

	# Keep only internal gaps (not touching image border) wide enough to be real.
	const MIN_GAP := 4
	var internal: Array[Dictionary] = []
	for g in gaps:
		if g["s"] > 0 and g["e"] < dim - 1 and (g["e"] - g["s"] + 1) >= MIN_GAP:
			internal.append(g)

	var need := count - 1
	# Fallback to uniform grid if not enough gaps found.
	if internal.size() < need:
		var cuts: Array[float] = []
		for k in range(need):
			cuts.append(float(dim) * float(k + 1) / float(count))
		return cuts

	# Take the `need` widest gaps, then sort them by position.
	internal.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["e"] - a["s"]) > (b["e"] - b["s"]))
	var selected := internal.slice(0, need)
	selected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["s"]) < int(b["s"]))

	var cuts: Array[float] = []
	for g in selected:
		cuts.append((float(g["s"]) + float(g["e"])) * 0.5)
	return cuts


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
