class_name SafeConfig
extends RefCounted
## Crash-safe ConfigFile saving for player data (progress, settings).
##
## Saving writes `<path>.tmp` first and only then swaps it in, keeping the
## previous good file as `<path>.bak`. If the app is killed mid-save, or the
## main file is damaged, loading falls back to the backup instead of starting
## the player over. A damaged file is kept as `<path>.damaged` and never
## silently overwritten.

const TEMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"
const DAMAGED_SUFFIX := ".damaged"


## Loads `path` into `config`, falling back to the backup. Returns OK, or
## ERR_FILE_NOT_FOUND for a first launch (config stays empty either way).
static func load_into(config: ConfigFile, path: String) -> Error:
	config.clear()
	if FileAccess.file_exists(path):
		if config.load(path) == OK:
			return OK
		push_warning("SafeConfig: %s is damaged; trying the backup" % path)
		config.clear()
		_copy(path, path + DAMAGED_SUFFIX)
	# Killed between swapping steps: the finished new save is still in temp.
	var temp := path + TEMP_SUFFIX
	if FileAccess.file_exists(temp):
		if config.load(temp) == OK:
			return OK
		config.clear()
	var backup := path + BACKUP_SUFFIX
	if FileAccess.file_exists(backup):
		if config.load(backup) == OK:
			return OK
		config.clear()
	return ERR_FILE_NOT_FOUND


static func save(config: ConfigFile, path: String) -> Error:
	var temp := path + TEMP_SUFFIX
	var err := config.save(temp)
	if err != OK:
		push_error("SafeConfig: could not write %s (%s)" % [temp, error_string(err)])
		return err
	# Keep the last good save as the backup, then swap the new file in.
	if FileAccess.file_exists(path):
		var check := ConfigFile.new()
		if check.load(path) == OK:
			_replace(path, path + BACKUP_SUFFIX)
	err = _replace(temp, path)
	if err != OK:
		# A file system without rename support: save in place rather than lose it.
		push_warning("SafeConfig: could not swap in %s (%s); saving in place" % [path, error_string(err)])
		err = config.save(path)
	return err


## Removes the file and its temp/backup/damaged siblings (tests, reset).
static func remove_all(path: String) -> void:
	for suffix in ["", TEMP_SUFFIX, BACKUP_SUFFIX, DAMAGED_SUFFIX]:
		var file: String = path + suffix
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))


static func _replace(from: String, to: String) -> Error:
	var global_to := ProjectSettings.globalize_path(to)
	if FileAccess.file_exists(to):
		DirAccess.remove_absolute(global_to)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(from), global_to)


static func _copy(from: String, to: String) -> void:
	DirAccess.copy_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))
