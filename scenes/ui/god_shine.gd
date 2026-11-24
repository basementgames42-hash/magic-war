extends Control
# God Shine: the extra sparkle on a God-Tier level-up button. Two layers,
# each a child covering the button:
#   "sweep" - a band of light gliding across the gold every couple of seconds
#             (clipped to the button)
#   "stars" - four-point stars twinkling around the button's edges
# Drawn with additive blending, so it glows. Never takes clicks.

const FX = preload("res://scenes/spells/spell_fx.gd")
const SWEEP_EVERY: float = 2.4   # Seconds between light sweeps
const SWEEP_TIME: float = 0.9    # How long one sweep takes to cross

var mode: String = "stars"   # "sweep" or "stars"; set before add_child
var clock: float = 0.0
var stars: Array = []        # [position as a fraction of the size, size, phase, speed]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = FX.additive_material()
	clip_contents = mode == "sweep"
	clock = randf() * SWEEP_EVERY  # Buttons don't all sweep at once
	if mode == "stars":
		# Corners, then a few spots along the edges.
		for at in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1),
				Vector2(0.3, 0), Vector2(0.72, 1), Vector2(0, 0.5), Vector2(1, 0.45),
				Vector2(0.55, 0), Vector2(0.18, 1)]:
			stars.append([at, randf_range(7.0, 13.0), randf() * TAU, randf_range(2.5, 4.5)])

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	if mode == "sweep":
		var k: float = fmod(clock, SWEEP_EVERY) / SWEEP_TIME
		if k > 1.0:
			return
		var x: float = lerpf(-80.0, size.x + 80.0, k)
		var slant: float = size.y * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 46, 0),
			Vector2(x + 46 - slant, size.y), Vector2(x - slant, size.y)]), Color(1, 0.95, 0.75, 0.35))
		return
	for s in stars:
		var twinkle: float = 0.5 + 0.5 * sin(clock * s[3] + s[2])
		var r: float = s[1] * (0.45 + 0.55 * twinkle)
		var c: Vector2 = s[0] * size
		var col := Color(1.0, 0.93, 0.6, 0.4 + 0.6 * twinkle)
		# A four-point star: two thin crossed diamonds and a bright dot.
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.22, 0),
			c + Vector2(0, r), c + Vector2(-r * 0.22, 0)]), col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(0, r * 0.22),
			c + Vector2(r, 0), c + Vector2(0, -r * 0.22)]), col)
		draw_circle(c, r * 0.18, Color(1, 1, 1, col.a))
