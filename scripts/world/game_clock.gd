extends Node

## 1 game day = 20 real minutes → 86400 game-sec ÷ 1200 real-sec = 72×
const SECS_PER_REAL_SEC  := 86400.0 / 1200.0
const DEFAULT_START_TIME := 6.0 * 3600.0   # 6:00 AM, day 1

const DAY_NAMES: Array[String] = [
	"Sunmorn", "Moonday", "Ashday", "Ironday", "Stormday", "Goldday", "Restday"
]
const MONTH_NAMES: Array[String] = [
	"Seedmoon", "Bloomtide", "Greenmere",
	"Sunpeak", "Hearthmonth", "Goldveil",
	"Harvestmoon", "Embertide", "Ashfall",
	"Frostmoon", "Deepwinter", "Coldend"
]

signal time_changed

var _game_time:   float = DEFAULT_START_TIME
var _last_minute: int   = -1


func _process(delta: float) -> void:
	_game_time += delta * SECS_PER_REAL_SEC
	var current_minute := int(_game_time / 60)
	if current_minute != _last_minute:
		_last_minute = current_minute
		time_changed.emit()


func get_game_time() -> float:
	return _game_time


func load_time(s: float) -> void:
	_game_time   = s
	_last_minute = int(_game_time / 60)
	time_changed.emit()


func get_date_time() -> Dictionary:
	return from_seconds(_game_time)


## Convert explicit calendar components to raw game seconds.
static func to_seconds(year: int, month_idx: int, day: int, hour: int, minute: int) -> float:
	return float(
		(year - 1) * 360 * 86400
		+ month_idx * 30 * 86400
		+ (day - 1) * 86400
		+ hour * 3600
		+ minute * 60
	)


func from_seconds(s: float) -> Dictionary:
	var total_minutes := int(s / 60)
	var minute        := total_minutes % 60
	var total_hours   := int(s / 3600)
	var hour_24       := total_hours % 24
	var am_pm         := "AM" if hour_24 < 12 else "PM"
	var hour12        := hour_24 % 12
	if hour12 == 0:
		hour12 = 12
	var total_days  := int(s / 86400)
	var weekday_idx := total_days % 7
	var day         := total_days % 30 + 1
	var month_idx   := (total_days / 30) % 12
	var year        := total_days / 360 + 1
	return {
		"year":         year,
		"month_idx":    month_idx,
		"month_name":   MONTH_NAMES[month_idx],
		"day":          day,
		"weekday_idx":  weekday_idx,
		"weekday_name": DAY_NAMES[weekday_idx],
		"hour12":       hour12,
		"minute":       minute,
		"am_pm":        am_pm,
	}
