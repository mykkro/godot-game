class_name MapObject

## All object types that can appear on a map cell.
enum Type {
	ROCK = 0,
}

## Returns false when an actor cannot pass through this object type.
static func is_type_passable(obj_type: int) -> bool:
	match obj_type:
		Type.ROCK: return false
	return true

## Placeholder fill color used during debug rendering.
static func get_color(obj_type: int) -> Color:
	match obj_type:
		Type.ROCK: return Color(0.50, 0.47, 0.42)
	return Color.WHITE
