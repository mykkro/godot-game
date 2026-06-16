class_name MapObject

## All object types that can appear on a map cell.
enum Type {
	ROCK          = 0,   ## Impassable obstacle.
	HERB          = 1,   ## Pickable herb.
	CRYSTAL       = 2,   ## Pickable crystal.
	COIN          = 3,   ## Pickable coin/ring.
	FEATHER       = 4,   ## Pickable feather.
	POTION        = 5,   ## Pickable potion.
	CHEST_SMALL   = 6,   ## Impassable interactable chest.
	## Materials — from nails.png atlas (32×32 grid).
	NAILS         = 7,
	WOOD_PLANK    = 8,
	WOODEN_ROD    = 9,
	CLOTH         = 10,
	COPPER_ORE    = 11,
	IRON_ORE      = 12,
	SILVER_NUGGET = 13,
	GOLD_NUGGET   = 14,
	COPPER_BAR    = 15,
	IRON_BAR      = 16,
	SILVER_BAR    = 17,
	GOLD_BAR      = 18,
	DRAGONSCALE   = 19,
	GEM           = 20,
	LEATHER       = 21,
	## Weapons & combat tools — from items2/.
	STONE_AXE              = 22,
	STONE_PICK             = 23,
	BRONZE_AXE             = 24,
	BRONZE_PICK            = 25,
	IRON_AXE               = 26,
	IRON_PICK              = 27,
	IRON_HAMMER            = 28,
	STEEL_PICK             = 29,
	FISHING_ROD            = 30,
	FISHING_NET            = 31,
	## Food — from items2/.
	APPLE         = 32,
	BANANA        = 33,
	BERRY         = 34,
	BLUEBERRY     = 35,
	BLACKBERRY    = 36,
	ORANGE        = 37,
	PEAR          = 38,
	COCONUT       = 39,
	MUSHROOM      = 40,
	TRUFFLE       = 41,
	BREAD_ROLL    = 42,
	SHRIMP        = 43,
	WHEAT         = 44,
	OATS          = 45,
	## Ores & minerals — from items2/.
	CASSITERITE   = 46,
	CHROMITE      = 47,
	CINNABAR      = 48,
	COAL_ORE      = 49,
	GALENA        = 50,
	MOLYBDENITE   = 51,
	QUARTZITE     = 52,
	LODESTONE     = 53,
	GRANITE       = 54,
	STONE         = 55,
	MELANTERITE   = 56,
	CHARACTITE    = 57,
	## Metal bars & alloys — from items2/.
	LEAD_BAR           = 58,
	SHOCK_STEEL_BAR    = 59,
	FERROCHROME        = 60,
	## Metal parts — from items2/.
	COPPER_DISK   = 61,
	COPPER_WIRE   = 62,
	## Glass & chemical bulk materials — from items2/.
	GLASS         = 63,
	GLASS_FIBER   = 64,
	MERCURY       = 65,
	MINIUM        = 66,
	NITER         = 67,
	SPIDER_PLASTIC = 68,
	## Wood logs — from items2/.
	CEDAR_LOG      = 69,
	DRAGONTAIL_LOG = 70,
	RED_PINE_LOG   = 71,
	WILLOW_LOG     = 72,
	## Boats & vehicles — from items2/.
	CEDAR_BOAT      = 73,
	DRAGONTAIL_BOAT = 74,
	RAFT            = 75,
	## Plants & herbs — from items2/.
	SARGASSUM     = 76,
	CARRAGEEN_MOSS = 77,
	FLAX          = 78,
	FRITILLARIA   = 79,
	HEARTROOT     = 80,
	ROSE          = 81,
	SEA_GRAPES    = 82,
	SEASHELL      = 83,
	## Seeds — from items2/.
	FLAX_SEEDS    = 84,
	OAT_SEEDS     = 85,
	ROSE_SEEDS    = 86,
	WHEAT_SEEDS   = 87,
	## Fibers & textiles — from items2/.
	FLAX_STRING   = 88,
	## Alchemy ingredients — from items2/.
	SARGASSUM_POWDER   = 89,
	CHARACTER_POWDER   = 90,
	FRITILLARIA_POWDER = 91,
	ROSE_POWDER        = 92,
	WEAK_STUDYING_DRINK = 93,
	CHARACTER          = 94,
	## Chemical vials — from items2/.
	GLASS_VIAL         = 95,
	VIAL_MERCURY       = 96,
	VIAL_NITRIC_ACID   = 97,
	VIAL_SULPHURIC_ACID = 98,
	VIAL_SLUG_GEL      = 99,
	VIAL_LEAD_DIOXIDE  = 100,
	## Elemental jars — from items2/.
	ELEMENTAL_JAR       = 101,
	ELEMENTAL_JAR_SAP   = 102,
	ELEMENTAL_JAR_LAVA  = 103,
	ELEMENTAL_JAR_WATER = 104,
	## Containers — from items2/.
	BRONZE_BUCKET      = 105,
	BRONZE_BUCKET_CLAY = 106,
	BRONZE_BUCKET_SAND = 107,
	CLAY_POT           = 108,
	POT                = 109,
	COPPER_RETORT      = 110,
	GLASS_RETORT       = 111,
	TIN_CAGE           = 112,
	## Agricultural tools — from items2/.
	BRONZE_HOE    = 113,
	BRONZE_SICKLE = 114,
	BRONZE_SPADE  = 115,
	COPPER_SICKLE = 116,
	IRON_HOE      = 117,
	IRON_SICKLE   = 118,
	WOODEN_HOE    = 119,
	## Extra food — from items2/.
	BLACK_OLIVE   = 120,
	JUICE         = 121,
	OATMEAL_BREAD = 122,
	SMOOTHIE      = 123,
	SOUP          = 124,
	STEW          = 125,
	## Clothing & accessories — from items2/.
	LINEN_BACKPACK    = 126,
	LINEN_SHOES       = 127,
	TINY_BACKPACK     = 128,
	BLACKHOLE_BACKPACK = 129,
	SADDLE            = 130,
	SKIS              = 131,
	## Books & documents — from items2/.
	ALMANAC     = 132,
	BOOK        = 133,
	CALENDAR    = 134,
	RECIPE      = 135,
	BIOME_MAP   = 136,
	MAP_DISPLAY = 137,
	SAFETY_MAP  = 138,
	## Devices & technology — from items2/.
	ANVIL                  = 139,
	AUTOFEEDER             = 140,
	BINOCULARS             = 141,
	CAMPFIRE               = 142,
	CHARGING_PAD           = 143,
	FLASHLIGHT             = 144,
	FORGE                  = 145,
	HAMSTER_WHEEL          = 146,
	HAMSTER_WHEEL_GENERATOR = 147,
	HOMOPOLAR_GENERATOR    = 148,
	JETPACK                = 149,
	LEAD_ACID_BATTERY      = 150,
	THERMOMETER            = 151,
	WATCH                  = 152,
	## Miscellaneous — from items2/.
	BADGE              = 153,
	FLAX_LEASH         = 154,
	UPGRADED_FLAX_LEASH = 155,
	MAP_PIN            = 156,
	RECYCLING_STAMP    = 157,
	SIGN               = 158,
	SMALL_WILLOW_CHEST = 159,
	SMOKE_SIGNAL       = 160,
	TICKET             = 161,
	TORCH              = 162,
	WILLOW_CHEST       = 163,
	## Equipment & loot — from ravenmore 128×128 icon pack.
	WOODEN_SWORD  = 164,
	## Armor — from flare 5×5 atlas (row=material, col=slot).
	## Row 0 cloth (col 0 empty), row 1 leather, row 2 hard leather, row 3 chain, row 4 plate.
	CLOTH_TUNIC           = 179,
	CLOTH_GLOVES          = 180,
	CLOTH_TROUSERS        = 181,
	CLOTH_BOOTS           = 182,
	LEATHER_HELM          = 183,
	LEATHER_TUNIC         = 184,
	LEATHER_GLOVES        = 185,
	LEATHER_TROUSERS      = 186,
	LEATHER_BOOTS         = 187,
	HARD_LEATHER_HELM     = 188,
	HARD_LEATHER_TUNIC    = 189,
	HARD_LEATHER_GLOVES   = 190,
	HARD_LEATHER_TROUSERS = 191,
	HARD_LEATHER_BOOTS    = 192,
	CHAIN_COIF            = 193,
	CHAIN_MAIL            = 194,
	CHAIN_GLOVES          = 195,
	CHAIN_TROUSERS        = 196,
	CHAIN_BOOTS           = 197,
	PLATE_HELM            = 198,
	PLATE_MAIL            = 199,
	PLATE_GAUNTLETS       = 200,
	PLATE_GREAVES         = 201,
	PLATE_BOOTS           = 202,
	SWORD         = 165,
	AXE           = 166,
	BOW           = 167,
	DAGGER        = 168,
	WAND          = 169,
	HELMET        = 170,
	ARMOR         = 171,
	SHIELD        = 172,
	SCROLL        = 173,
	TOME          = 174,
	GEM_RED       = 175,
	GEM_GREEN     = 176,
	GEM_BLUE      = 177,
	HEART_AMULET  = 178,
	## Equipment & loot — Kyrise individual PNG icons (media/kyrise/).
	## Swords.
	IRON_SWORD      = 203,
	STEEL_SWORD     = 204,
	SILVER_SWORD    = 205,
	## Bows.
	HUNTING_BOW     = 206,
	WAR_BOW         = 207,
	ELVEN_BOW       = 208,
	## Staves.
	APPRENTICE_STAFF = 209,
	WIZARD_STAFF     = 210,
	ELDER_STAFF      = 211,
	## Arrows (stackable ammo).
	WOOD_ARROW      = 212,
	BONE_ARROW      = 213,
	SILVER_ARROW    = 214,
	## Shields.
	BUCKLER         = 215,
	ROUND_SHIELD    = 216,
	KITE_SHIELD     = 217,
	## Helmets.
	OPEN_HELMET     = 218,
	GREAT_HELM      = 219,
	## Spell books.
	SPELLBOOK        = 220,
	ARCANE_TOME      = 221,
	FORBIDDEN_TOME   = 222,
	## Rings.
	IRON_RING        = 223,
	SILVER_RING      = 224,
	MAGIC_RING       = 225,
	## Necklaces.
	BRONZE_NECKLACE  = 226,
	SILVER_NECKLACE  = 227,
	MAGIC_NECKLACE   = 228,
	## Keys.
	IRON_KEY         = 229,
	GOLD_KEY         = 230,
	## Miscellaneous loot.
	PEARL            = 231,
	METAL_INGOT      = 232,
	RAW_FISH         = 233,
	SWEET            = 234,
	GIFT_BOX         = 235,
	FACETED_GEM      = 236,
	MAGIC_CRYSTAL    = 237,
	## Potions — useable consumables.
	HEALTH_POTION = 238,
	MANA_POTION   = 239,
}

## Returns false when an actor cannot pass through this object type.
static func is_type_passable(obj_type: int) -> bool:
	match obj_type:
		Type.ROCK, Type.CHEST_SMALL, Type.FORGE: return false
	return true

## Placeholder fill color used during debug rendering of non-pickable objects.
static func get_color(obj_type: int) -> Color:
	match obj_type:
		Type.ROCK: return Color(0.50, 0.47, 0.42)
	return Color.WHITE

## Human-readable display name.
static func get_display_name(obj_type: int) -> String:
	match obj_type:
		Type.ROCK:          return "Rock"
		Type.HERB:          return "Herb"
		Type.CRYSTAL:       return "Crystal"
		Type.COIN:          return "Coin"
		Type.FEATHER:       return "Feather"
		Type.POTION:        return "Potion"
		Type.CHEST_SMALL:   return "Chest"
		Type.NAILS:         return "Nails"
		Type.WOOD_PLANK:    return "Wood Plank"
		Type.WOODEN_ROD:    return "Wooden Rod"
		Type.CLOTH:         return "Cloth"
		Type.COPPER_ORE:    return "Copper Ore"
		Type.IRON_ORE:      return "Iron Ore"
		Type.SILVER_NUGGET: return "Silver Nugget"
		Type.GOLD_NUGGET:   return "Gold Nugget"
		Type.COPPER_BAR:    return "Copper Bar"
		Type.IRON_BAR:      return "Iron Bar"
		Type.SILVER_BAR:    return "Silver Bar"
		Type.GOLD_BAR:      return "Gold Bar"
		Type.DRAGONSCALE:   return "Dragonscale"
		Type.GEM:           return "Gem"
		Type.LEATHER:       return "Leather"
		Type.STONE_AXE:     return "Stone Axe"
		Type.STONE_PICK:    return "Stone Pickaxe"
		Type.BRONZE_AXE:    return "Bronze Axe"
		Type.BRONZE_PICK:   return "Bronze Pickaxe"
		Type.IRON_AXE:      return "Iron Axe"
		Type.IRON_PICK:     return "Iron Pickaxe"
		Type.IRON_HAMMER:   return "Iron Hammer"
		Type.STEEL_PICK:    return "Steel Pickaxe"
		Type.FISHING_ROD:   return "Fishing Rod"
		Type.FISHING_NET:   return "Fishing Net"
		Type.APPLE:         return "Apple"
		Type.BANANA:        return "Banana"
		Type.BERRY:         return "Berry"
		Type.BLUEBERRY:     return "Blueberry"
		Type.BLACKBERRY:    return "Blackberry"
		Type.ORANGE:        return "Orange"
		Type.PEAR:          return "Pear"
		Type.COCONUT:       return "Coconut"
		Type.MUSHROOM:      return "Mushroom"
		Type.TRUFFLE:       return "Truffle"
		Type.BREAD_ROLL:    return "Bread Roll"
		Type.SHRIMP:        return "Shrimp"
		Type.WHEAT:         return "Wheat"
		Type.OATS:          return "Oats"
		Type.CASSITERITE:   return "Cassiterite"
		Type.CHROMITE:      return "Chromite"
		Type.CINNABAR:      return "Cinnabar"
		Type.COAL_ORE:      return "Coal Ore"
		Type.GALENA:        return "Galena"
		Type.MOLYBDENITE:   return "Molybdenite"
		Type.QUARTZITE:     return "Quartzite"
		Type.LODESTONE:     return "Lodestone"
		Type.GRANITE:       return "Granite"
		Type.STONE:         return "Stone"
		Type.MELANTERITE:   return "Melanterite"
		Type.CHARACTITE:    return "Charactite"
		Type.LEAD_BAR:           return "Lead Bar"
		Type.SHOCK_STEEL_BAR:    return "Shock Steel Bar"
		Type.FERROCHROME:        return "Ferrochrome"
		Type.COPPER_DISK:   return "Copper Disk"
		Type.COPPER_WIRE:   return "Copper Wire"
		Type.GLASS:         return "Glass"
		Type.GLASS_FIBER:   return "Glass Fiber"
		Type.MERCURY:       return "Mercury"
		Type.MINIUM:        return "Minium"
		Type.NITER:         return "Niter"
		Type.SPIDER_PLASTIC: return "Spider Plastic"
		Type.CEDAR_LOG:      return "Cedar Log"
		Type.DRAGONTAIL_LOG: return "Dragontail Log"
		Type.RED_PINE_LOG:   return "Red Pine Log"
		Type.WILLOW_LOG:     return "Willow Log"
		Type.CEDAR_BOAT:      return "Cedar Boat"
		Type.DRAGONTAIL_BOAT: return "Dragontail Boat"
		Type.RAFT:            return "Raft"
		Type.SARGASSUM:      return "Sargassum"
		Type.CARRAGEEN_MOSS: return "Carrageen Moss"
		Type.FLAX:           return "Flax"
		Type.FRITILLARIA:    return "Fritillaria"
		Type.HEARTROOT:      return "Heartroot"
		Type.ROSE:           return "Rose"
		Type.SEA_GRAPES:     return "Sea Grapes"
		Type.SEASHELL:       return "Seashell"
		Type.FLAX_SEEDS:     return "Flax Seeds"
		Type.OAT_SEEDS:      return "Oat Seeds"
		Type.ROSE_SEEDS:     return "Rose Seeds"
		Type.WHEAT_SEEDS:    return "Wheat Seeds"
		Type.FLAX_STRING:    return "Flax String"
		Type.SARGASSUM_POWDER:    return "Sargassum Powder"
		Type.CHARACTER_POWDER:    return "Character Powder"
		Type.FRITILLARIA_POWDER:  return "Fritillaria Powder"
		Type.ROSE_POWDER:         return "Rose Powder"
		Type.WEAK_STUDYING_DRINK: return "Weak Studying Drink"
		Type.CHARACTER:           return "Character"
		Type.GLASS_VIAL:          return "Glass Vial"
		Type.VIAL_MERCURY:        return "Vial of Mercury"
		Type.VIAL_NITRIC_ACID:    return "Vial of Nitric Acid"
		Type.VIAL_SULPHURIC_ACID: return "Vial of Sulphuric Acid"
		Type.VIAL_SLUG_GEL:       return "Vial of Slug Gel"
		Type.VIAL_LEAD_DIOXIDE:   return "Vial of Lead Dioxide"
		Type.ELEMENTAL_JAR:       return "Elemental Jar"
		Type.ELEMENTAL_JAR_SAP:   return "Elemental Jar (Ancient Sap)"
		Type.ELEMENTAL_JAR_LAVA:  return "Elemental Jar (Lava Residue)"
		Type.ELEMENTAL_JAR_WATER: return "Elemental Jar (Twisting Water)"
		Type.BRONZE_BUCKET:      return "Bronze Bucket"
		Type.BRONZE_BUCKET_CLAY: return "Bronze Bucket (Clay)"
		Type.BRONZE_BUCKET_SAND: return "Bronze Bucket (Sand)"
		Type.CLAY_POT:           return "Clay Pot"
		Type.POT:                return "Pot"
		Type.COPPER_RETORT:      return "Copper Retort"
		Type.GLASS_RETORT:       return "Glass Retort"
		Type.TIN_CAGE:           return "Tin Cage"
		Type.BRONZE_HOE:    return "Bronze Hoe"
		Type.BRONZE_SICKLE: return "Bronze Sickle"
		Type.BRONZE_SPADE:  return "Bronze Spade"
		Type.COPPER_SICKLE: return "Copper Sickle"
		Type.IRON_HOE:      return "Iron Hoe"
		Type.IRON_SICKLE:   return "Iron Sickle"
		Type.WOODEN_HOE:    return "Wooden Hoe"
		Type.BLACK_OLIVE:   return "Black Olive"
		Type.JUICE:         return "Juice"
		Type.OATMEAL_BREAD: return "Oatmeal Bread"
		Type.SMOOTHIE:      return "Smoothie"
		Type.SOUP:          return "Soup"
		Type.STEW:          return "Stew"
		Type.LINEN_BACKPACK:     return "Linen Backpack"
		Type.LINEN_SHOES:        return "Linen Shoes"
		Type.TINY_BACKPACK:      return "Tiny Backpack"
		Type.BLACKHOLE_BACKPACK: return "Blackhole Backpack"
		Type.SADDLE:             return "Saddle"
		Type.SKIS:               return "Skis"
		Type.ALMANAC:     return "Almanac"
		Type.BOOK:        return "Book"
		Type.CALENDAR:    return "Calendar"
		Type.RECIPE:      return "Recipe"
		Type.BIOME_MAP:   return "Biome Map"
		Type.MAP_DISPLAY: return "Map Display"
		Type.SAFETY_MAP:  return "Safety Map"
		Type.ANVIL:                   return "Anvil"
		Type.AUTOFEEDER:              return "Autofeeder"
		Type.BINOCULARS:              return "Binoculars"
		Type.CAMPFIRE:                return "Campfire"
		Type.CHARGING_PAD:            return "Charging Pad"
		Type.FLASHLIGHT:              return "Flashlight"
		Type.FORGE:                   return "Forge"
		Type.HAMSTER_WHEEL:           return "Hamster Wheel"
		Type.HAMSTER_WHEEL_GENERATOR: return "Hamster Wheel Generator"
		Type.HOMOPOLAR_GENERATOR:     return "Homopolar Generator"
		Type.JETPACK:                 return "Jetpack"
		Type.LEAD_ACID_BATTERY:       return "Lead Acid Battery"
		Type.THERMOMETER:             return "Thermometer"
		Type.WATCH:                   return "Watch"
		Type.BADGE:               return "Badge"
		Type.FLAX_LEASH:          return "Flax Leash"
		Type.UPGRADED_FLAX_LEASH: return "Upgraded Flax Leash"
		Type.MAP_PIN:             return "Map Pin"
		Type.RECYCLING_STAMP:     return "Recycling Stamp"
		Type.SIGN:                return "Sign"
		Type.SMALL_WILLOW_CHEST:  return "Small Willow Chest"
		Type.SMOKE_SIGNAL:        return "Smoke Signal"
		Type.TICKET:              return "Ticket"
		Type.TORCH:               return "Torch"
		Type.WILLOW_CHEST:        return "Willow Chest"
		Type.WOODEN_SWORD:        return "Wooden Sword"
		Type.SWORD:               return "Sword"
		Type.AXE:                 return "Axe"
		Type.BOW:                 return "Bow"
		Type.DAGGER:              return "Dagger"
		Type.WAND:                return "Wand"
		Type.HELMET:              return "Helmet"
		Type.ARMOR:               return "Armor"
		Type.SHIELD:              return "Shield"
		Type.SCROLL:              return "Scroll"
		Type.TOME:                return "Tome"
		Type.GEM_RED:             return "Red Gem"
		Type.GEM_GREEN:           return "Green Gem"
		Type.GEM_BLUE:            return "Blue Gem"
		Type.HEART_AMULET:        return "Heart Amulet"
		Type.CLOTH_TUNIC:           return "Cloth Tunic"
		Type.CLOTH_GLOVES:          return "Cloth Gloves"
		Type.CLOTH_TROUSERS:        return "Cloth Trousers"
		Type.CLOTH_BOOTS:           return "Cloth Boots"
		Type.LEATHER_HELM:          return "Leather Helm"
		Type.LEATHER_TUNIC:         return "Leather Tunic"
		Type.LEATHER_GLOVES:        return "Leather Gloves"
		Type.LEATHER_TROUSERS:      return "Leather Trousers"
		Type.LEATHER_BOOTS:         return "Leather Boots"
		Type.HARD_LEATHER_HELM:     return "Hard Leather Helm"
		Type.HARD_LEATHER_TUNIC:    return "Hard Leather Tunic"
		Type.HARD_LEATHER_GLOVES:   return "Hard Leather Gloves"
		Type.HARD_LEATHER_TROUSERS: return "Hard Leather Trousers"
		Type.HARD_LEATHER_BOOTS:    return "Hard Leather Boots"
		Type.CHAIN_COIF:            return "Chain Coif"
		Type.CHAIN_MAIL:            return "Chain Mail"
		Type.CHAIN_GLOVES:          return "Chain Gloves"
		Type.CHAIN_TROUSERS:        return "Chain Trousers"
		Type.CHAIN_BOOTS:           return "Chain Boots"
		Type.PLATE_HELM:            return "Plate Helm"
		Type.PLATE_MAIL:            return "Plate Mail"
		Type.PLATE_GAUNTLETS:       return "Plate Gauntlets"
		Type.PLATE_GREAVES:         return "Plate Greaves"
		Type.PLATE_BOOTS:           return "Plate Boots"
		Type.IRON_SWORD:            return "Iron Sword"
		Type.STEEL_SWORD:           return "Steel Sword"
		Type.SILVER_SWORD:          return "Silver Sword"
		Type.HUNTING_BOW:           return "Hunting Bow"
		Type.WAR_BOW:               return "War Bow"
		Type.ELVEN_BOW:             return "Elven Bow"
		Type.APPRENTICE_STAFF:      return "Apprentice Staff"
		Type.WIZARD_STAFF:          return "Wizard Staff"
		Type.ELDER_STAFF:           return "Elder Staff"
		Type.WOOD_ARROW:            return "Wood Arrow"
		Type.BONE_ARROW:            return "Bone Arrow"
		Type.SILVER_ARROW:          return "Silver Arrow"
		Type.BUCKLER:               return "Buckler"
		Type.ROUND_SHIELD:          return "Round Shield"
		Type.KITE_SHIELD:           return "Kite Shield"
		Type.OPEN_HELMET:           return "Open Helmet"
		Type.GREAT_HELM:            return "Great Helm"
		Type.SPELLBOOK:             return "Spellbook"
		Type.ARCANE_TOME:           return "Arcane Tome"
		Type.FORBIDDEN_TOME:        return "Forbidden Tome"
		Type.IRON_RING:             return "Iron Ring"
		Type.SILVER_RING:           return "Silver Ring"
		Type.MAGIC_RING:            return "Magic Ring"
		Type.BRONZE_NECKLACE:       return "Bronze Necklace"
		Type.SILVER_NECKLACE:       return "Silver Necklace"
		Type.MAGIC_NECKLACE:        return "Magic Necklace"
		Type.IRON_KEY:              return "Iron Key"
		Type.GOLD_KEY:              return "Gold Key"
		Type.PEARL:                 return "Pearl"
		Type.METAL_INGOT:           return "Metal Ingot"
		Type.RAW_FISH:              return "Raw Fish"
		Type.SWEET:                 return "Sweet"
		Type.GIFT_BOX:              return "Gift Box"
		Type.FACETED_GEM:           return "Faceted Gem"
		Type.MAGIC_CRYSTAL:         return "Magic Crystal"
		Type.HEALTH_POTION:         return "Health Potion"
		Type.MANA_POTION:           return "Mana Potion"
	return "Unknown"
