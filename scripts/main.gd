extends Node2D

@onready var _world:       World        = $World
@onready var _fog_manager: FogManager   = $FogManager
@onready var _avatar:      Avatar       = $Avatar
@onready var _debug:       DebugOverlay = $DebugOverlay
@onready var _pause_menu:  PauseMenu    = $PauseMenu


func _ready() -> void:
	# Wire FogManager to World signals BEFORE world.start() so that every
	# chunk_loaded signal fired during startup is received by FogManager.
	_fog_manager.setup(_world)
	_avatar.setup(_world, _fog_manager)
	_debug.setup(_world, _fog_manager, _avatar)
	_pause_menu.setup(_fog_manager)

	# Now load the initial chunks; signals will reach FogManager correctly.
	_world.start()

	# Position the avatar on the first passable cell near chunk (0,0) centre.
	var spawn := _find_spawn_position()
	_avatar.position = spawn
	_world.update_avatar_position(spawn)
	_fog_manager.update_avatar_position(spawn)


# ── Private ──────────────────────────────────────────────────────────────────

func _find_spawn_position() -> Vector2:
	var chunk := _world.get_chunk(Vector2i(0, 0))
	if chunk == null:
		return Vector2(ChunkData.CHUNK_PIXEL_SIZE * 0.5,
					   ChunkData.CHUNK_PIXEL_SIZE * 0.5)

	# Scan cells row-by-row; first clear cell wins.
	for y in range(ChunkData.CHUNK_SIZE):
		for x in range(ChunkData.CHUNK_SIZE):
			var cell := chunk.get_cell(x, y)
			if _is_cell_clear(cell):
				return Vector2(
					(x + 0.5) * ChunkData.CELL_SIZE,
					(y + 0.5) * ChunkData.CELL_SIZE
				)

	# Fallback: centre of chunk 0,0 (shouldn't normally be needed).
	return Vector2(ChunkData.CHUNK_PIXEL_SIZE * 0.5,
				   ChunkData.CHUNK_PIXEL_SIZE * 0.5)


static func _is_cell_clear(cell: CellData) -> bool:
	if cell == null or cell.is_obstacle:
		return false
	for obj_type in cell.objects:
		if not MapObject.is_type_passable(obj_type):
			return false
	return true
