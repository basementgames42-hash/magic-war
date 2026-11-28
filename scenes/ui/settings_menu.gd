extends CanvasLayer
# Settings Menu: opened with Esc from any screen, or the title screen's
# Settings button. Shows the damage-number toggle and the volume sliders.
# (Fullscreen still works with F11 / Alt+Enter / the maximize button, run by
# the WindowControls autoload; it just has no button here.)
# Pauses the game while open, and puts the pause state back exactly as it
# was on close (so the level-up / game-over screens stay paused).
# Created by the WindowControls autoload, which is our parent.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const GAME_SCENE := "res://scenes/main.tscn"

var was_paused: bool = false
var privacy_button: Button

func _ready() -> void:
	visible = false
	%DamageNumbersButton.pressed.connect(_on_damage_numbers_pressed)
	%ResumeButton.pressed.connect(close)
	%MainMenuButton.pressed.connect(_on_main_menu_pressed)
	# Volume sliders drive the Music / SFX buses set up by the Audio autoload.
	%MusicSlider.value = Audio.get_volume("Music")
	%SfxSlider.value = Audio.get_volume("SFX")
	%MusicSlider.value_changed.connect(_on_music_changed)
	%SfxSlider.value_changed.connect(_on_sfx_changed)
	# Privacy Options: change the ad consent choice. Only where Google's
	# consent form applied (EU / UK players on phones), and required there.
	privacy_button = %DamageNumbersButton.duplicate(0)  # Same look, none of its wiring
	privacy_button.unique_name_in_owner = false
	privacy_button.text = "Privacy Options"
	privacy_button.pressed.connect(func():
		close()
		Ads.show_privacy_options())
	%DamageNumbersButton.add_sibling(privacy_button)

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	was_paused = get_tree().paused
	get_tree().paused = true
	# "Main Menu" only makes sense in the middle of a run.
	var scene: Node = get_tree().current_scene
	%MainMenuButton.visible = scene != null and scene.scene_file_path == GAME_SCENE
	%ResumeButton.text = "Resume" if %MainMenuButton.visible else "Close"
	$CenterContainer/VBoxContainer/TitleLabel.text = \
		"PAUSED" if %MainMenuButton.visible else "SETTINGS"
	refresh()
	fit_to_screen()
	visible = true

func fit_to_screen() -> void:
	# Shrink the menu (around the screen centre, leaving the dim backdrop
	# full size) when it's taller than the screen, e.g. a short phone screen.
	# (The screen size, not the container's: that isn't laid out yet while
	# we're hidden. The ribbon and scroll art also draw ~40px outside it.)
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var needed: float = $CenterContainer/VBoxContainer.get_combined_minimum_size().y + 40.0
	var s: float = minf(1.0, (screen.y - 16.0) / needed)
	$CenterContainer.pivot_offset = screen / 2.0
	$CenterContainer.scale = Vector2(s, s)

func close() -> void:
	visible = false
	get_tree().paused = was_paused

func refresh() -> void:
	%DamageNumbersButton.text = "Damage Numbers: %s" % ("On" if GameData.show_damage_numbers else "Off")
	privacy_button.visible = Ads.privacy_options_available()

func _on_damage_numbers_pressed() -> void:
	# Floating hit numbers over the player and enemies. Saved straight away,
	# and read on every hit, so it applies mid-run in both modes.
	GameData.show_damage_numbers = not GameData.show_damage_numbers
	GameData.save_game()
	refresh()

func _on_music_changed(value: float) -> void:
	Audio.set_volume("Music", value)

func _on_sfx_changed(value: float) -> void:
	Audio.set_volume("SFX", value)
	Audio.play("coin", -6.0, 0.0)  # Sample so you can hear the new level

func _on_main_menu_pressed() -> void:
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
