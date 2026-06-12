class_name PickableItemDef

## Static registry: maps MapObject.Type int → display metadata.
## Only types listed here are treated as pickable (passable, can be picked up).

## Returns true when this object type can be picked up by the avatar.
static func is_pickable(obj_type: int) -> bool:
	match obj_type:
		MapObject.Type.HERB:    return true
		MapObject.Type.CRYSTAL: return true
		MapObject.Type.COIN:    return true
		MapObject.Type.FEATHER: return true
		MapObject.Type.POTION:  return true
	return false


## Human-readable name shown in the inventory.
static func get_display_name(obj_type: int) -> String:
	match obj_type:
		MapObject.Type.HERB:    return "Herb"
		MapObject.Type.CRYSTAL: return "Crystal"
		MapObject.Type.COIN:    return "Coin"
		MapObject.Type.FEATHER: return "Feather"
		MapObject.Type.POTION:  return "Potion"
	return "Item"


## Sprite filename inside res://media/raven-objects/.
static func get_sprite(obj_type: int) -> String:
	match obj_type:
		MapObject.Type.HERB:    return "fc100.png"
		MapObject.Type.CRYSTAL: return "fc4.png"
		MapObject.Type.COIN:    return "fc2.png"
		MapObject.Type.FEATHER: return "fc7.png"
		MapObject.Type.POTION:  return "fc50.png"
	return "fc1.png"
