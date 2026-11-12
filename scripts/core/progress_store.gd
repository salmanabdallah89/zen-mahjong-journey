class_name ProgressStore
extends RefCounted
## The player's journey: best stars, best time left and best score per level, saved in a
## ConfigFile (user://progress.cfg). Level 1 is always open; each cleared
## level opens the next.

const DEFAULT_PATH := "user://progress.cfg"

var path: String
var _config := ConfigFile.new()


func _init(p_path := DEFAULT_PATH) -> void:
	path = p_path
	# A missing file is a fresh journey; a damaged one falls back to its backup.
	SafeConfig.load_into(_config, path)


func stars(level: int) -> int:
	return int(_config.get_value(_section(level), "stars", 0))


func is_cleared(level: int) -> bool:
	return stars(level) > 0


func is_unlocked(level: int) -> bool:
	return level == 1 or is_cleared(level - 1)


## Most seconds ever left on the clock when clearing, or -1 if never cleared.
func best_time_left(level: int) -> float:
	return float(_config.get_value(_section(level), "best_time_left", -1.0))


## Highest score ever made on a level (LevelScore), 0 if none yet.
func best_score(level: int) -> int:
	return int(_config.get_value(_section(level), "best_score", 0))


## The leaderboard score: every level's best score added up.
func total_score(level_count: int) -> int:
	var total := 0
	for level in range(1, level_count + 1):
		total += best_score(level)
	return total


## Adds a clear's points to the weekly competition; a new `week` starts from
## zero. Returns the points so far this week.
func add_week_points(points: int, week: int) -> int:
	var total := points
	if int(_config.get_value("week", "number", -1)) == week:
		total += int(_config.get_value("week", "points", 0))
	_config.set_value("week", "number", week)
	_config.set_value("week", "points", total)
	SafeConfig.save(_config, path)
	return total


## Word Garden stars for a stage of a language, 0 if never cleared.
func word_stars(language: String, stage: int) -> int:
	return int(_config.get_value("words_" + language, "stage_%d" % stage, 0))


## Words the player mixed up and should meet again.
func word_review(language: String) -> PackedStringArray:
	return PackedStringArray(_config.get_value("words_" + language, "review", PackedStringArray()))


## Saves a cleared stage: the best stars, and which words still need practice
## (`missed` join the list, words matched first try leave it).
func record_word_stage(language: String, stage: int, earned_stars: int, words: PackedStringArray, missed: PackedStringArray) -> void:
	var section := "words_" + language
	_config.set_value(section, "stage_%d" % stage, maxi(word_stars(language, stage), earned_stars))
	var review := PackedStringArray()
	for word in word_review(language):
		if not words.has(word):
			review.append(word)
	review.append_array(missed)
	_config.set_value(section, "review", review)
	SafeConfig.save(_config, path)


## Daily Challenge stars of a day number, 0 if not cleared.
func daily_stars(day: int) -> int:
	return int(_config.get_value("daily", "day_%d" % day, 0))


## Saves a cleared day, keeping the best stars. `on_the_day` keeps the streak;
## catching up later does not.
func record_daily(day: int, earned_stars: int, on_the_day: bool) -> void:
	_config.set_value("daily", "day_%d" % day, maxi(daily_stars(day), earned_stars))
	if on_the_day:
		_config.set_value("daily", "live_%d" % day, true)
	SafeConfig.save(_config, path)


## Days cleared, ever.
func daily_total() -> int:
	if not _config.has_section("daily"):
		return 0
	var total := 0
	for key in _config.get_section_keys("daily"):
		if key.begins_with("day_"):
			total += 1
	return total


## Days in a row played on the day, up to `today` (or yesterday while today is
## still to play).
func daily_streak(today: int) -> int:
	var day := today if _played_live(today) else today - 1
	var streak := 0
	while _played_live(day):
		streak += 1
		day -= 1
	return streak


func _played_live(day: int) -> bool:
	return bool(_config.get_value("daily", "live_%d" % day, false))


## Rank of a badge family (BadgeBook), 0 if not earned yet.
func badge_rank(family_id: String) -> int:
	return int(_config.get_value("badges", "rank_" + family_id, 0))


## How often a counted badge's event has happened.
func badge_count(family_id: String) -> int:
	return int(_config.get_value("badges", "count_" + family_id, 0))


## Longest run of days in a row with a clear.
func best_day_streak() -> int:
	return int(_config.get_value("badges", "best_streak", 0))


## Saves what a clear added to the counted badges ({family id: amount}) and
## the day it happened on.
func record_badge_facts(counts: Dictionary, day: int) -> void:
	for family_id: String in counts:
		_config.set_value("badges", "count_" + family_id, badge_count(family_id) + int(counts[family_id]))
	var last_day := int(_config.get_value("badges", "last_day", -1))
	if day != last_day:
		var streak := 1
		if day == last_day + 1:
			streak += int(_config.get_value("badges", "streak", 0))
		_config.set_value("badges", "last_day", day)
		_config.set_value("badges", "streak", streak)
		_config.set_value("badges", "best_streak", maxi(streak, best_day_streak()))
	SafeConfig.save(_config, path)


## Family ids earned or ranked up since the Badges page last showed them.
func new_badges() -> PackedStringArray:
	return PackedStringArray(_config.get_value("badges", "new", PackedStringArray()))


## Saves earned ranks ({id, rank} entries) and marks them new.
func earn_badges(earned: Array[Dictionary]) -> void:
	var fresh := new_badges()
	for entry in earned:
		_config.set_value("badges", "rank_" + str(entry.id), int(entry.rank))
		if not fresh.has(str(entry.id)):
			fresh.append(str(entry.id))
	_config.set_value("badges", "new", fresh)
	SafeConfig.save(_config, path)


func clear_new_badges() -> void:
	_config.set_value("badges", "new", PackedStringArray())
	SafeConfig.save(_config, path)


## Lotus Gifts (LotusRewards). Gifts of levels cleared before the feature
## arrived count as opened, so a returning player is not handed a pile of
## them at once: `baseline` is the last gift level cleared at that moment.
func lotus_baseline() -> int:
	return int(_config.get_value("rewards", "baseline", -1))


func _ensure_lotus_baseline() -> void:
	if lotus_baseline() >= 0:
		return
	var level := LotusRewards.EVERY
	var last := 0
	while is_cleared(level):
		last = level
		level += LotusRewards.EVERY
	_config.set_value("rewards", "baseline", last)


func is_lotus_opened(level: int) -> bool:
	if level <= maxi(lotus_baseline(), 0):
		return true
	return bool(_config.get_value("rewards", "lotus_%d" % level, false))


## A gift level that is cleared but whose gift is still closed.
func is_lotus_ready(level: int) -> bool:
	_ensure_lotus_baseline()
	return LotusRewards.is_gift_level(level) and is_cleared(level) and not is_lotus_opened(level)


## Opens a ready gift: the tools go to the saved ones (up to MAX_SAVED each).
## Returns what was added, or an empty gift if it was not ready.
func open_lotus(level: int) -> Dictionary:
	if not is_lotus_ready(level):
		return {"hints": 0, "shuffles": 0}
	var gift := LotusRewards.gift_for(level)
	var added := {}
	for key: String in ["hints", "shuffles"]:
		var before := saved_tools(key)
		var after := mini(before + int(gift[key]), LotusRewards.MAX_SAVED)
		_config.set_value("rewards", "saved_" + key, after)
		added[key] = after - before
	_config.set_value("rewards", "lotus_%d" % level, true)
	SafeConfig.save(_config, path)
	return added


## Saved hints or shuffles: `kind` is "hints" or "shuffles".
func saved_tools(kind: String) -> int:
	return int(_config.get_value("rewards", "saved_" + kind, 0))


## Spends one saved tool; false if there was none.
func spend_saved_tool(kind: String) -> bool:
	var left := saved_tools(kind)
	if left <= 0:
		return false
	_config.set_value("rewards", "saved_" + kind, left - 1)
	SafeConfig.save(_config, path)
	return true


## Levels ever cleared with no mistakes, hints or shuffles.
func is_perfect(level: int) -> bool:
	return bool(_config.get_value(_section(level), "perfect", false))


## Saves a Perfect Clear; true if it is the level's first.
func record_perfect(level: int) -> bool:
	if is_perfect(level):
		return false
	_config.set_value(_section(level), "perfect", true)
	SafeConfig.save(_config, path)
	return true


func total_stars(level_count: int) -> int:
	var total := 0
	for level in range(1, level_count + 1):
		total += stars(level)
	return total


## Highest open level (the one the journey continues from).
func current_level(level_count: int) -> int:
	var level := 1
	while level < level_count and is_unlocked(level + 1):
		level += 1
	return level


class Result extends RefCounted:
	var stars: int = 0
	var previous_stars: int = 0
	var new_best_stars: bool = false
	var new_best_time: bool = false
	var previous_score: int = 0
	## A higher score than an earlier clear (never true on the first clear).
	var new_best_score: bool = false
	## Level number that this result opened for the first time, or 0.
	var unlocked: int = 0


## Saves a clear, keeping the best stars, best time and best score separately.
func record_clear(level: int, earned_stars: int, time_left: float, level_count: int, score := 0) -> Result:
	# Fixes which gifts predate the feature before this clear can open one.
	_ensure_lotus_baseline()
	var result := Result.new()
	result.stars = earned_stars
	result.previous_stars = stars(level)
	var next_was_locked := level < level_count and not is_unlocked(level + 1)
	if earned_stars > result.previous_stars:
		_config.set_value(_section(level), "stars", earned_stars)
		result.new_best_stars = true
	if time_left > best_time_left(level):
		_config.set_value(_section(level), "best_time_left", time_left)
		result.new_best_time = result.previous_stars > 0
	result.previous_score = best_score(level)
	if score > result.previous_score:
		_config.set_value(_section(level), "best_score", score)
		result.new_best_score = result.previous_stars > 0
	if next_was_locked and is_unlocked(level + 1):
		result.unlocked = level + 1
	SafeConfig.save(_config, path)
	return result


func reset() -> void:
	_config.clear()
	SafeConfig.save(_config, path)


static func _section(level: int) -> String:
	return "level_%d" % level
