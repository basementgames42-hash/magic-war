extends Control
# Ad Offer: the card under the Level ribbon. Every so often it slides in with
# a free reward for watching an ad, picked from ShopCatalog.AD_OFFERS:
#   - x2 Gold / EXP / Drops for a while
#   - a free Second Chance, or a Shop boost (Elixir, Charm, Tome) for this run
#   - gems, for two ads back to back
# Only things sold for coins in the Shop (never gem items). Timing is in
# res://config/balance.tres (boost_*). Its countdowns stop whenever the game
# is paused, like everything in a run.
#
# Earned x2 boosts run on their own timers, listed above the card, so the card
# goes away after the reward and the next offer still comes on schedule. Boosts
# of different kinds stack; one already running is not offered again.

const BALANCE: Balance = preload("res://config/balance.tres")

enum State { WAITING, OFFERING, WATCHING, REWARD }

const CARD_SIZE := Vector2(340, 96)
const TEXT_X: float = 86.0
var home := Vector2(14, 156)   # Set each frame by main.gd (stack_status_column)
const GOLD := Color(1.0, 0.82, 0.32)
const INK := Color(0.09, 0.11, 0.2, 0.94)

var state: State = State.WAITING
var timer: float = BALANCE.boost_first_offer
var span: float = 1.0           # What timer counts down from (for the bar)
var offer: Dictionary = {}
var last_id: String = ""
var gem_offers: int = 0
var ads_watched: int = 0
var boosts: Dictionary = {}     # Running x2 boosts: offer id -> seconds left

var card: Button
var badges: VBoxContainer       # One line per running boost, under the card
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
	position = home
	size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	build()
	# A sibling, not a child, so the list stays up while the card is hidden.
	badges = VBoxContainer.new()
	badges.position = home + Vector2(0, CARD_SIZE.y + 8)
	badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badges.add_theme_constant_override("separation", 4)
	add_sibling.call_deferred(badges)

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
		var tint: Color = GOLD
		if k < 0.3:
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

func fit(label: Label, text: String, base_size: int, width: float) -> void:
	# Shrinks the font until the text fits beside the play button, so nothing
	# runs under it whatever the language or font.
	label.text = text
	var font: Font = label.get_theme_font("font")
	var size: int = base_size
	while size > 11 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	label.add_theme_font_size_override("font_size", size)

func show_card(eyebrow_text: String, title_text: String, detail_text: String, clickable: bool) -> void:
	# Text stops short of the play button (or the card's edge without it).
	var width: float = (cta.position.x - 8.0 if clickable else CARD_SIZE.x - 14.0) - TEXT_X
	fit(eyebrow, eyebrow_text, 13, width)
	fit(title, title_text, 21, width)
	fit(detail, detail_text, 15, width)
	icon.texture = ShopUI.icon(offer["icon"], 52)
	card.disabled = not clickable
	cta.visible = clickable
	bar.visible = state == State.OFFERING
	if not visible:
		visible = true
		position = Vector2(home.x - CARD_SIZE.x - 30, home.y)  # Slides in from the left
		create_tween().tween_property(self, "position:x", home.x, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_card() -> void:
	var t := create_tween()
	t.tween_property(self, "position:x", home.x - CARD_SIZE.x - 30, 0.25) \
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
		"boost":
			return not boosts.has(o["id"])  # Already running: offer something else
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
		State.REWARD:
			if timer <= 0.0:
				wait_for_next_offer()
				hide_card()
	tick_boosts(delta)
	# Glides up or down when things above it in the column come or go.
	position.y = lerpf(position.y, home.y, minf(1.0, delta * 12.0)) if visible else home.y
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
			boosts[offer["id"]] = BALANCE.boost_seconds
			if not offer["id"] in GameData.active_boosts:
				GameData.active_boosts.append(offer["id"])
			tick_boosts(0.0)
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
	var got: String = {"boost": "Active for %ds" % int(BALANCE.boost_seconds),
		"stock": "Ready for when you fall", "effect": "Working for the rest of this run",
		"gems": "Added to your gems"}[offer["kind"]]
	show_card("REWARD!", offer_title(offer), got, false)
	celebrate()

func tick_boosts(delta: float) -> void:
	# Counts the running boosts down, ends the ones that run out, and updates
	# their badges under the card.
	for id in boosts.keys():
		boosts[id] -= delta
		if boosts[id] <= 0.0:
			boosts.erase(id)
			GameData.active_boosts.erase(id)
	if badges == null or not badges.is_inside_tree():
		return
	# One tidy badge per boost (icon, name, seconds left, a bar running down),
	# built once and then only its numbers change.
	for id in badge_nodes.keys():
		if not boosts.has(id):
			badge_nodes[id]["panel"].queue_free()
			badge_nodes.erase(id)
	for id in boosts:
		if not badge_nodes.has(id):
			badge_nodes[id] = make_badge(id)
		var parts: Dictionary = badge_nodes[id]
		parts["time"].text = "%ds" % ceili(boosts[id])
		parts["fill"] = clampf(boosts[id] / BALANCE.boost_seconds, 0.0, 1.0)
		parts["bar"].set_meta("fill", parts["fill"])
		parts["bar"].queue_redraw()

const BADGE_GREEN := Color(0.5, 0.92, 0.5)
var badge_nodes: Dictionary = {}  # Boost id -> {panel, time, bar, fill}

func make_badge(id: String) -> Dictionary:
	var info: Dictionary = {}
	for o in ShopCatalog.AD_OFFERS:
		if o["id"] == id:
			info = o
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(196, 0)
	var s := StyleBoxFlat.new()
	s.bg_color = INK
	s.border_color = BADGE_GREEN
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 8
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", s)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	var pic := TextureRect.new()
	pic.texture = ShopUI.icon(info.get("icon", "coin_gold"), 22)
	pic.custom_minimum_size = Vector2(22, 22)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var name_label := Label.new()
	name_label.text = info.get("title", id)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)
	var time_label := Label.new()
	time_label.add_theme_font_size_override("font_size", 15)
	time_label.add_theme_color_override("font_color", BADGE_GREEN)
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(time_label)
	var bar := Control.new()  # Time left, shrinking along the bottom
	bar.custom_minimum_size = Vector2(0, 3)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var k: float = bar.get_meta("fill", 1.0)
		bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(1, 1, 1, 0.15))
		bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * k, bar.size.y)), BADGE_GREEN))
	column.add_child(bar)
	badges.add_child(panel)
	# Pops in.
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.2)
	return {"panel": panel, "time": time_label, "bar": bar, "fill": 1.0}

func celebrate() -> void:
	Audio.play("level_up", -4.0, 0.0)
	var pop := create_tween()
	card.pivot_offset = CARD_SIZE / 2.0
	pop.tween_property(card, "scale", Vector2.ONE * 1.08, 0.12)
	pop.tween_property(card, "scale", Vector2.ONE, 0.18)
