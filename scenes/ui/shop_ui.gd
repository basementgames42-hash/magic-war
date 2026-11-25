class_name ShopUI
# Small building blocks shared by the Shop and Daily Quests screens: the grass
# background, the coins + gems bar, item icons and one-row "cards".

const GRASS := preload("res://scenes/assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color5_single_grazz_tile.png")
const COIN := preload("res://scenes/assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_03.png")

static var icons: Dictionary = {}

static func icon(file: String, size: int = 56) -> Texture2D:
	# Pixel-art items blown up crisp, cached so screens open quickly.
	var key: String = "%s@%d" % [file, size]
	if not icons.has(key):
		var img: Image = load(ShopCatalog.ICON_DIR + file + ".png").get_image()
		img.resize(size, size, Image.INTERPOLATE_NEAREST)
		icons[key] = ImageTexture.create_from_image(img)
	return icons[key]

static func background(parent: Control) -> void:
	var bg := TextureRect.new()
	bg.texture = GRASS
	bg.modulate = Color(0.55, 0.6, 0.4)
	bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)

static func amount(texture: Texture2D, value_label: Label) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var pic := TextureRect.new()
	pic.texture = texture
	pic.custom_minimum_size = Vector2(36, 36)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(pic)
	value_label.theme_type_variation = &"DarkLabel"
	value_label.add_theme_font_size_override("font_size", 26)
	row.add_child(value_label)
	return row

static func wallet(coins_label: Label, gems_label: Label) -> HBoxContainer:
	# "[coin] 1234   [gem] 56", centred.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.add_child(amount(COIN, coins_label))
	row.add_child(amount(icon(ShopCatalog.GEM_ICON, 36), gems_label))
	return row

static func card(pic: Texture2D, title: String, desc: String, button: Button, tag: String = "") -> PanelContainer:
	# One item on one tidy row: icon | name (+ optional status tag) over a
	# one-line description | its button, the same width on every row.
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.35)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var image := TextureRect.new()
	image.texture = pic
	image.custom_minimum_size = Vector2(44, 44)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(image)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", -4)
	row.add_child(text)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	text.add_child(top)
	var name_label := Label.new()
	name_label.text = title
	name_label.theme_type_variation = &"DarkLabel"
	name_label.add_theme_font_size_override("font_size", 22)
	top.add_child(name_label)
	if tag != "":
		top.add_child(status_tag(tag))
	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.theme_type_variation = &"DarkLabel"
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.modulate = Color(1, 1, 1, 0.8)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 200
	text.add_child(desc_label)
	button.custom_minimum_size = Vector2(150, 44)
	button.add_theme_font_size_override("font_size", 22)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = false
	row.add_child(button)
	return panel

static func tile(pic: Texture2D, title: String, amount_text: String, button: Button, tag: String = "") -> PanelContainer:
	# A shop tile for side-by-side offers (gem packs): icon, name, amount,
	# optional tag, and the button along the bottom.
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.35)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -2)
	panel.add_child(col)
	var image := TextureRect.new()
	image.texture = pic
	image.custom_minimum_size = Vector2(34, 34)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(image)
	for line in [[title, 15, 0.8], [amount_text, 21, 1.0]]:
		var label := Label.new()
		label.text = line[0]
		label.theme_type_variation = &"DarkLabel"
		label.add_theme_font_size_override("font_size", line[1])
		label.modulate = Color(1, 1, 1, line[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(label)
	var tag_holder := CenterContainer.new()
	tag_holder.custom_minimum_size.y = 22
	col.add_child(tag_holder)
	if tag != "":
		tag_holder.add_child(status_tag(tag))
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_size_override("font_size", 22)
	button.focus_mode = Control.FOCUS_NONE
	col.add_child(button)
	return panel

static func status_tag(text: String) -> Label:
	# A small rounded label next to an item's name ("Owned", "2 / 5"...).
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.55, 0.3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	label.add_theme_stylebox_override("normal", style)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label

static func hint(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"DarkLabel"
	label.add_theme_font_size_override("font_size", 17)
	label.modulate = Color(1, 1, 1, 0.8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

static func heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"TitleRibbon"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
