class_name NpcMelee
extends StaticBody2D

## Idle melee character — stands in place permanently, occasionally turns.

const COLL_RADIUS    := 18.75
const DIR_CHANGE_MIN := 3.0
const DIR_CHANGE_MAX := 8.0
const MARK_BASE_Y    := -51.6
const BOB_AMP        := 3.0
const BOB_PERIOD     := 1.2
const QUEST_MARK_COLOR := Color(1.0, 0.85, 0.0)

var npc_id:     String   = ""
var heading:    float    = 0.0
var _sprite:    MeleeSprite = null
var _dir_timer: float    = 0.0
var _mark:      Sprite2D = null
var _mark_bob:  float    = 0.0


func _ready() -> void:
	# Occupy the actor layer so player and NPCs can't walk through.
	collision_layer = 1   # Actor.ACTOR_LAYER
	collision_mask  = 0

	var col    := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = COLL_RADIUS
	col.shape     = circle
	add_child(col)

	_sprite        = MeleeSprite.new()
	_sprite.scale  = Vector2(0.56, 0.56)
	_sprite.offset = Vector2(0.0, -36.6)
	add_child(_sprite)

	heading    = randf() * TAU
	_dir_timer = randf_range(DIR_CHANGE_MIN, DIR_CHANGE_MAX)
	_update_dir()

	_mark          = Sprite2D.new()
	_mark.texture  = load("res://media/cursors/Outline/Default/mark_exclamation.png")
	_mark.modulate = QUEST_MARK_COLOR
	_mark.position = Vector2(0.0, MARK_BASE_Y)
	add_child(_mark)


func _process(delta: float) -> void:
	_dir_timer -= delta
	if _dir_timer <= 0.0:
		heading    = randf() * TAU
		_dir_timer = randf_range(DIR_CHANGE_MIN, DIR_CHANGE_MAX)
		_update_dir()

	_mark_bob = fmod(_mark_bob + delta, BOB_PERIOD)
	if _mark != null:
		_mark.position.y = MARK_BASE_Y + sin(_mark_bob * TAU / BOB_PERIOD) * BOB_AMP


func to_dict() -> Dictionary:
	return {
		"type":    "melee",
		"npc_id":  npc_id,
		"x":       position.x,
		"y":       position.y,
		"heading": heading,
	}


func restore_from_dict(data: Dictionary) -> void:
	npc_id   = str(data.get("npc_id", ""))
	position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	heading  = float(data.get("heading", 0.0))
	_update_dir()


func _update_dir() -> void:
	if _sprite != null:
		_sprite.set_dir(_heading_to_dir(heading))


static func _heading_to_dir(h: float) -> int:
	var deg := fposmod(rad_to_deg(h), 360.0)
	var idx  := (int(round(deg / 45.0)) + 5) % 8
	return idx + 1
