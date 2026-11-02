class_name DailyChallenge
extends RefCounted
## One calm puzzle a day, the same for everyone on that date: no clock, no
## hearts, and built from the day number alone. A day number counts days since
## 1970 in the player's own time zone (BadgeBook.today). Days earlier in the
## current month can be caught up, but only the day itself keeps a streak.
## Cleared days earn the month's trophy: Bronze, Silver, then Gold for all.

const SEED_BASE := 500000
const SECONDS_PER_DAY := 86400
const TROPHY_DAYS: Array[int] = [10, 20]
const TROPHY := {"group": "Daily", "picture": "trophy"}
const MONTH_NAMES: PackedStringArray = ["January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December"]
## Week in calendar order, Sunday first.
const WEEKDAY_NAMES: PackedStringArray = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
## Difficulty by weekday: a gentle start, a little more towards the weekend.
const WEEK_DIFFICULTY: Array[int] = [2, 1, 1, 2, 2, 3, 3]
## Hand-out of golden lotus and mystery tiles, as on this journey level.
const SPECIALS_LEVEL := 10
const THREE_STAR_MISTAKES := 0
const TWO_STAR_MISTAKES := 2


static func date_of(day: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(day * SECONDS_PER_DAY)


## "2 November"
static func date_title(day: int) -> String:
	var date := date_of(day)
	return "%d %s" % [date.day, MONTH_NAMES[date.month - 1]]


## "November 2026"
static func month_title(day: int) -> String:
	var date := date_of(day)
	return "%s %d" % [MONTH_NAMES[date.month - 1], date.year]


static func first_of_month(day: int) -> int:
	return day - int(date_of(day).day) + 1


static func days_in_month(day: int) -> int:
	var first := first_of_month(day)
	return first_of_month(first + 31) - first


## The first day of the month before the one holding `day`.
static func previous_month(day: int) -> int:
	return first_of_month(first_of_month(day) - 1)


static func next_month(day: int) -> int:
	return first_of_month(first_of_month(day) + 31)


## Today and earlier days of this month can be played.
static func is_playable(day: int, today: int) -> bool:
	return day <= today and first_of_month(day) == first_of_month(today)


static func stars(mistakes: int) -> int:
	if mistakes <= THREE_STAR_MISTAKES:
		return LevelRating.MAX_STARS
	return 2 if mistakes <= TWO_STAR_MISTAKES else 1


## Cleared days in the month holding `day`.
static func month_count(store: ProgressStore, day: int) -> int:
	var first := first_of_month(day)
	var total := 0
	for offset in days_in_month(day):
		if store.daily_stars(first + offset) > 0:
			total += 1
	return total


## 0 none, then Bronze, Silver and Gold (BadgeBook ranks).
static func trophy_rank(cleared: int, month_days: int) -> int:
	if cleared >= month_days:
		return BadgeBook.MAX_RANK
	var rank := 0
	for goal in TROPHY_DAYS:
		if cleared >= goal:
			rank += 1
	return rank


## Days needed for the rank after `rank` (the whole month for Gold).
static func next_trophy_goal(rank: int, month_days: int) -> int:
	return TROPHY_DAYS[rank] if rank < TROPHY_DAYS.size() else month_days


static func level_for(day: int) -> LevelCatalog.LevelDefinition:
	var rng := RandomNumberGenerator.new()
	rng.seed = (SEED_BASE + day) * 2654435761 % 4294967296
	var difficulty: int = WEEK_DIFFICULTY[int(date_of(day).weekday)]
	var choices: Array = LevelRecipe.LAYOUTS[difficulty]
	var level := LevelCatalog.LevelDefinition.new()
	level.title = date_title(day)
	level.layout_path = "res://data/layouts/%s.json" % str(choices[rng.randi() % choices.size()])
	level.deal_seed = SEED_BASE + day
	level.suits = PackedStringArray(LevelRecipe.SUITS[difficulty])
	level.difficulty = difficulty
	level.background = LevelRecipe.GARDENS[rng.randi() % LevelRecipe.GARDENS.size()]
	level.time_limit = 0
	level.mistake_limit = 0
	return level
