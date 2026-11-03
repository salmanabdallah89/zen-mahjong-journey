@tool
extends EditorPlugin
## Android export step: strips permissions that plugins declare but Google Play
## restricts for a game. The Notification Scheduler plugin asks for exact alarms
## and a battery-optimisation exemption; without them it schedules inexact
## reminders, which is all play reminders need (docs/NOTIFICATIONS.md).

var _export_plugin: StripPermissions


func _enter_tree() -> void:
	_export_plugin = StripPermissions.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class StripPermissions extends EditorExportPlugin:
	const REMOVED: PackedStringArray = [
		"android.permission.SCHEDULE_EXACT_ALARM",
		"android.permission.USE_EXACT_ALARM",
		"android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
	]


	func _get_name() -> String:
		return "ZenAndroidManifest"


	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid


	## The Gradle manifest merger drops each permission marked tools:node="remove",
	## whichever library declared it.
	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		var contents := ""
		for permission in REMOVED:
			contents += "\n    <uses-permission android:name=\"%s\" tools:node=\"remove\" />" % permission
		return contents + "\n"
