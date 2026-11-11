@tool
extends EditorPlugin
## Android export step: strips permissions that plugins declare but Google Play
## restricts for a game. The Notification Scheduler plugin asks for exact alarms
## and a battery-optimisation exemption; without them it schedules inexact
## reminders, which is all play reminders need (docs/NOTIFICATIONS.md).
##
## It also gives Android's launch screen a sharp icon on every screen density.
## Godot writes the preset's splash_screen/icon to res/drawable/, which Android
## treats as mdpi and enlarges in memory up to 4x on modern phones. A copy in
## drawable-xxxhdpi is picked first by every denser screen and only ever
## scaled down to the 288 dp it is shown at.

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
	## The launch-screen icon (1152 px = 288 dp at xxxhdpi), made by
	## tools/make_splash_icon.gd; the same file the export preset names.
	const SPLASH_ICON := "res://assets/branding/splash_icon_1152.png"
	const SPLASH_TARGET := "res://android/build/res/drawable-xxxhdpi/splash_icon.png"


	func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		if not _supports_platform(get_export_platform()):
			return
		var data := FileAccess.get_file_as_bytes(SPLASH_ICON)
		if data.is_empty():
			push_error("ZenAndroidManifest: %s missing, the launch screen icon will be blurry" % SPLASH_ICON)
			return
		DirAccess.make_dir_recursive_absolute(SPLASH_TARGET.get_base_dir())
		var file := FileAccess.open(SPLASH_TARGET, FileAccess.WRITE)
		if file == null:
			push_error("ZenAndroidManifest: cannot write %s" % SPLASH_TARGET)
			return
		file.store_buffer(data)


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
