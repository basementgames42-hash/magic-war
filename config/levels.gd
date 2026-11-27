class_name Levels
extends RefCounted
# The twelve maps, in play order. Each has its own ground and building colour,
# its own scenery and five enemy types no other map uses. Beating a map
# (surviving BALANCE.win_time_minutes) unlocks the next: see GameData.
#
# Map keys:
#   ground        - tint for the grass tile (values above 1 are fine)
#   buildings     - which "<colour> Buildings" folder prop.gd draws from
#   foliage       - tint for trees and bushes
#   trees / rocks - prop kinds to scatter (see KINDS in prop.gd)
#   scatter       - how many [trees, rocks, bushes] to scatter
#   seed          - scatter seed: same map every run
#   health/damage/spawn - difficulty of the map, on top of wave + player level
#   landmarks     - hand-placed scenery as [kind, x, y]. Empty = keep the
#                   props placed by hand in world.tscn.
#   boss          - name of the map's boss: a giant version of its last enemy
#                   type that arrives in the final minute (main.gd)
#
# Enemy keys:
#   name, run, attack - folder and sheet suffixes in the Enemy Pack
#   ai     - which brain enemy.gd runs (every enemy has its own)
#   speed, health - multipliers on the Balance base stats
#   folder, file - where its sheets are, if not "<name>/<name>_<suffix>.png"
#                 (the pig and pig rider live in the pack's Extra folder);
#                 see sheet() below for units and whole-path suffixes
#   units  - its art is a hero-unit colour set (rival armies), not the pack
#   tint   - colour wash for a re-used creature's new-map variant (frost,
#            shadow...); a map's own creatures leave it out
#   scale  - size of a normal one, for sheets drawn bigger than usual (troll)
#   flat_damage - every hit (contact or its hazards) costs a flat amount of
#                 HP, ignoring damage multipliers and the swarm streak: 1 for
#                 a normal goblin, more for an elite one (balance.tres)

const ENEMY_PACK_DIR: String = "res://scenes/assets/Tiny Swords (Enemy Pack)/Tiny Swords (Enemy Pack)/Enemy Pack/"

# The sheet for one of an enemy type's animations (suffix "Run", "Attack"...).
# A suffix with a "/" is a whole path inside the pack instead (the guard
# poses live in Extra, apart from the creature's own sheets). units = from
# the hero art (rival armies) rather than the enemy pack; file "" = sheets
# named just by the suffix (the Monk's "Run", "Heal").
static func sheet(type: Dictionary, suffix: String) -> String:
	var root: String = Characters.UNITS_DIR if type.get("units", false) else ENEMY_PACK_DIR
	if "/" in suffix:
		return root + suffix + ".png"
	var file: String = type.get("file", type["name"])
	return root + type.get("folder", type["name"]) + "/" + (file + "_" if file != "" else "") + suffix + ".png"

const MAPS: Array[Dictionary] = [
	{
		"name": "Greenhollow Vale",
		"boss": "Mossback the Lizard Brute",
		"blurb": "Farmland under siege. The bones are only the start.",
		"ground": Color(0.55, 0.6, 0.4),
		"buildings": "Blue",
		"foliage": Color.WHITE,
		"trees": ["tree1", "tree2", "tree3", "tree4"],
		"rocks": ["rock1", "rock2", "rock3", "rock4", "stump"],
		"scatter": [40, 30, 70],
		"seed": 7,
		"health": 1.0, "damage": 0.0, "spawn": 1.0,
		"landmarks": [],
		"enemies": [
			{"name": "Skull", "run": "Run", "attack": "Attack", "ai": "march", "speed": 1.0, "health": 1.0},
			{"name": "Gnome", "run": "Run", "attack": "Attack", "ai": "scurry", "speed": 1.1, "health": 0.8},
			{"name": "Spider", "run": "Run", "attack": "Attack", "ai": "pounce", "speed": 0.8, "health": 1.0},
			{"name": "Thief", "run": "Run", "attack": "Attack", "ai": "flank", "speed": 1.2, "health": 1.0},
			{"name": "Lizard", "run": "Run", "attack": "Attack", "ai": "charge", "speed": 0.8, "health": 1.6},
		],
	},
	{
		"name": "Emberwaste",
		"boss": "Ashpelt the Ember Bear",
		"blurb": "Scorched badlands held by goblin raiders.",
		"ground": Color(1.75, 0.8, 0.42),
		"buildings": "Red",
		"foliage": Color(1.5, 0.72, 0.32),
		"trees": ["tree3", "tree4", "dead_tree"],
		"rocks": ["rock2", "rock3", "bones1", "bones2", "gold_stone2"],
		"scatter": [22, 55, 25],
		"seed": 23,
		"health": 1.4, "damage": 0.25, "spawn": 1.1,
		"landmarks": [
			["goblin_hut", -260, -340], ["goblin_hut", 270, -360], ["goblin_hut", -60, -560],
			["tower", -520, -520], ["tower", 520, -540], ["barracks", 0, -760],
			["goblin_hut", 980, 520], ["goblin_hut", 1240, 640], ["goblin_hut", 1100, 860],
			["archery", 1420, 420], ["rock3", 860, 700], ["rock1", 1320, 900],
			["house2", -1120, 780], ["house3", -1300, 930], ["goblin_hut", -940, 980],
			["tower", -1420, 700], ["gold_stone", -1560, -1120], ["gold_stone2", -1450, -1040],
			["gold_stone", -1620, -960], ["castle", 1500, -1320], ["tower", 1230, -1280],
			["tower", 1770, -1280], ["barracks", -320, 1420], ["goblin_hut", 60, 1500],
		],
		"enemies": [
			{"name": "Torch Goblin", "run": "Run", "attack": "Attack", "ai": "arson", "speed": 1.05, "health": 1.0, "flat_damage": true},
			{"name": "Spear Goblin", "run": "Run", "attack": "Attack Fast", "ai": "skirmish", "speed": 1.1, "health": 1.0, "flat_damage": true},
			{"name": "Gnoll", "run": "Walk", "attack": "Throw", "ai": "kite", "speed": 0.95, "health": 0.9},
			{"name": "Panda", "run": "Run", "attack": "Attack", "ai": "slam", "speed": 0.8, "health": 1.8, "flat_damage": true},
			{"name": "Bear", "run": "Run", "attack": "Attack", "ai": "enrage", "speed": 0.6, "health": 2.5},
		],
	},
	{
		"name": "Tidewrack Fen",
		"boss": "Ironshell, Tyrant of the Tides",
		"blurb": "A drowned marsh where the sea came ashore armed.",
		"ground": Color(0.42, 0.95, 1.05),
		"buildings": "Yellow",
		"foliage": Color(0.55, 1.05, 0.95),
		"trees": ["tree1", "tree2"],
		"rocks": ["rock1", "rock4", "stump"],
		"scatter": [28, 24, 90],
		"seed": 41,
		"health": 1.9, "damage": 0.5, "spawn": 1.2,
		"landmarks": [
			["fish_hut", -300, 300], ["fish_hut", -520, 420], ["fish_hut", -160, 520],
			["pirate_tower", -640, 620], ["pirate_tower", 40, 680],
			["fish_hut", 760, -340], ["fish_hut", 980, -470], ["fish_hut", 1180, -300],
			["pirate_tower", 1340, -520], ["house1", 860, -640], ["house3", 1120, -700],
			["monastery", -1180, -760], ["house2", -1440, -640], ["house1", -960, -620],
			["pirate_tower", -1300, -1040], ["castle", 1180, 1360], ["tower", 920, 1400],
			["tower", 1440, 1400], ["fish_hut", 700, 1120], ["fish_hut", -1400, 1200],
			["fish_hut", -1200, 1340], ["pirate_tower", -1560, 1360], ["archery", 100, -1400],
		],
		"enemies": [
			{"name": "Paddle Shark", "run": "Run", "attack": "Attack", "ai": "burrow", "speed": 1.15, "health": 1.0},
			{"name": "Snake", "run": "Run", "attack": "Attack", "ai": "slither", "speed": 1.0, "health": 1.0},
			{"name": "Harpoon Shark", "run": "Run", "attack": "Throw", "ai": "harpoon", "speed": 0.9, "health": 1.1},
			{"name": "Bomb Fish", "run": "Run", "attack": "Shoot", "ai": "lob", "speed": 0.9, "health": 1.0},
			{"name": "Turtle", "run": "Walk", "attack": "Attack", "ai": "shell", "speed": 0.6, "health": 2.5},
		],
	},
	{
		"name": "Hexfall Barrens",
		"boss": "Hexhorn the Cursed Minotaur",
		"blurb": "Cursed ground. Nothing here walks a straight line.",
		"ground": Color(0.95, 0.42, 1.0),
		"buildings": "Black",
		"foliage": Color(0.7, 0.5, 0.95),
		"trees": ["tree3", "tree4", "tree3", "dead_tree"],
		"rocks": ["skull_spike1", "skull_spike2", "bones1", "bones2", "rock3"],
		"scatter": [34, 60, 12],
		"seed": 67,
		"health": 2.5, "damage": 0.75, "spawn": 1.3,
		"landmarks": [
			["castle", 0, 620], ["tower", -240, 650], ["tower", 240, 650],
			["skull_spike2", -130, 300], ["skull_spike2", 130, 300],
			["skull_spike1", -300, 430], ["skull_spike1", 300, 430],
			["monastery", -1220, -300], ["skull_spike2", -1040, -240], ["skull_spike2", -1400, -240],
			["barracks", 1200, -260], ["house3", 1020, -480], ["house2", 1400, -490],
			["tower", 1000, -60], ["tower", 1420, -60], ["gnome_tower", -520, -1120],
			["gnome_hut", -360, -1040], ["gnome_hut", -700, -1040], ["house1", 1260, 1280],
			["house3", 1040, 1400], ["tower", -1380, 1300], ["tower", -1120, 1300],
			["archery", -1250, 1480], ["skull_spike1", 460, -1300], ["skull_spike2", 620, -1380],
		],
		"enemies": [
			{"name": "Giant Bat", "run": "Move", "attack": "Attack", "ai": "swoop", "speed": 0.85, "health": 0.9},
			{"name": "Bumblebee", "run": "Move", "attack": "Attack", "ai": "sting", "speed": 1.3, "health": 0.8},
			{"name": "Imp", "run": "Move", "attack": "Attack_Loop", "ai": "blink", "speed": 0.9, "health": 1.1},
			{"name": "Hex Shaman", "run": "Run", "attack": "Attack", "ai": "hex", "speed": 0.85, "health": 1.2},
			{"name": "Minotaur", "run": "Walk", "attack": "Attack", "ai": "bullrush", "speed": 0.8, "health": 3.0},
		],
	},
	# Maps 5-8: each brings one creature new to the war, alongside variants of
	# known ones in the map's colours (tint), and a boss of its own.
	{
		"name": "Frostpeak Pass",
		"boss": "Frostjaw the Ice Bear",
		"blurb": "A frozen mountain road. The dead march even in the snow.",
		"ground": Color(2.54, 1.54, 1.81),  # Snow
		"buildings": "Blue",
		"foliage": Color(0.78, 1.0, 1.15),
		"trees": ["tree1", "tree2", "tree1"],
		"rocks": ["rock1", "rock2", "rock4", "stump"],
		"scatter": [48, 42, 25],
		"seed": 89,
		"health": 3.0, "damage": 0.9, "spawn": 1.35,
		"landmarks": [
			["castle", 0, -700], ["tower", -290, -700], ["tower", 290, -700],
			["house1", -600, 380], ["house2", -820, 520], ["house3", -560, 640],
			["monastery", 1150, 420], ["tower", 1380, 300], ["house1", 960, 640],
			["barracks", -1250, -560], ["archery", -1500, -380], ["rock4", -1080, -380],
			["house2", 420, 1350], ["house3", 690, 1450], ["tower", 150, 1480],
			["castle", -1350, 1300], ["rock1", -1050, 1150], ["house1", 1450, -1250],
			["tower", 1680, -1100], ["rock2", 1250, -1050],
		],
		"enemies": [
			{"name": "Skull", "run": "Run", "attack": "Attack", "ai": "march", "speed": 1.0, "health": 1.0,
				"tint": Color(0.78, 0.95, 1.25)},
			{"name": "Slingshot Gnome", "run": "Run", "attack": "Shoot", "ai": "sling", "speed": 1.05, "health": 0.9},
			{"name": "Spider", "run": "Run", "attack": "Attack", "ai": "pounce", "speed": 0.85, "health": 1.1,
				"tint": Color(0.78, 0.95, 1.25)},
			{"name": "Snake", "run": "Run", "attack": "Attack", "ai": "slither", "speed": 1.0, "health": 1.1,
				"tint": Color(0.78, 0.95, 1.25)},
			{"name": "Bear", "run": "Run", "attack": "Attack", "ai": "enrage", "speed": 0.6, "health": 2.6,
				"tint": Color(0.8, 0.95, 1.3)},
		],
	},
	{
		"name": "Duskwood Hollow",
		"boss": "Gloomhide the Shadow Panda",
		"blurb": "A forest where the sun never quite comes up. Something stampedes in the dark.",
		"ground": Color(1.0, 0.44, 0.89),  # Dusk violet
		"buildings": "Purple",
		"foliage": Color(0.58, 0.45, 0.88),
		"trees": ["tree3", "tree4", "tree3", "dead_tree"],
		"rocks": ["rock3", "bones1", "skull_spike1", "stump"],
		"scatter": [55, 28, 45],
		"seed": 113,
		"health": 3.5, "damage": 1.05, "spawn": 1.4,
		"landmarks": [
			["monastery", 0, -680], ["house3", -320, -620], ["house2", 320, -620],
			["house1", -780, 320], ["tower", -1000, 420], ["dead_tree", -560, 520],
			["barracks", 980, 380], ["house3", 1220, 560], ["dead_tree", 820, 640],
			["castle", -1300, -1200], ["tower", -1020, -1160], ["tower", -1580, -1160],
			["house1", 1300, -980], ["house2", 1520, -860], ["skull_spike2", 1180, -760],
			["archery", 120, 1400], ["dead_tree", -260, 1380], ["house3", 1250, 1350],
			["tower", -1450, 1250], ["dead_tree", -1200, 1450],
		],
		"enemies": [
			{"name": "Giant Bat", "run": "Move", "attack": "Attack", "ai": "swoop", "speed": 0.85, "health": 0.9,
				"tint": Color(0.75, 0.6, 1.05)},
			{"name": "Thief", "run": "Run", "attack": "Attack", "ai": "flank", "speed": 1.2, "health": 1.0,
				"tint": Color(0.75, 0.6, 1.05)},
			{"name": "Pig", "folder": "Extra/Pig", "file": "Pig", "run": "Run", "attack": "Run",
				"ai": "stampede", "speed": 1.0, "health": 1.2},
			{"name": "Imp", "run": "Move", "attack": "Attack_Loop", "ai": "blink", "speed": 0.9, "health": 1.1,
				"tint": Color(0.8, 0.6, 1.1)},
			{"name": "Panda", "run": "Run", "attack": "Attack", "ai": "slam", "speed": 0.8, "health": 1.9,
				"tint": Color(0.7, 0.55, 1.0), "flat_damage": true},
		],
	},
	{
		"name": "Sunscorch Dunes",
		"boss": "Sandshell the Dune Tortoise",
		"blurb": "Endless sand and bleached bones. Riders come out of the haze.",
		"ground": Color(2.54, 1.21, 0.85),  # Sand
		"buildings": "Yellow",
		"foliage": Color(1.3, 1.1, 0.6),
		"trees": ["dead_tree", "tree3", "dead_tree"],
		"rocks": ["rock2", "rock3", "bones2", "gold_stone2", "skull_spike2"],
		"scatter": [14, 58, 15],
		"seed": 137,
		"health": 4.0, "damage": 1.2, "spawn": 1.45,
		"landmarks": [
			["castle", 0, 700], ["tower", -280, 720], ["tower", 280, 720],
			["gold_stone", -620, -420], ["gold_stone2", -520, -340], ["bones1", -720, -300],
			["house2", 980, -420], ["house3", 1200, -300], ["tower", 1400, -480],
			["archery", -1250, 360], ["barracks", -1500, 560], ["dead_tree", -1050, 600],
			["house1", 1250, 1150], ["house2", 1500, 1260], ["skull_spike2", 1080, 1300],
			["monastery", -1150, -1250], ["gold_stone", 300, -1450], ["bones2", 520, -1380],
			["dead_tree", -300, -1350], ["tower", 1650, -1200],
		],
		"enemies": [
			{"name": "Gnome", "run": "Run", "attack": "Attack", "ai": "scurry", "speed": 1.1, "health": 0.9,
				"tint": Color(1.25, 1.05, 0.75)},
			{"name": "Lizard", "run": "Run", "attack": "Attack", "ai": "charge", "speed": 0.85, "health": 1.6,
				"tint": Color(1.25, 1.05, 0.75)},
			{"name": "Pig Rider", "folder": "Extra/Pig Rider Spear Goblin", "file": "Pig Rider",
				"run": "Run", "attack": "Attack", "ai": "joust", "speed": 1.1, "health": 1.3},
			{"name": "Gnoll", "run": "Walk", "attack": "Throw", "ai": "kite", "speed": 0.95, "health": 1.0,
				"tint": Color(1.25, 1.05, 0.75)},
			{"name": "Turtle", "run": "Walk", "attack": "Attack", "ai": "shell", "speed": 0.6, "health": 2.6,
				"tint": Color(1.3, 1.1, 0.7)},
		],
	},
	{
		"name": "Ashen Throne",
		"boss": "Cinderhulk, Warden of the Ashen Throne",
		"blurb": "The burnt heart of the Magic War. Its warden has never been moved.",
		"ground": Color(1.06, 0.44, 0.44),  # Ash
		"buildings": "Black",
		"foliage": Color(0.62, 0.36, 0.3),
		"trees": ["dead_tree", "tree4", "dead_tree"],
		"rocks": ["skull_spike1", "skull_spike2", "bones1", "bones2", "rock3"],
		"scatter": [22, 72, 8],
		"seed": 151,
		"health": 4.6, "damage": 1.35, "spawn": 1.5,
		"landmarks": [
			["castle", 0, -720], ["tower", -300, -740], ["tower", 300, -740],
			["skull_spike2", -150, -420], ["skull_spike2", 150, -420],
			["skull_spike1", -320, -300], ["skull_spike1", 320, -300],
			["barracks", -1100, 300], ["tower", -1330, 200], ["goblin_hut", -900, 520],
			["goblin_hut", 1050, 420], ["goblin_hut", 1250, 620], ["tower", 1450, 380],
			["monastery", -1250, -1250], ["skull_spike2", -1000, -1100], ["castle", 1300, 1300],
			["tower", 1050, 1340], ["tower", 1560, 1340], ["skull_spike1", -1400, 1300],
			["dead_tree", 300, 1400], ["goblin_hut", -300, 1450],
		],
		"enemies": [
			{"name": "Torch Goblin", "run": "Run", "attack": "Attack", "ai": "arson", "speed": 1.05, "health": 1.0,
				"tint": Color(1.25, 0.75, 0.65), "flat_damage": true},
			{"name": "Hex Shaman", "run": "Run", "attack": "Attack", "ai": "hex", "speed": 0.85, "health": 1.2,
				"tint": Color(1.25, 0.75, 0.65)},
			{"name": "Bumblebee", "run": "Move", "attack": "Attack", "ai": "sting", "speed": 1.3, "health": 0.9,
				"tint": Color(1.25, 0.75, 0.65)},
			{"name": "Spear Goblin", "run": "Run", "attack": "Attack Fast", "ai": "skirmish", "speed": 1.1, "health": 1.0,
				"tint": Color(1.25, 0.75, 0.65), "flat_damage": true},
			{"name": "Troll", "run": "Walk", "attack": "Attack", "ai": "smash", "speed": 0.6, "health": 3.0,
				"scale": 0.6},
		],
	},
	# Maps 9-12: sea raiders, a rival army, shield-bearing guards, and the
	# shadow army's citadel.
	{
		"name": "Saltspray Coast",
		"boss": "Captain Brinejaw's Longboat",
		"blurb": "Wave-washed shallows. The sharks have learned to ride.",
		"ground": Color(1.06, 1.04, 1.44),  # Blue shallows
		"buildings": "Yellow",
		"foliage": Color(0.8, 1.1, 0.9),
		"trees": ["tree1", "tree2"],
		"rocks": ["rock1", "rock4", "stump"],
		"scatter": [20, 30, 60],
		"seed": 173,
		"health": 5.2, "damage": 1.45, "spawn": 1.55,
		"landmarks": [
			["pirate_tower", -320, -560], ["fish_hut", -560, -420], ["fish_hut", -120, -640],
			["pirate_tower", 760, 420], ["fish_hut", 1000, 560], ["fish_hut", 560, 620],
			["house2", -1100, 480], ["house3", -1320, 600], ["tower", -900, 680],
			["pirate_tower", 1300, -1100], ["fish_hut", 1520, -980], ["rock4", 1100, -940],
			["castle", -1300, -1300], ["tower", -1030, -1260], ["fish_hut", 250, 1400],
			["pirate_tower", -350, 1450], ["fish_hut", 1350, 1300], ["rock1", 1150, 1420],
		],
		"enemies": [
			{"name": "Paddle Shark", "run": "Run", "attack": "Attack", "ai": "burrow", "speed": 1.15, "health": 1.0,
				"tint": Color(0.8, 0.95, 1.25)},
			{"name": "Seahorse Raider", "folder": "Extra/Seahorse Boat", "file": "Seahorse Boat",
				"run": "Paddle Shark", "attack": "Paddle Shark", "ai": "charge", "speed": 1.1, "health": 1.2},
			{"name": "Seahorse Harpooner", "folder": "Extra/Seahorse Boat", "file": "Seahorse Boat",
				"run": "Harpoon Shark", "attack": "Harpoon Shark", "ai": "harpoon", "speed": 0.95, "health": 1.1},
			{"name": "Seahorse Bombardier", "folder": "Extra/Seahorse Boat", "file": "Seahorse Boat",
				"run": "Bomb Fish", "attack": "Bomb Fish", "ai": "lob", "speed": 0.9, "health": 1.1},
			{"name": "Longboat", "folder": "Extra/Boat", "file": "Paddle Shark", "run": "Row", "attack": "Row",
				"ai": "bullrush", "speed": 0.75, "health": 2.8},
		],
	},
	{
		"name": "Violet Legion Keep",
		"boss": "Lord Amethyst, Knight of the Legion",
		"blurb": "A rival army holds this keep. Pawns, archers, lancers, and monks to heal them all.",
		"ground": Color(1.53, 0.84, 1.01),  # Stone courtyard
		"buildings": "Purple",
		"foliage": Color(0.75, 0.6, 0.95),
		"trees": ["tree3", "tree4"],
		"rocks": ["rock2", "rock3", "stump"],
		"scatter": [18, 26, 12],
		"seed": 197,
		"health": 5.9, "damage": 1.55, "spawn": 1.6,
		"landmarks": [
			["castle", 0, -720], ["tower", -320, -740], ["tower", 320, -740],
			["barracks", -700, -420], ["barracks", 700, -420], ["archery", -1100, 200],
			["archery", 1100, 200], ["tower", -1350, 300], ["tower", 1350, 300],
			["house1", -600, 700], ["house2", -850, 820], ["house3", 600, 700], ["house1", 850, 820],
			["monastery", 0, 1300], ["castle", -1350, -1300], ["castle", 1350, -1300],
			["barracks", -1300, 1300], ["barracks", 1300, 1300],
		],
		"enemies": [
			{"name": "Purple Pawn", "units": true, "folder": "Purple Units/Pawn", "file": "Pawn",
				"run": "Run", "attack": "Interact Axe", "ai": "march", "speed": 1.05, "health": 0.9},
			{"name": "Purple Archer", "units": true, "folder": "Purple Units/Archer", "file": "Archer",
				"run": "Run", "attack": "Shoot", "ai": "volley", "speed": 0.95, "health": 0.9},
			{"name": "Purple Lancer", "units": true, "folder": "Purple Units/Lancer", "file": "Lancer",
				"run": "Run", "attack": "Right_Attack", "ai": "joust", "speed": 1.1, "health": 1.2, "scale": 0.65},
			{"name": "Purple Monk", "units": true, "folder": "Purple Units/Monk", "file": "",
				"run": "Run", "attack": "Heal", "ai": "mend", "speed": 0.9, "health": 1.0},
			{"name": "Purple Warrior", "units": true, "folder": "Purple Units/Warrior", "file": "Warrior",
				"run": "Run", "attack": "Attack1", "ai": "duel", "speed": 0.9, "health": 2.4},
		],
	},
	{
		"name": "Sentinel Ruins",
		"boss": "The Stone Sentinel",
		"blurb": "Moss-eaten ruins still kept by their old guards. They raise their shields as one.",
		"ground": Color(1.06, 0.81, 0.59),  # Moss
		"buildings": "Blue",
		"foliage": Color(0.7, 0.95, 0.6),
		"trees": ["tree1", "tree3", "tree4", "dead_tree"],
		"rocks": ["rock1", "rock2", "rock3", "rock4", "stump", "skull_spike1"],
		"scatter": [40, 55, 40],
		"seed": 211,
		"health": 6.6, "damage": 1.65, "spawn": 1.65,
		"landmarks": [
			["monastery", 0, -700], ["tower", -300, -680], ["tower", 300, -680],
			["dead_tree", -700, 300], ["rock3", -560, 480], ["tower", -900, 520],
			["castle", 1000, 400], ["rock4", 780, 650], ["dead_tree", 1300, 700],
			["tower", -1300, -1100], ["monastery", -1050, -1300], ["skull_spike2", -1450, -900],
			["castle", 1200, -1200], ["dead_tree", 1450, -1000], ["tower", 0, 1400],
			["rock2", -250, 1300], ["monastery", -1250, 1300], ["dead_tree", 1300, 1350],
		],
		"enemies": [
			{"name": "Skull Guard", "folder": "Skull", "file": "Skull", "run": "Run",
				"attack": "Extra/Skull Guard/Skull_Guard", "ai": "guard", "speed": 1.0, "health": 1.2},
			{"name": "Imp", "run": "Move", "attack": "Attack_Loop", "ai": "blink", "speed": 0.9, "health": 1.1,
				"tint": Color(0.8, 1.05, 0.7)},
			{"name": "Panda Guard", "folder": "Panda", "file": "Panda", "run": "Run",
				"attack": "Extra/Panda Guard/Panda_Guard", "ai": "guard", "speed": 0.85, "health": 1.6},
			{"name": "Turtle Guard", "folder": "Turtle", "file": "Turtle", "run": "Walk",
				"attack": "Extra/Turtle Guard/Turtle_Guard_In", "ai": "guard", "speed": 0.75, "health": 2.0},
			{"name": "Minotaur Sentinel", "folder": "Minotaur", "file": "Minotaur", "run": "Walk",
				"attack": "Extra/Minotaur Guard/Minotaur_Guard", "ai": "bullrush", "speed": 0.8, "health": 3.2,
				"tint": Color(0.82, 0.85, 0.8)},
		],
	},
	{
		"name": "Shadow Citadel",
		"boss": "The Shadow Colossus",
		"blurb": "The shadow army's fortress, under a sky with no stars. End the war here.",
		"ground": Color(0.59, 0.34, 0.52),  # Night stone
		"buildings": "Black",
		"foliage": Color(0.45, 0.4, 0.65),
		"trees": ["dead_tree", "tree4"],
		"rocks": ["skull_spike1", "skull_spike2", "bones1", "rock3"],
		"scatter": [16, 60, 6],
		"seed": 239,
		"health": 7.4, "damage": 1.75, "spawn": 1.7,
		"landmarks": [
			["castle", 0, -750], ["tower", -330, -770], ["tower", 330, -770],
			["skull_spike2", -160, -440], ["skull_spike2", 160, -440],
			["barracks", -900, 300], ["archery", -1150, 450], ["tower", -700, 520],
			["barracks", 900, 300], ["archery", 1150, 450], ["tower", 700, 520],
			["castle", -1350, -1300], ["castle", 1350, -1300], ["monastery", 0, 1350],
			["tower", -1350, 1300], ["tower", 1350, 1300], ["skull_spike1", -300, 1250],
			["skull_spike1", 300, 1250],
		],
		"enemies": [
			{"name": "Black Warrior", "units": true, "folder": "Black Units/Warrior", "file": "Warrior",
				"run": "Run", "attack": "Attack1", "ai": "duel", "speed": 0.95, "health": 1.3},
			{"name": "Black Archer", "units": true, "folder": "Black Units/Archer", "file": "Archer",
				"run": "Run", "attack": "Shoot", "ai": "volley", "speed": 0.95, "health": 1.0},
			{"name": "Black Monk", "units": true, "folder": "Black Units/Monk", "file": "",
				"run": "Run", "attack": "Heal", "ai": "mend", "speed": 0.9, "health": 1.1},
			{"name": "Hex Shaman", "run": "Run", "attack": "Attack", "ai": "hex", "speed": 0.85, "health": 1.3,
				"tint": Color(0.65, 0.55, 0.95)},
			{"name": "Troll", "run": "Walk", "attack": "Attack", "ai": "smash", "speed": 0.65, "health": 3.4,
				"scale": 0.6, "tint": Color(0.55, 0.5, 0.8)},
		],
	},
]

# Test map, for trying things out: only offered from the map select screen
# when the game runs from the Godot editor (see map_select.gd). It's not in
# MAPS, so it never counts toward unlocks, endless or the save file.
static func ranged_test() -> Dictionary:
	var test: Dictionary = MAPS[1].duplicate()  # Emberwaste's look and scenery
	test["name"] = "Ranged Test"
	test["blurb"] = "Nothing but throwers, bombers and casters."
	test["boss"] = "Malhex the Grand Hex Shaman"
	test["health"] = 1.0
	test["damage"] = 0.0
	test["spawn"] = 1.0
	test["enemies"] = [
		{"name": "Gnoll", "run": "Walk", "attack": "Throw", "ai": "kite", "speed": 0.95, "health": 0.9},
		{"name": "Bomb Fish", "run": "Run", "attack": "Shoot", "ai": "lob", "speed": 0.9, "health": 1.0},
		{"name": "Harpoon Shark", "run": "Run", "attack": "Throw", "ai": "harpoon", "speed": 0.9, "health": 1.1},
		{"name": "Hex Shaman", "run": "Run", "attack": "Attack", "ai": "hex", "speed": 0.85, "health": 1.2},
	]
	return test

# The map the run being started uses: a test map if one was picked,
# otherwise the chosen map.
static func current() -> Dictionary:
	return GameData.test_map if not GameData.test_map.is_empty() else MAPS[GameData.level_index]

# Endless mode starts on the first map and slowly drifts through the others
# (main.gd drift_map), and cycles through every enemy above, a little of
# each map at a time, so a long run sees the whole bestiary.
static func endless_enemies() -> Array[Dictionary]:
	var order: Array[Dictionary] = []
	for slot in 5:
		for map in MAPS:
			order.append(map["enemies"][slot])
	return order
