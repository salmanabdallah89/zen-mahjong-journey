extends TestCase
## Daily Challenge: dates, the daily puzzle, streaks and monthly trophies.

const PATH := "user://test_daily.cfg"
## 2 November 2026, a Monday.
const MONDAY := 20759


func _store() -> ProgressStore:
	SafeConfig.remove_all(PATH)
	return ProgressStore.new(PATH)


func test_dates() -> void:
	assert_eq(DailyChallenge.date_title(MONDAY), "2 November", "day title")
	assert_eq(DailyChallenge.month_title(MONDAY), "November 2026", "month title")
	assert_eq(int(DailyChallenge.date_of(MONDAY).weekday), 1, "weekday")
	assert_eq(DailyChallenge.first_of_month(MONDAY), MONDAY - 1, "first of month")
	assert_eq(DailyChallenge.days_in_month(MONDAY), 30, "November has 30 days")
	assert_eq(DailyChallenge.date_title(DailyChallenge.previous_month(MONDAY)), "1 October", "previous month")
	assert_eq(DailyChallenge.date_title(DailyChallenge.next_month(MONDAY)), "1 December", "next month")
	var february := DailyChallenge.first_of_month(MONDAY + 100)
	assert_eq(DailyChallenge.days_in_month(february), 28, "February 2027 has 28 days")


func test_only_this_month_up_to_today_is_playable() -> void:
	assert_true(DailyChallenge.is_playable(MONDAY, MONDAY), "today")
	assert_true(DailyChallenge.is_playable(MONDAY - 1, MONDAY), "earlier this month")
	assert_false(DailyChallenge.is_playable(MONDAY + 1, MONDAY), "tomorrow")
	assert_false(DailyChallenge.is_playable(MONDAY - 2, MONDAY), "last month")


func test_every_day_of_a_year_deals_a_clearable_board() -> void:
	var art := TileArtSet.active()
	var seeds := {}
	for day in range(MONDAY, MONDAY + 366):
		var level := DailyChallenge.level_for(day)
		seeds[level.deal_seed] = true
		assert_eq(level.time_limit, 0, "no clock")
		assert_eq(level.mistake_limit, 0, "no hearts")
		assert_true(BackgroundStyle.board_shade(level.background) >= 0.0, "known garden")
		if day % 30 == 0:
			var deal := BoardGenerator.generate(level.load_layout().build_geometry(), level.face_pool(art), level.deal_seed)
			assert_true(deal.ok, "day %d deals" % day)
	assert_eq(seeds.size(), 366, "every day is its own puzzle")


func test_same_day_same_puzzle() -> void:
	var a := DailyChallenge.level_for(MONDAY)
	var b := DailyChallenge.level_for(MONDAY)
	assert_eq(a.layout_path, b.layout_path, "same layout")
	assert_eq(a.deal_seed, b.deal_seed, "same seed")
	assert_eq(a.background, b.background, "same garden")


func test_best_stars_are_kept() -> void:
	var store := _store()
	store.record_daily(MONDAY, 3, true)
	store.record_daily(MONDAY, 1, true)
	assert_eq(ProgressStore.new(PATH).daily_stars(MONDAY), 3, "best stars saved")
	assert_eq(store.daily_total(), 1, "a replay is one day")
	SafeConfig.remove_all(PATH)


func test_streak_counts_only_days_played_on_the_day() -> void:
	var store := _store()
	store.record_daily(MONDAY - 2, 3, true)
	store.record_daily(MONDAY - 1, 3, true)
	assert_eq(store.daily_streak(MONDAY), 2, "today not played yet keeps the streak")
	store.record_daily(MONDAY, 2, true)
	assert_eq(store.daily_streak(MONDAY), 3, "today adds one")
	assert_eq(store.daily_streak(MONDAY + 2), 0, "a missed day ends it")
	store.record_daily(MONDAY + 1, 3, false)
	assert_eq(store.daily_streak(MONDAY + 2), 0, "catching up does not repair it")
	SafeConfig.remove_all(PATH)


func test_trophies() -> void:
	assert_eq(DailyChallenge.trophy_rank(9, 30), 0, "below bronze")
	assert_eq(DailyChallenge.trophy_rank(10, 30), 1, "bronze")
	assert_eq(DailyChallenge.trophy_rank(20, 30), 2, "silver")
	assert_eq(DailyChallenge.trophy_rank(30, 30), 3, "gold is every day")
	assert_eq(DailyChallenge.next_trophy_goal(2, 31), 31, "gold needs the whole month")
	var store := _store()
	store.record_daily(MONDAY, 3, true)
	store.record_daily(MONDAY - 1, 1, false)
	store.record_daily(MONDAY - 2, 3, true)
	assert_eq(DailyChallenge.month_count(store, MONDAY), 2, "only this month counts")
	SafeConfig.remove_all(PATH)


func test_daily_keeper_badge_reads_the_days() -> void:
	var store := _store()
	for day in range(MONDAY, MONDAY + 5):
		store.record_daily(day, 3, true)
	assert_eq(BadgeBook.value_of(BadgeBook.family("daily_keeper"), store, 10), 5, "days cleared")
	assert_eq(BadgeBook.award(store, 10)[0].id, "daily_keeper", "five days earn Bronze")
	SafeConfig.remove_all(PATH)
