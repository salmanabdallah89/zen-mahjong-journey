@tool
extends EditorPlugin
## Adds the billing plugin (bin/zen_play_billing.aar, built from
## android_plugins/play_billing by its build.sh) and Google's Play Billing
## library to Android exports. The library also adds Play's BILLING permission.

const AAR := "zen_play_billing/bin/zen_play_billing.aar"
const BILLING_LIBRARY := "com.android.billingclient:billing:8.0.0"

var _export_plugin: PlayBillingExport


func _enter_tree() -> void:
	_export_plugin = PlayBillingExport.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class PlayBillingExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "ZenPlayBilling"


	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid


	# Before the first build.sh run there is no AAR yet; the library alone is
	# still fetched into the Gradle cache, which build.sh compiles against.
	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([AAR]) if FileAccess.file_exists("res://addons/" + AAR) else PackedStringArray()


	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([BILLING_LIBRARY])
