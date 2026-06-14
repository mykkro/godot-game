class_name PerkDef

## Registry of all character perks and their named levels.
## Level 0 always means "does not have this perk".

enum ID {
	TRADER = 0,
	## Add future perks here, e.g.:
	## BLACKSMITH = 1,
	## HERBALIST  = 2,
}


static func get_perk_name(perk: ID) -> String:
	match perk:
		ID.TRADER: return "Trader"
	return "Unknown"


static func get_max_level(perk: ID) -> int:
	match perk:
		ID.TRADER: return 4
	return 0


## Returns the display name for a given level (empty string for level 0 / no perk).
static func get_level_name(perk: ID, level: int) -> String:
	if level <= 0:
		return ""
	match perk:
		ID.TRADER:
			match level:
				1: return "Apprentice Trader"
				2: return "Journeyman Trader"
				3: return "Expert Trader"
				4: return "Master Trader"
	return ""


## Factor applied to the coin amount the NPC pays when buying from the player.
## diff = npc_trader_level - player_trader_level
##   diff  0 → 1.0 (fair)   diff +3 → 0.5 (player gets half)
static func trader_sell_factor(player_level: int, npc_level: int) -> float:
	var diff := npc_level - player_level
	return clampf(1.0 - diff / 6.0, 0.2, 2.0)


## Factor applied to the coin cost when the player buys from the NPC.
## A skilled NPC trader charges more for their wares.
static func trader_buy_factor(player_level: int, npc_level: int) -> float:
	var diff := npc_level - player_level
	return clampf(1.0 + diff / 6.0, 0.5, 2.0)
