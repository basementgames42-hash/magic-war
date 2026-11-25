extends Control
# Ad Offer: the card under the Level ribbon. Every so often it slides in with
# a free reward for watching an ad, picked from ShopCatalog.AD_OFFERS:
#   - x2 Gold / EXP / Drops for a while
#   - a free Second Chance, or a Shop boost (Elixir, Charm, Tome) for this run
#   - gems, for two ads back to back
# Only things sold for coins in the Shop (never gem items). Timing is in
# res://config/balance.tres (boost_*). Its countdowns stop whenever the game
# is paused, like everything in a run.

const BALANCE: Balance = preload("res://config/balance.tres")

enum State { WAITING, OFFERING, WATCHING, ACTIVE, REWARD }

const CARD_SIZE := Vector2(320, 96)
const HOME := Vector2(14, 156)
const GOLD := Color(1.0, 0.82, 0.32)
const INK := Color(0.09, 0.11, 0.2, 0.94)

var state: State = State.WAITING
var timer: float = BALANCE.boost_first_offer
var span: float = 1.0           # What timer counts down from (for the bar)
var offer: Dictionary = {}
var last_id: String = ""
var gem_offers: int = 0
var ads_watched: int = 0

var card: Button
var glow: Control
var icon: TextureRect
var eyebrow: Label
var title: Label
var detail: Label
var cta: Control
var bar: Control
var clock: float = 0.0

func _ready() -> void:
	visible = false
	position = HOME
	size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	build()

# --- Look ---------------------------------------------------------------------

func box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(14)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s

func build() -> void:
	# The whole card is the button: tap anywhere on it.
	card = Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.size = CARD_SIZE
	card.add_theme_stylebox_override("normal", box(INK, GOLD))
	card.add_theme_stylebox_override("hover", box(INK.lightened(0.08), GOLD.lightened(0.3)))
	card.add_theme_stylebox_override("pressed", box(INK.darkened(0.2), GOLD))
	card.add_theme_stylebox_override("disabled", box(INK, Color(GOLD, 0.6)))
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.pressed.connect(_on_pressed)
	add_child(card)

	glow = Control.new()  # Soft pulsing light behind the reward's icon
	glow.position = Vector2(12, 14)
	glow.size = Vector2(64, 64)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.draw.connect(func():
		var pulse: float = 0.5 + 0.5 * sin(clock * 3.0)
		glow.draw_circle(Vector2(32, 32), 30.0 + 3.0 * pulse, Color(GOLD, 0.12 + 0.1 * pulse))
		glow.draw_circle(Vector2(32, 32), 22.0, Color(GOLD, 0.16)))
	card.add_child(glow)
	icon = TextureRect.new()
	icon.position = Vector2(18, 20)
	icon.size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)

	eyebrow = text_label(13, GOLD, Vector2(86, 8))
	title = text_label(21, Color.WHITE, Vector2(86, 24))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("outline_size", 4)
	detail = text_label(15, Color(0.85, 0.88, 0.95), Vector2(86, 52))

	cta = Control.new()  # Green "play" pill on the right
	cta.position = Vector2(CARD_SIZE.x - 64, 26)
	cta.size = Vector2(50, 40)
	cta.pivot_offset = cta.size / 2.0
	cta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cta.draw.connect(func():
		var r := Rect2(Vector2.ZERO, cta.size)
		var pill := StyleBoxFlat.new()
		pill.bg_color = Color(0.3, 0.72, 0.32)
		pill.border_color = Color(0.85, 1.0, 0.8)
		pill.set_border_width_all(2)
		pill.set_corner_radius_all(20)
		cta.draw_style_box(pill, r)
		var c: Vector2 = cta.size / 2.0 + Vector2(2, 0)
		cta.draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -10), c + Vector2(-7, 10), c + Vector2(10, 0)]),
			Color.WHITE))
	card.add_child(cta)

	bar = Control.new()  # Time left, along the bottom edge
	bar.position = Vector2(14, CARD_SIZE.y - 12)
	bar.size = Vector2(CARD_SIZE.x - 28, 5)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var k: float = clampf(timer / span, 0.0, 1.0)
		bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(1, 1, 1, 0.15))
		var tint: Color = GOLD if state != State.ACTIVE else Color(0.5, 0.9, 0.5)
		if state == State.OFFERING and k < 0.3:
			tint = Color(1.0, 0.45, 0.35)
		bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * k, bar.size.y)), tint))
	card.add_child(bar)

func text_label(font_size: int, color: Color, at: Vector2) -> Label:
	var l := Label.new()
	l.position = at
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(l)
	return l

func show_card(eyebrow_text: String, title_text: String, detail_text: String, clickable: bool) -> void:
	eyebrow.text = eyebrow_text
	title.text = title_text
	detail.text = detail_text
	icon.texture = ShopUI.icon(offer["icon"], 52)
	card.disabled = not clickable
	cta.visible = clickable
	bar.visible = state == State.OFFERING or state == State.ACTIVE
	if not visible:
		visible = true
		position = HOME + Vector2(-CARD_SIZE.x - 30, 0)  # Slides in from the left
		create_tween().tween_property(self, "position", HOME, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_card() -> void:
	var t := create_tween()
	t.tween_property(self, "position", HOME + Vector2(-CARD_SIZE.x - 30, 0), 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): visible = false)

# --- Offers -------------------------------------------------------------------

func offer_title(o: Dictionary) -> String:
	return o["title"] % o["gems"] if o["kind"] == "gems" else o["title"]

func offer_detail(o: Dictionary) -> String:
	match o["kind"]:
		"boost": return o["detail"] % int(BALANCE.boost_seconds)
		"gems": return o["detail"] % o["ads"]
	return o["detail"]

func eligible(o: Dictionary) -> bool:
	if o["id"] == last_id:
		return false  # Never the same one twice in a row
	match o["kind"]:
		"stock":
			var item: Dictionary = ShopCatalog.consumable(o["id"])
			return GameData.stock_count(o["id"]) < item.get("max", 99)
		"effect":
			return not o["id"] in GameData.run_effects
		"gems":
			return gem_offers < ShopCatalog.GEM_OFFERS_PER_RUN
	return true

func _process(delta: float) -> void:
	clock += delta
	timer -= delta
	match state:
		State.WAITING:
			if timer <= 0.0 and Ads.is_available():
				start_offer()
		State.OFFERING:
			if timer <= 0.0:
				wait_for_next_offer()
				hide_card()
		State.ACTIVE:
			detail.text = "%ds left" % ceili(maxf(timer, 0.0))
			if timer <= 0.0:
				GameData.active_boost = ""
				wait_for_next_offer()
				hide_card()
		State.REWARD:
			if timer <= 0.0:
				wait_for_next_offer()
				hide_card()
	if visible:
		glow.queue_redraw()
		bar.queue_redraw()
		# The play button gives a little "tap me" bounce every couple of seconds.
		var beat: float = fmod(clock, 1.6)
		cta.scale = Vector2.ONE * (1.0 + 0.12 * maxf(0.0, sin(beat * PI / 0.35)) * float(beat < 0.35))

func start_offer() -> void:
	var pool: Array = ShopCatalog.AD_OFFERS.filter(eligible)
	if pool.is_empty():
		wait_for_next_offer()
		return
	offer = pool[randi() % pool.size()]
	last_id = offer["id"]
	if offer["kind"] == "gems":
		gem_offers += 1
	state = State.OFFERING
	timer = BALANCE.boost_offer_seconds
	span = timer
	ads_watched = 0
	var eyebrow_text: String = "FREE  ·  %d ADS" % offer["ads"] if offer["kind"] == "gems" else "FREE  ·  WATCH AN AD"
	show_card(eyebrow_text, offer_title(offer), offer_detail(offer), true)

func wait_for_next_offer() -> void:
	state = State.WAITING
	timer = BALANCE.boost_offer_gap

func _on_pressed() -> void:
	if state != State.OFFERING and state != State.WATCHING:
		return
	var series: String = ""
	if offer["kind"] == "gems":
		series = "Ad %d of %d" % [ads_watched + 1, offer["ads"]]
	Ads.show_rewarded(_on_ad_finished, series)

func _on_ad_finished(rewarded: bool) -> void:
	if not rewarded:
		# Skipped: nothing given, and the offer goes away.
		wait_for_next_offer()
		hide_card()
		return
	ads_watched += 1
	if offer["kind"] == "gems" and ads_watched < offer["ads"]:
		# Back to back: the next ad starts straight away.
		state = State.WATCHING
		show_card("AD %d OF %d DONE" % [ads_watched, offer["ads"]], offer_title(offer), "Next ad starting...", false)
		_on_pressed.call_deferred()
		return
	give_reward()

func give_reward() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	match offer["kind"]:
		"boost":
			GameData.active_boost = offer["id"]
			state = State.ACTIVE
			timer = BALANCE.boost_seconds
			span = timer
			show_card("ACTIVE", offer_title(offer), "%ds left" % int(timer), false)
			celebrate()
			return
		"stock":
			GameData.add_stock(offer["id"])
		"effect":
			GameData.run_effects.append(offer["id"])
			if offer["id"] == "elixir" and player:
				player.weapon_damage = roundi(player.weapon_damage * ShopCatalog.ELIXIR_DAMAGE)
		"gems":
			GameData.add_gems(offer["gems"])
	state = State.REWARD
	timer = 2.5
	var got: String = {"stock": "Ready for when you fall", "effect": "Working for the rest of this run",
		"gems": "Added to your gems"}[offer["kind"]]
	show_card("REWARD!", offer_title(offer).trim_prefix("Free "), got, false)
	celebrate()

func celebrate() -> void:
	Audio.play("level_up", -4.0, 0.0)
	var pop := create_tween()
	card.pivot_offset = CARD_SIZE / 2.0
	pop.tween_property(card, "scale", Vector2.ONE * 1.08, 0.12)
	pop.tween_property(card, "scale", Vector2.ONE, 0.18)
