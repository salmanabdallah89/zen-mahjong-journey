extends TestCase
## Mystery (face-down) and golden lotus tiles (TileSpecials).


func _plan(level_number: int) -> Array:
	var level := LevelCatalog.get_level(level_number)
	var geometry := level.load_layout().build_geometry()
	var deal := BoardGenerator.generate(geometry, level.face_pool(), level.deal_seed)
	var model := BoardModel.new(geometry, deal.faces)
	return [TileSpecials.plan(level.number, level.difficulty, model, deal.solution, level.deal_seed), model, deal]


func test_first_levels_stay_plain() -> void:
	var first: TileSpecials = _plan(1)[0]
	assert_true(first.golden.is_empty() and first.mystery.is_empty(), "level 1 has no special tiles")
	var second: TileSpecials = _plan(TileSpecials.FIRST_MYSTERY_LEVEL)[0]
	assert_true(second.golden.is_empty() and not second.mystery.is_empty(), "face-down tiles arrive on level 2")
	var third: TileSpecials = _plan(TileSpecials.FIRST_GOLDEN_LEVEL)[0]
	assert_eq(third.golden.size(), 2, "the golden lotus arrives as one pair")


func test_harder_levels_hide_more_tiles() -> void:
	var last := 0.0
	for difficulty in [1, 2, 3, 4]:
		var share := float(TileSpecials.MYSTERY_SHARE[difficulty])
		assert_true(share > last and share <= 0.9, "difficulty %d hides more than the one before" % difficulty)
		last = share
	# Most blocked tiles of an expert board are face-down.
	var plan := _plan(10)
	var specials: TileSpecials = plan[0]
	var model: BoardModel = plan[1]
	var blocked := 0
	for i in model.tile_count():
		blocked += 0 if model.is_free(i) else 1
	assert_true(specials.mystery.size() >= blocked * 0.8, "level 10 hides most of its blocked tiles (%d of %d)" % [specials.mystery.size(), blocked])


func test_golden_tiles_are_a_matching_pair() -> void:
	for number in [3, 7, 25, 140, 999]:
		var plan := _plan(number)
		var specials: TileSpecials = plan[0]
		var model: BoardModel = plan[1]
		var tiles: Array = specials.golden.keys()
		assert_eq(tiles.size(), 2, "level %d gilds two tiles" % number)
		assert_true(TileCatalog.faces_match(model.face_of(tiles[0]), model.face_of(tiles[1])), "level %d: the golden tiles match" % number)
		assert_eq(specials.factor(tiles[0], tiles[1]), TileSpecials.GOLDEN_FACTOR, "level %d: golden match scores double" % number)


func test_mystery_tiles_start_blocked_and_never_golden() -> void:
	for number in [4, 10, 33, 260, 1000]:
		var plan := _plan(number)
		var specials: TileSpecials = plan[0]
		var model: BoardModel = plan[1]
		assert_false(specials.mystery.is_empty(), "level %d has face-down tiles" % number)
		for index: int in specials.mystery:
			assert_false(model.is_free(index), "level %d: face-down tile %d starts blocked" % [number, index])
			assert_false(specials.is_golden(index), "level %d: tile %d is not both golden and face-down" % [number, index])
		# Every free tile shows its face, so there is always something to read.
		assert_true(specials.mystery.size() <= model.tile_count() - model.free_tiles().size(), "level %d: only blocked tiles lie face-down" % number)


func test_plans_are_reproducible() -> void:
	for number in [5, 77]:
		var first: TileSpecials = _plan(number)[0]
		var second: TileSpecials = _plan(number)[0]
		assert_eq(first.mystery.keys(), second.mystery.keys(), "level %d: same face-down tiles every time" % number)
		assert_eq(first.golden.keys(), second.golden.keys(), "level %d: same golden pair every time" % number)


func test_tiles_turn_over_as_they_are_uncovered() -> void:
	var plan := _plan(8)
	var specials: TileSpecials = plan[0]
	var model: BoardModel = plan[1]
	var deal: BoardGenerator.Result = plan[2]
	var start := specials.mystery.size()
	var turned := 0
	for pair in deal.solution:
		model.remove_pair(pair.x, pair.y)
		var revealed := specials.reveal_free(model)
		turned += revealed.size()
		for index in revealed:
			assert_true(model.is_free(index), "tile %d turns over only once it is free" % index)
		for index: int in specials.mystery:
			assert_false(model.is_free(index) and not model.is_removed(index), "free tile %d is not left face-down" % index)
	assert_eq(turned, start, "every face-down tile turned over during the solution")
	assert_true(specials.mystery.is_empty(), "nothing is face-down at the end")


func test_golden_points_double() -> void:
	var score := LevelScore.new()
	var plain := score.add_match(1)
	var golden := score.add_match(1, TileSpecials.GOLDEN_FACTOR)
	assert_eq(golden, plain * TileSpecials.GOLDEN_FACTOR, "a golden match earns double")
	assert_eq(score.match_points, plain + golden, "both count towards the level score")
