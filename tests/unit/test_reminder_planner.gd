extends TestCase
## Which play reminders get scheduled when the player leaves the game.

const DAY := 86400
const TODAY := 20000


func _state(hour: int, minute := 0) -> ReminderPlanner.State:
	var state := ReminderPlanner.State.new()
	state.now_local = TODAY * DAY + hour * 3600 + minute * 60
	state.next_level = 42
	return state


func _ids(planned: Array[ReminderPlanner.Reminder]) -> Array[int]:
	var ids: Array[int] = []
	for reminder in planned:
		ids.append(reminder.id)
	return ids


func _texts() -> Dictionary:
	return {
		"daily": {"title": "Daily", "bodies": ["d0", "d1", "d2"]},
		"streak": {"title": "{streak}-day streak", "bodies": ["s"]},
		"journey": {"title": "Journey", "bodies": ["Level {level}"]},
	}


func test_morning_player_gets_today_tomorrow_and_come_back_reminders() -> void:
	var planned := ReminderPlanner.plan(_state(9), _texts())
	assert_eq(_ids(planned), [1, 2, 3, 4], "four slots")
	assert_eq(planned[0].delay, 10 * 3600, "today at 19:00")
	assert_eq(planned[1].delay, DAY + 10 * 3600, "tomorrow at 19:00")
	assert_eq(planned[2].delay, 3 * DAY + 10 * 3600, "day 3")
	assert_eq(planned[3].delay, 7 * DAY + 10 * 3600, "day 7")
	assert_eq(planned[0].open, ReminderPlanner.OPEN_DAILY, "daily opens the calendar")
	assert_eq(planned[3].open, ReminderPlanner.OPEN_JOURNEY, "come back opens the journey")
	assert_eq(planned[3].body, "Level 42", "level filled in")


func test_nothing_within_four_hours_of_playing() -> void:
	var planned := ReminderPlanner.plan(_state(16), _texts())
	assert_false(_ids(planned).has(1), "19:00 is too soon after 16:00")
	assert_true(_ids(planned).has(2), "tomorrow still planned")


func test_no_daily_reminder_today_once_it_is_played() -> void:
	var state := _state(8)
	state.daily_done_today = true
	assert_false(_ids(ReminderPlanner.plan(state, _texts())).has(1), "already played")


func test_streak_reminder_only_when_the_streak_can_continue() -> void:
	var state := _state(8)
	state.streak = 5
	var planned := ReminderPlanner.plan(state, _texts())
	assert_eq(planned[0].kind, "streak", "today keeps the streak")
	assert_eq(planned[0].title, "5-day streak", "streak in title")
	assert_eq(planned[1].kind, "daily", "tomorrow: streak breaks unless today is played")
	state.daily_done_today = true
	planned = ReminderPlanner.plan(state, _texts())
	assert_eq(planned[0].kind, "streak", "tomorrow keeps it")
	assert_eq(planned[0].id, ReminderPlanner.SLOT_TOMORROW, "first is tomorrow")
	state.streak = 2
	assert_eq(ReminderPlanner.plan(state, _texts())[0].kind, "daily", "short streaks are not mentioned")


func test_usual_time_is_the_median_kept_out_of_quiet_hours() -> void:
	assert_eq(ReminderPlanner.usual_minute([]), ReminderPlanner.DEFAULT_MINUTE, "default evening")
	assert_eq(ReminderPlanner.usual_minute([600, 1300, 720]), 720, "median")
	var state := _state(1)
	state.usual_minute = 23 * 60
	var planned := ReminderPlanner.plan(state, _texts())
	assert_eq(planned[0].delay, 19 * 3600 + 30 * 60, "late players are reminded at 20:30")
	state.usual_minute = 6 * 60
	planned = ReminderPlanner.plan(state, _texts())
	assert_eq(planned[0].delay, 9 * 3600, "early players at 10:00")


func test_ignored_reminders_back_off_then_stop() -> void:
	var state := _state(9)
	state.ignored = ReminderPlanner.WEEKLY_AFTER_IGNORED
	assert_eq(_ids(ReminderPlanner.plan(state, _texts())), [4], "weekly only")
	state.ignored = ReminderPlanner.STOP_AFTER_IGNORED
	assert_true(ReminderPlanner.plan(state, _texts()).is_empty(), "stopped")
	assert_eq(ReminderPlanner.ignored_after_open(2, 1, false), 3, "shown, not tapped")
	assert_eq(ReminderPlanner.ignored_after_open(5, 1, true), 0, "a tap clears it")
	assert_eq(ReminderPlanner.ignored_after_open(2, 0, false), 2, "nothing shown")


func test_at_most_one_reminder_per_day() -> void:
	var days := {}
	for reminder in ReminderPlanner.plan(_state(9), _texts()):
		var day := floori((_state(9).now_local + reminder.delay) / float(DAY))
		assert_false(days.has(day), "one per day")
		days[day] = true


func test_text_varies_by_day_and_shipped_texts_load() -> void:
	var planned := ReminderPlanner.plan(_state(9), _texts())
	assert_true(planned[0].body != planned[1].body, "today and tomorrow differ")
	var shipped := ReminderPlanner.load_texts()
	for kind in ["daily", "streak", "journey"]:
		assert_true(shipped.has(kind), "texts for " + kind)
		assert_false((shipped[kind].bodies as Array).is_empty(), "bodies for " + kind)
	for reminder in ReminderPlanner.plan(_state(9)):
		assert_false(reminder.title.is_empty() or reminder.body.is_empty(), "shipped text filled")
		assert_false(reminder.body.contains("{"), "placeholders filled")
