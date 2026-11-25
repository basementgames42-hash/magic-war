extends Node
# GameData: global state that survives scene changes AND game restarts.
# Registered as an "autoload" — Godot creates one instance at launch,
# accessible from anywhere as `GameData`. Think of it as a global module.

const SAVE_PATH: String = "user://savegame.json"
# Where the save actually goes: SAVE_PATH, unless the game was started with
# `-- --save-file=<path>` (test runs use that so they never touch the real save).
var save_path: String = SAVE_PATH
const BALANCE: Balance = preload("res://config/balance.tres")
# "user://" = a per-user writable folder Godot manages for you.
# On Windows it's under %APPDATA%\Godot\. Never save to res:// —
# that's read-only once the game is exported.

signal run_coins_changed(amount: int)

var coins: int = 0
var run_coins: int = 0   # Gold picked up in the current round only
var pending_coins: float = 0.0  # Greed: gold owed minus paid (<= 0 = paid ahead)
var endless: bool = false       # Mode of the run being started (set by the title screen)
var endless_best: float = 0.0   # Longest endless survival, in seconds (saved)
var level_index: int = 0        # Map of the run being started (index into Levels.MAPS)
var test_map: Dictionary = {}   # A test map from Levels (editor only), overrides level_index; not saved
var levels_unlocked: int = 1    # How many maps can be played; a win adds the next (saved)
var character: String = "warrior"  # Id from Characters.ROSTER (saved)
# Characters the player may pick (saved, shared by both modes). Only ever
# grows: nothing removes an id, and loading merges with what's saved.
var unlocked_characters: Array[String] = []
# Unlocked but not yet celebrated on the hero select screen (saved), so the
# lock-break plays there even if the game was closed in between.
var new_unlocks: Array[String] = []
var active_boost: String = ""   # Ad boost running now: "gold", "xp", "drops" or ""
var shop_from_run: bool = false # Upgrade shop opened from the game-over screen (Back = carry on)
var shop_back_text: String = "Play Again"  # What the shop's Back says then ("Next Level" after a win)
var map_to_celebrate: int = -1  # Map just unlocked, whose padlock breaks on map select (saved)
var upgrade_spent: int = 0      # Coins actually paid for upgrades so far: Reset refunds this (saved)
var show_damage_numbers: bool = false  # Settings menu toggle (saved), both modes

# --- Shop (see res://config/shop_catalog.gd) ---
signal gems_changed(amount: int)
signal quest_completed(text: String)
var gems: int = 0                     # The rarer currency (saved)
var stock: Dictionary = {}            # Consumables kept until used, id -> count (saved)
var armed: Array[String] = []         # Next-run consumables bought and waiting (saved)
var run_effects: Array[String] = []   # Next-run consumables working in this run
var premium: Array[String] = []       # Premium upgrades owned (saved)
var free_revive: bool = false         # Phoenix Feather's revive, still unused this run

# --- Daily Quests ---
var quest_day: String = ""            # Date the quests below are for (saved)
var quests: Array = []                # [{kind, tier, goal, progress, claimed}] (saved)
var quest_bonus_claimed: bool = false # All-three bonus taken today (saved)

# Meta upgrade levels the player has purchased. Keys must match
# the shop and player code.
var meta_upgrades: Dictionary = {
	"max_hp": 0,       # Max HP (BALANCE.vitality_per_level a level)
	"damage": 0,       # Weapon damage (BALANCE.power_per_level a level)
	"move_speed": 0,   # Move speed (BALANCE.agility_per_level a level)
	"coin_gain": 0,    # Gold per coin (BALANCE.greed_per_level a level)
	# "Luck" upgrades: each replaces a maxed upgrade above and raises one
	# pickup's drop chance per level (amounts in res://config/balance.tres).
	"potion_drop": 0,      # Health potions; unlocks when max_hp is maxed
	"nuke_drop": 0,        # Nukes; unlocks when damage is maxed
	"invincible_drop": 0,  # Super Mode (invincibility); unlocks when move_speed is maxed
	"magnet_drop": 0,      # Magnets; unlocks when coin_gain is maxed
	# Third tier: each unlocks when the Luck upgrade above it is maxed.
	"regen": 0,         # HP regeneration; after potion_drop
	"fire_rate": 0,     # Faster fireballs; after nuke_drop
	"dodge": 0,         # Chance to dodge a hit; after invincible_drop
	"pickup_range": 0,  # Coins/XP fly in from farther; after magnet_drop
}

# No upgrade goes past this level. The shop swaps a maxed upgrade for its
# replacement, if it has one.
const MAX_UPGRADE_LEVEL: int = 10

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-file="):
			save_path = arg.trim_prefix("--save-file=")
	for entry in Characters.ROSTER:
		if not entry.has("unlock"):
			unlocked_characters.append(entry["id"])  # Starters
	load_game()

func is_character_unlocked(id: String) -> bool:
	return id in unlocked_characters

func check_endless_unlocks(level: int, seconds: float) -> Array[String]:
	# Called during Endless matches. Unlocks (and saves at once) every
	# character whose milestone this match has reached; returns the new ones.
	var fresh: Array[String] = []
	for entry in Characters.ROSTER:
		var id: String = entry["id"]
		if not is_character_unlocked(id) and Characters.milestone_reached(entry, level, seconds):
			unlocked_characters.append(id)
			new_unlocks.append(id)
			fresh.append(id)
	if not fresh.is_empty():
		save_game()
	return fresh

func start_run() -> void:
	run_coins = 0
	pending_coins = 0.0
	active_boost = ""
	# Next-run consumables go to work now and are used up.
	run_effects = armed.duplicate()
	armed.clear()
	free_revive = has_premium("phoenix")
	quest_add("runs", 1)
	save_game()
	run_coins_changed.emit(run_coins)

func boost_factor(id: String) -> float:
	return BALANCE.boost_multiplier if active_boost == id else 1.0

# Everything that multiplies gold / EXP / damage outside the meta upgrades:
# the ad boost, this run's consumables and premium upgrades.
func gold_factor() -> float:
	var f: float = boost_factor("gold")
	if "charm" in run_effects:
		f *= ShopCatalog.CHARM_GOLD
	if has_premium("treasury"):
		f *= ShopCatalog.TREASURY_GOLD
	return f

func xp_factor() -> float:
	var f: float = boost_factor("xp")
	if "tome" in run_effects:
		f *= ShopCatalog.TOME_XP
	if has_premium("insight"):
		f *= ShopCatalog.INSIGHT_XP
	return f

func damage_factor() -> float:
	return ShopCatalog.ELIXIR_DAMAGE if "elixir" in run_effects else 1.0

func bonus_max_hp() -> int:
	return ShopCatalog.TITAN_HP if has_premium("titan") else 0

# --- Shop ---------------------------------------------------------------------

func add_gems(amount: int) -> void:
	gems += amount
	save_game()
	gems_changed.emit(gems)

func has_premium(id: String) -> bool:
	return id in premium

func stock_count(id: String) -> int:
	return int(stock.get(id, 0))

func is_armed(id: String) -> bool:
	return id in armed

func can_buy_consumable(id: String) -> bool:
	var item: Dictionary = ShopCatalog.consumable(id)
	if item.is_empty() or coins < item["cost"]:
		return false
	if item["kind"] == "stock":
		return stock_count(id) < item["max"]
	return not is_armed(id)

func buy_consumable(id: String) -> bool:
	if not can_buy_consumable(id):
		return false
	var item: Dictionary = ShopCatalog.consumable(id)
	coins -= item["cost"]
	if item["kind"] == "stock":
		stock[id] = stock_count(id) + 1
	else:
		armed.append(id)
	save_game()
	return true

func buy_premium(id: String) -> bool:
	var item: Dictionary = ShopCatalog.premium(id)
	if item.is_empty() or has_premium(id) or gems < item["cost"]:
		return false
	gems -= item["cost"]
	premium.append(id)
	save_game()
	gems_changed.emit(gems)
	return true

func buy_coin_chest() -> bool:
	var chest: Dictionary = ShopCatalog.COIN_CHEST
	if gems < chest["gems"]:
		return false
	gems -= chest["gems"]
	coins += chest["coins"]
	save_game()
	gems_changed.emit(gems)
	return true

func buy_gem_with_coins() -> bool:
	var ex: Dictionary = ShopCatalog.GEM_EXCHANGE
	if coins < ex["coins"]:
		return false
	coins -= ex["coins"]
	add_gems(ex["gems"])  # Saves
	return true

func add_stock(id: String) -> bool:
	# A free consumable (ad reward). False if already holding the most.
	var item: Dictionary = ShopCatalog.consumable(id)
	if item.is_empty() or stock_count(id) >= item.get("max", 99):
		return false
	stock[id] = stock_count(id) + 1
	save_game()
	return true

func second_chances() -> int:
	# Revives that need no ad: Phoenix Feather's free one, then bought ones.
	return stock_count("second_chance") + (1 if free_revive else 0)

func use_second_chance() -> bool:
	if free_revive:
		free_revive = false
		return true
	if stock_count("second_chance") > 0:
		stock["second_chance"] = stock_count("second_chance") - 1
		save_game()
		return true
	return false

# --- Daily Quests ---------------------------------------------------------------

static func today() -> String:
	return Time.get_date_string_from_system()

func refresh_quests() -> void:
	# New quests when the day changes; the same three all day.
	if quest_day == today() and quests.size() == ShopCatalog.QUESTS_PER_DAY:
		return
	quest_day = today()
	quest_bonus_claimed = false
	quests.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(quest_day)
	var pool: Array = ShopCatalog.QUESTS.duplicate()
	for i in ShopCatalog.QUESTS_PER_DAY:
		var def: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var tier: int = rng.randi_range(0, 2)
		quests.append({"kind": def["kind"], "tier": tier, "goal": def["goals"][tier],
			"progress": 0, "claimed": false})
	save_game()

static func quest_text(q: Dictionary) -> String:
	return ShopCatalog.quest_def(q["kind"])["text"] % q["goal"]

static func quest_reward(q: Dictionary) -> Array:
	return ShopCatalog.REWARDS[q["tier"]]

static func quest_done(q: Dictionary) -> bool:
	return q["progress"] >= q["goal"]

func quest_add(kind: String, amount: int) -> void:
	# Adds to a quest that counts up over the day. Not saved on every call
	# (kills happen constantly); runs save when they end.
	refresh_quests()
	for q in quests:
		if q["kind"] == kind and not quest_done(q):
			q["progress"] = mini(q["progress"] + amount, q["goal"])
			if quest_done(q):
				quest_completed.emit(quest_text(q))

func quest_best(kind: String, value: int) -> void:
	# For quests that count the best single run (level, Endless minutes).
	refresh_quests()
	for q in quests:
		if q["kind"] == kind and not quest_done(q) and value > q["progress"]:
			q["progress"] = mini(value, q["goal"])
			if quest_done(q):
				quest_completed.emit(quest_text(q))

func claimable_quests() -> int:
	refresh_quests()
	var n: int = 0
	for q in quests:
		if quest_done(q) and not q["claimed"]:
			n += 1
	if all_quests_claimed() and not quest_bonus_claimed:
		n += 1
	return n

func all_quests_claimed() -> bool:
	return quests.all(func(q): return q["claimed"])

func claim_quest(index: int) -> bool:
	var q: Dictionary = quests[index]
	if q["claimed"] or not quest_done(q):
		return false
	q["claimed"] = true
	var reward: Array = quest_reward(q)
	coins += reward[0]
	add_gems(reward[1])  # Saves
	return true

func claim_quest_bonus() -> bool:
	if quest_bonus_claimed or not all_quests_claimed():
		return false
	quest_bonus_claimed = true
	add_gems(ShopCatalog.ALL_DONE_GEMS)
	return true

func is_level_unlocked(index: int) -> bool:
	return index < levels_unlocked

func complete_level(index: int) -> void:
	# Winning a map opens the one after it. Replaying an old map changes nothing.
	levels_unlocked = clampi(maxi(levels_unlocked, index + 2), 1, Levels.MAPS.size())

func add_coins(amount: int) -> void:
	# coin_gain (Greed) meta upgrade: every coin picked up is worth
	# BALANCE.greed_per_level more per level. Coins are 1 gold each, so round
	# UP and carry the overpayment as credit until the total reaches the next
	# whole number (at +25%: 2, 1, 1, 1, then repeat = 5 gold per 4 coins).
	# The bonus shows on the first coin, and the total still comes out exact.
	pending_coins += amount * (1.0 + BALANCE.greed_per_level * meta_upgrades["coin_gain"]) \
		* gold_factor()
	var gained: int = maxi(ceili(pending_coins - 0.0001), 0)  # 0.0001: float slop
	pending_coins -= gained
	coins += gained
	run_coins += gained
	if gained > 0:
		quest_add("gold", gained)
	run_coins_changed.emit(run_coins)

# The Luck upgrades (second tier) and the third tier cost more than the
# four the shop starts with.
const TIER_2: Array[String] = ["potion_drop", "nuke_drop", "invincible_drop", "magnet_drop"]
const TIER_3: Array[String] = ["regen", "fire_rate", "dodge", "pickup_range"]

func get_upgrade_cost(id: String) -> int:
	# Escalating prices: level 0->1 costs the base, 1->2 twice it, and so on
	# (30, 60, 90 ... 300 with the default base), times the tier's multiplier.
	var tier: float = 1.0
	if id in TIER_3:
		tier = BALANCE.upgrade_tier3_cost
	elif id in TIER_2:
		tier = BALANCE.upgrade_tier2_cost
	return roundi(BALANCE.upgrade_base_cost * (meta_upgrades[id] + 1) * tier)

func is_maxed(id: String) -> bool:
	return meta_upgrades[id] >= MAX_UPGRADE_LEVEL

func try_purchase(id: String) -> bool:
	var cost: int = get_upgrade_cost(id)
	if coins < cost or is_maxed(id):
		return false
	coins -= cost
	upgrade_spent += cost
	meta_upgrades[id] += 1
	save_game()
	return true

func spent_on_upgrades() -> int:
	# What was really paid, so Reset Upgrades refunds exactly that, whatever
	# the prices are now.
	return upgrade_spent

static func old_price_total(levels: Dictionary) -> int:
	# Saves from before purchases were tracked: everything was bought at the
	# old prices (10, 20, ... 10L), which come to 5 * L * (L + 1) per upgrade.
	var total: int = 0
	for id in levels:
		var level: int = levels[id]
		total += 5 * level * (level + 1)
	return total

func reset_upgrades() -> int:
	# Title screen's Reset Upgrades: every upgrade back to 0, every coin spent
	# on them refunded. Returns the refund.
	var refund: int = spent_on_upgrades()
	coins += refund
	upgrade_spent = 0
	for id in meta_upgrades:
		meta_upgrades[id] = 0
	save_game()
	return refund

func save_game() -> void:
	var data: Dictionary = {
		"coins": coins,
		"meta_upgrades": meta_upgrades,
		"endless_best": endless_best,
		"levels_unlocked": levels_unlocked,
		"character": character,
		"unlocked_characters": unlocked_characters,
		"new_unlocks": new_unlocks,
		"show_damage_numbers": show_damage_numbers,
		"map_to_celebrate": map_to_celebrate,
		"upgrade_spent": upgrade_spent,
		"gems": gems,
		"stock": stock,
		"armed": armed,
		"premium": premium,
		"quest_day": quest_day,
		"quests": quests,
		"quest_bonus_claimed": quest_bonus_claimed,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	# File closes automatically when `file` goes out of scope.

func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return  # First launch — keep defaults.
	var file := FileAccess.open(save_path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if data == null:
		return  # Corrupted file — keep defaults rather than crash.
	coins = int(data.get("coins", 0))
	endless_best = float(data.get("endless_best", 0.0))
	show_damage_numbers = bool(data.get("show_damage_numbers", false))
	map_to_celebrate = int(data.get("map_to_celebrate", -1))
	levels_unlocked = clampi(int(data.get("levels_unlocked", 1)), 1, Levels.MAPS.size())
	# Add saved unlocks to the starters; never drop one that's already there.
	for id in data.get("unlocked_characters", []):
		if not is_character_unlocked(str(id)) and Characters.by_id(str(id))["id"] == str(id):
			unlocked_characters.append(str(id))
	for id in data.get("new_unlocks", []):
		if is_character_unlocked(str(id)) and not str(id) in new_unlocks:
			new_unlocks.append(str(id))
	character = Characters.by_id(str(data.get("character", "warrior")))["id"]
	if not is_character_unlocked(character):
		character = "warrior"  # A save from before unlocks existed
	# Merge saved levels into defaults (safe if we add new upgrades later).
	var saved: Dictionary = data.get("meta_upgrades", {})
	for key in meta_upgrades.keys():
		if saved.has(key):
			meta_upgrades[key] = mini(int(saved[key]), MAX_UPGRADE_LEVEL)
	upgrade_spent = int(data.get("upgrade_spent", old_price_total(meta_upgrades)))
	gems = int(data.get("gems", 0))
	var saved_stock: Dictionary = data.get("stock", {})
	for id in saved_stock:
		if not ShopCatalog.consumable(str(id)).is_empty():
			stock[str(id)] = int(saved_stock[id])
	for id in data.get("armed", []):
		if not ShopCatalog.consumable(str(id)).is_empty() and not str(id) in armed:
			armed.append(str(id))
	for id in data.get("premium", []):
		if not ShopCatalog.premium(str(id)).is_empty() and not str(id) in premium:
			premium.append(str(id))
	quest_day = str(data.get("quest_day", ""))
	quest_bonus_claimed = bool(data.get("quest_bonus_claimed", false))
	quests.clear()
	for q in data.get("quests", []):
		if q is Dictionary and not ShopCatalog.quest_def(str(q.get("kind", ""))).is_empty():
			quests.append({"kind": str(q["kind"]), "tier": clampi(int(q.get("tier", 0)), 0, 2),
				"goal": int(q.get("goal", 1)), "progress": int(q.get("progress", 0)),
				"claimed": bool(q.get("claimed", false))})
