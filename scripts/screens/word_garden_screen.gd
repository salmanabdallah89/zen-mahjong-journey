extends Control
## Word Garden's map: every stage is a mahjong tile on the same gold thread as
## the journey (JourneyWorld), per language. The Play button or an open tile
## starts a stage; the language button chooses what to learn and which language
## the player speaks (asked on the first visit). A stage opens when the one
## before it is cleared.

const SETTINGS_SECTION := "words"
const SETTINGS_KEY := "language"
const SETTINGS_KEY_NATIVE := "native"
const DEFAULT_NATIVE := "ar"

var settings_path := UserSettings.DEFAULT_PATH
var _language := ""
## The stage the player has reached (1-based).
var _current := 1
var _group := ButtonGroup.new()
var _native_group := ButtonGroup.new()
var _toast_tween: Tween
## Chapter the header shows (-1: needs refreshing).
var _shown_chapter := -1

@onready var _world: JourneyWorld = %World
@onready var _header: Control = %Header
@onready var _back: Button = %BackButton
@onready var _title: Label = %Title
@onready var _caption: Label = %Caption
@onready var _chapter_bar: ProgressBar = %ChapterBar
@onready var _stars_value: Label = %StarsValue
@onready var _buttons: Control = %BottomButtons
@onready var _language_button_main: Button = %LanguageButton
@onready var _play: Button = %PlayButton
@onready var _panel: Control = %LanguagePanel
@onready var _languages: GridContainer = %Languages
@onready var _natives: GridContainer = %Natives
@onready var _done: Button = %DoneButton
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel


func _ready() -> void:
	_back.pressed.connect(GameSession.go_home)
	_play.pressed.connect(func() -> void: GameSession.play_word_stage(_language, _current))
	_language_button_main.pressed.connect(_panel.show)
	_done.pressed.connect(_panel.hide)
	_toast.hide()
	AudioManager.play_music("main_menu")
	AudioManager.set_ambience(AudioCatalog.MENU_AMBIENCE)
	var languages := WordCatalog.languages()
	var settings := UserSettings.new(settings_path)
	var saved := str(settings.get_value(SETTINGS_SECTION, SETTINGS_KEY, ""))
	var saved_native := str(settings.get_value(SETTINGS_SECTION, SETTINGS_KEY_NATIVE, DEFAULT_NATIVE))
	_language = str(languages[0].id)
	for language: Dictionary in languages:
		if str(language.id) == saved:
			_language = saved
		if str(language.id) == saved_native:
			GameSession.word_native = saved_native
	for language: Dictionary in languages:
		_languages.add_child(_choice_button(language, _group, _language, choose_language))
		_natives.add_child(_choice_button(language, _native_group, GameSession.word_native, choose_native))
	_guard_languages()
	_panel.visible = saved.is_empty()
	_world.input_blocker = func() -> bool: return _panel.visible
	_world.ui_hit = _covers_map
	_world.camera_moved.connect(func(_camera: float) -> void: _show_chapter())
	_world.setup(WordCatalog.stage_count(), _setup_node)
	_refresh()
	_world.focus_level(_current, false)
	($Petals as CPUParticles2D).emitting = not Motion.reduced
	($Petals as CPUParticles2D).visible = not Motion.reduced


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or not is_node_ready():
		return
	if _panel.visible:
		_panel.hide()
	else:
		GameSession.go_home()


func language() -> String:
	return _language


func current_stage() -> int:
	return _current


func is_stage_open(stage: int) -> bool:
	return stage == 1 or GameSession.progress.word_stars(_language, stage - 1) > 0


## The stop for `stage` if it is on screen (else null).
func stage_node(stage: int) -> LevelNode:
	return _world.node_for(stage)


func focus_stage(stage: int) -> void:
	_world.focus_level(stage, false)


func choose_language(language_id: String) -> void:
	_language = language_id
	UserSettings.new(settings_path).set_value(SETTINGS_SECTION, SETTINGS_KEY, language_id)
	_guard_languages()
	_refresh()
	_world.focus_level(_current, false)


func choose_native(language_id: String) -> void:
	GameSession.word_native = language_id
	UserSettings.new(settings_path).set_value(SETTINGS_SECTION, SETTINGS_KEY_NATIVE, language_id)
	_guard_languages()


## Learning a language needs another one to translate into.
func _guard_languages() -> void:
	if GameSession.word_native == _language:
		var other := "en" if _language != "en" else DEFAULT_NATIVE
		GameSession.word_native = other
		(_natives.get_node(other) as Button).button_pressed = true
	for button: Button in _natives.get_children():
		button.disabled = button.name == _language


func _choice_button(language: Dictionary, group: ButtonGroup, current: String, on_choose: Callable) -> Button:
	var button := Button.new()
	button.text = str(language.name)
	button.name = str(language.id)
	button.toggle_mode = true
	button.button_group = group
	button.button_pressed = str(language.id) == current
	button.theme_type_variation = &"LanguageButton"
	button.custom_minimum_size = Vector2(350, 120)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_choose.bind(str(language.id)))
	return button


## Re-reads the chosen language's progress into the stops on screen.
func _refresh() -> void:
	var count := WordCatalog.stage_count()
	_current = count
	var stars := 0
	for stage in range(count, 0, -1):
		var earned := GameSession.progress.word_stars(_language, stage)
		stars += earned
		if earned == 0:
			_current = stage
	_world.set_current(_current - 1)
	_world.refresh_nodes()
	_stars_value.text = "%d / %d" % [stars, count * LevelRating.MAX_STARS]
	_play.text = "Play Stage %d" % _current
	for language: Dictionary in WordCatalog.languages():
		if str(language.id) == _language:
			_language_button_main.text = str(language.name)
	_shown_chapter = -1
	_show_chapter()


## Fills a stop as it comes into view (the map reuses stops while scrolling).
func _setup_node(node: LevelNode, stage: int) -> void:
	if not node.has_meta("wired"):
		node.set_meta("wired", true)
		node.pressed.connect(_on_stage_pressed)
	var level := WordCatalog.level_for(stage)
	level.number = stage
	level.title = "Stage %d" % stage
	var earned := GameSession.progress.word_stars(_language, stage)
	node.setup(level, earned, is_stage_open(stage), stage == _current, "%d WORDS" % WordCatalog.word_count(stage))


func _on_stage_pressed(stage: int) -> void:
	if is_stage_open(stage):
		AudioManager.play_sfx("button_click")
		GameSession.play_word_stage(_language, stage)
		return
	var node := _world.node_for(stage)
	if node:
		node.play_locked_nudge()
	AudioManager.play_sfx("tile_blocked")
	_show_toast("Clear Stage %d to unlock this stage." % (stage - 1))


func _covers_map(point: Vector2) -> bool:
	return _header.get_global_rect().has_point(point) or _buttons.get_global_rect().has_point(point)


## The header follows the chapter in view: garden name and stages cleared.
func _show_chapter() -> void:
	var chapter := int(_world.chapter_at_camera().x)
	if chapter == _shown_chapter:
		return
	_shown_chapter = chapter
	var first := chapter * LevelRecipe.CHAPTER_SIZE + 1
	var last := mini(first + LevelRecipe.CHAPTER_SIZE - 1, WordCatalog.stage_count())
	var cleared := 0
	for stage in range(first, last + 1):
		cleared += 1 if GameSession.progress.word_stars(_language, stage) > 0 else 0
	_title.text = BackgroundStyle.garden_name(LevelRecipe.garden_of_chapter(chapter))
	_caption.text = "CHAPTER %d · %d OF %d" % [chapter + 1, cleared, last - first + 1]
	_chapter_bar.max_value = last - first + 1
	_chapter_bar.value = cleared


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.show()
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_toast.hide)
