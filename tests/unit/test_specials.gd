extends TestCase
## Mystery (face-down) and golden lotus tiles (TileSpecials).


func _plan(level_number: int) -> Array:
	var level := LevelCatalog.get_level(level_number)
	var geometry := level.load_layout().build_geometry()
	var deal := BoardGenerator.generate(geometry, level.face_pool(), level.deal_seed)
	var model := BoardModel.new(geometry, deal.faces)
	return [TileSpecials.plan(level.number, level.difficulty, model, deal.solution, level.deal_seed), model, deal]


func test_first_levels_stay_plain() -> void:
	for number in [1, 2]:
		var specials: TileSpecials = _plan(number)[0]
		assert_true(specials.golden.is_empty() and specials.mystery.is_empty(), "level %d has no special tiles" % number)
	var third: TileSpecials = _plan(TileSpecials.FIRST_GOLDEN_LEVEL)[0]
	assert_eq(third.golden.size(), 2, "the golden lotus arrives first as one pair")
	assert_true(third.mystery.is_empty(), "no face-down tiles yet on level %d" % TileSpecials.FIRST_GOLDEN_LEVEL)


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
		assert_true(specials.mystery.size() <= ceili(model.tile_count() * 0.5), "level %d: at most half the board face-down" % number)


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
