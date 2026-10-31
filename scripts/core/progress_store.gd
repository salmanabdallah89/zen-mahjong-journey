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
