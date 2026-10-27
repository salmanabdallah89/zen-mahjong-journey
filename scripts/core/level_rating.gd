class_name LevelRating
extends RefCounted
## Stars for a cleared level (1 to 3):
##   1 star  - the level is cleared
##   2 stars - cleared with at most TWO_STAR_MISTAKES mistakes
##   3 stars - cleared with no mistakes and at least THREE_STAR_TIME_SHARE of
##             the clock left

const MAX_STARS := 3
const TWO_STAR_MISTAKES := 1
const THREE_STAR_TIME_SHARE := 0.5

## Rules for the level card. Words, not star glyphs: the UI font may not have them.
const RULES := "1 star: clear the level\n2 stars: at most 1 mistake\n3 stars: no mistakes and half the time left"


static func stars(time_left: float, time_limit: float, mistakes: int) -> int:
	if mistakes == 0 and time_limit > 0.0 and time_left >= time_limit * THREE_STAR_TIME_SHARE:
		return 3
	if mistakes <= TWO_STAR_MISTAKES:
		return 2
	return 1


## Difficulty label for the level card, from levels.json ("difficulty").
static func difficulty_label(difficulty: int) -> String:
	match difficulty:
		1:
			return "Easy"
		2:
			return "Medium"
		3:
			return "Hard"
		_:
			return "Expert"
