extends Node
# Store: the one place the game talks to a real-money store. Everything else
# only uses is_available(), price_text(), buy() and restore().
#
# Three modes, picked at startup:
#   PLAY - Android builds with the Google Play Billing plugin
#          (addons/GodotGooglePlayBilling). Products are the ids in
#          ShopCatalog.GEM_PACKS (consumable) and ShopCatalog.UNLOCK_ALL
#          (one-time), created with the same ids in the Play Console.
#   TEST - debug builds on desktop / in the editor: a labelled TEST checkout
#          that charges nothing.
#   OFF  - everything else (the Web build, desktop releases): the Shop hides
#          the real-money offers. Gems still come from Daily Quests.
#
# How a Play purchase is handled (also for ones that were interrupted, e.g. the
# app closed mid-purchase, or a slow payment method that clears later; Play
# hands those back at the next start):
#   1. Check it: PURCHASED (not PENDING), for this app, and signed by Google
#      (PLAY_LICENSE_KEY). A failed check is never granted.
#   2. Grant it once: the purchase token is saved, so the same purchase can
#      never give gems twice.
#   3. Tell Play it was delivered: consume (gem packs, so they can be bought
#      again) or acknowledge (Unlock Everything). Play refunds purchases that
#      are not confirmed within 3 days, so this is retried at every start.

# Your app's licence key: Play Console > your app > Monetize with Play >
# Monetization setup > "Licensing" (a long base64 string). Release builds
# refuse purchases until it is set; debug builds skip the signature check.
const PLAY_LICENSE_KEY: String = ""
const PACKAGE_NAME: String = "com.basementgames.magicwar"

enum Mode { OFF, TEST, PLAY }

var mode: Mode = Mode.OFF
var busy: bool = false
var on_finished: Callable
var product: Dictionary = {}
var test_checkout: CanvasLayer = null

# Play state
var billing: Node = null          # The plugin's BillingClient
var connected: bool = false
var prices: Dictionary = {}       # product id -> price in the player's currency, e.g. "€1,09"
var buying: String = ""           # Product id of the purchase in progress
var restore_callback: Callable
var retry_delay: float = 5.0
var verify_key: CryptoKey = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton("GodotGooglePlayBilling"):
		mode = Mode.PLAY
		start_play()
	elif OS.is_debug_build() and not OS.has_feature("web"):
		mode = Mode.TEST

func product_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for pack in ShopCatalog.GEM_PACKS:
		ids.append(pack["id"])
	ids.append(ShopCatalog.UNLOCK_ALL["id"])
	return ids

func is_available() -> bool:
	match mode:
		Mode.TEST: return true
		Mode.PLAY: return connected and not prices.is_empty()
	return false

func price_text(product_id: String) -> String:
	# The store's own price (local currency); the catalog's as a fallback.
	if prices.has(product_id):
		return prices[product_id]
	var item: Dictionary = catalog_item(product_id)
	return item.get("price", "")

func catalog_item(product_id: String) -> Dictionary:
	return ShopCatalog.UNLOCK_ALL if product_id == ShopCatalog.UNLOCK_ALL["id"] \
		else ShopCatalog.gem_pack(product_id)

func buy(product_id: String, finished: Callable) -> void:
	# Calls finished(paid: bool) once the checkout closes. On success the gems
	# are already added and saved.
	if busy or not is_available():
		return
	product = catalog_item(product_id)
	if product.is_empty():
		return
	busy = true
	on_finished = finished
	if mode == Mode.TEST:
		show_test_checkout()
		return
	buying = product_id
	var result: Dictionary = billing.purchase(product_id)
	if int(result.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		buying = ""
		finish(false)
	# Otherwise the result comes back through on_purchase_updated.

func restore(finished: Callable) -> void:
	# "Restore Purchases": asks the store for everything this account owns and
	# gives back Unlock Everything. finished(found: bool).
	match mode:
		Mode.PLAY:
			if not connected:
				finished.call(false)
				return
			restore_callback = finished
			billing.query_purchases(BillingClient.ProductType.INAPP)
		Mode.TEST:
			finished.call(GameData.has_everything())
		_:
			finished.call(false)

func finish(paid: bool) -> void:
	busy = false
	if test_checkout:
		test_checkout.queue_free()
		test_checkout = null
	if mode == Mode.TEST and paid:
		grant(product["id"])
	if on_finished.is_valid():
		on_finished.call(paid)

func grant(product_id: String) -> void:
	var item: Dictionary = catalog_item(product_id)
	if item.has("gems"):
		GameData.add_gems(item["gems"])  # Saves
	elif product_id == ShopCatalog.UNLOCK_ALL["id"]:
		GameData.unlock_everything()

# --- Google Play -------------------------------------------------------------

func start_play() -> void:
	billing = load("res://addons/GodotGooglePlayBilling/BillingClient.gd").new()
	add_child(billing)
	billing.connected.connect(_on_connected)
	billing.disconnected.connect(_on_disconnected)
	billing.connect_error.connect(func(_code, _msg): _on_disconnected())
	billing.query_product_details_response.connect(_on_product_details)
	billing.query_purchases_response.connect(_on_purchases_listed)
	billing.on_purchase_updated.connect(_on_purchase_updated)
	billing.consume_purchase_response.connect(_on_confirmed)
	billing.acknowledge_purchase_response.connect(_on_confirmed)
	if PLAY_LICENSE_KEY != "":
		verify_key = CryptoKey.new()
		var pem: String = "-----BEGIN PUBLIC KEY-----\n%s\n-----END PUBLIC KEY-----" % PLAY_LICENSE_KEY
		if verify_key.load_from_string(pem, true) != OK:
			verify_key = null
			push_error("Store: PLAY_LICENSE_KEY could not be read")
	billing.start_connection()

func _on_connected() -> void:
	connected = true
	retry_delay = 5.0
	billing.query_product_details(product_ids(), BillingClient.ProductType.INAPP)
	billing.query_purchases(BillingClient.ProductType.INAPP)  # Finish anything left over

func _on_disconnected() -> void:
	connected = false
	if busy and buying != "":
		buying = ""
		finish(false)
	get_tree().create_timer(retry_delay, true, false, true).timeout.connect(billing.start_connection)
	retry_delay = minf(retry_delay * 2.0, 120.0)

func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		return
	for details in response.get("product_details", []):
		var id: String = str(details.get("product_id", ""))
		var price: String = find_price(details)
		if id != "" and price != "":
			prices[id] = price

static func find_price(data: Variant) -> String:
	# The first "formatted_price" anywhere inside a product's details (its
	# one-time purchase offer).
	if data is Dictionary:
		if data.has("formatted_price"):
			return str(data["formatted_price"])
		for value in data.values():
			var found: String = find_price(value)
			if found != "":
				return found
	elif data is Array:
		for value in data:
			var found: String = find_price(value)
			if found != "":
				return found
	return ""

func _on_purchases_listed(response: Dictionary) -> void:
	var ok: bool = int(response.get("response_code", -1)) == BillingClient.BillingResponseCode.OK
	var found_unlock: bool = false
	if ok:
		for purchase in response.get("purchases", []):
			if handle_purchase(purchase) and ShopCatalog.UNLOCK_ALL["id"] in purchase.get("product_ids", []):
				found_unlock = true
	if restore_callback.is_valid():
		var callback: Callable = restore_callback
		restore_callback = Callable()
		callback.call(found_unlock)

func _on_purchase_updated(response: Dictionary) -> void:
	var code: int = int(response.get("response_code", -1))
	var granted: bool = false
	if code == BillingClient.BillingResponseCode.OK:
		for purchase in response.get("purchases", []):
			if handle_purchase(purchase) and buying in purchase.get("product_ids", []):
				granted = true
	elif code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
		billing.query_purchases(BillingClient.ProductType.INAPP)  # Owned already: restore it
		granted = buying == ShopCatalog.UNLOCK_ALL["id"]
	if busy and buying != "":
		buying = ""
		finish(granted)

func handle_purchase(purchase: Dictionary) -> bool:
	# True once this purchase's reward is in the save (now or earlier).
	if int(purchase.get("purchase_state", 0)) != BillingClient.PurchaseState.PURCHASED:
		return false  # PENDING: Play sends it again once the payment clears
	if not verified(purchase):
		push_error("Store: purchase failed verification, not granted")
		return false
	var token: String = str(purchase.get("purchase_token", ""))
	var ids: Array = Array(purchase.get("product_ids", []))
	if not GameData.has_purchase_token(token):
		for id in ids:
			grant(str(id))
		GameData.record_purchase_token(token)  # Saves
	# Tell Play it was delivered (retried at every start until it sticks).
	if ShopCatalog.UNLOCK_ALL["id"] in ids:
		if not bool(purchase.get("is_acknowledged", false)):
			billing.acknowledge_purchase(token)
	else:
		billing.consume_purchase(token)
	return true

func verified(purchase: Dictionary) -> bool:
	if str(purchase.get("package_name", PACKAGE_NAME)) != PACKAGE_NAME:
		return false
	if verify_key == null:
		# No licence key yet: fine while testing, never in a release build.
		return OS.is_debug_build()
	var data: PackedByteArray = str(purchase.get("original_json", "")).to_utf8_buffer()
	var signature: PackedByteArray = Marshalls.base64_to_raw(str(purchase.get("signature", "")))
	if data.is_empty() or signature.is_empty():
		return false
	var hash_ctx := HashingContext.new()
	hash_ctx.start(HashingContext.HASH_SHA1)
	hash_ctx.update(data)
	return Crypto.new().verify(HashingContext.HASH_SHA1, hash_ctx.finish(), signature, verify_key)

func _on_confirmed(_response: Dictionary) -> void:
	pass  # A failure is retried by the purchase list at the next start

# --- Test checkout (editor / desktop debug builds) ---------------------------

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
