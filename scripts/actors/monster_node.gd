class_name MonsterNode
extends StaticBody2D

const DISPLAY_SIZE := 48.0   # 75% of ChunkData.CELL_SIZE (64)
const COLL_RADIUS  := 24.0   # DISPLAY_SIZE / 2

var monster_id: String = ""
var species:    String = ""   # filename stem, e.g. "Wolf"

var _sprite: Sprite2D = null


func _ready() -> void:
	collision_layer = 1   # Actor.ACTOR_LAYER
	collision_mask  = 0
	add_to_group("monsters")

	var col    := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = COLL_RADIUS
	col.shape     = circle
	add_child(col)


## Call after add_child for new (non-restored) monsters to pick a random species.
func initialize() -> void:
	species = _pick_random_species()
	_load_sprite()


func to_dict() -> Dictionary:
	return {
		"type":       "monster",
		"monster_id": monster_id,
		"species":    species,
		"x":          position.x,
		"y":          position.y,
	}


func restore_from_dict(data: Dictionary) -> void:
	monster_id = str(data.get("monster_id", ""))
	species    = str(data.get("species", ""))
	position   = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	_load_sprite()


func _pick_random_species() -> String:
	var files := DirAccess.get_files_at("res://media/rpg-beings/")
	var pngs: Array[String] = []
	for f in files:
		if f.get_extension() == "png":
			pngs.append(f.get_basename())
	if pngs.is_empty():
		return "Unknown"
	return pngs[randi() % pngs.size()]


func _load_sprite() -> void:
	if _sprite != null:
		_sprite.queue_free()
		_sprite = null
	if species.is_empty():
		return
	var path := "res://media/rpg-beings/%s.png" % species
	var tex   := load(path) as Texture2D
	if tex == null:
		push_error("MonsterNode: texture not found at %s" % path)
		return
	_sprite         = Sprite2D.new()
	_sprite.texture = tex
	_sprite.scale   = Vector2(
		DISPLAY_SIZE / float(tex.get_width()),
		DISPLAY_SIZE / float(tex.get_height())
	)
	add_child(_sprite)
