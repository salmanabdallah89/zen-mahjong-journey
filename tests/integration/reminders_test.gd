extends Node
## Play reminders with a stand-in phone (_FakeBridge): the soft question and
## its limits, Android's permission answer, planning on leaving and cancelling
## on return, ignored reminders, a tapped reminder opening its screen, and the
## Settings switch. The real plugin only runs on a phone.
##   godot --headless --path . res://tests/integration/reminders_test.tscn

const SETTINGS_SCENE := preload("res://scenes/components/audio_settings.tscn")
const SETTINGS_PATH := "user://test_reminders.cfg"
const PROGRESS_PATH := "user://test_reminders_progress.cfg"
const DAY := 86400
## A Monday morning, 09:00 UTC.
const MORNING := 20000 * DAY + 9 * 3600

var _failures := PackedStringArray()
var _checks := 0


class _FakeBridge extends ReminderBridge:
	var grant := true
	var permitted := false
	var requests := 0
	var scheduled: Array[int] = []
	var cancelled: Array[int] = []
	var settings_opened := 0

	func is_supported() -> bool:
		return true

	func is_available() -> bool:
		return true

	func has_permission() -> bool:
		return permitted

	func request_permission() -> void:
		requests += 1
		permitted = grant
		permission_answered.emit(grant)

	func schedule(reminder: ReminderPlanner.Reminder) -> void:
		scheduled.append(reminder.id)

	func cancel(id: int) -> void:
		cancelled.append(id)

	func open_settings() -> void:
		settings_opened += 1


func _ready() -> void:
	_check(not Reminders.is_available(), "desktop runs have no reminders")
	SafeConfig.remove_all(SETTINGS_PATH)
	Reminders.settings_path = SETTINGS_PATH
	Reminders.returned()
	_check(not FileAccess.file_exists(SETTINGS_PATH), "without a phone nothing is saved")
	_check(not Reminders.offer_if_due(), "no question without a phone")
	var panel: AudioSettingsPanel = SETTINGS_SCENE.instantiate()
	add_child(panel)
	panel.open()
	_check(not (panel.get_node("%RemindersRow") as Control).visible, "no Settings switch without a phone")
	panel.queue_free()

	GameSession.progress = ProgressStore.new(PROGRESS_PATH)
	GameSession.progress.reset()
	GameSession.scene_changes_enabled = false
	Reminders.now_override = MORNING
	Reminders.bias_override = 0

	await _test_offer()
	await _test_planning()
	await _test_tap()
	await _test_denial()
	await _test_settings_switch()

	Reminders.close_offer()
	Reminders.use_bridge(ReminderBridge.new())
	Reminders.now_override = -1
	Reminders.settings_path = UserSettings.DEFAULT_PATH
	Reminders.restore()
	GameSession.scene_changes_enabled = true
	GameSession.progress.reset()
	SafeConfig.remove_all(PROGRESS_PATH)
	SafeConfig.remove_all(SETTINGS_PATH)
	GameSession.progress = ProgressStore.new()
	for failure in _failures:
		print("  FAIL  " + failure)
	print("reminders: %d checks, %d failed" % [_checks, _failures.size()])
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _fresh(grant := true) -> _FakeBridge:
	SafeConfig.remove_all(SETTINGS_PATH)
	Reminders.close_offer()
	Reminders.restore()
	var fake := _FakeBridge.new()
	fake.grant = grant
	Reminders.use_bridge(fake)
	return fake


func _test_offer() -> void:
	var fake := _fresh()
	_check(not Reminders.offer_if_due(), "a new player is not asked")
	for level in [1, 2, 3]:
		GameSession.progress.record_clear(level, 3, 10.0, LevelCatalog.count())
	_check(Reminders.offer_if_due(), "asked after three clears")
	_check(Reminders.is_offer_open(), "the question shows")
	_check(fake.requests == 0, "Android is not asked before the player says yes")
	var buttons := _offer_buttons()
	_check(buttons.size() == 2 and buttons[0].text == "Remind Me" and buttons[1].text == "Not Now", "Remind Me / Not Now")
	_check(buttons.all(func(b: Button) -> bool: return b.custom_minimum_size.y >= 120.0), "touch targets")
	buttons[1].pressed.emit()
	_check(not Reminders.is_offer_open() and not Reminders.enabled, "Not Now closes it, reminders stay off")
	_check(not Reminders.offer_if_due(), "not asked again the same week")
	Reminders.now_override = MORNING + 7 * DAY
	_check(Reminders.offer_if_due(), "asked once more a week later")
	_offer_buttons()[0].pressed.emit()
	await _frames(2)
	_check(fake.requests == 1, "Remind Me asks Android")
	_check(Reminders.enabled, "granted: reminders on")
	_check(UserSettings.new(SETTINGS_PATH).get_value("reminders", "enabled", false) == true, "saved")
	Reminders.turn_off()
	Reminders.now_override = MORNING + 30 * DAY
	_check(not Reminders.offer_if_due(), "never more than two questions")
	Reminders.now_override = MORNING


func _test_planning() -> void:
	var fake := _fresh()
	fake.permitted = true
	Reminders.turn_on(false)
	_check(Reminders.enabled and fake.requests == 0, "permission already given: no Android dialog")
	Reminders.left()
	_check(fake.scheduled == [1, 2, 3, 4], "leaving in the morning plans today, tomorrow, day 3 and day 7 (%s)" % [fake.scheduled])
	_check(fake.cancelled.has(1) and fake.cancelled.has(4), "the old plan is cancelled first")
	_check(Reminders.scheduled[0].open == ReminderPlanner.OPEN_DAILY, "today's reminder opens the Daily Challenge")
	_check(Reminders.scheduled[3].body.contains(str(GameSession.progress.current_level(LevelCatalog.count()))), "come-back text names the next level")
	# Two days away: today's and tomorrow's reminders were shown, not tapped.
	Reminders.now_override = MORNING + 2 * DAY
	fake.cancelled.clear()
	Reminders.returned()
	var settings := UserSettings.new(SETTINGS_PATH)
	_check(int(settings.get_value("reminders", "ignored", 0)) == 2, "shown but not tapped counts as ignored")
	_check(fake.cancelled.size() == ReminderPlanner.SLOT_DAYS.size(), "coming back cancels every reminder")
	_check((settings.get_value("reminders", "sessions", []) as Array).size() == 1, "the play time is remembered")
	# Today's Daily Challenge is done: no reminder for it today.
	GameSession.progress.record_daily(BadgeBook.local_day(Reminders.now_override, 0), 3, true)
	fake.scheduled.clear()
	Reminders.left()
	_check(not fake.scheduled.has(ReminderPlanner.SLOT_TODAY), "no Daily reminder once it is played")
	# Ignoring three in total: weekly only.
	settings.set_value("reminders", "ignored", ReminderPlanner.WEEKLY_AFTER_IGNORED)
	fake.scheduled.clear()
	Reminders.left()
	_check(fake.scheduled == [ReminderPlanner.SLOT_DAY_7], "after ignoring three, only the weekly one")
	# Switching off cancels and plans nothing.
	Reminders.turn_off()
	fake.scheduled.clear()
	Reminders.left()
	_check(fake.scheduled.is_empty() and not Reminders.enabled, "off: nothing planned")
	Reminders.turn_on(false)
	_check(int(UserSettings.new(SETTINGS_PATH).get_value("reminders", "ignored", -1)) == 0, "switching on again starts fresh")
	Reminders.now_override = MORNING
	await _frames(1)


func _test_tap() -> void:
	var fake := _fresh()
	fake.permitted = true
	Reminders.turn_on(false)
	UserSettings.new(SETTINGS_PATH).set_value("reminders", "ignored", 4)
	GameSession.last_requested_scene = ""
	fake.opened.emit(ReminderPlanner.SLOT_TOMORROW)
	await _frames(2)
	_check(GameSession.last_requested_scene == GameSession.DAILY_SCENE, "a Daily reminder opens the calendar")
	_check(int(UserSettings.new(SETTINGS_PATH).get_value("reminders", "ignored", -1)) == 0, "a tap clears the ignored count")
	fake.opened.emit(ReminderPlanner.SLOT_DAY_7)
	await _frames(2)
	_check(GameSession.last_requested_scene == GameSession.JOURNEY_SCENE, "a come-back reminder opens the journey")


func _test_denial() -> void:
	var fake := _fresh(false)
	_check(Reminders.offer_if_due(), "asked")
	_offer_buttons()[0].pressed.emit()
	await _frames(2)
	_check(not Reminders.enabled, "refused on Android: reminders stay off")
	Reminders.now_override = MORNING + 8 * DAY
	_check(not Reminders.offer_if_due(), "after Android's refusal the game stops asking")
	Reminders.now_override = MORNING
	Reminders.turn_on(true)
	Reminders.turn_on(true)
	_check(fake.settings_opened == 1, "after repeated refusals Settings opens the phone's app page")


func _test_settings_switch() -> void:
	var fake := _fresh()
	var panel: AudioSettingsPanel = SETTINGS_SCENE.instantiate()
	add_child(panel)
	panel.open()
	var row := panel.get_node("%RemindersRow") as Control
	var toggle := panel.get_node("%RemindersToggle") as Button
	_check(row.visible, "the switch shows on a phone")
	_check(toggle.text == "Off" and not toggle.button_pressed, "starts off")
	_check(toggle.custom_minimum_size.y >= 120.0, "switch touch target")
	# Every optional row shown (consent regions add Privacy Options): the panel
	# still fits on screen and scrolls instead.
	(panel.get_node("%PrivacyButton") as Control).show()
	panel.call("_fit_height")
	await _frames(3)
	var screen := panel.get_viewport_rect()
	var box := (panel.get_node("Center/Panel") as Control).get_global_rect()
	_check(screen.encloses(box), "the Settings panel fits on screen (%s in %s)" % [box, screen])
	_check((panel.get_node("%Scroll") as ScrollContainer).get_v_scroll_bar().max_value > box.size.y - 200.0, "its rows scroll")
	toggle.button_pressed = true
	await _frames(1)
	_check(fake.requests == 1 and Reminders.enabled and toggle.text == "On", "switching on asks Android and turns on")
	toggle.button_pressed = false
	await _frames(1)
	_check(not Reminders.enabled and toggle.text == "Off", "switching off")
	fake.grant = false
	fake.permitted = false
	toggle.button_pressed = true
	await _frames(1)
	_check(not toggle.button_pressed and toggle.text == "Off", "a refusal puts the switch back")
	panel.queue_free()
	await _frames(1)


func _offer_buttons() -> Array[Button]:
	var found: Array[Button] = []
	for button in Reminders.find_children("*", "Button", true, false):
		if not button.is_queued_for_deletion():
			found.append(button)
	return found


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
