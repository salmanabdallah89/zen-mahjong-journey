extends Node
## Autoload "Motion": the player's "Reduced animations" preference, saved in
## user settings (section "display"). Animations ask `Motion.reduced` and play
## a short fade instead of travel, bounce, pulses or drifting backgrounds.
##
## With no saved choice, the web build follows the browser's
## prefers-reduced-motion setting. Android's system "Remove animations"
## option is not readable from Godot without a plugin, so phones default to
## full motion until the player switches it in Settings.

signal changed(reduced: bool)

const SETTINGS_SECTION := "display"
const KEY := "reduced_motion"

var settings_path := UserSettings.DEFAULT_PATH
var reduced := false


func _ready() -> void:
	restore()


func restore() -> void:
	var settings := UserSettings.new(settings_path)
	var system_default: bool = _system_prefers_reduced()
	reduced = bool(settings.get_value(SETTINGS_SECTION, KEY, system_default))


func set_reduced(value: bool) -> void:
	if value == reduced:
		return
	reduced = value
	UserSettings.new(settings_path).set_value(SETTINGS_SECTION, KEY, reduced)
	changed.emit(reduced)


## `seconds` normally, or a short fade time when motion is reduced.
func duration(seconds: float) -> float:
	return minf(seconds, 0.12) if reduced else seconds


func _system_prefers_reduced() -> bool:
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		# Ask for a number: the bridge returns null for some JavaScript booleans.
		var answer: Variant = JavaScriptBridge.eval(
			"(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) ? 1 : 0", true)
		return typeof(answer) in [TYPE_INT, TYPE_FLOAT] and int(answer) == 1
	return false
