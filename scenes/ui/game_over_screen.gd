extends CanvasLayer
# Victory / Defeat screen: a ribbon headline, the run's numbers as tiles that
# count up, a "NEW MAP UNLOCKED" card when a win opens the next map (its
# padlock breaks, like a hero unlock), the weapons and upgrades taken, and
# the way on: Next Level (after a win), Play Again, Upgrades or Main Menu.
# Built in code so it can animate in; only the dim backdrop is in main.tscn.

const FX = preload("res://scenes/spells/spell_fx.gd")
const MAP_PREVIEW = preload("res://scenes/ui/map_preview.gd")
const LOCK_ICON = preload("res://scenes/ui/lock_icon.gd")
const ICONS := "res://scenes/assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/"
const ITEMS := "res://scenes/assets/Items Pack/items/"
const PLAY_ICON: Texture2D = preload(ICONS + "Icon_07.png")
const BACK_ICON: Texture2D = preload(ICONS + "Icon_08.png")
const COIN_ICON: Texture2D = preload(ICONS + "Icon_03.png")
const RED_RIBBON: Texture2D = preload("res://scenes/ui/skin/ribbon_big_red.png")
const GOLD := Color(1.0, 0.85, 0.35)

var next_level: int = -1  # Map the Next Level button leads to (-1 = no button)
var victory: bool = false
var content: Control       # Everything built for this showing (rebuilt each open)
var ribbon: Label
var banner: PanelContainer
var counters: Array = []   # [label, final value, is a time?]
var unlock_lock: Control   # Padlock on the new map's card, broken after the pop-in
var unlock_preview: Control
var unlock_card: Control
var primary: Button

func _ready() -> void:
	visible = false

# title: the ribbon ("VICTORY!"). subtitle: one line under it. won: picks
# the gold or red look and the confetti. stats: see main.gd run_stats().
func open(title: String, subtitle: String, stats: Dictionary, won: bool) -> void:
	victory = won
	next_level = stats.get("next_level", -1)
	if content:
		content.queue_free()
	build(title, subtitle, stats)
	visible = true
	get_tree().paused = true
	animate_in.call_deferred()

# --- Building ---------------------------------------------------------------

func build(title: String, subtitle: String, stats: Dictionary) -> void:
	var narrow: bool = WindowControls.is_narrow()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	$Panel.add_child(center)
	content = center
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	center.add_child(column)

	ribbon = Label.new()
	ribbon.text = title
	ribbon.theme_type_variation = &"GoldRibbon"
	ribbon.add_theme_font_size_override("font_size", 46)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ribbon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(ribbon)  # In the tree first, so the theme's ribbon can be read
	if not victory:
		var red := ribbon.get_theme_stylebox("normal").duplicate() as StyleBoxTexture
		if red:
			red.texture = RED_RIBBON
			ribbon.add_theme_stylebox_override("normal", red)

	banner = PanelContainer.new()
	banner.theme_type_variation = &"BannerPanel"
	banner.custom_minimum_size.x = 520.0 if narrow else 700.0
	column.add_child(banner)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	banner.add_child(body)

	var line := Label.new()
	line.text = subtitle
	line.theme_type_variation = &"HeadingLabel"
	line.add_theme_font_size_override("font_size", 26)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(line)

	body.add_child(stat_tiles(stats, narrow))
	if stats.get("endless", false):
		var record := Label.new()
		record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		record.theme_type_variation = &"DarkLabel"
		record.add_theme_font_size_override("font_size", 20)
		var best: float = stats.get("best", 0.0)
		record.text = "NEW RECORD!" if stats.get("new_record", false) \
			else "Best: %02d:%02d" % [int(best) / 60, int(best) % 60]
		body.add_child(record)
	if stats.has("unlocked_map"):
		body.add_child(unlock_card_for(stats["unlocked_map"], narrow))
	body.add_child(recap(stats))
	body.add_child(buttons(narrow))

func stat_tiles(stats: Dictionary, narrow: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8 if narrow else 12)
	counters.clear()
	var tiles: Array = [
		[ITEMS + "hourglass.png", stats.get("time", 0.0), true, "Time"],
		[ITEMS + "crystal_star.png", stats.get("level", 1), false, "Level"],
		[ITEMS + "skull.png", stats.get("kills", 0), false, "Kills"],
		[ITEMS + "coin_gold.png", stats.get("gold", 0), false, "Gold"],
	]
	if stats.get("endless", false):
		tiles.insert(1, [ITEMS + "hourglass.png", stats.get("wave", 1), false, "Wave"])
	for t in tiles:
		row.add_child(tile(load(t[0]), t[1], t[2], t[3], narrow))
	return row

func tile(icon: Texture2D, value: float, is_time: bool, caption: String, narrow: bool) -> PanelContainer:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.2, 0.08, 0.16)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6)
	box.add_theme_stylebox_override("panel", style)
	box.custom_minimum_size.x = 92.0 if narrow else 118.0
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	box.add_child(stack)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 6)
	stack.add_child(top)
	var pic := TextureRect.new()
	pic.texture = icon
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # Crisp pixel art
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(28, 28)
	top.add_child(pic)
	var number := Label.new()
	number.theme_type_variation = &"DarkLabel"
	number.add_theme_font_size_override("font_size", 26)
	number.text = format_value(0.0, is_time)
	top.add_child(number)
	counters.append([number, value, is_time])
	var label := Label.new()
	label.text = caption
	label.theme_type_variation = &"DarkLabel"
	label.add_theme_font_size_override("font_size", 15)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate.a = 0.75
	stack.add_child(label)
	return box

func unlock_card_for(index: int, narrow: bool) -> PanelContainer:
	var map: Dictionary = Levels.MAPS[index]
	unlock_card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.8, 0.3, 0.22)
	style.border_color = Color(0.75, 0.55, 0.15, 0.8)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(8)
	unlock_card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	unlock_card.add_child(row)
	# The map's live preview, dimmed and padlocked until the lock breaks.
	var shrink: float = 0.5
	var slot := Control.new()
	slot.custom_minimum_size = MAP_PREVIEW.SIZE * shrink
	row.add_child(slot)
	unlock_preview = MAP_PREVIEW.new()
	unlock_preview.index = index
	unlock_preview.scale = Vector2.ONE * shrink
	unlock_preview.modulate = Color(0.45, 0.45, 0.52)
	slot.add_child(unlock_preview)
	unlock_lock = LOCK_ICON.new()
	unlock_lock.scale = Vector2.ONE * 0.7
	unlock_lock.position = slot.custom_minimum_size * 0.5 - unlock_lock.size * 0.5
	slot.add_child(unlock_lock)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var heading := Label.new()
	heading.text = "NEW MAP UNLOCKED!"
	heading.theme_type_variation = &"HeadingLabel"
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", GOLD)
	words.add_child(heading)
	var name_label := Label.new()
	name_label.text = "%d. %s" % [index + 1, map["name"]]
	name_label.theme_type_variation = &"DarkLabel"
	name_label.add_theme_font_size_override("font_size", 22)
	words.add_child(name_label)
	if not narrow:
		var blurb := Label.new()
		blurb.text = map["blurb"]
		blurb.theme_type_variation = &"DarkLabel"
		blurb.add_theme_font_size_override("font_size", 16)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.custom_minimum_size.x = 380.0
		words.add_child(blurb)
	return unlock_card

func recap(stats: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 70)
	# Weapons: the one you start with, then spells in unlock order.
	var weapons: Array = [stats.get("weapon", "Fireball")] + stats.get("spells", [])
	# Upgrades: "Rapid Fire x2" style, or a dash if none were taken.
	var upgrades: Array = []
	var taken: Dictionary = stats.get("upgrades", {})
	for upgrade_name in taken:
		var times: int = taken[upgrade_name]
		upgrades.append(upgrade_name if times == 1 else "%s  x%d" % [upgrade_name, times])
	row.add_child(recap_column("Weapons", weapons))
	row.add_child(recap_column("Upgrades", upgrades if not upgrades.is_empty() else ["—"]))
	return row

func recap_column(header: String, lines: Array) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	var head := Label.new()
	head.text = header
	head.add_theme_font_size_override("font_size", 22)
	column.add_child(head)
	# Long runs: show the first few and how many more, so the screen fits.
	var shown: Array = lines.slice(0, 5)
	if lines.size() > 5:
		shown.append("+%d more" % (lines.size() - 5))
	for text in shown:
		var label := Label.new()
		label.text = text
		label.theme_type_variation = &"DarkLabel"
		label.add_theme_font_size_override("font_size", 18)
		column.add_child(label)
	return column

func buttons(narrow: bool) -> VBoxContainer:
	# One big button for the obvious next step (Next Level after a win, else
	# Play Again), then the rest in one even row underneath.
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	var wide: float = 150.0 if narrow else 196.0
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var again: Button = make_button("Play Again", PLAY_ICON, _on_restart_pressed, narrow)
	if next_level >= 0:
		primary = make_button("Next Level", PLAY_ICON, _on_next_pressed, narrow)
		row.add_child(again)
	else:
		primary = again
	primary.custom_minimum_size = Vector2(320.0 if not narrow else 260.0, 66.0)
	primary.add_theme_font_size_override("font_size", 26)
	primary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(primary)
	row.add_child(make_button("Upgrades", COIN_ICON, _on_upgrades_pressed, narrow))
	var menu: Button = make_button("Main Menu", BACK_ICON, _on_menu_pressed, narrow)
	menu.theme_type_variation = &"RedButton"
	row.add_child(menu)
	for b in row.get_children():
		b.custom_minimum_size = Vector2(wide, 56.0)
	stack.add_child(row)
	return stack

func make_button(text: String, icon: Texture2D, action: Callable, narrow: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = null if narrow else icon  # Phones: text only, so all three fit
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(action)
	return b

# --- Animation --------------------------------------------------------------

func animate_in() -> void:
	# Containers have laid everything out by now, so pivots can be centred.
	fit_to_screen()
	$Panel/ColorRect.modulate.a = 0.0
	banner.pivot_offset = banner.size * 0.5
	ribbon.pivot_offset = ribbon.size * 0.5
	banner.modulate.a = 0.0
	banner.scale = Vector2.ONE * 0.88
	ribbon.modulate.a = 0.0
	ribbon.scale = Vector2.ONE * 0.4
	var tween := create_tween().set_parallel()
	tween.tween_property($Panel/ColorRect, "modulate:a", 1.0, 0.3)
	tween.tween_property(banner, "modulate:a", 1.0, 0.25).set_delay(0.1)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.35).set_delay(0.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ribbon, "modulate:a", 1.0, 0.2).set_delay(0.3)
	tween.tween_property(ribbon, "scale", Vector2.ONE, 0.45).set_delay(0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The numbers count up from zero.
	for c in counters:
		tween.tween_method(func(v: float): c[0].text = format_value(v, c[2]),
			0.0, float(c[1]), 0.9).set_delay(0.45)
	if victory:
		tween.tween_callback(confetti).set_delay(0.45)
		tween.tween_callback(confetti).set_delay(0.8)
	if unlock_lock:
		tween.tween_callback(break_map_lock).set_delay(1.3)
	# The main button breathes gently so the way on is obvious.
	primary.pivot_offset = primary.size * 0.5
	var pulse := create_tween().set_loops()
	pulse.tween_property(primary, "scale", Vector2.ONE * 1.04, 0.6).set_delay(1.2) \
		.set_trans(Tween.TRANS_SINE)
	pulse.tween_property(primary, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)

func fit_to_screen() -> void:
	# Shrink the whole thing (around the screen centre) when it's taller than
	# the screen: a long run's recap, a short phone screen. The ribbon and
	# scroll art draw ~40px outside the measured size.
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var needed: float = content.get_child(0).get_combined_minimum_size().y + 40.0
	var s: float = minf(1.0, (screen.y - 12.0) / needed)
	content.pivot_offset = screen / 2.0
	content.scale = Vector2(s, s)

func confetti() -> void:
	# Bursts of gold, white and teal sparks from both ends of the ribbon.
	var left: Vector2 = ribbon.global_position + Vector2(60, ribbon.size.y * 0.5)
	var right: Vector2 = ribbon.global_position + Vector2(ribbon.size.x - 60, ribbon.size.y * 0.5)
	for spot in [left, right]:
		FX.burst(self, spot, GOLD, 26, 420.0, 0.9, 0.5)
		FX.burst(self, spot, Color(0.6, 1.0, 0.95), 14, 320.0, 0.8, 0.35)
		FX.burst(self, spot, Color.WHITE, 10, 260.0, 0.6, 0.3)

func break_map_lock() -> void:
	unlock_lock.shatter()
	await unlock_lock.shattered
	Audio.play("level_up", 0.0, 0.0)
	unlock_card.pivot_offset = unlock_card.size * 0.5
	var tween := create_tween()
	tween.tween_property(unlock_preview, "modulate", Color(2.0, 1.9, 1.4), 0.12)  # Flash
	tween.tween_property(unlock_preview, "modulate", Color.WHITE, 0.4)
	tween.parallel().tween_property(unlock_card, "scale", Vector2.ONE * 1.05, 0.12)
	tween.tween_property(unlock_card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	FX.burst(self, unlock_preview.global_position + MAP_PREVIEW.SIZE * 0.3, GOLD, 22, 300.0, 0.7, 0.4)

static func format_value(v: float, is_time: bool) -> String:
	if is_time:
		return "%d:%02d" % [int(v) / 60, int(v) % 60]
	return str(roundi(v))

# --- Buttons ----------------------------------------------------------------

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_next_pressed() -> void:
	GameData.level_index = next_level
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_upgrades_pressed() -> void:
	# Spend the gold right away; the shop's Back button then carries on:
	# into the next map after a win, or the same run again otherwise.
	GameData.shop_from_run = true
	GameData.shop_back_text = "Play Again"
	if next_level >= 0:
		GameData.level_index = next_level
		GameData.shop_back_text = "Next Level"
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/upgrade_shop.tscn")

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
