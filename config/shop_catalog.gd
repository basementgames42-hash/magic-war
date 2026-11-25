class_name ShopCatalog
# Everything the Shop sells and every Daily Quest, in one table each, so prices
# and rewards can be tuned here without touching the screens.
#
# Two currencies:
#   - Coins: earned in every run (the Upgrades shop uses them too).
#   - Gems: the rarer one. Earned from Daily Quests (no purchase needed),
#     or bought in packs through the Store (real money, optional).
# Gems can always be turned into coins, never the other way round.

# Consumables, bought with coins. "kind":
#   "stock"    - kept until used (Second Chance: used when you die)
#   "next_run" - armed for your next run only, one at a time
const CONSUMABLES: Array[Dictionary] = [
	{"id": "second_chance", "icon": "potion_round_gold", "name": "Second Chance", "kind": "stock", "cost": 250, "max": 5,
		"desc": "Revive where you fell. No ad needed."},
	{"id": "elixir", "icon": "potion_flask_amber", "name": "Battle Elixir", "kind": "next_run", "cost": 120,
		"desc": "+25% damage for your next run."},
	{"id": "charm", "icon": "clover", "name": "Lucky Charm", "kind": "next_run", "cost": 100,
		"desc": "+50% gold for your next run."},
	{"id": "tome", "icon": "book_blue", "name": "Wisdom Tome", "kind": "next_run", "cost": 100,
		"desc": "+50% EXP for your next run."},
]

# How strong each next-run consumable is (multipliers).
const ELIXIR_DAMAGE: float = 1.25
const CHARM_GOLD: float = 1.5
const TOME_XP: float = 1.5

# Premium upgrades: bought once with gems, kept forever. Small on purpose,
# so nothing in the game needs them.
const PREMIUM: Array[Dictionary] = [
	{"id": "phoenix", "icon": "feather_phoenix", "name": "Phoenix Feather", "cost": 600,
		"desc": "A free Second Chance every run."},
	{"id": "treasury", "icon": "crown_gold", "name": "Royal Treasury", "cost": 500,
		"desc": "+20% gold from every coin."},
	{"id": "insight", "icon": "crystal_ball", "name": "Sage's Insight", "cost": 500,
		"desc": "+15% EXP in every run."},
	{"id": "titan", "icon": "heart", "name": "Heart of the Titan", "cost": 300,
		"desc": "+25 max HP in every run."},
]
const TREASURY_GOLD: float = 1.2
const INSIGHT_XP: float = 1.15
const TITAN_HP: int = 25

# Gems -> coins.
const COIN_CHEST: Dictionary = {"id": "coin_chest", "icon": "chest_treasure", "name": "Coin Chest", "gems": 50, "coins": 750,
	"desc": "Trade 50 gems for 750 coins."}

# Coins -> gems (the long way round, for players with a big pile of gold).
const GEM_EXCHANGE: Dictionary = {"id": "gem_exchange", "icon": "gem_opal", "name": "Gem Exchange",
	"coins": 20000, "gems": 1, "desc": "Trade 20,000 coins for 1 gem."}

# In-run ad offers: the card under the Level ribbon. Watch an ad, get the
# reward. Only things that cost coins in the Shop (never gem items), plus
# gems themselves. "kind":
#   "boost"  - x2 gold / EXP / drops for BALANCE.boost_seconds
#   "stock"  - a free Shop consumable kept until used (Second Chance)
#   "effect" - a Shop boost working for the rest of THIS run
#   "gems"   - gems, for watching "ads" ads back to back
const AD_OFFERS: Array[Dictionary] = [
	{"id": "gold", "kind": "boost", "icon": "coin_stack", "title": "Double Gold", "detail": "x2 gold for %ds"},
	{"id": "xp", "kind": "boost", "icon": "potion_bottle_green", "title": "Double EXP", "detail": "x2 EXP for %ds"},
	{"id": "drops", "kind": "boost", "icon": "chest_wood", "title": "Double Drops", "detail": "x2 item drops for %ds"},
	{"id": "second_chance", "kind": "stock", "icon": "potion_round_gold", "title": "Free Second Chance", "detail": "Revive once, no ad needed"},
	{"id": "elixir", "kind": "effect", "icon": "potion_flask_amber", "title": "Free Battle Elixir", "detail": "+25% damage this run"},
	{"id": "charm", "kind": "effect", "icon": "clover", "title": "Free Lucky Charm", "detail": "+50% gold this run"},
	{"id": "tome", "kind": "effect", "icon": "book_blue", "title": "Free Wisdom Tome", "detail": "+50% EXP this run"},
	{"id": "gems", "kind": "gems", "icon": "diamond", "title": "+%d Gems", "detail": "Watch %d short ads", "gems": 10, "ads": 2},
]
const GEM_OFFERS_PER_RUN: int = 2  # The gem offer comes up at most this often in one run

# Gem packs, sold for real money through the Store autoload.
const GEM_PACKS: Array[Dictionary] = [
	{"id": "gems_100", "icon": "diamond", "name": "Pouch of Gems", "gems": 100, "price": "$0.99"},
	{"id": "gems_550", "icon": "crystal_cluster", "name": "Sack of Gems", "gems": 550, "price": "$4.99", "tag": "+10% bonus"},
	{"id": "gems_1200", "icon": "crystal_rainbow", "name": "Chest of Gems", "gems": 1200, "price": "$9.99", "tag": "+20% bonus"},
]

const ICON_DIR := "res://scenes/assets/Items Pack/items/"
const GEM_ICON := "diamond"

static func consumable(id: String) -> Dictionary:
	for item in CONSUMABLES:
		if item["id"] == id:
			return item
	return {}

static func premium(id: String) -> Dictionary:
	for item in PREMIUM:
		if item["id"] == id:
			return item
	return {}

static func gem_pack(id: String) -> Dictionary:
	for item in GEM_PACKS:
		if item["id"] == id:
			return item
	return {}

# --- Daily Quests ------------------------------------------------------------
# Three a day, each of a different kind, picked from this pool by the date (so
# they're the same all day and change at midnight). "goals" are the possible
# targets: easy, medium, hard, with matching rewards in REWARDS. "best" quests
# count the best single run; the rest add up over the day.
const QUESTS: Array[Dictionary] = [
	{"kind": "kill", "text": "Defeat %d enemies", "goals": [150, 300, 500]},
	{"kind": "elite", "text": "Defeat %d elites", "goals": [2, 4, 6]},
	{"kind": "gold", "text": "Collect %d gold", "goals": [100, 200, 350]},
	{"kind": "endless_minutes", "text": "Survive %d minutes in one Endless run", "goals": [5, 8, 12], "best": true},
	{"kind": "level", "text": "Reach level %d in one run", "goals": [10, 15, 20], "best": true},
	{"kind": "win", "text": "Win %d map(s)", "goals": [1, 2, 3]},
	{"kind": "runs", "text": "Play %d runs", "goals": [2, 3, 5]},
]
# [coins, gems] for an easy, medium and hard quest.
const REWARDS: Array = [[80, 5], [150, 10], [250, 15]]
# Extra gems for finishing all three in a day.
const ALL_DONE_GEMS: int = 20
const QUESTS_PER_DAY: int = 3

static func quest_def(kind: String) -> Dictionary:
	for q in QUESTS:
		if q["kind"] == kind:
			return q
	return {}
