class_name LevelCatalog
extends RefCounted
## The journey's levels: the hand-made ones from data/levels/levels.json,
## then generated ones up to LevelRecipe.TOTAL_LEVELS (built from each
## level's number, so they never change between runs or devices).

const LEVELS_PATH := "res://data/levels/levels.json"
const BACKGROUND_PATTERN := "res://assets/backgrounds/%s.png"


class LevelDefinition extends RefCounted:
	var number: int = 0
	var title: String = ""
	var layout_path: String = ""
	var deal_seed: int = 0
	## Seconds on the clock; the level is lost when it reaches zero.
	var time_limit: int = 300
	## Non-matching pairs the player may pick; the last one loses the level.
	var mistake_limit: int = 3
	## 1 Easy, 2 Medium, 3 Hard, 4 Expert.
	var difficulty: int = 1
	var suits: PackedStringArray = PackedStringArray()
	var background: String = ""

	## Layouts are read once and shared (they are never changed after
	## loading; boards are built from them with build_geometry()).
	func load_layout() -> BoardLayout:
		if not LevelCatalog._layouts.has(layout_path):
			LevelCatalog._layouts[layout_path] = BoardLayout.load_json(layout_path)
		return LevelCatalog._layouts[layout_path]

	## Faces this level deals from: its suits, minus any face whose artwork the
	## active tile collection marks as unverified.
	## Changing a face's verified flag changes the deals of levels using its suit.
	func face_pool(art: TileArtSet = null) -> PackedStringArray:
		if art == null:
			art = TileArtSet.active()
		var pool := PackedStringArray()
		for face in TileCatalog.faces_for_suits(suits):
			if art.is_verified(face):
				pool.append(face)
		return pool

	func background_path() -> String:
		return BACKGROUND_PATTERN % background


static var _levels: Array[LevelDefinition] = []
static var _layouts := {}


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
		level.time_limit = int(entry.get("time_limit", 300))
		level.mistake_limit = int(entry.get("mistakes", 3))
		level.difficulty = int(entry.get("difficulty", 1))
		_levels.append(level)
	# The rest of the journey is generated from each level's number.
	while _levels.size() < LevelRecipe.TOTAL_LEVELS:
		var generated := LevelDefinition.new()
		generated.number = _levels.size() + 1
		LevelRecipe.build(generated)
		_levels.append(generated)
