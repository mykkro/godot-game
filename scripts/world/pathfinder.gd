class_name Pathfinder

## Maximum A* iterations before giving up (guards against huge open areas).
const MAX_STEPS := 2000
## Reject paths longer than this multiple of the straight-line distance.
const MAX_RATIO := 3.0

const CELL_SIZE  := ChunkData.CELL_SIZE
const CHUNK_SIZE := ChunkData.CHUNK_SIZE

## Returns world-space cell-centre waypoints from `from_world` to `to_world`,
## or an empty array when no valid path exists or the path is too winding.
static func find_path(world: World, from_world: Vector2, to_world: Vector2) -> Array[Vector2]:
	var start := world.world_to_cell_coords(from_world)
	var goal  := world.world_to_cell_coords(to_world)

	if start == goal:
		return []

	var goal_cell := world.get_cell_at(to_world)
	if goal_cell == null or goal_cell.is_obstacle:
		return []

	var g_score:   Dictionary = { start: 0.0 }
	var came_from: Dictionary = {}
	var open:      Array      = []          # min-heap of [f_score, Vector2i]

	_heap_push(open, [_h(start, goal), start])

	var steps := 0
	while not open.is_empty() and steps < MAX_STEPS:
		steps += 1
		var entry := _heap_pop(open)
		var cur   := entry[1] as Vector2i

		if cur == goal:
			return _build_and_validate(came_from, goal, from_world, to_world)

		var cur_g := float(g_score.get(cur, INF))
		for nb in _neighbors(cur, world):
			var ng := cur_g + 1.0
			if ng < float(g_score.get(nb, INF)):
				g_score[nb]   = ng
				came_from[nb] = cur
				_heap_push(open, [ng + _h(nb, goal), nb])

	return []


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _h(a: Vector2i, b: Vector2i) -> float:
	return float(abs(a.x - b.x) + abs(a.y - b.y))


static func _neighbors(cell: Vector2i, world: World) -> Array:
	var result: Array = []
	for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var n  := cell + (d as Vector2i)
		var nw := Vector2((n.x + 0.5) * CELL_SIZE, (n.y + 0.5) * CELL_SIZE)
		var c  := world.get_cell_at(nw)
		if c != null and not c.is_obstacle:
			result.append(n)
	return result


static func _build_and_validate(
		came_from: Dictionary,
		goal:      Vector2i,
		from_w:    Vector2,
		to_w:      Vector2) -> Array[Vector2]:

	var path: Array[Vector2] = []
	var cur := goal
	while came_from.has(cur):
		path.append(Vector2((cur.x + 0.5) * CELL_SIZE, (cur.y + 0.5) * CELL_SIZE))
		cur = came_from[cur] as Vector2i
	path.reverse()

	var euclidean := from_w.distance_to(to_w)
	if euclidean > 0.0 and float(path.size()) * CELL_SIZE > MAX_RATIO * euclidean:
		return []
	return path


# ── Min-heap ──────────────────────────────────────────────────────────────────

static func _heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if float(heap[p][0]) <= float(item[0]):
			break
		var tmp: Array = heap[p]
		heap[p] = heap[i]
		heap[i] = tmp
		i = p


static func _heap_pop(heap: Array) -> Array:
	var top:  Array = heap[0]
	var last: Array = heap[heap.size() - 1]
	heap.resize(heap.size() - 1)
	if not heap.is_empty():
		heap[0] = last
		_heap_sift_down(heap, 0)
	return top


static func _heap_sift_down(heap: Array, i: int) -> void:
	var n := heap.size()
	while true:
		var s := i
		var l := 2 * i + 1
		var r := 2 * i + 2
		if l < n and float(heap[l][0]) < float(heap[s][0]):
			s = l
		if r < n and float(heap[r][0]) < float(heap[s][0]):
			s = r
		if s == i:
			break
		var tmp: Array = heap[i]
		heap[i] = heap[s]
		heap[s] = tmp
		i = s
