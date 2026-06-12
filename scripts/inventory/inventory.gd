class_name Inventory

const MAX_ITEMS := 50

## Ordered list of picked-up item type ids (MapObject.Type values).
var items: Array[int] = []


func has_space() -> bool:
	return items.size() < MAX_ITEMS


## Add item_type to the inventory.  Returns false when full.
func add(item_type: int) -> bool:
	if not has_space():
		return false
	items.append(item_type)
	return true


func count() -> int:
	return items.size()


func to_dict() -> Dictionary:
	return { "items": items.duplicate() }


static func from_dict(data: Dictionary) -> Inventory:
	var inv := Inventory.new()
	for v in data.get("items", []):
		inv.items.append(int(v))
	return inv
