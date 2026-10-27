extends TestCase
## The shipped introductory levels.


func test_ten_levels_defined() -> void:
	assert_eq(LevelCatalog.count(), 10, "ten introductory levels")


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
	for level in LevelCatalog.levels():
		var layout := level.load_layout()
		assert_true(layout.tile_count() > previous_tiles,
			"level %d has more tiles (%d) than the one before (%d)" % [level.number, layout.tile_count(), previous_tiles])
		assert_true(layout.layer_count() >= previous_layers, "level %d does not lose layers" % level.number)
		previous_tiles = layout.tile_count()
		previous_layers = layout.layer_count()


func test_levels_use_only_verified_art() -> void:
	for level in LevelCatalog.levels():
		var pool := level.face_pool()
		assert_false(pool.is_empty(), "level %d has faces" % level.number)
		for face in pool:
			assert_true(TileCatalog.is_art_verified(face), "level %d avoids defective art (%s)" % [level.number, face])
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
	for level in LevelCatalog.levels():
		var geometry := level.load_layout().build_geometry()
		var a := BoardGenerator.generate(geometry, level.face_pool(), level.deal_seed)
		var b := BoardGenerator.generate(geometry, level.face_pool(), level.deal_seed)
		assert_eq(a.faces, b.faces, "level %d deals identically on restart" % level.number)


func test_solver_confirms_every_level() -> void:
	for level in LevelCatalog.levels():
		var layout := level.load_layout()
		var geometry := layout.build_geometry()
		var result := BoardGenerator.generate(geometry, level.face_pool(), level.deal_seed)
		var model := BoardModel.new(geometry, result.faces)
		var solved := BoardSolver.solve(model, 200000)
		assert_true(solved.solved, "solver independently clears level %d (%d nodes)" % [level.number, solved.nodes])
		print("        level %2d %-16s tiles %3d  layers %d  faces %2d  deal attempts %d  solver nodes %d  opening moves %d" % [
			level.number, level.title, layout.tile_count(), layout.layer_count(),
			_distinct(result.faces), result.attempts, solved.nodes, model.available_matches().size()])


func _distinct(faces: PackedStringArray) -> int:
	var seen := {}
	for face in faces:
		seen[face] = true
	return seen.size()
