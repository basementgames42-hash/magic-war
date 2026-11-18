extends Node2D
# One Thornwake patch: thorny vines push up out of a patch of churned earth,
# cut and slow enemies on it, sway a little, then wither and sink back.

const TICK: float = 0.6
const VINES: int = 6
const GROW_TIME: float = 0.35     # Seconds for the vines to burst out of the ground
const WITHER_TIME: float = 0.6    # Seconds at the end to shrivel and fade
const SOIL := Color(0.24, 0.16, 0.09, 0.55)
const SOIL_DARK := Color(0.14, 0.09, 0.05, 0.8)
const OUTLINE := Color(0.09, 0.12, 0.08)  # Dark edge, like the game's outlined art
const VINE := Color(0.24, 0.46, 0.15)
const VINE_LIGHT := Color(0.42, 0.66, 0.24)
const THORN := Color(0.86, 0.8, 0.6)
const DEAD := Color(0.42, 0.32, 0.18)  # What the vines fade to as they wither

var radius: float = 58.0
var lifetime: float = 3.0
var damage: int = 1
var age: float = 0.0
var tick_timer: float = 0.0
var vines: Array = []   # [angle, length (0-1 of radius), bend, phase]
var soil: PackedVector2Array

func _ready() -> void:
	z_index = -1
	rotation = randf() * TAU
	for i in VINES:
		vines.append([TAU / VINES * i + randf_range(-0.3, 0.3), randf_range(0.85, 1.1),
			randf_range(-0.9, 0.9), randf() * TAU])
	# A lumpy patch of churned earth, not a perfect circle.
	for i in 14:
		var a: float = TAU / 14 * i
		soil.append(Vector2.from_angle(a) * radius * randf_range(0.3, 0.45))

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	queue_redraw()  # Growing, swaying, withering
	tick_timer -= delta
	if tick_timer > 0.0:
		return
	tick_timer = TICK
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) < radius:
			enemy.take_damage(damage)
			enemy.apply_slow(0.6, 0.7, false)  # Snagged, not frozen: no blue tint

func _draw() -> void:
	var grow: float = ease(clampf(age / GROW_TIME, 0.0, 1.0), 0.4)  # Fast burst, soft finish
	var wither: float = clampf((age - (lifetime - WITHER_TIME)) / WITHER_TIME, 0.0, 1.0)
	var fade: float = 1.0 - wither
	draw_colored_polygon(soil, Color(SOIL, SOIL.a * fade))
	# A few dark cracks where the vines broke through.
	for v in vines:
		var dir := Vector2.from_angle(v[0])
		draw_line(dir * radius * 0.08, dir * radius * 0.4, Color(SOIL_DARK, SOIL_DARK.a * fade), 3.0)
	var body: Color = VINE.lerp(DEAD, wither)
	var light: Color = VINE_LIGHT.lerp(DEAD, wither)
	var reach: float = grow * (1.0 - wither * 0.35)
	# Two passes: every vine's dark outline first, then the green on top, so
	# where vines cross they still read as separate stems.
	for v in vines:
		draw_vine(v, reach, Color(OUTLINE, fade), Color(OUTLINE, fade), 4.0)
	for v in vines:
		draw_vine(v, reach, Color(body, fade), Color(light, fade), 0.0)

# edge > 0 draws the outline pass: everything that much fatter, in one colour.
func draw_vine(v: Array, reach: float, body: Color, light: Color, edge: float) -> void:
	# A curling vine: a curve from the patch's middle out to its tip, thick
	# at the root and thin at the end, with thorns along both sides.
	var dir := Vector2.from_angle(v[0])
	var sway: float = sin(age * 2.2 + v[3]) * 0.12
	var tip: Vector2 = dir * radius * v[1] * reach
	var bend: Vector2 = dir.orthogonal() * radius * (v[2] + sway) * 0.35 * reach
	var root: Vector2 = dir * radius * 0.1
	var steps: int = 8
	var last: Vector2 = root
	for s in range(1, steps + 1):
		var t: float = float(s) / steps
		var point: Vector2 = root.lerp(tip, t) + bend * 4.0 * t * (1.0 - t)  # Bowed curve
		var width: float = lerpf(11.0, 3.0, t) + edge
		draw_line(last, point, body, width)
		draw_circle(point, width * 0.5, body)  # Round joints, no gaps on bends
		if edge == 0.0:
			draw_line(last, point, light, width * 0.3)  # Highlight down the stem
		# A thorn every other step, alternating sides, leaning toward the tip.
		if s % 2 == 0 and s < steps:
			var along: Vector2 = (point - last).normalized()
			var side: Vector2 = along.orthogonal() * (1.0 if s % 4 == 0 else -1.0)
			var size: float = lerpf(14.0, 7.0, t) + edge
			var hook: PackedVector2Array = [
				point - along * size * 0.4, point + along * size * 0.4,
				point + side * (size + width * 0.5) + along * size * 0.6,
			]
			draw_colored_polygon(hook, body if edge > 0.0 else Color(THORN, body.a))
		last = point
