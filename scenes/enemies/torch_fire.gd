extends "res://scenes/enemies/enemy_hazard.gd"
# Torch Fire: the blaze a Torch Goblin (and its giant elite) leaves behind.
# Same timing and damage as any lingering hazard; only the look is its own:
# a scorched patch with glowing cracks, a cluster of flickering flames and a
# heat glow. Bigger patches (elites) get bigger and more flames. It dies down
# to smoke at the end.
#
# Built to stay cheap however many goblins there are:
#   - The scorch, cracks and warning ring are drawn ONCE, into their own
#     layers. After that only their opacity changes (no redrawing).
#   - The flames are a few looping sprites from the pack's fire sheets, made
#     once per patch; nothing new is created while it burns.
#   - At most MAX_BURNING patches burn at once. A new one makes the oldest
#     die down early, so a big crowd can't stack up unlimited fires.

const FIRE_SHEETS: Array[Texture2D] = [
	preload("res://scenes/assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Particle FX/Fire_02.png"),
	preload("res://scenes/assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Particle FX/Fire_03.png"),
]
const DUST_SHEET: Texture2D = preload("res://scenes/assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Particle FX/Dust_01.png")
const SCORCH := Color(0.13, 0.07, 0.04)
const EMBER := Color(1.0, 0.42, 0.08)
const FLAME_ORANGE := Color(1.0, 0.55, 0.1)
const DIE_DOWN: float = 0.6  # Seconds at the end for the flames to sink away
const TICK: float = 1.0      # Seconds between burns while standing in the fire
const MAX_BURNING: int = 40  # Patches allowed to burn at once (about 12+ goblins before it kicks in)
# The bright part of each fire sheet (later frames turn to smoke), played
# forward and back so the flame flickers up and down without a jump.
const FLAME_LOOP: Array[int] = [1, 2, 3, 4, 5, 4, 3, 2]

static var burning: Array = []        # Live patches, oldest first
static var flame_frames: Dictionary = {}  # Sheet id -> shared SpriteFrames

var scorch: PackedVector2Array
var ground: Node2D   # Scorch mark (drawn once)
var cracks: Node2D   # Glowing cracks (drawn once; pulses by opacity)
var ring: Node2D     # Warning ring while it catches (drawn once)
var flames: Node2D   # Holds the flame sprites
var heat: Sprite2D

func _ready() -> void:
	super()
	redraw_every_frame = false
	tick = TICK  # Burns you once a second while you stand in it (hazards default to 0.6 s)
	burning.append(self)
	cap_fires()
	for i in 16:
		scorch.append(Vector2.from_angle(TAU / 16 * i) * radius * randf_range(0.82, 1.04))
	heat = FX.glow_sprite(Color(1.0, 0.45, 0.1, 0.0), radius * 2.6)
	heat.show_behind_parent = true
	add_child(heat)
	ground = layer(draw_ground)
	ground.modulate.a = 0.0
	cracks = layer(draw_cracks)
	cracks.modulate.a = 0.0
	ring = layer(draw_ring)
	build_flames()

func _exit_tree() -> void:
	burning.erase(self)

# --- Cap ----------------------------------------------------------------------

func dying() -> bool:
	return age >= fuse + linger - DIE_DOWN

func cap_fires() -> void:
	# Too many still going strong: the oldest one starts dying down now.
	var strong: Array = burning.filter(func(f): return is_instance_valid(f) and not f.dying())
	if strong.size() > MAX_BURNING:
		strong[0].burn_out()

func burn_out() -> void:
	age = maxf(age, fuse + linger - DIE_DOWN)

# --- Building (once) ------------------------------------------------------------

func layer(painter: Callable) -> Node2D:
	# A child that draws itself once; only its opacity changes afterwards.
	var n := Node2D.new()
	n.draw.connect(painter.bind(n))
	add_child(n)
	return n

func draw_ground(n: Node2D) -> void:
	# Scorch mark in soft layers: faint sooty edge, darker burnt middle.
	n.draw_colored_polygon(scorch, Color(SCORCH, 0.32))
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * 0.78)
	n.draw_colored_polygon(scorch, Color(SCORCH, 0.4))
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * 0.5)
	n.draw_colored_polygon(scorch, Color(SCORCH, 0.35))

func draw_cracks(n: Node2D) -> void:
	for i in 7:
		var dir := Vector2.from_angle(randf() * TAU)
		var length: float = randf_range(0.45, 0.9)
		var mid: Vector2 = dir * radius * length * 0.5 + dir.orthogonal() * radius * 0.08
		var end: Vector2 = dir * radius * length
		n.draw_line(dir * radius * 0.08, mid, EMBER, 3.0)
		n.draw_line(mid, end, Color(EMBER, 0.7), 2.0)

func draw_ring(n: Node2D) -> void:
	n.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(EMBER, 0.8), 3.0)

static func frames_for(sheet: Texture2D) -> SpriteFrames:
	var key: int = sheet.get_instance_id()
	if flame_frames.has(key):
		return flame_frames[key]
	var frames := SpriteFrames.new()
	frames.add_animation(&"burn")
	frames.set_animation_speed(&"burn", 12.0)
	frames.set_animation_loop(&"burn", true)
	var size: int = sheet.get_height()  # Square frames in one row
	for i in FLAME_LOOP:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * size, 0, size, size)
		frames.add_frame(&"burn", atlas)
	flame_frames[key] = frames
	return frames

func build_flames() -> void:
	flames = Node2D.new()
	flames.modulate.a = 0.0
	add_child(flames)
	var count: int = clampi(int(radius / 20.0), 3, 7)
	var spots: Array = []
	for i in count:
		spots.append(Vector2.from_angle(randf() * TAU) * radius * sqrt(randf()) * 0.65)
	spots.sort_custom(func(a, b): return a.y < b.y)  # Back flames drawn first
	var size: float = clampf(radius / 52.0, 0.9, 2.4)
	for spot in spots:
		var flame := AnimatedSprite2D.new()
		flame.sprite_frames = frames_for(FIRE_SHEETS.pick_random())
		flame.position = spot
		flame.offset = Vector2(0, -22)  # The flame's foot sits on its spot
		flame.scale = Vector2.ONE * size * randf_range(0.85, 1.15)
		flame.flip_h = randf() < 0.5
		flame.speed_scale = randf_range(0.85, 1.2)
		# Warm the pack's yellow flames toward orange-red, a little different each.
		flame.modulate = Color(1.0, 0.85, 0.7).lerp(Color(1.0, 0.6, 0.45), randf())
		flames.add_child(flame)
		flame.play(&"burn")
		flame.frame = randi() % FLAME_LOOP.size()  # Out of step with its neighbours

# --- Every frame (opacity and scale only) ------------------------------------------

func _process(delta: float) -> void:
	var was_burning: bool = age >= fuse
	if was_burning and age + delta >= fuse + linger:
		# Last frame: a puff of smoke where the fire was.
		FX.play_sheet(get_parent(), global_position, DUST_SHEET, 14.0, clampf(radius / 60.0, 1.0, 2.5))
	super(delta)
	if is_queued_for_deletion():
		return
	if age < fuse:
		# Catching: the patch smoulders and small flames rise as the fuse burns.
		var catching: float = age / fuse if fuse > 0.0 else 1.0
		ground.modulate.a = 0.45 * catching
		flames.modulate.a = 0.6 * catching
		flames.scale = Vector2.ONE * (0.35 + 0.3 * catching)
		return
	if not was_burning:
		ignite()
	var left: float = fuse + linger - age
	var fade: float = clampf(left / DIE_DOWN, 0.0, 1.0)
	var rise: float = minf((age - fuse) / 0.2, 1.0)  # Flames leap up as it catches
	ground.modulate.a = fade
	cracks.modulate.a = (0.6 + 0.4 * sin(age * 5.0)) * (0.4 + 0.6 * fade)  # Coals pulsing
	heat.modulate.a = 0.5 * fade * (0.85 + 0.15 * sin(age * 13.0))
	flames.modulate.a = fade
	flames.scale = Vector2.ONE * lerpf(0.65, 1.0, rise) * (0.55 + 0.45 * fade)

func ignite() -> void:
	if is_instance_valid(ring):
		ring.queue_free()
	FX.burst(get_parent(), global_position, FLAME_ORANGE, 10, radius * 2.0, 0.35, 0.3)

func _draw() -> void:
	pass  # Everything is in the layers and sprites above
