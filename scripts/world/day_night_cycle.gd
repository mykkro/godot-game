class_name DayNightCycle
extends CanvasModulate

## Day/night tint keyframes: [hour_float_0_to_24, Color].
## First and last share the same color so midnight wraps cleanly.
const _TIME_KEYS := [
	[0.0,  Color(0.28, 0.32, 0.58)],  # midnight — dark, deep blue
	[4.0,  Color(0.22, 0.26, 0.52)],  # pre-dawn — darkest
	[5.5,  Color(0.75, 0.55, 0.48)],  # dawn — warm orange
	[7.0,  Color(0.97, 0.93, 0.90)],  # morning — slightly warm
	[10.0, Color(1.00, 1.00, 1.00)],  # midday — neutral
	[15.0, Color(1.00, 1.00, 0.98)],  # afternoon — barely warm
	[18.0, Color(1.00, 0.88, 0.68)],  # golden hour
	[19.5, Color(0.82, 0.55, 0.55)],  # dusk — deep red-orange
	[21.0, Color(0.48, 0.42, 0.68)],  # evening — blue-purple
	[22.5, Color(0.32, 0.35, 0.62)],  # late night transition
	[24.0, Color(0.28, 0.32, 0.58)],  # midnight (wrap)
]

const WINTER_TINT     := Color(0.90, 0.93, 1.00)  # cool, faintly grayish-white
const SUMMER_TINT     := Color(1.00, 0.98, 0.90)  # warm, slightly golden
const SEASON_STRENGTH := 0.20                       # max 20% seasonal shift from neutral


func _ready() -> void:
	color = Color.WHITE
	GameClock.time_changed.connect(_on_time_changed)
	_on_time_changed()


func _on_time_changed() -> void:
	var dt         := GameClock.get_date_time()
	var hour_float := _to_hour24(dt["hour12"], dt["minute"], dt["am_pm"])
	var time_color := _sample_time(hour_float)

	var sf          := _season_factor(dt["month_idx"], dt["day"])
	var tint_target := SUMMER_TINT if sf >= 0.0 else WINTER_TINT
	var season_tint := Color.WHITE.lerp(tint_target, absf(sf) * SEASON_STRENGTH)

	color = Color(
		time_color.r * season_tint.r,
		time_color.g * season_tint.g,
		time_color.b * season_tint.b,
		1.0
	)


## Convert 12-hour + AM/PM + minute to a float hour in [0, 24).
static func _to_hour24(h12: int, minute: int, am_pm: String) -> float:
	var h24: float
	if am_pm == "AM":
		h24 = 0.0 if h12 == 12 else float(h12)
	else:
		h24 = 12.0 if h12 == 12 else float(h12) + 12.0
	return h24 + float(minute) / 60.0


## Linear interpolation across the time keyframes.
func _sample_time(hour: float) -> Color:
	for i in range(_TIME_KEYS.size() - 1):
		var h0: float = _TIME_KEYS[i][0]
		var h1: float = _TIME_KEYS[i + 1][0]
		if hour >= h0 and hour < h1:
			var t := (hour - h0) / (h1 - h0)
			return (_TIME_KEYS[i][1] as Color).lerp(_TIME_KEYS[i + 1][1] as Color, t)
	return _TIME_KEYS[0][1]


## Cosine season factor: +1.0 at midsummer (month 4, mid), -1.0 at midwinter (month 10, mid).
static func _season_factor(month_idx: int, day: int) -> float:
	var total_day := float(month_idx * 30 + day - 1)
	return cos((total_day - 135.0) / 360.0 * TAU)
