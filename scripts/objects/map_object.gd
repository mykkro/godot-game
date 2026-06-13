class_name MapObject

## All object types that can appear on a map cell.
enum Type {
	ROCK        = 0,  ## Impassable obstacle.
	HERB        = 1,  ## Pickable herb.
	CRYSTAL     = 2,  ## Pickable crystal.
	COIN        = 3,  ## Pickable coin/ring.
	FEATHER     = 4,  ## Pickable feather.
	POTION      = 5,  ## Pickable potion.
	CHEST_SMALL = 6,  ## Impassable interactable chest (up to 20 items).
}

## Returns false when an actor cannot pass through this object type.
static func is_type_passable(obj_type: int) -> bool:
	match obj_type:
		Type.ROCK, Type.CHEST_SMALL: return false
	return true

## Placeholder fill color used during debug rendering of non-pickable objects.
static func get_color(obj_type: int) -> Color:
	match obj_type:
		Type.ROCK: return Color(0.50, 0.47, 0.42)
	return Color.WHITE

## Human-readable display name.
static func get_display_name(obj_type: int) -> String:
	match obj_type:
		Type.ROCK:        return "Rock"
		Type.HERB:        return "Herb"
		Type.CRYSTAL:     return "Crystal"
		Type.COIN:        return "Coin"
		Type.FEATHER:     return "Feather"
		Type.POTION:      return "Potion"
		Type.CHEST_SMALL: return "Chest"
	return "Unknown"
