extends Node
## Connects the godot-admob plugin (res://addons/AdmobPlugin) to AdsManager.
## AdsManager creates it on phones only and is its only caller; screens never
## see it. Loaded by path, so nothing references the plugin's classes when the
## plugin is absent.
##
## Start-up order (AdMob policy): consent first (Google's User Messaging
## Platform: update the consent info, show the form when it is required),
## then initialize the SDK, then preload one rewarded and one interstitial
## ad. Any failure along the way just means "no ad": rewarded offers
## disappear (AdsManager.is_available()) and interstitials are skipped.
##
## Rewards are paid only on rewarded_ad_user_earned_reward. Ads that fail to
## load are retried after RETRY_SECONDS.

## The banner was shown, hidden, or changed size.
signal banner_changed

const RETRY_SECONDS := 60.0
## Wait after a full-screen ad closes before reporting, in case the SDK
## delivers the reward just after the dismissal.
const SETTLE_SECONDS := 0.3

var initialized := false
var banner_visible := false

var _admob: Admob
var _initializing := false
var _loading := {"rewarded": false, "interstitial": false, "banner": false}
var _ready_ads := {"rewarded": false, "interstitial": false, "banner": false}
var _banner_wanted := false
## The full-screen ad on screen ("rewarded" / "interstitial"), or "".
var _active := ""
var _earned := false
var _on_done := Callable()


## `ids`: "banner", "interstitial" and "rewarded" unit ids. `real` is true
## only for release builds with the ids from data/ads_release.json; otherwise
## they are Google's test ids from data/ads.json.
func start(ids: Dictionary, real := false) -> void:
	_admob = Admob.new()
	_admob.name = "Admob"
	# Ad unit ids are read in the node's _ready, so set them first.
	_admob.is_real = real
	if real:
		_admob.android_real_banner_id = str(ids.get("banner", ""))
		_admob.android_real_interstitial_id = str(ids.get("interstitial", ""))
		_admob.android_real_rewarded_id = str(ids.get("rewarded", ""))
		_admob.ios_real_banner_id = str(ids.get("banner", ""))
		_admob.ios_real_interstitial_id = str(ids.get("interstitial", ""))
		_admob.ios_real_rewarded_id = str(ids.get("rewarded", ""))
	else:
		_admob.android_debug_banner_id = str(ids.get("banner", _admob.android_debug_banner_id))
		_admob.android_debug_interstitial_id = str(ids.get("interstitial", _admob.android_debug_interstitial_id))
		_admob.android_debug_rewarded_id = str(ids.get("rewarded", _admob.android_debug_rewarded_id))
		_admob.ios_debug_banner_id = str(ids.get("banner", _admob.ios_debug_banner_id))
		_admob.ios_debug_interstitial_id = str(ids.get("interstitial", _admob.ios_debug_interstitial_id))
		_admob.ios_debug_rewarded_id = str(ids.get("rewarded", _admob.ios_debug_rewarded_id))
	_admob.banner_position = LoadAdRequest.AdPosition.BOTTOM
	_admob.banner_size = LoadAdRequest.RequestedAdSize.ADAPTIVE
	_admob.banner_anchor_to_safe_area = true
	_admob.remove_interstitial_ads_after_displayed = true
	add_child(_admob)

	_admob.consent_info_updated.connect(_on_consent_info_updated)
	_admob.consent_info_update_failed.connect(func(_error: FormError) -> void: _initialize())
	_admob.consent_form_loaded.connect(func() -> void: _admob.show_consent_form())
	_admob.consent_form_failed_to_load.connect(func(_error: FormError) -> void: _initialize())
	_admob.consent_form_dismissed.connect(func(_error: FormError) -> void: _initialize())
	_admob.initialization_completed.connect(_on_initialization_completed)

	_admob.rewarded_ad_loaded.connect(func(_ad: AdInfo, _response: ResponseInfo) -> void: _loaded("rewarded"))
	_admob.rewarded_ad_failed_to_load.connect(func(_ad: AdInfo, _error: LoadAdError) -> void: _load_failed("rewarded"))
	_admob.rewarded_ad_user_earned_reward.connect(func(_ad: AdInfo, _reward: RewardItem) -> void: _earned = true)
	_admob.rewarded_ad_dismissed_full_screen_content.connect(func(_ad: AdInfo) -> void: _closed("rewarded"))
	_admob.rewarded_ad_failed_to_show_full_screen_content.connect(func(ad: AdInfo, _error: AdError) -> void:
		_admob.remove_rewarded_ad(ad.get_ad_id())
		_closed("rewarded"))

	_admob.interstitial_ad_loaded.connect(func(_ad: AdInfo, _response: ResponseInfo) -> void: _loaded("interstitial"))
	_admob.interstitial_ad_failed_to_load.connect(func(_ad: AdInfo, _error: LoadAdError) -> void: _load_failed("interstitial"))
	_admob.interstitial_ad_dismissed_full_screen_content.connect(func(_ad: AdInfo) -> void: _closed("interstitial"))
	_admob.interstitial_ad_failed_to_show_full_screen_content.connect(func(ad: AdInfo, _error: AdError) -> void:
		_admob.remove_interstitial_ad(ad.get_ad_id())
		_closed("interstitial"))

	_admob.banner_ad_loaded.connect(func(_ad: AdInfo, _response: ResponseInfo) -> void: _on_banner_loaded())
	_admob.banner_ad_failed_to_load.connect(func(_ad: AdInfo, _error: LoadAdError) -> void: _load_failed("banner"))

	_admob.update_consent_info()


func rewarded_ready() -> bool:
	return initialized and bool(_ready_ads["rewarded"])


func interstitial_ready() -> bool:
	return initialized and bool(_ready_ads["interstitial"])


## Shows the preloaded rewarded ad; `on_done` gets true only if the reward was
## earned. Without a ready ad it answers false at once.
func show_rewarded(on_done: Callable) -> void:
	_show_full_screen("rewarded", on_done)


## Shows the preloaded interstitial; `on_done` runs when it closes (or at once
## without a ready ad).
func show_interstitial(on_done: Callable) -> void:
	_show_full_screen("interstitial", on_done)


func show_banner() -> void:
	_banner_wanted = true
	if not initialized:
		return
	if _ready_ads["banner"]:
		_admob.show_banner_ad()
		_set_banner_visible(true)
	else:
		_load("banner")


func hide_banner() -> void:
	_banner_wanted = false
	if _ready_ads["banner"]:
		_admob.hide_banner_ad()
	_set_banner_visible(false)


## Canvas height the banner covers at the bottom of the screen.
func banner_height(canvas_height: float) -> float:
	if not banner_visible:
		return 0.0
	var window_height := float(DisplayServer.window_get_size().y)
	if window_height <= 0.0:
		return 0.0
	return _admob.get_banner_dimension_in_pixels().y * canvas_height / window_height


## True when the player is in a region where they can change their ad
## consent choice (the Settings "Privacy options" button).
func privacy_options_available() -> bool:
	var consent := _admob.get_consent_status()
	return consent != null and consent.status in [UserConsent.Status.REQUIRED, UserConsent.Status.OBTAINED] \
		and _admob.is_consent_form_available()


## Opens Google's consent form again so the player can change their choice.
func show_privacy_options() -> void:
	_admob.load_consent_form()


# --- Start-up -----------------------------------------------------------------

func _on_consent_info_updated() -> void:
	var consent := _admob.get_consent_status()
	if consent != null and consent.status == UserConsent.Status.REQUIRED and _admob.is_consent_form_available():
		_admob.load_consent_form()  # consent_form_loaded shows it; closing it initializes.
	else:
		_initialize()


func _initialize() -> void:
	if initialized or _initializing:
		return
	_initializing = true
	_admob.initialize()


func _on_initialization_completed(_status: InitializationStatus) -> void:
	_initializing = false
	initialized = true
	_load("rewarded")
	_load("interstitial")
	if _banner_wanted:
		_load("banner")


# --- Loading ------------------------------------------------------------------

func _load(kind: String) -> void:
	if not initialized or _loading[kind] or _ready_ads[kind]:
		return
	_loading[kind] = true
	match kind:
		"rewarded":
			_admob.load_rewarded_ad()
		"interstitial":
			_admob.load_interstitial_ad()
		"banner":
			_admob.load_banner_ad()


func _loaded(kind: String) -> void:
	_loading[kind] = false
	_ready_ads[kind] = true


func _load_failed(kind: String) -> void:
	_loading[kind] = false
	_ready_ads[kind] = false
	get_tree().create_timer(RETRY_SECONDS).timeout.connect(func() -> void:
		if kind != "banner" or _banner_wanted:
			_load(kind))


func _on_banner_loaded() -> void:
	_loaded("banner")
	# The banner may arrive after the player left the map.
	if _banner_wanted:
		_admob.show_banner_ad()
		_set_banner_visible(true)
	else:
		_admob.hide_banner_ad()


func _set_banner_visible(on: bool) -> void:
	if banner_visible == on:
		return
	banner_visible = on
	banner_changed.emit()


# --- Full-screen ads ----------------------------------------------------------

func _show_full_screen(kind: String, on_done: Callable) -> void:
	if _active != "" or not (rewarded_ready() if kind == "rewarded" else interstitial_ready()):
		on_done.call(false)
		_load(kind)
		return
	_ready_ads[kind] = false
	_active = kind
	_earned = false
	_on_done = on_done
	if kind == "rewarded":
		_admob.show_rewarded_ad()
	else:
		_admob.show_interstitial_ad()


func _closed(kind: String) -> void:
	if _active != kind:
		return
	get_tree().create_timer(SETTLE_SECONDS).timeout.connect(func() -> void:
		var rewarded := kind == "rewarded" and _earned
		var callback := _on_done
		_active = ""
		_on_done = Callable()
		_load(kind)
		if callback.is_valid():
			callback.call(rewarded))
