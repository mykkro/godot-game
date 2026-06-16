class_name PerkDef

## Registry of all character perks and their named levels.
## Level 0 always means "does not have this perk".

enum ID {
	TRADER           = 0,
	SWIFT_WALKER     = 1,
	STRONG           = 2,
	TOUGH            = 3,
	WISE             = 4,
	ARMORED          = 5,
	SPELL_FOCUS      = 6,
	VAMPIRIC         = 7,
	EFFICIENT_CASTER = 8,
	BERSERKER        = 9,
	QUICK            = 10,
}


static func get_perk_name(perk: ID) -> String:
	match perk:
		ID.TRADER:           return "Trader"
		ID.SWIFT_WALKER:     return "Swift Walker"
		ID.STRONG:           return "Strong"
		ID.TOUGH:            return "Tough"
		ID.WISE:             return "Wise"
		ID.ARMORED:          return "Armored"
		ID.SPELL_FOCUS:      return "Spell Focus"
		ID.VAMPIRIC:         return "Vampiric"
		ID.EFFICIENT_CASTER: return "Efficient Caster"
		ID.BERSERKER:        return "Berserker"
		ID.QUICK:            return "Quick"
	return "Unknown"


static func get_max_level(perk: ID) -> int:
	match perk:
		ID.TRADER:       return 4
		ID.SWIFT_WALKER: return 3
		ID.STRONG, ID.TOUGH, ID.WISE, ID.ARMORED, \
		ID.SPELL_FOCUS, ID.VAMPIRIC, \
		ID.EFFICIENT_CASTER, ID.BERSERKER, ID.QUICK: return 3
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
		ID.SWIFT_WALKER:
			match level:
				1: return "Wayfarer"
				2: return "Strider"
				3: return "Windwalker"
		ID.STRONG:
			match level:
				1: return "Strengthened"
				2: return "Mighty"
				3: return "Titan"
		ID.TOUGH:
			match level:
				1: return "Hardy"
				2: return "Stalwart"
				3: return "Ironhide"
		ID.WISE:
			match level:
				1: return "Focused"
				2: return "Enlightened"
				3: return "Sage"
		ID.ARMORED:
			match level:
				1: return "Plated"
				2: return "Fortified"
				3: return "Bulwark"
		ID.SPELL_FOCUS:
			match level:
				1: return "Attuned"
				2: return "Channeler"
				3: return "Arcane Mastery"
		ID.VAMPIRIC:
			match level:
				1: return "Blood Drinker"
				2: return "Lifesteal"
				3: return "Soul Drain"
		ID.EFFICIENT_CASTER:
			match level:
				1: return "Conserving"
				2: return "Efficient"
				3: return "Arcane Efficiency"
		ID.BERSERKER:
			match level:
				1: return "Hot-Blooded"
				2: return "Frenzy"
				3: return "Berserker"
		ID.QUICK:
			match level:
				1: return "Nimble"
				2: return "Swift"
				3: return "Lightning Reflexes"
	return ""


## Movement speed multiplier relative to the (halved) baseline.
## Level 2 restores the original speed; level 3 exceeds it.
static func swift_walker_speed_mult(level: int) -> float:
	match level:
		1: return 1.35
		2: return 2.0
		3: return 2.75
	return 1.0


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


## Stat delta applied to HeroStats when picking one level of a stat perk.
## Runtime perks (Vampiric, Berserker, Efficient Caster) return {}.
static func get_stat_delta(perk: ID) -> Dictionary:
	match perk:
		ID.STRONG:      return {"attack":   1}
		ID.TOUGH:       return {"max_hp":   5}
		ID.WISE:        return {"max_mana": 3}
		ID.ARMORED:     return {"defense":  1}
		ID.SPELL_FOCUS: return {"magic":    1}
		ID.QUICK:       return {"initiative": 1}
	return {}


## HP healed after killing a monster (Vampiric perk).
static func get_vampiric_heal(level: int) -> int:
	return level  # 1 / 2 / 3


## Flat attack bonus when hero HP is below 30% (Berserker perk).
static func get_berserker_bonus(level: int) -> int:
	return level * 3  # 3 / 6 / 9


## Description of what the given NEW level of a perk grants.
## Used in the level-up card UI.
static func perk_description(perk: ID, new_level: int) -> String:
	match perk:
		ID.STRONG:           return "+1 Attack"
		ID.TOUGH:            return "+5 Max HP"
		ID.WISE:             return "+3 Max Mana"
		ID.ARMORED:          return "+1 Defense"
		ID.SPELL_FOCUS:      return "+1 Magic"
		ID.VAMPIRIC:         return "Heal %d HP after killing a monster" % new_level
		ID.EFFICIENT_CASTER: return "Spells cost %d less mana (min 1)" % new_level
		ID.BERSERKER:        return "+%d Attack when below 30%% HP" % (new_level * 3)
		ID.QUICK:            return "+1 Initiative"
	return ""
