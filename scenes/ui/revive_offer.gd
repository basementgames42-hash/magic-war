extends CanvasLayer
# Revive Offer: shown when the player dies and still has an ad revive left
# this run (BALANCE.revives_per_run). A Second Chance / Phoenix Feather never
# shows it: Main uses that up on its own at the first death. Main pauses the
# game behind it and decides what each answer does.

signal accepted       # Watch an ad
signal chance_used    # Use a Second Chance
signal declined

var body: Label
var chance_button: Button
var watch_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"BannerPanel"
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "YOU DIED"
	heading.theme_type_variation = &"HeadingLabel"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	body = Label.new()
	body.theme_type_variation = &"DarkLabel"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(body)
	chance_button = Button.new()
	chance_button.custom_minimum_size = Vector2(400, 72)
	chance_button.icon = ShopUI.icon("potion_round_gold", 40)
	chance_button.pressed.connect(_on_answer.bind(chance_used))
	column.add_child(chance_button)
	watch_button = Button.new()
	watch_button.text = "Watch Ad & Continue"
	watch_button.custom_minimum_size = Vector2(400, 72)
	watch_button.icon = ShopUI.icon("crystal_ball", 40)
	watch_button.pressed.connect(_on_answer.bind(accepted))
	column.add_child(watch_button)
	var give_up := Button.new()
	give_up.text = "No Thanks"
	give_up.theme_type_variation = &"RedButton"
	give_up.custom_minimum_size = Vector2(400, 72)
	give_up.pressed.connect(_on_answer.bind(declined))
	column.add_child(give_up)

func open(ads_left: int, ad: bool) -> void:
	# A Second Chance / Phoenix Feather is used up on its own at the first
	# death (Main), so this only ever offers the ad revive now.
	chance_button.visible = false
	watch_button.visible = ad
	body.text = "Watch an ad to fight on from here?"
	if ads_left > 0:
		body.text += "\n%d ad revive%s left this run" % [ads_left, "" if ads_left == 1 else "s"]
	visible = true

func _on_answer(answer: Signal) -> void:
	visible = false
	answer.emit()
