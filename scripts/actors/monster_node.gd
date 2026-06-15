class_name MonsterNode
extends StaticBody2D

const DISPLAY_SIZE := 48.0   # 75% of ChunkData.CELL_SIZE (64)
const COLL_RADIUS  := 24.0   # DISPLAY_SIZE / 2

var monster_id:       String = ""
var species:          String = ""   # filename stem, e.g. "Wolf"
var is_editor_placed: bool   = false

## Combat stats — initialised from MonsterStats on first initialize().
var max_hp:    int = 0
var current_hp: int = 0
var attack:    int = 0
var defense:   int = 0
var xp_reward: int = 0

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
	if species.is_empty():
		species = _pick_random_species()
	_load_sprite()
	if max_hp == 0:
		_init_stats()


func _init_stats() -> void:
	var s  := MonsterStats.for_species(species)
	max_hp    = int(s.get("hp",      10))
	current_hp = max_hp
	attack    = int(s.get("attack",   4))
	defense   = int(s.get("defense",  1))
	xp_reward = int(s.get("xp",      10))


func to_dict() -> Dictionary:
	return {
		"type":             "monster",
		"monster_id":       monster_id,
		"species":          species,
		"is_editor_placed": is_editor_placed,
		"current_hp":       current_hp,
		"max_hp":           max_hp,
		"x":                position.x,
		"y":                position.y,
	}


func restore_from_dict(data: Dictionary) -> void:
	monster_id       = str(data.get("monster_id", ""))
	species          = str(data.get("species", ""))
	is_editor_placed = bool(data.get("is_editor_placed", false))
	position         = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	_load_sprite()
	_init_stats()
	# Restore saved HP (may be reduced from a previous fight the hero fled).
	var saved_hp := int(data.get("current_hp", max_hp))
	current_hp    = clampi(saved_hp, 0, max_hp)


static var _species_pool: Array[String] = []

func _pick_random_species() -> String:
	if _species_pool.is_empty():
		for f in DirAccess.get_files_at("res://media/rpg-beings/"):
			if f.get_extension() == "png":
				_species_pool.append(f.get_basename())
	if _species_pool.is_empty():
		return "Unknown"
	return _species_pool[randi() % _species_pool.size()]


func _load_sprite() -> void:
	if _sprite != null:
		_sprite.queue_free()
		_sprite = null
	if species.is_empty():
		return
	var tex := TextureCache.get_being_texture(species)
	if tex == null:
		push_error("MonsterNode: texture not found for species '%s'" % species)
		return
	_sprite         = Sprite2D.new()
	_sprite.texture = tex
	_sprite.scale   = Vector2(
		DISPLAY_SIZE / float(tex.get_width()),
		DISPLAY_SIZE / float(tex.get_height())
	)
	add_child(_sprite)
