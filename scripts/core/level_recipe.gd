class_name LevelRecipe
extends RefCounted
## Builds the levels after the hand-made ones (data/levels/levels.json), up to
## TOTAL_LEVELS, from the level number alone. Same number, same level, always:
## only a RandomNumberGenerator seeded from the number is used, and each deal
## is still made by BoardGenerator, which verifies it can be cleared.
##
## Chapters of CHAPTER_SIZE levels cycle through the four gardens. Within a
## chapter difficulty rises in waves and ends on a "summit" (hard or expert);
## later chapters slowly lift easy levels to medium and some medium to hard.
## Layout size follows difficulty; the time limit follows the tile count
## (calibrated on the hand-made levels) and tightens a little in later
## chapters; hearts are 5 / 4 / 3 / 3 for easy / medium / hard / expert.

const TOTAL_LEVELS := 1000
const CHAPTER_SIZE := 20
const GARDENS: PackedStringArray = ["bg_golden_sakura", "bg_bamboo_forest", "bg_misty_temple", "bg_moonlight_sanctuary"]

## Difficulty by position in a chapter (1 easy .. 4 expert).
const WAVE: Array[int] = [1, 1, 2, 1, 2, 2, 3, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 2, 3, 4]
## Layouts by size, smallest first, for each difficulty.
const LAYOUTS := {
	1: ["lotus_pond", "stepping_stones", "bamboo_grove"],
	2: ["quiet_path", "pagoda", "mountain_shrine"],
	3: ["koi_garden", "evening_lanterns"],
	4: ["moon_bridge", "temple_summit"],
}
const SUITS := {
	1: ["bamboo", "dots", "characters", "dragons", "flowers"],
	2: ["bamboo", "dots", "characters", "dragons", "flowers", "seasons"],
	3: ["bamboo", "dots", "characters", "dragons", "flowers", "seasons", "winds"],
	4: ["bamboo", "dots", "characters", "dragons", "flowers", "seasons", "winds"],
}
## Seconds per tile by difficulty, plus a fixed allowance.
const SECONDS_PER_TILE := {1: 6.5, 2: 5.6, 3: 4.8, 4: 4.2}
const SECONDS_BASE := 30.0
const HEARTS := {1: 5, 2: 4, 3: 3, 4: 3}

## Place names per garden: first word + second word.
const NAMES := {
	"bg_golden_sakura": [["Blossom", "Petal", "Lantern", "Koi", "Plum", "Spring", "Dawn", "Silk"],
		["Path", "Bridge", "Pond", "Gate", "Steps", "Grove", "Terrace", "Pavilion"]],
	"bg_bamboo_forest": [["Bamboo", "Whisper", "Green", "Mossy", "Rustling", "Jade", "Wind", "Shade"],
		["Grove", "Trail", "Hollow", "Stream", "Glade", "Steps", "Gate", "Thicket"]],
	"bg_misty_temple": [["Misty", "Cloud", "Temple", "Silent", "Mountain", "Bell", "Incense", "Stone"],
		["Shrine", "Peak", "Stairs", "Hall", "Ridge", "Garden", "Falls", "Court"]],
	"bg_moonlight_sanctuary": [["Moonlit", "Silver", "Night", "Star", "Evening", "Owl", "Firefly", "Quiet"],
		["Lake", "Bridge", "Sanctuary", "Pool", "Lantern", "Pagoda", "Garden", "Path"]],
}

static var _tile_counts := {}


## Chapter (0-based) of level `number`.
static func chapter_of(number: int) -> int:
	return floori((number - 1) / float(CHAPTER_SIZE))


## The garden a chapter belongs to (its journey-map backdrop).
static func garden_of_chapter(chapter: int) -> String:
	return GARDENS[chapter % GARDENS.size()]


static func difficulty_of(number: int) -> int:
	var chapter := chapter_of(number)
	var position := (number - 1) % CHAPTER_SIZE
	var difficulty: int = WAVE[position]
	# Later chapters: easy levels become medium (each chapter still opens
	# easy), then some medium levels become hard.
	if chapter >= 5 and difficulty == 1 and position != 0:
		difficulty = 2
	if chapter >= 20 and difficulty == 2 and position % 2 == 1:
		difficulty = 3
	return difficulty


## Fills `level` (whose number is set) with its generated content.
static func build(level: LevelCatalog.LevelDefinition) -> void:
	var number := level.number
	var rng := RandomNumberGenerator.new()
	rng.seed = number * 2654435761 % 4294967296
	var chapter := chapter_of(number)
	var difficulty := difficulty_of(number)
	var garden := garden_of_chapter(chapter)
	var choices: Array = LAYOUTS[difficulty]
	# Later chapters lean toward the larger layouts of each size.
	var lean := clampf(chapter / 30.0, 0.0, 1.0)
	var index := clampi(int(rng.randf() * choices.size() * (1.0 - lean * 0.5) + lean * 0.5 * choices.size()), 0, choices.size() - 1)
	var layout_id: String = choices[index]
	level.layout_path = "res://data/layouts/%s.json" % layout_id
	level.deal_seed = 100000 + number * 7919
	level.suits = PackedStringArray(SUITS[difficulty])
	level.background = garden
	level.difficulty = difficulty
	level.mistake_limit = HEARTS[difficulty]
	var tightening := 1.0 - minf(chapter, 40.0) * 0.004
	var seconds := (tile_count(layout_id) * float(SECONDS_PER_TILE[difficulty]) + SECONDS_BASE) * tightening
	level.time_limit = maxi(int(roundf(seconds / 15.0)) * 15, 150)
	var words: Array = NAMES[garden]
	level.title = "%s %s" % [words[0][rng.randi() % words[0].size()], words[1][rng.randi() % words[1].size()]]


static func tile_count(layout_id: String) -> int:
	if not _tile_counts.has(layout_id):
		_tile_counts[layout_id] = BoardLayout.load_json("res://data/layouts/%s.json" % layout_id).tile_count()
	return _tile_counts[layout_id]
