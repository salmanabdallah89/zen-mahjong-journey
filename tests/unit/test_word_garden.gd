extends TestCase
## Word Garden content and rules: words, stages, picture-word matching.


func test_words_fit_tiles_and_are_unique() -> void:
	for language: Dictionary in WordCatalog.languages():
		var seen := {}
		for word_id in WordCatalog.word_ids():
			var text := WordCatalog.text(word_id, str(language.id))
			assert_true(text.length() <= WordCatalog.MAX_LETTERS and not text.contains(" "), "%s fits a tile" % text)
			assert_true(not seen.has(text), "%s is on one word only" % text)
			seen[text] = true


func test_pictures_exist_and_are_not_held_back() -> void:
	for word_id in WordCatalog.word_ids():
		assert_true(WordCatalog.picture(word_id, func(path: String) -> Texture2D: return load(path) if ResourceLoader.exists(path) else null) != null,
			"%s has a picture" % word_id)
	var words := FileAccess.get_file_as_string(WordCatalog.WORDS_PATH)
	for collection in ["fruits", "vegetables"]:
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/collections/%s.json" % collection))
		for held: String in manifest.held_back_symbols:
			assert_true(not words.contains('_%s.png"' % held), "%s is held back" % held)


func test_every_stage_fills_its_board_and_every_word_is_taught() -> void:
	var taught := {}
	for stage in range(1, WordCatalog.STAGE_COUNT + 1):
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
	for stage in range(1, WordCatalog.STAGE_COUNT + 1):
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
