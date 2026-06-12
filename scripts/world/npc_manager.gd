class_name NpcManager
extends Node

const SPAWN_CHANCE := 0.35   # probability per newly loaded chunk

var _world: World = null


## Wire to World BEFORE world.start() so startup chunks are covered.
func setup(world: World) -> void:
	_world = world
	world.chunk_loaded.connect(_on_chunk_loaded)


func _on_chunk_loaded(coord: Vector2i) -> void:
	if randf() > SPAWN_CHANCE:
		return
	var spawn := _find_spawn_pos(coord)
	if not is_finite(spawn.x):
		return
	var npc      := NpcKnight.new()
	npc.position  = spawn
	_world.add_child(npc)


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
