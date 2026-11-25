extends Area2D
# XP Orb: dropped by dead enemies. Flies to the player when they get
# close (magnet effect), grants XP on contact.
# Looks like a small emerald sphere of mana with a swirling core, a soft
# halo, and a gentle bob — drawn in code like the spell visuals.

const FX = preload("res://scenes/spells/spell_fx.gd")
const BALANCE: Balance = preload("res://config/balance.tres")

@export var xp_value: int = 1
@export var magnet_range: float = 150.0   # Start flying when player is this close
@export var magnet_speed: float = 400.0   # Faster than the player, so it catches up

@export var attracted_speed: float = 900.0 # Speed once a magnet pickup grabs us

var player: Node2D = null
var attracted: bool = false   # Set by the magnet pickup: fly in from any distance

var age: float = 0.0
var glow: Sprite2D = null
# The orb is drawn ONCE into these child nodes and animated only by moving,
# scaling and rotating them (cheap), instead of redrawing ~10 shapes every
# frame, which made a few hundred orbs slow on the web.
var look: Node2D      # Bob + pulse
var core: Node2D      # Swirl, spins
var twinkle: Node2D   # Rim sparkle, fades in and out

func _ready() -> void:
	# Reach shop upgrade: fly in from farther away.
	magnet_range *= 1.0 + BALANCE.pickup_range_per_level * GameData.meta_upgrades["pickup_range"]
	add_to_group("xp_orbs")
	player = get_tree().get_first_node_in_group("player")
	body_entered.connect(_on_body_entered)

	# Random start point so a pile of orbs doesn't pulse in lockstep.
	age = randf() * TAU
	glow = FX.glow_sprite(Color(0.3, 1.0, 0.8, 0.6), 46.0)
	glow.show_behind_parent = true
	add_child(glow)
	look = Node2D.new()
	add_child(look)
	var body := Node2D.new()
	body.draw.connect(_draw_body.bind(body))
	look.add_child(body)
	core = Node2D.new()
	core.draw.connect(_draw_core.bind(core))
	look.add_child(core)
	twinkle = Node2D.new()
	twinkle.position = Vector2(8.0 * 0.6, -8.0 * 0.65)
	twinkle.draw.connect(_draw_twinkle.bind(twinkle))
	look.add_child(twinkle)
	# Merged orbs (worth more) are a little bigger.
	if xp_value > 1:
		scale = Vector2.ONE * minf(1.0 + 0.12 * (xp_value - 1), 1.8)

func _process(delta: float) -> void:
	age += delta
	var bob: float = sin(age * 3.0) * 2.5
	# The halo breathes along with the sphere and bobs with it.
	glow.scale = Vector2.ONE * (46.0 / 64.0) * (1.0 + sin(age * 4.0) * 0.15)
	glow.position.y = bob
	look.position.y = bob
	look.scale = Vector2.ONE * (1.0 + sin(age * 4.0) * 0.06)
	core.rotation = age * 5.0
	twinkle.modulate.a = clampf(sin(age * 2.3) * 3.0 - 2.0, 0.0, 1.0)

const R: float = 8.0

func _draw_body(n: Node2D) -> void:
	# Sphere = thin rim, emerald body, lighter inner layer, glassy highlight.
	n.draw_circle(Vector2.ZERO, R + 1.0, Color(0.05, 0.4, 0.35, 0.9))
	n.draw_circle(Vector2.ZERO, R, Color(0.15, 0.85, 0.65))
	n.draw_circle(Vector2(0.0, 0.8), R * 0.72, Color(0.45, 1.0, 0.8))
	n.draw_circle(Vector2.ZERO, R * 0.22, Color(0.95, 1.0, 0.95))
	n.draw_circle(Vector2(-R * 0.38, -R * 0.4), R * 0.2, Color(1, 1, 1, 0.85))

func _draw_core(n: Node2D) -> void:
	# Swirling core: two arcs of light chasing each other around.
	n.draw_arc(Vector2.ZERO, R * 0.45, 0.0, PI * 0.8, 10, Color(0.85, 1.0, 0.9, 0.9), 1.4)
	n.draw_arc(Vector2.ZERO, R * 0.45, PI, PI * 1.8, 10, Color(0.85, 1.0, 0.9, 0.9), 1.4)

func _draw_twinkle(n: Node2D) -> void:
	var s: float = 3.5
	n.draw_line(Vector2(-s, 0), Vector2(s, 0), Color.WHITE, 1.0)
	n.draw_line(Vector2(0, -s), Vector2(0, s), Color.WHITE, 1.0)

func _physics_process(delta: float) -> void:
	if player == null:
		return
	if attracted:
		global_position = global_position.move_toward(
			player.global_position, attracted_speed * delta
		)
	# Magnet: if the player is near, slide toward them each frame.
	elif global_position.distance_to(player.global_position) < magnet_range:
		global_position = global_position.move_toward(
			player.global_position, magnet_speed * delta
		)

func _on_body_entered(body: Node2D) -> void:
	# Enemies also touch us — only the player may collect.
	if body.is_in_group("player"):
		body.collect_xp(xp_value)
		Audio.play("xp", -12.0, 0.15)
		FX.burst(get_tree().current_scene, global_position,
			Color(0.4, 1.0, 0.8), 6, 90.0, 0.25, 0.15)
		queue_free()
