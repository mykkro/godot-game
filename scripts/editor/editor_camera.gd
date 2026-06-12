class_name EditorCamera
extends Camera2D

const ZOOM_MIN  := Vector2(0.25, 0.25)
const ZOOM_MAX  := Vector2(4.0,  4.0)
const ZOOM_STEP := 0.15

var _drag_active: bool    = false
var _drag_origin: Vector2 = Vector2.ZERO
var _cam_origin:  Vector2 = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_MIDDLE:
				_drag_active = mb.pressed
				if mb.pressed:
					_drag_origin = mb.position
					_cam_origin  = position
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_by(ZOOM_STEP)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_by(-ZOOM_STEP)
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _drag_active:
		var mm := event as InputEventMouseMotion
		position = _cam_origin - (mm.position - _drag_origin) / zoom
		get_viewport().set_input_as_handled()


func _zoom_by(delta: float) -> void:
	var new_zoom := (zoom + Vector2(delta, delta)).clamp(ZOOM_MIN, ZOOM_MAX)
	zoom = new_zoom
