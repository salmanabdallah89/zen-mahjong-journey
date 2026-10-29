extends Node
## Google Play Games: sign-in and the total-score leaderboard (every level's
## best score added up, ProgressStore.total_score).
##
## Works only on Android with the GodotPlayGameServices plugin enabled
## (addons/GodotPlayGameServices, its game id set in the Android export preset)
## and a leaderboard id in data/play_games.json. Everywhere else (web, desktop,
## a phone without the plugin) is_available() is false, every call does nothing
## and the game plays the same. Setup: docs/PLAY_GAMES.md.

## Sign-in finished (also the silent check at start-up).
signal signed_in_changed(signed_in: bool)

const CONFIG_PATH := "res://data/play_games.json"
const PLUGIN_NAME := "GodotPlayGameServices"

var leaderboard_id := ""
var signed_in := false
## Scores sent, newest last (tests read it).
var submitted: Array[int] = []
## The Android plugin (or a stand-in in tests); null when unavailable.
var _plugin: Object
## Best total waiting for sign-in, or -1.
var _pending_score := -1
var _open_board_after_sign_in := false


func _ready() -> void:
	leaderboard_id = str(_load_config().get("leaderboard_total_score", ""))
	if OS.get_name() == "Android" and Engine.has_singleton(PLUGIN_NAME) and not leaderboard_id.is_empty():
		var plugin := Engine.get_singleton(PLUGIN_NAME)
		plugin.call("initialize")
		use_plugin(plugin)


## Connects the plugin (the real one, or a test stand-in with the same method
## and signal names) and checks quietly whether the player is signed in.
func use_plugin(plugin: Object) -> void:
	_plugin = plugin
	signed_in = false
	if plugin == null:
		return
	plugin.connect("userAuthenticated", _on_user_authenticated)
	plugin.connect("scoreSubmitted", _on_score_submitted)
	plugin.call("isAuthenticated")


func is_available() -> bool:
	return _plugin != null and not leaderboard_id.is_empty()


## Opens Google's leaderboard screen, signing in first when needed.
func show_leaderboard() -> void:
	if not is_available():
		return
	if signed_in:
		_plugin.call("showLeaderboard", leaderboard_id)
	else:
		_open_board_after_sign_in = true
		_plugin.call("signIn")


## Sends the player's total score. Before sign-in it waits; Google keeps only a
## player's best, so sending the same total again is harmless.
func submit_total(score: int) -> void:
	if not is_available() or score <= 0:
		return
	if not signed_in:
		_pending_score = maxi(_pending_score, score)
		return
	submitted.append(score)
	_plugin.call("submitScore", leaderboard_id, score)


func _on_user_authenticated(is_authenticated: bool) -> void:
	signed_in = is_authenticated
	signed_in_changed.emit(signed_in)
	if not signed_in:
		_open_board_after_sign_in = false
		return
	# Progress made before signing in (or on an older version) counts too.
	var total := maxi(_pending_score, GameSession.progress.total_score(LevelCatalog.count()))
	_pending_score = -1
	submit_total(total)
	if _open_board_after_sign_in:
		_open_board_after_sign_in = false
		_plugin.call("showLeaderboard", leaderboard_id)


func _on_score_submitted(is_submitted: bool, board_id: String) -> void:
	if not is_submitted:
		push_warning("PlayGames: score not submitted to %s" % board_id)


func _load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	return parsed if parsed is Dictionary else {}
