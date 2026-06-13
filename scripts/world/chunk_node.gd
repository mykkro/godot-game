class_name ChunkNode
extends Node2D

## Mirrors ChunkData constants for local readability.
const CELL_SIZE  := ChunkData.CELL_SIZE
const CHUNK_SIZE := ChunkData.CHUNK_SIZE

var _data: ChunkData  = null
var _body: StaticBody2D = null


func _ready() -> void:
	# Pixel-art tiles – no interpolation between pixels.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Call once after adding to the scene tree.
func initialize(data: ChunkData) -> void:
	_data = data
	_rebuild_collision()
	_spawn_pickables()
	_spawn_chests()
	queue_redraw()


## Spawn ChestNodes for every CHEST_SMALL object in the chunk.
func _spawn_chests() -> void:
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var cell := _data.get_cell(x, y)
			if cell == null:
				continue
			for obj_type in cell.objects:
				if obj_type == MapObject.Type.CHEST_SMALL:
					var node := ChestNode.new()
					node.position = Vector2(
						(x + 0.5) * CELL_SIZE,
						(y + 0.5) * CELL_SIZE
					)
					add_child(node)
					node.initialize(x, y, _data.chunk_x, _data.chunk_y)


## Spawn Area2D PickableNodes for every pickable object in the chunk.
func _spawn_pickables() -> void:
	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var cell := _data.get_cell(x, y)
			if cell == null:
				continue
			for obj_type in cell.objects:
				if PickableItemDef.is_pickable(obj_type):
					var node := PickableNode.new()
					node.position = Vector2(
						(x + 0.5) * CELL_SIZE,
						(y + 0.5) * CELL_SIZE
					)
					add_child(node)
					node.initialize(obj_type, x, y, _data,
							_data.get_pickable_count(x, y))


## Spawn a single PickableNode for an item already added to _data.
## Called by World.drop_item_near after mutating the ChunkData.
func spawn_pickable_at(item_type: int, lx: int, ly: int, count: int = 1) -> void:
	var node := PickableNode.new()
	node.position = Vector2((lx + 0.5) * CELL_SIZE, (ly + 0.5) * CELL_SIZE)
	add_child(node)
	node.initialize(item_type, lx, ly, _data, count)


## Rebuild the StaticBody2D collision shapes from current chunk data.
func _rebuild_collision() -> void:
	if _body != null:
		_body.queue_free()

	_body = StaticBody2D.new()
	add_child(_body)

	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var cell := _data.get_cell(x, y)
			if cell == null:
				continue

			var cx_px := x * CELL_SIZE + CELL_SIZE / 2
			var cy_px := y * CELL_SIZE + CELL_SIZE / 2

			if cell.is_obstacle:
				# Entire cell is impassable → solid rectangle.
				_add_rect_collision(cx_px, cy_px, CELL_SIZE, CELL_SIZE)
			else:
				# Individual objects may block movement.
				for obj_type in cell.objects:
					if not MapObject.is_type_passable(obj_type):
						if obj_type == MapObject.Type.CHEST_SMALL:
							continue  # ChestNode owns its own collision
						_add_circle_collision(cx_px, cy_px, CELL_SIZE * 0.28)


func _add_rect_collision(cx: int, cy: int, w: int, h: int) -> void:
	var col  := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size      = Vector2(w, h)
	col.shape      = rect
	col.position   = Vector2(cx, cy)
	_body.add_child(col)


func _add_circle_collision(cx: int, cy: int, radius: float) -> void:
	var col    := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	col.shape     = circle
	col.position  = Vector2(cx, cy)
	_body.add_child(col)


# ── Rendering ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _data == null:
		return

	for y in range(CHUNK_SIZE):
		for x in range(CHUNK_SIZE):
			var cell := _data.get_cell(x, y)
			if cell == null:
				continue

			var px := x * CELL_SIZE
			var py := y * CELL_SIZE
			var cell_rect := Rect2(px, py, CELL_SIZE, CELL_SIZE)

			# Terrain fill: texture when available, fallback to flat colour.
			var tex := TextureCache.get_texture(cell.terrain_type)
			if tex != null:
				draw_texture_rect(tex, cell_rect, false)
			else:
				draw_rect(cell_rect, Color(0.22, 0.65, 0.18))

			# Subtle grid lines.
			draw_rect(cell_rect, Color(0, 0, 0, 0.07), false, 1.0)

			# Objects.
			for obj_type in cell.objects:
				_draw_object(obj_type, px, py)


func _draw_object(obj_type: int, px: int, py: int) -> void:
	# Objects rendered by dedicated child nodes skip draw here.
	if PickableItemDef.is_pickable(obj_type):
		return
	if obj_type == MapObject.Type.CHEST_SMALL:
		return  # rendered by ChestNode sprite
	var center := Vector2(px + CELL_SIZE * 0.5, py + CELL_SIZE * 0.5)
	match obj_type:
		MapObject.Type.ROCK:
			draw_circle(center, CELL_SIZE * 0.25, MapObject.get_color(obj_type))
			draw_arc(center, CELL_SIZE * 0.25, 0.0, TAU, 16,
					 Color(0.25, 0.22, 0.18), 1.5)
