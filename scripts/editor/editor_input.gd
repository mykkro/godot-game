class_name EditorInput
extends Node

signal paint_cell(chunk_coord: Vector2i, local_coord: Vector2i)
signal erase_cell(chunk_coord: Vector2i, local_coord: Vector2i)
signal hover_cell(chunk_coord: Vector2i, local_coord: Vector2i)
signal stroke_started
signal stroke_ended

const CELL_SIZE  := ChunkData.CELL_SIZE
const CHUNK_SIZE := ChunkData.CHUNK_SIZE
const CHUNK_PX   := CELL_SIZE * CHUNK_SIZE  # 1024

var _camera:      Camera2D = null
var _paint_held:  bool     = false
var _erase_held:  bool     = false


func setup(camera: Camera2D) -> void:
	_camera = camera


func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_paint_held = mb.pressed
				if mb.pressed:
					stroke_started.emit()
					_emit_paint(mb.position)
				else:
					stroke_ended.emit()
			MOUSE_BUTTON_RIGHT:
				_erase_held = mb.pressed
				if mb.pressed:
					stroke_started.emit()
					_emit_erase(mb.position)
				else:
					stroke_ended.emit()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var coords := _screen_to_coords(mm.position)
		hover_cell.emit(coords[0], coords[1])
		if _paint_held:
			_emit_paint(mm.position)
		elif _erase_held:
			_emit_erase(mm.position)


func _emit_paint(screen_pos: Vector2) -> void:
	var coords := _screen_to_coords(screen_pos)
	paint_cell.emit(coords[0], coords[1])


func _emit_erase(screen_pos: Vector2) -> void:
	var coords := _screen_to_coords(screen_pos)
	erase_cell.emit(coords[0], coords[1])


## Returns [chunk_coord: Vector2i, local_coord: Vector2i].
func _screen_to_coords(screen_pos: Vector2) -> Array:
	var vp      := _camera.get_viewport()
	var world   := vp.get_canvas_transform().affine_inverse() * screen_pos
	var gx      := int(floor(world.x / CELL_SIZE))
	var gy      := int(floor(world.y / CELL_SIZE))
	var cx      := int(floor(float(gx) / CHUNK_SIZE))
	var cy      := int(floor(float(gy) / CHUNK_SIZE))
	var lx      := gx - cx * CHUNK_SIZE
	var ly      := gy - cy * CHUNK_SIZE
	return [Vector2i(cx, cy), Vector2i(lx, ly)]
