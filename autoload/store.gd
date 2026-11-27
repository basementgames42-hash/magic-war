extends Node
# Store: the one place the game talks to a real-money store. Everything else
# only uses is_available() and buy(), so a real store plugs in here alone
# (Google Play Billing / App Store on phones, or a web checkout):
#   1. Add the store plugin and register the product ids from
#      ShopCatalog.GEM_PACKS (gems_100, gems_550, gems_1200), plus
#      ShopCatalog.UNLOCK_ALL (unlock_all: a one-time, non-consumable buy
#      that "restore purchases" should give back on a new device).
#   2. Make is_available() true once the store is connected.
#   3. Make buy() open the store's checkout, and call finish(true) only when
#      the store confirms the payment (finish(false) if cancelled or failed).
#
# Until then it's a placeholder, set up exactly like Ads: debug builds show a
# labelled TEST checkout that charges nothing. Release builds have no store:
# is_available() is false, so the Shop hides the gem packs (gems still come
# from Daily Quests). The one exception: the Web build shows the test
# checkout when the page address ends in ?teststore=1.

var enabled: bool = OS.is_debug_build() or web_test_store_requested()
var busy: bool = false
var on_finished: Callable
var product: Dictionary = {}
var test_checkout: CanvasLayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

static func web_test_store_requested() -> bool:
	if not OS.has_feature("web"):
		return false
	var query: Variant = JavaScriptBridge.eval("window.location.search", true)
	return query is String and "teststore=1" in query

func is_available() -> bool:
	return enabled

func buy(product_id: String, finished: Callable) -> void:
	# Calls finished(paid: bool) once the checkout closes. On success the gems
	# are already added and saved.
	if busy or not enabled:
		return
	product = ShopCatalog.UNLOCK_ALL if product_id == ShopCatalog.UNLOCK_ALL["id"] \
		else ShopCatalog.gem_pack(product_id)
	if product.is_empty():
		return
	busy = true
	on_finished = finished
	show_test_checkout()

func finish(paid: bool) -> void:
	busy = false
	if test_checkout:
		test_checkout.queue_free()
		test_checkout = null
	if paid:
		if product.has("gems"):
			GameData.add_gems(product["gems"])
		else:
			GameData.unlock_everything()  # The only other product
	on_finished.call(paid)

func show_test_checkout() -> void:
	test_checkout = CanvasLayer.new()
	test_checkout.layer = 100
	add_child(test_checkout)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.08, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	test_checkout.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	test_checkout.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"BannerPanel"
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "TEST CHECKOUT"
	heading.theme_type_variation = &"HeadingLabel"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var body := Label.new()
	var what: String = ("%d gems" % product["gems"]) if product.has("gems") else "everything unlocked"
	body.text = "%s: %s for %s\nThis is a test. No money is charged." % [
		product["name"], what, product["price"]]
	body.theme_type_variation = &"DarkLabel"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(body)
	var pay := Button.new()
	pay.text = "Buy (test)"
	pay.custom_minimum_size = Vector2(380, 66)
	pay.pressed.connect(finish.bind(true))
	column.add_child(pay)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.theme_type_variation = &"RedButton"
	cancel.custom_minimum_size = Vector2(380, 66)
	cancel.pressed.connect(finish.bind(false))
	column.add_child(cancel)
	cancel.grab_focus()
