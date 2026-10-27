class_name AudioSettingsPanel
extends Control
## Settings panel: music, sound-effect and nature-ambience volume sliders,
## vibration and mute toggles. Changes apply immediately through
## AudioManager, which saves them. Opening or closing it never touches the
## music, so the soundtrack keeps playing.

signal closed

@onready var _music: HSlider = %MusicSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _ambience: HSlider = %AmbienceSlider
@onready var _music_value: Label = %MusicValue
@onready var _sfx_value: Label = %SfxValue
@onready var _ambience_value: Label = %AmbienceValue
@onready var _vibration: Button = %VibrationToggle
@onready var _mute: Button = %MuteToggle
@onready var _back: Button = %BackButton


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
	_mute.toggled.connect(func(on: bool) -> void:
		AudioManager.set_muted(on)
		_sync_labels())
	_back.pressed.connect(_close)


func open(back_label := "Back") -> void:
	_back.text = back_label
	_music.set_value_no_signal(AudioManager.music_volume)
	_sfx.set_value_no_signal(AudioManager.sfx_volume)
	_ambience.set_value_no_signal(AudioManager.ambience_volume)
	_vibration.set_pressed_no_signal(AudioManager.vibration)
	_mute.set_pressed_no_signal(AudioManager.muted)
	_sync_labels()
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)


func _sync_labels() -> void:
	_music_value.text = "%d%%" % roundi(_music.value * 100.0)
	_sfx_value.text = "%d%%" % roundi(_sfx.value * 100.0)
	_ambience_value.text = "%d%%" % roundi(_ambience.value * 100.0)
	_vibration.text = "On" if _vibration.button_pressed else "Off"
	_mute.text = "Muted" if _mute.button_pressed else "Sound on"
	# Sliders read as inactive while everything is muted.
	for slider in [_music, _sfx, _ambience]:
		(slider as Control).modulate.a = 0.45 if _mute.button_pressed else 1.0


func _close() -> void:
	AudioManager.flush_settings()
	hide()
	closed.emit()
