class_name UserSettings
extends RefCounted
## Player preferences stored in a ConfigFile (user://settings.cfg by default).

const DEFAULT_PATH := "user://settings.cfg"

var path: String
var _config := ConfigFile.new()


func _init(p_path := DEFAULT_PATH) -> void:
	path = p_path
	# A missing file just means defaults.
	_config.load(path)


func get_value(section: String, key: String, default: Variant = null) -> Variant:
	return _config.get_value(section, key, default)


func set_value(section: String, key: String, value: Variant) -> Error:
	_config.set_value(section, key, value)
	return _config.save(path)
