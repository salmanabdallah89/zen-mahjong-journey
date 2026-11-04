class_name AudioSettingsPanel
extends Control
## Settings panel: music, sound-effect and nature-ambience volume sliders,
## vibration, reduced-animation, play-reminder and mute toggles, and the
## one-time Remove Ads purchase where Google Play sells it. Changes apply immediately through
## AudioManager, which saves them. Opening or closing it never touches the
## music, so the soundtrack keeps playing.

signal closed

## Room kept above and below the panel (status bar, navigation bar).
const SCREEN_MARGIN := 240.0

@onready var _music: HSlider = %MusicSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _ambience: HSlider = %AmbienceSlider
@onready var _music_value: Label = %MusicValue
@onready var _sfx_value: Label = %SfxValue
@onready var _ambience_value: Label = %AmbienceValue
@onready var _vibration: Button = %VibrationToggle
@onready var _motion: Button = %MotionToggle
@onready var _mute: Button = %MuteToggle
@onready var _reminders_row: Control = %RemindersRow
@onready var _reminders: Button = %RemindersToggle
@onready var _purchase_row: Control = %PurchaseRow
@onready var _purchase_status: Label = %PurchaseStatus
@onready var _remove_ads: Button = %RemoveAdsButton
@onready var _restore: Button = %RestoreButton
@onready var _back: Button = %BackButton
@onready var _how_to_play: Button = %HowToPlayButton
@onready var _privacy: Button = %PrivacyButton
@onready var _licences_button: Button = %LicencesButton
@onready var _licences: CreditsPanel = %CreditsPanel
@onready var _scroll: ScrollContainer = %Scroll
@onready var _content: Control = %Content


func _ready() -> void:
	_music.value_changed.connect(func(value: float) -> void:
		AudioManager.set_music_volume(value)
		_sync_labels())
	_sfx.value_changed.connect(func(value: float) -> void:
		AudioManager.set_sfx_volume(value)
		_sync_labels())
	# Let the player hear the new effects level once they let go.
	_sfx.drag_ended.connect(func(_changed: bool) -> void: AudioManager.play_sfx("tile_select"))
	_ambience.value_changed.connect(func(value: float) -> void:
		AudioManager.set_ambience_volume(value)
		_sync_labels())
	_vibration.toggled.connect(func(on: bool) -> void:
		AudioManager.set_vibration(on)
		if on:
			AudioManager.vibrate(40)
		_sync_labels())
	_motion.toggled.connect(func(on: bool) -> void:
		Motion.set_reduced(on)
		_sync_labels())
	# Turning reminders on may ask Android first; the answer comes back through
	# Reminders.changed and sets the toggle.
	_reminders.toggled.connect(func(on: bool) -> void:
		if on:
			Reminders.turn_on(true)
		else:
			Reminders.turn_off()
		_sync_labels())
	Reminders.changed.connect(func(on: bool) -> void:
		_reminders.set_pressed_no_signal(on)
		_sync_labels())
	_mute.toggled.connect(func(on: bool) -> void:
		AudioManager.set_muted(on)
		_sync_labels())
	_remove_ads.pressed.connect(Purchases.buy)
	_restore.pressed.connect(Purchases.restore_purchases)
	Purchases.changed.connect(_sync_purchase)
	_back.pressed.connect(_close)
	# Replays the first-play tutorial on level 1.
	_how_to_play.pressed.connect(func() -> void:
		AudioManager.flush_settings()
		hide()
		GameSession.start_tutorial())
	# Ad consent (AdMob, consent regions only): Google's form, shown again.
	_privacy.pressed.connect(AdsManager.show_privacy_options)
	_licences_button.pressed.connect(_licences.open)
	get_viewport().size_changed.connect(_fit_height)


func open(back_label := "Back") -> void:
	_back.text = back_label
	_music.set_value_no_signal(AudioManager.music_volume)
	_sfx.set_value_no_signal(AudioManager.sfx_volume)
	_ambience.set_value_no_signal(AudioManager.ambience_volume)
	_vibration.set_pressed_no_signal(AudioManager.vibration)
	_motion.set_pressed_no_signal(Motion.reduced)
	_mute.set_pressed_no_signal(AudioManager.muted)
	# Only phones with the notification plugin can show reminders.
	_reminders_row.visible = Reminders.is_available()
	_reminders.set_pressed_no_signal(Reminders.enabled)
	_privacy.visible = AdsManager.privacy_options_available()
	_sync_purchase()
	_sync_labels()
	show()
	_fit_height.call_deferred()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, Motion.duration(0.2)).set_trans(Tween.TRANS_SINE)


## The panel is as tall as its rows, and scrolls when that is taller than the
## screen (short phones, or with every optional row shown).
func _fit_height() -> void:
	var needed := _content.get_combined_minimum_size()
	_scroll.custom_minimum_size = Vector2(needed.x, minf(needed.y, get_viewport_rect().size.y - SCREEN_MARGIN))


## Remove Ads: the price button and Restore, a pending note, or a thank-you.
func _sync_purchase() -> void:
	_purchase_row.visible = Purchases.shows_row()
	_remove_ads.visible = Purchases.is_available() and not Purchases.ads_removed and not Purchases.pending
	_remove_ads.text = "Remove Ads · %s" % Purchases.price
	_restore.visible = not Purchases.ads_removed
	_purchase_status.visible = Purchases.ads_removed or Purchases.pending
	_purchase_status.text = "Ads removed. Thank you for supporting the garden!" if Purchases.ads_removed \
			else "Payment pending: ads switch off once Google Play confirms it."
	if visible:
		_fit_height.call_deferred()


func _sync_labels() -> void:
	_music_value.text = "%d%%" % roundi(_music.value * 100.0)
	_sfx_value.text = "%d%%" % roundi(_sfx.value * 100.0)
	_ambience_value.text = "%d%%" % roundi(_ambience.value * 100.0)
	_vibration.text = "On" if _vibration.button_pressed else "Off"
	_motion.text = "On" if _motion.button_pressed else "Off"
	_reminders.text = "On" if _reminders.button_pressed else "Off"
	_mute.text = "Muted" if _mute.button_pressed else "Sound on"
	# Sliders read as inactive while everything is muted.
	for slider in [_music, _sfx, _ambience]:
		(slider as Control).modulate.a = 0.45 if _mute.button_pressed else 1.0


## Closes the panel as its Back button does (Android back).
func close() -> void:
	if _licences.visible:
		_licences.hide()
	else:
		_close()


func _close() -> void:
	AudioManager.flush_settings()
	hide()
	closed.emit()
