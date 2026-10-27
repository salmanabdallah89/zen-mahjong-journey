extends TestCase
## Seeded generation, solution verification, solver and shuffle.

const POOL: PackedStringArray = ["bamboo_1", "bamboo_2", "bamboo_3", "dots_1", "dots_2",
	"flowers_plum", "flowers_orchid", "flowers_chrysanthemum", "flowers_bamboo"]


func _pyramid() -> BoardGeometry:
	return BoardLayout.from_dict({"layers": [
		{"rows": ["XXXXXX", "XXXXXX", "XXXXXX", "XXXXXX"]},
		{"offset": [2, 2], "rows": ["XXXX", "XXXX"]},
		{"offset": [4, 3], "rows": ["XX"]},
	]}).build_geometry()


func test_same_seed_gives_same_board() -> void:
	var geometry := _pyramid()
	var a := BoardGenerator.generate(geometry, POOL, 42)
	var b := BoardGenerator.generate(geometry, POOL, 42)
	assert_true(a.ok and b.ok, "generation succeeds")
	assert_eq(a.faces, b.faces, "faces are deterministic")
	assert_eq(a.solution, b.solution, "solution is deterministic")


func test_different_seeds_give_different_boards() -> void:
	var geometry := _pyramid()
	var a := BoardGenerator.generate(geometry, POOL, 1)
	var b := BoardGenerator.generate(geometry, POOL, 2)
	assert_true(a.faces != b.faces, "different seeds deal differently")


func test_generated_solution_clears_board() -> void:
	var geometry := _pyramid()
	for deal_seed in range(1, 21):
		var result := BoardGenerator.generate(geometry, POOL, deal_seed)
		assert_true(result.ok, "seed %d generates" % deal_seed)
		var model := BoardModel.new(geometry, result.faces)
		for pair in result.solution:
			assert_true(model.remove_pair(pair.x, pair.y), "seed %d: solution move %s is legal" % [deal_seed, pair])
		assert_true(model.is_cleared(), "seed %d: solution clears the board" % deal_seed)


func test_generated_faces_come_in_matching_pairs() -> void:
	var result := BoardGenerator.generate(_pyramid(), POOL, 7)
	var counts := {}
	for face in result.faces:
		assert_true(POOL.has(face), "%s comes from the pool" % face)
		var group := TileCatalog.match_group(face)
		counts[group] = int(counts.get(group, 0)) + 1
	for group: String in counts:
		assert_eq(int(counts[group]) % 2, 0, "group %s has an even count" % group)


func test_group_suits_are_dealt() -> void:
	# Regression: flowers were once silently dropped from the pool.
	var pool: PackedStringArray = ["bamboo_1", "flowers_plum", "flowers_orchid",
		"flowers_chrysanthemum", "flowers_bamboo"]
	var result := BoardGenerator.generate(_pyramid(), pool, 8)
	var flowers := 0
	for face in result.faces:
		if TileCatalog.suit_of(face) == "flowers":
			flowers += 1
	assert_true(flowers >= 4, "flowers appear on the board (%d found)" % flowers)


func test_verify_rejects_illegal_solution() -> void:
	var geometry := _pyramid()
	var result := BoardGenerator.generate(geometry, POOL, 3)
	var reversed := result.solution.duplicate()
	reversed.reverse()
	var empty := PackedByteArray()
	empty.resize(geometry.size())
	assert_false(BoardGenerator.verify_solution(geometry, result.faces, empty, reversed),
		"playing the solution backwards starts with covered tiles and is rejected")


func test_solver_finds_solution_independently() -> void:
	var geometry := _pyramid()
	var result := BoardGenerator.generate(geometry, POOL, 11)
	var model := BoardModel.new(geometry, result.faces)
	var solved := BoardSolver.solve(model, 200000)
	assert_true(solved.solved, "solver clears the generated board")
	var empty := PackedByteArray()
	empty.resize(geometry.size())
	assert_true(BoardGenerator.verify_solution(geometry, result.faces, empty, solved.moves), "solver moves are legal")


func test_solver_proves_dead_end() -> void:
	var model := make_model([{"rows": ["X"]}, {"rows": ["X"]}], PackedStringArray(["dots_1", "dots_1"]))
	var solved := BoardSolver.solve(model)
	assert_false(solved.solved, "stacked pair cannot be cleared")
	assert_false(solved.exhausted, "the search proved it rather than running out of budget")


func test_reshuffle_keeps_faces_and_is_solvable() -> void:
	var geometry := _pyramid()
	var result := BoardGenerator.generate(geometry, POOL, 5)
	var model := BoardModel.new(geometry, result.faces)
	for k in 4:
		var pair := result.solution[k]
		model.remove_pair(pair.x, pair.y)
	var before := _sorted_remaining_faces(model)
	var shuffled := BoardGenerator.reshuffle(model, 99)
	assert_true(shuffled.ok, "reshuffle succeeds")
	model.set_faces(shuffled.faces)
	assert_eq(_sorted_remaining_faces(model), before, "same faces remain after shuffle")
	for pair in shuffled.solution:
		assert_true(model.remove_pair(pair.x, pair.y), "reshuffle solution move is legal")
	assert_true(model.is_cleared(), "reshuffled board clears")


func test_reshuffle_reports_impossible_geometry() -> void:
	var model := make_model([{"rows": ["X"]}, {"rows": ["X"]}], PackedStringArray(["dots_1", "dots_1"]))
	assert_false(BoardGenerator.reshuffle(model, 1).ok, "a single stack can never be dealt solvably")


func _sorted_remaining_faces(model: BoardModel) -> PackedStringArray:
	var faces := PackedStringArray()
	for i in model.remaining_tiles():
		faces.append(model.faces[i])
	faces.sort()
	return faces
