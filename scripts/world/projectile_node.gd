class_name ProjectileNode
extends Node2D

const SPEED    := 500.0
const LIFETIME :=   3.0
const RADIUS   :=   4.0

var _velocity: Vector2 = Vector2.ZERO
var _elapsed:  float   = 0.0
var _world:    World   = null


func initialize(start_pos: Vector2, direction: Vector2, world: World) -> void:
	position  = start_pos
	_velocity = direction.normalized() * SPEED
	_world    = world


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()
		return

	position += _velocity * delta
	queue_redraw()

	if _world == null:
		return
	var cell := _world.get_cell_at(position)
	if _cell_blocks_projectile(cell):
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.82, 0.15))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 16, Color(1.0, 0.45, 0.0), 1.5)


static func _cell_blocks_projectile(cell: CellData) -> bool:
	if cell == null:
		return true  # outside loaded chunks
	if TerrainType.blocks_projectile(cell.terrain_type):
		return true
	for obj in cell.objects:
		if obj == MapObject.Type.ROCK:
			return true
	return false
