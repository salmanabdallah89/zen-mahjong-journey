extends TestCase
## Tile availability (blocking) and matching rules.


func test_row_ends_are_free_and_middle_is_blocked() -> void:
	var model := make_model([{"rows": ["XXX"]}], PackedStringArray(["bamboo_1", "bamboo_2", "bamboo_1"]))
	assert_true(model.is_free(tile_at(model, 0, 0, 0)), "left end is free")
	assert_false(model.is_free(tile_at(model, 2, 0, 0)), "middle tile is blocked on both sides")
	assert_true(model.is_free(tile_at(model, 4, 0, 0)), "right end is free")


func test_lone_tile_is_free() -> void:
	var model := make_model([{"rows": ["X"]}, {"z": 0, "offset": [6, 0], "rows": ["X"]}],
		PackedStringArray(["dots_1", "dots_1"]))
	assert_true(model.is_free(0) and model.is_free(1), "tiles with both sides open are free")


func test_tile_covered_from_above_is_blocked() -> void:
	var model := make_model([{"rows": ["X"]}, {"rows": ["X"]}], PackedStringArray(["dots_1", "dots_1"]))
	var bottom := tile_at(model, 0, 0, 0)
	var top := tile_at(model, 0, 0, 1)
	assert_false(model.is_free(bottom), "a tile directly underneath another is blocked")
	assert_true(model.is_free(top), "the top tile is free")
	assert_false(model.can_remove_pair(bottom, top), "a covered tile cannot be matched")


func test_half_offset_tile_covers_both_tiles_beneath() -> void:
	# Top tile sits across the seam of two bottom tiles (offset by half a tile).
	var model := make_model([{"rows": ["XX"]}, {"offset": [1, 0], "rows": ["X"]}],
		PackedStringArray(["dots_1", "dots_2", "dots_3"]))
	assert_false(model.is_free(tile_at(model, 0, 0, 0)), "left tile is partially covered")
	assert_false(model.is_free(tile_at(model, 2, 0, 0)), "right tile is partially covered")
	assert_true(model.is_free(tile_at(model, 1, 0, 1)), "bridging top tile is free")


func test_half_row_offset_neighbor_blocks_side() -> void:
	# A tile shifted half a row down still touches the side of its neighbour.
	var model := make_model([{"rows": ["X"]}, {"z": 0, "offset": [2, 1], "rows": ["X"]},
		{"z": 0, "offset": [4, 0], "rows": ["X"]}], PackedStringArray(["dots_1", "dots_2", "dots_1"]))
	assert_false(model.is_free(tile_at(model, 2, 1, 0)), "offset tile between two neighbours is blocked")


func test_tiles_in_different_rows_do_not_block_sides() -> void:
	var model := make_model([{"rows": ["X.", ".X"]}], PackedStringArray(["dots_1", "dots_1"]))
	assert_true(model.is_free(0) and model.is_free(1), "diagonal tiles do not block each other")


func test_removing_neighbor_frees_tile() -> void:
	var model := make_model([{"rows": ["XXXX"]}],
		PackedStringArray(["bamboo_1", "bamboo_2", "bamboo_2", "bamboo_1"]))
	var second := tile_at(model, 2, 0, 0)
	assert_false(model.is_free(second), "second tile starts blocked")
	assert_true(model.remove_pair(tile_at(model, 0, 0, 0), tile_at(model, 6, 0, 0)), "ends match and are removed")
	assert_true(model.is_free(second), "second tile is free after its left neighbour is gone")


func test_removing_cover_frees_tile() -> void:
	var model := make_model([{"rows": ["XXX"]}, {"offset": [2, 0], "rows": ["X"]}],
		PackedStringArray(["dots_5", "dots_5", "dots_5", "dots_5"]))
	var top := tile_at(model, 2, 0, 1)
	var under := tile_at(model, 2, 0, 0)
	assert_true(model.remove_pair(top, tile_at(model, 0, 0, 0)), "top and left end match")
	assert_true(model.is_free(under), "uncovered tile with an open side is free")


func test_identical_faces_match() -> void:
	assert_true(TileCatalog.faces_match("bamboo_3", "bamboo_3"), "identical faces match")
	assert_false(TileCatalog.faces_match("bamboo_3", "bamboo_4"), "different ranks do not match")
	assert_false(TileCatalog.faces_match("bamboo_3", "dots_3"), "same rank in another suit does not match")


func test_flowers_and_seasons_match_within_suit() -> void:
	assert_true(TileCatalog.faces_match("flowers_plum", "flowers_orchid"), "any two flowers match")
	assert_true(TileCatalog.faces_match("seasons_spring", "seasons_winter"), "any two seasons match")
	assert_false(TileCatalog.faces_match("flowers_plum", "seasons_spring"), "a flower does not match a season")
	assert_false(TileCatalog.faces_match("flowers_bamboo", "bamboo_1"), "bamboo flower is not a bamboo suit tile")


func test_cannot_match_tile_with_itself_or_mismatch() -> void:
	var model := make_model([{"rows": ["X"]}, {"z": 0, "offset": [6, 0], "rows": ["X"]}],
		PackedStringArray(["dots_1", "dots_2"]))
	assert_false(model.can_remove_pair(0, 0), "a tile cannot pair with itself")
	assert_false(model.remove_pair(0, 1), "different faces cannot be removed")
	assert_eq(model.remaining, 2, "nothing was removed")


func test_win_detection_and_restore() -> void:
	var model := make_model([{"rows": ["XX"]}], PackedStringArray(["dots_9", "dots_9"]))
	assert_false(model.is_cleared(), "board starts with tiles")
	assert_true(model.remove_pair(0, 1), "last pair removed")
	assert_true(model.is_cleared(), "empty board is a win")
	assert_false(model.has_moves(), "no moves on an empty board")
	model.restore_pair(0, 1)
	assert_eq(model.remaining, 2, "undo restores both tiles")
	assert_true(model.can_remove_pair(0, 1), "restored pair is playable again")


func test_dead_end_has_no_moves() -> void:
	# Two matching tiles stacked: only the top one is ever free.
	var model := make_model([{"rows": ["X"]}, {"rows": ["X"]}], PackedStringArray(["dots_1", "dots_1"]))
	assert_false(model.has_moves(), "stacked pair has no available match")
	assert_true(model.available_matches().is_empty(), "available_matches agrees")


func test_available_matches_lists_free_pairs_only() -> void:
	var model := make_model([{"rows": ["XXX"]}], PackedStringArray(["dots_1", "dots_1", "dots_1"]))
	var matches := model.available_matches()
	assert_eq(matches.size(), 1, "only the two free ends form a match")
	assert_eq(matches[0], Vector2i(0, 2), "the free ends")
