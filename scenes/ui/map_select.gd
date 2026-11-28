extends Control
# Map Select: the second setup screen for normal runs, after Hero Select.
# Each box shows a live preview of its map (see map_preview.gd). Maps stay
# locked until the one before them is beaten. Play starts the run with the
# hero and map in GameData; Back returns to Hero Select with the hero kept.

# Big boxes, four to a page (a row on a wide screen, 2x2 on a phone), with
# < and > to turn between pages. Every map is on some page.
const MAP_SIZE := Vector2(238, 204)
const PREVIEW_SCALE: float = 1.0    # The live preview at full size
const PER_PAGE: int = 4
const SELECTED_TINT := Color(1.5, 1.35, 0.7)  # Golden glow on the current pick
const LOCKED_TINT := Color(0.45, 0.45, 0.52)
const MAP_PREVIEW = preload("res://scenes/ui/map_preview.gd")
const LOCK_ICON = preload("res://scenes/ui/lock_icon.gd")

var map_buttons: Array[Button] = []
var page: int = 0

func _ready() -> void:
	# A map unlocked since this screen was last seen starts out padlocked,
	# then breaks its lock (like a new hero on Hero Select).
	var celebrate: int = GameData.map_to_celebrate
	for i in Levels.MAPS.size():
		var button: Button = make_map_card(i, GameData.is_level_unlocked(i) and i != celebrate)
		%MapRow.add_child(button)
		map_buttons.append(button)
		button.pressed.connect(select_map.bind(i))
	select_map(mini(GameData.level_index, GameData.levels_unlocked - 1))
	# Open on the page with the chosen map, or the newly unlocked one.
	show_page((celebrate if celebrate >= 0 else GameData.level_index) / PER_PAGE)
	%PrevButton.pressed.connect(turn_page.bind(-1))
	%NextButton.pressed.connect(turn_page.bind(1))
	if celebrate >= 0 and GameData.is_level_unlocked(celebrate):
		get_tree().create_timer(0.6).timeout.connect(break_lock.bind(celebrate))
	if celebrate >= 0:
		GameData.map_to_celebrate = -1
		GameData.save_game()

	WindowControls.layout_changed.connect(fit_to_screen)
	fit_to_screen()
	%PlayButton.pressed.connect(_on_play_pressed)
	%BackButton.pressed.connect(_on_back_pressed)

func fit_to_screen() -> void:
	# Phones: the page's four boxes two to a row.
	%MapRow.columns = 2 if WindowControls.is_narrow() else 4

func page_count() -> int:
	return ceili(map_buttons.size() / float(PER_PAGE))

func show_page(p: int) -> void:
	page = clampi(p, 0, page_count() - 1)
	for i in map_buttons.size():
		map_buttons[i].visible = i / PER_PAGE == page
	# An arrow with no page that way stays in place (so nothing shifts) but fades.
	%PrevButton.disabled = page == 0
	%NextButton.disabled = page == page_count() - 1
	%PrevButton.modulate.a = 0.35 if %PrevButton.disabled else 1.0
	%NextButton.modulate.a = 0.35 if %NextButton.disabled else 1.0
	%PageLabel.text = "%d / %d" % [page + 1, page_count()]

func turn_page(step: int) -> void:
	if page + step < 0 or page + step >= page_count():
		return
	Audio.play("ui_click", -6.0)
	show_page(page + step)

func _unhandled_input(event: InputEvent) -> void:
	# Keyboard / controller: left and right turn the page too.
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		turn_page(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		turn_page(1)

func make_map_card(index: int, unlocked: bool) -> Button:
	var map: Dictionary = Levels.MAPS[index]
	var button := Button.new()
	button.toggle_mode = true
	button.disabled = not unlocked
	button.custom_minimum_size = MAP_SIZE
	var preview: Control = MAP_PREVIEW.new()
	preview.name = "Preview"
	preview.index = index
	preview.position = Vector2(6, 10)
	preview.scale = Vector2.ONE * PREVIEW_SCALE
	button.add_child(preview)
	var label := Label.new()
	label.name = "Label"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(8, 138)
	label.size = Vector2(MAP_SIZE.x - 16.0, 60.0)
	button.add_child(label)
	if unlocked:
		label.text = "%d. %s" % [index + 1, map["name"]]
	else:
		# Same look as a locked hero: dimmed, padlocked, and how to open it.
		preview.modulate = LOCKED_TINT
		label.text = "%d. %s\nBeat %s" % [index + 1, map["name"], Levels.MAPS[index - 1]["name"]]
		label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
		var lock: Control = LOCK_ICON.new()
		lock.name = "Lock"
		lock.position = Vector2(MAP_SIZE.x / 2.0, 70.0) - lock.size * 0.5
		button.add_child(lock)
	return button

func break_lock(index: int) -> void:
	# The new map's padlock bursts, its preview lights up, and it can be picked.
	var button: Button = map_buttons[index]
	var lock: Control = button.get_node("Lock")
	lock.shatter()
	await lock.shattered
	Audio.play("level_up", 0.0, 0.0)
	var label: Label = button.get_node("Label")
	label.remove_theme_color_override("font_color")
	label.text = "%d. %s\nNEW!" % [index + 1, Levels.MAPS[index]["name"]]
	button.disabled = false
	var preview: Control = button.get_node("Preview")
	var tween := create_tween()
	tween.tween_property(preview, "modulate", Color(2.2, 2.0, 1.4), 0.12)  # Flash
	tween.tween_property(preview, "modulate", Color.WHITE, 0.4)
	button.pivot_offset = button.size * 0.5
	tween.parallel().tween_property(button, "scale", Vector2.ONE * 1.06, 0.12)
	tween.tween_property(button, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)

func select_map(index: int) -> void:
	GameData.level_index = index
	for i in map_buttons.size():
		map_buttons[i].set_pressed_no_signal(i == index)
		map_buttons[i].modulate = SELECTED_TINT if i == index else Color.WHITE

func _on_play_pressed() -> void:
	GameData.test_map = {}
	GameData.save_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/run_select.tscn")
