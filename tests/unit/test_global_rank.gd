extends TestCase
## World rank: replies from a stand-in Talo server, no network.

const SETTINGS := "user://test_global_rank.cfg"
const CONFIG := "user://test_leaderboard.json"

var _calls: PackedStringArray
var _position := 41
var _online := true


func _reply(method: String, url: String, headers: PackedStringArray, _body: String) -> Dictionary:
	_calls.append("%s %s" % [method, url])
	if not _online:
		return {}
	if url.contains("/players/identify"):
		return {"code": 200, "data": {"alias": {"id": 7, "player": {"id": "p-1"}}}}
	if method == "POST":
		assert_true(headers.has("x-talo-alias: 7"), "entries are sent as the identified player")
		return {"code": 200, "data": {"entry": {"position": _position}, "updated": true}}
	return {"code": 200, "data": {"entries": [], "count": 900}}


func _service() -> GlobalRankService:
	SafeConfig.remove_all(SETTINGS)
	var file := FileAccess.open(CONFIG, FileAccess.WRITE)
	file.store_string('{"access_key": "test"}')
	file.close()
	var service := GlobalRankService.new()
	service.settings_path = SETTINGS
	service.config_path = CONFIG
	service.transport = _reply
	_calls = PackedStringArray()
	_online = true
	_position = 41
	return service


func test_reports_ranks_from_one() -> void:
	var service := _service()
	var answers := []
	service.report(1200, 300, answers.append)
	assert_eq(answers.size(), 1, "the answer arrives")
	assert_eq(answers[0].rank, 42, "position 41 is rank 42")
	assert_eq(answers[0].players, 900, "player count")
	assert_eq(GlobalRankService.rank_text(answers[0]), "World rank #42 of 900\nThis week #42", "first text")
	_position = 29
	var again := []
	service.report(1500, 600, again.append)
	assert_true(GlobalRankService.rank_text(again[0]).ends_with("Up 12 places!"), "climbing is shown")
	assert_eq(_calls.size(), 7, "the player is identified only once")
	service.free()


func test_no_key_or_no_connection_shows_nothing() -> void:
	var service := _service()
	service.config_path = "user://missing_leaderboard.json"
	assert_true(not service.is_available(), "no key, no rank")
	var answers := []
	service.report(10, 10, answers.append)
	assert_eq(answers[0].size(), 0, "empty answer without a key")
	assert_eq(_calls.size(), 0, "nothing is sent without a key")
	service.config_path = CONFIG
	_online = false
	var offline := []
	service.report(10, 10, offline.append)
	assert_eq(GlobalRankService.rank_text(offline[0]), "", "offline shows no rank")
	service.free()


func test_week_number_turns_on_monday() -> void:
	var sunday := 1793577599  # 23:59:59 UTC on Sunday 1 November 2026.
	assert_eq(GlobalRankService.week_number(sunday + 1), GlobalRankService.week_number(sunday) + 1, "new week on Monday 00:00 UTC")


func test_week_points_add_up_and_restart() -> void:
	var path := "user://test_week_points.cfg"
	SafeConfig.remove_all(path)
	var store := ProgressStore.new(path)
	assert_eq(store.add_week_points(100, 5), 100, "first clear")
	assert_eq(store.add_week_points(50, 5), 150, "same week adds up")
	assert_eq(store.add_week_points(70, 6), 70, "a new week starts again")
	SafeConfig.remove_all(path)
	SafeConfig.remove_all(SETTINGS)
