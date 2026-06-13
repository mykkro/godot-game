class_name NpcKnight
extends Actor

const MOVE_SPEED     := 80.0
const LIFETIME       := 60.0
const IDLE_MIN       := 1.0
const IDLE_MAX       := 3.5
const STEP_CELLS_MIN := 3
const STEP_CELLS_MAX := 8
const ARRIVE_DIST    := 12.0   # px — considered arrived when this close to target
const WALK_TIMEOUT   := 5.0    # give up walk step after this many seconds
const STUCK_INTERVAL := 0.5    # check for stuck every N seconds
const STUCK_MIN_MOVE := 5.0    # must move at least this many px per STUCK_INTERVAL

## Use the same circle as Avatar so both knights look consistent.
const COLL_RADIUS   := 18.75
const COLL_OFFSET_Y := -29.4

enum State { IDLE, WALKING }

var npc_id:       String  = ""
var _state:       int     = State.IDLE
var _idle_timer:  float   = 0.0
var _walk_timer:  float   = 0.0
var _walk_target: Vector2 = Vector2.ZERO
var _elapsed:     float   = 0.0
var _stuck_timer: float   = 0.0
var _stuck_pos:   Vector2 = Vector2.ZERO
var _sprite:      GreatswordSprite = null


func _setup_collision() -> void:
	var col    := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = COLL_RADIUS
	col.shape     = circle
	col.position  = Vector2.ZERO
	add_child(col)


func _ready() -> void:
	# Ensure actors push against terrain and against each other.
	collision_layer = ACTOR_LAYER
	collision_mask  = ACTOR_LAYER

	super._ready()  # calls _setup_collision()

	_sprite        = GreatswordSprite.new()
	_sprite.scale  = Vector2(0.56, 0.56)
	_sprite.offset = Vector2(0.0, -3.1)
	add_child(_sprite)

	_idle_timer = randf_range(IDLE_MIN, IDLE_MAX)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()
		return

	match _state:
		State.IDLE:
			velocity    = Vector2.ZERO
			_idle_timer -= delta
			if _idle_timer <= 0.0:
				_start_walk()

		State.WALKING:
			_walk_timer  -= delta
			_stuck_timer -= delta

			if position.distance_to(_walk_target) < ARRIVE_DIST or _walk_timer <= 0.0:
				_go_idle()
				return

			if _stuck_timer <= 0.0:
				if position.distance_to(_stuck_pos) < STUCK_MIN_MOVE:
					_go_idle()
					return
				_stuck_pos   = position
				_stuck_timer = STUCK_INTERVAL

			var dir  := (_walk_target - position).normalized()
			heading   = dir.angle()
			velocity  = dir * MOVE_SPEED
			move_and_slide()

	if _sprite != null:
		_sprite.update_anim(_state == State.WALKING, heading)


func _start_walk() -> void:
	var angle     := randf() * TAU
	var cells     := randi_range(STEP_CELLS_MIN, STEP_CELLS_MAX)
	_walk_target   = position + Vector2(cos(angle), sin(angle)) * (cells * ChunkData.CELL_SIZE)
	_walk_timer    = WALK_TIMEOUT
	_stuck_timer   = STUCK_INTERVAL
	_stuck_pos     = position
	_state         = State.WALKING


func _go_idle() -> void:
	velocity    = Vector2.ZERO
	_idle_timer = randf_range(IDLE_MIN, IDLE_MAX)
	_state      = State.IDLE


func to_dict() -> Dictionary:
	return {
		"type":    "knight",
		"npc_id":  npc_id,
		"x":       position.x,
		"y":       position.y,
		"heading": heading,
		"elapsed": _elapsed,
	}


func restore_from_dict(data: Dictionary) -> void:
	npc_id   = str(data.get("npc_id", ""))
	position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	heading  = float(data.get("heading", 0.0))
	_elapsed = float(data.get("elapsed", 0.0))
