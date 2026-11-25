extends Control
# Shop: three tabs.
#   Items   - consumables bought with coins (Second Chance, next-run boosts)
#   Premium - one-time permanent upgrades bought with gems, and the Coin Chest
#   Gems    - gem packs for real money (only when the Store is available)
# Built in code from ShopCatalog, so new items only need a catalog entry.

var coins_label := Label.new()
var gems_label := Label.new()
var tab_buttons: Dictionary = {}
var list: VBoxContainer
var tab: String = "items"
var panel: PanelContainer

func _ready() -> void:
	Audio.play_music("title")  # Keeps the title tune going
	ShopUI.background(self)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	center.add_child(column)
	column.add_child(ShopUI.heading("SHOP"))
	panel = PanelContainer.new()
	panel.theme_type_variation = &"BannerPanel"
	column.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	panel.add_child(inner)
	inner.add_child(ShopUI.wallet(coins_label, gems_label))
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	inner.add_child(tabs)
	var names: Array = [["items", "Items"], ["premium", "Premium"]]
	if Store.is_available():
		names.append(["gems", "Gems"])
	for entry in names:
		var b := Button.new()
		b.text = entry[1]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(150, 54)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(show_tab.bind(entry[0]))
		tabs.add_child(b)
		tab_buttons[entry[0]] = b
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.name = "Scroll"
	inner.add_child(scroll)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(240, 60)
	back.add_theme_font_size_override("font_size", 24)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn"))
	inner.add_child(back)
	WindowControls.layout_changed.connect(fit_to_screen)
	fit_to_screen()
	show_tab("items")

func fit_to_screen() -> void:
	var view: Vector2 = get_viewport_rect().size
	var scroll: ScrollContainer = panel.find_child("Scroll", true, false)
	scroll.custom_minimum_size = Vector2(minf(680.0, view.x - 80.0), clampf(view.y - 360.0, 220.0, 470.0))

func show_tab(id: String) -> void:
	tab = id
	for key in tab_buttons:
		tab_buttons[key].button_pressed = key == id
	refresh()

func refresh() -> void:
	coins_label.text = str(GameData.coins)
	gems_label.text = str(GameData.gems)
	for child in list.get_children():
		child.queue_free()
	match tab:
		"items": build_items()
		"premium": build_premium()
		"gems": build_gems()

func build_items() -> void:
	for item in ShopCatalog.CONSUMABLES:
		var id: String = item["id"]
		var b := Button.new()
		var desc: String = item["desc"]
		if item["kind"] == "stock":
			desc += "\nOwned: %d / %d" % [GameData.stock_count(id), item["max"]]
			if GameData.stock_count(id) >= item["max"]:
				b.text = "Full"
				b.disabled = true
		elif GameData.is_armed(id):
			desc += "\nReady for your next run."
			b.text = "Ready"
			b.disabled = true
		if b.text == "":
			b.text = "%d coins" % item["cost"]
			b.icon = ShopUI.COIN
			b.expand_icon = false
			b.disabled = GameData.coins < item["cost"]
			b.pressed.connect(func():
				if GameData.buy_consumable(id):
					Audio.play("coin", 0.0, 0.0)
					refresh())
		list.add_child(ShopUI.card(ShopUI.icon(item["icon"]), item["name"], desc, b))

func build_premium() -> void:
	for item in ShopCatalog.PREMIUM:
		var id: String = item["id"]
		var b := Button.new()
		if GameData.has_premium(id):
			b.text = "Owned"
			b.disabled = true
		else:
			b.text = "%d gems" % item["cost"]
			b.icon = ShopUI.icon(ShopCatalog.GEM_ICON, 32)
			b.disabled = GameData.gems < item["cost"]
			b.pressed.connect(func():
				if GameData.buy_premium(id):
					Audio.play("level_up", 0.0, 0.0)
					refresh())
		list.add_child(ShopUI.card(ShopUI.icon(item["icon"]), item["name"], item["desc"], b))
	var chest: Dictionary = ShopCatalog.COIN_CHEST
	var cb := Button.new()
	cb.text = "%d gems" % chest["gems"]
	cb.icon = ShopUI.icon(ShopCatalog.GEM_ICON, 32)
	cb.disabled = GameData.gems < chest["gems"]
	cb.pressed.connect(func():
		if GameData.buy_coin_chest():
			Audio.play("coin", 0.0, 0.0)
			refresh())
	list.add_child(ShopUI.card(ShopUI.icon(chest["icon"]), chest["name"], chest["desc"], cb))
	var note := Label.new()
	note.text = "Earn gems from Daily Quests%s." % (", or buy them in the Gems tab" if Store.is_available() else "")
	note.theme_type_variation = &"DarkLabel"
	note.add_theme_font_size_override("font_size", 17)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(note)

func build_gems() -> void:
	for pack in ShopCatalog.GEM_PACKS:
		var id: String = pack["id"]
		var b := Button.new()
		b.text = pack["price"]
		b.pressed.connect(func():
			Store.buy(id, func(paid: bool):
				if paid:
					Audio.play("level_up", 0.0, 0.0)
				refresh()))
		var desc: String = "%d gems" % pack["gems"]
		if pack.has("tag"):
			desc += "  (%s)" % pack["tag"]
		list.add_child(ShopUI.card(ShopUI.icon(pack["icon"]), pack["name"], desc, b))
	var note := Label.new()
	note.text = "Optional. Everything in the game can be earned by playing."
	note.theme_type_variation = &"DarkLabel"
	note.add_theme_font_size_override("font_size", 17)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(note)
