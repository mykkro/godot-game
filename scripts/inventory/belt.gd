class_name Belt

const SLOT_COUNT := 5

## Each element: { "type": int, "count": int } or null for empty.
var slots: Array = []

signal belt_changed


func _init() -> void:
	slots.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		slots[i] = null


func has_item(index: int) -> bool:
	return slots[index] != null


func get_type(index: int) -> int:
	if slots[index] == null:
		return -1
	return int(slots[index]["type"])


func get_count(index: int) -> int:
	if slots[index] == null:
		return 0
	return int(slots[index]["count"])


func set_slot(index: int, item_type: int, count: int) -> void:
	slots[index] = {"type": item_type, "count": count}
	belt_changed.emit()


func clear_slot(index: int) -> void:
	slots[index] = null
	belt_changed.emit()


## Consume one item from slot. Returns the item type consumed, or -1 if empty.
func consume(index: int) -> int:
	if slots[index] == null:
		return -1
	var item_type: int = int(slots[index]["type"])
	slots[index]["count"] = int(slots[index]["count"]) - 1
	if int(slots[index]["count"]) <= 0:
		slots[index] = null
	belt_changed.emit()
	return item_type


func to_dict() -> Dictionary:
	var arr: Array = []
	for s in slots:
		if s == null:
			arr.append(null)
		else:
			arr.append({"type": int(s["type"]), "count": int(s["count"])})
	return {"slots": arr}


static func from_dict(data: Dictionary) -> Belt:
	var b := Belt.new()
	var arr: Array = data.get("slots", [])
	for i in mini(arr.size(), Belt.SLOT_COUNT):
		var v: Variant = arr[i]
		if v is Dictionary:
			b.slots[i] = {
				"type":  int((v as Dictionary).get("type",  0)),
				"count": int((v as Dictionary).get("count", 1)),
			}
	return b
