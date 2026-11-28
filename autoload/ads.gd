extends Node
# Ads: the one place the game talks to an ad network. Everything else only uses
# is_available() and show_rewarded(), plus the privacy-options pair the
# Settings menu shows.
#
# Three modes, picked at startup:
#   ADMOB - phone builds with the AdMob plugin (addons/AdmobPlugin). Google's
#           consent form first (EU/UK players), Apple's tracking prompt on iOS,
#           then rewarded ads are loaded ahead so an offer can play at once.
#           Debug builds and builds without real ad unit ids use Google's
#           test ads (safe to tap); see REAL_* below.
#   TEST  - debug builds anywhere else (the editor, desktop): a labelled
#           fake ad that grants the reward after a few seconds.
#   OFF   - everything else (the Web build, desktop releases): no ads, and
#           the game hides every ad offer.

# Real AdMob rewarded ad unit ids, from your AdMob account. While these are
# empty (or in debug builds) Google's test ads are used. The matching AdMob
# *app* ids go in addons/AdmobPlugin/android_export.cfg / ios_export.cfg.
const REAL_ANDROID_REWARDED_ID: String = ""
const REAL_IOS_REWARDED_ID: String = ""
# Shown by Apple's tracking prompt (iOS only).
const ATT_TEXT: String = "This lets ads in Magic War be more relevant to you. The game works the same either way."

const TEST_AD_SECONDS: float = 5.0
const KEEP_LOADED: int = 2        # Ads loaded ahead (the gem offer plays two in a row)
const LOAD_WAIT_SECONDS: float = 8.0  # How long show_rewarded() waits for an ad that is still loading

enum Mode { OFF, TEST, ADMOB }

var mode: Mode = Mode.OFF
var showing: bool = false
var was_paused: bool = false
var on_finished: Callable
var series: String = ""  # e.g. "Ad 1 of 2", shown on the test ad

# AdMob state
var admob: Node = null            # The plugin's Admob node
var started: bool = false         # Consent done and the SDK initialised
var loaded: int = 0               # Rewarded ads ready to show
var loading: int = 0              # Requests in flight
var retry_delay: float = 15.0
var earned: bool = false          # The current ad's reward was granted
var waiting_for_load: float = 0.0 # > 0 while show_rewarded() waits for an ad
var privacy_required: bool = false

# Test-ad state
var test_ad: CanvasLayer = null
var test_label: Label
var test_timer: float = 0.0

func _ready() -> void:
	# Keeps running while the game is paused behind the ad.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton("AdmobPlugin"):
		mode = Mode.ADMOB
		start_admob()
	elif OS.is_debug_build() and not OS.has_feature("web"):
		mode = Mode.TEST

func is_available() -> bool:
	match mode:
		Mode.TEST: return true
		Mode.ADMOB: return started and loaded > 0
	return false

func show_rewarded(finished: Callable, series_text: String = "") -> void:
	# Calls finished(rewarded: bool) once the ad closes. The game stays paused
	# until then, and goes back to how it was (so a menu behind it stays up).
	if showing or mode == Mode.OFF:
		return
	showing = true
	series = series_text
	on_finished = finished
	was_paused = get_tree().paused
	get_tree().paused = true
	if mode == Mode.TEST:
		show_test_ad()
	elif loaded > 0:
		play_admob()
	else:
		# The second ad of a pair can still be loading: give it a moment.
		waiting_for_load = LOAD_WAIT_SECONDS
		load_more()

func finish(rewarded: bool) -> void:
	showing = false
	AudioServer.set_bus_mute(0, false)
	get_tree().paused = was_paused
	if on_finished.is_valid():
		on_finished.call(rewarded)

# --- Privacy options (Settings menu) ---------------------------------------

func privacy_options_available() -> bool:
	# Google requires a way to change the consent choice wherever the consent
	# form was needed (EU / UK players). Elsewhere the button stays hidden.
	return mode == Mode.ADMOB and privacy_required

func show_privacy_options() -> void:
	if privacy_options_available():
		admob.load_consent_form()  # consent_form_loaded shows it

# --- AdMob -----------------------------------------------------------------

func start_admob() -> void:
	var script: Script = load("res://addons/AdmobPlugin/Admob.gd")
	admob = script.new()
	var real: bool = not OS.is_debug_build() and (
		REAL_IOS_REWARDED_ID if OS.has_feature("ios") else REAL_ANDROID_REWARDED_ID) != ""
	admob.is_real = real
	admob.android_real_rewarded_id = REAL_ANDROID_REWARDED_ID
	admob.ios_real_rewarded_id = REAL_IOS_REWARDED_ID
	admob.att_enabled = true
	admob.att_text = ATT_TEXT
	# Ads live for the whole session, not one scene.
	admob.remove_rewarded_ads_after_scene = false
	admob.max_rewarded_ad_cache = KEEP_LOADED + 1
	add_child(admob)
	admob.consent_info_updated.connect(_on_consent_info_updated)
	admob.consent_info_update_failed.connect(func(_e): begin_ads())
	admob.consent_form_loaded.connect(func(): admob.show_consent_form())
	admob.consent_form_failed_to_load.connect(func(_e): begin_ads())
	admob.consent_form_dismissed.connect(func(_e): _on_consent_done())
	admob.tracking_authorization_granted.connect(initialize_sdk)
	admob.tracking_authorization_denied.connect(initialize_sdk)
	admob.initialization_completed.connect(_on_initialized)
	admob.rewarded_ad_loaded.connect(_on_ad_loaded)
	admob.rewarded_ad_failed_to_load.connect(_on_ad_failed_to_load)
	admob.rewarded_ad_user_earned_reward.connect(func(_info, _reward): earned = true)
	admob.rewarded_ad_dismissed_full_screen_content.connect(func(_info): _on_ad_closed())
	admob.rewarded_ad_failed_to_show_full_screen_content.connect(func(_info, _e): _on_ad_closed())
	# 1. Ask Google whether this player needs the consent form.
	admob.update_consent_info()

func _on_consent_info_updated() -> void:
	var consent: Variant = admob.get_consent_status()
	var status: int = consent.status if consent else 0
	privacy_required = status == UserConsent.Status.REQUIRED or status == UserConsent.Status.OBTAINED
	if status == UserConsent.Status.REQUIRED and admob.is_consent_form_available():
		admob.load_consent_form()  # 2. Show it (consent_form_loaded)
	else:
		begin_ads()

func _on_consent_done() -> void:
	# The form also closes after "Privacy options" mid-game: only start once.
	begin_ads()

func begin_ads() -> void:
	if started or admob == null:
		return
	# 3. iOS: Apple's tracking prompt, after the consent form. Then the SDK.
	if OS.has_feature("ios"):
		admob.request_tracking_authorization()
	else:
		initialize_sdk()

func initialize_sdk() -> void:
	if started:
		return
	admob.initialize()

func _on_initialized(_status) -> void:
	started = true
	load_more()

func load_more() -> void:
	if not started:
		return
	while loaded + loading < KEEP_LOADED:
		loading += 1
		admob.load_rewarded_ad()

func _on_ad_loaded(_info, _response) -> void:
	loading = maxi(loading - 1, 0)
	loaded += 1
	retry_delay = 15.0
	if showing and waiting_for_load > 0.0:
		waiting_for_load = 0.0
		play_admob()

func _on_ad_failed_to_load(_info, _error) -> void:
	loading = maxi(loading - 1, 0)
	# No fill or no connection: try again later, backing off up to 5 minutes.
	get_tree().create_timer(retry_delay, true, false, true).timeout.connect(load_more)
	retry_delay = minf(retry_delay * 2.0, 300.0)

func play_admob() -> void:
	earned = false
	loaded -= 1
	AudioServer.set_bus_mute(0, true)  # The ad brings its own sound
	admob.show_rewarded_ad()

func _on_ad_closed() -> void:
	if showing:
		finish(earned)
	load_more()

func _process(delta: float) -> void:
	if waiting_for_load > 0.0:
		waiting_for_load -= delta
		if waiting_for_load <= 0.0 and showing:
			finish(false)  # Never loaded: no ad, no reward
	if test_ad == null:
		return
	test_timer -= delta
	test_label.text = "TEST AD%s\nReward in %d..." % [
		("  (" + series + ")") if series != "" else "", ceili(test_timer)]
	if test_timer <= 0.0:
		close_test_ad(true)

# --- Test ad (editor / desktop debug builds) --------------------------------

func show_test_ad() -> void:
	test_timer = TEST_AD_SECONDS
	test_ad = CanvasLayer.new()
	test_ad.layer = 100
	add_child(test_ad)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.08)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	test_ad.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	test_ad.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)
	test_label = Label.new()
	test_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(test_label)
	var skip := Button.new()
	skip.text = "Skip (no reward)"
	skip.theme_type_variation = &"RedButton"
	skip.custom_minimum_size = Vector2(320, 68)
	skip.pressed.connect(close_test_ad.bind(false))
	column.add_child(skip)

func close_test_ad(rewarded: bool) -> void:
	test_ad.queue_free()
	test_ad = null
	finish(rewarded)
