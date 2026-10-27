extends TestCase
## Star rating rules and saved journey progress.

const PATH := "user://test_progress_unit.cfg"


func _fresh() -> ProgressStore:
	var store := ProgressStore.new(PATH)
	store.reset()
	return store


func test_star_rules() -> void:
	assert_eq(LevelRating.stars(100.0, 180.0, 0), 3, "no mistakes and over half the time left: 3 stars")
	assert_eq(LevelRating.stars(90.0, 180.0, 0), 3, "exactly half the time left still earns 3 stars")
	assert_eq(LevelRating.stars(89.0, 180.0, 0), 2, "under half the time: 2 stars")
	assert_eq(LevelRating.stars(170.0, 180.0, 1), 2, "one mistake: at most 2 stars")
	assert_eq(LevelRating.stars(170.0, 180.0, 2), 1, "two mistakes: 1 star")
	assert_eq(LevelRating.stars(1.0, 180.0, 4), 1, "any clear earns at least 1 star")


func test_difficulty_labels() -> void:
	assert_eq(LevelRating.difficulty_label(1), "Easy", "1 is Easy")
	assert_eq(LevelRating.difficulty_label(4), "Expert", "4 is Expert")
	for level in LevelCatalog.levels():
		assert_true(level.difficulty >= 1 and level.difficulty <= 4, "level %d has a difficulty" % level.number)


func test_fresh_journey_opens_only_level_one() -> void:
	var store := _fresh()
	assert_true(store.is_unlocked(1), "level 1 is open")
	assert_false(store.is_unlocked(2), "level 2 starts locked")
	assert_eq(store.total_stars(10), 0, "no stars yet")
	assert_eq(store.current_level(10), 1, "journey starts at level 1")


func test_clear_unlocks_next_and_keeps_best() -> void:
	var store := _fresh()
	var first := store.record_clear(1, 2, 60.0, 10)
	assert_eq(first.unlocked, 2, "clearing level 1 opens level 2")
	assert_true(first.new_best_stars, "first clear is a best")
	assert_true(store.is_unlocked(2) and not store.is_unlocked(3), "only the next level opens")
	var worse := store.record_clear(1, 1, 30.0, 10)
	assert_eq(store.stars(1), 2, "a worse replay keeps the best stars")
	assert_false(worse.new_best_stars or worse.new_best_time, "a worse replay is not a best")
	assert_eq(worse.unlocked, 0, "replaying does not unlock again")
	var better := store.record_clear(1, 3, 120.0, 10)
	assert_eq(store.stars(1), 3, "a better replay raises the stars")
	assert_true(better.new_best_stars and better.new_best_time, "better replay reports new bests")
	assert_eq(store.best_time_left(1), 120.0, "best time left is kept")
	assert_eq(store.current_level(10), 2, "journey continues at level 2")
	assert_eq(store.total_stars(10), 3, "total stars")


func test_last_level_unlocks_nothing() -> void:
	var store := _fresh()
	for level in range(1, 11):
		store.record_clear(level, 1, 10.0, 10)
	assert_eq(store.record_clear(10, 3, 10.0, 10).unlocked, 0, "there is no level 11")
	assert_eq(store.current_level(10), 10, "journey ends at level 10")


func test_progress_survives_restart() -> void:
	var store := _fresh()
	store.record_clear(1, 3, 99.0, 10)
	store.record_clear(2, 1, 5.0, 10)
	var reloaded := ProgressStore.new(PATH)
	assert_eq(reloaded.stars(1), 3, "stars saved")
	assert_eq(reloaded.best_time_left(1), 99.0, "best time saved")
	assert_true(reloaded.is_unlocked(3), "unlocks saved")
	reloaded.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
