extends Node2D
# Epic Combo: a special ability made from two of the run's additional weapons
# (Lightning, Frost, Orbit, Runeward, Starfall, Moonreaver, Thornwake), with
# traits of both. 21 pairs, each with its own attack and look. Offered (in
# purple) by the level-up menu from level 13; at most 2 per run. Added as a
# child of the player, so it moves with them. The two weapons keep working.
#
# Each combo is three optional methods named after its id ("+" -> "_"):
#   tick_<id>(delta)  - the attack logic, every frame
#   paint_<id>()      - anything drawn around the player, above the world
#   ground_<id>()     - anything drawn around the player, on the ground
# Damage numbers below are scaled by BALANCE.epic_damage_scale.

const FX = preload("res://scenes/spells/spell_fx.gd")
const EFX = preload("res://scenes/spells/epic_fx.gd")
const BLADE = preload("res://scenes/spells/moonreaver_blade.gd")
const STRIKE = preload("res://scenes/spells/starfall_strike.gd")
const BRAMBLE = preload("res://scenes/spells/bramble.gd")
const BALANCE: Balance = preload("res://config/balance.tres")

# Element colours, so every combo wears both of its parents' colours.
const BOLT := Color(1.0, 0.92, 0.4)
const BOLT_GLOW := Color(0.45, 0.65, 1.0, 0.5)
const ICE := Color(0.62, 0.92, 1.0)
const ARCANE := Color(0.78, 0.45, 1.0)
const RUNE := Color(1.0, 0.82, 0.35)
const STAR := Color(0.85, 0.92, 1.0)
const MOON := Color(0.9, 0.95, 1.0)
const THORN := Color(0.45, 0.8, 0.3)

# id -> name and the line the level-up menu shows. Ids are the two weapon
# ids in alphabetical order, joined by "+" (see combo_id).
const COMBOS: Dictionary = {
	"frost+lightning": ["Frozen Tempest", "Chain lightning leaps through 5 enemies, freezing each one"],
	"lightning+orbit": ["Storm Satellites", "3 storm orbs circle you, zapping anything near them"],
	"lightning+runeward": ["Thunder Sigil", "A rune circle calls bolts from the sky onto everything inside"],
	"lightning+starfall": ["Thunderstar", "Stars crash on crowds and burst into chain lightning"],
	"lightning+moonreaver": ["Storm Reaver", "A charged blade that zaps enemies as it flies"],
	"lightning+thornwake": ["Voltaic Briars", "Brambles in your path, linked by arcs that shock enemies"],
	"frost+orbit": ["Glacier Orbit", "Ice shards orbit wide and fast, freezing what they hit"],
	"frost+runeward": ["Permafrost Ward", "A frozen zone around you slows and chills all inside"],
	"frost+starfall": ["Comet Hail", "Ice comets slam into crowds and leave frozen ground"],
	"frost+moonreaver": ["Frostfang Reaver", "An ice blade freezes its path and bursts into a nova"],
	"frost+thornwake": ["Rime Thorns", "Icy brambles that freeze enemies caught in them"],
	"orbit+runeward": ["Arcane Bastion", "Orbs ride a rune ring that pulses and knocks enemies back"],
	"orbit+starfall": ["Astral Orrery", "4 orbiting stars launch one by one onto crowds"],
	"moonreaver+orbit": ["Crescent Halo", "Crescent blades orbit you, then all fly outward"],
	"orbit+thornwake": ["Thorned Orbit", "Orbiting orbs seed brambles wherever they pass"],
	"runeward+starfall": ["Celestial Seal", "A golden seal marks a crowd, then a pillar of starlight falls"],
	"moonreaver+runeward": ["Rune Reaver", "6 golden blades burst from a rune ring in every direction"],
	"runeward+thornwake": ["Verdant Ward", "A living hedge of thorns rings you, snaring all who cross"],
	"moonreaver+starfall": ["Meteor Glaive", "A thrown blade calls stars down along its whole path"],
	"starfall+thornwake": ["Starbloom", "Falling stars sprout big bramble patches where they land"],
	"moonreaver+thornwake": ["Thornwhip Reaver", "A blade that leaves a line of thorns along its path"],
}

var id: String = ""          # A COMBOS key; set before add_child
var key: String = ""         # id with "+" -> "_", for the method names
var clock: float = 0.0       # Seconds since this combo was gained
var timer: float = 0.6       # Countdown to the next main attack
var spin: float = 0.0        # Orbit angle for the orbiting combos
var cooldowns: Dictionary = {}   # "slot" -> seconds, for extra timers
var hit_at: Dictionary = {}      # enemy id -> clock time it may be hit again
var patches: Array = []          # Bramble patches this combo planted
var zones: Array = []            # [position, radius, until] frozen ground
var blade: Node2D = null         # The thrown blade, for the blade combos
var blade_path: Array[Vector2] = []
var last_drop: Vector2 = Vector2.INF
var ground: Node2D               # Draws the on-the-ground part

static func combo_id(a: String, b: String) -> String:
	var pair: Array[String] = [a, b]
	pair.sort()
	return "+".join(pair)

func _ready() -> void:
	key = id.replace("+", "_")
	z_index = 5  # Above the y-sorted world
	ground = Node2D.new()
	ground.z_index = -1
	ground.z_as_relative = false
	ground.draw.connect(func():
		if has_method("ground_" + key):
			call("ground_" + key))
	add_child(ground)

func _process(delta: float) -> void:
	clock += delta
	timer -= delta
	for slot in cooldowns:
		cooldowns[slot] -= delta
	call("tick_" + key, delta)
	queue_redraw()
	ground.queue_redraw()

func _draw() -> void:
	if has_method("paint_" + key):
		call("paint_" + key)

# --- Helpers -----------------------------------------------------------------

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

func hurt(e, amount: float, slow: float = 0.0, slow_time: float = 0.0, frozen: bool = true) -> void:
	if not alive(e):
		return
	e.take_damage(maxi(roundi(amount * BALANCE.epic_damage_scale), 1))
	if slow > 0.0 and alive(e):
		e.apply_slow(slow, slow_time, frozen)

func ready_to_hit(e, every: float) -> bool:
	# Per-enemy cooldown, for things that touch enemies every frame (orbs).
	var at: float = hit_at.get(e.get_instance_id(), -1.0)
	if clock < at:
		return false
	hit_at[e.get_instance_id()] = clock + every
	return true

func every(slot: String, seconds: float, first: float = 0.0) -> bool:
	# True once each `seconds` per slot: a timer for the second attack.
	if not cooldowns.has(slot):
		cooldowns[slot] = first
	if cooldowns[slot] > 0.0:
		return false
	cooldowns[slot] = seconds
	return true

func crowd_spot(reach: float, radius: float, avoid: Array = []) -> Vector2:
	# Where the most enemies are within `reach`, aimed ahead of their walk.
	var pool: Array = near(global_position, reach)
	var best := Vector2.INF
	var best_n: int = 0
	for e in pool:
		var aim: Vector2 = e.global_position + e.velocity * STRIKE.DROP_TIME
		if avoid.any(func(s): return s.distance_to(aim) < radius):
			continue
		var n: int = pool.filter(func(o): return o.global_position.distance_to(aim) < radius).size()
		if n > best_n:
			best_n = n
			best = aim
	return best

func aim_dir() -> Vector2:
	var e: Node2D = nearest(global_position, 700.0)
	return (e.global_position - global_position).normalized() if e else Vector2.from_angle(randf() * TAU)

func jagged(from: Vector2, to: Vector2, segments: int = 8, wobble: float = 16.0) -> PackedVector2Array:
	var pts := PackedVector2Array([from])
	var side: Vector2 = (to - from).normalized().orthogonal()
	for i in range(1, segments):
		pts.append(from.lerp(to, float(i) / segments) + side * randf_range(-wobble, wobble))
	pts.append(to)
	return pts

func bolt(from: Vector2, to: Vector2, core: Color = BOLT, glow: Color = BOLT_GLOW) -> void:
	# A zig-zag bolt that flickers once and fades, drawn in world space.
	# (Kept in an array: a lambda gets copies of plain locals, but shares arrays.)
	var path: Array = [jagged(from, to)]
	EFX.spawn(world(), Vector2.ZERO, 0.25, func(fx: Node2D, k: float):
		if k > 0.35 and randf() < 0.3:
			path[0] = jagged(from, to)
		var a: float = 1.0 - k
		fx.draw_polyline(path[0], Color(glow, glow.a * a), 12.0)
		fx.draw_polyline(path[0], Color(core, a), 4.0)
		fx.draw_polyline(path[0], Color(1, 1, 1, a), 1.5))

func ring(pos: Vector2, radius: float, color: Color, life: float = 0.4, width: float = 8.0) -> void:
	EFX.spawn(world(), pos, life, func(fx: Node2D, k: float):
		var r: float = radius * (1.0 - pow(1.0 - k, 3.0))
		fx.draw_circle(Vector2.ZERO, r, Color(color, 0.12 * (1.0 - k)))
		fx.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(color, 1.0 - k), width * (1.0 - k * 0.6)), -1)

func throw_blade(dir: Vector2, dmg: float, tint: Color) -> Node2D:
	var b: Node2D = BLADE.new()
	b.direction = dir
	b.damage = maxi(roundi(dmg * BALANCE.epic_damage_scale), 1)
	b.thrower = get_parent()
	b.modulate = tint
	world().add_child(b)
	b.global_position = global_position
	var trail: CPUParticles2D = FX.trail(tint, 24, 0.35, 0.35)
	b.add_child(trail)
	return b

func patch_at(pos: Vector2, radius: float, dmg: float, life: float, tint: Color) -> Node2D:
	var p: Node2D = BRAMBLE.new()
	p.radius = radius
	p.lifetime = life
	p.damage = maxi(roundi(dmg * BALANCE.epic_damage_scale), 1)
	p.modulate = tint
	world().add_child(p)
	p.global_position = pos
	patches.append(p)
	patches = patches.filter(func(x): return is_instance_valid(x))
	return p

func star_at(pos: Vector2, dmg: float, radius: float) -> void:
	var s: Node2D = STRIKE.new()
	s.damage = maxi(roundi(dmg * BALANCE.epic_damage_scale), 1)
	s.radius = radius
	world().add_child(s)
	s.global_position = pos

func later(seconds: float, action: Callable) -> void:
	# Runs action after a delay that pauses with the game.
	get_tree().create_timer(seconds, false).timeout.connect(func():
		if is_inside_tree():
			action.call())

func orbit_points(count: int, radius: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in count:
		out.append(Vector2.from_angle(spin + TAU / count * i) * radius)
	return out

func touch_orbs(points: Array[Vector2], reach: float, dmg: float, cd: float,
		slow: float = 0.0, slow_time: float = 0.0) -> void:
	for p in points:
		for e in near(global_position + p, reach):
			if ready_to_hit(e, cd):
				hurt(e, dmg, slow, slow_time)

func draw_star(at: Vector2, size: float, color: Color, turn: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var r: float = size if i % 2 == 0 else size * 0.45
		pts.append(at + Vector2.from_angle(turn + TAU / 10.0 * i - PI / 2.0) * r)
	draw_colored_polygon(pts, color)

func falling(pos: Vector2, life: float, head: Color, trail: Color, sparky: bool) -> void:
	# A comet/star dropping onto pos from high above, its tail behind it.
	EFX.spawn(world(), pos, life, func(fx: Node2D, k: float):
		var y: float = -520.0 * (1.0 - k * k)
		var tip := Vector2(0, y)
		if sparky:
			fx.draw_polyline(jagged(tip + Vector2(0, -150), tip, 5, 10.0), Color(trail, 0.8), 4.0)
		else:
			fx.draw_colored_polygon(PackedVector2Array([tip + Vector2(-14, 0), tip + Vector2(14, 0),
				tip + Vector2(0, -150)]), Color(trail, 0.6))
		fx.draw_circle(Vector2.ZERO, 70.0 * k, Color(head, 0.12))
		fx.draw_arc(Vector2.ZERO, 80.0, 0.0, TAU, 32, Color(head, 0.5), 2.0)
		fx.draw_circle(tip, 16.0, head)
		fx.draw_circle(tip, 7.0, Color.WHITE))

# --- 1. Frozen Tempest (Lightning + Frost) -----------------------------------
func tick_frost_lightning(_delta: float) -> void:
	if timer > 0.0:
		return
	timer = 1.4
	var from: Vector2 = global_position
	var hit: Array = []
	var target: Node2D = nearest(from, 420.0)
	for i in 5:
		if target == null:
			break
		bolt(from, target.global_position, ICE, Color(0.4, 0.8, 1.0, 0.55))
		hurt(target, 32, 0.5, 2.0)
		FX.burst(world(), target.global_position, ICE, 12, 220.0, 0.35, 0.3)
		hit.append(target)
		from = target.global_position
		target = nearest(from, 230.0, hit)
	if not hit.is_empty():
		Audio.play("lightning", -6.0, 0.1)

# --- 2. Storm Satellites (Lightning + Orbit) ---------------------------------
func tick_lightning_orbit(delta: float) -> void:
	spin += 2.2 * delta
	var orbs := orbit_points(3, 130.0)
	for i in 3:
		if every("orb%d" % i, 0.45, 0.15 * i):
			var from: Vector2 = global_position + orbs[i]
			var e: Node2D = nearest(from, 230.0)
			if e:
				bolt(from, e.global_position)
				hurt(e, 18)

func paint_lightning_orbit() -> void:
	draw_arc(Vector2.ZERO, 130.0, 0.0, TAU, 48, Color(BOLT_GLOW, 0.25), 2.0)
	for p in orbit_points(3, 130.0):
		draw_circle(p, 17.0, Color(0.45, 0.65, 1.0, 0.35))
		draw_circle(p, 10.0, BOLT)
		draw_circle(p, 4.5, Color.WHITE)
		for j in 2:  # Little crackles around each orb
			var a: float = randf() * TAU
			draw_polyline(jagged(p + Vector2.from_angle(a) * 10.0, p + Vector2.from_angle(a) * 26.0, 3, 5.0),
				Color(BOLT, 0.8), 2.0)

# --- 3. Thunder Sigil (Lightning + Runeward) ---------------------------------
const SIGIL_R: float = 200.0
func tick_lightning_runeward(_delta: float) -> void:
	if timer > 0.0:
		return
	timer = 2.0
	var inside: Array = near(global_position, SIGIL_R).slice(0, 12)
	for e in inside:
		var spot: Vector2 = e.global_position
		bolt(spot + Vector2(randf_range(-40, 40), -460), spot)
		hurt(e, 32)
	ring(global_position, SIGIL_R, BOLT, 0.35)
	if not inside.is_empty():
		Audio.play("lightning", -4.0, 0.1)

func ground_lightning_runeward() -> void:
	var g := ground
	var charge: float = 1.0 - clampf(timer / 2.0, 0.0, 1.0)  # Brightens before each strike
	g.draw_circle(Vector2.ZERO, SIGIL_R, Color(RUNE, 0.06 + 0.08 * charge))
	g.draw_arc(Vector2.ZERO, SIGIL_R, 0.0, TAU, 64, Color(BOLT, 0.5 + 0.4 * charge), 3.0)
	g.draw_arc(Vector2.ZERO, SIGIL_R - 16.0, 0.0, TAU, 64, Color(RUNE, 0.35), 2.0)
	for i in 8:  # Rune marks turning slowly around the rim
		var a: float = clock * 0.6 + TAU / 8.0 * i
		var at: Vector2 = Vector2.from_angle(a) * (SIGIL_R - 8.0)
		var t: Vector2 = Vector2.from_angle(a + PI / 2.0) * 7.0
		g.draw_polyline(PackedVector2Array([at - t, at + t * 0.4 - at.normalized() * 8.0, at + t]),
			Color(BOLT, 0.8), 2.5)

# --- 4. Thunderstar (Lightning + Starfall) -----------------------------------
func tick_lightning_starfall(_delta: float) -> void:
	if timer > 0.0:
		return
	timer = 2.6
	var spots: Array = []
	for i in 2:
		var s: Vector2 = crowd_spot(560.0, 110.0, spots)
		if s != Vector2.INF:
			spots.append(s)
	for s in spots:
		falling(s, STRIKE.DROP_TIME, BOLT, BOLT, true)
		later(STRIKE.DROP_TIME, func():
			var hit: Array = near(s, 110.0)
			for e in hit:
				hurt(e, 22)
			FX.burst(world(), s, BOLT, 18, 300.0, 0.4, 0.4)
			# Then lightning jumps out to a few more enemies around the crater.
			var from: Vector2 = s
			for j in 3:
				var e: Node2D = nearest(s, 280.0, hit)
				if e == null:
					break
				bolt(from, e.global_position)
				hurt(e, 14)
				hit.append(e)
			Audio.play("lightning", -6.0, 0.1))

# --- 5. Storm Reaver (Lightning + Moonreaver) --------------------------------
func tick_lightning_moonreaver(_delta: float) -> void:
	if timer <= 0.0 and not is_instance_valid(blade):
		timer = 2.4
		blade = throw_blade(aim_dir(), 18, Color(1.1, 1.05, 0.55))
	if is_instance_valid(blade) and every("zap", 0.15):
		var e: Node2D = nearest(blade.global_position, 170.0)
		if e:
			bolt(blade.global_position, e.global_position)
			hurt(e, 12)

# --- 6. Voltaic Briars (Lightning + Thornwake) -------------------------------
func tick_lightning_thornwake(_delta: float) -> void:
	if last_drop == Vector2.INF or global_position.distance_to(last_drop) > 110.0:
		last_drop = global_position
		patch_at(global_position, 55.0, 8, 3.0, Color(1.15, 1.15, 0.6))
	if not every("arc", 1.0):
		return
	var live: Array = patches.filter(func(p): return is_instance_valid(p))
	for i in live.size():
		var p: Node2D = live[i]
		for e in near(p.global_position, 75.0).slice(0, 3):
			bolt(p.global_position, e.global_position)
			hurt(e, 16)
		if i + 1 < live.size() and p.global_position.distance_to(live[i + 1].global_position) < 260.0:
			bolt(p.global_position, live[i + 1].global_position, BOLT, Color(0.6, 1.0, 0.4, 0.4))

# --- 7. Glacier Orbit (Frost + Orbit) ----------------------------------------
func tick_frost_orbit(delta: float) -> void:
	spin += 3.0 * delta
	for p in orbit_points(4, 170.0):
		for e in near(global_position + p, 38.0):
			if ready_to_hit(e, 0.45):
				hurt(e, 24, 0.4, 1.5)
				FX.burst(world(), e.global_position, ICE, 8, 160.0, 0.3, 0.25)

func paint_frost_orbit() -> void:
	draw_arc(Vector2.ZERO, 170.0, 0.0, TAU, 64, Color(ICE, 0.2), 2.0)
	for p in orbit_points(4, 170.0):
		var along: Vector2 = p.normalized().orthogonal()
		# Frosty streak behind each shard, then the shard itself.
		draw_arc(Vector2.ZERO, 170.0, p.angle() - 0.5, p.angle(), 10, Color(ICE, 0.35), 10.0)
		var out: Vector2 = p.normalized()
		var shard := PackedVector2Array([p + out * 22.0, p + along * 9.0, p - out * 14.0, p - along * 9.0])
		draw_colored_polygon(shard, ICE)
		draw_polyline(shard + PackedVector2Array([shard[0]]), Color.WHITE, 2.0)

# --- 8. Permafrost Ward (Frost + Runeward) -----------------------------------
const WARD_R: float = 190.0
func tick_frost_runeward(_delta: float) -> void:
	if every("chill", 0.3):
		for e in near(global_position, WARD_R):
			e.apply_slow(0.45, 0.5, true)
	if every("bite", 0.8):
		for e in near(global_position, WARD_R):
			hurt(e, 16)

func ground_frost_runeward() -> void:
	var g := ground
	g.draw_circle(Vector2.ZERO, WARD_R, Color(ICE, 0.12))
	g.draw_arc(Vector2.ZERO, WARD_R, 0.0, TAU, 64, Color(ICE, 0.7), 3.0)
	for i in 16:  # Ice crystals jutting out of the rim
		var a: float = clock * 0.2 + TAU / 16.0 * i
		var base: Vector2 = Vector2.from_angle(a) * WARD_R
		var side: Vector2 = Vector2.from_angle(a + PI / 2.0) * 6.0
		var tall: float = 16.0 + 6.0 * sin(clock * 2.0 + i)
		g.draw_colored_polygon(PackedVector2Array([base - side, base + side,
			base + Vector2.from_angle(a) * tall]), Color(0.85, 0.97, 1.0, 0.85))
	for i in 18:  # Drifting snow inside
		var seed_a: float = i * 2.39996
		var r: float = WARD_R * fmod(0.25 + i * 0.13 + clock * 0.05, 0.95)
		g.draw_circle(Vector2.from_angle(seed_a + clock * 0.3) * r, 2.5, Color(1, 1, 1, 0.7))

# --- 9. Comet Hail (Frost + Starfall) ----------------------------------------
func tick_frost_starfall(_delta: float) -> void:
	if every("frozen", 0.3):
		zones = zones.filter(func(z): return z[2] > clock)
		for z in zones:
			for e in near(z[0], z[1]):
				e.apply_slow(0.4, 0.5, true)
	if timer > 0.0:
		return
	timer = 2.6
	var spots: Array = []
	for i in 3:
		var s: Vector2 = crowd_spot(560.0, 100.0, spots)
		if s != Vector2.INF:
			spots.append(s)
	for s in spots:
		falling(s, STRIKE.DROP_TIME, ICE, Color(0.8, 0.97, 1.0), false)
		later(STRIKE.DROP_TIME, func():
			for e in near(s, 100.0):
				hurt(e, 32, 0.45, 1.5)
			FX.burst(world(), s, ICE, 22, 320.0, 0.45, 0.4)
			Audio.play("frost_nova", -8.0, 0.1)
			zones.append([s, 95.0, clock + 2.5])
			EFX.spawn(world(), s, 2.5, func(fx: Node2D, k: float):
				var a: float = 0.5 * (1.0 - k)
				fx.draw_circle(Vector2.ZERO, 95.0, Color(0.75, 0.95, 1.0, a))
				for c in 7:  # Cracks in the ice
					var d := Vector2.from_angle(TAU / 7.0 * c + 0.4)
					fx.draw_line(d * 12.0, d * 88.0, Color(1, 1, 1, a * 1.4), 2.0), -1))

# --- 10. Frostfang Reaver (Frost + Moonreaver) -------------------------------
func tick_frost_moonreaver(_delta: float) -> void:
	if timer <= 0.0 and not is_instance_valid(blade):
		timer = 2.2
		blade = throw_blade(aim_dir(), 20, Color(0.65, 1.0, 1.25))
		blade.tree_exiting.connect(func():
			# The blade comes home and bursts into a frost nova around you.
			if not is_inside_tree() or not get_tree().current_scene:
				return
			for e in near(global_position, 170.0):
				hurt(e, 18, 0.4, 1.5)
			ring(global_position, 170.0, ICE, 0.45, 10.0)
			FX.burst(world(), global_position, ICE, 24, 340.0, 0.45, 0.35))
	if is_instance_valid(blade) and every("freeze", 0.2):
		for e in near(blade.global_position, 75.0):
			e.apply_slow(0.4, 1.2, true)

# --- 11. Rime Thorns (Frost + Thornwake) -------------------------------------
func tick_frost_thornwake(_delta: float) -> void:
	if last_drop == Vector2.INF or global_position.distance_to(last_drop) > 100.0:
		last_drop = global_position
		patch_at(global_position, 58.0, 14, 3.0, Color(0.65, 0.95, 1.35))
		FX.burst(world(), global_position, ICE, 6, 120.0, 0.3, 0.2)
	if every("rime", 0.5):
		for p in patches:
			if is_instance_valid(p):
				for e in near(p.global_position, 58.0):
					e.apply_slow(0.35, 1.0, true)

# --- 12. Arcane Bastion (Orbit + Runeward) -----------------------------------
const BASTION_R: float = 170.0
func tick_orbit_runeward(delta: float) -> void:
	spin += 1.6 * delta
	touch_orbs(orbit_points(6, BASTION_R), 32.0, 18, 0.5)
	if timer > 0.0:
		return
	timer = 3.0
	for e in near(global_position, BASTION_R):
		hurt(e, 28)
		if alive(e):  # Knocked back out of the ring
			e.global_position += (e.global_position - global_position).normalized() * 70.0
	ring(global_position, BASTION_R + 30.0, ARCANE, 0.4, 10.0)

func ground_orbit_runeward() -> void:
	ground.draw_circle(Vector2.ZERO, BASTION_R, Color(ARCANE, 0.07))
	ground.draw_arc(Vector2.ZERO, BASTION_R, 0.0, TAU, 64, Color(RUNE, 0.6), 3.0)
	for i in 12:
		var a: float = -clock * 0.5 + TAU / 12.0 * i
		ground.draw_arc(Vector2.ZERO, BASTION_R - 14.0, a, a + 0.3, 6, Color(ARCANE, 0.6), 3.0)

func paint_orbit_runeward() -> void:
	for p in orbit_points(6, BASTION_R):
		draw_circle(p, 15.0, Color(ARCANE, 0.4))
		draw_circle(p, 8.0, ARCANE)
		draw_circle(p, 3.5, Color.WHITE)

# --- 13. Astral Orrery (Orbit + Starfall) ------------------------------------
func tick_orbit_starfall(delta: float) -> void:
	spin += 1.2 * delta
	for i in 4:
		if every("star%d" % i, 4.0, 1.0 * i):
			var s: Vector2 = crowd_spot(560.0, 95.0)
			if s != Vector2.INF:
				star_at(s, 18, 95.0)
				cooldowns["gone%d" % i] = 0.8  # This star is away for a moment

func paint_orbit_starfall() -> void:
	draw_arc(Vector2.ZERO, 110.0, 0.0, TAU, 48, Color(STAR, 0.2), 2.0)
	var pts := orbit_points(4, 110.0)
	for i in 4:
		if cooldowns.get("gone%d" % i, 0.0) > 0.0:
			continue
		draw_circle(pts[i], 14.0, Color(STAR, 0.25))
		draw_star(pts[i], 12.0, Color(1.0, 0.95, 0.65), clock * 2.0)

# --- 14. Crescent Halo (Orbit + Moonreaver) ----------------------------------
func tick_moonreaver_orbit(delta: float) -> void:
	spin += 4.0 * delta
	var away: bool = cooldowns.get("away", 0.0) > 0.0
	if not away:
		touch_orbs(orbit_points(3, 140.0), 40.0, 13, 0.5)
	if timer > 0.0:
		return
	timer = 3.0
	cooldowns["away"] = 1.6
	for p in orbit_points(3, 140.0):
		throw_blade(p.normalized(), 15, Color(1.0, 0.75, 1.35))

func paint_moonreaver_orbit() -> void:
	if cooldowns.get("away", 0.0) > 0.0:
		return
	for p in orbit_points(3, 140.0):
		var face: float = p.angle() + PI / 2.0
		draw_arc(p, 26.0, face - 1.2, face + 1.2, 14, Color(ARCANE, 0.4), 14.0)
		draw_arc(p, 28.0, face - 1.2, face + 1.2, 14, Color(MOON, 0.95), 5.0)

# --- 15. Thorned Orbit (Orbit + Thornwake) -----------------------------------
func tick_orbit_thornwake(delta: float) -> void:
	spin += 2.0 * delta
	var orbs := orbit_points(3, 150.0)
	touch_orbs(orbs, 32.0, 12, 0.5)
	for i in 3:
		if every("seed%d" % i, 0.6, 0.2 * i) and patches.size() < 18:
			patch_at(global_position + orbs[i], 48.0, 9, 2.5, Color(0.85, 1.2, 0.85))

func paint_orbit_thornwake() -> void:
	for p in orbit_points(3, 150.0):
		draw_circle(p, 15.0, Color(THORN, 0.35))
		draw_circle(p, 9.0, ARCANE)
		for j in 3:  # A crown of little thorns on each orb
			var a: float = clock * 3.0 + TAU / 3.0 * j
			draw_colored_polygon(PackedVector2Array([p + Vector2.from_angle(a - 0.3) * 8.0,
				p + Vector2.from_angle(a + 0.3) * 8.0, p + Vector2.from_angle(a) * 18.0]), THORN)

# --- 16. Celestial Seal (Runeward + Starfall) --------------------------------
func tick_runeward_starfall(_delta: float) -> void:
	if timer > 0.0:
		return
	var spot: Vector2 = crowd_spot(560.0, 130.0)
	if spot == Vector2.INF:
		timer = 0.3
		return
	timer = 3.0
	# A golden seal draws itself on the ground...
	EFX.spawn(world(), spot, 0.8, func(fx: Node2D, k: float):
		fx.draw_circle(Vector2.ZERO, 130.0 * k, Color(RUNE, 0.12))
		fx.draw_arc(Vector2.ZERO, 130.0, -PI / 2.0, -PI / 2.0 + TAU * k, 48, RUNE, 4.0)
		fx.draw_arc(Vector2.ZERO, 100.0, PI / 2.0, PI / 2.0 - TAU * k, 48, Color(RUNE, 0.6), 2.5)
		for i in 6:
			var a: float = TAU / 6.0 * i + k * 1.5
			fx.draw_line(Vector2.from_angle(a) * 100.0, Vector2.from_angle(a + 2.1) * 100.0,
				Color(RUNE, 0.5 * k), 2.0), -1)
	# ...then a pillar of starlight smashes down onto it.
	later(0.8, func():
		for e in near(spot, 130.0):
			hurt(e, 48)
		FX.burst(world(), spot, STAR, 26, 360.0, 0.5, 0.45)
		Audio.play("nuke", -10.0, 0.1)
		EFX.spawn(world(), spot, 0.5, func(fx: Node2D, k: float):
			var a: float = 1.0 - k
			var w: float = 70.0 * (1.0 - k * 0.5)
			fx.draw_rect(Rect2(-w / 2.0, -700.0, w, 700.0), Color(STAR, 0.35 * a))
			fx.draw_rect(Rect2(-w / 6.0, -700.0, w / 3.0, 700.0), Color(1, 1, 1, 0.8 * a))
			fx.draw_circle(Vector2.ZERO, 130.0 * (0.6 + k * 0.5), Color(RUNE, 0.3 * a))))

# --- 17. Rune Reaver (Moonreaver + Runeward) ---------------------------------
func tick_moonreaver_runeward(_delta: float) -> void:
	if timer > 0.0:
		return
	timer = 2.8
	ring(global_position, 150.0, RUNE, 0.35, 8.0)
	for i in 6:
		throw_blade(Vector2.from_angle(TAU / 6.0 * i + clock), 13, Color(1.3, 1.1, 0.55))

func ground_moonreaver_runeward() -> void:
	var charge: float = 1.0 - clampf(timer / 2.8, 0.0, 1.0)
	ground.draw_arc(Vector2.ZERO, 150.0, 0.0, TAU, 64, Color(RUNE, 0.25 + 0.5 * charge), 3.0)
	for i in 6:  # Six blade marks waiting on the ring
		var a: float = TAU / 6.0 * i + clock
		ground.draw_arc(Vector2.from_angle(a) * 150.0, 14.0, a - 1.0, a + 1.0, 8,
			Color(MOON, 0.3 + 0.6 * charge), 4.0)

# --- 18. Verdant Ward (Runeward + Thornwake) ---------------------------------
const HEDGE_R: float = 160.0
func tick_runeward_thornwake(_delta: float) -> void:
	if not every("snare", 0.5):
		return
	for e in near(global_position, HEDGE_R + 40.0):
		if absf(e.global_position.distance_to(global_position) - HEDGE_R) < 40.0:
			hurt(e, 20, 0.2, 0.6, false)  # Snagged in the hedge: nearly stopped

func ground_runeward_thornwake() -> void:
	var g := ground
	g.draw_arc(Vector2.ZERO, HEDGE_R, 0.0, TAU, 64, Color(0.24, 0.16, 0.09, 0.5), 30.0)
	var count: int = 22
	for i in count:  # Vines weaving round the ring, thorns sticking out
		var a: float = TAU / count * i
		var sway: float = sin(clock * 2.0 + i) * 4.0
		var from: Vector2 = Vector2.from_angle(a) * (HEDGE_R + sway)
		var to: Vector2 = Vector2.from_angle(a + TAU / count * 1.3) * (HEDGE_R - sway)
		g.draw_line(from, to, Color(0.09, 0.12, 0.08), 9.0)
		g.draw_line(from, to, THORN, 5.0)
		var out: Vector2 = Vector2.from_angle(a) * (1.0 if i % 2 == 0 else -1.0)
		g.draw_colored_polygon(PackedVector2Array([from + from.orthogonal().normalized() * 4.0,
			from - from.orthogonal().normalized() * 4.0, from + out * 13.0]), Color(0.86, 0.8, 0.6))

# --- 19. Meteor Glaive (Moonreaver + Starfall) -------------------------------
func tick_moonreaver_starfall(_delta: float) -> void:
	if timer <= 0.0 and not is_instance_valid(blade):
		timer = 2.4
		blade_path.clear()
		blade = throw_blade(aim_dir(), 18, Color(1.0, 1.0, 1.3))
		blade.tree_exiting.connect(func():
			# When it's back, stars rain down along the path it flew.
			if not is_inside_tree() or blade_path.size() < 2:
				return
			for i in 5:
				var spot: Vector2 = blade_path[blade_path.size() * i / 5]
				later(0.1 * i, func(): star_at(spot, 22, 85.0)))
	if is_instance_valid(blade) and every("trace", 0.05):
		blade_path.append(blade.global_position)

# --- 20. Starbloom (Starfall + Thornwake) ------------------------------------
func tick_starfall_thornwake(_delta: float) -> void:
	if timer > 0.0:
		return
	timer = 2.8
	var spots: Array = []
	for i in 2:
		var s: Vector2 = crowd_spot(560.0, 95.0, spots)
		if s != Vector2.INF:
			spots.append(s)
	for s in spots:
		star_at(s, 22, 95.0)
		later(STRIKE.DROP_TIME, func():
			patch_at(s, 78.0, 10, 3.5, Color(1.05, 1.15, 0.85))
			FX.burst(world(), s, THORN, 14, 220.0, 0.4, 0.3))

# --- 21. Thornwhip Reaver (Moonreaver + Thornwake) ---------------------------
func tick_moonreaver_thornwake(_delta: float) -> void:
	if timer <= 0.0 and not is_instance_valid(blade):
		timer = 2.2
		blade = throw_blade(aim_dir(), 16, Color(0.75, 1.25, 0.65))
		last_drop = global_position
	if is_instance_valid(blade) and blade.global_position.distance_to(last_drop) > 70.0:
		last_drop = blade.global_position
		patch_at(blade.global_position, 44.0, 12, 2.5, Color(0.9, 1.2, 0.8))
