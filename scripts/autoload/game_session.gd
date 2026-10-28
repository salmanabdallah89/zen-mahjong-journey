extends Node
## Autoload "GameSession": which level is being played, the saved journey
## progress, and moving between screens.

const STARTUP_SCENE := "res://scenes/screens/startup_screen.tscn"
const GAME_SCENE := "res://scenes/screens/game_screen.tscn"
const JOURNEY_SCENE := "res://scenes/screens/journey_screen.tscn"

var current_level: int = 1
var progress := ProgressStore.new()
## Level opened by the last clear, so the journey map can celebrate it once.
var just_unlocked := 0
## Tests turn scene changes off and read the scene that would have opened.
var scene_changes_enabled := true
var last_requested_scene := ""

const FADE_OUT := 0.22
const FADE_IN := 0.32
const FADE_COLOR := Color(0.20784314, 0.30980393, 0.26666668, 0.0)

var _fade: ColorRect
## Shown on the fade while the next screen loads (seconds on the web, where
## loading blocks drawing; a blink on phones).
var _loading: Label
var _fade_tween: Tween


func _ready() -> void:
	# Keeps fading while the tree is paused and above ads and dialogs.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_fade = ColorRect.new()
	_fade.name = "ScreenFade"
	_fade.color = FADE_COLOR
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_loading = Label.new()
	_loading.text = "Loading…"
	_loading.theme_type_variation = &"ComboLabel"
	_loading.add_theme_font_size_override("font_size", 48)
	_loading.set_anchors_preset(Control.PRESET_CENTER)
	_loading.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loading.grow_vertical = Control.GROW_DIRECTION_BOTH
	_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading.modulate.a = 0.0
	_fade.add_child(_loading)


## First-play tutorial (level 1): seen/skipped state lives in user settings,
## so returning players are never interrupted. "How to Play" asks for it again.
const TUTORIAL_SECTION := "tutorial"
const TUTORIAL_KEY := "level1_done"
var tutorial_settings_path := UserSettings.DEFAULT_PATH
## Set by "How to Play": the next level 1 shows the tutorial even if seen.
var tutorial_requested := false


func tutorial_seen() -> bool:
	return bool(UserSettings.new(tutorial_settings_path).get_value(TUTORIAL_SECTION, TUTORIAL_KEY, false))


## `how` is "completed" or "skipped" (kept for later tuning).
func set_tutorial_seen(how: String) -> void:
	var settings := UserSettings.new(tutorial_settings_path)
	settings.set_value(TUTORIAL_SECTION, TUTORIAL_KEY, true)
	settings.set_value(TUTORIAL_SECTION, "outcome", how)
	tutorial_requested = false


func should_show_tutorial(level_number: int) -> bool:
	return level_number == 1 and (tutorial_requested or not tutorial_seen())


## "How to Play": replays the tutorial on level 1.
func start_tutorial() -> void:
	tutorial_requested = true
	play_level(1)


func play_level(number: int) -> void:
	current_level = clampi(number, 1, LevelCatalog.count())
	_change(GAME_SCENE)


func has_next_level() -> bool:
	return current_level < LevelCatalog.count()


func play_next_level() -> void:
	play_level(current_level + 1)


func go_home() -> void:
	_change(STARTUP_SCENE)


func go_levels() -> void:
	_change(JOURNEY_SCENE)


## Screens change behind a soft fade through the garden's forest green; taps
## are blocked while it runs. Reduced animations make it a quick dip.
func _change(path: String) -> void:
	last_requested_scene = path
	if not scene_changes_enabled:
		return
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	var out_time := Motion.duration(FADE_OUT)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 1.0, out_time * (1.0 - _fade.color.a)).set_trans(Tween.TRANS_SINE)
	# Draw "Loading…" for a frame before loading blocks the screen.
	_fade_tween.tween_callback(func() -> void: _loading.modulate.a = 0.7)
	_fade_tween.tween_interval(0.03)
	_fade_tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file(path)
		_loading.modulate.a = 0.0)
	# Give the new screen a frame to build before revealing it.
	_fade_tween.tween_interval(0.05)
	_fade_tween.tween_property(_fade, "color:a", 0.0, Motion.duration(FADE_IN)).set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_callback(func() -> void: _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE)


func is_changing_scene() -> bool:
	return _fade_tween != null and _fade_tween.is_running()
