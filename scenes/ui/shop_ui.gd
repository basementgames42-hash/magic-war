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

static func card(pic: Texture2D, title: String, desc: String, button: Button) -> PanelContainer:
	# One item: icon, name and description, and its button on the right.
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.35)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var image := TextureRect.new()
	image.texture = pic
	image.custom_minimum_size = Vector2(56, 56)
	image.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(image)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var name_label := Label.new()
	name_label.text = title
	name_label.theme_type_variation = &"DarkLabel"
	name_label.add_theme_font_size_override("font_size", 24)
	text.add_child(name_label)
	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.theme_type_variation = &"DarkLabel"
	desc_label.add_theme_font_size_override("font_size", 17)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 200
	text.add_child(desc_label)
	button.custom_minimum_size = Vector2(170, 58)
	button.add_theme_font_size_override("font_size", 20)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	row.add_child(button)
	return panel

static func heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"TitleRibbon"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
