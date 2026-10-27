extends Node
## Autoload "GameSession": which level is being played and moving between
## screens. Holds no save data yet; progress resets when the app restarts.

const STARTUP_SCENE := "res://scenes/screens/startup_screen.tscn"
const GAME_SCENE := "res://scenes/screens/game_screen.tscn"

var current_level: int = 1


func play_level(number: int) -> void:
	current_level = clampi(number, 1, LevelCatalog.count())
	get_tree().change_scene_to_file(GAME_SCENE)


func has_next_level() -> bool:
	return current_level < LevelCatalog.count()


func play_next_level() -> void:
	play_level(current_level + 1)


func go_home() -> void:
	get_tree().change_scene_to_file(STARTUP_SCENE)
