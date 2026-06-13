class_name ForgeRecipeDef

const OUTPUT_CAP := 5   # must match ForgeNode output slot count

static var _recipes: Array = []


static func load_recipes() -> void:
	_recipes.clear()
	var f := FileAccess.open("res://data/forge_recipes.json", FileAccess.READ)
	if f == null:
		push_error("ForgeRecipeDef: cannot open res://data/forge_recipes.json")
		return
	var parsed := JSON.parse_string(f.get_as_text())
	f.close()
	if parsed == null or not (parsed is Array):
		push_error("ForgeRecipeDef: invalid JSON")
		return
	_recipes = parsed as Array


static func get_all() -> Array:
	return _recipes


## Returns true when input_contents contains at least the required types+counts.
## Order-free: aggregates total count per type across all input slots.
static func can_craft(recipe: Dictionary, input_contents: Array) -> bool:
	var available: Dictionary = {}
	for slot in input_contents:
		var t: int = int(slot["type"])
		available[t] = available.get(t, 0) + int(slot["count"])
	for req in recipe["inputs"]:
		if available.get(int(req["type"]), 0) < int(req["count"]):
			return false
	return true


## Consumes ingredients and appends outputs. Returns false without mutating if
## can_craft is false or output has insufficient free slots.
static func craft(recipe: Dictionary, input_contents: Array, output_contents: Array) -> bool:
	if not can_craft(recipe, input_contents):
		return false
	if not _output_has_room(recipe, output_contents):
		return false
	_consume(recipe, input_contents)
	_place_outputs(recipe, output_contents)
	return true


static func _output_has_room(recipe: Dictionary, output_contents: Array) -> bool:
	var free_slots := OUTPUT_CAP - output_contents.size()
	for out_entry in recipe["outputs"]:
		var out_type:  int = int(out_entry["type"])
		var needed:    int = int(out_entry["count"])
		var max_st := PickableItemDef.max_stack_size(out_type)
		for slot in output_contents:
			if needed <= 0:
				break
			if int(slot["type"]) == out_type:
				needed -= (max_st - int(slot["count"]))
		if needed > 0:
			var extra := int(ceil(float(needed) / float(maxi(max_st, 1))))
			if extra > free_slots:
				return false
			free_slots -= extra
	return true


static func _consume(recipe: Dictionary, input_contents: Array) -> void:
	for req in recipe["inputs"]:
		var req_type:  int = int(req["type"])
		var remaining: int = int(req["count"])
		var i := 0
		while i < input_contents.size() and remaining > 0:
			var entry: Dictionary = input_contents[i]
			if int(entry["type"]) == req_type:
				var take := mini(int(entry["count"]), remaining)
				entry["count"] = int(entry["count"]) - take
				remaining -= take
				if int(entry["count"]) <= 0:
					input_contents.remove_at(i)
				else:
					i += 1
			else:
				i += 1


static func _place_outputs(recipe: Dictionary, output_contents: Array) -> void:
	for out_entry in recipe["outputs"]:
		var out_type:  int = int(out_entry["type"])
		var remaining: int = int(out_entry["count"])
		var max_st := PickableItemDef.max_stack_size(out_type)
		for slot in output_contents:
			if remaining <= 0:
				break
			if int(slot["type"]) == out_type:
				var space := max_st - int(slot["count"])
				if space > 0:
					var fill := mini(remaining, space)
					slot["count"] = int(slot["count"]) + fill
					remaining -= fill
		while remaining > 0:
			var amt := mini(remaining, maxi(max_st, 1))
			output_contents.append({"type": out_type, "count": amt})
			remaining -= amt
