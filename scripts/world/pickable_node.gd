class_name PickableNode
extends Area2D

## Collision layer for pickable items (distinct from physics layer 1).
const LAYER_PICKABLE := 2
## Visual half-size for the sprite display (pixels).
const SPRITE_SCALE   := 1.8
## Pickup detection radius.
const AREA_RADIUS    := 20.0

## The item type this node represents (MapObject.Type value).
var item_type: int = 0

var _cell_x:    int       = 0
var _cell_y:    int       = 0
var _chunk_data: ChunkData = null


## Call immediately after adding to the scene tree.
func initialize(p_item_type: int, p_cx: int, p_cy: int,
				p_chunk_data: ChunkData) -> void:
	item_type   = p_item_type
	_cell_x     = p_cx
	_cell_y     = p_cy
	_chunk_data = p_chunk_data

	# Pickable objects are passable – live on a separate collision layer.
	collision_layer = LAYER_PICKABLE
	collision_mask  = 0

	# Sprite using the item's sprite sheet entry.
	var sprite           := Sprite2D.new()
	sprite.texture        = TextureCache.get_object_texture(
			PickableItemDef.get_sprite(item_type))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale          = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	add_child(sprite)

	# Detection area.
	var col    := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = AREA_RADIUS
	col.shape     = circle
	add_child(col)


## Remove from both the world node tree and CellData, then free self.
func remove_from_world() -> void:
	if _chunk_data != null:
		var cell := _chunk_data.get_cell(_cell_x, _cell_y)
		if cell != null:
			cell.objects.erase(item_type)
	queue_free()
