extends CanvasLayer
# Revive Offer: shown when the player dies and can come back, either by using
# a Second Chance (bought in the Shop, or Phoenix Feather's free one) or by
# watching an ad. Main pauses the game behind it and decides what each
# answer does. Call open() to show it with the right buttons.

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

func open(chances: int, ad: bool) -> void:
	chance_button.visible = chances > 0
	chance_button.text = "Use Second Chance (%d left)" % chances
	watch_button.visible = ad
	body.text = "Fight on from here?" if chances > 0 else "Watch an ad to fight on from here?"
	visible = true

func _on_answer(answer: Signal) -> void:
	visible = false
	answer.emit()
