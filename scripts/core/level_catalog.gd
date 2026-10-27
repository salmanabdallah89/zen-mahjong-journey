class_name LevelCatalog
extends RefCounted
## Loads level definitions from data/levels/levels.json.

const LEVELS_PATH := "res://data/levels/levels.json"
const BACKGROUND_PATTERN := "res://assets/backgrounds/%s.png"


class LevelDefinition extends RefCounted:
	var number: int = 0
	var title: String = ""
	var layout_path: String = ""
	var deal_seed: int = 0
	var suits: PackedStringArray = PackedStringArray()
	var background: String = ""

	func load_layout() -> BoardLayout:
		return BoardLayout.load_json(layout_path)

	func face_pool() -> PackedStringArray:
		return TileCatalog.faces_for_suits(suits)

	func background_path() -> String:
		return BACKGROUND_PATTERN % background


static var _levels: Array[LevelDefinition] = []


static func levels() -> Array[LevelDefinition]:
	if _levels.is_empty():
		_load()
	return _levels


static func count() -> int:
	return levels().size()


## Returns the level with the given 1-based number, or null.
static func get_level(number: int) -> LevelDefinition:
	var all := levels()
	if number < 1 or number > all.size():
		return null
	return all[number - 1]


static func _load() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_PATH))
	if not data is Dictionary:
		push_error("LevelCatalog: cannot parse %s" % LEVELS_PATH)
		return
	for entry: Dictionary in (data as Dictionary).get("levels", []):
		var level := LevelDefinition.new()
		level.number = _levels.size() + 1
		level.title = str(entry.get("title", "Level %d" % level.number))
		level.layout_path = "res://data/layouts/%s.json" % str(entry.get("layout", ""))
		level.deal_seed = int(entry.get("seed", level.number))
		level.suits = PackedStringArray(entry.get("suits", []))
		level.background = str(entry.get("background", "bg_golden_sakura"))
		_levels.append(level)
