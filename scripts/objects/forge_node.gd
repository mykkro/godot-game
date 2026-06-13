class_name ForgeNode
extends StaticBody2D

## Impassable interactable forge. Registered in group "forges".
## input_contents:  up to 9 item stacks [{type, count}, ...]
## output_contents: up to 5 item stacks [{type, count}, ...]

const SPRITE_SCALE   := 1.75
const COLL_HALF      := 20.0
const INPUT_SLOTS    := 9
const OUTPUT_SLOTS   := 5

var _cell_x:     int       = 0
var _cell_y:     int       = 0
var _chunk_data: ChunkData = null   # set by ChunkNode after initialize

var input_contents:  Array[Dictionary] = []
var output_contents: Array[Dictionary] = []


func initialize(p_cx: int, p_cy: int,
		p_chunk_x: int = 0, p_chunk_y: int = 0,
		p_stored_input: Variant = null, p_stored_output: Variant = null) -> void:
	_cell_x = p_cx
	_cell_y = p_cy

	add_to_group("forges")

	collision_layer = 1
	collision_mask  = 0

	var col  := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(COLL_HALF * 2.0, COLL_HALF * 2.0)
	col.shape = rect
	add_child(col)

	var sprite               := Sprite2D.new()
	sprite.texture            = PickableItemDef.get_texture(MapObject.Type.FORGE)
	sprite.texture_filter     = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale              = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	add_child(sprite)

	if p_stored_input != null:
		for entry in (p_stored_input as Array):
			input_contents.append({"type": int(entry["type"]), "count": int(entry["count"])})
	if p_stored_output != null:
		for entry in (p_stored_output as Array):
			output_contents.append({"type": int(entry["type"]), "count": int(entry["count"])})


func flush_to_data() -> void:
	if _chunk_data == null:
		return
	_chunk_data.set_forge_input(_cell_x,  _cell_y, input_contents.duplicate(true))
	_chunk_data.set_forge_output(_cell_x, _cell_y, output_contents.duplicate(true))
