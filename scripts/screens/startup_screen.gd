extends Control
## First screen shown on launch: environment background, game title and a
## Play button that opens the journey map, the Tile Collection chooser,
## Settings and (with Google Play Games) the leaderboard.

## The garden behind the title (its HD repaint when there is one).
const MENU_GARDEN := "bg_golden_sakura"

@onready var _title_block: Control = %TitleBlock
@onready var _play_button: Button = %PlayButton
@onready var _daily_button: Button = %DailyButton
@onready var _daily_marker: Control = %DailyMarker
@onready var _words_button: Button = %WordsButton
@onready var _collection_button: Button = %CollectionButton
@onready var _badges_button: Button = %BadgesButton
@onready var _new_badges: Control = %NewBadges
@onready var _new_badges_label: Label = %NewBadgesLabel
@onready var _picker: CollectionPicker = %CollectionPicker
@onready var _settings_button: Button = %SettingsButton
@onready var _settings: AudioSettingsPanel = %AudioSettings
@onready var _leaderboard_button: Button = %LeaderboardButton
@onready var _leaderboard_gap: Control = %LeaderboardGap


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_daily_button.pressed.connect(GameSession.go_daily)
	_daily_marker.visible = GameSession.progress.daily_stars(BadgeBook.today()) == 0
	_words_button.pressed.connect(GameSession.go_words)
	_collection_button.pressed.connect(_picker.open)
	_picker.hide()
	_badges_button.pressed.connect(GameSession.go_badges)
	_show_new_badges()
	_settings_button.pressed.connect(_settings.open)
	_settings.hide()
	_leaderboard_button.pressed.connect(PlayGames.show_leaderboard)
	_update_leaderboard_button()
	AudioManager.play_music("main_menu")
	AudioManager.set_ambience(AudioCatalog.MENU_AMBIENCE)
	var background := $Background as TextureRect
	background.texture = load(LevelCatalog.background_path_for(MENU_GARDEN))
	BackgroundDrift.start(background)
	GardenAmbience.add_over(background).setup(MENU_GARDEN)
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


## Ranks the save has reached are awarded here, so a returning player's
## journey shows as new badges; the marker is a number, not only a colour.
func _show_new_badges() -> void:
	BadgeBook.award(GameSession.progress, LevelCatalog.count())
	var count := GameSession.progress.new_badges().size()
	_new_badges.visible = count > 0
	_new_badges_label.text = str(count)


func _play_intro() -> void:
	_title_block.modulate.a = 0.0
	_play_button.modulate.a = 0.0
	_daily_button.modulate.a = 0.0
	_words_button.modulate.a = 0.0
	_collection_button.modulate.a = 0.0
	_settings_button.modulate.a = 0.0
	_badges_button.modulate.a = 0.0
	_leaderboard_button.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_title_block, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_play_button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_daily_button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_words_button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_collection_button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_settings_button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_badges_button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_leaderboard_button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)


## The leaderboard lives in Google Play Games, so the button only shows where
## that is available (the Android app with Play Games set up).
func _update_leaderboard_button() -> void:
	var available := PlayGames.is_available()
	_leaderboard_button.visible = available
	_leaderboard_gap.visible = available


func _on_play_pressed() -> void:
	GameSession.go_levels()
