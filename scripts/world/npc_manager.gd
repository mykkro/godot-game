class_name NpcManager
extends Node

const SPAWN_CHANCE        := 0.70        # NpcKnight probability per chunk
const MELEE_SPAWN_CHANCE  := 0.50        # NpcMelee probability per chunk (at most 1)
const QUEST_GIVER_CHANCE  := 1.0 / 3.0  # Fraction of melee NPCs that are quest givers

var _world:         World      = null
var _melee_spawned: Dictionary = {}   # Vector2i → true for chunks that have a melee NPC
var _next_melee_id: int        = 1
var _next_knight_id: int       = 1


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
				if not d.has("perks"):
					_roll_trader_perk(npc)
				_bump_counter(npc.npc_id, "melee_", _next_melee_id)
				# Mark chunk so we don't double-spawn on chunk-load signal.
				var cc := _chunk_of(npc.position)
				_melee_spawned[cc] = true
			_:
				var npc := NpcKnight.new()
				_world.add_child(npc)
				npc.restore_from_dict(d)
				_bump_counter(npc.npc_id, "knight_", _next_knight_id)


func _on_chunk_loaded(coord: Vector2i) -> void:
	# Wandering greatsword knight (temporary).
	if randf() < SPAWN_CHANCE:
		var spawn := _find_spawn_pos(coord)
		if is_finite(spawn.x):
			var npc       := NpcKnight.new()
			npc.npc_id     = "knight_%03d" % _next_knight_id
			_next_knight_id += 1
			npc.position   = spawn
			_world.add_child(npc)

	# Idle melee NPC (permanent, at most 1 per chunk).
	if not _melee_spawned.has(coord) and randf() < MELEE_SPAWN_CHANCE:
		var spawn := _find_spawn_pos(coord)
		if is_finite(spawn.x):
			var npc        := NpcMelee.new()
			npc.npc_id      = "melee_%03d" % _next_melee_id
			_next_melee_id  += 1
			npc.position    = spawn
			npc.birth_time  = GameClock.get_game_time()
			_roll_trader_perk(npc)
			_world.add_child(npc)
			if randf() < QUEST_GIVER_CHANCE:
				npc.make_quest_giver(NpcMelee.NAMES[randi() % NpcMelee.NAMES.size()])
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


## Advance the given counter ref past the numeric suffix of a loaded NPC id.
func _bump_counter(id: String, prefix: String, counter: int) -> void:
	if id.begins_with(prefix):
		var n := int(id.substr(prefix.length()))
		if n >= counter:
			if prefix == "melee_":
				_next_melee_id = n + 1
			else:
				_next_knight_id = n + 1


static func _roll_trader_perk(npc: NpcMelee) -> void:
	var r := randf()
	if   r < 0.05: npc.perks.set_level(PerkDef.ID.TRADER, 4)
	elif r < 0.15: npc.perks.set_level(PerkDef.ID.TRADER, 3)
	elif r < 0.30: npc.perks.set_level(PerkDef.ID.TRADER, 2)
	elif r < 0.55: npc.perks.set_level(PerkDef.ID.TRADER, 1)


static func _chunk_of(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / ChunkData.CHUNK_PIXEL_SIZE)),
		int(floor(world_pos.y / ChunkData.CHUNK_PIXEL_SIZE))
	)
