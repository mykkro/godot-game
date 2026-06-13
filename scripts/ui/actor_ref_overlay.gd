class_name ActorRefOverlay
extends Node2D

## Draws a small cross at the world position (= collision-circle centre)
## of the avatar and every NPC. Toggled by F4 together with collision shapes.

const CROSS_HALF := 6.0          # half-arm length in world pixels
const THICKNESS  := 1.5
const COLOR_AVATAR := Color(1.0, 1.0, 0.0, 1.0)   # yellow
const COLOR_NPC    := Color(0.0, 1.0, 1.0, 1.0)   # cyan

var _avatar: Avatar = null
var _world:  World  = null


func setup(avatar: Avatar, world: World) -> void:
	_avatar = avatar
	_world  = world
	z_index         = 100
	z_as_relative   = false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _avatar != null:
		_cross(_avatar.position, COLOR_AVATAR)

	if _world != null:
		for child in _world.get_children():
			if child is NpcKnight or child is NpcMelee:
				_cross((child as Node2D).position, COLOR_NPC)


func _cross(p: Vector2, color: Color) -> void:
	draw_line(p + Vector2(-CROSS_HALF, 0), p + Vector2(CROSS_HALF, 0), color, THICKNESS)
	draw_line(p + Vector2(0, -CROSS_HALF), p + Vector2(0, CROSS_HALF), color, THICKNESS)
