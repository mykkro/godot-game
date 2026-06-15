class_name HeroStats
extends RefCounted

signal changed

## XP needed to reach the next level = XP_PER_LEVEL * current_level.
const XP_PER_LEVEL := 20

var level:        int = 1
var xp:           int = 0
var max_hp:       int = 30
var current_hp:   int = 30
var max_mana:     int = 10
var current_mana: int = 10
var attack:       int = 6
var magic:        int = 4
var defense:      int = 2


func xp_to_next() -> int:
	return XP_PER_LEVEL * level


## Add XP; auto-levels if threshold crossed. Returns true if level-up occurred.
func add_xp(amount: int) -> bool:
	xp += amount
	var leveled := false
	while xp >= xp_to_next():
		xp -= xp_to_next()
		_do_level_up()
		leveled = true
	changed.emit()
	return leveled


func take_damage(amount: int) -> void:
	current_hp = maxi(0, current_hp - amount)
	changed.emit()


func heal(amount: int) -> void:
	current_hp = mini(max_hp, current_hp + amount)
	changed.emit()


func is_dead() -> bool:
	return current_hp <= 0


func to_dict() -> Dictionary:
	return {
		"level":        level,
		"xp":           xp,
		"max_hp":       max_hp,
		"current_hp":   current_hp,
		"max_mana":     max_mana,
		"current_mana": current_mana,
		"attack":       attack,
		"magic":        magic,
		"defense":      defense,
	}


static func from_dict(d: Dictionary) -> HeroStats:
	var s := HeroStats.new()
	s.level        = int(d.get("level",        1))
	s.xp           = int(d.get("xp",           0))
	s.max_hp       = int(d.get("max_hp",       30))
	s.current_hp   = int(d.get("current_hp",   30))
	s.max_mana     = int(d.get("max_mana",     10))
	s.current_mana = int(d.get("current_mana", 10))
	s.attack       = int(d.get("attack",        6))
	s.magic        = int(d.get("magic",         4))
	s.defense      = int(d.get("defense",       2))
	return s


func _do_level_up() -> void:
	level    += 1
	max_hp   += 3
	current_hp = mini(current_hp + 3, max_hp)
	max_mana += 1
