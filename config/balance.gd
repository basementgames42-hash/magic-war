class_name Balance
extends Resource
# Game balance knobs in one place. Edit res://config/balance.tres in the
# Inspector (double-click it in the FileSystem dock), then press F5 to play.
# Scripts read these at spawn time:
#   player.gd, enemy.gd, main.gd (win time, elites, waves), lightning/frost/orbit spells.
# Hover a value in the Inspector to see what it does.

@export_group("Win Condition")
## Minutes the player must survive to win a map (and unlock the next one).
## Endless mode ignores it. The map's five enemy types are spread evenly across
## this time, so every map shows all five however long the run is.
@export_range(0.5, 30.0, 0.5) var win_time_minutes: float = 5.0

@export_group("Endless Mode")
## Minutes endless mode stays on one map before it starts drifting to the next.
## Maps go in play order and loop back to the first after the last.
@export_range(0.5, 30.0, 0.5) var endless_map_minutes: float = 3.5
## Minutes the drift into the next map takes: the ground and foliage colours
## blend, and buildings, trees and rocks change a few at a time while off-screen.
@export_range(0.1, 10.0, 0.1) var endless_blend_minutes: float = 1.5

@export_group("Difficulty Scaling")
## Extra enemy health per player level above 1 (0.08 = +8% each level).
## Each map adds its own multiplier on top (see config/levels.gd).
@export_range(0.0, 0.5, 0.01) var health_per_player_level: float = 0.08
## Extra damage taken per player level above 1 (0.04 = +4% each level).
@export_range(0.0, 0.5, 0.01) var damage_per_player_level: float = 0.04
## Extra spawn rate per player level above 1 (0.03 = 3% more enemies each level).
@export_range(0.0, 0.2, 0.01) var spawn_rate_per_player_level: float = 0.03
## Spawning pauses at this many living enemies, so late runs stay playable.
@export_range(50, 1000, 10) var max_enemies: int = 250
## Extra normal enemy health per full minute of the run.
@export_range(0, 20) var enemy_health_per_minute: int = 2
## Extra elite health per full minute of the run.
@export_range(0, 200) var elite_health_per_minute: int = 20
## Endless: waves up to this one make enemies tougher (health) and hit harder
## at the full per-wave rate, as in a normal map...
@export_range(1, 20) var endless_full_waves: int = 5
## ...and every wave after it counts this much (0.5 = half as much per wave),
## so a long endless run keeps getting harder without hitting a sudden wall.
@export_range(0.0, 1.0, 0.05) var endless_late_wave_factor: float = 0.5

@export_group("Ads")
## Watch-an-ad revives allowed per run. 0 turns the offer off.
@export_range(0, 10) var revives_per_run: int = 1
## Seconds of invincibility after a revive, to get clear of the swarm.
@export_range(0.0, 10.0, 0.5) var revive_invincible_seconds: float = 3.0
## How much a boost multiplies gold, EXP or pickup drop chance.
@export_range(1.0, 5.0, 0.5) var boost_multiplier: float = 2.0
## How long a boost lasts once earned, in seconds.
@export_range(10.0, 300.0, 5.0) var boost_seconds: float = 60.0
## Seconds into a run before the first boost offer.
@export_range(0.0, 300.0, 5.0) var boost_first_offer: float = 30.0
## How long a boost offer stays on screen, in seconds.
@export_range(3.0, 30.0, 1.0) var boost_offer_seconds: float = 15.0
## Seconds until the next offer, after one is ignored or a boost runs out.
@export_range(10.0, 600.0, 5.0) var boost_offer_gap: float = 120.0

@export_group("Player Speed")
## How fast the player moves at the start of a run (pixels/second).
## Swift Boots (+15%) and the Agility shop upgrade multiply this.
@export_range(100.0, 600.0, 5.0) var player_speed: float = 280.0

@export_group("Player Damage")
## Starting weapons (one per hero) — damage per hit. The level-up spells and
## weapons below are tuned to sit on the same scale: weaker than the starting
## weapon at level 1, catching up to (and in a crowd passing) it when maxed.
## Monk's Fireball damage per hit.
@export_range(1, 50) var fireball_damage: int = 1
## Share of Fireball damage the explosion deals to other enemies close to the
## impact (0.5 = half). Without it the Monk can only fight one enemy at a time.
@export_range(0.0, 1.0, 0.05) var fireball_splash: float = 0.5
## Lightning Arc damage per strike (one enemy every 1.2s).
@export_range(1, 50) var lightning_damage: int = 20
## Frost Nova damage per pulse (everything nearby every 3s, and slows them).
@export_range(1, 50) var frost_damage: int = 10
## Arcane Orbit damage per orb hit.
@export_range(1, 50) var orbit_damage: int = 9
## Warrior's Cleave damage per enemy hit.
@export_range(1, 50) var cleave_damage: int = 1
## Lancer's Lance Thrust damage per enemy hit.
@export_range(1, 50) var thrust_damage: int = 1
## Archer's Piercing Arrow damage per enemy hit.
@export_range(1, 50) var arrow_damage: int = 1
## Starting-weapon damage level-up ("Honed Edge" etc.): adds this share of
## the hero's base weapon damage per pick (0.15 = +3 on a 20-damage weapon).
@export_range(0.05, 1.0, 0.05) var damage_pick_bonus: float = 0.15
## Starting-weapon speed level-up ("Battle Rhythm" etc.): attacks this much
## faster per pick (0.15 = 15% shorter wait between attacks).
@export_range(0.05, 0.5, 0.05) var fire_rate_pick: float = 0.15

@export_group("Level-Up Weapons")
## Highest level for Runeward Circle, Starfall, Moonreaver and Thornwake.
@export_range(1, 10) var weapon_max_level: int = 5
## Runeward Circle: damage per tick at level 1, and extra per level.
@export_range(1, 50) var runeward_damage: int = 4
@export_range(0, 20) var runeward_damage_per_level: int = 1
## Runeward Circle: radius in pixels at level 1, and extra per level.
@export_range(50.0, 400.0, 5.0) var runeward_radius: float = 130.0
@export_range(0.0, 150.0, 5.0) var runeward_radius_per_level: float = 25.0
## Runeward Circle: seconds between damage ticks.
@export_range(0.1, 2.0, 0.05) var runeward_tick: float = 0.5
## Starfall: damage at level 1, and extra per level.
@export_range(1, 50) var starfall_damage: int = 14
@export_range(0, 20) var starfall_damage_per_level: int = 2
## Moonreaver: damage per pass at level 1, and extra per level.
@export_range(1, 50) var moonreaver_damage: int = 8
@export_range(0, 20) var moonreaver_damage_per_level: int = 1
## Thornwake: damage per bramble tick at level 1, and extra per level.
@export_range(1, 50) var thornwake_damage: int = 4
@export_range(0, 20) var thornwake_damage_per_level: int = 2

@export_group("Enemy Speed")
## Normal enemy move speed (pixels/second). Compare with Player Speed.
## Each enemy type multiplies it (config/levels.gd).
@export_range(50.0, 500.0, 5.0) var enemy_speed: float = 190.0
## Elite (giant) enemy move speed. Keep it below Enemy Speed: elites are slow.
@export_range(30.0, 500.0, 5.0) var elite_speed: float = 70.0
## From this enemy type on (3 = the 3rd type to appear in a run), enemies move
## slower: multiplied by Later Enemy Speed. Same rule in normal and endless.
@export_range(1, 20) var later_enemy_from_type: int = 3
@export_range(0.3, 1.0, 0.05) var later_enemy_speed: float = 0.85
## Those later enemies also speed up a touch per full minute of the run
## (0.01 = +1% a minute), up to Enemy Speed Max Bonus in total.
@export_range(0.0, 0.05, 0.005) var enemy_speed_per_minute: float = 0.01
@export_range(0.0, 1.0, 0.05) var enemy_speed_max_bonus: float = 0.2

@export_group("Enemy Damage")
## Base damage a normal enemy's hit does to the player (before multipliers).
@export_range(1, 20) var enemy_damage: int = 1
## Base damage an elite's hit does to the player.
@export_range(1, 20) var elite_damage: int = 3
## Every hit the player takes is multiplied by this (1.0 = no change).
@export_range(0.25, 5.0, 0.05) var damage_taken_multiplier: float = 1.5
## Extra damage taken per new enemy type (wave). 0.25 = +25% per wave.
@export_range(0.0, 1.0, 0.05) var wave_damage_bonus: float = 0.25
## Ranged hits (thrown bones, harpoons, hex bolts, lobbed bombs) do this
## share of a melee hit (0.5 = half), and never build the swarm streak below.
@export_range(0.1, 1.0, 0.05) var ranged_damage_multiplier: float = 0.5
## Most enemy shots per second across ALL ranged enemies together, so a crowd
## of throwers takes turns instead of firing in one wall. Only enemies on
## screen may shoot, so every shot can be seen coming.
@export_range(0.25, 10.0, 0.25) var enemy_shots_per_second: float = 1.5
## Seconds between one enemy's hits. Lower = swarms hurt faster.
@export_range(0.1, 3.0, 0.05) var enemy_attack_cooldown: float = 0.6
## Hits within this many seconds of the last one build a swarm streak.
@export_range(0.0, 3.0, 0.05) var streak_window: float = 0.75
## Extra damage per streak step (0.25 = +25% per consecutive hit).
@export_range(0.0, 1.0, 0.05) var streak_bonus: float = 0.25
## Most streak steps that count (8 x 0.25 = up to 3x damage).
@export_range(0, 20) var max_streak: int = 8

@export_group("Enemy Toughness")
## Normal enemy health at the start of a run (+2 per minute, +15% per wave).
@export_range(1, 50) var enemy_health: int = 4
## Elite health at the start of a run (+20 per minute, +15% per wave).
@export_range(1, 500) var elite_health: int = 60

@export_group("Boss")
## Regular maps: the boss (a giant version of the map's last enemy type)
## arrives when this many seconds are left on the clock. At 0:00 the clock
## shows BOSS and the map only clears once it's dead.
@export_range(10.0, 240.0, 5.0) var boss_arrives_seconds_left: float = 60.0
## Boss health on the first map; harder maps multiply it (config/levels.gd),
## and it gains Boss Health Per Player Level for each level above 1.
@export_range(100, 20000, 50) var boss_health: int = 1200
@export_range(0.0, 0.2, 0.01) var boss_health_per_player_level: float = 0.05
## Damage of one boss hit, before the usual multipliers.
@export_range(1, 30) var boss_damage: int = 4
## Boss size compared with a normal enemy (elites are 2.5).
@export_range(1.0, 4.0, 0.05) var boss_scale: float = 1.75
## A nuke hits the boss for this share of its max health instead of killing it.
@export_range(0.0, 1.0, 0.05) var boss_nuke_share: float = 0.1
## Coins and XP orbs the boss drops.
@export_range(0, 500) var boss_coins: int = 60
@export_range(0, 200) var boss_xp: int = 40

@export_group("Coin Drops")
## Coins a normal enemy drops when it dies. Each coin is worth 1 gold,
## plus the Greed shop bonus (+25% per level).
@export_range(0, 20) var coins_per_enemy: int = 1
## Coins an elite (giant) enemy drops when it dies.
@export_range(0, 100) var coins_per_elite: int = 15

@export_group("Shop Prices")
## Price of an upgrade's first level; each level costs this times the level
## (30, 60, 90 ... 300 at max). Was 10.
@export_range(1, 500) var upgrade_base_cost: int = 30
## The Luck upgrades (second tier) and the third tier cost this much more.
@export_range(1.0, 5.0, 0.1) var upgrade_tier2_cost: float = 1.5
@export_range(1.0, 5.0, 0.1) var upgrade_tier3_cost: float = 2.0

@export_group("Shop Upgrades")
## Max HP per Vitality level.
@export_range(1, 10) var vitality_per_level: int = 2
## Starting-weapon damage per Power level.
@export_range(1, 10) var power_per_level: int = 1
## Move speed per Agility level (0.04 = +4% a level, +40% at max).
@export_range(0.0, 0.1, 0.01) var agility_per_level: float = 0.04
## Gold per coin per Greed level (0.1 = +10% a level, 2 gold per coin at max).
@export_range(0.0, 0.5, 0.05) var greed_per_level: float = 0.1
## Extra chance per Potion Luck level that any enemy drops a health potion
## (0.03 = +3% per level, +30% at max, on top of the base ~1.2%). Unlocks once Vitality is maxed.
@export_range(0.0, 0.1, 0.005) var potion_drop_per_level: float = 0.03
## Extra nuke drop chance per Nuke Luck level (0.005 = +5% at max, on top of
## the base 0.2%). A nuke kills every enemy on the map. Unlocks once Power is maxed.
@export_range(0.0, 0.02, 0.001) var nuke_drop_per_level: float = 0.005
## Super Mode drop chance per level (no base chance). Unlocks once Agility is maxed.
@export_range(0.0, 0.02, 0.001) var invincible_drop_per_level: float = 0.003
## Seconds of invincibility from one Super Mode pickup.
@export_range(1.0, 20.0, 0.5) var invincible_duration: float = 6.0
## Extra magnet drop chance per Magnet Luck level (base 0.6%). Unlocks once Greed is maxed.
@export_range(0.0, 0.05, 0.001) var magnet_drop_per_level: float = 0.005
## HP healed per second per Regeneration level (0.05 = Lv 10 heals 1 HP every 2s).
## Unlocks once Potion Luck is maxed.
@export_range(0.0, 0.5, 0.01) var regen_per_level: float = 0.05
## Starting-weapon cooldown cut per Rapid Fire level (0.03 = 3% a level,
## 30% shorter at max). Unlocks once Nuke Luck is maxed.
@export_range(0.0, 0.09, 0.01) var fire_rate_per_level: float = 0.03
## Chance to dodge a hit per Dodge level (0.03 = Lv 10 dodges 30%).
## Unlocks once Super Mode is maxed.
@export_range(0.0, 0.09, 0.01) var dodge_per_level: float = 0.03
## Coin/XP pickup range bonus per Reach level (0.1 = +10% each level).
## Unlocks once Magnet Luck is maxed.
@export_range(0.0, 0.5, 0.05) var pickup_range_per_level: float = 0.1
