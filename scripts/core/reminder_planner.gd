class_name ReminderPlanner
extends RefCounted
## Play reminders: which local notifications to schedule when the player
## leaves the game (docs/NOTIFICATIONS.md). Pure rules, no Nodes, no clock:
## the caller passes the local time and the save's facts.
##
## At most one reminder per day, never in quiet hours or soon after playing:
## today's Daily Challenge (if not played yet), tomorrow's, then "come back"
## reminders 3 and 7 days later. A player who keeps ignoring them gets only
## the weekly one, and after STOP_AFTER ignored reminders none at all.

const TEXTS_PATH := "res://data/reminders.json"

## Slot ids double as the Android notification ids.
const SLOT_TODAY := 1
const SLOT_TOMORROW := 2
const SLOT_DAY_3 := 3
const SLOT_DAY_7 := 4
const SLOT_DAYS := {SLOT_TODAY: 0, SLOT_TOMORROW: 1, SLOT_DAY_3: 3, SLOT_DAY_7: 7}

const DEFAULT_MINUTE := 19 * 60
## The usual play time is kept between 10:00 and 20:30.
const EARLIEST_MINUTE := 10 * 60
const LATEST_MINUTE := 20 * 60 + 30
## Quiet hours start here (21:00); nothing is planned after it.
const QUIET_START_MINUTE := 21 * 60
## No reminder within this many seconds of leaving the game.
const MIN_GAP := 4 * 3600
const STREAK_MIN := 3
const WEEKLY_AFTER_IGNORED := 3
const STOP_AFTER_IGNORED := 6
const SESSIONS_KEPT := 10

const OPEN_DAILY := "daily"
const OPEN_JOURNEY := "journey"


class State extends RefCounted:
	## Local time in seconds (unix time plus the time-zone bias).
	var now_local: int = 0
	var daily_done_today := false
	## Days in a row of live Daily Challenges (ProgressStore.daily_streak).
	var streak: int = 0
	var next_level: int = 1
	## Usual play time, minutes after local midnight (usual_minute()).
	var usual_minute: int = DEFAULT_MINUTE
	var ignored: int = 0


class Reminder extends RefCounted:
	var id: int = 0
	## Seconds from now.
	var delay: int = 0
	var kind := ""
	var title := ""
	var body := ""
	## Screen a tap opens: OPEN_DAILY or OPEN_JOURNEY.
	var open := ""


static func plan(state: State, texts := load_texts()) -> Array[Reminder]:
	var planned: Array[Reminder] = []
	if state.ignored >= STOP_AFTER_IGNORED:
		return planned
	var weekly_only := state.ignored >= WEEKLY_AFTER_IGNORED
	var today := floori(state.now_local / 86400.0)
	var minute := clampi(state.usual_minute, EARLIEST_MINUTE, LATEST_MINUTE)
	for slot: int in [SLOT_TODAY, SLOT_TOMORROW, SLOT_DAY_3, SLOT_DAY_7]:
		if weekly_only and slot != SLOT_DAY_7:
			continue
		var day: int = today + int(SLOT_DAYS[slot])
		var at := day * 86400 + minute * 60
		if at - state.now_local < MIN_GAP or minute >= QUIET_START_MINUTE:
			continue
		var kind := _kind_for(slot, state)
		if kind.is_empty():
			continue
		var reminder := Reminder.new()
		reminder.id = slot
		reminder.delay = at - state.now_local
		reminder.kind = kind
		reminder.open = open_for(slot)
		var words := {"streak": state.streak, "level": state.next_level}
		var entry: Dictionary = texts.get(kind, {})
		reminder.title = str(entry.get("title", "")).format(words)
		var bodies: Array = entry.get("bodies", [])
		if not bodies.is_empty():
			reminder.body = str(bodies[posmod(day, bodies.size())]).format(words)
		planned.append(reminder)
	return planned


## "daily", "streak", "journey" or "" (nothing for this slot).
static func _kind_for(slot: int, state: State) -> String:
	match slot:
		SLOT_TODAY:
			if state.daily_done_today:
				return ""
			return "streak" if state.streak >= STREAK_MIN else "daily"
		SLOT_TOMORROW:
			# A streak still runs tomorrow only if today's day is played.
			return "streak" if state.daily_done_today and state.streak >= STREAK_MIN else "daily"
	return "journey"


## The screen a tapped reminder opens, from its id.
static func open_for(id: int) -> String:
	return OPEN_DAILY if id == SLOT_TODAY or id == SLOT_TOMORROW else OPEN_JOURNEY


## Median start time of the recent sessions (minutes after midnight), or the
## default evening time when there are none.
static func usual_minute(session_minutes: Array) -> int:
	if session_minutes.is_empty():
		return DEFAULT_MINUTE
	var sorted := session_minutes.duplicate()
	sorted.sort()
	return int(sorted[sorted.size() / 2])


## The ignored count after the player opens the game: a tapped reminder clears
## it, reminders that were shown but not tapped add to it.
static func ignored_after_open(ignored: int, shown: int, opened_from_reminder: bool) -> int:
	if opened_from_reminder:
		return 0
	return ignored + shown


static func load_texts() -> Dictionary:
	if not FileAccess.file_exists(TEXTS_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXTS_PATH))
	return parsed if parsed is Dictionary else {}
