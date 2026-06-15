class_name QuestInstance
extends RefCounted

## A single quest at any stage of its lifecycle.

enum State { ACTIVE, READY, COMPLETED }
enum Type  { FETCH_RESOURCE }

var quest_id:       String = ""
var quest_type:     int    = Type.FETCH_RESOURCE
var title:          String = ""
var description:    String = ""
var giver_npc_id:   String = ""
var giver_npc_name: String = ""
var required_item:  int    = 0   # MapObject.Type value
var required_count: int    = 0
var gold_reward:    int    = 0
var state:          int    = State.ACTIVE
var given_at:       float  = 0.0
var completed_at:   float  = 0.0


func to_dict() -> Dictionary:
	return {
		"quest_id":       quest_id,
		"quest_type":     quest_type,
		"title":          title,
		"description":    description,
		"giver_npc_id":   giver_npc_id,
		"giver_npc_name": giver_npc_name,
		"required_item":  required_item,
		"required_count": required_count,
		"gold_reward":    gold_reward,
		"state":          state,
		"given_at":       given_at,
		"completed_at":   completed_at,
	}


func from_dict(data: Dictionary) -> void:
	quest_id       = str(data.get("quest_id",       ""))
	quest_type     = int(data.get("quest_type",     Type.FETCH_RESOURCE))
	title          = str(data.get("title",          ""))
	description    = str(data.get("description",    ""))
	giver_npc_id   = str(data.get("giver_npc_id",   ""))
	giver_npc_name = str(data.get("giver_npc_name", ""))
	required_item  = int(data.get("required_item",  0))
	required_count = int(data.get("required_count", 0))
	gold_reward    = int(data.get("gold_reward",    0))
	state          = int(data.get("state",          State.ACTIVE))
	given_at       = float(data.get("given_at",     0.0))
	completed_at   = float(data.get("completed_at", 0.0))
