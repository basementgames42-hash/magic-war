extends Node2D
# Main: spawns enemies (harder over time), runs the clock, spawns elites
# and (on a map) the final boss, triggers win/lose screens.

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const BALANCE: Balance = preload("res://config/balance.tres")
const REVIVE_OFFER = preload("res://scenes/ui/revive_offer.gd")
const ENEMY_SCRIPT = preload("res://scenes/enemies/enemy.gd")
const BOOST_OFFER = preload("res://scenes/ui/boost_offer.gd")
const UNLOCK_TOAST = preload("res://scenes/ui/unlock_toast.gd")
const BOSS_HUD = preload("res://scenes/ui/boss_hud.gd")
const FX = preload("res://scenes/spells/spell_fx.gd")
const ELITE_SCALE: float = 2.5  # Elite size compared with a normal enemy

@export var spawn_distance: float = 800.0
@export var elite_interval: float = 60.0    # An elite every minute
# A normal run spreads its map's enemy types evenly across the win time.
# Each new wave is tougher than the last. Wave 0 = x1.0, wave 1 = x1.15 enemy
# HP and x1.25 damage to the player.
@export var wave_health_bonus: float = 0.15
# Per-wave damage bonus is in res://config/balance.tres (wave_damage_bonus).
@export var endless_wave_interval: float = 60.0  # Endless: new type every minute

var endless: bool = false                   # Copied from GameData at start
var player: Node2D = null
var elapsed: float = 0.0
var next_elite_at: float = 60.0
var run_over: bool = false
var wave: int = 0                           # How many waves have started (0 = first)
var map: Dictionary = Levels.current()
var enemy_order: Array[Dictionary] = []     # Enemy types in wave order (see config/levels.gd)
var enemy_type: Dictionary = {}             # The type spawning now
var wave_interval: float = 60.0             # Seconds per enemy type, set in _ready
var frames_cache: Dictionary = {}           # Enemy type name -> SpriteFrames
var kills: int = 0                          # Enemies killed this run (HUD, top right)
var revives_left: int = BALANCE.revives_per_run
var revive_offer: CanvasLayer
var map_stage: int = 0                      # Endless: how many maps it has moved on
var morph_wait: float = 0.0                 # Endless: seconds until the next World.morph
# The map's final boss: arrives with BALANCE.boss_arrives_seconds_left to go;
# the map only clears once the clock is out AND the boss is dead.
var boss: CharacterBody2D = null
var boss_spawned: bool = false
var boss_down: bool = false
var boss_hud: Control

func _enter_tree() -> void:
	# Before the player's _ready, so this run's shop consumables are working
	# when it sets up its stats.
	GameData.start_run()

func _ready() -> void:
	endless = GameData.endless
	enemy_order.assign(Levels.endless_enemies() if endless else map["enemies"])
	enemy_type = enemy_order[0]
	wave_interval = endless_wave_interval if endless \
		else BALANCE.win_time_minutes * 60.0 / enemy_order.size()
	$Ground.modulate = map["ground"]
	revive_offer = REVIVE_OFFER.new()
	revive_offer.accepted.connect(_on_revive_accepted)
	revive_offer.declined.connect(finish_run)
	revive_offer.chance_used.connect(_on_second_chance_used)
	add_child(revive_offer)
	$HUD.add_child(BOOST_OFFER.new())
	boss_hud = BOSS_HUD.new()
	$HUD.add_child(boss_hud)
	WindowControls.layout_changed.connect(fit_hud)
	fit_hud()
	show_map_banner()
	player = get_tree().get_first_node_in_group("player")
	$Timer.timeout.connect(_on_spawn_timer_timeout)

	player.xp_changed.connect(_on_xp_changed)
	player.leveled_up.connect(_on_leveled_up)
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)

	update_damage_bonus()
	_on_xp_changed(player.xp, player.xp_to_next)
	_on_health_changed(player.max_health, player.max_health)

	Audio.play_music("battle")

	# Touch controls: the pause button opens the Settings menu (which pauses).
	$HUD/PauseButton.pressed.connect(WindowControls.open_settings)

	# Round gold counter.
	GameData.run_coins_changed.connect(_on_run_coins_changed)
	_on_run_coins_changed(GameData.run_coins)
	GameData.quest_completed.connect(_on_quest_completed)

	# Keep the camera inside the arena (plus a strip of the tree line).
	var camera: Camera2D = player.get_node("Camera2D")
	var edge: int = int($World.half_size + 250.0)
	camera.limit_left = -edge
	camera.limit_top = -edge
	camera.limit_right = edge
	camera.limit_bottom = edge
	update_clock()  # 05:00 from the first frame, not the scene's 00:00

func _physics_process(_delta: float) -> void:
	# Far-away enemies update in turns (see enemy.gd LOD). The view's half
	# diagonal plus a margin counts as "far", whatever the screen shape.
	ENEMY_SCRIPT.lod_tick += 1
	if ENEMY_SCRIPT.lod_tick % 30 == 0:
		var camera: Camera2D = player.get_node("Camera2D") if player else null
		if camera:
			ENEMY_SCRIPT.far_distance = (get_viewport_rect().size / camera.zoom).length() * 0.5 + 250.0

func _process(delta: float) -> void:
	if run_over:
		return
	elapsed += delta
	update_clock()  # First, so a win leaves the countdown on 00:00

	if not endless:
		var left: float = BALANCE.win_time_minutes * 60.0 - elapsed
		if not boss_spawned and left <= BALANCE.boss_arrives_seconds_left:
			spawn_boss()
		# Clock out and boss dead: victory. With the boss still up, play on
		# (the clock reads BOSS) until it falls. (Endless has no finish line.)
		if left <= 0.0 and boss_down:
			win_level()
			return

	# Difficulty ramp: spawn faster as time passes. 1.0s at start, floor of
	# 0.25s (reached at ~2.5 min). Harder maps and a stronger player both
	# shorten it further.
	$Timer.wait_time = clamp(1.0 - elapsed * 0.005, 0.25, 1.0) \
		/ (map["spawn"] * (1.0 + levels_gained() * BALANCE.spawn_rate_per_player_level))

	# New wave: everything that spawns from now on is the next type in
	# order, with tougher stats.
	var current_wave: int = int(elapsed / wave_interval)
	if current_wave != wave:
		wave = current_wave
		if endless:
			enemy_type = enemy_order[wave % enemy_order.size()]
		else:
			enemy_type = enemy_order[mini(wave, enemy_order.size() - 1)]
		update_damage_bonus()
	if endless:
		$HUD/TimerLabel.text += "  ·  Wave %d" % (wave + 1)
		drift_map(delta)
		check_unlocks()

	# Elite alarm.
	if elapsed >= next_elite_at:
		next_elite_at += elite_interval
		spawn_elite()

func update_clock() -> void:
	# Endless counts up (how long you've lasted). A map counts down to the
	# level clear: 05:00 at the start, 00:00 = victory. The last 10 seconds
	# glow red and pulse.
	var clock: Label = $HUD/TimerLabel
	if endless:
		clock.text = format_time(elapsed)
		return
	var left: float = maxf(BALANCE.win_time_minutes * 60.0 - elapsed, 0.0)
	clock.text = "BOSS" if left <= 0.0 and boss_spawned and not boss_down else format_time(ceilf(left))
	var final: bool = left <= 10.0
	clock.modulate = Color(1.0, 0.45, 0.4) if final else Color.WHITE
	clock.pivot_offset = clock.size / 2.0
	clock.scale = Vector2.ONE * (1.0 + 0.08 * absf(sin(elapsed * PI)) if final else 1.0)

func drift_map(delta: float) -> void:
	# Endless: hold each map for a while, then drift slowly into the next one
	# (see the Endless Mode knobs in balance.tres). Loops back after the last.
	var hold: float = BALANCE.endless_map_minutes * 60.0
	var blend: float = BALANCE.endless_blend_minutes * 60.0
	var stage: int = int(elapsed / (hold + blend))
	var into: float = elapsed - stage * (hold + blend)
	var from: int = stage % Levels.MAPS.size()
	var to: int = (stage + 1) % Levels.MAPS.size()
	var t: float = smoothstep(hold, hold + blend, into)
	$Ground.modulate = Levels.MAPS[from]["ground"].lerp(Levels.MAPS[to]["ground"], t)
	if stage != map_stage:
		map_stage = stage
		show_map_banner(Levels.MAPS[from]["name"].to_upper())  # Fully arrived
	morph_wait -= delta
	if morph_wait <= 0.0:
		morph_wait = 0.25
		$World.morph(from, to, t, camera_view())

func camera_view() -> Rect2:
	# What the camera sees, plus a margin so props change well out of sight.
	var camera: Camera2D = player.get_node("Camera2D")
	var half: Vector2 = get_viewport_rect().size / camera.zoom * 0.5 + Vector2(300, 300)
	return Rect2(camera.get_screen_center_position() - half, half * 2.0)

func _notification(what: int) -> void:
	# Phone call, app switch, tab hidden: pause rather than die off-screen.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not run_over \
			and not get_tree().paused:
		WindowControls.open_settings()

func _on_xp_changed(current_xp: int, xp_needed: int) -> void:
	$HUD/XPBar.max_value = xp_needed
	$HUD/XPBar.value = current_xp

func _on_leveled_up(new_level: int) -> void:
	$HUD/LevelLabel.text = "Level %d" % new_level
	update_damage_bonus()
	$LevelUpMenu.open()
	GameData.quest_best("level", new_level)
	if endless:
		check_unlocks()  # Level milestones count the moment they're reached

func check_unlocks() -> void:
	# Endless milestones (config/characters.gd) unlock heroes for both modes.
	# GameData saves at once and the toast celebrates it without pausing
	# anything. The run carries on with the hero it started with: the new one
	# is only offered on the hero select screen, for the next run.
	var fresh: Array[String] = GameData.check_endless_unlocks(player.level, elapsed)
	for i in fresh.size():
		var toast: CanvasLayer = UNLOCK_TOAST.new()
		toast.character = Characters.by_id(fresh[i])
		toast.delay = i * 5.5
		add_child(toast)

func levels_gained() -> int:
	return player.level - 1

func wave_strength() -> float:
	# How many waves' worth of toughness enemies have. A normal map only has
	# five waves, so it's just the wave number; a long endless run counts the
	# waves after the first few at a reduced rate, so it keeps getting harder
	# without suddenly becoming unwinnable.
	var full: int = BALANCE.endless_full_waves
	if not endless or wave <= full:
		return float(wave)
	return full + (wave - full) * BALANCE.endless_late_wave_factor

func enemy_speed_scale() -> float:
	# From the Nth enemy type on (balance.tres), enemies start slower, then
	# creep up a little with every full minute, capped. Elites follow it too.
	if wave + 1 < BALANCE.later_enemy_from_type:
		return 1.0
	var ramp: float = minf(int(elapsed / 60.0) * BALANCE.enemy_speed_per_minute,
		BALANCE.enemy_speed_max_bonus)
	return BALANCE.later_enemy_speed * (1.0 + ramp)

func update_damage_bonus() -> void:
	# Every hit the player takes gets stronger with each new enemy type, on
	# harder maps, and as the player levels up — including hits from enemies
	# already on the field.
	player.wave_damage_bonus = wave_strength() * BALANCE.wave_damage_bonus + map["damage"] \
		+ levels_gained() * BALANCE.damage_per_player_level

func _on_health_changed(current_hp: int, max_hp: int) -> void:
	$HUD/HPBar.max_value = max_hp
	$HUD/HPBar.value = current_hp
	$HUD/HPBar/HPLabel.text = "%d / %d" % [maxi(current_hp, 0), max_hp]

func win_level() -> void:
	run_over = true
	var index: int = GameData.level_index
	var testing: bool = not GameData.test_map.is_empty()
	var stats: Dictionary = run_stats()
	if not testing:  # A test map unlocks nothing
		GameData.quest_add("win", 1)
		var unlocked_before: int = GameData.levels_unlocked
		GameData.complete_level(index)
		if GameData.levels_unlocked > unlocked_before:
			# First win here: the victory screen and map select both celebrate it.
			stats["unlocked_map"] = GameData.levels_unlocked - 1
			GameData.map_to_celebrate = GameData.levels_unlocked - 1
	GameData.save_game()
	Audio.stop_music()
	Audio.play("victory", 0.0, 0.0)
	if testing:
		$GameOverScreen.open("TEST COMPLETE", "You survived %s." % map["name"], stats, true)
	elif index + 1 < Levels.MAPS.size():
		stats["next_level"] = index + 1
		$GameOverScreen.open("VICTORY!", "%s has fallen. %s awaits." % [boss_name(),
			Levels.MAPS[index + 1]["name"]], stats, true)
	else:
		$GameOverScreen.open("VICTORY!", "%s has fallen. You ended the Magic War." % boss_name(),
			stats, true)

func _on_player_died() -> void:
	# revives_left below 0 = unlimited (BALANCE.revives_per_run = -1).
	# A Second Chance (Shop) works even where there are no ads.
	var ad: bool = revives_left != 0 and Ads.is_available()
	if ad or GameData.second_chances() > 0:
		get_tree().paused = true
		revive_offer.open(GameData.second_chances(), ad)
	else:
		finish_run()

func _on_second_chance_used() -> void:
	if GameData.use_second_chance():
		get_tree().paused = false
		player.revive()
	else:
		_on_player_died()

func _on_revive_accepted() -> void:
	Ads.show_rewarded(_on_revive_ad_finished)

func _on_revive_ad_finished(rewarded: bool) -> void:
	if rewarded:
		if revives_left > 0:
			revives_left -= 1
		get_tree().paused = false
		player.revive()
	else:
		_on_player_died()  # Skipped: the choice stands

func finish_run() -> void:
	get_tree().paused = false
	run_over = true
	var stats: Dictionary = run_stats()
	if endless:
		GameData.quest_best("endless_minutes", int(elapsed / 60.0))
		# Personal best for endless runs (saved with the rest of GameData).
		stats["best"] = GameData.endless_best
		stats["new_record"] = elapsed > GameData.endless_best
		if stats["new_record"]:
			GameData.endless_best = elapsed
			stats["best"] = elapsed
	GameData.save_game()  # ← new
	Audio.stop_music()
	Audio.play("defeat", 0.0, 0.0)
	var survived: String = format_time(elapsed)
	if endless:
		$GameOverScreen.open("DEFEATED", "You lasted %s in Endless." % survived, stats, false)
	else:
		var left: float = ceilf(maxf(BALANCE.win_time_minutes * 60.0 - elapsed, 0.0))
		$GameOverScreen.open("DEFEATED", "%s%s was left on the clock." % [
			"So close! " if left <= 60.0 else "", format_time(left)], stats, false)

func _on_quest_completed(text: String) -> void:
	# A banner at the top for a few seconds. It ignores the mouse and keeps
	# going while paused, so it never gets in the way.
	var label := Label.new()
	label.text = "Quest complete: " + text
	label.theme_type_variation = &"DarkLabel"
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02))
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position.y = 120
	$HUD.add_child(label)
	label.position.x = (get_viewport().get_visible_rect().size.x - label.size.x) / 2.0
	Audio.play("level_up", -6.0, 0.0)
	var t := label.create_tween()
	t.tween_interval(3.0)
	t.tween_property(label, "modulate:a", 0.0, 0.6)
	t.tween_callback(label.queue_free)

static func format_time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _on_run_coins_changed(amount: int) -> void:
	$HUD/GoldCounter/GoldLabel.text = str(amount)

func _on_enemy_killed() -> void:
	kills += 1
	$HUD/GoldCounter/KillLabel.text = str(kills)
	GameData.quest_add("kill", 1)

func boss_name() -> String:
	return map.get("boss", "The Warlord")

func spawn_boss() -> void:
	# A giant version of the map's last enemy type, with its own brain, a
	# name, a health bar, boss music and a "BOSS INCOMING" announcement.
	boss_spawned = true
	var final_type: Dictionary = enemy_order.back()
	var spawning: Dictionary = enemy_type
	enemy_type = final_type  # make_enemy() builds whatever enemy_type is
	boss = make_enemy()
	enemy_type = spawning
	boss.is_boss = true
	# Always hits for boss_damage, even when its kind is a flat 1-damage enemy
	# (Duskwood's boss is a giant Panda).
	boss.flat_hit = false
	boss.max_health = roundi(BALANCE.boss_health * map["health"]
		* (1.0 + levels_gained() * BALANCE.boss_health_per_player_level))
	boss.move_speed = BALANCE.enemy_speed * final_type["speed"] * enemy_speed_scale()
	boss.contact_damage = BALANCE.boss_damage
	boss.coin_drop = BALANCE.boss_coins
	boss.xp_drop = BALANCE.boss_xp
	# Same big-sheet correction as elites, so a minotaur boss isn't enormous.
	var frame_height: float = boss.custom_frames.get_frame_texture(&"run", 0).get_height()
	# Swapped with the last elite's size (see spawn_elite).
	boss.scale = Vector2.ONE * ELITE_SCALE * minf(192.0 / frame_height, 1.0)
	boss.killed.connect(_on_boss_killed)
	add_child(boss)
	boss_hud.announce(boss_name(), boss)
	Audio.play("boss_warning", 0.0, 0.0)
	Audio.play_music("boss")

func _on_boss_killed() -> void:
	boss_down = true
	boss_hud.defeated()
	for color in [Color(1.0, 0.85, 0.35), Color(1.0, 0.4, 0.15), Color.WHITE]:
		FX.burst(self, boss.global_position, color, 30, 520.0, 0.9, 0.6)
	Audio.play("nuke", -2.0, 0.0)
	if BALANCE.win_time_minutes * 60.0 - elapsed > 0.0:
		Audio.play_music("battle")  # Time still left: back to the battle tune
		return
	# Slain after the clock ran out: a moment to enjoy it, then victory.
	get_tree().create_timer(1.4, false).timeout.connect(func():
		if not run_over:
			win_level())

func run_stats() -> Dictionary:
	# Everything the game-over recap shows.
	return {
		"level": player.level,
		"gold": GameData.run_coins,
		"weapon": player.character["weapon_name"],
		"spells": $LevelUpMenu.weapon_recap(),
		"upgrades": $LevelUpMenu.upgrades_taken,
		"endless": endless,
		"wave": wave + 1,
		"time": elapsed,
		"kills": kills,
	}

func spawn_point() -> Vector2:
	return open_spot_near(player.global_position, spawn_distance)

func open_spot_near(center: Vector2, distance: float) -> Vector2:
	# A spot `distance` from `center`, inside the arena and not inside a
	# building/tree. Tries a few random angles before giving up.
	var space := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 4 | 8  # Obstacles and rocks (see prop.gd)
	var pos: Vector2 = Vector2.ZERO
	for attempt in 8:
		var angle: float = randf() * TAU
		pos = $World.clamp_to_arena(center + Vector2.from_angle(angle) * distance, 80.0)
		query.position = pos
		if space.intersect_point(query, 1).is_empty():
			return pos
	return pos

func _on_spawn_timer_timeout() -> void:
	if run_over or get_tree().get_node_count_in_group("enemies") >= enemy_cap():
		return
	spawn_enemy()

func apply_scaling(enemy: CharacterBody2D) -> void:
	# Call after the enemy's base stats are set, before add_child. Tougher
	# with each wave, each map and each level the player has gained.
	# (Damage scales on the player instead — see update_damage_bonus.)
	enemy.max_health = roundi(enemy.max_health * enemy_type["health"] * map["health"]
		* (1.0 + wave_strength() * wave_health_bonus)
		* (1.0 + levels_gained() * BALANCE.health_per_player_level))

func get_enemy_frames() -> SpriteFrames:
	var type_name: String = enemy_type["name"]
	if not frames_cache.has(type_name):
		frames_cache[type_name] = build_enemy_frames(enemy_type)
	return frames_cache[type_name]

func build_enemy_frames(type: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	# [animation name, sheet suffix, fps] — same names/speeds for every enemy.
	for entry in [[&"run", type["run"], 10.0], [&"attack", type["attack"], 12.0]]:
		var sheet: Texture2D = load(Levels.sheet(type, entry[1]))
		frames.add_animation(entry[0])
		frames.set_animation_speed(entry[0], entry[2])
		frames.set_animation_loop(entry[0], true)
		# Sheets are one row of square frames, so height = frame size.
		var frame_size: int = sheet.get_height()
		for i in sheet.get_width() / frame_size:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * frame_size, 0, frame_size, frame_size)
			frames.add_frame(entry[0], atlas)
	return frames

func make_enemy() -> CharacterBody2D:
	var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()
	enemy.custom_frames = get_enemy_frames()
	enemy.ai = enemy_type["ai"]
	enemy.flat_hit = enemy_type.get("flat_damage", false)
	enemy.variant_tint = enemy_type.get("tint", Color.WHITE)
	enemy.global_position = spawn_point()
	enemy.killed.connect(_on_enemy_killed)
	return enemy

static func enemy_cap() -> int:
	return BALANCE.max_enemies_web if OS.has_feature("web") else BALANCE.max_enemies

func spawn_enemy() -> void:
	if player == null:
		return
	var enemy: CharacterBody2D = make_enemy()
	enemy.move_speed *= enemy_type["speed"] * enemy_speed_scale()
	enemy.scale *= enemy_type.get("scale", 1.0)  # Oversized sheets (troll) drawn smaller

	# Enemies get extra max HP per full minute elapsed. Setting it BEFORE
	# add_child works because _ready (health = max_health) runs on add.
	enemy.max_health += int(elapsed / 60.0) * BALANCE.enemy_health_per_minute
	apply_scaling(enemy)

	add_child(enemy)

func spawn_elite() -> void:
	if player == null:
		return
	# An elite is a regular enemy with cranked stats — no new scene needed.
	var elite: CharacterBody2D = make_enemy()
	elite.coin_drop = BALANCE.coins_per_elite
	# Elite goblins hit harder than their small kin, still as flat damage.
	elite.flat_contact = BALANCE.elite_goblin_hit
	elite.flat_fire = BALANCE.elite_goblin_fire
	# Base elite stats come from res://config/balance.tres.
	elite.max_health = BALANCE.elite_health + int(elapsed / 60.0) * BALANCE.elite_health_per_minute
	elite.move_speed = BALANCE.elite_speed * enemy_type["speed"] * enemy_speed_scale()  # Slower, scarier
	elite.contact_damage = BALANCE.elite_damage
	elite.xp_drop = 10              # Kill reward: a shower of orbs
	elite.killed.connect(GameData.quest_add.bind("elite", 1))
	# Physically huge. Sheets bigger than the usual 192px frame need less
	# scaling, or a minotaur elite would hide the player completely.
	var frame_height: float = elite.custom_frames.get_frame_texture(&"run", 0).get_height()
	# Regular maps: the last enemy type's elite takes the boss's size and the
	# boss takes the elite size, so the boss always looks bigger than its kin.
	var elite_size: float = ELITE_SCALE
	if not endless and enemy_type == enemy_order.back():
		elite_size = BALANCE.boss_scale
	elite.scale = Vector2.ONE * elite_size * minf(192.0 / frame_height, 1.0)
	apply_scaling(elite)

	add_child(elite)

func fit_hud() -> void:
	# Too narrow for the clock beside the health bar: it drops to the next row.
	var clock: Label = $HUD/TimerLabel
	clock.offset_top = 92.0 if WindowControls.is_narrow() else 26.0
	clock.offset_bottom = clock.offset_top + 60.0

func show_map_banner(text: String = "") -> void:
	# The map's name fades out over the first few seconds of a run (and in
	# endless, again each time it reaches a new map).
	var banner := Label.new()
	if text == "":
		text = "ENDLESS" if endless else map["name"].to_upper()
	banner.text = text
	banner.theme_type_variation = &"GoldRibbon"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -220.0
	banner.offset_right = 220.0
	banner.offset_top = 170.0 if WindowControls.is_narrow() else 130.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(banner)
	var tween := banner.create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(banner, "modulate:a", 0.0, 1.0)
	tween.tween_callback(banner.queue_free)
