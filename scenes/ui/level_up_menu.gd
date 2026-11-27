extends CanvasLayer
# Level-Up Menu: pauses the game, offers 3 random upgrades.
# Spell unlocks are marked "once" and leave the pool after being taken.
# Entries with a "weapon" can be picked again to level that weapon up.
# A run may add at most BALANCE.max_extra_weapons new weapons (spells and
# level-up weapons) to the hero's own. Once that many are taken the rest
# leave the pool for good; upgrades to the ones you have keep coming.
# Past BALANCE.epic_min_level, with 2+ additional weapons, a level-up may
# swap one choice for a purple Epic Combo of two of them (epic_combo.gd),
# up to BALANCE.max_epics per run.
# Endless only: from BALANCE.god_min_level, once three additional weapons
# are taken, one level-up offers three gold God-Tier Combos instead
# (god_combo.gd), one led by each weapon. One per run.

const BALANCE: Balance = preload("res://config/balance.tres")
const EPIC_COMBO = preload("res://scenes/spells/epic_combo.gd")
const EPIC_TINT := Color(0.78, 0.45, 1.25)  # Purple wash over an Epic choice's button
const GOD_COMBO = preload("res://scenes/spells/god_combo.gd")
const GOD_TINT := Color(1.0, 0.76, 0.22)   # God-Tier choices: a gold button (see paint_button)
const GOD_SHINE = preload("res://scenes/ui/god_shine.gd")
const FX = preload("res://scenes/spells/spell_fx.gd")
# Weapon id -> its name, for "Frozen Tempest: Lightning Arc + Frost Nova".
const WEAPON_NAMES: Dictionary = {
	"lightning": "Lightning Arc", "frost": "Frost Nova", "orbit": "Arcane Orbit",
	"runeward": "Runeward Circle", "starfall": "Starfall", "moonreaver": "Moonreaver",
	"thornwake": "Thornwake",
}

# Upgrades to the starting weapon, by weapon: damage, fire rate, and speed
# (projectiles) or reach (melee).
const WEAPON_UPGRADES: Dictionary = {
	"fireball": [
		{"name": "Sharper Flames", "desc": "Fireball damage +{dmg}", "id": "damage"},
		{"name": "Rapid Fire", "desc": "Fire {rate}% faster", "id": "fire_rate"},
		{"name": "Blazing Bolts", "desc": "Fireballs fly {proj}% faster", "id": "projectile_speed"},
	],
	"cleave": [
		{"name": "Honed Edge", "desc": "Cleave damage +{dmg}", "id": "damage"},
		{"name": "Battle Rhythm", "desc": "Cleave {rate}% faster", "id": "fire_rate"},
		{"name": "Wide Swing", "desc": "Cleave reach +{reach}%", "id": "reach"},
	],
	"thrust": [
		{"name": "Tempered Tip", "desc": "Lance damage +{dmg}", "id": "damage"},
		{"name": "Quick Recovery", "desc": "Thrust {rate}% faster", "id": "fire_rate"},
		{"name": "Long Haft", "desc": "Lance reach +{reach}%", "id": "reach"},
	],
	"arrow": [
		{"name": "Barbed Heads", "desc": "Arrow damage +{dmg}", "id": "damage"},
		{"name": "Quick Draw", "desc": "Shoot {rate}% faster", "id": "fire_rate"},
		{"name": "Strong Bow", "desc": "Arrows fly {proj}% faster", "id": "projectile_speed"},
	],
}

# Entries with a "weapon" level up: they stay in the pool until BALANCE.weapon_max_level.
var upgrade_pool: Array = [
	{"name": "Swift Boots", "desc": "Move speed +{boots}%", "id": "move_speed"},
	{"name": "Keen Eye", "desc": "Critical hit chance +{crit}% (crits deal {mult}x damage)", "id": "crit"},
	{"name": "Lightning Arc", "desc": "NEW SPELL: zaps random enemies", "id": "unlock_lightning", "once": true},
	{"name": "Frost Nova", "desc": "NEW SPELL: icy blast that slows", "id": "unlock_frost", "once": true},
	{"name": "Arcane Orbit", "desc": "NEW SPELL: orbs circle you", "id": "unlock_orbit", "once": true},
	{"name": "Runeward Circle", "desc": "NEW WEAPON: enemies inside the ring take damage",
		"more": "larger ring, more damage", "weapon": "runeward"},
	{"name": "Starfall", "desc": "NEW WEAPON: stars crash down on enemies",
		"more": "bigger blasts, more damage", "weapon": "starfall"},
	{"name": "Moonreaver", "desc": "NEW WEAPON: a blade that flies out and returns",
		"more": "more damage, extra blades", "weapon": "moonreaver"},
	{"name": "Thornwake", "desc": "NEW WEAPON: brambles grow along your path",
		"more": "bigger, sharper brambles", "weapon": "thornwake"},
]

var current_choices: Array = []
# What was picked this round, for the game-over recap.
var spells_taken: Array[String] = []        # Spell names, in unlock order
var upgrades_taken: Dictionary = {}         # Upgrade name -> times picked
var weapon_ids: Dictionary = {}             # Levelled weapon name -> its id
var extra_weapons: int = 0                  # New weapons taken this run (spells + level-up weapons)
var acquired: Array[String] = []            # Their ids, in pick order ("lightning", "starfall"...)
var epics_taken: Array[String] = []         # Epic Combo ids gained this run
var god_taken: bool = false                 # A God-Tier Combo was chosen this run
var buttons: Array = []
var player: Node = null

func _ready() -> void:
	visible = false
	player = get_tree().get_first_node_in_group("player")
	upgrade_pool.append_array(WEAPON_UPGRADES[player.character["weapon"]])
	buttons = [%Option1, %Option2, %Option3]
	for i in 3:
		buttons[i].pressed.connect(_on_option_pressed.bind(i))

func open() -> void:
	# Always three choices, drawn only from what the player can still take.
	current_choices = upgrade_pool.filter(eligible)
	current_choices.shuffle()
	current_choices = current_choices.slice(0, 3)
	var god: bool = god_ready()
	if god:
		current_choices = god_options()
	else:
		maybe_offer_epic()
	set_heading(god)

	for i in 3:
		buttons[i].text = current_choices[i]["name"] + "\n" + describe(current_choices[i])
		var tint: Variant = GOD_TINT if current_choices[i].has("god") \
			else (EPIC_TINT if current_choices[i].has("epic") else null)
		paint_button(buttons[i], tint)
		# Long descriptions wrap on a phone rather than pushing off the screen,
		# and God-Tier ones (the longest) always wrap.
		buttons[i].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART \
			if WindowControls.is_narrow() or god else TextServer.AUTOWRAP_OFF
		# God-Tier buttons are wider, so their text stays at about two lines.
		buttons[i].custom_minimum_size.x = (520.0 if WindowControls.is_narrow() else 780.0) \
			if god else 460.0

	visible = true
	get_tree().paused = true
	if god:
		Audio.play("victory", -2.0, 0.0)
		god_reveal.call_deferred()
	else:
		Audio.play("level_up", -3.0, 0.0)

func epic_options() -> Array[String]:
	# Every pair of this run's additional weapons not combined yet.
	var out: Array[String] = []
	for i in acquired.size():
		for j in range(i + 1, acquired.size()):
			var id: String = EPIC_COMBO.combo_id(acquired[i], acquired[j])
			if not id in epics_taken:
				out.append(id)
	return out

func maybe_offer_epic() -> void:
	# Sometimes (never guaranteed) one of the three choices becomes an Epic.
	if player.level <= BALANCE.epic_min_level or epics_taken.size() >= BALANCE.max_epics:
		return
	var options: Array[String] = epic_options()
	if options.is_empty() or randf() >= BALANCE.epic_offer_chance:
		return
	var id: String = options.pick_random()
	var parts: PackedStringArray = id.split("+")
	current_choices[randi() % current_choices.size()] = {
		"epic": id, "name": "EPIC: " + EPIC_COMBO.COMBOS[id][0],
		"desc": "%s  (%s + %s)" % [EPIC_COMBO.COMBOS[id][1], WEAPON_NAMES[parts[0]], WEAPON_NAMES[parts[1]]],
	}

const GOD_WEAPONS: int = 3  # A God-Tier is one lead weapon plus two infused ones

func god_ready() -> bool:
	# Endless, past the level, three extra weapons in hand, none taken yet.
	# (A run can hold four; God-Tier doesn't wait for the fourth.)
	return GameData.endless and not god_taken and player.level >= BALANCE.god_min_level \
		and acquired.size() >= GOD_WEAPONS

func god_options() -> Array:
	# Three God-Tiers from the same three weapons: each one led by a
	# different weapon, with the other two infused into it.
	var trio: Array[String] = acquired.slice(0, GOD_WEAPONS)  # The first three taken
	var out: Array = []
	for lead in trio:
		var others: Array = trio.filter(func(w): return w != lead)
		var id: String = GOD_COMBO.combo_id(lead, others)
		out.append({"god": id, "name": "GOD-TIER: " + GOD_COMBO.title(id), "desc": GOD_COMBO.blurb(id)})
	return out

func set_heading(god: bool) -> void:
	var heading: Label = get_node_or_null("CenterContainer/VBoxContainer/TitleLabel")
	var subtitle: Label = get_node_or_null("CenterContainer/VBoxContainer/Panel/VBoxContainer/Subtitle")
	if heading:
		heading.text = "GOD-TIER!" if god else "LEVEL UP!"
	if subtitle:
		subtitle.text = "Choose one ultimate power" if god else "Choose an upgrade"

func paint_button(button: Button, tint: Variant) -> void:
	# Epic choices get a purple wash on every state of the button. God-Tier
	# choices are solid gold instead (tinting the blue button art toward gold
	# just turns it green). null = the normal look.
	for fx in button.get_children():
		if fx.is_in_group("god_fx"):
			fx.queue_free()
	# God-Tier text is drawn by a rich-text label on top (decorate_god), so
	# only the title can be bold; the button's own text stays for its size,
	# but invisible.
	var colours: Array[String] = ["font_color", "font_hover_color", "font_pressed_color",
		"font_focus_color", "font_outline_color"]
	for colour in colours:
		button.remove_theme_color_override(colour)
	# The regular text colours, read before they're hidden below.
	var text_colour: Color = button.get_theme_color("font_color")
	var outline_colour: Color = button.get_theme_color("font_outline_color")
	if tint == GOD_TINT:
		for colour in colours:
			button.add_theme_color_override(colour, Color(0, 0, 0, 0))
	for state in ["normal", "hover", "pressed", "focus"]:
		button.remove_theme_stylebox_override(state)
		if tint == GOD_TINT:
			button.add_theme_stylebox_override(state, gold_box(state))
		elif tint != null:
			var box := button.get_theme_stylebox(state).duplicate()
			if box is StyleBoxTexture:
				box.modulate_color = tint
			elif box is StyleBoxFlat:
				box.bg_color = box.bg_color * tint
			button.add_theme_stylebox_override(state, box)
	if tint == GOD_TINT:
		decorate_god(button, text_colour, outline_colour)

func gold_box(state: String) -> StyleBoxFlat:
	# Deep burnished gold with a bright gold rim and a warm glow around it, so
	# the regular white text reads clearly on it.
	var gold := Color(0.78, 0.5, 0.08)
	var box := StyleBoxFlat.new()
	box.bg_color = {"normal": gold, "hover": gold.lightened(0.15),
		"pressed": gold.darkened(0.15), "focus": gold.lightened(0.08)}[state]
	box.border_color = Color(1.0, 0.88, 0.45)
	box.set_border_width_all(4)
	box.set_corner_radius_all(14)
	box.shadow_color = Color(1.0, 0.8, 0.25, 0.7 if state == "hover" else 0.5)
	box.shadow_size = 14 if state == "hover" else 10
	box.set_content_margin_all(12)
	return box

func decorate_god(button: Button, text_colour: Color, outline_colour: Color) -> void:
	# The text on top: "GOD-TIER:" and the title in bold, the description in
	# the same weight, size and colour as every other upgrade.
	var choice: Dictionary = current_choices[buttons.find(button)]
	var label := RichTextLabel.new()
	label.add_to_group("god_fx")
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_TOP]:
		label.set_offset(side, 12.0)
	for side in [SIDE_RIGHT, SIDE_BOTTOM]:
		label.set_offset(side, -12.0)
	var font: Font = button.get_theme_font("font")
	var bold := FontVariation.new()
	bold.base_font = font
	bold.variation_embolden = 0.9
	var size: int = button.get_theme_font_size("font_size")
	label.add_theme_font_override("normal_font", font)
	label.add_theme_font_override("bold_font", bold)
	label.add_theme_font_size_override("normal_font_size", size)
	label.add_theme_font_size_override("bold_font_size", size)
	label.add_theme_color_override("default_color", text_colour)
	label.add_theme_color_override("font_outline_color", outline_colour)
	label.add_theme_constant_override("outline_size", button.get_theme_constant("outline_size"))
	label.text = "[center][b]GOD-TIER:[/b] [b]%s[/b]
%s[/center]" % [
		choice["name"].trim_prefix("GOD-TIER: "), describe(choice)]
	button.add_child(label)
	# The sparkle: a light sweep across the gold, stars on the edges and
	# drifting golden motes.
	for mode in ["sweep", "stars"]:
		var shine: Control = GOD_SHINE.new()
		shine.mode = mode
		shine.add_to_group("god_fx")
		button.add_child(shine)
	var motes := CPUParticles2D.new()
	motes.add_to_group("god_fx")
	motes.texture = FX.glow_texture()
	motes.material = FX.additive_material()
	motes.amount = 18
	motes.lifetime = 1.3
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.direction = Vector2.UP
	motes.spread = 25.0
	motes.gravity = Vector2(0, -40)
	motes.initial_velocity_min = 10.0
	motes.initial_velocity_max = 40.0
	motes.scale_amount_min = 0.08
	motes.scale_amount_max = 0.2
	motes.color = Color(1.0, 0.88, 0.45)
	motes.color_ramp = FX.fade_ramp()
	button.add_child(motes)
	# Placed once the button has its real size.
	(func():
		motes.position = button.size * 0.5
		motes.emission_rect_extents = button.size * 0.5).call_deferred()

func god_reveal() -> void:
	# The God-Tier pop-up: the ribbon bounces in, golden sparks burst from
	# it, and the three choices drop in one after another.
	var heading: Label = get_node_or_null("CenterContainer/VBoxContainer/TitleLabel")
	if heading:
		heading.pivot_offset = heading.size * 0.5
		heading.scale = Vector2.ONE * 1.8
		var h := create_tween()
		h.tween_property(heading, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var at := Vector2(get_viewport().get_visible_rect().size.x * 0.5,
			heading.global_position.y + heading.size.y * 0.5)  # Centre of the ribbon
		for color in [Color(1.0, 0.85, 0.35), Color.WHITE, Color(1.0, 0.6, 0.2)]:
			FX.burst(self, at, color, 28, 460.0, 0.9, 0.45)
	for i in buttons.size():
		var b: Button = buttons[i]
		b.pivot_offset = b.size * 0.5
		b.scale = Vector2.ONE * 0.6
		b.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.2 + 0.14 * i)
		t.tween_property(b, "modulate:a", 1.0, 0.15)
		t.parallel().tween_property(b, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_callback(func(): FX.burst(self, b.global_position + b.size * 0.5, Color(1.0, 0.85, 0.35), 14, 320.0, 0.6, 0.3))

func is_new_weapon(choice: Dictionary) -> bool:
	# A spell unlock, or a level-up weapon the player doesn't have yet.
	if choice.get("once", false):
		return true
	return choice.has("weapon") and player.weapon_level(choice["weapon"]) == 0

func eligible(choice: Dictionary) -> bool:
	if is_new_weapon(choice) and extra_weapons >= BALANCE.max_extra_weapons:
		return false
	if choice.get("id", "") == "crit" and player.crit_chance >= BALANCE.crit_max:
		return false
	return true

func describe(choice: Dictionary) -> String:
	if choice.has("epic") or choice.has("god"):
		return choice["desc"]
	if choice.has("weapon"):
		var level: int = player.weapon_level(choice["weapon"])
		if level > 0:
			return "Level %d: %s" % [level + 1, choice["more"]]
	# Starting-weapon upgrades: the real numbers come from balance.tres.
	var text: String = choice["desc"].format({
		"dmg": player.damage_pick(),
		"rate": roundi(BALANCE.fire_rate_pick * 100.0),
		"reach": roundi(BALANCE.reach_pick * 100.0),
		"proj": roundi(BALANCE.projectile_speed_pick * 100.0),
		"boots": roundi(BALANCE.move_speed_pick * 100.0),
		"crit": ("%.2f" % (BALANCE.crit_chance_per_pick * 100.0)).trim_suffix("0").trim_suffix("0").trim_suffix("."),  # 0.25, 3, 2.5
		"mult": str(BALANCE.crit_multiplier).trim_suffix(".0"),
	})
	if is_new_weapon(choice):
		# Which weapon slot this would fill, e.g. "slot 2 of 3".
		text += "  (slot %d of %d)" % [extra_weapons + 1, BALANCE.max_extra_weapons]
	return text

func took_new_weapon() -> void:
	# One more weapon slot filled. At the limit, every weapon not taken
	# leaves the pool for the rest of the run.
	extra_weapons += 1
	if extra_weapons >= BALANCE.max_extra_weapons:
		upgrade_pool = upgrade_pool.filter(func(c): return not is_new_weapon(c))

func weapon_recap() -> Array[String]:
	# Spells in unlock order, with levels for the weapons that have them.
	var recap: Array[String] = []
	for spell in spells_taken:
		var weapon: String = weapon_ids.get(spell, "")
		recap.append(spell if weapon == "" else "%s  Lv %d" % [spell, player.weapon_level(weapon)])
	return recap

func take_weapon(choice: Dictionary) -> void:
	var weapon: String = choice["weapon"]
	var was_new: bool = is_new_weapon(choice)
	player.apply_upgrade("level_" + weapon)
	if not weapon_ids.has(choice["name"]):
		weapon_ids[choice["name"]] = weapon
		spells_taken.append(choice["name"])
	if player.weapon_level(weapon) >= BALANCE.weapon_max_level:
		upgrade_pool.erase(choice)
	if was_new:
		acquired.append(weapon)
		took_new_weapon()

func _on_option_pressed(index: int) -> void:
	var choice: Dictionary = current_choices[index]
	if choice.has("god"):
		player.add_god(choice["god"])
		god_taken = true
		spells_taken.append("God-Tier: " + GOD_COMBO.title(choice["god"]))
		visible = false
		get_tree().paused = false
		var scene: Node = get_tree().current_scene
		if scene and scene.has_method("show_map_banner"):
			scene.show_map_banner(GOD_COMBO.LEADS[GOD_COMBO.parts(choice["god"])[0]][0].to_upper())
		return
	if choice.has("epic"):
		player.add_epic(choice["epic"])
		epics_taken.append(choice["epic"])
		spells_taken.append("Epic: " + EPIC_COMBO.COMBOS[choice["epic"]][0])
		visible = false
		get_tree().paused = false
		return
	if choice.has("weapon"):
		take_weapon(choice)
		visible = false
		get_tree().paused = false
		return

	player.apply_upgrade(choice["id"])

	# One-time upgrades (spell unlocks) leave the pool forever.
	if choice.get("once", false):
		upgrade_pool.erase(choice)
		spells_taken.append(choice["name"])
		acquired.append(choice["id"].trim_prefix("unlock_"))
		took_new_weapon()
	else:
		upgrades_taken[choice["name"]] = upgrades_taken.get(choice["name"], 0) + 1

	visible = false
	get_tree().paused = false
