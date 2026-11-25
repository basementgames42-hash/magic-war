extends Control
# Daily Quests: today's three quests, their progress and Claim buttons, plus
# a gem bonus for finishing all three. New quests every day at midnight.

var coins_label := Label.new()
var gems_label := Label.new()
var list: VBoxContainer
var reset_label: Label

func _ready() -> void:
	Audio.play_music("title")
	GameData.refresh_quests()
	ShopUI.background(self)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	center.add_child(column)
	column.add_child(ShopUI.heading("DAILY QUESTS"))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"BannerPanel"
	column.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	panel.add_child(inner)
	inner.add_child(ShopUI.wallet(coins_label, gems_label))
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.custom_minimum_size.x = minf(680.0, get_viewport_rect().size.x - 80.0)
	inner.add_child(list)
	reset_label = Label.new()
	reset_label.theme_type_variation = &"DarkLabel"
	reset_label.add_theme_font_size_override("font_size", 17)
	reset_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(reset_label)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(240, 60)
	back.add_theme_font_size_override("font_size", 24)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn"))
	inner.add_child(back)
	refresh()

func _process(_delta: float) -> void:
	# Countdown to midnight; rolls the quests over if the screen stays open.
	var now: Dictionary = Time.get_time_dict_from_system()
	var left: int = 86400 - (now["hour"] * 3600 + now["minute"] * 60 + now["second"])
	reset_label.text = "New quests in %dh %02dm" % [left / 3600, (left % 3600) / 60]
	if GameData.quest_day != GameData.today():
		GameData.refresh_quests()
		refresh()

func refresh() -> void:
	coins_label.text = str(GameData.coins)
	gems_label.text = str(GameData.gems)
	for child in list.get_children():
		child.queue_free()
	for i in GameData.quests.size():
		var q: Dictionary = GameData.quests[i]
		var reward: Array = GameData.quest_reward(q)
		var b := Button.new()
		if q["claimed"]:
			b.text = "Claimed"
			b.disabled = true
		elif GameData.quest_done(q):
			b.text = "Claim"
			b.pressed.connect(func():
				if GameData.claim_quest(i):
					Audio.play("level_up", 0.0, 0.0)
					refresh())
		else:
			b.text = "%d / %d" % [q["progress"], q["goal"]]
			b.disabled = true
		var pics: Array = ["coin_silver", "coin_gold", "coin_stack"]
		list.add_child(ShopUI.card(ShopUI.icon(pics[q["tier"]]), GameData.quest_text(q),
			"Reward: %d coins + %d gems" % [reward[0], reward[1]], b))
	var bonus := Button.new()
	if GameData.quest_bonus_claimed:
		bonus.text = "Claimed"
		bonus.disabled = true
	elif GameData.all_quests_claimed():
		bonus.text = "Claim"
		bonus.pressed.connect(func():
			if GameData.claim_quest_bonus():
				Audio.play("level_up", 0.0, 0.0)
				refresh())
	else:
		bonus.text = "Locked"
		bonus.disabled = true
	list.add_child(ShopUI.card(ShopUI.icon("chest_treasure"), "Daily Bonus",
		"Claim all three quests: +%d gems" % ShopCatalog.ALL_DONE_GEMS, bonus))
