class_name PlayUpdateBridge
extends RefCounted
## Google Play In-App Updates as the update notice sees it. Wraps the
## ZenPlayUpdate Android plugin (addons/zen_play_update, source in
## android_plugins/play_update) or a test stand-in with the same method and
## signal names. Play decides whether this player has an update (their track,
## their installed version), so no file has to be kept in step.
##
## Works only for an install that came from Google Play; anywhere else
## is_available() is false and the notice falls back to site/version.json.

## Play's answer: an update exists, which flows it allows, its version code
## and how many days ago Play first offered it (-1 unknown).
signal checked(available: bool, flexible: bool, immediate: bool, version_code: int, staleness_days: int)
signal check_failed(message: String)
## Download/install progress of a flexible update (Play's InstallStatus).
signal status_changed(status: int, downloaded: int, total: int)
## Play's update screen closed: accepted or not.
signal flow_finished(accepted: bool)

const PLUGIN_NAME := "ZenPlayUpdate"
## Play's InstallStatus values.
const PENDING := 1
const DOWNLOADING := 2
const INSTALLING := 3
const INSTALLED := 4
const FAILED := 5
const CANCELED := 6
const DOWNLOADED := 11
## Activity.RESULT_OK.
const RESULT_OK := -1

var _plugin: Object


static func from_engine() -> PlayUpdateBridge:
	var bridge := PlayUpdateBridge.new()
	if OS.get_name() == "Android" and Engine.has_singleton(PLUGIN_NAME):
		bridge.use_plugin(Engine.get_singleton(PLUGIN_NAME))
	return bridge


func use_plugin(plugin: Object) -> void:
	_plugin = plugin
	if plugin == null:
		return
	plugin.connect("update_checked", func(available: bool, flexible: bool, immediate: bool, code: int, days: int) -> void:
		checked.emit(available, flexible, immediate, code, days))
	plugin.connect("check_failed", func(message: String) -> void: check_failed.emit(message))
	plugin.connect("install_status", func(status: int, done: int, total: int) -> void:
		status_changed.emit(status, done, total))
	plugin.connect("flow_result", func(result: int) -> void: flow_finished.emit(result == RESULT_OK))


func is_available() -> bool:
	return _plugin != null


func check() -> void:
	if _plugin != null:
		_plugin.call("checkForUpdate")


## Opens Play's update screen; false if Play would not allow that flow.
func start(immediate: bool) -> bool:
	return _plugin != null and bool(_plugin.call("startUpdate", immediate))


## Installs a downloaded update; Play closes and restarts the game.
func complete() -> void:
	if _plugin != null:
		_plugin.call("completeUpdate")
