class_name ChestNode
extends StaticBody2D

## Impassable interactable chest.  Registered in group "chests".
## contents holds up to CAPACITY item stacks: [{"type": int, "count": int}, …]

const SPRITE_SCALE    := 1.2    # 32-px source → 38-px on screen
const COLL_HALF       := 20.0   # half-size of blocking rectangle in px
const CHEST_VARIANTS  := 12     # number of chest_XX.png files
const CAPACITY        := 20     # max item stacks

var _cell_x:     int       = 0
var _cell_y:     int       = 0
var _chunk_data: ChunkData = null   # set by ChunkNode after initialize

## Item stacks stored in the chest; populated deterministically on spawn.
var contents: Array[Dictionary] = []


## p_variant 0 = use deterministic formula from position.
## p_stored_contents null = generate randomly; [] = intentionally empty.
func initialize(p_cx: int, p_cy: int,
		p_chunk_x: int = 0, p_chunk_y: int = 0,
		p_variant: int = 0, p_stored_contents: Variant = null) -> void:
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

	var variant := p_variant if p_variant > 0 \
			else ((p_cx * 7 + p_cy * 13) % CHEST_VARIANTS) + 1
	var tex := TextureCache.get_chest_texture(variant)

	var sprite               := Sprite2D.new()
	sprite.texture            = tex
	sprite.texture_filter     = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale              = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	add_child(sprite)

	if p_stored_contents == null:
		_fill_contents(p_chunk_x, p_chunk_y, p_cx, p_cy)
	else:
		for entry in (p_stored_contents as Array):
			contents.append({"type": int(entry["type"]), "count": int(entry["count"])})


## Persist current contents back to the chunk save data.
## Called by ChestLootUI when the player closes the loot screen.
func flush_to_data() -> void:
	if _chunk_data != null:
		_chunk_data.set_chest_contents(_cell_x, _cell_y, contents.duplicate(true))


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

	# 1–3 common crafting materials (stack 1–12)
	var common_mats := [
		MapObject.Type.NAILS,      MapObject.Type.WOOD_PLANK,
		MapObject.Type.WOODEN_ROD, MapObject.Type.CLOTH,
		MapObject.Type.COPPER_ORE, MapObject.Type.IRON_ORE,
		MapObject.Type.FEATHER,    MapObject.Type.LEATHER,
	]
	var common_count := rng.randi_range(1, 3)
	for _i in range(common_count):
		var pick: int = common_mats[rng.randi() % common_mats.size()]
		contents.append({"type": pick, "count": rng.randi_range(1, 12)})

	# 50 % chance: one uncommon ore or bar (stack 1–6)
	if rng.randi() % 2 == 0:
		var uncommon := [
			MapObject.Type.SILVER_NUGGET, MapObject.Type.GOLD_NUGGET,
			MapObject.Type.COPPER_BAR,    MapObject.Type.IRON_BAR,
		]
		var pick: int = uncommon[rng.randi() % uncommon.size()]
		contents.append({"type": pick, "count": rng.randi_range(1, 6)})

	# 25 % chance: one rare material (stack 1–3)
	if rng.randi() % 4 == 0:
		var rare := [
			MapObject.Type.SILVER_BAR,  MapObject.Type.GOLD_BAR,
			MapObject.Type.DRAGONSCALE, MapObject.Type.GEM,
		]
		var pick: int = rare[rng.randi() % rare.size()]
		contents.append({"type": pick, "count": rng.randi_range(1, 3)})
