class_name BadgeBook
extends RefCounted
## The badges: seventeen families with three ranks each (Bronze, Silver, Gold).
## A family's value comes from the save (`counter` families count events the
## save has no other record of; the rest are worked out from stars, scores and
## stages, so a returning player gets what the journey already earned).
## Ranks are only ever gained. Earning one marks it new until the Badges page
## has shown it.

const MAX_RANK := 3
const RANK_NAMES: PackedStringArray = ["Locked", "Bronze", "Silver", "Gold"]
const GROUPS: PackedStringArray = ["Journey", "Mastery", "Discoveries", "Word Garden", "Daily"]
const LEVELS_PER_CHAPTER := 20

## `picture` is a file in assets/words, struck into the medal in one metal.
const FAMILIES: Array[Dictionary] = [
	{"id": "pathfinder", "name": "Pathfinder", "group": "Journey", "picture": "footprints",
		"goal": "Clear %s levels", "goals": [10, 100, 500]},
	{"id": "star_gatherer", "name": "Star Gatherer", "group": "Journey", "picture": "star",
		"goal": "Collect %s stars", "goals": [30, 300, 1500]},
	{"id": "garden_keeper", "name": "Garden Keeper", "group": "Journey", "picture": "seedling",
		"goal": "Finish %s whole chapters", "goals": [1, 5, 25]},
	{"id": "golden_hands", "name": "Golden Hands", "group": "Journey", "picture": "trophy",
		"goal": "Reach a total score of %s", "goals": [25000, 250000, 1000000]},
	{"id": "still_mind", "name": "Still Mind", "group": "Mastery", "picture": "feather", "counter": true,
		"goal": "Clear %s levels without a mistake", "goals": [5, 50, 250]},
	{"id": "moon_gazer", "name": "Moon Gazer", "group": "Mastery", "picture": "telescope",
		"goal": "Earn 3 stars on %s levels", "goals": [5, 50, 300]},
	{"id": "swift_stream", "name": "Swift Stream", "group": "Mastery", "picture": "stopwatch", "counter": true,
		"goal": "Clear %s levels with 3/4 of the time left", "goals": [5, 25, 100]},
	{"id": "quiet_hands", "name": "Quiet Hands", "group": "Mastery", "picture": "hand", "counter": true,
		"goal": "Clear %s levels without hints or shuffles", "goals": [5, 50, 250]},
	{"id": "last_petal", "name": "Last Petal", "group": "Mastery", "picture": "rose", "counter": true,
		"goal": "Clear %s levels after the tray had one place left", "goals": [1, 10, 50]},
	{"id": "flowing_river", "name": "Flowing River", "group": "Mastery", "picture": "water_drop", "counter": true,
		"goal": "Reach the x5 combo in %s levels", "goals": [1, 25, 100]},
	{"id": "golden_lotus", "name": "Golden Lotus", "group": "Discoveries", "picture": "hibiscus", "counter": true,
		"goal": "Match %s golden lotus pairs", "goals": [5, 50, 250]},
	{"id": "veil_lifter", "name": "Veil Lifter", "group": "Discoveries", "picture": "magnifier", "counter": true,
		"goal": "Reveal %s mystery tiles", "goals": [25, 250, 1000]},
	{"id": "word_seeker", "name": "Word Seeker", "group": "Word Garden", "picture": "book",
		"goal": "Learn %s words in one language", "goals": [50, 250, 1000]},
	{"id": "world_voice", "name": "World Voice", "group": "Word Garden", "picture": "earth",
		"goal": "Clear a stage in %s languages", "goals": [2, 3, 4]},
	{"id": "perfect_recall", "name": "Perfect Recall", "group": "Word Garden", "picture": "brain",
		"goal": "Earn 3 stars on %s stages", "goals": [10, 50, 150]},
	{"id": "daily_calm", "name": "Daily Calm", "group": "Daily", "picture": "sunrise",
		"goal": "Play %s days in a row", "goals": [3, 7, 30]},
	{"id": "daily_keeper", "name": "Daily Keeper", "group": "Daily", "picture": "calendar",
		"goal": "Clear %s Daily Challenges", "goals": [5, 30, 150]},
]


static func family(family_id: String) -> Dictionary:
	for entry in FAMILIES:
		if entry.id == family_id:
			return entry
	return {}


static func families_in(group: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in FAMILIES:
		if entry.group == group:
			result.append(entry)
	return result


static func picture_path(entry: Dictionary) -> String:
	return "res://assets/words/%s.png" % entry.picture


static func total_ranks() -> int:
	return FAMILIES.size() * MAX_RANK


## Ranks earned so far, across all families.
static func earned_ranks(store: ProgressStore) -> int:
	var total := 0
	for entry in FAMILIES:
		total += store.badge_rank(entry.id)
	return total


## "Clear 100 levels": what rank `rank` (1..3) of a family asks for.
static func goal_text(entry: Dictionary, rank: int) -> String:
	return str(entry.goal) % ScoreMeter.format_points(int(entry.goals[rank - 1]))


## The rank a value reaches (0 when below the first goal).
static func rank_for(entry: Dictionary, value: int) -> int:
	var rank := 0
	for goal: int in entry.goals:
		if value >= goal:
			rank += 1
	return rank


## A family's progress as it stands in the save.
static func value_of(entry: Dictionary, store: ProgressStore, level_count: int) -> int:
	if entry.get("counter", false):
		return store.badge_count(entry.id)
	match str(entry.id):
		"pathfinder":
			return _count_levels(store, level_count, 1)
		"star_gatherer":
			return store.total_stars(level_count)
		"garden_keeper":
			return _whole_chapters(store, level_count)
		"golden_hands":
			return store.total_score(level_count)
		"moon_gazer":
			return _count_levels(store, level_count, LevelRating.MAX_STARS)
		"word_seeker":
			return _most_words(store)
		"world_voice":
			return _languages_started(store)
		"perfect_recall":
			return _perfect_stages(store)
		"daily_calm":
			return store.best_day_streak()
		"daily_keeper":
			return store.daily_total()
	return 0


## What a family's value is measured against: the next goal, or the last one
## when it has reached Gold.
static func next_goal(entry: Dictionary, rank: int) -> int:
	return int(entry.goals[mini(rank, MAX_RANK - 1)])


## Share of the way to the next rank, measured from the rank before it.
static func next_share(entry: Dictionary, value: int, rank: int) -> float:
	if rank >= MAX_RANK:
		return 1.0
	var start := 0 if rank == 0 else int(entry.goals[rank - 1])
	var goal := next_goal(entry, rank)
	return clampf(float(value - start) / float(goal - start), 0.0, 1.0)


## The family closest to its next rank, for the page's "next badge" card
## (empty once everything is Gold).
static func closest(store: ProgressStore, level_count: int) -> Dictionary:
	var best := {}
	var best_share := -1.0
	for entry in FAMILIES:
		var rank := store.badge_rank(entry.id)
		if rank >= MAX_RANK:
			continue
		var share := next_share(entry, value_of(entry, store, level_count), rank)
		if share > best_share:
			best_share = share
			best = entry
	return best


## Awards every rank the save has reached. Returns one {id, rank} per family
## that moved up, highest rank first, so a reveal starts with the best.
static func award(store: ProgressStore, level_count: int) -> Array[Dictionary]:
	var earned: Array[Dictionary] = []
	for entry in FAMILIES:
		var rank := rank_for(entry, value_of(entry, store, level_count))
		if rank > store.badge_rank(entry.id):
			earned.append({"id": entry.id, "rank": rank})
	if not earned.is_empty():
		earned.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rank > b.rank)
		store.earn_badges(earned)
	return earned


## The day number in the player's own time zone, for streaks.
static func local_day(unix_time: int, bias_minutes: int) -> int:
	return floori((unix_time + bias_minutes * 60) / 86400.0)


static func today() -> int:
	return local_day(int(Time.get_unix_time_from_system()), int(Time.get_time_zone_from_system().get("bias", 0)))


static func _count_levels(store: ProgressStore, level_count: int, at_least: int) -> int:
	var total := 0
	for level in range(1, level_count + 1):
		if store.stars(level) >= at_least:
			total += 1
	return total


static func _whole_chapters(store: ProgressStore, level_count: int) -> int:
	var total := 0
	for chapter in floori(float(level_count) / LEVELS_PER_CHAPTER):
		var whole := true
		for level in range(chapter * LEVELS_PER_CHAPTER + 1, (chapter + 1) * LEVELS_PER_CHAPTER + 1):
			if not store.is_cleared(level):
				whole = false
				break
		if whole:
			total += 1
	return total


## New words the cleared stages of a language taught; the best language counts.
static func _most_words(store: ProgressStore) -> int:
	var most := 0
	for language: Dictionary in WordCatalog.languages():
		var words := 0
		for stage in range(1, WordCatalog.stage_count() + 1):
			if store.word_stars(str(language.id), stage) > 0:
				words += WordCatalog.FIRST_STAGE_WORDS if stage == 1 else WordCatalog.NEW_WORDS_PER_STAGE
		most = maxi(most, words)
	return mini(most, WordCatalog.word_ids().size())


static func _languages_started(store: ProgressStore) -> int:
	var total := 0
	for language: Dictionary in WordCatalog.languages():
		for stage in range(1, WordCatalog.stage_count() + 1):
			if store.word_stars(str(language.id), stage) > 0:
				total += 1
				break
	return total


static func _perfect_stages(store: ProgressStore) -> int:
	var total := 0
	for language: Dictionary in WordCatalog.languages():
		for stage in range(1, WordCatalog.stage_count() + 1):
			if store.word_stars(str(language.id), stage) >= LevelRating.MAX_STARS:
				total += 1
	return total
