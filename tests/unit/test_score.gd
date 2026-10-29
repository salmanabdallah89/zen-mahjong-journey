extends TestCase
## Level points (LevelScore) and best scores for the leaderboard (ProgressStore).

const PATH := "user://test_score_unit.cfg"


func test_multiplier_grows_with_combo() -> void:
	var seen := []
	for combo in range(1, 11):
		seen.append(LevelScore.multiplier(combo))
	assert_eq(seen, [1, 2, 2, 3, 3, 4, 4, 5, 5, 5], "x1, x2 from 2 in a row … x5 from 8")
	assert_eq(LevelScore.multiplier(0), 1, "never below x1")
	assert_eq(LevelScore.points_for(1), 100, "a single match is 100")
	assert_eq(LevelScore.points_for(4), 300, "4 in a row is 300")


func test_matches_undo_and_bonuses() -> void:
	var score := LevelScore.new()
	assert_eq(score.add_match(1), 100, "first match")
	var second := score.add_match(2)
	assert_eq(second, 200, "second in a row is doubled")
	assert_eq(score.match_points, 300, "points add up")
	score.take_back(second)
	assert_eq(score.match_points, 100, "undo takes the match's points back")
	score.take_back(500)
	assert_eq(score.match_points, 0, "points never go below 0")
	score.add_match(1)
	assert_eq(LevelScore.time_bonus(42.9), 420, "10 per whole second left")
	assert_eq(LevelScore.time_bonus(-3.0), 0, "no time bonus below 0")
	assert_eq(score.total(42.9, 0), 100 + 420 + 500, "flawless clear adds 500")
	assert_eq(score.total(42.9, 1), 100 + 420, "a mistake loses the flawless bonus")


func test_best_score_saved_and_totalled() -> void:
	SafeConfig.remove_all(PATH)
	var store := ProgressStore.new(PATH)
	var first := store.record_clear(1, 2, 60.0, 10, 1500)
	assert_false(first.new_best_score, "a first clear is not called a new best")
	assert_eq(store.best_score(1), 1500, "first score saved")
	var worse := store.record_clear(1, 2, 60.0, 10, 900)
	assert_false(worse.new_best_score, "a lower score is not a best")
	assert_eq(store.best_score(1), 1500, "a lower score keeps the best")
	var better := store.record_clear(1, 2, 60.0, 10, 2100)
	assert_true(better.new_best_score and better.previous_score == 1500, "a higher replay is a new best")
	store.record_clear(2, 1, 10.0, 10, 800)
	assert_eq(store.total_score(10), 2900, "total is the sum of best scores")
	assert_eq(ProgressStore.new(PATH).total_score(10), 2900, "scores survive a restart")
	store.record_clear(3, 1, 10.0, 10)
	assert_eq(store.best_score(3), 0, "old callers without a score save none")
	SafeConfig.remove_all(PATH)
