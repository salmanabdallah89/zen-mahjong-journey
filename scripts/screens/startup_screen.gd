extends Control
## First screen shown on launch: environment background, game title and a
## Play button that opens the journey map, the Tile Collection chooser,
## Settings and (with Google Play Games) the leaderboard.

@onready var _title_block: Control = %TitleBlock
@onready var _play_button: Button = %PlayButton
@onready var _collection_button: Button = %CollectionButton
@onready var _picker: CollectionPicker = %CollectionPicker
@onready var _settings_button: Button = %SettingsButton
@onready var _settings: AudioSettingsPanel = %AudioSettings
@onready var _leaderboard_button: Button = %LeaderboardButton
@onready var _leaderboard_gap: Control = %LeaderboardGap


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_collection_button.pressed.connect(_picker.open)
	_picker.hide()
	_settings_button.pressed.connect(_settings.open)
	_settings.hide()
	_leaderboard_button.pressed.connect(PlayGames.show_leaderboard)
	_update_leaderboard_button()
	AudioManager.play_music("main_menu")
	AudioManager.set_ambience(AudioCatalog.MENU_AMBIENCE)
	BackgroundDrift.start($Background)
	_play_intro()


## Android back closes an open panel; on the title screen itself it leaves
## the app (quit_on_go_back is off so the other screens can step back).
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or not is_node_ready():
		return
	if _settings.visible:
		_settings.close()
	elif _picker.visible:
		_picker.close()
	elif GameSession.scene_changes_enabled:
		get_tree().quit()


func _play_intro() -> void:
	_title_block.modulate.a = 0.0
	_play_button.modulate.a = 0.0
	_collection_button.modulate.a = 0.0
	_settings_button.modulate.a = 0.0
	_leaderboard_button.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_title_block, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_play_button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_collection_button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_settings_button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_leaderboard_button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)


## The leaderboard lives in Google Play Games, so the button only shows where
## that is available (the Android app with Play Games set up).
func _update_leaderboard_button() -> void:
	var available := PlayGames.is_available()
	_leaderboard_button.visible = available
	_leaderboard_gap.visible = available


func _on_play_pressed() -> void:
	GameSession.go_levels()
