class_name Inventory

const MAX_ITEMS := 50

## Each element: { "type": int, "count": int }
var items: Array = []


## Returns true if item_type can be added — either by stacking into an existing
## slot or by occupying a new empty slot.  Pass -1 (default) to check only
## whether any empty slot is available (used for the Split operation).
func has_space(for_type: int = -1) -> bool:
	if for_type >= 0 and PickableItemDef.max_stack_size(for_type) > 1:
		for slot in items:
			if slot["type"] == for_type \
					and slot["count"] < PickableItemDef.max_stack_size(for_type):
				return true
	return items.size() < MAX_ITEMS


## Add one of item_type.  Stacks into an existing slot when possible.
## Returns false when the inventory has no room.
func add(item_type: int) -> bool:
	var max_stack := PickableItemDef.max_stack_size(item_type)
	if max_stack > 1:
		for slot in items:
			if slot["type"] == item_type and slot["count"] < max_stack:
				slot["count"] += 1
				return true
	if items.size() >= MAX_ITEMS:
		return false
	items.append({"type": item_type, "count": 1})
	return true


func get_type(slot: int) -> int:
	return items[slot]["type"]


func get_count(slot: int) -> int:
	return items[slot]["count"]


## Number of occupied slots (not total item count).
func count() -> int:
	return items.size()


## Split slot into two halves; the new half is appended to the end.
## Returns false when the stack has fewer than 2 items or inventory is full.
func split_slot(slot: int) -> bool:
	if slot < 0 or slot >= items.size():
		return false
	var c: int = items[slot]["count"]
	if c < 2 or items.size() >= MAX_ITEMS:
		return false
	var half := c / 2
	items[slot]["count"] = c - half
	items.append({"type": items[slot]["type"], "count": half})
	return true


## Remove up to n items from slot.  Deletes the slot when count reaches 0.
## Returns the number actually removed.
func remove_from_slot(slot: int, n: int) -> int:
	if slot < 0 or slot >= items.size():
		return 0
	var available: int = items[slot]["count"]
	var removed   := mini(n, available)
	items[slot]["count"] -= removed
	if items[slot]["count"] <= 0:
		items.remove_at(slot)
	return removed


## Move the item at from_idx to a different position.
## If to_idx < count: swap the two slots.
## If to_idx >= count: move item to end of the list.
func move_slot(from_idx: int, to_idx: int) -> void:
	if from_idx < 0 or from_idx >= items.size() or from_idx == to_idx:
		return
	if to_idx < items.size():
		var tmp: Dictionary = items[from_idx]
		items[from_idx] = items[to_idx]
		items[to_idx]   = tmp
	else:
		var item: Dictionary = items[from_idx]
		items.remove_at(from_idx)
		items.append(item)


func to_dict() -> Dictionary:
	var arr: Array = []
	for slot in items:
		arr.append({"type": slot["type"], "count": slot["count"]})
	return {"items": arr}


static func from_dict(data: Dictionary) -> Inventory:
	var inv := Inventory.new()
	for v in data.get("items", []):
		if v is Dictionary:
			inv.items.append({
				"type":  int(v.get("type",  0)),
				"count": int(v.get("count", 1)),
			})
		else:
			# Backward compat: old saves stored raw int item types.
			inv.items.append({"type": int(v), "count": 1})
	return inv
