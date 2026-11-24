extends "res://scenes/enemies/enemy_hazard.gd"
# Torch Fire: the blaze a Torch Goblin (and its giant elite) leaves behind.
# Same timing and damage as any lingering hazard; only the look is its own:
# a scorched patch with glowing cracks, flickering tongues of flame, the pack's
# fire bursts popping across it, rising embers and a heat glow. Bigger patches
# (elites) get more of everything. It dies down to smoke at the end.

const FIRE_SHEETS: Array[Texture2D] = [
	preload("res://scenes/assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Particle FX/Fire_01.png"),
	preload("res://scenes/assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Particle FX/Fire_02.png"),
	preload("res://scenes/assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Particle FX/Fire_03.png"),
]
const DUST_SHEET: Texture2D = preload("res://scenes/assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Particle FX/Dust_01.png")
const SCORCH := Color(0.13, 0.07, 0.04)
const EMBER := Color(1.0, 0.42, 0.08)
const FLAME_RED := Color(0.86, 0.2, 0.05)
const FLAME_ORANGE := Color(1.0, 0.55, 0.1)
const FLAME_CORE := Color(1.0, 0.93, 0.55)
const DIE_DOWN: float = 0.6  # Seconds at the end for the flames to sink away

var flames: Array = []   # [offset, height (0-1), phase]
var scorch: PackedVector2Array
var cracks: Array = []   # [angle, length (0-1 of radius)]
var puff_timer: float = 0.0
var embers: CPUParticles2D
var heat: Sprite2D

func _ready() -> void:
	super()
	var count: int = clampi(int(radius / 12.0), 5, 16)
	for i in count:
		var spot: Vector2 = Vector2.from_angle(randf() * TAU) * radius * sqrt(randf()) * 0.75
		flames.append([spot, randf_range(0.6, 1.0), randf() * TAU])
	flames.sort_custom(func(a, b): return a[0].y < b[0].y)  # Back flames drawn first
	for i in 16:
		scorch.append(Vector2.from_angle(TAU / 16 * i) * radius * randf_range(0.82, 1.04))
	for i in 7:
		cracks.append([randf() * TAU, randf_range(0.45, 0.9)])
	heat = FX.glow_sprite(Color(1.0, 0.45, 0.1, 0.0), radius * 2.6)
	heat.show_behind_parent = true
	add_child(heat)
	embers = CPUParticles2D.new()
	embers.texture = FX.glow_texture()
	embers.material = FX.additive_material()
	embers.amount = count * 3
	embers.lifetime = 1.1
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = radius * 0.7
	embers.direction = Vector2.UP
	embers.spread = 25.0
	embers.gravity = Vector2(0, -70)
	embers.initial_velocity_min = 25.0
	embers.initial_velocity_max = 80.0
	embers.scale_amount_min = 0.1
	embers.scale_amount_max = 0.25
	embers.color = EMBER
	embers.color_ramp = FX.fade_ramp()
	embers.emitting = false
	add_child(embers)

func _process(delta: float) -> void:
	var was_burning: bool = age >= fuse
	if was_burning and age + delta >= fuse + linger:
		# Last frame: a puff of smoke where the fire was.
		FX.play_sheet(get_parent(), global_position, DUST_SHEET, 14.0, clampf(radius / 60.0, 1.0, 2.5))
	super(delta)
	if is_queued_for_deletion() or age < fuse:
		return
	if not was_burning:
		ignite()
	var left: float = fuse + linger - age
	heat.modulate.a = 0.5 * clampf(left / DIE_DOWN, 0.0, 1.0) * (0.85 + 0.15 * sin(age * 13.0))
	if left < DIE_DOWN:
		embers.emitting = false
		return
	# The pack's fire bursts popping up across the patch.
	puff_timer -= delta
	if puff_timer <= 0.0:
		puff_timer = randf_range(0.12, 0.28) * 60.0 / radius
		var spot: Vector2 = Vector2.from_angle(randf() * TAU) * radius * sqrt(randf()) * 0.7
		FX.play_sheet(get_parent(), global_position + spot, FIRE_SHEETS.pick_random(),
			randf_range(14.0, 20.0), clampf(radius / 70.0, 0.8, 2.2))

func ignite() -> void:
	embers.emitting = true
	FX.burst(get_parent(), global_position, FLAME_ORANGE, 14, radius * 2.0, 0.35, 0.3)

func _draw() -> void:
	if age < fuse:
		# Catching: the patch smoulders and the flames rise as the fuse burns.
		var catching: float = age / fuse if fuse > 0.0 else 1.0
		draw_colored_polygon(scorch, Color(SCORCH, 0.45 * catching))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(EMBER, 0.8), 3.0)
		draw_flames(catching * 0.5, 1.0)
		return
	var left: float = fuse + linger - age
	var fade: float = clampf(left / DIE_DOWN, 0.0, 1.0)
	var rise: float = minf((age - fuse) / 0.2, 1.0)  # Flames leap up as it catches
	# Scorch mark in soft layers: faint sooty edge, darker burnt middle.
	draw_colored_polygon(scorch, Color(SCORCH, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * 0.78)
	draw_colored_polygon(scorch, Color(SCORCH, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * 0.5)
	draw_colored_polygon(scorch, Color(SCORCH, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0)
	# Glowing cracks in the burnt ground, pulsing like coals.
	var pulse: float = 0.6 + 0.4 * sin(age * 5.0)
	for crack in cracks:
		var dir := Vector2.from_angle(crack[0])
		var bend: Vector2 = dir.orthogonal() * radius * 0.08
		var mid: Vector2 = dir * radius * crack[1] * 0.5 + bend
		var end: Vector2 = dir * radius * crack[1]
		var c := Color(EMBER, pulse * (0.4 + 0.6 * fade))
		draw_line(dir * radius * 0.08, mid, c, 3.0)
		draw_line(mid, end, Color(c, c.a * 0.7), 2.0)
	draw_flames(rise * fade, fade)

func draw_flames(size: float, alpha: float) -> void:
	if size <= 0.01:
		return
	var scale_up: float = clampf(radius / 58.0, 1.0, 2.6)
	for f in flames:
		var flicker: float = 0.8 + 0.2 * sin(age * 17.0 + f[2]) + 0.1 * sin(age * 29.0 + f[2] * 2.0)
		var height: float = 40.0 * f[1] * flicker * size * scale_up
		var width: float = 10.0 * scale_up * (0.7 + 0.3 * size)
		var sway: float = sin(age * 6.0 + f[2]) * width * 0.6
		draw_colored_polygon(tongue(f[0], width, height, sway), Color(FLAME_RED, 0.9 * alpha))
		draw_colored_polygon(tongue(f[0] + Vector2(0, 1), width * 0.68, height * 0.7, sway * 0.8),
			Color(FLAME_ORANGE, 0.95 * alpha))
		draw_colored_polygon(tongue(f[0] + Vector2(0, 2), width * 0.36, height * 0.4, sway * 0.5),
			Color(FLAME_CORE, alpha))

func tongue(base: Vector2, width: float, height: float, sway: float) -> PackedVector2Array:
	# A licking flame: a round bottom, sides that bulge out then curl in to a
	# tip, and the whole flame bending with `sway` (more toward the tip).
	# One loop, no repeated points: up the right side to the tip, down the
	# left side, then round the bottom back toward where it started.
	var points := PackedVector2Array()
	var steps: int = 8
	for i in steps + 1:                  # Right base (t=0) up to the tip (t=1)
		points.append(base + flame_side(float(i) / steps, width, height, sway, 1.0))
	for i in range(steps - 1, -1, -1):   # Left side, just below the tip down to its base
		points.append(base + flame_side(float(i) / steps, width, height, sway, -1.0))
	for i in range(1, 8):                # Round bottom, left to right (ends excluded)
		var a: float = PI * float(i) / 8.0
		points.append(base + Vector2(-cos(a) * width, sin(a) * width * 0.55))
	return points

func flame_side(t: float, width: float, height: float, sway: float, side: float) -> Vector2:
	# t = 0 at the base, 1 at the tip. Fattest a third of the way up.
	var half: float = width * pow(1.0 - t, 0.75) * (1.0 + 0.45 * sin(t * PI))
	return Vector2(side * half + sway * t * t, -height * t)
