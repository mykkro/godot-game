class_name Actor
extends CharacterBody2D

## Physics layer shared by all actor types so they collide with each other.
const ACTOR_LAYER := 1

## Facing direction in radians.  0 = right (+X), PI/2 = down (+Y).
var heading: float = 0.0

## Radius of the circular collision shape in pixels.
## Set this BEFORE calling super._ready() in derived classes.
var collision_radius: float = 16.0


func _ready() -> void:
	_setup_collision()


# ── Private ──────────────────────────────────────────────────────────────────

func _setup_collision() -> void:
	var col    := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = collision_radius
	col.shape     = circle
	add_child(col)
