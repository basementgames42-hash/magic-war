extends Node2D
# God-Tier Combo: Endless mode's ultimate power, made from all three of the
# run's additional weapons. One weapon leads: it decides the attack (seven
# big hand-made attacks, one per weapon). The other two are infused: every
# hit also triggers their effects (chain lightning, freezing, rune
# detonations...) and the attack wears their colours. So each God-Tier looks
# and plays differently: 7 leads x 15 infusion pairs = 105 of them.
#
# Offered (in gold) by the level-up menu: three at once, one led by each of
# the run's three weapons, from BALANCE.god_min_level; one per run. Added as
# a child of the player, so it moves with them. The weapons keep working.
#
# Each lead has tick_<lead>(delta) for its attack, and optionally
# paint_<lead>() (drawn above the world) and ground_<lead>() (on the ground).
# Each infusion has infuse_<weapon>(pos, enemy), run when an attack hits.

const FX = preload("res://scenes/spells/spell_fx.gd")
const EFX = preload("res://scenes/spells/epic_fx.gd")
const STRIKE = preload("res://scenes/spells/starfall_strike.gd")
const BRAMBLE = preload("res://scenes/spells/bramble.gd")
const BALANCE: Balance = preload("res://config/balance.tres")

const GOLD := Color(1.0, 0.82, 0.3)
# Each weapon's colour: the lead's is the attack's main colour, the
# infusions' are its accents.
const COLOURS: Dictionary = {
	"lightning": Color(1.0, 0.92, 0.4), "frost": Color(0.6, 0.92, 1.0),
	"orbit": Color(0.78, 0.45, 1.0), "runeward": Color(1.0, 0.8, 0.32),
	"starfall": Color(0.85, 0.92, 1.0), "moonreaver": Color(0.7, 0.8, 1.0),
	"thornwake": Color(0.45, 0.82, 0.3),
}
# Lead -> [title, what the attack does]; infusion -> [epithet, what it adds].
const LEADS: Dictionary = {
	"lightning": ["Heavenrend Tempest", "A storm cloud follows you and hurls giant bolts at 8 enemies"],
	"frost": ["Eternal Winter", "A blizzard slows all around you as ice spires erupt in a spiral"],
	"orbit": ["Arcane Singularity", "A black hole drags crowds together, then implodes"],
	"runeward": ["Sanctum of the Ancients", "A vast rune circle burns all inside and bursts outward"],
	"starfall": ["Cataclysm", "A meteor storm of 7 burning stars smashes the crowds"],
	"moonreaver": ["Eclipse Reaper", "An eclipse scythe sweeps all around you, then crescents spiral out"],
	"thornwake": ["Wrath of the Wildwood", "Giant thorn vines erupt outward in every direction"],
}
const INFUSIONS: Dictionary = {
	"lightning": ["Storm", "chains lightning"],
	"frost": ["Frost", "freezes"],
	"orbit": ["Void", "echoes with an arcane blast"],
	"runeward": ["Rune", "leaves a rune that detonates"],
	"starfall": ["Star", "has a chance to call down a star"],
	"moonreaver": ["Moon", "releases a crescent slash"],
	"thornwake": ["Thorn", "sprouts brambles"],
}

var id: String = ""          # "lead|a+b", set before add_child (see combo_id)
var lead: String = ""
var infusions: Array[String] = []
var main: Color              # The lead's colour
var accent: Color            # First infusion's colour
var accent2: Color           # Second infusion's colour
var clock: float = 0.0
var timer: float = 0.8       # Countdown to the next main attack
var spin: float = 0.0
var cooldowns: Dictionary = {}
var patches: Array = []
var ground: Node2D

# lead|a+b with a and b in alphabetical order, so each God-Tier has one id.
static func combo_id(lead_id: String, others: Array) -> String:
	var pair: Array = others.duplicate()
	pair.sort()
	return lead_id + "|" + "+".join(pair)

static func parts(combo: String) -> Array:
	# [lead, [infusion, infusion]]
	var halves: PackedStringArray = combo.split("|")
	return [halves[0], Array(halves[1].split("+"))]

static func title(combo: String) -> String:
	var p: Array = parts(combo)
	return "%s (%s & %s)" % [LEADS[p[0]][0], INFUSIONS[p[1][0]][0], INFUSIONS[p[1][1]][0]]

static func blurb(combo: String) -> String:
	var p: Array = parts(combo)
	return "%s. Every hit also %s and %s." % [LEADS[p[0]][1], INFUSIONS[p[1][0]][1], INFUSIONS[p[1][1]][1]]

func _ready() -> void:
	var p: Array = parts(id)
	lead = p[0]
	infusions.assign(p[1])
	main = COLOURS[lead]
	accent = COLOURS[infusions[0]]
	accent2 = COLOURS[infusions[1]]
	z_index = 5
	ground = Node2D.new()
	ground.z_index = -1
	ground.z_as_relative = false
	ground.draw.connect(func():
		if has_method("ground_" + lead):
			call("ground_" + lead))
	add_child(ground)
	# The moment it's gained: a golden blast and the name across the screen.
	FX.burst(world(), global_position, GOLD, 40, 520.0, 0.7, 0.5)
	ring(global_position, 420.0, GOLD, 0.7, 14.0)
	Audio.play("nuke", -6.0, 0.0)

func _process(delta: float) -> void:
	clock += delta
	timer -= delta
	for slot in cooldowns:
		cooldowns[slot] -= delta
	call("tick_" + lead, delta)
	queue_redraw()
	ground.queue_redraw()

func _draw() -> void:
	if has_method("paint_" + lead):
		call("paint_" + lead)

# --- Helpers ---------------------------------------------------------------

func world() -> Node:
	return get_tree().current_scene

func alive(e) -> bool:
	return e != null and is_instance_valid(e) and not e.is_queued_for_deletion()

func near(pos: Vector2, radius: float) -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(e):
		return alive(e) and e.global_position.distance_to(pos) < radius)

func nearest(pos: Vector2, radius: float, skip: Array = []) -> Node2D:
	var best: Node2D = null
	var best_d: float = radius
	for e in near(pos, radius):
		var d: float = e.global_position.distance_to(pos)
		if d < best_d and not e in skip:
			best_d = d
			best = e
	return best

func power(amount: float) -> int:
	# God-Tier damage: scaled in balance.tres, and growing with every level
	# past the one it unlocks at, so it stays worth having in a long run.
	var level: int = get_parent().level if get_parent() else BALANCE.god_min_level
	var growth: float = 1.0 + BALANCE.god_damage_per_level * maxi(level - BALANCE.god_min_level, 0)
	return maxi(roundi(amount * BALANCE.god_damage_scale * growth), 1)

func smite(e, amount: float) -> void:
	# A main-attack hit: damage, then every infusion's effect on it.
	if not alive(e):
		return
	var pos: Vector2 = e.global_position
	e.take_damage(power(amount))
	for inf in infusions:
		call("infuse_" + inf, pos, e)

func every(slot: String, seconds: float, first: float = 0.0) -> bool:
	if not cooldowns.has(slot):
		cooldowns[slot] = first
	if cooldowns[slot] > 0.0:
		return false
	cooldowns[slot] = seconds
	return true

func later(seconds: float, action: Callable) -> void:
	get_tree().create_timer(seconds, false).timeout.connect(func():
		if is_inside_tree():
			action.call())

func crowd_spot(reach: float, radius: float, avoid: Array = []) -> Vector2:
	var pool: Array = near(global_position, reach)
	var best := Vector2.INF
	var best_n: int = 0
	for e in pool:
		var aim: Vector2 = e.global_position + e.velocity * 0.4
		if avoid.any(func(s): return s.distance_to(aim) < radius):
			continue
		var n: int = pool.filter(func(o): return o.global_position.distance_to(aim) < radius).size()
		if n > best_n:
			best_n = n
			best = aim
	return best

func jagged(from: Vector2, to: Vector2, segments: int = 9, wobble: float = 20.0) -> PackedVector2Array:
	var pts := PackedVector2Array([from])
	var side: Vector2 = (to - from).normalized().orthogonal()
	for i in range(1, segments):
		pts.append(from.lerp(to, float(i) / segments) + side * randf_range(-wobble, wobble))
	pts.append(to)
	return pts

func bolt(from: Vector2, to: Vector2, core: Color, glow: Color, width: float = 1.0) -> void:
	var path: Array = [jagged(from, to)]
	EFX.spawn(world(), Vector2.ZERO, 0.3, func(fx: Node2D, k: float):
		if k > 0.3 and randf() < 0.3:
			path[0] = jagged(from, to)
		var a: float = 1.0 - k
		fx.draw_polyline(path[0], Color(glow, 0.5 * a), 18.0 * width)
		fx.draw_polyline(path[0], Color(core, a), 6.0 * width)
		fx.draw_polyline(path[0], Color(1, 1, 1, a), 2.0 * width))

func ring(pos: Vector2, radius: float, color: Color, life: float = 0.45, width: float = 10.0) -> void:
	EFX.spawn(world(), pos, life, func(fx: Node2D, k: float):
		var r: float = radius * (1.0 - pow(1.0 - k, 3.0))
		fx.draw_circle(Vector2.ZERO, r, Color(color, 0.14 * (1.0 - k)))
		fx.draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(color, 1.0 - k), width * (1.0 - k * 0.6)), -1)

func crescent(at: Vector2, facing: float, size: float, color: Color, fx: Node2D) -> void:
	fx.draw_arc(at, size, facing - 1.2, facing + 1.2, 16, Color(color, color.a * 0.4), size * 0.45)
	fx.draw_arc(at, size * 1.05, facing - 1.2, facing + 1.2, 16, Color(1, 1, 1, color.a), size * 0.14)

# --- Infusions: what every hit adds --------------------------------------
# Rate-limited per infusion so a big attack doesn't bury the screen.

func infuse_lightning(pos: Vector2, e) -> void:
	if not every("inf_lightning", 0.12):
		return
	var hit: Array = [e]
	var from: Vector2 = pos
	for i in 2:
		var next: Node2D = nearest(from, 240.0, hit)
		if next == null:
			break
		bolt(from, next.global_position, COLOURS["lightning"], accent2 if infusions[0] == "lightning" else accent, 0.6)
		next.take_damage(power(22))
		hit.append(next)
		from = next.global_position

func infuse_frost(pos: Vector2, e) -> void:
	if alive(e):
		e.apply_slow(0.3, 1.6, true)
	if every("inf_frost", 0.15):
		FX.burst(world(), pos, COLOURS["frost"], 10, 200.0, 0.35, 0.3)

func infuse_orbit(pos: Vector2, _e) -> void:
	if not every("inf_orbit", 0.2):
		return
	later(0.35, func():
		ring(pos, 95.0, COLOURS["orbit"], 0.35, 8.0)
		for o in near(pos, 95.0):
			o.take_damage(power(18)))

func infuse_runeward(pos: Vector2, _e) -> void:
	if not every("inf_runeward", 0.25):
		return
	var rune := COLOURS["runeward"]
	EFX.spawn(world(), pos, 0.75, func(fx: Node2D, k: float):
		fx.draw_arc(Vector2.ZERO, 34.0, -PI / 2.0, -PI / 2.0 + TAU * k, 24, rune, 3.0)
		for i in 3:
			var a: float = TAU / 3.0 * i + k * 3.0
			fx.draw_line(Vector2.from_angle(a) * 26.0, Vector2.from_angle(a + 2.1) * 26.0, Color(rune, 0.8), 2.0), -1)
	later(0.75, func():
		ring(pos, 85.0, rune, 0.35, 9.0)
		for o in near(pos, 85.0):
			o.take_damage(power(30)))

func infuse_starfall(pos: Vector2, _e) -> void:
	if randf() > 0.3 or not every("inf_starfall", 0.3):
		return
	var s: Node2D = STRIKE.new()
	s.damage = power(34)
	s.radius = 90.0
	world().add_child(s)
	s.global_position = pos

func infuse_moonreaver(pos: Vector2, _e) -> void:
	if not every("inf_moonreaver", 0.18):
		return
	var facing: float = global_position.angle_to_point(pos)
	var moon := COLOURS["moonreaver"]
	for o in near(pos, 130.0):
		if absf(Vector2.from_angle(facing).angle_to(o.global_position - pos)) < 0.9:
			o.take_damage(power(22))
	EFX.spawn(world(), pos, 0.3, func(fx: Node2D, k: float):
		crescent(Vector2.from_angle(facing) * 70.0 * k, facing, 40.0, Color(moon, 1.0 - k), fx))

func infuse_thornwake(pos: Vector2, _e) -> void:
	patches = patches.filter(func(p): return is_instance_valid(p))
	if patches.size() >= 14 or not every("inf_thornwake", 0.3):
		return
	var p: Node2D = BRAMBLE.new()
	p.radius = 60.0
	p.lifetime = 3.0
	p.damage = power(10)
	world().add_child(p)
	p.global_position = pos
	patches.append(p)

# --- 1. Heavenrend Tempest (Lightning leads) -----------------------------
const CLOUD := Vector2(0, -190)

func tick_lightning(_delta: float) -> void:
	if timer > 0.0:
		return
	timer = 1.5
	var targets: Array = near(global_position, 560.0)
	targets.shuffle()
	targets = targets.slice(0, 8)
	for e in targets:
		var spot: Vector2 = e.global_position
		bolt(global_position + CLOUD + Vector2(randf_range(-70, 70), 0), spot, main, accent, 1.5)
		ring(spot, 70.0, accent2, 0.3, 6.0)
		smite(e, 95)
	if not targets.is_empty():
		Audio.play("lightning", -3.0, 0.1)

func paint_lightning() -> void:
	# A churning storm cloud overhead, flashing as it charges.
	var flash: float = 1.0 - clampf(timer / 1.5, 0.0, 1.0)
	for i in 7:
		var off := Vector2((i - 3) * 30.0, sin(clock * 1.5 + i) * 8.0)
		var r: float = 42.0 + 10.0 * sin(clock * 2.0 + i * 1.3)
		draw_circle(CLOUD + off, r, Color(0.16, 0.17, 0.26, 0.85))
	for i in 5:
		var off := Vector2((i - 2) * 34.0, -14.0 + sin(clock * 2.3 + i) * 6.0)
		draw_circle(CLOUD + off, 30.0, Color(main.lerp(accent, 0.5), 0.15 + 0.35 * flash))
	if randf() < 0.15 + 0.4 * flash:
		var a: Vector2 = CLOUD + Vector2(randf_range(-90, 90), 10)
		draw_polyline(jagged(a, a + Vector2(randf_range(-30, 30), 60), 4, 8.0), Color(main, 0.9), 2.5)

# --- 2. Eternal Winter (Frost leads) --------------------------------------
const WINTER_R: float = 300.0

func tick_frost(_delta: float) -> void:
	if every("chill", 0.3):
		for e in near(global_position, WINTER_R):
			e.apply_slow(0.55, 0.5, true)
	if timer > 0.0:
		return
	timer = 2.2
	Audio.play("frost_nova", -3.0, 0.05)
	ring(global_position, WINTER_R + 40.0, main, 0.5, 14.0)
	# Ice spires burst up one after another along a spiral.
	var turn: float = randf() * TAU
	for i in 12:
		var spot: Vector2 = global_position + Vector2.from_angle(turn + i * 0.85) * (60.0 + i * 22.0)
		later(0.04 * i, func():
			spire(spot)
			for e in near(spot, 75.0):
				smite(e, 80))

func spire(at: Vector2) -> void:
	var tint: Color = main.lerp(accent, 0.3)
	EFX.spawn(world(), at, 0.7, func(fx: Node2D, k: float):
		var rise: float = minf(k * 4.0, 1.0)
		var a: float = 1.0 - maxf(k - 0.6, 0.0) / 0.4
		for j in 3:  # A cluster of three crystals
			var x: float = (j - 1) * 14.0
			var h: float = (70.0 if j == 1 else 46.0) * rise
			fx.draw_colored_polygon(PackedVector2Array([Vector2(x - 11, 0), Vector2(x + 11, 0), Vector2(x, -h)]),
				Color(tint, 0.9 * a))
			fx.draw_line(Vector2(x, 0), Vector2(x, -h), Color(1, 1, 1, 0.8 * a), 2.0)
		fx.draw_circle(Vector2.ZERO, 30.0, Color(accent2, 0.25 * a)))

func ground_frost() -> void:
	var g := ground
	g.draw_circle(Vector2.ZERO, WINTER_R, Color(main, 0.1))
	g.draw_arc(Vector2.ZERO, WINTER_R, 0.0, TAU, 72, Color(main, 0.6), 3.0)
	g.draw_arc(Vector2.ZERO, WINTER_R * 0.7, 0.0, TAU, 72, Color(accent, 0.25), 2.0)
	for i in 36:  # Snow whirling round in the blizzard
		var a: float = i * 2.39996 + clock * (0.6 + 0.02 * i)
		var r: float = WINTER_R * fmod(0.15 + i * 0.071, 0.97)
		g.draw_circle(Vector2.from_angle(a) * r, 2.0 + (i % 3), Color(1, 1, 1, 0.75))

# --- 3. Arcane Singularity (Orbit leads) ----------------------------------
var hole := Vector2.INF       # Where the black hole is, while it's open
var hole_age: float = 0.0
const HOLE_PULL: float = 270.0
const HOLE_LIFE: float = 1.6

func tick_orbit(delta: float) -> void:
	spin += 2.5 * delta
	if hole != Vector2.INF:
		hole_age += delta
		for e in near(hole, HOLE_PULL):
			e.global_position = e.global_position.move_toward(hole, 220.0 * delta)
		if every("hole_tick", 0.25):
			for e in near(hole, 110.0):
				e.take_damage(power(10))
		if hole_age >= HOLE_LIFE:
			var at: Vector2 = hole
			hole = Vector2.INF
			ring(at, 230.0, main, 0.5, 16.0)
			ring(at, 160.0, accent, 0.4, 10.0)
			FX.burst(world(), at, main, 36, 460.0, 0.6, 0.45)
			Audio.play("nuke", -8.0, 0.1)
			for e in near(at, 220.0):
				smite(e, 85)
		return
	if timer > 0.0:
		return
	var spot: Vector2 = crowd_spot(600.0, 160.0)
	if spot == Vector2.INF:
		timer = 0.3
		return
	timer = 3.4
	hole = spot
	hole_age = 0.0

func paint_orbit() -> void:
	for i in 2:  # Two satellites orbit you, feeding the next black hole
		var p := Vector2.from_angle(spin + PI * i) * 90.0
		draw_circle(p, 15.0, Color(accent, 0.35))
		draw_circle(p, 9.0, main)
		draw_circle(p, 4.0, Color.WHITE)
	if hole == Vector2.INF:
		return
	var at: Vector2 = to_local(hole)
	var grow: float = minf(hole_age / 0.3, 1.0)
	draw_circle(at, HOLE_PULL * grow, Color(main, 0.06))
	for i in 5:  # Spiralling streaks being sucked in
		var a: float = clock * 5.0 + TAU / 5.0 * i
		draw_arc(at, (60.0 + 30.0 * i) * grow, a, a + 1.4, 12, Color(accent if i % 2 == 0 else accent2, 0.6), 3.0)
	draw_circle(at, 58.0 * grow, Color(main, 0.55))
	draw_circle(at, 42.0 * grow, Color(0.04, 0.02, 0.08))
	draw_arc(at, 44.0 * grow, 0.0, TAU, 32, Color(1, 1, 1, 0.8), 2.0)

# --- 4. Sanctum of the Ancients (Runeward leads) ---------------------------
const SANCTUM_R: float = 280.0

func tick_runeward(_delta: float) -> void:
	if every("burn", 0.4):
		for e in near(global_position, SANCTUM_R):
			e.take_damage(power(18))
	if timer > 0.0:
		return
	timer = 3.0
	ring(global_position, SANCTUM_R + 70.0, main, 0.5, 16.0)
	ring(global_position, SANCTUM_R + 20.0, accent, 0.45, 8.0)
	Audio.play("nuke", -9.0, 0.15)
	for e in near(global_position, SANCTUM_R + 60.0):
		smite(e, 90)
		if alive(e):
			e.global_position += (e.global_position - global_position).normalized() * 90.0

func ground_runeward() -> void:
	var g := ground
	var charge: float = 1.0 - clampf(timer / 3.0, 0.0, 1.0)
	g.draw_circle(Vector2.ZERO, SANCTUM_R, Color(main, 0.07 + 0.08 * charge))
	g.draw_arc(Vector2.ZERO, SANCTUM_R, 0.0, TAU, 96, Color(main, 0.75), 4.0)
	g.draw_arc(Vector2.ZERO, SANCTUM_R - 26.0, 0.0, TAU, 96, Color(accent, 0.5), 2.5)
	g.draw_arc(Vector2.ZERO, SANCTUM_R * 0.55, 0.0, TAU, 72, Color(accent2, 0.4), 2.0)
	for i in 6:  # A hexagram turning one way...
		var a: float = clock * 0.4 + TAU / 6.0 * i
		g.draw_line(Vector2.from_angle(a) * SANCTUM_R * 0.55, Vector2.from_angle(a + TAU / 3.0) * SANCTUM_R * 0.55,
			Color(main, 0.35 + 0.4 * charge), 2.5)
	for i in 16:  # ...and glyphs round the rim turning the other
		var a: float = -clock * 0.5 + TAU / 16.0 * i
		var at: Vector2 = Vector2.from_angle(a) * (SANCTUM_R - 13.0)
		var t: Vector2 = Vector2.from_angle(a + PI / 2.0) * 8.0
		g.draw_polyline(PackedVector2Array([at - t, at - at.normalized() * 9.0, at + t]),
			Color(main if i % 2 == 0 else accent, 0.9), 2.5)

# --- 5. Cataclysm (Starfall leads) ----------------------------------------
func tick_starfall(_delta: float) -> void:
	if timer > 0.0:
		return
	timer = 3.5
	var spots: Array = []
	for i in 7:
		var s: Vector2 = crowd_spot(620.0, 120.0, spots)
		if s == Vector2.INF:
			s = global_position + Vector2.from_angle(randf() * TAU) * randf_range(150.0, 450.0)
		spots.append(s)
	for i in spots.size():
		var s: Vector2 = spots[i]
		later(0.12 * i, func(): meteor(s))

func meteor(at: Vector2) -> void:
	var fall: float = 0.5
	var tail: Color = main.lerp(accent, 0.5)
	EFX.spawn(world(), at, fall, func(fx: Node2D, k: float):
		var tip := Vector2(-260.0, -620.0) * (1.0 - k * k)
		fx.draw_circle(Vector2.ZERO, 130.0 * k, Color(accent2, 0.14))
		fx.draw_arc(Vector2.ZERO, 130.0, 0.0, TAU, 40, Color(main, 0.6), 2.5)
		var back: Vector2 = Vector2(-0.39, -0.92) * 190.0  # Tail streams up the way it came
		fx.draw_colored_polygon(PackedVector2Array([tip + back.orthogonal().normalized() * 22.0,
			tip - back.orthogonal().normalized() * 22.0, tip + back]), Color(tail, 0.6))
		fx.draw_circle(tip, 26.0, Color(accent, 0.6))
		fx.draw_circle(tip, 18.0, main)
		fx.draw_circle(tip, 8.0, Color.WHITE))
	later(fall, func():
		FX.burst(world(), at, main, 26, 420.0, 0.5, 0.45)
		ring(at, 140.0, accent, 0.45, 12.0)
		Audio.play("fireball_hit", -4.0, 0.15)
		for e in near(at, 130.0):
			smite(e, 110)
		EFX.spawn(world(), at, 1.5, func(fx: Node2D, k: float):  # Glowing crater
			var a: float = 1.0 - k
			fx.draw_circle(Vector2.ZERO, 110.0, Color(0.12, 0.08, 0.06, 0.5 * a))
			fx.draw_circle(Vector2.ZERO, 60.0, Color(main, 0.3 * a))
			for c in 6:
				var d := Vector2.from_angle(TAU / 6.0 * c + 0.3)
				fx.draw_line(d * 30.0, d * 105.0, Color(accent, 0.6 * a), 3.0), -1))

# --- 6. Eclipse Reaper (Moonreaver leads) ---------------------------------
const ECLIPSE := Vector2(0, -150)
const SWEEP_R: float = 240.0
var sweep_age: float = -1.0   # Seconds into the current sweep (-1 = none)

func tick_moonreaver(delta: float) -> void:
	if sweep_age >= 0.0:
		sweep_age += delta
		if sweep_age > 0.4:
			sweep_age = -1.0
	if timer > 0.0:
		return
	timer = 2.4
	sweep_age = 0.0
	Audio.play("fireball_cast", -3.0, 0.1)
	for e in near(global_position, SWEEP_R):
		smite(e, 70)
	# Then six crescents spiral outward from the sweep.
	for i in 6:
		var dir := Vector2.from_angle(clock + TAU / 6.0 * i)
		var start: Vector2 = global_position
		var hit: Dictionary = {}
		EFX.spawn(world(), start, 0.7, func(fx: Node2D, k: float):
			var a: float = dir.angle() + k * 2.2
			var at: Vector2 = Vector2.from_angle(a) * (60.0 + 460.0 * k)
			crescent(at, a, 34.0, Color(accent, 1.0 - k * 0.6), fx)
			for e in near(fx.global_position + at, 60.0):
				if not hit.has(e.get_instance_id()):
					hit[e.get_instance_id()] = true
					e.take_damage(power(40)))

func paint_moonreaver() -> void:
	# The eclipse hanging over you: a dark moon in a blazing ring of light.
	var pulse: float = 0.5 + 0.5 * sin(clock * 3.0)
	draw_circle(ECLIPSE, 40.0 + 6.0 * pulse, Color(accent, 0.25))
	draw_circle(ECLIPSE, 31.0, main)
	draw_circle(ECLIPSE + Vector2(5, -3), 28.0, Color(0.05, 0.05, 0.12))
	for i in 12:  # Corona flares
		var a: float = TAU / 12.0 * i + clock * 0.5
		draw_line(ECLIPSE + Vector2.from_angle(a) * 33.0, ECLIPSE + Vector2.from_angle(a) * (42.0 + 8.0 * pulse),
			Color(accent2, 0.7), 2.0)
	if sweep_age < 0.0:
		return
	# The scythe sweep: a full circle of moonlight slicing round you.
	var k: float = sweep_age / 0.4
	var head: float = clock * 2.0 + k * TAU
	draw_arc(Vector2.ZERO, SWEEP_R * 0.8, head - 2.4, head, 32, Color(main, 0.35 * (1.0 - k)), SWEEP_R * 0.35)
	draw_arc(Vector2.ZERO, SWEEP_R, head - 2.4, head, 32, Color(1, 1, 1, 1.0 - k), 6.0)
	draw_arc(Vector2.ZERO, SWEEP_R * 0.62, head - 1.6, head, 24, Color(accent, 0.7 * (1.0 - k)), 4.0)

# --- 7. Wrath of the Wildwood (Thornwake leads) ---------------------------
const VINE_LEN: float = 380.0

func tick_thornwake(_delta: float) -> void:
	if timer > 0.0:
		return
	timer = 2.6
	var turn: float = randf() * TAU
	for i in 8:
		var dir := Vector2.from_angle(turn + TAU / 8.0 * i)
		vine(global_position, dir)
	Audio.play("orb_hit", -2.0, 0.1)

func vine(from: Vector2, dir: Vector2) -> void:
	# A thick thorny vine bursting out along the ground, hitting what it passes.
	var hit: Dictionary = {}
	var green: Color = main
	var thorn_tint: Color = accent.lerp(Color(0.9, 0.85, 0.65), 0.5)
	EFX.spawn(world(), from, 1.1, func(fx: Node2D, k: float):
		var reach: float = VINE_LEN * minf(k * 3.0, 1.0)
		var a: float = 1.0 - maxf(k - 0.65, 0.0) / 0.35
		var steps: int = 12
		var last := Vector2.ZERO
		for s in range(1, steps + 1):
			var t: float = float(s) / steps
			var p: Vector2 = dir * reach * t + dir.orthogonal() * sin(t * 9.0) * 16.0
			var w: float = lerpf(22.0, 6.0, t)
			fx.draw_line(last, p, Color(0.08, 0.1, 0.06, a), w + 5.0)
			fx.draw_line(last, p, Color(green, a), w)
			if s % 2 == 0:
				var side: Vector2 = dir.orthogonal() * (1.0 if s % 4 == 0 else -1.0)
				fx.draw_colored_polygon(PackedVector2Array([p - dir * 7.0, p + dir * 7.0,
					p + side * (w * 0.5 + 20.0) + dir * 10.0]), Color(thorn_tint, a))
			last = p
		fx.draw_circle(last, 10.0, Color(accent2, a))
		for e in near(fx.global_position, reach + 30.0):
			if hit.has(e.get_instance_id()):
				continue
			var off: Vector2 = e.global_position - fx.global_position
			var along: float = off.dot(dir)
			if along > 0.0 and along < reach and absf(off.dot(dir.orthogonal())) < 46.0:
				hit[e.get_instance_id()] = true
				smite(e, 80)
				if alive(e):
					e.apply_slow(0.3, 1.2, false), -1)
