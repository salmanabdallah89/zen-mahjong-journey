extends TestCase
## Badge rules: values, ranks, streaks and saving.

const PATH := "user://test_badges.cfg"
const LEVELS := 100


func _store() -> ProgressStore:
	SafeConfig.remove_all(PATH)
	return ProgressStore.new(PATH)


func test_families_are_complete() -> void:
	var seen := {}
	for entry in BadgeBook.FAMILIES:
		assert_false(seen.has(entry.id), "duplicate family " + str(entry.id))
		seen[entry.id] = true
		assert_true(BadgeBook.GROUPS.has(entry.group), "known group: " + str(entry.id))
		assert_true(BadgeMedal.ENAMEL.has(entry.group), "enamel for " + str(entry.group))
		assert_true(ResourceLoader.exists(BadgeBook.picture_path(entry)), "picture for " + str(entry.id))
		assert_eq(entry.goals.size(), BadgeBook.MAX_RANK, "three goals: " + str(entry.id))
		assert_true(entry.goals[0] < entry.goals[1] and entry.goals[1] < entry.goals[2], "goals rise: " + str(entry.id))
	SafeConfig.remove_all(PATH)


func test_rank_and_share_follow_the_goals() -> void:
	var entry := BadgeBook.family("pathfinder")
	assert_eq(BadgeBook.rank_for(entry, 9), 0, "below the first goal")
	assert_eq(BadgeBook.rank_for(entry, 10), 1, "bronze at the goal")
	assert_eq(BadgeBook.rank_for(entry, 500), 3, "gold at the last goal")
	assert_eq(BadgeBook.next_share(entry, 55, 1), 0.5, "share counts from the rank before")
	assert_eq(BadgeBook.next_share(entry, 600, 3), 1.0, "gold is full")


func test_award_comes_from_the_save_once() -> void:
	var store := _store()
	for level in range(1, 21):
		store.record_clear(level, 3, 10.0, LEVELS, 100)
	var earned := BadgeBook.award(store, LEVELS)
	var ids := earned.map(func(entry: Dictionary) -> String: return entry.id)
	assert_true(ids.has("pathfinder"), "20 clears earn Pathfinder")
	assert_true(ids.has("star_gatherer"), "60 stars earn Star Gatherer")
	assert_true(ids.has("garden_keeper"), "a whole chapter earns Garden Keeper")
	assert_true(ids.has("moon_gazer"), "20 three-star levels earn Moon Gazer")
	assert_eq(store.new_badges().size(), earned.size(), "each is marked new")
	assert_true(BadgeBook.award(store, LEVELS).is_empty(), "nothing is awarded twice")
	store.clear_new_badges()
	assert_eq(ProgressStore.new(PATH).new_badges().size(), 0, "seen marks are saved")
	assert_eq(ProgressStore.new(PATH).badge_rank("pathfinder"), 1, "ranks are saved")
	SafeConfig.remove_all(PATH)


func test_a_rank_is_never_lost() -> void:
	var store := _store()
	store.earn_badges([{"id": "pathfinder", "rank": 2}])
	assert_true(BadgeBook.award(store, LEVELS).is_empty(), "a lower value earns nothing")
	assert_eq(store.badge_rank("pathfinder"), 2, "the rank stays")
	SafeConfig.remove_all(PATH)


func test_counters_add_up_and_best_rank_comes_first() -> void:
	var store := _store()
	store.record_badge_facts({"still_mind": 3}, 10)
	store.record_badge_facts({"still_mind": 2, "last_petal": 10}, 10)
	assert_eq(store.badge_count("still_mind"), 5, "counts add up")
	var earned := BadgeBook.award(store, LEVELS)
	assert_eq(earned[0].id, "last_petal", "the higher rank is revealed first")
	assert_eq(earned[0].rank, 2, "ten last-heart clears are Silver")
	SafeConfig.remove_all(PATH)


func test_day_streak() -> void:
	var store := _store()
	for day in [10, 10, 11, 12]:
		store.record_badge_facts({}, day)
	assert_eq(store.best_day_streak(), 3, "same-day plays count once")
	store.record_badge_facts({}, 20)
	assert_eq(store.best_day_streak(), 3, "a gap keeps the best streak")
	store.record_badge_facts({}, 21)
	assert_eq(ProgressStore.new(PATH).best_day_streak(), 3, "the streak is saved")
	SafeConfig.remove_all(PATH)


func test_local_day_uses_the_players_time_zone() -> void:
	assert_eq(BadgeBook.local_day(86399, 0), 0, "before midnight")
	assert_eq(BadgeBook.local_day(86399, 60), 1, "an hour ahead is the next day")


func test_word_badges_read_the_stages() -> void:
	var store := _store()
	for stage in range(1, 11):
		store.record_word_stage("es", stage, 3, PackedStringArray(), PackedStringArray())
	store.record_word_stage("fr", 1, 1, PackedStringArray(), PackedStringArray())
	assert_eq(BadgeBook.value_of(BadgeBook.family("word_seeker"), store, LEVELS), 12 + 9 * 8, "new words of the best language")
	assert_eq(BadgeBook.value_of(BadgeBook.family("world_voice"), store, LEVELS), 2, "languages with a cleared stage")
	assert_eq(BadgeBook.value_of(BadgeBook.family("perfect_recall"), store, LEVELS), 10, "three-star stages")
	SafeConfig.remove_all(PATH)


func test_closest_badge_is_the_nearest_rank() -> void:
	var store := _store()
	store.record_badge_facts({"last_petal": 0, "still_mind": 4}, 10)
	assert_eq(BadgeBook.closest(store, LEVELS).id, "still_mind", "four of five is the closest")
	SafeConfig.remove_all(PATH)
