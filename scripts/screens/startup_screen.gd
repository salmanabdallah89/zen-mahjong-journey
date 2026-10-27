extends Control
## First screen shown on launch: environment background, game title and a
## Play button that starts the first level, and the Tile Collection chooser.

@onready var _title_block: Control = %TitleBlock
@onready var _play_button: Button = %PlayButton
@onready var _collection_button: Button = %CollectionButton
@onready var _picker: CollectionPicker = %CollectionPicker
@onready var _settings_button: Button = %SettingsButton
@onready var _settings: AudioSettingsPanel = %AudioSettings


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_collection_button.pressed.connect(_picker.open)
	_picker.hide()
	_settings_button.pressed.connect(_settings.open)
	_settings.hide()
	AudioManager.play_music("main_menu")
	AudioManager.set_ambience(AudioCatalog.MENU_AMBIENCE)
	_play_intro()


func _play_intro() -> void:
	_title_block.modulate.a = 0.0
	_play_button.modulate.a = 0.0
	_collection_button.modulate.a = 0.0
	_settings_button.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_title_block, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_play_button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_collection_button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_settings_button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)


func _on_play_pressed() -> void:
	GameSession.play_level(1)
