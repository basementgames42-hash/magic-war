extends Control
# Effect Icons: one small icon under the Level ribbon for every consumable
# working in this run (Battle Elixir, Lucky Charm, Wisdom Tome), whether it
# was bought in the Shop or won from an ad offer mid-run.
# Tap an icon: a little label drops down under it saying what it does. The
# label floats up and fades after 5 seconds, or at once if the icon is
# tapped again. Opening one closes any other.

const ICON_SIZE: float = 40.0
const GAP: float = 6.0
const SHOW_SECONDS: float = 5.0
const GOLD := Color(1.0, 0.82, 0.32)
const INK := Color(0.09, 0.11, 0.2, 0.94)
# What each one does for THIS run (the Shop's text talks about the next run).
const THIS_RUN: Dictionary = {
	"elixir": "+25% damage this run",
	"charm": "+50% gold this run",
	"tome": "+50% EXP this run",
}

var shown: Array[String] = []     # Effect ids with an icon, in order
var buttons: Dictionary = {}      # id -> Button
var open_id: String = ""          # Whose label is showing ("" = none)
var label_panel: PanelContainer = null
var label_timer: float = 0.0
var max_right: float = 340.0  # Icons wrap to a new row past this x (Main sets it)
var per_row: int = 3

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if shown != GameData.run_effects:
		sync_icons()
	if label_panel != null and label_timer > 0.0:
		label_timer -= delta
		if label_timer <= 0.0:
			close_label()

func sync_icons() -> void:
	# Adds icons for new effects (with a little pop) and drops any that ended.
	for id in shown.duplicate():
		if not id in GameData.run_effects:
			buttons[id].queue_free()
			buttons.erase(id)
			shown.erase(id)
			if open_id == id:
				close_label()
	for id in GameData.run_effects:
		if id in shown or not THIS_RUN.has(id):
			continue
		shown.append(id)
		var b: Button = make_icon(id)
		add_child(b)
		buttons[id] = b
		b.pivot_offset = Vector2.ONE * ICON_SIZE * 0.5
		b.scale = Vector2.ONE * 0.3
		create_tween().tween_property(b, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	place_icons()

func place_icons() -> void:
	# As many per row as fit before max_right, then the next row below.
	per_row = maxi(int((max_right - position.x + GAP) / (ICON_SIZE + GAP)), 1)
	for i in shown.size():
		buttons[shown[i]].position = Vector2((i % per_row) * (ICON_SIZE + GAP),
			(i / per_row) * (ICON_SIZE + GAP))

func bottom() -> float:
	# Lowest edge of the icons (or the top of the row when there are none).
	var rows: int = ceili(float(shown.size()) / per_row)
	return position.y + rows * (ICON_SIZE + GAP) - (GAP if rows > 0 else 0.0)

func make_icon(id: String) -> Button:
	var item: Dictionary = ShopCatalog.consumable(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2.ONE * ICON_SIZE
	b.custom_minimum_size = b.size
	b.icon = ShopUI.icon(item["icon"], 28)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = false
	b.tooltip_text = "%s: %s" % [item["name"], THIS_RUN[id]]
	for state in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = INK if state != "hover" else INK.lightened(0.1)
		s.border_color = GOLD if state != "pressed" else GOLD.lightened(0.3)
		s.set_border_width_all(2)
		s.set_corner_radius_all(int(ICON_SIZE * 0.5))  # Round badge
		s.set_content_margin_all(4)
		b.add_theme_stylebox_override(state, s)
	b.pressed.connect(_on_icon_pressed.bind(id))
	return b

func _on_icon_pressed(id: String) -> void:
	Audio.play("ui_click", -8.0)
	var was_open: bool = open_id == id
	close_label()
	if not was_open:
		open_label(id)

func open_label(id: String) -> void:
	var item: Dictionary = ShopCatalog.consumable(id)
	open_id = id
	label_timer = SHOW_SECONDS
	label_panel = PanelContainer.new()
	label_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = INK
	s.border_color = GOLD
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 8
	label_panel.add_theme_stylebox_override("panel", s)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_panel.add_child(column)
	for line in [[item["name"], 18, GOLD], [THIS_RUN[id], 15, Color(0.88, 0.9, 0.96)]]:
		var l := Label.new()
		l.text = line[0]
		l.add_theme_font_size_override("font_size", line[1])
		l.add_theme_color_override("font_color", line[2])
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(l)
	add_child(label_panel)
	# Drops down from under its icon.
	var under: Vector2 = buttons[id].position + Vector2(0, ICON_SIZE + 6.0)
	label_panel.position = under - Vector2(0, 10)
	label_panel.modulate.a = 0.0
	var t := label_panel.create_tween().set_parallel()
	t.tween_property(label_panel, "position", under, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(label_panel, "modulate:a", 1.0, 0.18)

func close_label() -> void:
	# Floats up and fades out (after 5 s, or when its icon is tapped again).
	open_id = ""
	if label_panel == null:
		return
	var old: PanelContainer = label_panel
	label_panel = null
	var t := old.create_tween().set_parallel()
	t.tween_property(old, "position:y", old.position.y - 14.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(old, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(old.queue_free)
