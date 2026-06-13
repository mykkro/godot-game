class_name MinimapUI
extends CanvasLayer

const CELLS      := 128
const PX_CELL    := 2
const MAP_SIZE   := CELLS * PX_CELL   # 256 px
const BORDER     := 2
const PANEL_SIZE := MAP_SIZE + BORDER * 2  # 260 px

var _world:       World      = null
var _fog_manager: FogManager = null
var _avatar:      Avatar     = null

var _image:        Image        = null
var _texture:      ImageTexture = null
var _texture_rect: TextureRect  = null
var _container:    Control      = null
var _show:         bool         = false
var _last_center:  Vector2i     = Vector2i(-99999, -99999)


func setup(world: World, fog_manager: FogManager, avatar: Avatar) -> void:
	_world       = world
	_fog_manager = fog_manager
	_avatar      = avatar


func _ready() -> void:
	layer = 65

	_image   = Image.create(CELLS, CELLS, false, Image.FORMAT_RGB8)
	_texture = ImageTexture.create_from_image(_image)

	_texture_rect = TextureRect.new()
	_texture_rect.texture        = _texture
	_texture_rect.position       = Vector2(BORDER, BORDER)
	_texture_rect.size           = Vector2(MAP_SIZE, MAP_SIZE)
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_container.offset_left   = -(PANEL_SIZE + 8)
	_container.offset_top    = -(PANEL_SIZE + 8)
	_container.offset_right  = -8
	_container.offset_bottom = -8
	_container.add_child(bg)
	_container.add_child(_texture_rect)
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
			_last_center = Vector2i(-99999, -99999)
			_refresh()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _show or _avatar == null:
		return
	var center := _world_to_cell(_avatar.position)
	if center != _last_center:
		_last_center = center
		_refresh()


func _refresh() -> void:
	if _avatar == null or _world == null or _fog_manager == null:
		return
	var center := _world_to_cell(_avatar.position)
	var half   := CELLS / 2  # 64

	for row in range(CELLS):
		for col in range(CELLS):
			var gx := center.x - half + col
			var gy := center.y - half + row
			_image.set_pixel(col, row, _cell_color(Vector2i(gx, gy)))

	# Quest-giver dots: 3×3 yellow for each fog-revealed NpcMelee
	var q_color := NpcMelee.QUEST_MARK_COLOR
	for child in _world.get_children():
		if not (child is NpcMelee) or not (child as NpcMelee).is_quest_giver:
			continue
		var gc  := _world_to_cell((child as NpcMelee).position)
		var px  := half + (gc.x - center.x)
		var py  := half + (gc.y - center.y)
		if px < 0 or px >= CELLS or py < 0 or py >= CELLS:
			continue
		if _fog_level_at(gc) == FogData.UNEXPLORED:
			continue
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var ix := px + dx
				var iy := py + dy
				if ix >= 0 and ix < CELLS and iy >= 0 and iy < CELLS:
					_image.set_pixel(ix, iy, q_color)

	# Player dot: 3×3 white at center — painted last so it is always on top
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_image.set_pixel(half + dx, half + dy, Color.WHITE)

	_texture.update(_image)


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
	var level := _fog_level_at(gc)
	if level == FogData.UNEXPLORED:
		return Color.BLACK

	var cs := ChunkData.CHUNK_SIZE
	var cc  := Vector2i(
		int(floor(float(gc.x) / float(cs))),
		int(floor(float(gc.y) / float(cs)))
	)
	var lx := gc.x - cc.x * cs
	var ly := gc.y - cc.y * cs

	var chunk := _world.get_chunk(cc)
	if chunk == null:
		return Color.BLACK

	var cell := chunk.get_cell(lx, ly)
	var base := _terrain_color(cell.terrain_type)

	if not cell.objects.is_empty():
		base = base.darkened(0.35)

	var b: float
	match level:
		FogData.DIM:     b = 0.25
		FogData.PARTIAL: b = 0.6
		_:               b = 1.0  # VISIBLE

	return Color(base.r * b, base.g * b, base.b * b)


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
