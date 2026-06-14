extends Node2D

var _music:        AudioStreamPlayer = null
var _music_tracks: Array             = []   # shuffled list of res:// paths
var _music_index:  int               = 0

@onready var _world:        World        = $World
@onready var _fog_manager:  FogManager   = $FogManager
@onready var _avatar:       Avatar       = $Avatar
@onready var _debug:        DebugOverlay = $DebugOverlay
@onready var _pause_menu:   PauseMenu    = $PauseMenu
@onready var _inventory_ui: InventoryUI  = $InventoryUI
@onready var _pickup_hint:  PickupHint   = $PickupHint
@onready var _minimap:      MinimapUI    = $MinimapUI
@onready var _npc_manager:  NpcManager   = $NpcManager

var _actor_refs:    ActorRefOverlay = null
var _npc_dialog:    NpcDialog       = null
var _chest_loot_ui: ChestLootUI     = null
var _forge_ui:      ForgeUI         = null
var _shop_ui:       ShopUI          = null
var _clock_ui:      ClockUI         = null
var _day_night:     DayNightCycle   = null


func _ready() -> void:
	var cursor := load("res://media/cursors/Outline/Default/cursor_none.png") as Texture2D
	if cursor != null:
		Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, Vector2.ZERO)

	_actor_refs = ActorRefOverlay.new()
	_actor_refs.visible = false
	add_child(_actor_refs)

	_npc_dialog = NpcDialog.new()
	add_child(_npc_dialog)

	_chest_loot_ui = ChestLootUI.new()
	add_child(_chest_loot_ui)

	ForgeRecipeDef.load_recipes()
	_forge_ui = ForgeUI.new()
	add_child(_forge_ui)

	_shop_ui = ShopUI.new()
	add_child(_shop_ui)

	_clock_ui = ClockUI.new()
	add_child(_clock_ui)

	_day_night = DayNightCycle.new()
	add_child(_day_night)

	AudioManager.apply_saved_settings()
	_start_music()

	# Wire FogManager and NpcManager to World signals BEFORE world.start() so
	# that every chunk_loaded signal fired during startup is received by both.
	_fog_manager.setup(_world)
	_npc_manager.setup(_world)

	# Load saved inventory (empty Inventory if no save exists).
	_avatar.inventory = SaveManager.load_inventory()
	if _avatar.inventory.count() == 0:
		for entry in [
			[12, 2], [49, 1],         # Iron Bar
			[11, 2], [64, 1],         # Copper Wire
			[15, 2], [16, 1], [9, 1], # Bronze Axe
			[63, 2], [7,  1],         # Glass Vial
			[21, 3], [88, 1],         # Cloth Strip
		]:
			_avatar.inventory.items.append({"type": entry[0], "count": entry[1]})

	_avatar.setup(_world, _fog_manager, _inventory_ui)
	_avatar.npc_interact_requested.connect(_npc_dialog.open)
	_avatar.chest_interact_requested.connect(
		func(chest: ChestNode) -> void:
			_chest_loot_ui.open(_avatar.inventory, chest)
	)
	_avatar.forge_interact_requested.connect(
		func(forge: ForgeNode) -> void:
			_forge_ui.open(_avatar.inventory, forge)
	)

	_npc_dialog.shop_requested.connect(
		func(npc: NpcMelee) -> void:
			_shop_ui.open(_avatar.inventory, npc)
	)
	_inventory_ui.drop_requested.connect(_avatar.drop_item)
	_debug.setup(_world, _fog_manager, _avatar)
	_pause_menu.setup(_fog_manager, _avatar, _npc_manager, _npc_dialog)
	_inventory_ui.setup(_avatar.inventory)
	_pickup_hint.setup(_avatar)
	_minimap.setup(_world, _fog_manager, _avatar)

	# Now load the initial chunks; signals will reach FogManager correctly.
	_world.start()
	_ensure_test_forge()
	_actor_refs.setup(_avatar, _world)

	# Restore saved position, or find a spawn point for a fresh game.
	var spawn := _load_or_find_spawn()
	_avatar.position = spawn
	var player_data  := SaveManager.load_player()
	if not player_data.is_empty():
		_avatar.heading = float(player_data.get("heading", 0.0))
	_world.update_avatar_position(spawn)
	_fog_manager.update_avatar_position(spawn)
	_npc_manager.load_and_spawn()
	_npc_dialog.set_visited_data(SaveManager.load_dialog_visited())
	ShopUI.set_shop_states(SaveManager.load_shop_states())
	GameClock.load_time(SaveManager.load_clock())


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_F4:
		var on := not get_tree().debug_collisions_hint
		get_tree().debug_collisions_hint = on
		_actor_refs.visible              = on
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


func _start_music() -> void:
	for f in DirAccess.get_files_at("res://media/music/"):
		if f.get_extension() == "mp3":
			_music_tracks.append("res://media/music/" + f)
	if _music_tracks.is_empty():
		return
	_music_tracks.shuffle()

	_music     = AudioStreamPlayer.new()
	_music.bus = AudioManager.MUSIC_BUS
	_music.finished.connect(_on_music_finished)
	add_child(_music)
	_play_track(0)


func _play_track(index: int) -> void:
	_music_index = index
	var stream := load(_music_tracks[_music_index]) as AudioStreamMP3
	stream.loop   = false
	_music.stream = stream
	_music.play()


func _on_music_finished() -> void:
	var next := _music_index + 1
	if next >= _music_tracks.size():
		_music_tracks.shuffle()
		next = 0
	_play_track(next)


func _ensure_test_forge() -> void:
	var chunk_data := _world.get_chunk(Vector2i(0, 0))
	var chunk_node := _world.get_chunk_node(Vector2i(0, 0))
	if chunk_data == null or chunk_node == null:
		return
	for y in range(ChunkData.CHUNK_SIZE):
		for x in range(ChunkData.CHUNK_SIZE):
			var cell := chunk_data.get_cell(x, y)
			if cell != null and cell.objects.has(MapObject.Type.FORGE):
				return  # already has a forge somewhere in chunk 0,0
	const CX := 0
	const CY := 0
	var target_cell := chunk_data.get_cell(CX, CY)
	if target_cell == null:
		return
	target_cell.objects.append(MapObject.Type.FORGE)
	var forge := ForgeNode.new()
	forge.position = Vector2((CX + 0.5) * ChunkData.CELL_SIZE, (CY + 0.5) * ChunkData.CELL_SIZE)
	chunk_node.add_child(forge)
	forge.initialize(CX, CY, 0, 0)
	forge._chunk_data = chunk_data


static func _is_cell_clear(cell: CellData) -> bool:
	if cell == null or cell.is_obstacle:
		return false
	for obj_type in cell.objects:
		if not MapObject.is_type_passable(obj_type):
			return false
	return true
