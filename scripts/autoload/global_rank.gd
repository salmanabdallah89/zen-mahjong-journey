class_name GlobalRankService
extends Node
## The player's world rank, from the Talo leaderboards (docs/LEADERBOARD.md).
## report() sends the total score and this week's points after each clear and
## answers with the ranks. It never blocks play: without a key (web, tests) or
## without a connection the answer is simply empty and no rank is shown.

const CONFIG_PATH := "res://data/leaderboard.json"
const API := "https://api.trytalo.com/v1"
const TOTAL_BOARD := "total-score"
const WEEK_BOARD := "weekly-score"
const IDENTITY_SERVICE := "zen_mahjong"
const TIMEOUT := 8.0
const SETTINGS_SECTION := "online"
## Weeks start on Monday; 1 January 1970 was a Thursday.
const FIRST_MONDAY := 345600
const WEEK_SECONDS := 604800

var settings_path := UserSettings.DEFAULT_PATH
var config_path := CONFIG_PATH
## func(method: String, url: String, headers: PackedStringArray, body: String) -> Dictionary
## answering {"code": int, "data": Variant}. Tests replace it.
var transport: Callable = _http
var _alias_id := 0
var _player_id := ""


## The current week's number, for ProgressStore.add_week_points().
static func week_number(unix_time: int) -> int:
	return floori(float(unix_time - FIRST_MONDAY) / WEEK_SECONDS)


## What the Level Complete dialog shows; "" for an empty answer.
static func rank_text(answer: Dictionary) -> String:
	if answer.is_empty():
		return ""
	var players := int(answer.players)
	var text := "World rank #%s" % ScoreMeter.format_points(int(answer.rank))
	if players > 0:
		text += " of %s" % ScoreMeter.format_points(players)
	if int(answer.week_rank) > 0:
		text += "\nThis week #%s" % ScoreMeter.format_points(int(answer.week_rank))
	var climbed := int(answer.previous_rank) - int(answer.rank)
	if int(answer.previous_rank) > 0 and climbed > 0:
		text += "\nUp %s %s!" % [ScoreMeter.format_points(climbed), "place" if climbed == 1 else "places"]
	return text


func is_available() -> bool:
	return not _access_key().is_empty()


## Calls `done` with {rank, players, week_rank, previous_rank} (ranks from 1),
## or with {} when there is no rank to show. A freed `done` is skipped.
func report(total_score: int, week_points: int, done: Callable) -> void:
	var answer := await _fetch(total_score, week_points)
	if done.is_valid():
		done.call(answer)


func _fetch(total_score: int, week_points: int) -> Dictionary:
	if not is_available() or not await _identify():
		return {}
	var rank := await _submit(TOTAL_BOARD, total_score)
	if rank <= 0:
		return {}
	var week_rank := await _submit(WEEK_BOARD, week_points)
	var players := await _player_count()
	var settings := UserSettings.new(settings_path)
	var previous := int(settings.get_value(SETTINGS_SECTION, "last_rank", 0))
	settings.set_value(SETTINGS_SECTION, "last_rank", rank)
	return {"rank": rank, "players": players, "week_rank": week_rank, "previous_rank": previous}


func _identify() -> bool:
	if _alias_id > 0:
		return true
	var query := "service=%s&identifier=%s" % [IDENTITY_SERVICE, _anonymous_id()]
	var reply: Dictionary = await transport.call("GET", "%s/players/identify?%s" % [API, query], _headers(), "")
	var data: Variant = reply.get("data")
	if int(reply.get("code", 0)) != 200 or not data is Dictionary or not data.has("alias"):
		return false
	_alias_id = int(data.alias.id)
	_player_id = str(data.alias.player.id)
	return true


## The rank on `board` (from 1), or 0 if it could not be sent.
func _submit(board: String, score: int) -> int:
	var url := "%s/leaderboards/%s/entries" % [API, board]
	var reply: Dictionary = await transport.call("POST", url, _headers(), JSON.stringify({"score": score}))
	var data: Variant = reply.get("data")
	if int(reply.get("code", 0)) != 200 or not data is Dictionary or not data.has("entry"):
		return 0
	return int(data.entry.get("position", -1)) + 1


func _player_count() -> int:
	var url := "%s/leaderboards/%s/entries?page=0" % [API, TOTAL_BOARD]
	var reply: Dictionary = await transport.call("GET", url, _headers(), "")
	var data: Variant = reply.get("data")
	return int(data.get("count", 0)) if data is Dictionary else 0


func _headers() -> PackedStringArray:
	var headers: PackedStringArray = ["Authorization: Bearer %s" % _access_key(), "Content-Type: application/json"]
	if _alias_id > 0:
		headers.append("x-talo-alias: %d" % _alias_id)
		headers.append("x-talo-player: %s" % _player_id)
	return headers


## A random id, the only thing that links scores to this install.
func _anonymous_id() -> String:
	var settings := UserSettings.new(settings_path)
	var saved := str(settings.get_value(SETTINGS_SECTION, "player_id", ""))
	if saved.is_empty():
		saved = Crypto.new().generate_random_bytes(16).hex_encode()
		settings.set_value(SETTINGS_SECTION, "player_id", saved)
	return saved


func _access_key() -> String:
	if not FileAccess.file_exists(config_path):
		return ""
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	return str(data.get("access_key", "")) if data is Dictionary else ""


func _http(method: String, url: String, headers: PackedStringArray, body: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = TIMEOUT
	add_child(request)
	var http_method := HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET
	if request.request(url, headers, http_method, body) != OK:
		request.queue_free()
		return {}
	var result: Array = await request.request_completed
	request.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {}
	return {"code": int(result[1]), "data": JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())}
