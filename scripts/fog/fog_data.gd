class_name FogData

const CHUNK_SIZE := ChunkData.CHUNK_SIZE

## The four fog levels (2-bit range 0-3).
const UNEXPLORED := 0  ## Never visited — full black overlay.
const DIM        := 1  ## Explored but outside current view — 60 % overlay.
const PARTIAL    := 2  ## On the outer edge of current view — 25 % overlay.
const VISIBLE    := 3  ## Fully inside view radius — transparent.

var chunk_x: int = 0
var chunk_y: int = 0

## Row-major flat byte array: index = y * CHUNK_SIZE + x.  Values 0-3.
var _levels: PackedByteArray


func _init(cx: int = 0, cy: int = 0) -> void:
	chunk_x = cx
	chunk_y = cy
	_levels = PackedByteArray()
	_levels.resize(CHUNK_SIZE * CHUNK_SIZE)
	_levels.fill(UNEXPLORED)


func get_level(x: int, y: int) -> int:
	return _levels[y * CHUNK_SIZE + x]


func set_level(x: int, y: int, level: int) -> void:
	_levels[y * CHUNK_SIZE + x] = level


func to_dict() -> Dictionary:
	return {
		"chunk_x": chunk_x,
		"chunk_y": chunk_y,
		"levels":  Marshalls.raw_to_base64(_levels),
	}


static func from_dict(data: Dictionary) -> FogData:
	var fog := FogData.new(data.get("chunk_x", 0), data.get("chunk_y", 0))
	var b64: String = data.get("levels", "")
	if b64 != "":
		var raw := Marshalls.base64_to_raw(b64)
		if raw.size() == CHUNK_SIZE * CHUNK_SIZE:
			fog._levels = raw
	return fog
