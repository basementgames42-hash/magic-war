extends Node2D
# Crit Popup: a big "CRITICAL!" that bursts out over an enemy when a Keen Eye
# critical hit lands. Arcade brawler lettering: chunky slanted letters with a
# thick black outline, a hot red fill with a lighter top edge, a drop shadow,
# and a jagged impact burst behind. Only shown when Damage Numbers are on.
#   const CritPopup = preload("res://scenes/ui/crit_popup.gd")
#   CritPopup.spawn(enemy.global_position)

const WORD: String = "CRITICAL!"
const FONT_SIZE: int = 44
const RED := Color(0.93, 0.08, 0.06)
const RED_TOP := Color(1.0, 0.42, 0.22)    # Lighter band along the top of the letters
const RED_DARK := Color(0.42, 0.02, 0.02)  # Inner outline
const INK := Color(0.05, 0.02, 0.02)       # Outer outline and shadow
const BURST := Color(1.0, 0.82, 0.25)
const LIFETIME: float = 0.95
const MIN_GAP: float = 0.18  # Seconds between popups, so fast crits don't pile up

static var font: Font
static var last_shown: float = -1.0

var age: float = 0.0
var spikes: PackedVector2Array

static func spawn(pos: Vector2) -> void:
	if not GameData.show_damage_numbers:
		return  # Off in Settings, like the damage numbers themselves
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - last_shown < MIN_GAP:
		return
	last_shown = now
	if font == null:
		# The game's own font, made heavy and slanted (works in the web build).
		var f := FontVariation.new()
		f.base_font = ThemeDB.fallback_font
		f.variation_embolden = 1.1
		font = f
	var popup: Node2D = preload("res://scenes/ui/crit_popup.gd").new()
	popup.z_index = 101  # Above damage numbers
	popup.z_as_relative = false
	popup.global_position = pos + Vector2(randf_range(-8, 8), -96)
	popup.rotation = deg_to_rad(randf_range(-9.0, -4.0))
	popup.skew = deg_to_rad(-16.0)  # Letters lean forward, brawler style
	tree.current_scene.add_child(popup)

func _ready() -> void:
	# A jagged star of uneven spikes, different every time.
	var points: int = 14
	for i in points * 2:
		var r: float = (randf_range(46, 62) if i % 2 == 0 else randf_range(20, 28))
		spikes.append(Vector2.from_angle(TAU * i / (points * 2)) * Vector2(r * 1.9, r * 0.8))
	scale = Vector2.ONE * 0.35

func _process(delta: float) -> void:
	age += delta
	# Slam in big, settle, hang, then drift up and fade.
	var s: float
	if age < 0.09:
		s = lerpf(0.35, 1.3, age / 0.09)
	elif age < 0.2:
		s = lerpf(1.3, 1.0, (age - 0.09) / 0.11)
	else:
		s = 1.0
	scale = Vector2.ONE * s
	if age > 0.45:
		position.y -= 38.0 * delta
		modulate.a = clampf(1.0 - (age - 0.45) / (LIFETIME - 0.45), 0.0, 1.0)
	if age >= LIFETIME:
		queue_free()
	queue_redraw()

func _draw() -> void:
	# Impact burst: bright for a moment, then it shrinks away under the word.
	var burst_k: float = clampf(1.0 - age / 0.5, 0.0, 1.0)
	if burst_k > 0.0:
		var star := PackedVector2Array()
		for p in spikes:
			star.append(p * (0.6 + 0.4 * burst_k))
		draw_colored_polygon(star, Color(BURST, minf(1.0, 1.4 * burst_k)))
		draw_polyline(star + PackedVector2Array([star[0]]), Color(INK, 0.8 * burst_k), 3.0)
	var width: float = font.get_string_size(WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var at := Vector2(-width / 2.0, FONT_SIZE * 0.35)
	# Drop shadow, thick black outline, dark red inner outline.
	draw_string_outline(font, at + Vector2(4, 5), WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 16, INK)
	draw_string_outline(font, at, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 16, INK)
	draw_string_outline(font, at, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 7, RED_DARK)
	# Red fill, then a lighter band along the top edge of the letters.
	draw_string(font, at, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, RED)
	draw_string(font, at + Vector2(0, -3), WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(RED_TOP, 0.55))
	draw_string(font, at + Vector2(0, 2), WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, RED)
