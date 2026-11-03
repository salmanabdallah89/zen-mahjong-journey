class_name ReminderBridge
extends Node
## The phone's notification system as the Reminders autoload sees it. This
## base does nothing (desktop, web, a phone without the plugin); the Android
## bridge talks to the Notification Scheduler plugin and tests use a fake.

## The answer to request_permission().
signal permission_answered(granted: bool)
## The player tapped the reminder with this id.
signal opened(id: int)
## The plugin finished starting; scheduling and permission calls work now.
signal became_ready


## This device can show reminders at all (the plugin may still be starting).
func is_supported() -> bool:
	return false


## The plugin has started: scheduling and permission calls work.
func is_available() -> bool:
	return false


func has_permission() -> bool:
	return false


func request_permission() -> void:
	pass


func schedule(_reminder: ReminderPlanner.Reminder) -> void:
	pass


func cancel(_id: int) -> void:
	pass


## The system page where the player can allow notifications again.
func open_settings() -> void:
	pass
