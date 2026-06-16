class_name PickableItemDef

## Static registry: maps MapObject.Type int → display metadata.
## Only types listed here are treated as pickable (passable, can be picked up).

## Maximum items per inventory stack. 1 = non-stackable (default).
static func max_stack_size(obj_type: int) -> int:
	match obj_type:
		MapObject.Type.COIN: return 1000

		# Stack 64 — raw materials, ores, seeds, fibers, bulk solids.
		MapObject.Type.NAILS,         MapObject.Type.WOOD_PLANK,  \
		MapObject.Type.WOODEN_ROD,    MapObject.Type.CLOTH,       \
		MapObject.Type.COPPER_ORE,    MapObject.Type.IRON_ORE,    \
		MapObject.Type.SILVER_NUGGET, MapObject.Type.GOLD_NUGGET, \
		MapObject.Type.COPPER_BAR,    MapObject.Type.IRON_BAR,    \
		MapObject.Type.SILVER_BAR,    MapObject.Type.GOLD_BAR,    \
		MapObject.Type.DRAGONSCALE,   MapObject.Type.GEM,         \
		MapObject.Type.LEATHER,                                    \
		MapObject.Type.CASSITERITE,   MapObject.Type.CHROMITE,    \
		MapObject.Type.CINNABAR,      MapObject.Type.COAL_ORE,    \
		MapObject.Type.GALENA,        MapObject.Type.MOLYBDENITE, \
		MapObject.Type.QUARTZITE,     MapObject.Type.LODESTONE,   \
		MapObject.Type.GRANITE,       MapObject.Type.STONE,       \
		MapObject.Type.MELANTERITE,   MapObject.Type.CHARACTITE,  \
		MapObject.Type.LEAD_BAR,      MapObject.Type.SHOCK_STEEL_BAR, \
		MapObject.Type.FERROCHROME,                               \
		MapObject.Type.COPPER_DISK,   MapObject.Type.COPPER_WIRE, \
		MapObject.Type.GLASS,         MapObject.Type.GLASS_FIBER, \
		MapObject.Type.MINIUM,        MapObject.Type.NITER,       \
		MapObject.Type.SPIDER_PLASTIC,                            \
		MapObject.Type.FLAX_SEEDS,    MapObject.Type.OAT_SEEDS,   \
		MapObject.Type.ROSE_SEEDS,    MapObject.Type.WHEAT_SEEDS, \
		MapObject.Type.FLAX_STRING:
			return 64

		# Stack 16 — perishables, plants, logs, powders, food.
		MapObject.Type.FEATHER,                                     \
		MapObject.Type.MERCURY,                                     \
		MapObject.Type.CEDAR_LOG,      MapObject.Type.DRAGONTAIL_LOG, \
		MapObject.Type.RED_PINE_LOG,   MapObject.Type.WILLOW_LOG,  \
		MapObject.Type.SARGASSUM,      MapObject.Type.CARRAGEEN_MOSS, \
		MapObject.Type.FLAX,           MapObject.Type.FRITILLARIA, \
		MapObject.Type.HEARTROOT,      MapObject.Type.ROSE,        \
		MapObject.Type.SEA_GRAPES,     MapObject.Type.SEASHELL,    \
		MapObject.Type.SARGASSUM_POWDER, MapObject.Type.CHARACTER_POWDER, \
		MapObject.Type.FRITILLARIA_POWDER, MapObject.Type.ROSE_POWDER,   \
		MapObject.Type.APPLE,          MapObject.Type.BANANA,      \
		MapObject.Type.BERRY,          MapObject.Type.BLUEBERRY,   \
		MapObject.Type.BLACKBERRY,     MapObject.Type.ORANGE,      \
		MapObject.Type.PEAR,           MapObject.Type.COCONUT,     \
		MapObject.Type.MUSHROOM,       MapObject.Type.TRUFFLE,     \
		MapObject.Type.BREAD_ROLL,     MapObject.Type.SHRIMP,      \
		MapObject.Type.WHEAT,          MapObject.Type.OATS,        \
		MapObject.Type.BLACK_OLIVE,    MapObject.Type.JUICE,       \
		MapObject.Type.OATMEAL_BREAD,  MapObject.Type.SMOOTHIE,    \
		MapObject.Type.SOUP,           MapObject.Type.STEW,        \
		MapObject.Type.BADGE,          MapObject.Type.MAP_PIN,     \
		MapObject.Type.RECYCLING_STAMP, MapObject.Type.TICKET, \
		MapObject.Type.HEALTH_POTION, MapObject.Type.MANA_POTION:
			return 16

		# Stack 8 — drinks and fragile vials.
		MapObject.Type.WEAK_STUDYING_DRINK,                        \
		MapObject.Type.GLASS_VIAL,     MapObject.Type.VIAL_MERCURY, \
		MapObject.Type.VIAL_NITRIC_ACID, MapObject.Type.VIAL_SULPHURIC_ACID, \
		MapObject.Type.VIAL_SLUG_GEL,  MapObject.Type.VIAL_LEAD_DIOXIDE, \
		MapObject.Type.SMOKE_SIGNAL,   MapObject.Type.TORCH:
			return 8

		# Stack 4 — elemental jars.
		MapObject.Type.ELEMENTAL_JAR,      MapObject.Type.ELEMENTAL_JAR_SAP, \
		MapObject.Type.ELEMENTAL_JAR_LAVA, MapObject.Type.ELEMENTAL_JAR_WATER:
			return 4

		# Stack 16 — ravenmore gems.
		MapObject.Type.GEM_RED, MapObject.Type.GEM_GREEN, MapObject.Type.GEM_BLUE:
			return 16

		# Kyrise stackables.
		MapObject.Type.WOOD_ARROW,  MapObject.Type.BONE_ARROW,  \
		MapObject.Type.SILVER_ARROW, MapObject.Type.METAL_INGOT:
			return 64
		MapObject.Type.RAW_FISH, MapObject.Type.SWEET,           \
		MapObject.Type.FACETED_GEM, MapObject.Type.MAGIC_CRYSTAL, \
		MapObject.Type.PEARL:
			return 16

	# Default 1 = non-stackable.
	# Covers: HERB, CRYSTAL, POTION, all weapons, agri-tools, containers,
	# boats, clothing, books, devices, and unique misc items.
	return 1


## Returns true when this object type can be picked up by the avatar.
## Everything except map obstacles (ROCK, CHEST_SMALL) is pickable.
static func is_pickable(obj_type: int) -> bool:
	return obj_type != MapObject.Type.ROCK \
		and obj_type != MapObject.Type.CHEST_SMALL \
		and obj_type != MapObject.Type.FORGE


## Returns true when an item can be placed in the belt and used directly.
static func is_useable(obj_type: int) -> bool:
	return obj_type == MapObject.Type.HEALTH_POTION \
		or obj_type == MapObject.Type.MANA_POTION


## Human-readable name shown in the inventory.
static func get_display_name(obj_type: int) -> String:
	return MapObject.get_display_name(obj_type)


## Sprite filename inside res://media/raven-objects/ (legacy items only).
static func get_sprite(obj_type: int) -> String:
	match obj_type:
		MapObject.Type.HERB:    return "fc100.png"
		MapObject.Type.CRYSTAL: return "fc4.png"
		MapObject.Type.COIN:    return "fc2.png"
		MapObject.Type.FEATHER: return "fc7.png"
		MapObject.Type.POTION:  return "fc50.png"
	return "fc1.png"


## Filename in res://media/kyrise/ for this type, or "" if sourced elsewhere.
static func _kyrise_file(obj_type: int) -> String:
	match obj_type:
		MapObject.Type.IRON_SWORD:        return "sword_01a.png"
		MapObject.Type.STEEL_SWORD:       return "sword_02a.png"
		MapObject.Type.SILVER_SWORD:      return "sword_03a.png"
		MapObject.Type.HUNTING_BOW:       return "bow_01a.png"
		MapObject.Type.WAR_BOW:           return "bow_02a.png"
		MapObject.Type.ELVEN_BOW:         return "bow_03a.png"
		MapObject.Type.APPRENTICE_STAFF:  return "staff_01a.png"
		MapObject.Type.WIZARD_STAFF:      return "staff_02ab.png"
		MapObject.Type.ELDER_STAFF:       return "staff_03a.png"
		MapObject.Type.WOOD_ARROW:        return "arrow_01a.png"
		MapObject.Type.BONE_ARROW:        return "arrow_02a.png"
		MapObject.Type.SILVER_ARROW:      return "arrow_03a.png"
		MapObject.Type.BUCKLER:           return "shield_01a.png"
		MapObject.Type.ROUND_SHIELD:      return "shield_02a.png"
		MapObject.Type.KITE_SHIELD:       return "shield_03a.png"
		MapObject.Type.OPEN_HELMET:       return "helmet_01a.png"
		MapObject.Type.GREAT_HELM:        return "helmet_02a.png"
		MapObject.Type.SPELLBOOK:         return "spellbook_01a.png"
		MapObject.Type.ARCANE_TOME:       return "spellbook_02a.png"
		MapObject.Type.FORBIDDEN_TOME:    return "spellbook_03a.png"
		MapObject.Type.IRON_RING:         return "ring_01a.png"
		MapObject.Type.SILVER_RING:       return "ring_02a.png"
		MapObject.Type.MAGIC_RING:        return "ring_03a.png"
		MapObject.Type.BRONZE_NECKLACE:   return "necklace_01a.png"
		MapObject.Type.SILVER_NECKLACE:   return "necklace_02a.png"
		MapObject.Type.MAGIC_NECKLACE:    return "necklace_03a.png"
		MapObject.Type.IRON_KEY:          return "key_01a.png"
		MapObject.Type.GOLD_KEY:          return "key_02a.png"
		MapObject.Type.PEARL:             return "pearl_01a.png"
		MapObject.Type.METAL_INGOT:       return "ingot_01a.png"
		MapObject.Type.RAW_FISH:          return "fish_01a.png"
		MapObject.Type.SWEET:             return "candy_01a.png"
		MapObject.Type.GIFT_BOX:          return "gift_01a.png"
		MapObject.Type.FACETED_GEM:       return "gem_01a.png"
		MapObject.Type.MAGIC_CRYSTAL:     return "crystal_01a.png"
	return ""


## [col, row] in the Flare 5×5 armor atlas, or Vector2i(-1,-1) if not armor.
static func _flare_armor_coord(obj_type: int) -> Vector2i:
	match obj_type:
		MapObject.Type.CLOTH_TUNIC:           return Vector2i(1, 0)
		MapObject.Type.CLOTH_GLOVES:          return Vector2i(2, 0)
		MapObject.Type.CLOTH_TROUSERS:        return Vector2i(3, 0)
		MapObject.Type.CLOTH_BOOTS:           return Vector2i(4, 0)
		MapObject.Type.LEATHER_HELM:          return Vector2i(0, 1)
		MapObject.Type.LEATHER_TUNIC:         return Vector2i(1, 1)
		MapObject.Type.LEATHER_GLOVES:        return Vector2i(2, 1)
		MapObject.Type.LEATHER_TROUSERS:      return Vector2i(3, 1)
		MapObject.Type.LEATHER_BOOTS:         return Vector2i(4, 1)
		MapObject.Type.HARD_LEATHER_HELM:     return Vector2i(0, 2)
		MapObject.Type.HARD_LEATHER_TUNIC:    return Vector2i(1, 2)
		MapObject.Type.HARD_LEATHER_GLOVES:   return Vector2i(2, 2)
		MapObject.Type.HARD_LEATHER_TROUSERS: return Vector2i(3, 2)
		MapObject.Type.HARD_LEATHER_BOOTS:    return Vector2i(4, 2)
		MapObject.Type.CHAIN_COIF:            return Vector2i(0, 3)
		MapObject.Type.CHAIN_MAIL:            return Vector2i(1, 3)
		MapObject.Type.CHAIN_GLOVES:          return Vector2i(2, 3)
		MapObject.Type.CHAIN_TROUSERS:        return Vector2i(3, 3)
		MapObject.Type.CHAIN_BOOTS:           return Vector2i(4, 3)
		MapObject.Type.PLATE_HELM:            return Vector2i(0, 4)
		MapObject.Type.PLATE_MAIL:            return Vector2i(1, 4)
		MapObject.Type.PLATE_GAUNTLETS:       return Vector2i(2, 4)
		MapObject.Type.PLATE_GREAVES:         return Vector2i(3, 4)
		MapObject.Type.PLATE_BOOTS:           return Vector2i(4, 4)
	return Vector2i(-1, -1)


## Filename in res://media/ravenmore/ for this type, or "" if sourced elsewhere.
static func _ravenmore_file(obj_type: int) -> String:
	match obj_type:
		MapObject.Type.WOODEN_SWORD: return "swordWood.png"
		MapObject.Type.SWORD:        return "sword.png"
		MapObject.Type.AXE:          return "axe.png"
		MapObject.Type.BOW:          return "bow.png"
		MapObject.Type.DAGGER:       return "dagger.png"
		MapObject.Type.WAND:         return "wand.png"
		MapObject.Type.HELMET:       return "helmet.png"
		MapObject.Type.ARMOR:        return "armor.png"
		MapObject.Type.SHIELD:       return "shield.png"
		MapObject.Type.SCROLL:       return "scroll.png"
		MapObject.Type.TOME:         return "tome.png"
		MapObject.Type.GEM_RED:      return "gemRed.png"
		MapObject.Type.GEM_GREEN:    return "gemGreen.png"
		MapObject.Type.GEM_BLUE:     return "gemBlue.png"
		MapObject.Type.HEART_AMULET: return "heart.png"
		MapObject.Type.HEALTH_POTION: return "potionRed.png"
		MapObject.Type.MANA_POTION:   return "potionBlue.png"
	return ""


## Filename in res://media/items2/ for this type, or "" if sourced elsewhere.
static func _items2_file(obj_type: int) -> String:
	match obj_type:
		# Materials with items2 equivalents.
		MapObject.Type.WOOD_PLANK:    return "plank.png"
		MapObject.Type.WOODEN_ROD:    return "stick.png"
		MapObject.Type.CLOTH:         return "linen fabric.png"
		MapObject.Type.COPPER_ORE:    return "copper ore.png"
		MapObject.Type.IRON_ORE:      return "hematite.png"
		MapObject.Type.SILVER_NUGGET: return "tiny platinum nugget.png"
		MapObject.Type.COPPER_BAR:    return "copper bar.png"
		MapObject.Type.IRON_BAR:      return "iron bar.png"
		MapObject.Type.SILVER_BAR:    return "tin bar.png"
		MapObject.Type.GOLD_BAR:      return "bronze bar.png"
		MapObject.Type.DRAGONSCALE:   return "Thorn dragon egg.png"
		MapObject.Type.GEM:           return "scheelite.png"
		# Weapons.
		MapObject.Type.STONE_AXE:     return "stone axe.png"
		MapObject.Type.STONE_PICK:    return "stone pick.png"
		MapObject.Type.BRONZE_AXE:    return "bronze axe.png"
		MapObject.Type.BRONZE_PICK:   return "bronze pick.png"
		MapObject.Type.IRON_AXE:      return "iron axe.png"
		MapObject.Type.IRON_PICK:     return "iron pick.png"
		MapObject.Type.IRON_HAMMER:   return "iron hammer.png"
		MapObject.Type.STEEL_PICK:    return "steel pick.png"
		MapObject.Type.FISHING_ROD:   return "fishing rod.png"
		MapObject.Type.FISHING_NET:   return "fishing net.png"
		# Food (first set).
		MapObject.Type.APPLE:         return "apple.png"
		MapObject.Type.BANANA:        return "banana.png"
		MapObject.Type.BERRY:         return "berry.png"
		MapObject.Type.BLUEBERRY:     return "blueberry.png"
		MapObject.Type.BLACKBERRY:    return "blackberry.png"
		MapObject.Type.ORANGE:        return "orange.png"
		MapObject.Type.PEAR:          return "pear.png"
		MapObject.Type.COCONUT:       return "coconut.png"
		MapObject.Type.MUSHROOM:      return "mushroom.png"
		MapObject.Type.TRUFFLE:       return "truffle.png"
		MapObject.Type.BREAD_ROLL:    return "bread roll.png"
		MapObject.Type.SHRIMP:        return "shrimp.png"
		MapObject.Type.WHEAT:         return "wheat.png"
		MapObject.Type.OATS:          return "oats.png"
		# Ores & minerals.
		MapObject.Type.CASSITERITE:   return "cassiterite.png"
		MapObject.Type.CHROMITE:      return "chromite.png"
		MapObject.Type.CINNABAR:      return "cinnabar.png"
		MapObject.Type.COAL_ORE:      return "coal ore.png"
		MapObject.Type.GALENA:        return "galena.png"
		MapObject.Type.MOLYBDENITE:   return "molybdenite.png"
		MapObject.Type.QUARTZITE:     return "quartzite.png"
		MapObject.Type.LODESTONE:     return "lodestone.png"
		MapObject.Type.GRANITE:       return "granite.png"
		MapObject.Type.STONE:         return "stone.png"
		MapObject.Type.MELANTERITE:   return "melanterite.png"
		MapObject.Type.CHARACTITE:    return "charactite.png"
		# Metal bars & alloys.
		MapObject.Type.LEAD_BAR:           return "lead bar.png"
		MapObject.Type.SHOCK_STEEL_BAR:    return "shock steel bar.png"
		MapObject.Type.FERROCHROME:        return "ferrochrome.png"
		# Metal parts.
		MapObject.Type.COPPER_DISK:   return "copper disk.png"
		MapObject.Type.COPPER_WIRE:   return "copper wire.png"
		# Glass & chemical materials.
		MapObject.Type.GLASS:          return "glass.png"
		MapObject.Type.GLASS_FIBER:    return "glass fiber.png"
		MapObject.Type.MERCURY:        return "mercury.png"
		MapObject.Type.MINIUM:         return "minium.png"
		MapObject.Type.NITER:          return "niter.png"
		MapObject.Type.SPIDER_PLASTIC: return "spider plastic.png"
		# Logs.
		MapObject.Type.CEDAR_LOG:      return "cedar log.png"
		MapObject.Type.DRAGONTAIL_LOG: return "dragontail log.png"
		MapObject.Type.RED_PINE_LOG:   return "red pine log.png"
		MapObject.Type.WILLOW_LOG:     return "willow log.png"
		# Boats.
		MapObject.Type.CEDAR_BOAT:      return "cedar boat.png"
		MapObject.Type.DRAGONTAIL_BOAT: return "dragontail boat.png"
		MapObject.Type.RAFT:            return "raft.png"
		# Plants & herbs.
		MapObject.Type.SARGASSUM:      return "Sargassum.png"
		MapObject.Type.CARRAGEEN_MOSS: return "carrageen moss.png"
		MapObject.Type.FLAX:           return "flax.png"
		MapObject.Type.FRITILLARIA:    return "fritillaria imperialis.png"
		MapObject.Type.HEARTROOT:      return "heartroot.png"
		MapObject.Type.ROSE:           return "rose.png"
		MapObject.Type.SEA_GRAPES:     return "sea grapes.png"
		MapObject.Type.SEASHELL:       return "seashell.png"
		# Seeds.
		MapObject.Type.FLAX_SEEDS:  return "flax seeds.png"
		MapObject.Type.OAT_SEEDS:   return "oat seeds.png"
		MapObject.Type.ROSE_SEEDS:  return "rose seeds.png"
		MapObject.Type.WHEAT_SEEDS: return "wheat seeds.png"
		# Fibers.
		MapObject.Type.FLAX_STRING: return "flax string.png"
		# Alchemy.
		MapObject.Type.SARGASSUM_POWDER:    return "Sargassum powder.png"
		MapObject.Type.CHARACTER_POWDER:    return "character powder.png"
		MapObject.Type.FRITILLARIA_POWDER:  return "fritillaria powder.png"
		MapObject.Type.ROSE_POWDER:         return "rose powder.png"
		MapObject.Type.WEAK_STUDYING_DRINK: return "weak studying drink.png"
		MapObject.Type.CHARACTER:           return "character.png"
		# Chemical vials.
		MapObject.Type.GLASS_VIAL:          return "glass vial.png"
		MapObject.Type.VIAL_MERCURY:        return "glass vial with mercury.png"
		MapObject.Type.VIAL_NITRIC_ACID:    return "glass vial with nitric acid.png"
		MapObject.Type.VIAL_SULPHURIC_ACID: return "glass vial with sulphuric acid.png"
		MapObject.Type.VIAL_SLUG_GEL:       return "glass vial with slug gel.png"
		MapObject.Type.VIAL_LEAD_DIOXIDE:   return "glass vial with lead dioxide.png"
		# Elemental jars.
		MapObject.Type.ELEMENTAL_JAR:       return "elemental jar.png"
		MapObject.Type.ELEMENTAL_JAR_SAP:   return "elemental jar with ancient sap.png"
		MapObject.Type.ELEMENTAL_JAR_LAVA:  return "elemental jar with lava residue.png"
		MapObject.Type.ELEMENTAL_JAR_WATER: return "elemental jar with twisting water.png"
		# Containers.
		MapObject.Type.BRONZE_BUCKET:      return "bronze bucket.png"
		MapObject.Type.BRONZE_BUCKET_CLAY: return "bronze bucket with clay.png"
		MapObject.Type.BRONZE_BUCKET_SAND: return "bronze bucket with sand.png"
		MapObject.Type.CLAY_POT:           return "clay pot.png"
		MapObject.Type.POT:                return "pot.png"
		MapObject.Type.COPPER_RETORT:      return "copper retort.png"
		MapObject.Type.GLASS_RETORT:       return "glass retort.png"
		MapObject.Type.TIN_CAGE:           return "tin cage.png"
		# Agricultural tools.
		MapObject.Type.BRONZE_HOE:    return "bronze hoe.png"
		MapObject.Type.BRONZE_SICKLE: return "bronze sickle.png"
		MapObject.Type.BRONZE_SPADE:  return "bronze spade.png"
		MapObject.Type.COPPER_SICKLE: return "copper sickle.png"
		MapObject.Type.IRON_HOE:      return "iron hoe.png"
		MapObject.Type.IRON_SICKLE:   return "iron sickle.png"
		MapObject.Type.WOODEN_HOE:    return "wooden hoe.png"
		# Extra food.
		MapObject.Type.BLACK_OLIVE:   return "black olive.png"
		MapObject.Type.JUICE:         return "juice.png"
		MapObject.Type.OATMEAL_BREAD: return "oatmeal bread.png"
		MapObject.Type.SMOOTHIE:      return "smoothie.png"
		MapObject.Type.SOUP:          return "soup.png"
		MapObject.Type.STEW:          return "stew.png"
		# Clothing & accessories.
		MapObject.Type.LINEN_BACKPACK:     return "linen backpack.png"
		MapObject.Type.LINEN_SHOES:        return "linen shoes.png"
		MapObject.Type.TINY_BACKPACK:      return "tiny backpack.png"
		MapObject.Type.BLACKHOLE_BACKPACK: return "blackhole backpack.png"
		MapObject.Type.SADDLE:             return "saddle.png"
		MapObject.Type.SKIS:               return "skis.png"
		# Books & documents.
		MapObject.Type.ALMANAC:     return "almanac.png"
		MapObject.Type.BOOK:        return "book.png"
		MapObject.Type.CALENDAR:    return "calendar.png"
		MapObject.Type.RECIPE:      return "recipe.png"
		MapObject.Type.BIOME_MAP:   return "biome map.png"
		MapObject.Type.MAP_DISPLAY: return "map display.png"
		MapObject.Type.SAFETY_MAP:  return "safety map.png"
		# Devices & technology.
		MapObject.Type.ANVIL:                   return "anvil.png"
		MapObject.Type.AUTOFEEDER:              return "autofeeder.png"
		MapObject.Type.BINOCULARS:              return "binoculars.png"
		MapObject.Type.CAMPFIRE:                return "campfire.png"
		MapObject.Type.CHARGING_PAD:            return "charging pad.png"
		MapObject.Type.FLASHLIGHT:              return "flashlight.png"
		MapObject.Type.FORGE:                   return "forge.png"
		MapObject.Type.HAMSTER_WHEEL:           return "hamster wheel.png"
		MapObject.Type.HAMSTER_WHEEL_GENERATOR: return "hamster wheel generator.png"
		MapObject.Type.HOMOPOLAR_GENERATOR:     return "homopolar generator.png"
		MapObject.Type.JETPACK:                 return "jetpack.png"
		MapObject.Type.LEAD_ACID_BATTERY:       return "lead acid battery.png"
		MapObject.Type.THERMOMETER:             return "thermometer.png"
		MapObject.Type.WATCH:                   return "watch.png"
		# Miscellaneous.
		MapObject.Type.BADGE:               return "badge.png"
		MapObject.Type.FLAX_LEASH:          return "flax leash.png"
		MapObject.Type.UPGRADED_FLAX_LEASH: return "upgraded flax leash.png"
		MapObject.Type.MAP_PIN:             return "map pin wheat.png"
		MapObject.Type.RECYCLING_STAMP:     return "recycling stamp.png"
		MapObject.Type.SIGN:                return "sign.png"
		MapObject.Type.SMALL_WILLOW_CHEST:  return "small willow chest.png"
		MapObject.Type.SMOKE_SIGNAL:        return "smoke signal.png"
		MapObject.Type.TICKET:              return "ticket.png"
		MapObject.Type.TORCH:               return "torch.png"
		MapObject.Type.WILLOW_CHEST:        return "willow chest.png"
	return ""


## Column and row in the 4×4 materials atlas (res://media/materials/nails.png).
## Returns Vector2i(-1, -1) for items not in the atlas.
static func _atlas_coord(obj_type: int) -> Vector2i:
	match obj_type:
		MapObject.Type.NAILS:         return Vector2i(0, 0)
		MapObject.Type.WOOD_PLANK:    return Vector2i(1, 0)
		MapObject.Type.WOODEN_ROD:    return Vector2i(2, 0)
		MapObject.Type.CLOTH:         return Vector2i(3, 0)
		MapObject.Type.COPPER_ORE:    return Vector2i(0, 1)
		MapObject.Type.IRON_ORE:      return Vector2i(1, 1)
		MapObject.Type.SILVER_NUGGET: return Vector2i(2, 1)
		MapObject.Type.GOLD_NUGGET:   return Vector2i(3, 1)
		MapObject.Type.COPPER_BAR:    return Vector2i(0, 2)
		MapObject.Type.IRON_BAR:      return Vector2i(1, 2)
		MapObject.Type.SILVER_BAR:    return Vector2i(2, 2)
		MapObject.Type.GOLD_BAR:      return Vector2i(3, 2)
		MapObject.Type.FEATHER:       return Vector2i(0, 3)
		MapObject.Type.DRAGONSCALE:   return Vector2i(1, 3)
		MapObject.Type.GEM:           return Vector2i(2, 3)
		MapObject.Type.LEATHER:       return Vector2i(3, 3)
	return Vector2i(-1, -1)


## Returns the icon Texture2D for any pickable item type.
## Priority: ravenmore → flare armor → kyrise → items2 PNG → materials atlas → legacy sprite.
static func get_texture(obj_type: int) -> Texture2D:
	var r := _ravenmore_file(obj_type)
	if r != "":
		return TextureCache.get_ravenmore_texture(r)
	var ac := _flare_armor_coord(obj_type)
	if ac.x >= 0:
		return TextureCache.get_flare_armor_texture(ac.x, ac.y)
	var k := _kyrise_file(obj_type)
	if k != "":
		return TextureCache.get_kyrise_texture(k)
	var f := _items2_file(obj_type)
	if f != "":
		return TextureCache.get_items2_texture(f)
	var coord := _atlas_coord(obj_type)
	if coord.x >= 0:
		return TextureCache.get_material_texture(coord.x, coord.y)
	return TextureCache.get_object_texture(get_sprite(obj_type))


## Coin value for one unit of this item type.  Used by ShopUI for balance calc.
static func get_coin_value(obj_type: int) -> int:
	match obj_type:
		MapObject.Type.COIN, MapObject.Type.STONE, MapObject.Type.GRANITE, MapObject.Type.FEATHER:
			return 1
		MapObject.Type.NAILS,        MapObject.Type.WOOD_PLANK,   \
		MapObject.Type.WOODEN_ROD,   MapObject.Type.CLOTH,        \
		MapObject.Type.COAL_ORE,     MapObject.Type.FLAX_SEEDS,   \
		MapObject.Type.OAT_SEEDS,    MapObject.Type.ROSE_SEEDS,   \
		MapObject.Type.WHEAT_SEEDS:
			return 3
		MapObject.Type.CEDAR_LOG,    MapObject.Type.RED_PINE_LOG,  \
		MapObject.Type.WILLOW_LOG,   MapObject.Type.LEATHER,       \
		MapObject.Type.FLAX,         MapObject.Type.SEA_GRAPES,    \
		MapObject.Type.SEASHELL,     MapObject.Type.APPLE,         \
		MapObject.Type.BERRY,        MapObject.Type.BLUEBERRY,     \
		MapObject.Type.BLACKBERRY,   MapObject.Type.BANANA,        \
		MapObject.Type.ORANGE,       MapObject.Type.PEAR,          \
		MapObject.Type.COCONUT,      MapObject.Type.BLACK_OLIVE,   \
		MapObject.Type.WHEAT,        MapObject.Type.OATS:
			return 4
		MapObject.Type.DRAGONTAIL_LOG, MapObject.Type.ROSE,         \
		MapObject.Type.SARGASSUM,    MapObject.Type.CARRAGEEN_MOSS, \
		MapObject.Type.JUICE,        MapObject.Type.TORCH:
			return 5
		MapObject.Type.COPPER_ORE,   MapObject.Type.GLASS,         \
		MapObject.Type.BREAD_ROLL,   MapObject.Type.SHRIMP:
			return 6
		MapObject.Type.IRON_ORE,     MapObject.Type.CASSITERITE,   \
		MapObject.Type.CHROMITE,     MapObject.Type.CINNABAR,      \
		MapObject.Type.GALENA,       MapObject.Type.MOLYBDENITE,   \
		MapObject.Type.QUARTZITE,    MapObject.Type.LODESTONE,     \
		MapObject.Type.MELANTERITE,  MapObject.Type.CHARACTITE,    \
		MapObject.Type.MUSHROOM,     MapObject.Type.FRITILLARIA:
			return 8
		MapObject.Type.COPPER_DISK,  MapObject.Type.COPPER_WIRE,   \
		MapObject.Type.HEARTROOT,    MapObject.Type.MAP_PIN,       \
		MapObject.Type.FLAX_STRING,  MapObject.Type.FLAX_LEASH,   \
		MapObject.Type.BADGE:
			return 10
		MapObject.Type.COPPER_BAR,   MapObject.Type.GLASS_FIBER,   \
		MapObject.Type.MINIUM,       MapObject.Type.NITER,         \
		MapObject.Type.SARGASSUM_POWDER, MapObject.Type.OATMEAL_BREAD:
			return 12
		MapObject.Type.MERCURY,      MapObject.Type.SPIDER_PLASTIC, \
		MapObject.Type.CHARACTER_POWDER,                            \
		MapObject.Type.FRITILLARIA_POWDER, MapObject.Type.ROSE_POWDER, \
		MapObject.Type.VIAL_SLUG_GEL, MapObject.Type.VIAL_LEAD_DIOXIDE, \
		MapObject.Type.VIAL_MERCURY, MapObject.Type.LEAD_BAR,      \
		MapObject.Type.SMOOTHIE,     MapObject.Type.UPGRADED_FLAX_LEASH, \
		MapObject.Type.RECYCLING_STAMP:
			return 15
		MapObject.Type.IRON_BAR,     MapObject.Type.VIAL_NITRIC_ACID, \
		MapObject.Type.VIAL_SULPHURIC_ACID:
			return 18
		MapObject.Type.SILVER_NUGGET, MapObject.Type.GLASS_VIAL,   \
		MapObject.Type.CALENDAR,     MapObject.Type.BRONZE_BUCKET, \
		MapObject.Type.SOUP,         MapObject.Type.SIGN,          \
		MapObject.Type.WEAK_STUDYING_DRINK, MapObject.Type.ELEMENTAL_JAR, \
		MapObject.Type.CAMPFIRE,     MapObject.Type.HERB,          \
		MapObject.Type.STONE_AXE,    MapObject.Type.STONE_PICK,    \
		MapObject.Type.WOODEN_HOE:
			return 20
		MapObject.Type.STEW,         MapObject.Type.TRUFFLE,       \
		MapObject.Type.CRYSTAL,      MapObject.Type.LINEN_SHOES,   \
		MapObject.Type.THERMOMETER,  MapObject.Type.RECIPE,        \
		MapObject.Type.SMOKE_SIGNAL, MapObject.Type.TICKET,        \
		MapObject.Type.CLAY_POT,     MapObject.Type.TIN_CAGE:
			return 25
		MapObject.Type.GOLD_NUGGET,  MapObject.Type.CHARACTER,     \
		MapObject.Type.BRONZE_AXE,   MapObject.Type.BRONZE_PICK,   \
		MapObject.Type.BRONZE_HOE,   MapObject.Type.BRONZE_SICKLE, \
		MapObject.Type.BRONZE_SPADE, MapObject.Type.COPPER_SICKLE, \
		MapObject.Type.BOOK,         MapObject.Type.FISHING_ROD,   \
		MapObject.Type.ALMANAC,      MapObject.Type.LINEN_BACKPACK, \
		MapObject.Type.SMALL_WILLOW_CHEST, MapObject.Type.POT,     \
		MapObject.Type.POTION:
			return 30
		MapObject.Type.SILVER_BAR,   MapObject.Type.BIOME_MAP,     \
		MapObject.Type.COPPER_RETORT, MapObject.Type.BRONZE_BUCKET_CLAY, \
		MapObject.Type.BRONZE_BUCKET_SAND:
			return 35
		MapObject.Type.FISHING_NET,  MapObject.Type.TINY_BACKPACK, \
		MapObject.Type.SKIS,         MapObject.Type.SAFETY_MAP,    \
		MapObject.Type.GLASS_RETORT, MapObject.Type.AUTOFEEDER,    \
		MapObject.Type.BINOCULARS,   MapObject.Type.ELEMENTAL_JAR_SAP:
			return 40
		MapObject.Type.SHOCK_STEEL_BAR, MapObject.Type.FERROCHROME, \
		MapObject.Type.MAP_DISPLAY:
			return 45
		MapObject.Type.GOLD_BAR,     MapObject.Type.GEM,           \
		MapObject.Type.DRAGONSCALE,  MapObject.Type.IRON_HOE,      \
		MapObject.Type.IRON_SICKLE,  MapObject.Type.IRON_AXE,      \
		MapObject.Type.IRON_PICK,    MapObject.Type.IRON_HAMMER,   \
		MapObject.Type.SADDLE,       MapObject.Type.WILLOW_CHEST:
			return 50
		MapObject.Type.FLASHLIGHT,   MapObject.Type.WATCH,         \
		MapObject.Type.HAMSTER_WHEEL, MapObject.Type.CHARGING_PAD, \
		MapObject.Type.LEAD_ACID_BATTERY:
			return 60
		MapObject.Type.STEEL_PICK,   MapObject.Type.ANVIL:
			return 70
		MapObject.Type.RAFT,         MapObject.Type.ELEMENTAL_JAR_LAVA, \
		MapObject.Type.ELEMENTAL_JAR_WATER:
			return 80
		MapObject.Type.HAMSTER_WHEEL_GENERATOR:
			return 90
		MapObject.Type.CEDAR_BOAT,   MapObject.Type.HOMOPOLAR_GENERATOR, \
		MapObject.Type.BLACKHOLE_BACKPACK:
			return 100
		MapObject.Type.DRAGONTAIL_BOAT:
			return 150
		MapObject.Type.JETPACK:
			return 200
		# Ravenmore equipment.
		MapObject.Type.SCROLL:
			return 15
		MapObject.Type.WOODEN_SWORD:
			return 20
		MapObject.Type.DAGGER:
			return 25
		MapObject.Type.GEM_RED, MapObject.Type.GEM_GREEN, MapObject.Type.GEM_BLUE:
			return 25
		MapObject.Type.BOW:
			return 30
		MapObject.Type.AXE:
			return 30
		MapObject.Type.TOME:
			return 35
		MapObject.Type.HELMET:
			return 40
		MapObject.Type.SHIELD:
			return 40
		MapObject.Type.WAND:
			return 45
		MapObject.Type.SWORD:
			return 50
		MapObject.Type.HEART_AMULET:
			return 75
		MapObject.Type.ARMOR:
			return 60
		# Flare armor — cloth (cheapest).
		MapObject.Type.CLOTH_TUNIC:
			return 15
		MapObject.Type.CLOTH_GLOVES, MapObject.Type.CLOTH_BOOTS:
			return 10
		MapObject.Type.CLOTH_TROUSERS:
			return 12
		# Leather.
		MapObject.Type.LEATHER_HELM:
			return 20
		MapObject.Type.LEATHER_TUNIC:
			return 25
		MapObject.Type.LEATHER_GLOVES, MapObject.Type.LEATHER_BOOTS:
			return 18
		MapObject.Type.LEATHER_TROUSERS:
			return 20
		# Hard leather.
		MapObject.Type.HARD_LEATHER_HELM:
			return 30
		MapObject.Type.HARD_LEATHER_TUNIC:
			return 40
		MapObject.Type.HARD_LEATHER_GLOVES, MapObject.Type.HARD_LEATHER_BOOTS:
			return 28
		MapObject.Type.HARD_LEATHER_TROUSERS:
			return 32
		# Chain.
		MapObject.Type.CHAIN_COIF:
			return 50
		MapObject.Type.CHAIN_MAIL:
			return 70
		MapObject.Type.CHAIN_GLOVES, MapObject.Type.CHAIN_BOOTS:
			return 45
		MapObject.Type.CHAIN_TROUSERS:
			return 55
		# Plate (most expensive).
		MapObject.Type.PLATE_HELM:
			return 80
		MapObject.Type.PLATE_MAIL:
			return 120
		MapObject.Type.PLATE_GAUNTLETS:
			return 70
		MapObject.Type.PLATE_GREAVES:
			return 90
		MapObject.Type.PLATE_BOOTS:
			return 85
		# Kyrise items.
		MapObject.Type.WOOD_ARROW:
			return 2
		MapObject.Type.BONE_ARROW:
			return 4
		MapObject.Type.SILVER_ARROW:
			return 6
		MapObject.Type.RAW_FISH:
			return 3
		MapObject.Type.SWEET:
			return 5
		MapObject.Type.IRON_KEY:
			return 10
		MapObject.Type.GIFT_BOX:
			return 15
		MapObject.Type.METAL_INGOT:
			return 15
		MapObject.Type.PEARL, MapObject.Type.FACETED_GEM:
			return 20
		MapObject.Type.MAGIC_CRYSTAL:
			return 22
		MapObject.Type.IRON_RING, MapObject.Type.GOLD_KEY:
			return 25
		MapObject.Type.IRON_SWORD, MapObject.Type.HUNTING_BOW, MapObject.Type.OPEN_HELMET, \
		MapObject.Type.BUCKLER:
			return 30
		MapObject.Type.APPRENTICE_STAFF, MapObject.Type.SPELLBOOK:
			return 35
		MapObject.Type.BRONZE_NECKLACE, MapObject.Type.SILVER_RING, \
		MapObject.Type.ROUND_SHIELD, MapObject.Type.WAR_BOW:
			return 40
		MapObject.Type.STEEL_SWORD, MapObject.Type.WIZARD_STAFF, MapObject.Type.ARCANE_TOME, \
		MapObject.Type.GREAT_HELM:
			return 55
		MapObject.Type.SILVER_NECKLACE, MapObject.Type.MAGIC_RING, \
		MapObject.Type.KITE_SHIELD, MapObject.Type.ELVEN_BOW:
			return 60
		MapObject.Type.SILVER_SWORD, MapObject.Type.ELDER_STAFF, MapObject.Type.FORBIDDEN_TOME, \
		MapObject.Type.MAGIC_NECKLACE:
			return 80
	return 10
