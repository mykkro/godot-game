extends Node2D

@onready var _world:        World        = $World
@onready var _fog_manager:  FogManager   = $FogManager
@onready var _avatar:       Avatar       = $Avatar
@onready var _debug:        DebugOverlay = $DebugOverlay
@onready var _pause_menu:   PauseMenu    = $PauseMenu
@onready var _inventory_ui: InventoryUI  = $InventoryUI
@onready var _pickup_hint:  PickupHint   = $PickupHint
@onready var _minimap:      MinimapUI    = $MinimapUI
@onready var _npc_manager:  NpcManager   = $NpcManager


func _ready() -> void:
	# Wire FogManager and NpcManager to World signals BEFORE world.start() so
	# that every chunk_loaded signal fired during startup is received by both.
	_fog_manager.setup(_world)
	_npc_manager.setup(_world)

	# Load saved inventory (empty Inventory if no save exists).
	_avatar.inventory = SaveManager.load_inventory()

	_avatar.setup(_world, _fog_manager, _inventory_ui)
	_inventory_ui.drop_requested.connect(_avatar.drop_item)
	_debug.setup(_world, _fog_manager, _avatar)
	_pause_menu.setup(_fog_manager, _avatar, _npc_manager)
	_inventory_ui.setup(_avatar.inventory)
	_pickup_hint.setup(_avatar)
	_minimap.setup(_world, _fog_manager, _avatar)

	# Now load the initial chunks; signals will reach FogManager correctly.
	_world.start()

	# Restore saved position, or find a spawn point for a fresh game.
	var spawn := _load_or_find_spawn()
	_avatar.position = spawn
	var player_data  := SaveManager.load_player()
	if not player_data.is_empty():
		_avatar.heading = float(player_data.get("heading", 0.0))
	_world.update_avatar_position(spawn)
	_fog_manager.update_avatar_position(spawn)
	_npc_manager.load_and_spawn()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_F4:
		get_tree().debug_collisions_hint = not get_tree().debug_collisions_hint
		get_viewport().set_input_as_handled()


# ── Private ──────────────────────────────────────────────────────────────────

## Returns saved avatar position when a save exists, otherwise scans for
## the first passable cell near the origin.
func _load_or_find_spawn() -> Vector2:
	var data := SaveManager.load_player()
	if not data.is_empty():
		return Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	return _find_spawn_position()

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
