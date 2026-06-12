class_name Avatar
extends Actor

const MOVE_SPEED := 200.0  # pixels / second

var _world:       World      = null
var _fog_manager: FogManager = null


## Must be called after the node is in the scene tree (from Main._ready).
func setup(world: World, fog_manager: FogManager) -> void:
	_world       = world
	_fog_manager = fog_manager


func _ready() -> void:
	# Set collision radius before super creates the CollisionShape2D.
	collision_radius = 14.0
	super._ready()


func _physics_process(_delta: float) -> void:
	var dir := _read_input()

	if dir != Vector2.ZERO:
		dir      = dir.normalized()
		heading  = dir.angle()
		velocity = dir * MOVE_SPEED
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	if _world != null:
		_world.update_avatar_position(position)
	if _fog_manager != null:
		_fog_manager.update_avatar_position(position)

	queue_redraw()


func _draw() -> void:
	# Body fill.
	draw_circle(Vector2.ZERO, collision_radius, Color(0.20, 0.55, 1.00))
	# Direction indicator (short line from centre toward heading).
	var tip := Vector2(cos(heading), sin(heading)) * (collision_radius + 5.0)
	draw_line(Vector2.ZERO, tip, Color.WHITE, 2.5)
	# Outline ring.
	draw_arc(Vector2.ZERO, collision_radius, 0.0, TAU, 24,
			 Color(0.10, 0.30, 0.70), 1.5)


# ── Private ──────────────────────────────────────────────────────────────────

static func _read_input() -> Vector2:
	return Vector2(
		float(Input.is_action_pressed("ui_right")) - float(Input.is_action_pressed("ui_left")),
		float(Input.is_action_pressed("ui_down"))  - float(Input.is_action_pressed("ui_up"))
	)
