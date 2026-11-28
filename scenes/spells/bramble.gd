extends Node2D
# One Thornwake patch: thorny vines push up out of a patch of churned earth,
# cut and slow enemies on it, sway a little, then wither and sink back.
#
# Speed matters here: a run can have dozens of patches at once. Each patch's
# drawing is ~280 shapes, and even drawn once the renderer had to send all of
# them every frame, which made the web build lag. So a few bramble patterns
# are painted ONCE into images (one small offscreen viewport each, kept for
# the whole game), and every patch is just one of those pictures: growing,
# swaying and withering are done by scaling, rotating and tinting it.

const TICK: float = 0.6
const VINES: int = 6
const VARIANTS: int = 4           # Different patterns per size, picked at random
const GROW_TIME: float = 0.35     # Seconds for the vines to burst out of the ground
const WITHER_TIME: float = 0.6    # Seconds at the end to shrivel and fade
const SOIL := Color(0.24, 0.16, 0.09, 0.55)
const SOIL_DARK := Color(0.14, 0.09, 0.05, 0.8)
const OUTLINE := Color(0.09, 0.12, 0.08)  # Dark edge, like the game's outlined art
const VINE := Color(0.24, 0.46, 0.15)
const VINE_LIGHT := Color(0.42, 0.66, 0.24)
const THORN := Color(0.86, 0.8, 0.6)
const WITHERED := Color(1.25, 0.72, 0.55)  # Tint that turns the green vines brown as they wither

var radius: float = 58.0
var lifetime: float = 3.0
var damage: int = 1
var age: float = 0.0
var tick_timer: float = 0.0
var tint: Color = Color.WHITE   # The planter's colour (Epic combos tint their thorns)
var base_rotation: float = 0.0
var sway_phase: float = 0.0

# "size|variant" -> the painted pattern (a ViewportTexture). Shared by every
# patch for the rest of the game.
static var patterns: Dictionary = {}
static var query_shape: CircleShape2D = null

func _ready() -> void:
	z_index = -1
	tint = modulate
	base_rotation = randf() * TAU
	sway_phase = randf() * TAU
	scale = Vector2.ONE * 0.15  # Bursts up out of the ground from here
	var picture := Sprite2D.new()
	picture.texture = pattern(get_tree(), radius, randi() % VARIANTS)
	add_child(picture)

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	# Grow, sway and wither by moving the finished picture, never redrawing it.
	var grow: float = ease(clampf(age / GROW_TIME, 0.0, 1.0), 0.4)  # Fast burst, soft finish
	var wither: float = clampf((age - (lifetime - WITHER_TIME)) / WITHER_TIME, 0.0, 1.0)
	scale = Vector2.ONE * lerpf(0.15, 1.0, grow) * (1.0 - wither * 0.2)
	rotation = base_rotation + sin(age * 2.2 + sway_phase) * 0.05
	modulate = tint * Color.WHITE.lerp(WITHERED, wither)
	modulate.a = tint.a * (1.0 - wither)
	tick_timer -= delta
	if tick_timer > 0.0:
		return
	tick_timer = TICK
	for enemy in enemies_on_patch():
		enemy.take_damage(damage)
		enemy.apply_slow(0.6, 0.7, false)  # Snagged, not frozen: no blue tint

func enemies_on_patch() -> Array:
	# Asks the physics engine for bodies overlapping the patch (it already
	# knows what's where), instead of checking every enemy on the map. Same
	# rule as before: an enemy counts when its centre is on the patch.
	if query_shape == null:
		query_shape = CircleShape2D.new()
	query_shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = query_shape
	query.transform = Transform2D(0.0, global_position)
	query.collide_with_areas = false
	var found: Array = []
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 128):
		var body: Object = hit["collider"]
		if body != null and body.is_in_group("enemies") and not body.is_queued_for_deletion() \
				and global_position.distance_to(body.global_position) < radius:
			found.append(body)
	return found

# --- Painting the patterns (once each) ---------------------------------------

static func pattern(tree: SceneTree, patch_radius: float, variant: int) -> Texture2D:
	# Sizes are rounded to 5 px so a handful of pictures covers every patch.
	var size: int = maxi(snappedi(int(patch_radius), 5), 10)
	var key: String = "%d|%d" % [size, variant]
	if patterns.has(key):
		return patterns[key]
	var extent: int = ceili(size * 1.15 + 26.0)  # Room for the longest vine and its thorns
	var viewport := SubViewport.new()
	viewport.size = Vector2i(extent * 2, extent * 2)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := Node2D.new()
	painter.position = Vector2(extent, extent)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var vines: Array = []   # [angle, length (0-1 of radius), bend]
	for i in VINES:
		vines.append([TAU / VINES * i + rng.randf_range(-0.3, 0.3), rng.randf_range(0.85, 1.1),
			rng.randf_range(-0.9, 0.9)])
	var soil := PackedVector2Array()  # A lumpy patch of churned earth, not a perfect circle
	for i in 14:
		soil.append(Vector2.from_angle(TAU / 14 * i) * size * rng.randf_range(0.3, 0.45))
	painter.draw.connect(paint.bind(painter, float(size), vines, soil))
	viewport.add_child(painter)
	tree.root.add_child.call_deferred(viewport)  # Kept for the whole game
	patterns[key] = viewport.get_texture()
	return patterns[key]

static func paint(n: Node2D, r: float, vines: Array, soil: PackedVector2Array) -> void:
	n.draw_colored_polygon(soil, SOIL)
	# A few dark cracks where the vines broke through.
	for v in vines:
		var dir := Vector2.from_angle(v[0])
		n.draw_line(dir * r * 0.08, dir * r * 0.4, SOIL_DARK, 3.0)
	# Two passes: every vine's dark outline first, then the green on top, so
	# where vines cross they still read as separate stems.
	for v in vines:
		paint_vine(n, r, v, OUTLINE, OUTLINE, 4.0)
	for v in vines:
		paint_vine(n, r, v, VINE, VINE_LIGHT, 0.0)

# edge > 0 draws the outline pass: everything that much fatter, in one colour.
static func paint_vine(n: Node2D, r: float, v: Array, body: Color, light: Color, edge: float) -> void:
	# A curling vine: a curve from the patch's middle out to its tip, thick
	# at the root and thin at the end, with thorns along both sides.
	var dir := Vector2.from_angle(v[0])
	var tip: Vector2 = dir * r * v[1]
	var bend: Vector2 = dir.orthogonal() * r * v[2] * 0.35
	var root: Vector2 = dir * r * 0.1
	var steps: int = 8
	var last: Vector2 = root
	for s in range(1, steps + 1):
		var t: float = float(s) / steps
		var point: Vector2 = root.lerp(tip, t) + bend * 4.0 * t * (1.0 - t)  # Bowed curve
		var width: float = lerpf(11.0, 3.0, t) + edge
		n.draw_line(last, point, body, width)
		n.draw_circle(point, width * 0.5, body)  # Round joints, no gaps on bends
		if edge == 0.0:
			n.draw_line(last, point, light, width * 0.3)  # Highlight down the stem
		# A thorn every other step, alternating sides, leaning toward the tip.
		if s % 2 == 0 and s < steps:
			var along: Vector2 = (point - last).normalized()
			var side: Vector2 = along.orthogonal() * (1.0 if s % 4 == 0 else -1.0)
			var size: float = lerpf(14.0, 7.0, t) + edge
			var hook: PackedVector2Array = [
				point - along * size * 0.4, point + along * size * 0.4,
				point + side * (size + width * 0.5) + along * size * 0.6,
			]
			n.draw_colored_polygon(hook, body if edge > 0.0 else Color(THORN, body.a))
		last = point
