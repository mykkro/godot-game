class_name NpcManager
extends Node

const SPAWN_CHANCE       := 0.70   # NpcKnight probability per chunk
const MELEE_SPAWN_CHANCE := 0.50   # NpcMelee probability per chunk (at most 1)

var _world:         World      = null
var _melee_spawned: Dictionary = {}   # Vector2i → true for chunks that have a melee NPC


## Wire to World BEFORE world.start() so startup chunks are covered.
func setup(world: World) -> void:
	_world = world
	world.chunk_loaded.connect(_on_chunk_loaded)


## Collect every live NPC and persist their state.
func save() -> void:
	var data: Array = []
	for child in _world.get_children():
		if child is NpcKnight:
			data.append((child as NpcKnight).to_dict())
		elif child is NpcMelee:
			data.append((child as NpcMelee).to_dict())
	SaveManager.save_npcs(data)


## Spawn NPCs from a previously saved snapshot.
## Call after world.start() so the scene tree is ready.
func load_and_spawn() -> void:
	for entry in SaveManager.load_npcs():
		var d := entry as Dictionary
		match d.get("type", "knight"):
			"melee":
				var npc := NpcMelee.new()
				_world.add_child(npc)
				npc.restore_from_dict(d)
				# Mark chunk so we don't double-spawn on chunk-load signal.
				var cc := _chunk_of(npc.position)
				_melee_spawned[cc] = true
			_:
				var npc := NpcKnight.new()
				_world.add_child(npc)
				npc.restore_from_dict(d)


func _on_chunk_loaded(coord: Vector2i) -> void:
	# Wandering greatsword knight (temporary).
	if randf() < SPAWN_CHANCE:
		var spawn := _find_spawn_pos(coord)
		if is_finite(spawn.x):
			var npc      := NpcKnight.new()
			npc.position  = spawn
			_world.add_child(npc)

	# Idle melee NPC (permanent, at most 1 per chunk).
	if not _melee_spawned.has(coord) and randf() < MELEE_SPAWN_CHANCE:
		var spawn := _find_spawn_pos(coord)
		if is_finite(spawn.x):
			var npc      := NpcMelee.new()
			npc.position  = spawn
			_world.add_child(npc)
			_melee_spawned[coord] = true


## Returns world-space centre of a random passable, empty cell in the chunk,
## or Vector2(INF, INF) if none found within 20 attempts.
func _find_spawn_pos(chunk_coord: Vector2i) -> Vector2:
	var chunk := _world.get_chunk(chunk_coord)
	if chunk == null:
		return Vector2(INF, INF)

	for _i in range(20):
		var lx   := randi() % ChunkData.CHUNK_SIZE
		var ly   := randi() % ChunkData.CHUNK_SIZE
		var cell := chunk.get_cell(lx, ly)
		if cell == null or cell.is_obstacle or not cell.objects.is_empty():
			continue
		var ox := chunk_coord.x * ChunkData.CHUNK_PIXEL_SIZE
		var oy := chunk_coord.y * ChunkData.CHUNK_PIXEL_SIZE
		return Vector2(
			ox + (lx + 0.5) * ChunkData.CELL_SIZE,
			oy + (ly + 0.5) * ChunkData.CELL_SIZE
		)

	return Vector2(INF, INF)


static func _chunk_of(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / ChunkData.CHUNK_PIXEL_SIZE)),
		int(floor(world_pos.y / ChunkData.CHUNK_PIXEL_SIZE))
	)
