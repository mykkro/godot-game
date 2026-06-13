class_name ChestNode
extends StaticBody2D

## Impassable interactable chest.  Registered in group "chests".
## contents holds up to CAPACITY item stacks: [{"type": int, "count": int}, …]

const SPRITE_SCALE    := 1.5    # 32-px source → 48-px on screen
const COLL_HALF       := 20.0   # half-size of blocking rectangle in px
const CHEST_VARIANTS  := 12     # number of chest_XX.png files
const CAPACITY        := 20     # max item stacks

var _cell_x: int = 0
var _cell_y: int = 0

## Item stacks stored in the chest; populated deterministically on spawn.
var contents: Array[Dictionary] = []


func initialize(p_cx: int, p_cy: int,
		p_chunk_x: int = 0, p_chunk_y: int = 0) -> void:
	_cell_x = p_cx
	_cell_y = p_cy

	add_to_group("chests")

	# Block actor movement — same layer as chunk static body.
	collision_layer = 1
	collision_mask  = 0

	var col  := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(COLL_HALF * 2.0, COLL_HALF * 2.0)
	col.shape = rect
	add_child(col)

	# Pick a chest variant deterministically from position.
	var variant := ((p_cx * 7 + p_cy * 13) % CHEST_VARIANTS) + 1
	var path    := "res://media/chests/chest_%02d.png" % variant
	var tex     := load(path) as Texture2D

	var sprite               := Sprite2D.new()
	sprite.texture            = tex
	sprite.texture_filter     = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale              = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	add_child(sprite)

	_fill_contents(p_chunk_x, p_chunk_y, p_cx, p_cy)


func _fill_contents(cx: int, cy: int, lx: int, ly: int) -> void:
	var rng  := RandomNumberGenerator.new()
	rng.seed  = abs((cx * 73856093) ^ (cy * 19349663) ^ (lx * 31) ^ (ly * 97) ^ 554899)

	# 5–50 coins (one stack)
	contents.append({"type": MapObject.Type.COIN,    "count": rng.randi_range(5, 50)})
	# 1–5 crystals (one per stack slot)
	var crystals := rng.randi_range(1, 5)
	for _i in range(crystals):
		contents.append({"type": MapObject.Type.CRYSTAL, "count": 1})
	# 0–3 random extra items
	var item_pool := [MapObject.Type.HERB, MapObject.Type.FEATHER, MapObject.Type.POTION]
	var extras    := rng.randi_range(0, 3)
	for _i in range(extras):
		var pick: int = item_pool[rng.randi() % item_pool.size()]
		contents.append({"type": pick, "count": 1})
