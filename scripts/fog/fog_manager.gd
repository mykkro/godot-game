class_name FogManager
extends Node2D

## View radii in pixels that map to fog levels.
##   ≤ RADIUS_FULL    → VISIBLE  (level 3)
##   ≤ RADIUS_PARTIAL → PARTIAL  (level 2)
##   ≤ RADIUS_DIM     → DIM      (level 1)
##   beyond           → no change (cells keep their existing level)
const RADIUS_FULL    := 220.0
const RADIUS_PARTIAL := 352.0
const RADIUS_DIM     := 480.0

## Minimum avatar movement (px) required before re-evaluating fog.
const UPDATE_THRESHOLD := 16.0

# Loaded fog state, keyed by Vector2i chunk coordinates.
var _fog_data:  Dictionary = {}  # Vector2i → FogData
var _renderers: Dictionary = {}  # Vector2i → FogRenderer

# INF sentinel: any finite avatar position will be further than UPDATE_THRESHOLD.
var _last_update_pos := Vector2(INF, INF)


## Returns the FogData for a loaded chunk, or null if not loaded.
func get_fog_data(coord: Vector2i) -> FogData:
	return _fog_data.get(coord, null)


## Wire this to the World node.  Call from main._ready() BEFORE world.start().
func setup(world: World) -> void:
	world.chunk_loaded.connect(_on_chunk_loaded)
	world.chunk_unloaded.connect(_on_chunk_unloaded)


## Called every physics frame by Avatar (mirrors world.update_avatar_position).
func update_avatar_position(world_pos: Vector2) -> void:
	if world_pos.distance_to(_last_update_pos) < UPDATE_THRESHOLD:
		return
	_last_update_pos = world_pos
	_update_all_fog(world_pos)


## Persist all currently loaded fog chunks to disk (call before quitting/menu).
func save_all() -> void:
	for coord in _fog_data:
		FogPersistence.save(_fog_data[coord])


# ── Chunk event handlers ──────────────────────────────────────────────────────

func _on_chunk_loaded(coord: Vector2i) -> void:
	# Load existing fog or start fresh.
	var data := FogPersistence.load_fog(coord.x, coord.y)
	if data == null:
		data = FogData.new(coord.x, coord.y)
	_fog_data[coord] = data

	_spawn_renderer(coord, data)

	# If the avatar already has a known position, reveal cells immediately.
	if is_finite(_last_update_pos.x):
		_update_chunk_fog(coord, data, _last_update_pos)


func _on_chunk_unloaded(coord: Vector2i) -> void:
	# Persist fog before discarding.
	if _fog_data.has(coord):
		FogPersistence.save(_fog_data[coord])
		_fog_data.erase(coord)
	if _renderers.has(coord):
		(_renderers[coord] as FogRenderer).queue_free()
		_renderers.erase(coord)


# ── Fog computation ───────────────────────────────────────────────────────────

func _update_all_fog(world_pos: Vector2) -> void:
	for coord in _fog_data:
		_update_chunk_fog(coord, _fog_data[coord], world_pos)


func _update_chunk_fog(coord: Vector2i, fog: FogData, world_pos: Vector2) -> void:
	var origin := Vector2(
		coord.x * ChunkData.CHUNK_PIXEL_SIZE,
		coord.y * ChunkData.CHUNK_PIXEL_SIZE
	)

	# Early-out: skip entirely if the chunk's closest point is beyond the DIM radius.
	var chunk_rect := Rect2(origin, Vector2(ChunkData.CHUNK_PIXEL_SIZE, ChunkData.CHUNK_PIXEL_SIZE))
	if _rect_min_dist(chunk_rect, world_pos) > RADIUS_DIM:
		return

	var changed := false

	for y in range(ChunkData.CHUNK_SIZE):
		for x in range(ChunkData.CHUNK_SIZE):
			var cell_center := origin + Vector2(
				(x + 0.5) * ChunkData.CELL_SIZE,
				(y + 0.5) * ChunkData.CELL_SIZE
			)
			var dist: float = world_pos.distance_to(cell_center)

			var new_level: int
			if dist <= RADIUS_FULL:
				new_level = FogData.VISIBLE
			elif dist <= RADIUS_PARTIAL:
				new_level = FogData.PARTIAL
			elif dist <= RADIUS_DIM:
				new_level = FogData.DIM
			else:
				continue  # Beyond DIM radius — leave cell unchanged.

			# Fog only increases; once explored, it stays explored.
			if new_level > fog.get_level(x, y):
				fog.set_level(x, y, new_level)
				changed = true

	if changed and _renderers.has(coord):
		(_renderers[coord] as FogRenderer).refresh(fog)


# ── Scene helpers ─────────────────────────────────────────────────────────────

func _spawn_renderer(coord: Vector2i, data: FogData) -> void:
	var renderer := FogRenderer.new()
	renderer.position = Vector2(
		coord.x * ChunkData.CHUNK_PIXEL_SIZE,
		coord.y * ChunkData.CHUNK_PIXEL_SIZE
	)
	add_child(renderer)
	renderer.initialize(data)
	_renderers[coord] = renderer


## Returns the minimum distance from `point` to the nearest edge of `rect`.
## Returns 0 when the point is inside the rect.
static func _rect_min_dist(rect: Rect2, point: Vector2) -> float:
	var dx := maxf(0.0, maxf(rect.position.x - point.x, point.x - rect.end.x))
	var dy := maxf(0.0, maxf(rect.position.y - point.y, point.y - rect.end.y))
	return sqrt(dx * dx + dy * dy)
