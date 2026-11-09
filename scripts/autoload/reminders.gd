extends Node
## Autoload "Reminders": gentle play reminders scheduled on the phone itself
## (docs/NOTIFICATIONS.md). No server and no network.
##
## The player is asked in the game's own words first (offer_if_due, after a few
## clears), and only then by Android. Whenever the game goes to the background
## the next reminders are planned from scratch (ReminderPlanner); when it comes
## back they are all cancelled. A tapped reminder opens the Daily Challenge
## calendar or the journey map. Everywhere without the plugin (desktop, web)
## is_available() is false and nothing happens.

## Reminders were switched on or off (also after the permission answer).
signal changed(enabled: bool)

const SECTION := "reminders"
const DIALOG_SCENE := preload("res://scenes/components/modal_dialog.tscn")
## The soft question is asked at most this often, this many days apart.
const MAX_OFFERS := 2
const OFFER_GAP_DAYS := 7
## The question waits until the player has cleared this many levels (or a
## Daily Challenge).
const OFFER_AFTER_LEVELS := 3
## After this many refusals Android no longer shows its dialog, so turning
## reminders on in Settings opens the app's system page instead.
const DENIALS_BEFORE_SETTINGS := 2
## Seconds a screen settles before the question shows.
const OFFER_DELAY := 1.2

var settings_path := UserSettings.DEFAULT_PATH
var enabled := false
## Tests set the local clock: unix seconds and time-zone bias in minutes.
var now_override := -1
var bias_override := 0
## Reminders handed to the phone, newest plan (tests read it).
var scheduled: Array[ReminderPlanner.Reminder] = []

var _bridge: ReminderBridge
var _dialog: ModalDialog
## The question came from Settings (a refusal there may open system settings).
var _asked_from_settings := false
## Android's permission dialog is open. Its answer comes from the plugin, and
## the game also reads the permission itself when it comes back to the front,
## in case that answer never arrives (seen on a phone: allowed, but the switch
## stayed off). Whichever comes first settles it; the other is ignored.
var _awaiting_permission := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	_dialog = DIALOG_SCENE.instantiate()
	_dialog.hide()
	layer.add_child(_dialog)
	restore()
	use_bridge(AndroidReminderBridge.new() if AndroidReminderBridge.can_run() else ReminderBridge.new())
	returned()


func restore() -> void:
	enabled = bool(_settings().get_value(SECTION, "enabled", false))


## Connects the phone side (the Android plugin, or a test fake).
func use_bridge(bridge: ReminderBridge) -> void:
	if _bridge != null:
		_bridge.queue_free()
	_bridge = bridge
	_awaiting_permission = false
	add_child(bridge)
	bridge.permission_answered.connect(_on_permission_answered)
	bridge.opened.connect(_on_opened)
	bridge.became_ready.connect(_cancel_all)


func is_available() -> bool:
	return _bridge != null and _bridge.is_available()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		left()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		returned()


## The game went to the background: plan and schedule the next reminders.
func left() -> void:
	_cancel_all()
	if not enabled or not is_available() or not _bridge.has_permission():
		return
	var settings := _settings()
	var state := ReminderPlanner.State.new()
	state.now_local = _now() + _bias() * 60
	var today := BadgeBook.local_day(_now(), _bias())
	var progress := GameSession.progress
	state.daily_done_today = progress.daily_stars(today) > 0
	state.streak = progress.daily_streak(today)
	state.next_level = progress.current_level(LevelCatalog.count())
	state.usual_minute = ReminderPlanner.usual_minute(settings.get_value(SECTION, "sessions", []))
	state.ignored = int(settings.get_value(SECTION, "ignored", 0))
	var pending := []
	for reminder in ReminderPlanner.plan(state):
		_bridge.schedule(reminder)
		scheduled.append(reminder)
		pending.append(_now() + reminder.delay)
	settings.set_value(SECTION, "pending", pending)


## The game opened or came back: reminders that were shown in the meantime
## count as ignored (a tap clears that in _on_opened), and nothing stays queued.
func returned() -> void:
	# Desktop and web keep no reminder state (and tests' saves stay untouched).
	if _bridge == null or not _bridge.is_supported():
		return
	var settings := _settings()
	var shown := 0
	for fire_time: int in settings.get_value(SECTION, "pending", []):
		if fire_time <= _now():
			shown += 1
	var ignored := ReminderPlanner.ignored_after_open(int(settings.get_value(SECTION, "ignored", 0)), shown, false)
	settings.set_value(SECTION, "ignored", ignored)
	settings.set_value(SECTION, "pending", [])
	var sessions: Array = settings.get_value(SECTION, "sessions", [])
	var local := _now() + _bias() * 60
	sessions.append(posmod(local, 86400) / 60)
	settings.set_value(SECTION, "sessions", sessions.slice(-ReminderPlanner.SESSIONS_KEPT))
	_cancel_all()
	if _awaiting_permission:
		_on_permission_answered(_bridge.has_permission())


func _cancel_all() -> void:
	scheduled.clear()
	if _bridge == null:
		return
	for id: int in ReminderPlanner.SLOT_DAYS:
		_bridge.cancel(id)


## Asks the soft question when it is due: reminders available but off, the
## player has played a little, and the question was not asked too often or
## too recently. Returns true when the question is showing.
func offer_if_due() -> bool:
	if enabled or not is_available() or _dialog.visible:
		return false
	var settings := _settings()
	var offers := int(settings.get_value(SECTION, "offers", 0))
	var today := BadgeBook.local_day(_now(), _bias())
	if offers >= MAX_OFFERS or bool(settings.get_value(SECTION, "declined_system", false)):
		return false
	if offers > 0 and today - int(settings.get_value(SECTION, "last_offer_day", 0)) < OFFER_GAP_DAYS:
		return false
	var progress := GameSession.progress
	if not progress.is_cleared(OFFER_AFTER_LEVELS) and progress.daily_total() == 0:
		return false
	settings.set_value(SECTION, "offers", offers + 1)
	settings.set_value(SECTION, "last_offer_day", today)
	_dialog.open("Gentle Reminders", "Want a calm nudge when a new Daily Challenge is ready? At most one a day, and you can turn it off in Settings.")
	_dialog.add_action("Remind Me", func() -> void: turn_on(false), true)
	_dialog.add_action("Not Now", func() -> void: pass)
	return true


## Offers after the screen has settled, unless a level is open by then.
func offer_later(tree: SceneTree) -> void:
	tree.create_timer(OFFER_DELAY).timeout.connect(func() -> void:
		var scene := tree.current_scene
		if scene != null and scene.scene_file_path != GameSession.GAME_SCENE:
			offer_if_due())


func is_offer_open() -> bool:
	return _dialog.visible


## Closes the question as "Not Now" (Android back).
func close_offer() -> void:
	_dialog.close()


## Switches reminders on, asking Android for permission when needed.
func turn_on(from_settings: bool) -> void:
	_asked_from_settings = from_settings
	if not is_available():
		return
	if _bridge.has_permission():
		_set_enabled(true)
	else:
		_awaiting_permission = true
		_bridge.request_permission()


func turn_off() -> void:
	_set_enabled(false)


func _set_enabled(value: bool) -> void:
	var settings := _settings()
	enabled = value
	settings.set_value(SECTION, "enabled", value)
	if value:
		# A fresh start: earlier ignored reminders no longer hold them back.
		settings.set_value(SECTION, "ignored", 0)
	else:
		_cancel_all()
		settings.set_value(SECTION, "pending", [])
	changed.emit(enabled)


func _on_permission_answered(granted: bool) -> void:
	if not _awaiting_permission:
		return
	_awaiting_permission = false
	if granted:
		_set_enabled(true)
		return
	var settings := _settings()
	var denials := int(settings.get_value(SECTION, "denials", 0)) + 1
	settings.set_value(SECTION, "denials", denials)
	# A refusal of Android's own dialog ends the soft questions.
	settings.set_value(SECTION, "declined_system", true)
	if _asked_from_settings and denials > DENIALS_BEFORE_SETTINGS:
		_bridge.open_settings()
	enabled = false
	settings.set_value(SECTION, "enabled", false)
	changed.emit(false)


## A tapped reminder: the player came back because of it. It opens its screen
## unless a level is being played.
func _on_opened(id: int) -> void:
	_settings().set_value(SECTION, "ignored", 0)
	_route.call_deferred(ReminderPlanner.open_for(id))


func _route(open: String) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == GameSession.GAME_SCENE:
		return
	if open == ReminderPlanner.OPEN_DAILY:
		GameSession.go_daily()
	else:
		GameSession.go_levels()


func _settings() -> UserSettings:
	return UserSettings.new(settings_path)


func _now() -> int:
	return now_override if now_override >= 0 else int(Time.get_unix_time_from_system())


func _bias() -> int:
	return bias_override if now_override >= 0 else int(Time.get_time_zone_from_system().get("bias", 0))
