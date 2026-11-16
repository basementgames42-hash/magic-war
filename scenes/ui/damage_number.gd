extends Label
# DamageNumber: a number that pops up over whoever got hit, drifts up and
# fades out. White = damage you deal to enemies, red = damage you take,
# blue "DODGE" = a hit the Dodge upgrade cancelled.
#   const DamageNumber = preload("res://scenes/ui/damage_number.gd")
#   DamageNumber.spawn(global_position, 12, DamageNumber.ENEMY_HIT)

const ENEMY_HIT := Color(1.0, 1.0, 1.0)
const PLAYER_HIT := Color(1.0, 0.25, 0.2)
const DODGED := Color(0.55, 0.85, 1.0)

const RISE: float = 46.0       # Pixels it floats up over its life
const LIFETIME: float = 0.7

const STACK_GAP: float = 22.0   # Hits close together stack this far apart
const STACK_WINDOW: float = 0.35  # ...if the earlier number is younger than this

# One shared style for every number (outlined so it reads on any ground).
static var settings: LabelSettings
# Numbers still on screen, so two hits on the same target at once stack
# ("20" above "7") instead of overlapping into "207".
static var live: Array = []

var origin: Vector2  # Where the hit was
var born: float      # Seconds (engine clock) when it appeared

static func spawn(pos: Vector2, value: Variant, color: Color, big: bool = false) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	if settings == null:
		settings = LabelSettings.new()
		settings.font_size = 22
		settings.outline_size = 7
		settings.outline_color = Color(0.08, 0.05, 0.05)
	var label := preload("res://scenes/ui/damage_number.gd").new()
	label.text = str(value)
	label.label_settings = settings
	label.modulate = color
	label.scale = Vector2.ONE * (1.4 if big else 1.0)
	label.z_index = 100  # Above enemies, pickups and the y-sorted world
	label.z_as_relative = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.current_scene.add_child(label)
	# Stack above any fresh number from (nearly) the same spot.
	var now: float = Time.get_ticks_msec() / 1000.0
	live = live.filter(func(n): return is_instance_valid(n))
	var stacked: int = 0
	for n in live:
		if now - n.born < STACK_WINDOW and n.origin.distance_to(pos) < 30.0:
			stacked += 1
	label.origin = pos
	label.born = now
	live.append(label)
	# Centre the text on the hit, nudged sideways so a swarm's numbers fan out.
	label.reset_size()
	label.pivot_offset = label.size / 2.0
	label.global_position = pos - label.size / 2.0 \
		+ Vector2(randf_range(-10, 10), -30 - STACK_GAP * stacked)
	label.animate()

func animate() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y - RISE, LIFETIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Pop in, then shrink a little and fade over the second half.
	scale *= 1.3
	tween.tween_property(self, "scale", scale / 1.3, 0.12)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME * 0.5).set_delay(LIFETIME * 0.5)
	tween.chain().tween_callback(queue_free)
