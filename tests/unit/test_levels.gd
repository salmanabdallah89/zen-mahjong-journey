extends TestCase
## The journey's levels: the 10 hand-made ones and the generated rest.

const HANDMADE := 10


func _handmade() -> Array[LevelCatalog.LevelDefinition]:
	return LevelCatalog.levels().slice(0, HANDMADE)


func test_every_level_has_time_and_mistake_limits() -> void:
	var previous_time := 0
	for level in LevelCatalog.levels():
		var pairs := level.load_layout().tile_count() / 2.0
		assert_true(level.time_limit > 0 and level.mistake_limit > 0, "level %d has a clock and hearts" % level.number)
		assert_true(level.time_limit / pairs >= 7.0,
			"level %d allows at least 7 s per pair (%.1f)" % [level.number, level.time_limit / pairs])
		if level.number <= HANDMADE:
			assert_true(level.time_limit >= previous_time, "level %d gives no less time than the one before" % level.number)
			previous_time = level.time_limit


func test_thousand_levels_defined() -> void:
	assert_eq(LevelCatalog.count(), LevelRecipe.TOTAL_LEVELS, "the journey has %d levels" % LevelRecipe.TOTAL_LEVELS)
	assert_eq(LevelCatalog.get_level(1).title, "Lotus Pond", "hand-made levels come first, unchanged")
	assert_eq(LevelCatalog.get_level(10).deal_seed, 2010, "level 10 keeps its hand-made seed")


func test_layouts_are_valid() -> void:
	for level in LevelCatalog.levels():
		var layout := level.load_layout()
		assert_true(layout != null, "level %d layout loads" % level.number)
		if layout == null:
			continue
		for error in layout.validate():
			failures.append("level %d (%s): %s" % [level.number, layout.id, error])
		assert_true(layout.layer_count() >= 2, "level %d has stacked layers" % level.number)


func test_difficulty_increases() -> void:
	var previous_tiles := 0
	var previous_layers := 0
	for level: LevelCatalog.LevelDefinition in _handmade():
		var layout := level.load_layout()
		assert_true(layout.tile_count() > previous_tiles,
			"level %d has more tiles (%d) than the one before (%d)" % [level.number, layout.tile_count(), previous_tiles])
		assert_true(layout.layer_count() >= previous_layers, "level %d does not lose layers" % level.number)
		previous_tiles = layout.tile_count()
		previous_layers = layout.layer_count()


func test_levels_use_only_verified_art() -> void:
	for level in LevelCatalog.levels():
		var pool := level.face_pool()
		assert_true(_suit_count(pool) >= 3, "level %d mixes at least three suits" % level.number)
		assert_false(pool.is_empty(), "level %d has faces" % level.number)
		for face in pool:
			assert_true(TileArtSet.active().is_verified(face), "level %d avoids defective art (%s)" % [level.number, face])
		assert_true(ResourceLoader.exists(level.background_path()), "level %d background exists" % level.number)


func test_every_level_generates_with_verified_solution() -> void:
	for level in LevelCatalog.levels():
		var geometry := level.load_layout().build_geometry()
		var result := BoardGenerator.generate(geometry, level.face_pool(), level.deal_seed)
		assert_true(result.ok, "level %d deals a solvable board" % level.number)
		if not result.ok:
			continue
		# Play the level to completion through the same API the game uses.
		var model := BoardModel.new(geometry, result.faces)
		for pair in result.solution:
			assert_true(model.can_remove_pair(pair.x, pair.y), "level %d: move %s is legal" % [level.number, pair])
			model.remove_pair(pair.x, pair.y)
		assert_true(model.is_cleared(), "level %d is won after the solution" % level.number)


func test_level_deals_are_deterministic() -> void:
	for level: LevelCatalog.LevelDefinition in LevelCatalog.levels().slice(0, 40):
		var geometry := level.load_layout().build_geometry()
		var a := BoardGenerator.generate(geometry, level.face_pool(), level.deal_seed)
		var b := BoardGenerator.generate(geometry, level.face_pool(), level.deal_seed)
		assert_eq(a.faces, b.faces, "level %d deals identically on restart" % level.number)


func test_solver_confirms_every_level() -> void:
	for level in LevelCatalog.levels():
		# The verified solution covers every level; the independent solver
		# checks the hand-made ones and every 25th generated one.
		if level.number > HANDMADE and level.number % 25 != 0:
			continue
		var layout := level.load_layout()
		var geometry := layout.build_geometry()
		var result := BoardGenerator.generate(geometry, level.face_pool(), level.deal_seed)
		var model := BoardModel.new(geometry, result.faces)
		var solved := BoardSolver.solve(model, 200000)
		assert_true(solved.solved, "solver independently clears level %d (%d nodes)" % [level.number, solved.nodes])
		if level.number <= HANDMADE:
			print("        level %2d %-16s tiles %3d  layers %d  faces %2d  deal attempts %d  solver nodes %d  opening moves %d" % [
				level.number, level.title, layout.tile_count(), layout.layer_count(),
				_distinct(result.faces), result.attempts, solved.nodes, model.available_matches().size()])


func _distinct(faces: PackedStringArray) -> int:
	var seen := {}
	for face in faces:
		seen[face] = true
	return seen.size()


func _suit_count(faces: PackedStringArray) -> int:
	var suits := {}
	for face in faces:
		suits[TileCatalog.suit_of(face)] = true
	return suits.size()


func test_generated_levels_follow_the_recipe() -> void:
	for level: LevelCatalog.LevelDefinition in LevelCatalog.levels().slice(HANDMADE):
		var chapter := LevelRecipe.chapter_of(level.number)
		assert_eq(level.background, LevelRecipe.garden_of_chapter(chapter), "level %d plays in its chapter's garden" % level.number)
		assert_true(level.difficulty >= 1 and level.difficulty <= 4, "level %d difficulty in range" % level.number)
		assert_true(level.mistake_limit >= 3 and level.mistake_limit <= 5, "level %d has 3 to 5 hearts" % level.number)
		assert_false(level.title.is_empty(), "level %d has a name" % level.number)
		if level.number % LevelRecipe.CHAPTER_SIZE == 0:
			assert_true(level.difficulty >= 3, "level %d ends its chapter on a summit" % level.number)


func test_generated_levels_are_stable() -> void:
	# Built again from the number alone, a level is identical.
	for number in [11, 237, 640, 1000]:
		var again := LevelCatalog.LevelDefinition.new()
		again.number = number
		LevelRecipe.build(again)
		var shipped := LevelCatalog.get_level(number)
		assert_true(again.layout_path == shipped.layout_path and again.deal_seed == shipped.deal_seed
			and again.time_limit == shipped.time_limit and again.title == shipped.title,
			"level %d is the same every time (%s)" % [number, shipped.title])
