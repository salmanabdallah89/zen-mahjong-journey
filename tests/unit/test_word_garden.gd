extends TestCase
## Word Garden content and rules: words, stages, picture-word matching.

const FONT := preload("res://assets/fonts/Fraunces.ttf")
const ARABIC := preload("res://assets/fonts/NotoNaskhArabic.ttf")


func test_words_fit_tiles_and_the_fonts_have_them() -> void:
	for language: Dictionary in WordCatalog.languages():
		var font: Font = ARABIC if str(language.id) == "ar" else FONT
		for word_id in WordCatalog.word_ids():
			var text := WordCatalog.text(word_id, str(language.id))
			assert_true(not text.is_empty(), "%s has text" % word_id)
			for line in WordCatalog.tile_text(text).split("\n"):
				assert_true(line.length() <= WordCatalog.MAX_LETTERS, "%s fits a tile" % text)
			for i in text.length():
				assert_true(font.has_char(text.unicode_at(i)) or text[i] == " ", "the font can draw %s" % text)


func test_at_least_a_thousand_words_and_no_lookalikes_on_a_board() -> void:
	assert_true(WordCatalog.word_ids().size() >= 1000, "1000 words (%d)" % WordCatalog.word_ids().size())
	for stage in range(1, WordCatalog.stage_count() + 1):
		var words := WordCatalog.stage_words(stage)
		for language: Dictionary in WordCatalog.languages():
			var seen := {}
			for word_id in words:
				seen[WordCatalog.text(word_id, str(language.id))] = true
			assert_eq(seen.size(), words.size(), "stage %d: no two %s words are spelled alike" % [stage, language.id])


func test_words_without_pictures_pair_with_their_translation() -> void:
	var skin := WordSkin.new()
	skin.set_languages("es", "ar")
	assert_eq(skin.word_text("word_because_w"), "Porque", "the word to learn")
	assert_eq(skin.word_text("word_because_p"), "لأن", "its meaning")
	assert_eq(skin.word_text("word_cat_p"), "", "a picture word keeps its picture")
	assert_eq(WordCatalog.tile_text("Pomme de terre"), "Pomme de\nterre", "two lines")


func test_pictures_exist_and_are_not_held_back() -> void:
	for word_id in WordCatalog.word_ids():
		if WordCatalog.has_picture(word_id):
			assert_true(WordCatalog.picture(word_id, func(path: String) -> Texture2D: return load(path) if ResourceLoader.exists(path) else null) != null,
				"%s has a picture" % word_id)
	var words := FileAccess.get_file_as_string(WordCatalog.WORDS_PATH)
	for collection in ["fruits", "vegetables"]:
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/collections/%s.json" % collection))
		for held: String in manifest.held_back_symbols:
			assert_true(not words.contains('_%s.png"' % held), "%s is held back" % held)


func test_every_stage_fills_its_board_and_every_word_is_taught() -> void:
	var taught := {}
	for stage in range(1, WordCatalog.stage_count() + 1):
		var words := WordCatalog.stage_words(stage)
		assert_eq(words.size(), WordCatalog.word_count(stage), "stage %d fills its board" % stage)
		var unique := {}
		for word_id in words:
			unique[word_id] = true
			taught[word_id] = true
		assert_eq(unique.size(), words.size(), "stage %d has no repeats" % stage)
	assert_eq(taught.size(), WordCatalog.word_ids().size(), "every word is taught")


func test_review_words_come_back() -> void:
	var stage_two := WordCatalog.stage_words(2, PackedStringArray(["cat"]))
	assert_true(stage_two.has("cat"), "a missed word returns")
	assert_true(not WordCatalog.stage_words(3).has("nothing"), "only known words are used")
	var path := "user://test_words_progress.cfg"
	SafeConfig.remove_all(path)
	var store := ProgressStore.new(path)
	store.record_word_stage("es", 1, 2, PackedStringArray(["cat", "dog"]), PackedStringArray(["cat"]))
	assert_eq(store.word_stars("es", 1), 2, "stars saved per language")
	assert_eq(store.word_stars("fr", 1), 0, "languages are separate")
	assert_true(store.word_review("es").has("cat"), "the missed word is saved")
	store.record_word_stage("es", 2, 3, PackedStringArray(["cat"]), PackedStringArray())
	assert_true(not store.word_review("es").has("cat"), "a word matched first try leaves the list")
	store.record_word_stage("es", 1, 1, PackedStringArray(), PackedStringArray())
	assert_eq(store.word_stars("es", 1), 2, "the best stars stay")
	SafeConfig.remove_all(path)


func test_picture_only_matches_its_word() -> void:
	assert_true(TileCatalog.faces_match("word_cat_p", "word_cat_w"), "picture matches its word")
	assert_true(not TileCatalog.faces_match("word_cat_p", "word_dog_w"), "not another word")
	assert_eq(WordCatalog.id_of("word_cat_w"), "cat", "word id")
	assert_true(WordCatalog.is_picture("word_cat_p") and not WordCatalog.is_picture("word_cat_w"), "picture or word")


func test_deals_are_solvable_and_keep_one_picture_per_word() -> void:
	for stage in range(1, WordCatalog.stage_count() + 1):
		var level := WordCatalog.level_for(stage)
		var geometry := level.load_layout().build_geometry()
		var deal := BoardGenerator.generate(geometry, WordCatalog.faces_for(WordCatalog.stage_words(stage)), level.deal_seed)
		assert_true(deal.ok, "stage %d deals" % stage)
		var counts := {}
		for face in deal.faces:
			counts[face] = int(counts.get(face, 0)) + 1
		assert_eq(counts.size(), deal.faces.size(), "stage %d: each picture and word is on the board once" % stage)
		var model := BoardModel.new(geometry, deal.faces)
		assert_true(BoardSolver.solve(model, 200000).solved, "stage %d can be solved" % stage)
		var shuffled := BoardGenerator.reshuffle(model, level.deal_seed + 1)
		assert_true(shuffled.ok, "stage %d can be shuffled" % stage)


func test_stars() -> void:
	assert_eq(WordCatalog.stars(0), 3, "no mistakes")
	assert_eq(WordCatalog.stars(2), 2, "a few mistakes")
	assert_eq(WordCatalog.stars(9), 1, "always one star for finishing")
