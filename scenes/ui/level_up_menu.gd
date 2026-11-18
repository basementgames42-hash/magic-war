extends CanvasLayer
# Level-Up Menu: pauses the game, offers 3 random upgrades.
# Spell unlocks are marked "once" and leave the pool after being taken.
# Entries with a "weapon" can be picked again to level that weapon up.
# A run may add at most BALANCE.max_extra_weapons new weapons (spells and
# level-up weapons) to the hero's own. Once that many are taken the rest
# leave the pool for good; upgrades to the ones you have keep coming.

const BALANCE: Balance = preload("res://config/balance.tres")

# Upgrades to the starting weapon, by weapon: damage, fire rate, and speed
# (projectiles) or reach (melee).
const WEAPON_UPGRADES: Dictionary = {
	"fireball": [
		{"name": "Sharper Flames", "desc": "Fireball damage +{dmg}", "id": "damage"},
		{"name": "Rapid Fire", "desc": "Fire {rate}% faster", "id": "fire_rate"},
		{"name": "Blazing Bolts", "desc": "Fireballs fly 30% faster", "id": "projectile_speed"},
	],
	"cleave": [
		{"name": "Honed Edge", "desc": "Cleave damage +{dmg}", "id": "damage"},
		{"name": "Battle Rhythm", "desc": "Cleave {rate}% faster", "id": "fire_rate"},
		{"name": "Wide Swing", "desc": "Cleave reach +15%", "id": "reach"},
	],
	"thrust": [
		{"name": "Tempered Tip", "desc": "Lance damage +{dmg}", "id": "damage"},
		{"name": "Quick Recovery", "desc": "Thrust {rate}% faster", "id": "fire_rate"},
		{"name": "Long Haft", "desc": "Lance reach +15%", "id": "reach"},
	],
	"arrow": [
		{"name": "Barbed Heads", "desc": "Arrow damage +{dmg}", "id": "damage"},
		{"name": "Quick Draw", "desc": "Shoot {rate}% faster", "id": "fire_rate"},
		{"name": "Strong Bow", "desc": "Arrows fly 30% faster", "id": "projectile_speed"},
	],
}

# Entries with a "weapon" level up: they stay in the pool until BALANCE.weapon_max_level.
var upgrade_pool: Array = [
	{"name": "Swift Boots", "desc": "Move speed +15%", "id": "move_speed"},
	{"name": "Keen Eye", "desc": "Critical hit chance +{crit}% (crits deal {mult}x damage)", "id": "crit"},
	{"name": "Lightning Arc", "desc": "NEW SPELL: zaps random enemies", "id": "unlock_lightning", "once": true},
	{"name": "Frost Nova", "desc": "NEW SPELL: icy blast that slows", "id": "unlock_frost", "once": true},
	{"name": "Arcane Orbit", "desc": "NEW SPELL: orbs circle you", "id": "unlock_orbit", "once": true},
	{"name": "Runeward Circle", "desc": "NEW WEAPON: enemies inside the ring take damage",
		"more": "larger ring, more damage", "weapon": "runeward"},
	{"name": "Starfall", "desc": "NEW WEAPON: stars crash down on enemies",
		"more": "bigger blasts, more damage", "weapon": "starfall"},
	{"name": "Moonreaver", "desc": "NEW WEAPON: a blade that flies out and returns",
		"more": "more damage, extra blades", "weapon": "moonreaver"},
	{"name": "Thornwake", "desc": "NEW WEAPON: brambles grow along your path",
		"more": "bigger, longer, sharper", "weapon": "thornwake"},
]

var current_choices: Array = []
# What was picked this round, for the game-over recap.
var spells_taken: Array[String] = []        # Spell names, in unlock order
var upgrades_taken: Dictionary = {}         # Upgrade name -> times picked
var weapon_ids: Dictionary = {}             # Levelled weapon name -> its id
var extra_weapons: int = 0                  # New weapons taken this run (spells + level-up weapons)
var buttons: Array = []
var player: Node = null

func _ready() -> void:
	visible = false
	player = get_tree().get_first_node_in_group("player")
	upgrade_pool.append_array(WEAPON_UPGRADES[player.character["weapon"]])
	buttons = [%Option1, %Option2, %Option3]
	for i in 3:
		buttons[i].pressed.connect(_on_option_pressed.bind(i))

func open() -> void:
	# Always three choices, drawn only from what the player can still take.
	current_choices = upgrade_pool.filter(eligible)
	current_choices.shuffle()
	current_choices = current_choices.slice(0, 3)

	for i in 3:
		buttons[i].text = current_choices[i]["name"] + "\n" + describe(current_choices[i])
		# Long descriptions wrap on a phone rather than pushing off the screen.
		buttons[i].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART \
			if WindowControls.is_narrow() else TextServer.AUTOWRAP_OFF

	visible = true
	get_tree().paused = true
	Audio.play("level_up", -3.0, 0.0)

func is_new_weapon(choice: Dictionary) -> bool:
	# A spell unlock, or a level-up weapon the player doesn't have yet.
	if choice.get("once", false):
		return true
	return choice.has("weapon") and player.weapon_level(choice["weapon"]) == 0

func eligible(choice: Dictionary) -> bool:
	if is_new_weapon(choice) and extra_weapons >= BALANCE.max_extra_weapons:
		return false
	if choice.get("id", "") == "crit" and player.crit_chance >= BALANCE.crit_max:
		return false
	return true

func describe(choice: Dictionary) -> String:
	if choice.has("weapon"):
		var level: int = player.weapon_level(choice["weapon"])
		if level > 0:
			return "Level %d: %s" % [level + 1, choice["more"]]
	# Starting-weapon upgrades: the real numbers come from balance.tres.
	var text: String = choice["desc"].format({
		"dmg": player.damage_pick(),
		"rate": roundi(BALANCE.fire_rate_pick * 100.0),
		"crit": roundi(BALANCE.crit_chance_per_pick * 100.0),
		"mult": str(BALANCE.crit_multiplier).trim_suffix(".0"),
	})
	if is_new_weapon(choice):
		# Which weapon slot this would fill, e.g. "slot 2 of 3".
		text += "  (slot %d of %d)" % [extra_weapons + 1, BALANCE.max_extra_weapons]
	return text

func took_new_weapon() -> void:
	# One more weapon slot filled. At the limit, every weapon not taken
	# leaves the pool for the rest of the run.
	extra_weapons += 1
	if extra_weapons >= BALANCE.max_extra_weapons:
		upgrade_pool = upgrade_pool.filter(func(c): return not is_new_weapon(c))

func weapon_recap() -> Array[String]:
	# Spells in unlock order, with levels for the weapons that have them.
	var recap: Array[String] = []
	for spell in spells_taken:
		var weapon: String = weapon_ids.get(spell, "")
		recap.append(spell if weapon == "" else "%s  Lv %d" % [spell, player.weapon_level(weapon)])
	return recap

func take_weapon(choice: Dictionary) -> void:
	var weapon: String = choice["weapon"]
	var was_new: bool = is_new_weapon(choice)
	player.apply_upgrade("level_" + weapon)
	if not weapon_ids.has(choice["name"]):
		weapon_ids[choice["name"]] = weapon
		spells_taken.append(choice["name"])
	if player.weapon_level(weapon) >= BALANCE.weapon_max_level:
		upgrade_pool.erase(choice)
	if was_new:
		took_new_weapon()

func _on_option_pressed(index: int) -> void:
	var choice: Dictionary = current_choices[index]
	if choice.has("weapon"):
		take_weapon(choice)
		visible = false
		get_tree().paused = false
		return

	player.apply_upgrade(choice["id"])

	# One-time upgrades (spell unlocks) leave the pool forever.
	if choice.get("once", false):
		upgrade_pool.erase(choice)
		spells_taken.append(choice["name"])
		took_new_weapon()
	else:
		upgrades_taken[choice["name"]] = upgrades_taken.get(choice["name"], 0) + 1

	visible = false
	get_tree().paused = false
