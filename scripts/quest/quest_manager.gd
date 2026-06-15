extends Node

## Autoload singleton — owns the full quest lifecycle.
## Add new quest types by extending QuestInstance.Type and adding a
## corresponding generate_* method.

## One in-game week: 7 days × 86400 sec/day.
const WEEK_SECS := 604800.0

## Items shopkeepers may request. Extend as more world resources are added.
const FETCH_POOL: Array[int] = [
	MapObject.Type.HERB,
	MapObject.Type.CRYSTAL,
	MapObject.Type.FEATHER,
	MapObject.Type.BERRY,
	MapObject.Type.MUSHROOM,
	MapObject.Type.COPPER_ORE,
	MapObject.Type.IRON_ORE,
	MapObject.Type.COAL_ORE,
]

var active_quests:    Array[QuestInstance] = []
var completed_quests: Array[QuestInstance] = []
## npc_id → game-time when their last quest was given (starts cooldown).
var _npc_cooldowns:   Dictionary           = {}
## quest_id of the quest currently shown on the minimap, or "".
var tracked_quest_id: String               = ""

signal quest_given(quest: QuestInstance)
signal quest_ready(quest: QuestInstance)
signal quest_completed(quest: QuestInstance)


# ── Query ─────────────────────────────────────────────────────────────────────

## True when the NPC has no active quest with the player and the weekly
## cooldown has elapsed (or no quest has ever been given to this NPC).
func can_offer_quest(npc: NpcMelee) -> bool:
	if get_quest_from_npc(npc.npc_id) != null:
		return false
	if not _npc_cooldowns.has(npc.npc_id):
		return true  # never issued a quest — always ready
	return GameClock.get_game_time() - float(_npc_cooldowns[npc.npc_id]) >= WEEK_SECS


## Returns the active quest given by this NPC, or null.
func get_quest_from_npc(npc_id: String) -> QuestInstance:
	for q: QuestInstance in active_quests:
		if q.giver_npc_id == npc_id:
			return q
	return null


## How many of item_type the inventory currently holds across all slots.
func count_item(inventory: Inventory, item_type: int) -> int:
	var total := 0
	for slot: Dictionary in inventory.items:
		if slot.get("type", -1) == item_type:
			total += int(slot.get("count", 0))
	return total


# ── Lifecycle ─────────────────────────────────────────────────────────────────

## Builds a fresh QuestInstance for an NPC offer (not yet registered).
## Call accept_quest() if the player agrees.
func generate_quest(npc: NpcMelee) -> QuestInstance:
	var q               := QuestInstance.new()
	q.quest_id           = "%s_%d" % [npc.npc_id, randi()]
	q.quest_type         = QuestInstance.Type.FETCH_RESOURCE
	q.giver_npc_id       = npc.npc_id
	q.giver_npc_name     = npc.npc_name
	q.given_at           = GameClock.get_game_time()
	q.required_item      = FETCH_POOL[randi() % FETCH_POOL.size()]
	q.required_count     = randi_range(3, 8)
	var unit_value       := PickableItemDef.get_coin_value(q.required_item)
	q.gold_reward        = max(8, unit_value * q.required_count * 2)
	var item_name        := PickableItemDef.get_display_name(q.required_item)
	q.title              = "%s's Request" % npc.npc_name
	q.description        = "Bring %d %s to %s." % [q.required_count, item_name, npc.npc_name]
	return q


## Toggles tracking for quest_id; clears it if already tracked.
func set_tracked(quest_id: String) -> void:
	tracked_quest_id = quest_id if tracked_quest_id != quest_id else ""


## Registers an offered quest; starts the NPC's weekly cooldown.
func accept_quest(quest: QuestInstance) -> void:
	active_quests.append(quest)
	_npc_cooldowns[quest.giver_npc_id] = quest.given_at
	quest_given.emit(quest)
	save()


## Syncs ACTIVE ↔ READY based on current inventory. Call whenever inventory
## may have changed (journal open, before turn-in dialog).
func check_readiness(inventory: Inventory) -> void:
	for q: QuestInstance in active_quests:
		var have := count_item(inventory, q.required_item)
		if q.state == QuestInstance.State.ACTIVE:
			if have >= q.required_count:
				q.state = QuestInstance.State.READY
				quest_ready.emit(q)
		elif q.state == QuestInstance.State.READY:
			if have < q.required_count:
				q.state = QuestInstance.State.ACTIVE


## Removes the required items from inventory, awards gold, marks the quest
## COMPLETED, and returns the gold paid. Returns 0 if the quest was not READY
## or the player no longer has the required items.
func try_complete(npc_id: String, inventory: Inventory) -> int:
	var q := get_quest_from_npc(npc_id)
	if q == null or q.state != QuestInstance.State.READY:
		return 0

	# Guard: re-verify the player still has everything (items may have been
	# dropped or used after the READY state was set).
	if count_item(inventory, q.required_item) < q.required_count:
		q.state = QuestInstance.State.ACTIVE
		return 0

	var remaining := q.required_count
	for i: int in range(inventory.items.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var slot := inventory.items[i] as Dictionary
		if slot.get("type", -1) == q.required_item:
			var to_take := mini(remaining, int(slot.get("count", 0)))
			inventory.remove_from_slot(i, to_take)
			remaining -= to_take

	for _i: int in range(q.gold_reward):
		inventory.add(MapObject.Type.COIN)

	q.state        = QuestInstance.State.COMPLETED
	q.completed_at = GameClock.get_game_time()
	active_quests.erase(q)
	completed_quests.append(q)
	if q.quest_id == tracked_quest_id:
		tracked_quest_id = ""
	quest_completed.emit(q)
	save()
	return q.gold_reward


# ── Persistence ───────────────────────────────────────────────────────────────

func save() -> void:
	SaveManager.save_quests(self)


func load_state() -> void:
	SaveManager.load_quests(self)


func to_dict() -> Dictionary:
	var active_arr:    Array = []
	var completed_arr: Array = []
	for q: QuestInstance in active_quests:
		active_arr.append(q.to_dict())
	for q: QuestInstance in completed_quests:
		completed_arr.append(q.to_dict())
	return {
		"active":    active_arr,
		"completed": completed_arr,
		"cooldowns": _npc_cooldowns,
	}


func from_dict(data: Dictionary) -> void:
	active_quests.clear()
	completed_quests.clear()
	_npc_cooldowns = data.get("cooldowns", {}) as Dictionary
	for d: Dictionary in (data.get("active", []) as Array):
		var q := QuestInstance.new()
		q.from_dict(d)
		active_quests.append(q)
	for d: Dictionary in (data.get("completed", []) as Array):
		var q := QuestInstance.new()
		q.from_dict(d)
		completed_quests.append(q)
