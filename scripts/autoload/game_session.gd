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


func _change(path: String) -> void:
	last_requested_scene = path
	if scene_changes_enabled:
		get_tree().change_scene_to_file(path)
