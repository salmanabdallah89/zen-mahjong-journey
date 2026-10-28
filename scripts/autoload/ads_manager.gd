extends Node
## Autoload "AdsManager": the one place the game asks for ads. Screens call
## show_rewarded(), after_level_complete(), after_level_lost() and
## show_banner()/hide_banner();
## which ad network (if any) serves them is decided here.
##
## Providers:
##  - "admob":     Google AdMob on Android/iOS through the godot-admob plugin
##                 (godot-sdk-integrations, v7, for Godot 4.7) and our bridge
##                 (scripts/ads/admob_bridge.gd: consent, loading, retries).
##                 Offers appear only while an ad is ready, so offline phones
##                 play like the web build (docs/ADMOB_SETUP.md).
##  - "simulated": stand-in test ads drawn by the game, on desktop debug runs
##                 (data/ads.json "simulate_on_desktop"), so every placement
##                 can be played and tested.
##  - "none":      the web build, release desktop builds, or no plugin. The
##                 game then works without ads: hints stay free and there is
##                 no ad-based second chance.

signal ad_started(kind: String, placement: String)
signal ad_finished(kind: String, placement: String, rewarded: bool)
## The banner appeared, went away or changed height (screens leave room for it).
signal banner_changed

const CONFIG_PATH := "res://data/ads.json"
## Real AdMob ids, used only by release builds on phones. Debug builds,
## tests and the desktop always use the test ids in CONFIG_PATH.
const RELEASE_CONFIG_PATH := "res://data/ads_release.json"
## The AdMob plugin's folder, and our bridge to it. Phones use AdMob only
## when both are present.
const ADMOB_PLUGIN_DIR := "res://addons/AdmobPlugin"
const ADMOB_BRIDGE := "res://scripts/ads/admob_bridge.gd"
const BANNER_HEIGHT := 130.0

var provider := "none"
var config := {}
## Levels finished this session (cleared or lost), for the interstitial cadence.
var levels_ended := 0
## When the last full-screen ad closed (Time.get_ticks_msec), or -1. An
## interstitial never follows another ad within "interstitial_min_gap_seconds".
var last_ad_ended_msec := -1
## Recent ad events, newest last: {"kind", "placement", "rewarded"} (tests, debugging).
var history: Array[Dictionary] = []

var _showing := false
var _banner_wanted := false
var _layer: CanvasLayer
var _banner: Control
var _overlay: Control
## The AdMob bridge (provider "admob" only).
var _admob: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	config = data if data is Dictionary else {}
	provider = _pick_provider()
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	if provider == "admob":
		_admob = (load(ADMOB_BRIDGE) as GDScript).new()
		_admob.name = "AdmobBridge"
		add_child(_admob)
		_admob.banner_changed.connect(banner_changed.emit)
		var platform := "ios" if OS.has_feature("ios") else "android"
		# Debug builds (and platforms without real ids) always get test ads.
		var ids: Dictionary = config.get(platform, {})
		var real := not OS.is_debug_build()
		if real:
			ids = release_ids(platform)
			real = not ids.is_empty()
			if not real:
				ids = config.get(platform, {})
		_admob.start(ids, real)


func _pick_provider() -> String:
	if OS.has_feature("web"):
		return "none"
	if OS.has_feature("mobile"):
		return "admob" if admob_installed() else "none"
	if OS.is_debug_build() and bool(config.get("simulate_on_desktop", true)):
		return "simulated"
	return "none"


## True when the AdMob plugin and our bridge to it are both in the project.
static func admob_installed() -> bool:
	return DirAccess.dir_exists_absolute(ADMOB_PLUGIN_DIR) and ResourceLoader.exists(ADMOB_BRIDGE)


## True when a rewarded ad can be shown right now (so ad-based offers should
## appear). With AdMob that means one is loaded and ready.
func is_available() -> bool:
	match provider:
		"none":
			return false
		"admob":
			return _admob != null and _admob.rewarded_ready()
	return true


func is_showing() -> bool:
	return _showing


func setting(key: String, default: Variant) -> Variant:
	return config.get(key, default)


## Ad unit id for the current platform ("banner", "interstitial", "rewarded").
## The real AdMob ids for release builds (data/ads_release.json), or {} when
## the platform has none or they are incomplete.
static func release_ids(platform: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(RELEASE_CONFIG_PATH))
	if not data is Dictionary:
		return {}
	var ids: Variant = (data as Dictionary).get(platform, {})
	if not ids is Dictionary:
		return {}
	for kind in ["app_id", "banner", "interstitial", "rewarded"]:
		if not str((ids as Dictionary).get(kind, "")).begins_with("ca-app-pub-"):
			return {}
	return ids


func unit_id(kind: String) -> String:
	var platform := "ios" if OS.has_feature("ios") else "android"
	return str((config.get(platform, {}) as Dictionary).get(kind, ""))


# --- Rewarded ---------------------------------------------------------------

## Shows a rewarded ad; `on_done` gets true only if the player watched it to
## the end. Never pays out if ads are unavailable.
func show_rewarded(placement: String, on_done: Callable) -> void:
	if not is_available() or _showing:
		if on_done.is_valid():
			on_done.call(false)
		return
	_begin("rewarded", placement)
	match provider:
		"simulated":
			_show_simulated("rewarded", placement, on_done)
		"admob":
			_admob.show_rewarded(func(rewarded: bool) -> void: _end("rewarded", placement, rewarded, on_done))
		_:
			_end("rewarded", placement, false, on_done)


# --- Interstitial -------------------------------------------------------------

## Call when a level is cleared, with what to do next. Every Nth finished
## level (cleared or lost) first shows an interstitial; `then` always runs
## afterwards.
func after_level_complete(then: Callable) -> void:
	_after_level_end("level_complete", then)


## Call when the player leaves a lost level (Retry or Levels). Losses count
## toward the same cadence as clears.
func after_level_lost(then: Callable) -> void:
	_after_level_end("level_lost", then)


func _after_level_end(placement: String, then: Callable) -> void:
	levels_ended += 1
	var every := int(config.get("interstitial_every_levels", 2))
	var gap_msec := int(config.get("interstitial_min_gap_seconds", 30)) * 1000
	var too_soon := last_ad_ended_msec >= 0 and Time.get_ticks_msec() - last_ad_ended_msec < gap_msec
	if provider == "none" or every <= 0 or levels_ended % every != 0 or too_soon 			or (provider == "admob" and not _admob.interstitial_ready()):
		then.call()
		return
	_begin("interstitial", placement)
	match provider:
		"simulated":
			_show_simulated("interstitial", placement, func(_r: bool) -> void: then.call())
		"admob":
			_admob.show_interstitial(func(_r: bool) -> void:
				_end("interstitial", placement, false, func(_r2: bool) -> void: then.call()))
		_:
			_end("interstitial", placement, false, func(_r: bool) -> void: then.call())


# --- Banner -----------------------------------------------------------------

func show_banner() -> void:
	_banner_wanted = true
	if provider == "none":
		return
	if provider == "admob":
		_admob.show_banner()
	elif _banner == null:
		_banner = _make_banner()
		_layer.add_child(_banner)
	history.append({"kind": "banner", "placement": "journey", "rewarded": false})


func hide_banner() -> void:
	_banner_wanted = false
	if _admob:
		_admob.hide_banner()
	if _banner:
		_banner.queue_free()
		_banner = null


func is_banner_visible() -> bool:
	if _admob:
		return _admob.banner_visible
	return _banner != null and _banner.visible


## Canvas height the banner covers at the bottom (screens leave room for it).
func banner_height() -> float:
	if _admob:
		return _admob.banner_height(get_viewport().get_visible_rect().size.y)
	return BANNER_HEIGHT if is_banner_visible() else 0.0


## True when the player may change their ad consent choice (Settings shows
## a "Privacy options" button). Only AdMob in consent regions.
func privacy_options_available() -> bool:
	return _admob != null and _admob.privacy_options_available()


func show_privacy_options() -> void:
	if _admob:
		_admob.show_privacy_options()


# --- Simulated ads ----------------------------------------------------------

func _begin(kind: String, placement: String) -> void:
	_showing = true
	AudioManager.set_ad_playing(true)
	if _banner:
		_banner.hide()
	ad_started.emit(kind, placement)


func _end(kind: String, placement: String, rewarded: bool, on_done: Callable) -> void:
	_showing = false
	last_ad_ended_msec = Time.get_ticks_msec()
	AudioManager.set_ad_playing(false)
	if _banner and _banner_wanted:
		_banner.show()
	history.append({"kind": kind, "placement": placement, "rewarded": rewarded})
	ad_finished.emit(kind, placement, rewarded)
	# The screen that asked may be gone by now (e.g. the player left).
	if on_done.is_valid():
		on_done.call(rewarded)


## A full-screen stand-in ad with a countdown. Rewarded ads pay only if the
## countdown finishes; closing early forfeits the reward.
func _show_simulated(kind: String, placement: String, on_done: Callable) -> void:
	var seconds := float(config.get("simulated_ad_seconds", 3.0))
	_overlay = Control.new()
	_overlay.name = "TestAd"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.1, 0.12, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 30)
	_overlay.add_child(box)
	var title := Label.new()
	title.text = "Test Ad" if kind == "interstitial" else "Test Rewarded Ad"
	title.theme_type_variation = &"TitleAccentLabel"
	title.add_theme_font_size_override("font_size", 96)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var note := Label.new()
	note.text = "Stand-in for an AdMob ad.\nReal ads appear in the phone app."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	var count := Label.new()
	count.name = "Countdown"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(count)
	var close := Button.new()
	close.name = "Close"
	close.custom_minimum_size = Vector2(520, 136)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.theme_type_variation = &"SecondaryButton"
	close.set_meta("custom_sound", true)
	box.add_child(close)
	_layer.add_child(_overlay)

	var state := {"left": seconds, "done": false}
	var finish := func(rewarded: bool) -> void:
		if state["done"]:
			return
		state["done"] = true
		_overlay.queue_free()
		_overlay = null
		_end(kind, placement, rewarded, on_done)
	var update := func() -> void:
		var left: float = state["left"]
		count.text = "Ad ends in %d s" % ceili(left) if left > 0.0 else "Thanks for watching!"
		if kind == "rewarded":
			close.text = "Skip (no reward)" if left > 0.0 else "Collect Reward"
		else:
			close.text = "Close" if left <= 0.0 else "Close in %d s" % ceili(left)
			close.disabled = left > 0.0
	close.pressed.connect(func() -> void: finish.call(kind == "rewarded" and float(state["left"]) <= 0.0))
	update.call()
	var timer := Timer.new()
	timer.wait_time = 0.1
	_overlay.add_child(timer)
	timer.timeout.connect(func() -> void:
		state["left"] = maxf(float(state["left"]) - 0.1, 0.0)
		update.call())
	timer.start()


## Ends any ad on screen at once, without a reward (scene changes, tests).
func cancel() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	if _showing:
		_showing = false
		AudioManager.set_ad_playing(false)


## Presses the stand-in ad's button (tests).
func press_simulated_close() -> void:
	if _overlay:
		(_overlay.find_child("Close", true, false) as Button).emit_signal("pressed")


func _make_banner() -> Control:
	var banner := PanelContainer.new()
	banner.name = "TestBanner"
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.anchor_top = 1.0
	banner.anchor_bottom = 1.0
	banner.offset_top = -BANNER_HEIGHT
	banner.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.18, 0.96)
	style.border_width_top = 3
	style.border_color = Color(0.78, 0.65, 0.42)
	banner.add_theme_stylebox_override("panel", style)
	var text := Label.new()
	text.text = "Test banner ad · real AdMob banners appear in the phone app"
	text.add_theme_font_size_override("font_size", 30)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_child(text)
	return banner
