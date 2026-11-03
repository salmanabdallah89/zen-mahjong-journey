class_name AndroidReminderBridge
extends ReminderBridge
## Reminders through the Notification Scheduler plugin
## (addons/NotificationSchedulerPlugin). Exact alarms are stripped from the
## manifest (addons/zen_android_manifest), so the plugin schedules inexact
## alarms; it reschedules them itself after a reboot.

const CHANNEL_ID := "gentle_reminders"
const ICON := "ic_zen_notification"

var _scheduler: NotificationScheduler
var _ready_to_use := false


static func can_run() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton(NotificationScheduler.PLUGIN_SINGLETON_NAME)


func _ready() -> void:
	_scheduler = NotificationScheduler.new()
	add_child(_scheduler)
	_scheduler.initialization_completed.connect(_on_initialized)
	_scheduler.post_notifications_permission_granted.connect(func(_permission: String) -> void:
		permission_answered.emit(true))
	_scheduler.post_notifications_permission_denied.connect(func(_permission: String) -> void:
		permission_answered.emit(false))
	_scheduler.notification_opened.connect(func(data: NotificationData) -> void:
		opened.emit(data.get_id()))
	_scheduler.initialize()


func _on_initialized() -> void:
	_ready_to_use = true
	var channel := NotificationChannel.new() \
		.set_id(CHANNEL_ID) \
		.set_name("Gentle reminders") \
		.set_description("Daily Challenge and journey reminders") \
		.set_importance(NotificationChannel.Importance.DEFAULT) \
		.set_badge_enabled(false)
	# ERR_ALREADY_EXISTS after the first launch is expected.
	_scheduler.create_notification_channel(channel)
	became_ready.emit()


func is_supported() -> bool:
	return true


func is_available() -> bool:
	return _ready_to_use


func has_permission() -> bool:
	return _ready_to_use and _scheduler.has_post_notifications_permission()


func request_permission() -> void:
	if not _ready_to_use:
		permission_answered.emit(false)
		return
	if _scheduler.has_post_notifications_permission():
		permission_answered.emit(true)
		return
	_scheduler.request_post_notifications_permission()


func schedule(reminder: ReminderPlanner.Reminder) -> void:
	if not _ready_to_use:
		return
	var data := NotificationData.new() \
		.set_id(reminder.id) \
		.set_channel_id(CHANNEL_ID) \
		.set_title(reminder.title) \
		.set_content(reminder.body) \
		.set_small_icon_name(ICON) \
		.set_delay(reminder.delay)
	_scheduler.schedule(data)


func cancel(id: int) -> void:
	if _ready_to_use:
		_scheduler.cancel(id)


func open_settings() -> void:
	if _ready_to_use:
		_scheduler.open_app_info_settings()
