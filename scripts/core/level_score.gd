class_name LevelScore
extends RefCounted
## Points for one attempt at a level (pure rules, no Nodes):
##   - every match earns MATCH_POINTS times the combo multiplier, which grows
##     with matches in a row (x1 … x5); undo takes that match's points back
##   - clearing the level adds TIME_BONUS_PER_SECOND for every whole second
##     left and FLAWLESS_BONUS when no mistake was made
## The leaderboard ranks the sum of every level's best score (ProgressStore).

const MATCH_POINTS := 100
const MAX_MULTIPLIER := 5
const TIME_BONUS_PER_SECOND := 10
const FLAWLESS_BONUS := 500

## Points from matches so far this attempt.
var match_points := 0


## Multiplier for the `combo`-th match in a row: x1, then x2 from 2 in a row,
## x3 from 4, x4 from 6, x5 from 8.
static func multiplier(combo: int) -> int:
	return clampi(1 + floori(combo / 2.0), 1, MAX_MULTIPLIER)


static func points_for(combo: int) -> int:
	return MATCH_POINTS * multiplier(combo)


## Adds a match and returns the points it earned.
func add_match(combo: int) -> int:
	var points := points_for(combo)
	match_points += points
	return points


## Undo: takes back the points a match earned.
func take_back(points: int) -> void:
	match_points = maxi(match_points - points, 0)


static func time_bonus(time_left: float) -> int:
	return floori(maxf(time_left, 0.0)) * TIME_BONUS_PER_SECOND


static func flawless_bonus(mistakes: int) -> int:
	return FLAWLESS_BONUS if mistakes == 0 else 0


## Final score for a cleared level.
func total(time_left: float, mistakes: int) -> int:
	return match_points + time_bonus(time_left) + flawless_bonus(mistakes)
