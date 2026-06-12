class_name World
extends Node2D

## Pixel size of one cell and one chunk (mirrors ChunkData constants).
const CELL_SIZE        := ChunkData.CELL_SIZE
const CHUNK_SIZE       := ChunkData.CHUNK_SIZE
const CHUNK_PIXEL_SIZE := ChunkData.CHUNK_PIXEL_SIZE

## Chebyshev radius (in chunks) to keep loaded around the avatar.
const LOAD_RADIUS := 2
## Preload one extra ring beyond LOAD_RADIUS — data only, no scene nodes.
const PRELOAD_RADIUS    := 3
## Max milliseconds per frame spent preloading (keeps frame time stable).
const PRELOAD_BUDGET_MS := 2

## Emitted after a ChunkNode is added to the scene tree.
signal chunk_loaded(coord: Vector2i)
## Emitted just before a ChunkNode is freed.
signal chunk_unloaded(coord: Vector2i)

# loaded chunk data, keyed by Vector2i chunk coordinates
var _chunks: Dictionary = {}
# live ChunkNode scene nodes, keyed by Vector2i chunk coordinates
var _nodes:  Dictionary = {}
# last chunk the avatar was in; sentinel forces a load on first frame
var _last_avatar_chunk := Vector2i(999999, 999999)
# preloaded ChunkData for the ring just outside LOAD_RADIUS (no scene nodes yet)
var _preload_cache: Dictionary = {}
# ordered list of chunk coords still waiting to be preloaded
var _preload_queue: Array = []


func _ready() -> void:
	pass  # Intentionally empty; call start() after connecting signals.


func _process(_delta: float) -> void:
	# Time-budgeted preloading: generate/load chunk data without spawning nodes.
	var t0 := Time.get_ticks_msec()
	while not _preload_queue.is_empty():
		if Time.get_ticks_msec() - t0 >= PRELOAD_BUDGET_MS:
			break
		var coord: Vector2i = _preload_queue.pop_front()
		if _chunks.has(coord) or _preload_cache.has(coord):
			continue
		_preload_cache[coord] = _load_or_generate(coord)


## Load the initial chunks around the world origin.
## Call this from main._ready() AFTER wiring up all signal listeners
## (e.g. FogManager) so they receive chunk_loaded for every startup chunk.
func start() -> void:
	_update_chunks(Vector2i(0, 0))


## Called by Avatar every physics frame.  Triggers chunk streaming when
## the avatar crosses into a new chunk.
func update_avatar_position(world_pos: Vector2) -> void:
	var coord := world_to_chunk_coords(world_pos)
	if coord != _last_avatar_chunk:
		_last_avatar_chunk = coord
		_update_chunks(coord)


## Returns the ChunkData for a loaded chunk, or null.
func get_chunk(coord: Vector2i) -> ChunkData:
	return _chunks.get(coord, null)


## Returns the CellData at the given world position, or null if not loaded.
func get_cell_at(world_pos: Vector2) -> CellData:
	var gc    := world_to_cell_coords(world_pos)
	var cc    := Vector2i(
		int(floor(float(gc.x) / CHUNK_SIZE)),
		int(floor(float(gc.y) / CHUNK_SIZE))
	)
	var chunk := get_chunk(cc)
	if chunk == null:
		return null
	var lx := gc.x - cc.x * CHUNK_SIZE
	var ly := gc.y - cc.y * CHUNK_SIZE
	return chunk.get_cell(lx, ly)


## Returns the live ChunkNode for a loaded chunk, or null.
func get_chunk_node(coord: Vector2i) -> ChunkNode:
	return _nodes.get(coord, null)


## Find the nearest passable, object-free cell within MAX_RADIUS of `near`,
## add item_type to its CellData, spawn a PickableNode with count, return true.
## Returns false when no suitable cell is found.
func drop_item_near(near: Vector2, item_type: int, count: int = 1) -> bool:
	if not PickableItemDef.is_pickable(item_type):
		return false
	const MAX_RADIUS := 8
	var origin := world_to_cell_coords(near)

	for radius in range(MAX_RADIUS + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				# Only check the outer ring at each radius step.
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var gc  := origin + Vector2i(dx, dy)
				var cc  := Vector2i(
					int(floor(float(gc.x) / CHUNK_SIZE)),
					int(floor(float(gc.y) / CHUNK_SIZE))
				)
				var chunk := get_chunk(cc)
				if chunk == null:
					continue
				var lx   := gc.x - cc.x * CHUNK_SIZE
				var ly   := gc.y - cc.y * CHUNK_SIZE
				var cell := chunk.get_cell(lx, ly)
				if cell == null or cell.is_obstacle or not cell.objects.is_empty():
					continue
				cell.add_object(item_type)
				chunk.set_pickable_count(lx, ly, count)
				var node := get_chunk_node(cc)
				if node != null:
					node.spawn_pickable_at(item_type, lx, ly, count)
				return true

	return false


## Convert a world-space position to chunk grid coordinates.
func world_to_chunk_coords(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / CHUNK_PIXEL_SIZE)),
		int(floor(world_pos.y / CHUNK_PIXEL_SIZE))
	)


## Convert a world-space position to global cell coordinates.
func world_to_cell_coords(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / CELL_SIZE)),
		int(floor(world_pos.y / CELL_SIZE))
	)


# ── Private ──────────────────────────────────────────────────────────────────

func _update_chunks(center: Vector2i) -> void:
	# Build the set of chunks that should be actively loaded (with scene nodes).
	var needed: Dictionary = {}
	for dy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			needed[center + Vector2i(dx, dy)] = true

	# Load any missing chunks (uses preload cache when available).
	for coord in needed:
		if not _chunks.has(coord):
			var data := _load_or_generate(coord)
			_chunks[coord] = data
			_spawn_node(coord, data)

	# Unload chunks that are too far away.
	var to_remove: Array = []
	for coord in _chunks:
		if not needed.has(coord):
			to_remove.append(coord)
	for coord in to_remove:
		_unload_chunk(coord)

	# Rebuild preload queue for the ring just outside the active zone.
	var preload_ring: Dictionary = {}
	for dy in range(-PRELOAD_RADIUS, PRELOAD_RADIUS + 1):
		for dx in range(-PRELOAD_RADIUS, PRELOAD_RADIUS + 1):
			var coord := center + Vector2i(dx, dy)
			if not needed.has(coord):
				preload_ring[coord] = true

	_preload_queue.clear()
	for coord in preload_ring:
		if not _chunks.has(coord) and not _preload_cache.has(coord):
			_preload_queue.append(coord)

	# Evict cached data for coords no longer in the preload ring.
	for coord in _preload_cache.keys():
		if not preload_ring.has(coord):
			_preload_cache.erase(coord)


func _load_or_generate(coord: Vector2i) -> ChunkData:
	if _preload_cache.has(coord):
		var data: ChunkData = _preload_cache[coord]
		_preload_cache.erase(coord)
		return data
	if ChunkPersistence.exists(coord.x, coord.y):
		var loaded := ChunkPersistence.load_chunk(coord.x, coord.y)
		if loaded != null:
			return loaded
	var chunk := ChunkGenerator.generate(coord.x, coord.y)
	ChunkPersistence.save(chunk)
	return chunk


func _spawn_node(coord: Vector2i, data: ChunkData) -> void:
	var node      := ChunkNode.new()
	node.position  = Vector2(coord.x * CHUNK_PIXEL_SIZE, coord.y * CHUNK_PIXEL_SIZE)
	add_child(node)
	node.initialize(data)
	_nodes[coord] = node
	emit_signal("chunk_loaded", coord)


func _unload_chunk(coord: Vector2i) -> void:
	emit_signal("chunk_unloaded", coord)
	# Re-save chunk so any runtime mutations (picked-up/dropped objects, etc.)
	# are persisted before the data is discarded from memory.
	if _chunks.has(coord):
		ChunkPersistence.save(_chunks[coord])
	if _nodes.has(coord):
		(_nodes[coord] as ChunkNode).queue_free()
		_nodes.erase(coord)
	_chunks.erase(coord)
