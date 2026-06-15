class_name NpcMelee
extends StaticBody2D

## Idle melee character — stands in place permanently, occasionally turns.

const COLL_RADIUS    := 18.75
const DIR_CHANGE_MIN := 3.0
const DIR_CHANGE_MAX := 8.0
const MARK_BASE_Y    := -54.8
const BOB_AMP        := 3.0
const BOB_PERIOD     := 1.2
const QUEST_MARK_COLOR := Color(1.0, 0.85, 0.0)

const NAME_LABEL_Y     := -80.0
const NAME_LABEL_WIDTH := 150.0

enum Stance { NEUTRAL, FRIENDLY, ALERT, HOSTILE }
const STANCE_COLORS: Dictionary = {
	Stance.NEUTRAL:  Color(1.0, 1.0, 1.0),
	Stance.FRIENDLY: Color(0.2, 1.0, 0.35),
	Stance.ALERT:    Color(1.0, 0.75, 0.0),
	Stance.HOSTILE:  Color(1.0, 0.2, 0.15),
}

const NAMES := [
	"Aldric", "Brennan", "Cedric", "Doran", "Edric", "Faolan", "Gareth",
	"Hadwin", "Idris", "Jorin", "Kael", "Leofric", "Maewen", "Nolan",
	"Oswin", "Perin", "Quinlan", "Rodric", "Serafin", "Torin", "Urien",
	"Valdis", "Wren", "Xander", "Yoric", "Zephyr",
]

var npc_id:           String   = ""
var heading:          float    = 0.0
var is_quest_giver:   bool     = false
var npc_name:         String   = ""
var stance:           int      = Stance.NEUTRAL
var birth_time:       float    = 0.0
var perks:            CharacterPerks = CharacterPerks.new()
var _sprite:          MeleeSprite = null
var _dir_timer:       float    = 0.0
var _mark:            Sprite2D = null
var _mark_bob:        float    = 0.0
var _name_label:      Label    = null
var _quest_connected: bool     = false


func _ready() -> void:
	# Occupy the actor layer so player and NPCs can't walk through.
	collision_layer = 1   # Actor.ACTOR_LAYER
	collision_mask  = 0

	var col    := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = COLL_RADIUS
	col.shape     = circle
	add_child(col)

	_sprite        = MeleeSprite.new()
	_sprite.scale  = Vector2(0.56, 0.56)
	_sprite.offset = Vector2(0.0, -36.6)
	add_child(_sprite)

	heading    = randf() * TAU
	_dir_timer = randf_range(DIR_CHANGE_MIN, DIR_CHANGE_MAX)
	_update_dir()

	_mark          = Sprite2D.new()
	_mark.texture  = load("res://media/cursors/Outline/Default/mark_exclamation.png")
	_mark.modulate = QUEST_MARK_COLOR
	_mark.position = Vector2(0.0, MARK_BASE_Y)
	_mark.visible  = false
	add_child(_mark)

	_name_label                    = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.custom_minimum_size  = Vector2(NAME_LABEL_WIDTH, 0)
	_name_label.position             = Vector2(-NAME_LABEL_WIDTH / 2.0, NAME_LABEL_Y)
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_constant_override("outline_size", 10)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.visible = false
	add_child(_name_label)


func _process(delta: float) -> void:
	_dir_timer -= delta
	if _dir_timer <= 0.0:
		heading    = randf() * TAU
		_dir_timer = randf_range(DIR_CHANGE_MIN, DIR_CHANGE_MAX)
		_update_dir()

	if is_quest_giver:
		_mark_bob        = fmod(_mark_bob + delta, BOB_PERIOD)
		if _mark != null:
			_mark.position.y = MARK_BASE_Y + sin(_mark_bob * TAU / BOB_PERIOD) * BOB_AMP


func make_quest_giver(name: String) -> void:
	is_quest_giver = true
	npc_name       = name
	stance         = Stance.FRIENDLY
	if _mark != null:
		_mark.visible = true
	_refresh_name_label()
	_connect_quest_signals()
	call_deferred("_refresh_mark_visibility")


func _connect_quest_signals() -> void:
	if _quest_connected:
		return
	QuestManager.quest_given.connect(_on_quest_event)
	QuestManager.quest_completed.connect(_on_quest_event)
	QuestManager.quest_ready.connect(_on_quest_event)
	_quest_connected = true


func _on_quest_event(quest: QuestInstance) -> void:
	if quest.giver_npc_id == npc_id:
		_refresh_mark_visibility()


func _refresh_mark_visibility() -> void:
	if _mark == null or not is_quest_giver:
		return
	var q    := QuestManager.get_quest_from_npc(npc_id)
	var show := QuestManager.can_offer_quest(self) or \
		(q != null and q.state == QuestInstance.State.READY)
	_mark.visible = show


func _refresh_name_label() -> void:
	if _name_label == null:
		return
	var has_name := not npc_name.is_empty()
	_name_label.text    = npc_name
	_name_label.visible = has_name
	if has_name:
		_name_label.add_theme_color_override("font_color", STANCE_COLORS[stance])


func to_dict() -> Dictionary:
	return {
		"type":           "melee",
		"npc_id":         npc_id,
		"x":              position.x,
		"y":              position.y,
		"heading":        heading,
		"is_quest_giver": is_quest_giver,
		"npc_name":       npc_name,
		"birth_time":     birth_time,
		"perks":          perks.to_dict(),
	}


func restore_from_dict(data: Dictionary) -> void:
	npc_id         = str(data.get("npc_id", ""))
	position       = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	heading        = float(data.get("heading", 0.0))
	is_quest_giver = bool(data.get("is_quest_giver", false))
	npc_name       = str(data.get("npc_name", ""))
	birth_time     = float(data.get("birth_time", 0.0))
	perks.from_dict(data.get("perks", {}))
	if is_quest_giver:
		stance = Stance.FRIENDLY
		_connect_quest_signals()
	if _mark != null:
		_mark.visible = is_quest_giver
	_refresh_name_label()
	if is_quest_giver:
		call_deferred("_refresh_mark_visibility")
	_update_dir()


func _update_dir() -> void:
	if _sprite != null:
		_sprite.set_dir(_heading_to_dir(heading))


static func _heading_to_dir(h: float) -> int:
	var deg := fposmod(rad_to_deg(h), 360.0)
	var idx  := (int(round(deg / 45.0)) + 5) % 8
	return idx + 1
