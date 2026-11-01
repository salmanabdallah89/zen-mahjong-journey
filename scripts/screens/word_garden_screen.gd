extends Control
## Word Garden's first page: choose the language to learn and a stage. A stage
## opens when the one before it is cleared.

const GARDEN := "bg_bamboo_forest"
const STAR := preload("res://assets/ui/icons/icon_star.png")
const STAGE_SIZE := Vector2(464, 136)
const STAR_SIZE := 44.0
const SETTINGS_SECTION := "words"
const SETTINGS_KEY := "language"

var settings_path := UserSettings.DEFAULT_PATH
var _language := ""
var _group := ButtonGroup.new()

@onready var _languages: HBoxContainer = %Languages
@onready var _stages: GridContainer = %Stages
@onready var _back: Button = %BackButton


func _ready() -> void:
	_back.pressed.connect(GameSession.go_home)
	var background := %Background as TextureRect
	background.texture = load(LevelCatalog.background_path_for(GARDEN))
	AudioManager.play_music("main_menu")
	AudioManager.set_ambience(AudioCatalog.MENU_AMBIENCE)
	var languages := WordCatalog.languages()
	var saved := str(UserSettings.new(settings_path).get_value(SETTINGS_SECTION, SETTINGS_KEY, ""))
	_language = str(languages[0].id)
	for language: Dictionary in languages:
		if str(language.id) == saved:
			_language = saved
		_languages.add_child(_language_button(language))
	_show_stages()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		GameSession.go_home()


func language() -> String:
	return _language


func stage_button(stage: int) -> Button:
	return _stages.get_child(stage - 1)


func choose_language(language_id: String) -> void:
	_language = language_id
	UserSettings.new(settings_path).set_value(SETTINGS_SECTION, SETTINGS_KEY, language_id)
	_show_stages()


func _language_button(language: Dictionary) -> Button:
	var button := Button.new()
	button.text = str(language.name)
	button.name = str(language.id)
	button.toggle_mode = true
	button.button_group = _group
	button.button_pressed = str(language.id) == _language
	button.theme_type_variation = &"CollectionCard"
	button.custom_minimum_size = Vector2(320, 136)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(choose_language.bind(str(language.id)))
	return button


func _show_stages() -> void:
	for child in _stages.get_children():
		_stages.remove_child(child)
		child.queue_free()
	var latest := 1
	for stage in range(1, WordCatalog.stage_count() + 1):
		_stages.add_child(_stage_button(stage))
		if GameSession.progress.word_stars(_language, stage - 1) > 0:
			latest = stage
	_scroll_to.call_deferred(latest)


## The list opens on the stage the player has reached.
func _scroll_to(stage: int) -> void:
	await get_tree().process_frame
	if is_inside_tree():
		%StageScroll.ensure_control_visible(stage_button(stage))


func _stage_button(stage: int) -> Button:
	var progress := GameSession.progress
	var open := stage == 1 or progress.word_stars(_language, stage - 1) > 0
	var button := Button.new()
	button.text = "Stage %d" % stage if open else "Stage %d · Locked" % stage
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.disabled = not open
	button.theme_type_variation = &"SecondaryButton"
	button.custom_minimum_size = STAGE_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: GameSession.play_word_stage(_language, stage))
	var stars := HBoxContainer.new()
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.alignment = BoxContainer.ALIGNMENT_END
	stars.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	stars.offset_left = -190.0
	stars.offset_right = -44.0
	stars.add_theme_constant_override("separation", 2)
	button.add_child(stars)
	for i in progress.word_stars(_language, stage):
		var star := TextureRect.new()
		star.texture = STAR
		star.custom_minimum_size = Vector2(STAR_SIZE, STAR_SIZE)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars.add_child(star)
	return button
