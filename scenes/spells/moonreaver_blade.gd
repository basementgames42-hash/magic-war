extends Node2D
# One Moonreaver blade: a spinning crescent moon of night-blue steel. It slows
# to a stop at the far end of its throw, then accelerates back to the player.
# Each enemy can be hit once per direction. Looks: a moonlit halo, fading
# afterimages of its spin, a trail of star dust and a few twinkling stars
# riding along with it.

const FX = preload("res://scenes/spells/spell_fx.gd")

const HIT_RADIUS: float = 52.0
const THROW_SPEED: float = 760.0
const SLOWDOWN: float = 900.0
const SPIN: float = 15.0          # Radians per second
const GHOSTS: int = 7             # Afterimages kept behind the blade
const GHOST_EVERY: float = 0.018  # Seconds between afterimages

const MOON_PALE := Color(0.93, 0.96, 1.0)
const MOON_STEEL := Color(0.62, 0.74, 1.0)
const NIGHT := Color(0.18, 0.22, 0.55)
const GHOST := Color(0.42, 0.52, 1.0)

# The crescent's outline, built once: an outer moon with a smaller disc cut out
# of one side. Points run around the moon's back, then back along the inside.
static var crescent: PackedVector2Array = make_crescent(34.0, 29.0, 14.0)
static var crescent_core: PackedVector2Array = make_crescent(29.0, 27.0, 13.0)

var direction: Vector2 = Vector2.RIGHT
var damage: int = 1
var thrower: Node2D = null  # The player it returns to
var speed: float = THROW_SPEED
var returning: bool = false
var already_hit: Dictionary = {}
var ghosts: Array = []      # [global position, rotation], newest first
var ghost_timer: float = 0.0
var age: float = 0.0

static func make_crescent(outer: float, inner: float, offset: float) -> PackedVector2Array:
	# Where the two circles cross: those are the crescent's horn tips.
	var x: float = (outer * outer - inner * inner + offset * offset) / (2.0 * offset)
	var y: float = sqrt(maxf(outer * outer - x * x, 0.0))
	var outer_from: float = atan2(y, x)
	var inner_from: float = atan2(y, x - offset)
	var points := PackedVector2Array()
	var steps: int = 20
	for i in steps + 1:  # The moon's outer back, horn to horn
		points.append(Vector2.from_angle(lerpf(outer_from, TAU - outer_from, float(i) / steps)) * outer)
	for i in range(1, steps):  # The cut-out edge, back toward the first horn
		# (Its two ends are the horn tips, already added: no repeats, or the
		# polygon won't fill.)
		var a: float = lerpf(TAU - inner_from, inner_from, float(i) / steps)
		points.append(Vector2(offset, 0) + Vector2.from_angle(a) * inner)
	return points

func _ready() -> void:
	z_index = 5
	# Moonlight halo, drawn behind the blade and spinning with it.
	var halo: Sprite2D = FX.glow_sprite(Color(0.45, 0.6, 1.0, 0.75), 150.0)
	halo.show_behind_parent = true
	add_child(halo)
	var dust: CPUParticles2D = FX.trail(Color(0.75, 0.85, 1.0), 26, 0.5, 0.32)
	dust.show_behind_parent = true
	add_child(dust)
	FX.burst(get_tree().current_scene, global_position, MOON_STEEL, 10, 200.0, 0.3, 0.25)

func _process(delta: float) -> void:
	age += delta
	rotation += SPIN * delta
	ghost_timer -= delta
	if ghost_timer <= 0.0:
		ghost_timer = GHOST_EVERY
		ghosts.push_front([global_position, rotation])
		if ghosts.size() > GHOSTS:
			ghosts.pop_back()
	if not returning:
		speed -= SLOWDOWN * delta
		global_position += direction * speed * delta
		if speed <= 0.0:
			returning = true
			already_hit.clear()
	else:
		speed += SLOWDOWN * delta
		global_position = global_position.move_toward(thrower.global_position, speed * delta)
		if global_position.distance_to(thrower.global_position) < 24.0:
			FX.burst(get_tree().current_scene, global_position, MOON_PALE, 8, 140.0, 0.25, 0.2)
			queue_free()
			return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not already_hit.has(enemy.get_instance_id()) \
				and global_position.distance_to(enemy.global_position) < HIT_RADIUS:
			already_hit[enemy.get_instance_id()] = true
			enemy.take_damage(damage)
			FX.burst(get_tree().current_scene, enemy.global_position, MOON_PALE, 7, 180.0, 0.25, 0.22)
	queue_redraw()

func _draw() -> void:
	# Afterimages first (behind), oldest faintest: each one drawn where and at
	# the angle the blade was, so the spin smears into a moonlit ring.
	for i in range(ghosts.size() - 1, -1, -1):
		var fade: float = 1.0 - float(i + 1) / (GHOSTS + 1)
		draw_set_transform(to_local(ghosts[i][0]), ghosts[i][1] - rotation)
		draw_colored_polygon(crescent, Color(GHOST, 0.35 * fade))
	draw_set_transform(Vector2.ZERO, 0.0)
	# The blade: dark night-blue rim, steel body, pale moonlit face, bright edge.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * 1.08)
	draw_colored_polygon(crescent, NIGHT)
	draw_set_transform(Vector2.ZERO, 0.0)
	draw_colored_polygon(crescent, MOON_STEEL)
	draw_colored_polygon(crescent_core, MOON_PALE)
	draw_polyline(crescent.slice(0, 21), Color.WHITE, 2.0, true)
	# Three small stars riding with the blade, twinkling out of step.
	for i in 3:
		var spot: Vector2 = Vector2.from_angle(PI + (i - 1) * 0.9) * 48.0
		var twinkle: float = 0.5 + 0.5 * sin(age * 9.0 + i * 2.1)
		draw_star(spot, 3.0 + 4.0 * twinkle, Color(1.0, 1.0, 1.0, 0.4 + 0.6 * twinkle))

func draw_star(at: Vector2, size: float, color: Color) -> void:
	# A four-point twinkle: a long cross and a short diagonal one.
	draw_line(at - Vector2(size, 0), at + Vector2(size, 0), color, 1.5)
	draw_line(at - Vector2(0, size), at + Vector2(0, size), color, 1.5)
	var d: float = size * 0.45
	draw_line(at - Vector2(d, d), at + Vector2(d, d), Color(color, color.a * 0.6), 1.0)
	draw_line(at - Vector2(d, -d), at + Vector2(d, -d), Color(color, color.a * 0.6), 1.0)
