class_name MinimapUI
extends CanvasLayer

const CELLS      := 128
const PX_CELL    := 2
const MAP_SIZE   := CELLS * PX_CELL   # 256 px
const BORDER     := 2
const PANEL_SIZE := MAP_SIZE + BORDER * 2  # 260 px

const ZOOM_MIN   := 16    # half-width in world cells (max zoom-in)
const ZOOM_MAX   := 192   # half-width in world cells (max zoom-out)
const ZOOM_STEP  := 16    # world cells changed per scroll tick
const FLASH_HALF := 0.40  # seconds per flash half-period

var _world:       World      = null
var _fog_manager: FogManager = null
var _avatar:      Avatar     = null

var _image:        Image        = null
var _texture:      ImageTexture = null
var _texture_rect: TextureRect  = null
var _container:    Control      = null
var _tooltip_lbl:  Label        = null
var _show:         bool         = false
var _last_center:  Vector2i     = Vector2i(-99999, -99999)

var _zoom_half:     int   = CELLS / 2   # 64 world cells each side (default)
var _flash_timer:   float = 0.0
var _flash_visible: bool  = true
## {px, py, name} for each dot drawn this refresh — drives hover tooltip.
var _dot_hits: Array[Dictionary] = []
## chunk_coord → PackedColorArray[CHUNK_SIZE²] of base terrain colours (no fog).
## Persists across chunk unloads so the minimap never goes blank on revisited areas.
var _terrain_cache: Dictionary = {}


func setup(world: World, fog_manager: FogManager, avatar: Avatar) -> void:
	_world       = world
	_fog_manager = fog_manager
	_avatar      = avatar
	world.chunk_loaded.connect(_on_chunk_loaded)


func _ready() -> void:
	layer = 65

	_image   = Image.create(CELLS, CELLS, false, Image.FORMAT_RGB8)
	_texture = ImageTexture.create_from_image(_image)

	_texture_rect = TextureRect.new()
	_texture_rect.texture        = _texture
	_texture_rect.position       = Vector2(BORDER, BORDER)
	_texture_rect.size           = Vector2(MAP_SIZE, MAP_SIZE)
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.mouse_filter   = Control.MOUSE_FILTER_STOP
	_texture_rect.gui_input.connect(_on_minimap_input)
	_texture_rect.mouse_exited.connect(func() -> void: _tooltip_lbl.visible = false)

	_tooltip_lbl = Label.new()
	_tooltip_lbl.add_theme_font_size_override("font_size", 11)
	_tooltip_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.85))
	_tooltip_lbl.add_theme_constant_override("outline_size", 2)
	_tooltip_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_tooltip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_lbl.visible      = false

	var bg := ColorRect.new()
	bg.color        = Color(0.12, 0.12, 0.12)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_container.offset_left   = -(PANEL_SIZE + 8)
	_container.offset_top    = -(PANEL_SIZE + 8)
	_container.offset_right  = -8
	_container.offset_bottom = -8
	_container.add_child(bg)
	_container.add_child(_texture_rect)
	_container.add_child(_tooltip_lbl)
	add_child(_container)

	_container.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if ke.keycode == KEY_M and ke.pressed and not ke.echo:
		_show = not _show
		_container.visible = _show
		if _show:
			_last_center           = Vector2i(-99999, -99999)
			_texture_rect.position = Vector2(BORDER, BORDER)
			_refresh()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _show or _avatar == null:
		return

	# Flash timer — reset when nothing is tracked so it starts visible on next track.
	if QuestManager.tracked_quest_id.is_empty():
		_flash_visible = true
		_flash_timer   = 0.0
	else:
		_flash_timer += delta
		if _flash_timer >= FLASH_HALF:
			_flash_timer   = fmod(_flash_timer, FLASH_HALF)
			_flash_visible = not _flash_visible
			_refresh()

	# Sub-cell smooth scroll: shift the TextureRect by the player's fractional
	# position within the current cell so the map scrolls continuously instead
	# of snapping by one cell at a time.
	var scale  := float(_zoom_half) / float(CELLS / 2)
	var cs     := float(ChunkData.CELL_SIZE)
	var pos    := _avatar.global_position
	var frac_x := fposmod(pos.x / cs, 1.0)
	var frac_y := fposmod(pos.y / cs, 1.0)
	var off_x  := frac_x * float(PX_CELL) / scale
	var off_y  := frac_y * float(PX_CELL) / scale
	_texture_rect.position = Vector2(float(BORDER) - off_x, float(BORDER) - off_y)

	var center := _world_to_cell(pos)
	if center != _last_center:
		_last_center = center
		_refresh()


func _refresh() -> void:
	if _avatar == null or _world == null or _fog_manager == null:
		return
	var center := _world_to_cell(_avatar.global_position)
	var half   := CELLS / 2   # image centre pixel = 64
	var scale  := float(_zoom_half) / float(half)

	_dot_hits.clear()

	# Terrain.
	for row in range(CELLS):
		for col in range(CELLS):
			var gx := center.x + int(round(float(col - half) * scale))
			var gy := center.y + int(round(float(row - half) * scale))
			_image.set_pixel(col, row, _cell_color(Vector2i(gx, gy)))

	# Quest-giver NPC dots (3×3 yellow).
	var q_color := NpcMelee.QUEST_MARK_COLOR
	for child in _world.get_children():
		if not (child is NpcMelee):
			continue
		var npc := child as NpcMelee
		if not npc.is_quest_giver:
			continue
		var gc := _world_to_cell(npc.global_position)
		var px := half + int(round(float(gc.x - center.x) / scale))
		var py := half + int(round(float(gc.y - center.y) / scale))
		if px < 0 or px >= CELLS or py < 0 or py >= CELLS:
			continue
		if _fog_level_at(gc) == FogData.UNEXPLORED:
			continue
		_paint_dot(px, py, q_color)
		if not npc.npc_name.is_empty():
			_dot_hits.append({"px": px, "py": py, "name": npc.npc_name})

	# Tracked quest indicator (flashing cyan; clamped to border when off-screen).
	if not QuestManager.tracked_quest_id.is_empty():
		_draw_tracked_quest(center, half, scale)

	# Player dot — always last so it is never covered.
	_paint_dot(half, half, Color.WHITE)

	_texture.update(_image)


func _draw_tracked_quest(center: Vector2i, half: int, scale: float) -> void:
	var tracked: QuestInstance = null
	for q: QuestInstance in QuestManager.active_quests:
		if q.quest_id == QuestManager.tracked_quest_id:
			tracked = q
			break
	if tracked == null:
		return

	# Find giver NPC in world tree.
	var npc_pos := Vector2.ZERO
	var found   := false
	for child in _world.get_children():
		if child is NpcMelee and (child as NpcMelee).npc_id == tracked.giver_npc_id:
			npc_pos = (child as NpcMelee).global_position
			found   = true
			break
	if not found:
		return

	var gc  := _world_to_cell(npc_pos)
	var px  := half + int(round(float(gc.x - center.x) / scale))
	var py  := half + int(round(float(gc.y - center.y) / scale))

	# Clamp to minimap border only when the NPC is truly outside the image.
	if px < 0 or px >= CELLS or py < 0 or py >= CELLS:
		const EDGE := 3   # how close to the image edge the border indicator sits
		var dir_x  := float(px - half)
		var dir_y  := float(py - half)
		var t      := 1.0
		if abs(dir_x) > 0.0:
			t = minf(t, float(half - EDGE) / abs(dir_x))
		if abs(dir_y) > 0.0:
			t = minf(t, float(half - EDGE) / abs(dir_y))
		px = half + int(dir_x * t)
		py = half + int(dir_y * t)

	if _flash_visible:
		_paint_dot(px, py, Color(0.15, 0.90, 1.0))
	# Always register for tooltip even when flash-invisible.
	_dot_hits.append({"px": px, "py": py, "name": "↺ " + tracked.giver_npc_name})


func _paint_dot(cx: int, cy: int, color: Color) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var ix := cx + dx
			var iy := cy + dy
			if ix >= 0 and ix < CELLS and iy >= 0 and iy < CELLS:
				_image.set_pixel(ix, iy, color)


func _on_minimap_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_half = maxi(ZOOM_MIN, _zoom_half - ZOOM_STEP)
			_force_refresh()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_half = mini(ZOOM_MAX, _zoom_half + ZOOM_STEP)
			_force_refresh()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_on_hover((event as InputEventMouseMotion).position)


func _on_hover(local_pos: Vector2) -> void:
	# local_pos is in TextureRect space (0..MAP_SIZE); convert to image pixel coords.
	var img_x := int(local_pos.x / PX_CELL)
	var img_y := int(local_pos.y / PX_CELL)
	for hit: Dictionary in _dot_hits:
		var dx := img_x - int(hit["px"])
		var dy := img_y - int(hit["py"])
		if dx * dx + dy * dy <= 4:   # within ~2 px radius
			_tooltip_lbl.text = hit["name"] as String
			# Convert to container space using the TextureRect's current position
			# (which shifts with the sub-cell scroll offset).
			var tp := _texture_rect.position + local_pos + Vector2(8.0, -18.0)
			tp.x = clampf(tp.x, 0.0, float(PANEL_SIZE) - 80.0)
			tp.y = clampf(tp.y, 0.0, float(PANEL_SIZE) - 14.0)
			_tooltip_lbl.position = tp
			_tooltip_lbl.visible  = true
			return
	_tooltip_lbl.visible = false


func _force_refresh() -> void:
	_last_center = Vector2i(-99999, -99999)
	if _show:
		_refresh()


func _fog_level_at(gc: Vector2i) -> int:
	var cs := ChunkData.CHUNK_SIZE
	var cc  := Vector2i(
		int(floor(float(gc.x) / float(cs))),
		int(floor(float(gc.y) / float(cs)))
	)
	var fog := _fog_manager.get_fog_data(cc)
	if fog == null:
		return FogData.UNEXPLORED
	return fog.get_level(gc.x - cc.x * cs, gc.y - cc.y * cs)


func _cell_color(gc: Vector2i) -> Color:
	var cs := ChunkData.CHUNK_SIZE
	var cc  := Vector2i(
		int(floor(float(gc.x) / float(cs))),
		int(floor(float(gc.y) / float(cs)))
	)
	var lx := gc.x - cc.x * cs
	var ly := gc.y - cc.y * cs

	# Resolve base terrain colour: prefer live chunk, fall back to cache.
	var base: Color
	var chunk := _world.get_chunk(cc)
	if chunk != null:
		var cell := chunk.get_cell(lx, ly)
		base = _terrain_color(cell.terrain_type)
		if not cell.objects.is_empty():
			base = base.darkened(0.35)
		_write_cache(cc, lx, ly, cs, base)
	elif _terrain_cache.has(cc):
		base = (_terrain_cache[cc] as PackedColorArray)[ly * cs + lx]
	else:
		return Color.BLACK   # chunk never loaded — truly unknown

	# Apply fog brightness.  Loaded-but-unexplored terrain shows at 12 % so
	# the minimap is never blank for a chunk that is in memory or was cached.
	var level := _fog_level_at(gc)
	var b: float
	match level:
		FogData.UNEXPLORED: b = 0.12
		FogData.DIM:        b = 0.25
		FogData.PARTIAL:    b = 0.60
		_:                  b = 1.00   # VISIBLE

	return Color(base.r * b, base.g * b, base.b * b)


func _write_cache(cc: Vector2i, lx: int, ly: int, cs: int, color: Color) -> void:
	if not _terrain_cache.has(cc):
		var arr := PackedColorArray()
		arr.resize(cs * cs)
		_terrain_cache[cc] = arr
	(_terrain_cache[cc] as PackedColorArray)[ly * cs + lx] = color


## Pre-cache every cell of a freshly-loaded chunk and refresh the minimap so
## the new terrain appears immediately without waiting for player movement.
func _on_chunk_loaded(coord: Vector2i) -> void:
	var chunk := _world.get_chunk(coord)
	if chunk == null:
		return
	var cs := ChunkData.CHUNK_SIZE
	if not _terrain_cache.has(coord):
		var arr := PackedColorArray()
		arr.resize(cs * cs)
		_terrain_cache[coord] = arr
	var cache: PackedColorArray = _terrain_cache[coord]
	for ly in range(cs):
		for lx in range(cs):
			var cell := chunk.get_cell(lx, ly)
			var base := _terrain_color(cell.terrain_type)
			if not cell.objects.is_empty():
				base = base.darkened(0.35)
			cache[ly * cs + lx] = base
	if _show:
		_force_refresh()


static func _terrain_color(filename: String) -> Color:
	var tile := TileRegistry.get_tile(filename)
	var tags: Array = tile.get("tags", []) if tile else []
	if tags.has("aquatic") or tags.has("water"):
		return Color(0.20, 0.40, 0.75)
	if tags.has("ice") or tags.has("snow"):
		return Color(0.85, 0.90, 0.95)
	if tags.has("sand") or tags.has("coastal"):
		return Color(0.85, 0.78, 0.50)
	if tags.has("cave") or tags.has("rock"):
		return Color(0.38, 0.33, 0.28)
	if tags.has("swamp") or tags.has("algae"):
		return Color(0.28, 0.42, 0.18)
	return Color(0.22, 0.55, 0.18)


static func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / ChunkData.CELL_SIZE)),
		int(floor(world_pos.y / ChunkData.CELL_SIZE))
	)
