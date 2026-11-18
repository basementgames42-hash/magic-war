extends Control
# Boss HUD: the "BOSS INCOMING" announcement (a red flash, a red ribbon
# slamming onto the screen with the boss's name under it, a little shake),
# then the boss's name and health bar along the top of the screen until
# it dies. Lives in the HUD; main.gd calls announce() and defeated().

const RED_RIBBON: Texture2D = preload("res://scenes/ui/skin/ribbon_big_red.png")
const BAR_WIDTH: float = 480.0
const GOLD := Color(1.0, 0.85, 0.35)

var boss: Node2D = null
var bar: ProgressBar
var bar_box: VBoxContainer

func _ready() -> void:
	# Cover the whole screen (anchors AND offsets, or it stays 0 x 0 in the corner).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func announce(boss_name: String, target: Node2D) -> void:
	boss = target
	# Red flash over the whole screen.
	var flash := ColorRect.new()
	flash.color = Color(0.8, 0.05, 0.02, 0.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var t := flash.create_tween()
	t.tween_property(flash, "color:a", 0.35, 0.12)
	t.tween_property(flash, "color:a", 0.0, 0.6)
	t.tween_callback(flash.queue_free)

	# The ribbon and the name, centred a little above the middle.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -140.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	center.add_child(column)
	var ribbon := Label.new()
	ribbon.text = "BOSS INCOMING"
	ribbon.theme_type_variation = &"GoldRibbon"
	ribbon.add_theme_font_size_override("font_size", 52)
	ribbon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(ribbon)
	var red := ribbon.get_theme_stylebox("normal").duplicate() as StyleBoxTexture
	if red:
		red.texture = RED_RIBBON
		ribbon.add_theme_stylebox_override("normal", red)
	var title := Label.new()
	title.text = boss_name
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_constant_override("outline_size", 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	slam_in.call_deferred(center, column, ribbon, title)
	build_bar(boss_name)

func slam_in(center: Control, column: Control, ribbon: Label, title: Label) -> void:
	# Laid out now: the ribbon slams down from huge, the screen shakes, the
	# name fades in under it, it holds, then everything fades away.
	ribbon.pivot_offset = ribbon.size * 0.5
	ribbon.scale = Vector2.ONE * 2.6
	ribbon.modulate.a = 0.0
	title.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(ribbon, "modulate:a", 1.0, 0.15)
	t.parallel().tween_property(ribbon, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(shake.bind(column))
	t.tween_property(title, "modulate:a", 1.0, 0.3)
	t.tween_interval(2.0)
	t.tween_property(center, "modulate:a", 0.0, 0.5)
	t.tween_callback(center.queue_free)
	# The health bar slides in as the announcement clears.
	t.parallel().tween_property(bar_box, "modulate:a", 1.0, 0.5)

func shake(node: Control) -> void:
	var home: Vector2 = node.position
	var t := create_tween()
	for i in 8:
		t.tween_property(node, "position", home + Vector2(randf_range(-12, 12), randf_range(-8, 8)), 0.04)
	t.tween_property(node, "position", home, 0.05)

func build_bar(boss_name: String) -> void:
	bar_box = VBoxContainer.new()
	bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_box.add_theme_constant_override("separation", 2)
	bar_box.anchor_left = 0.5
	bar_box.anchor_right = 0.5
	bar_box.offset_left = -BAR_WIDTH / 2.0
	bar_box.offset_right = BAR_WIDTH / 2.0
	# Below the clock (which drops to a second row on narrow screens).
	bar_box.offset_top = 162.0 if WindowControls.is_narrow() else 96.0
	bar_box.modulate.a = 0.0
	add_child(bar_box)
	var label := Label.new()
	label.text = boss_name
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar_box.add_child(label)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(BAR_WIDTH, 22)
	bar.show_percentage = false
	bar.max_value = boss.max_health
	bar.value = boss.max_health
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.08, 0.05, 0.05, 0.8)
	back.border_color = GOLD
	back.set_border_width_all(2)
	back.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.12, 0.08)
	fill.set_corner_radius_all(5)
	fill.set_expand_margin_all(-2.0)  # Sits inside the gold border
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	bar_box.add_child(bar)

func _process(_delta: float) -> void:
	if boss != null and is_instance_valid(boss) and bar:
		bar.value = maxi(boss.health, 0)

func defeated() -> void:
	# Bar empties, the name flashes "DEFEATED!", then the bar fades out.
	boss = null
	if not bar_box:
		return
	bar.value = 0
	var label: Label = bar_box.get_child(0)
	label.text = "%s  —  DEFEATED!" % label.text
	var t := create_tween()
	t.tween_interval(1.6)
	t.tween_property(bar_box, "modulate:a", 0.0, 0.6)
	t.tween_callback(bar_box.queue_free)
