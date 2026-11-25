extends Control
# Shop: three tabs.
#   Items   - consumables bought with coins (Second Chance, next-run boosts)
#   Premium - one-time permanent upgrades bought with gems
#   Gems    - the Coin Chest (gems -> coins), and gem packs for real money
#             (those only when the Store is available)
# Built in code from ShopCatalog, so new items only need a catalog entry.

var coins_label := Label.new()
var gems_label := Label.new()
var tab_buttons: Dictionary = {}
var list: VBoxContainer
var tab: String = "items"
var panel: PanelContainer
var hint_label: Label
const HINTS: Dictionary = {
	"items": "Spend coins. Boosts last for your next run only.",
	"premium": "Spend gems. Bought once, kept forever. Earn gems from Daily Quests.",
	"gems": "Trade gems and coins. Packs are optional: everything can be earned by playing.",
}

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
	# Coins/gems and the tabs share one row (wrapping onto two on a phone).
	var top := HFlowContainer.new()
	top.alignment = FlowContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("h_separation", 24)
	top.add_theme_constant_override("v_separation", 8)
	inner.add_child(top)
	var wallet: HBoxContainer = ShopUI.wallet(coins_label, gems_label)
	wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(wallet)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	top.add_child(tabs)
	var names: Array = [["items", "Items"], ["premium", "Premium"], ["gems", "Gems"]]
	for entry in names:
		var b := Button.new()
		b.text = entry[1]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(128, 52)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(show_tab.bind(entry[0]))
		tabs.add_child(b)
		tab_buttons[entry[0]] = b
	hint_label = ShopUI.hint("")
	inner.add_child(hint_label)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.name = "Scroll"
	inner.add_child(scroll)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
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
	var width: float = minf(660.0, view.x - 80.0)
	scroll.custom_minimum_size = Vector2(width, clampf(view.y - 340.0, 200.0, 5 * 76.0))
	hint_label.custom_minimum_size.x = width

func show_tab(id: String) -> void:
	tab = id
	for key in tab_buttons:
		tab_buttons[key].button_pressed = key == id
	refresh()

func refresh() -> void:
	coins_label.text = str(GameData.coins)
	gems_label.text = str(GameData.gems)
	hint_label.text = HINTS[tab]
	for child in list.get_children():
		child.queue_free()
	match tab:
		"items": build_items()
		"premium": build_premium()
		"gems": build_gems()

func price_button(cost: int, gems: bool) -> Button:
	var b := Button.new()
	b.text = str(cost)
	b.icon = ShopUI.icon(ShopCatalog.GEM_ICON, 30) if gems else ShopUI.icon("coin_gold", 30)
	b.disabled = (GameData.gems if gems else GameData.coins) < cost
	return b

func done_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = true
	return b

func build_items() -> void:
	for item in ShopCatalog.CONSUMABLES:
		var id: String = item["id"]
		var tag: String = ""
		var b: Button
		if item["kind"] == "stock":
			tag = "%d / %d" % [GameData.stock_count(id), item["max"]]
			b = done_button("Full") if GameData.stock_count(id) >= item["max"] 				else price_button(item["cost"], false)
		elif GameData.is_armed(id):
			tag = "Next run"
			b = done_button("Ready")
		else:
			b = price_button(item["cost"], false)
		if not b.disabled:
			b.pressed.connect(func():
				if GameData.buy_consumable(id):
					Audio.play("coin", 0.0, 0.0)
					refresh())
		list.add_child(ShopUI.card(ShopUI.icon(item["icon"]), item["name"], item["desc"], b, tag))

func build_premium() -> void:
	for item in ShopCatalog.PREMIUM:
		var id: String = item["id"]
		var owned: bool = GameData.has_premium(id)
		var b: Button = done_button("Owned") if owned else price_button(item["cost"], true)
		if not owned:
			b.pressed.connect(func():
				if GameData.buy_premium(id):
					Audio.play("level_up", 0.0, 0.0)
					refresh())
		list.add_child(ShopUI.card(ShopUI.icon(item["icon"]), item["name"], item["desc"], b,
			"Owned" if owned else ""))

func build_gems() -> void:
	var chest: Dictionary = ShopCatalog.COIN_CHEST
	var cb: Button = price_button(chest["gems"], true)
	cb.pressed.connect(func():
		if GameData.buy_coin_chest():
			Audio.play("coin", 0.0, 0.0)
			refresh())
	list.add_child(ShopUI.card(ShopUI.icon(chest["icon"]), chest["name"], chest["desc"], cb))
	var ex: Dictionary = ShopCatalog.GEM_EXCHANGE
	var eb: Button = price_button(ex["coins"], false)
	eb.text = "20,000" if ex["coins"] == 20000 else str(ex["coins"])
	eb.pressed.connect(func():
		if GameData.buy_gem_with_coins():
			Audio.play("level_up", 0.0, 0.0)
			refresh())
	list.add_child(ShopUI.card(ShopUI.icon(ex["icon"]), ex["name"], ex["desc"], eb))
	if not Store.is_available():
		hint_label.text = "Trade gems and coins. Earn gems from Daily Quests."
		return
	# The packs as three side-by-side tiles.
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 8)
	list.add_child(tiles)
	for pack in ShopCatalog.GEM_PACKS:
		var id: String = pack["id"]
		var b := Button.new()
		b.text = pack["price"]
		b.pressed.connect(func():
			Store.buy(id, func(paid: bool):
				if paid:
					Audio.play("level_up", 0.0, 0.0)
				refresh()))
		tiles.add_child(ShopUI.tile(ShopUI.icon(pack["icon"]), pack["name"],
			"%d gems" % pack["gems"], b, pack.get("tag", "")))
