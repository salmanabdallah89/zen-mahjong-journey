class_name WordCatalog
extends RefCounted
## Word Garden's content: languages, words (data/words/words.json, in teaching
## order) and which words each stage uses. Every stage brings new words and
## brings back ones to practise. A stage's new words depend only on its
## number; its review words also on what the player mixed up.

const WORDS_PATH := "res://data/words/words.json"
## Longest line a tile can show large enough to read.
const MAX_LETTERS := 11
const FIRST_STAGE_WORDS := 12
const NEW_WORDS_PER_STAGE := 8
## Stages from here on use the larger board.
const LARGE_STAGE := 8
const SMALL_LAYOUT := "lotus_pond"
const LARGE_LAYOUT := "stepping_stones"
const SEED_BASE := 7300
## Mistakes allowed for 3 and for 2 stars.
const THREE_STAR_MISTAKES := 0
const TWO_STAR_MISTAKES := 2

static var _languages: Array = []
static var _words := {}
static var _order := PackedStringArray()


static func languages() -> Array:
	_load()
	return _languages


static func word_ids() -> PackedStringArray:
	_load()
	return _order


## Stages follow from the word list: the first stage, then the new words of
## each later one.
static func stage_count() -> int:
	return 1 + ceili(float(word_ids().size() - FIRST_STAGE_WORDS) / NEW_WORDS_PER_STAGE)


## `text` as drawn on a tile: on two lines, broken as evenly as possible at a
## space or hyphen, when it has either.
static func tile_text(text: String) -> String:
	var best := -1
	for i in text.length():
		if text[i] in [" ", "-"] and (best < 0 or absi(i * 2 - text.length()) < absi(best * 2 - text.length())):
			best = i
	if best < 0:
		return text
	var first := text.left(best + 1).strip_edges()
	return first + "\n" + text.substr(best + 1).strip_edges()


static func text(word_id: String, language: String) -> String:
	_load()
	return str(_words[word_id][language])


static func has_picture(word_id: String) -> bool:
	_load()
	return _words[word_id].has("image")


## The picture of a word, framed without the caption some collection PNGs carry.
static func picture(word_id: String, loader: Callable) -> Texture2D:
	_load()
	var word: Dictionary = _words[word_id]
	var texture: Texture2D = loader.call(str(word.image))
	if texture == null or not word.has("region"):
		return texture
	var framed := AtlasTexture.new()
	framed.atlas = texture
	framed.region = Rect2(word.region[0], word.region[1], word.region[2], word.region[3])
	return framed


static func word_count(stage: int) -> int:
	return BoardLayout.load_json(_layout_path(stage)).tile_count() / 2


## The stage's new words, then review: `review` words first, then earlier ones.
static func stage_words(stage: int, review := PackedStringArray()) -> PackedStringArray:
	_load()
	var seen := FIRST_STAGE_WORDS + (stage - 2) * NEW_WORDS_PER_STAGE
	var first_new := 0 if stage == 1 else mini(seen, _order.size())
	var new_count := FIRST_STAGE_WORDS if stage == 1 else NEW_WORDS_PER_STAGE
	var result := _order.slice(first_new, mini(first_new + new_count, _order.size()))
	var wanted := word_count(stage)
	for word_id in review:
		if result.size() < wanted and _words.has(word_id) and _fits(word_id, result):
			result.append(word_id)
	# Older words, most recent first, so yesterday's words come back soonest.
	var index := first_new - 1
	while result.size() < wanted and index >= 0:
		if _fits(_order[index], result):
			result.append(_order[index])
		index -= 1
	return result


## A board never holds a word twice, nor two words spelled alike in a language
## ("Mañana" is both morning and tomorrow).
static func _fits(word_id: String, chosen: PackedStringArray) -> bool:
	if chosen.has(word_id):
		return false
	for other in chosen:
		for language: Dictionary in _languages:
			if text(word_id, str(language.id)) == text(other, str(language.id)):
				return false
	return true


static func level_for(stage: int) -> LevelCatalog.LevelDefinition:
	var level := LevelCatalog.LevelDefinition.new()
	level.title = "Word Garden"
	level.layout_path = _layout_path(stage)
	level.deal_seed = SEED_BASE + stage
	level.time_limit = 0
	level.mistake_limit = 0
	level.background = LevelRecipe.garden_of_chapter((stage - 1) / LevelRecipe.CHAPTER_SIZE)
	return level


static func faces_for(words: PackedStringArray) -> PackedStringArray:
	var faces := PackedStringArray()
	for word_id in words:
		faces.append("%s_%s_p" % [TileCatalog.WORD_SUIT, word_id])
		faces.append("%s_%s_w" % [TileCatalog.WORD_SUIT, word_id])
	return faces


static func id_of(face_id: String) -> String:
	return face_id.trim_prefix(TileCatalog.WORD_SUIT + "_").left(-2)


static func is_picture(face_id: String) -> bool:
	return face_id.ends_with("_p")


static func stars(mistakes: int) -> int:
	if mistakes <= THREE_STAR_MISTAKES:
		return 3
	return 2 if mistakes <= TWO_STAR_MISTAKES else 1


static func _layout_path(stage: int) -> String:
	return "res://data/layouts/%s.json" % (LARGE_LAYOUT if stage >= LARGE_STAGE else SMALL_LAYOUT)


static func _load() -> void:
	if not _order.is_empty():
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORDS_PATH))
	if not data is Dictionary:
		push_error("WordCatalog: cannot parse %s" % WORDS_PATH)
		return
	_languages = data.languages
	for word: Dictionary in data.words:
		_words[str(word.id)] = word
		_order.append(str(word.id))
