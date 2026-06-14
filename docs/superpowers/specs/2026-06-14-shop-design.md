# Shop Feature Design
**Date:** 2026-06-14

## Overview

Every melee NPC (`NpcMelee`) gains a **Shop** dialog option. Clicking it opens a two-panel trade window. The player can **buy** NPC goods (drag NPC items to player panel, pay with coins dragged to NPC panel) or **sell** items (drag player items to NPC panel; on Trade the NPC auto-pays from its coin pool). Coins are the only currency — no item-for-item barter. Each NPC starts with 1 000 coins; if the NPC owes more than it holds, the shortfall is forfeit.

---

## Architecture

### New / changed files

| File | Change |
|---|---|
| `scripts/ui/shop_ui.gd` | New — full shop window (CanvasLayer) |
| `scripts/objects/pickable_item_def.gd` | Add `get_coin_value(type) -> int` static function |
| `scripts/ui/npc_dialog.gd` | Add `shop_requested(npc)` signal; add "Shop" menu option for all `NpcMelee` |
| `scripts/main.gd` | Instantiate `ShopUI`, connect `npc_dialog.shop_requested` |

### Signal flow

1. Player presses E near `NpcMelee` → `NpcDialog.open(npc)` (unchanged)
2. Player clicks **Shop** → `NpcDialog` emits `shop_requested(npc)` and closes
3. `main.gd` calls `ShopUI.open(avatar.inventory, npc)`
4. `ShopUI` generates stock, clones working arrays, shows window
5. Player drags items; balance updates live
6. **Trade** applies working arrays to real inventory; **Reset** or **ESC** discards

---

## Working-copy model

`ShopUI` never touches the real `Inventory` object until Trade is confirmed.

| Variable | Description |
|---|---|
| `_player_work: Array` | Clone of `avatar.inventory.items` at open time |
| `_shop_work: Array` | NPC's generated stock (fresh every open, never saved) |
| `_player_orig: Array` | Deep-copy snapshot of player items — used by Reset |
| `_shop_orig: Array` | Deep-copy snapshot of shop items — used by Reset |

**Balance formula:**
```
balance = orig_shop_value − current_shop_value
```
Because conservation of value means items only move between the two panels, this equals the net coin-equivalent value the player has taken from the NPC.

- Positive → player still owes; Trade disabled
- Zero or negative → player has paid enough (or NPC owes player); Trade enabled

**On Trade:**
1. If `balance < 0`: NPC auto-pays `min(|balance|, npc_coin_pool)` coins to player (fills existing coin slots first, then creates new ones up to `Inventory.MAX_ITEMS`). Any unpayable remainder is forfeit.
2. Copy `_player_work` back into `avatar.inventory.items`.

**On Reset:** copy `_player_orig` → `_player_work`, `_shop_orig` → `_shop_work`, refresh UI.  
**On ESC / close without Trade:** discard working arrays, real inventory unchanged.

---

## UI Layout

Layer 73 (above `ChestLootUI` at 72, above `InventoryUI` at 70).  
Dark semi-transparent overlay. Centered `HBoxContainer` containing two equal panels.

```
┌─────────────────────────┐   ┌─────────────────────────┐
│  Your Inventory  [Sort] │   │  Aldric's Shop          │
│  12 / 50 items          │   │  5 items                │
│  5×4 grid (20 slots)    │   │  5×4 grid (20 slots)    │
│  shows player items 0…19│   │  shows NPC stock 0…7    │
└─────────────────────────┘   └─────────────────────────┘
         Balance: +12 coins      [ Reset ]  [ Trade ]
```

- **Both grids:** 5 columns × 4 rows = 20 slots, 52 px slot size, 4 px padding — identical widget to `ChestLootUI._make_slot()`
- **Balance label:** red when `balance > 0` ("offer more"); green when `≤ 0`. When NPC owes coins on trade, shows "NPC pays X" and optionally "Y forfeit" if the NPC's coin pool is insufficient.
- **Trade button:** disabled when `balance > 0`; clicking finalises exchange and closes
- **Reset button:** always enabled; restores both panels to their state at open
- **ESC:** closes without trading (same pattern as all other UIs)
- **Sort button** on player panel only — sort + compact player working array

### Drag-and-drop rules

Any item may be dragged in either direction. Coins dragged from player → NPC merge into the NPC's single coin pile (no stack cap on NPC side). When player drags their items to NPC panel, that represents items offered for sale; on Trade the NPC pays for them automatically in coins.

| Tag key | Direction |
|---|---|
| `shop_player_slot` | dragged from player panel |
| `shop_npc_slot` | dragged from NPC panel |

Same-type stackable merging applies (identical logic to `ChestLootUI`). Dragging NPC coins to player side caps at `max_stack_size` (100) per slot.

---

## Item Generation

Called inside `ShopUI.open()`. Stock is **not** persisted — fresh random roll every visit.

**Seed:** `hash(npc.npc_id)` so the same NPC always rolls the same seed (stable within one session; resets on world reload — acceptable).

**Selection:** pick 3–8 unique types at random from the full list of pickable types, excluding `COIN` and the non-pickables already excluded by `PickableItemDef.is_pickable` (ROCK, CHEST_SMALL, FORGE). After selecting items, always append one COIN entry with count 1 000 — this is the NPC's payment reserve.

The full pickable-type list is built once at startup by iterating `MapObject.Type` values filtered through `PickableItemDef.is_pickable()`, cached as a static Array.

**Stack count per item:**

| `max_stack_size` | count rolled |
|---|---|
| 1 | always 1 |
| 4 | `randi_range(1, 3)` |
| 8 | `randi_range(1, 5)` |
| 16 | `randi_range(2, 8)` |
| 64 | `randi_range(3, 20)` |
| 100 | `randi_range(5, 50)` |

---

## Pricing — `PickableItemDef.get_coin_value(type) -> int`

Default fallback: **10 coins**.

| Price | Items |
|---|---|
| 1 | STONE, GRANITE, FEATHER |
| 3 | NAILS, WOOD_PLANK, WOODEN_ROD, CLOTH, COAL_ORE, FLAX_SEEDS, OAT_SEEDS, ROSE_SEEDS, WHEAT_SEEDS |
| 4 | CEDAR_LOG, RED_PINE_LOG, WILLOW_LOG, LEATHER, FLAX, SEA_GRAPES, SEASHELL, APPLE, BERRY, BLUEBERRY, BLACKBERRY, BANANA, ORANGE, PEAR, COCONUT, BLACK_OLIVE, WHEAT, OATS |
| 5 | DRAGONTAIL_LOG, ROSE, SARGASSUM, CARRAGEEN_MOSS, JUICE, TORCH |
| 6 | COPPER_ORE, GLASS, BREAD_ROLL, SHRIMP |
| 8 | IRON_ORE, CASSITERITE, CHROMITE, CINNABAR, GALENA, MOLYBDENITE, QUARTZITE, LODESTONE, MELANTERITE, CHARACTITE, MUSHROOM, FRITILLARIA |
| 10 | COPPER_DISK, COPPER_WIRE, HEARTROOT, MAP_PIN, FLAX_STRING, FLAX_LEASH, BADGE |
| 12 | COPPER_BAR, GLASS_FIBER, MINIUM, NITER, SARGASSUM_POWDER, OATMEAL_BREAD |
| 15 | MERCURY, SPIDER_PLASTIC, CHARACTER_POWDER, FRITILLARIA_POWDER, ROSE_POWDER, VIAL_SLUG_GEL, VIAL_LEAD_DIOXIDE, VIAL_MERCURY, LEAD_BAR, SMOOTHIE, UPGRADED_FLAX_LEASH, RECYCLING_STAMP |
| 18 | IRON_BAR, VIAL_NITRIC_ACID, VIAL_SULPHURIC_ACID |
| 20 | SILVER_NUGGET, GLASS_VIAL, CALENDAR, BRONZE_BUCKET, SOUP, SIGN, WEAK_STUDYING_DRINK, ELEMENTAL_JAR, CAMPFIRE, HERB, STONE_AXE, STONE_PICK, WOODEN_HOE |
| 25 | STEW, TRUFFLE, CRYSTAL, LINEN_SHOES, THERMOMETER, RECIPE, SMOKE_SIGNAL, TICKET, CLAY_POT, TIN_CAGE |
| 30 | GOLD_NUGGET, CHARACTER, BRONZE_AXE, BRONZE_PICK, BRONZE_HOE, BRONZE_SICKLE, BRONZE_SPADE, COPPER_SICKLE, BOOK, FISHING_ROD, ALMANAC, LINEN_BACKPACK, SMALL_WILLOW_CHEST, POT |
| 35 | SILVER_BAR, RECIPE (advanced), BIOME_MAP, COPPER_RETORT, BRONZE_BUCKET_CLAY, BRONZE_BUCKET_SAND |
| 40 | FISHING_NET, TINY_BACKPACK, SKIS, SAFETY_MAP, GLASS_RETORT, AUTOFEEDER, BINOCULARS, ELEMENTAL_JAR_SAP |
| 45 | SHOCK_STEEL_BAR, FERROCHROME, MAP_DISPLAY |
| 50 | GOLD_BAR, GEM, DRAGONSCALE (per scale), IRON_HOE, IRON_SICKLE, IRON_AXE, IRON_PICK, IRON_HAMMER, BOOK (special), SADDLE, WILLOW_CHEST |
| 60 | FLASHLIGHT, WATCH, HAMSTER_WHEEL, CHARGING_PAD, LEAD_ACID_BATTERY |
| 70 | STEEL_PICK, ANVIL |
| 80 | RAFT, ELEMENTAL_JAR_LAVA, ELEMENTAL_JAR_WATER |
| 90 | HAMSTER_WHEEL_GENERATOR |
| 100 | CEDAR_BOAT, HOMOPOLAR_GENERATOR, BLACKHOLE_BACKPACK |
| 150 | DRAGONTAIL_BOAT |
| 200 | JETPACK |

---

## Out of Scope

- Shop inventory persistence between visits (fresh roll every open)
- NPC selling price vs. player buy-back price distinction (no markup/margin)
- Scrolling player inventory panel (20 slots shown; sort/compact to manage)
- Sound effects beyond existing UI sounds

