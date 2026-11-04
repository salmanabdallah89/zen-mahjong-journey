@tool
extends EditorPlugin
## Adds the in-app update plugin (bin/zen_play_update.aar, built from
## android_plugins/play_update by its build.sh) and Google's app-update
## library to Android exports.

var _export_plugin: PlayUpdateExport


func _enter_tree() -> void:
	_export_plugin = PlayUpdateExport.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class PlayUpdateExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "ZenPlayUpdate"


	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid


	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["zen_play_update/bin/zen_play_update.aar"])


	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["com.google.android.play:app-update:2.1.0"])
