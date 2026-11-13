extends TestCase
## The tile tray: taking tiles, matching in the tray, a full tray, undo,
## second chance and hints.


## A flat row of tiles side by side: only the two ends are free.
func _row(faces: PackedStringArray) -> BoardModel:
	return make_model([{"rows": ["X".repeat(faces.size())]}], faces)


## Tiles with gaps between them: every tile is free.
func _apart(faces: PackedStringArray) -> BoardModel:
	var row := ""
	for i in faces.size():
		row += "X."
	return make_model([{"rows": [row]}], faces)


func test_a_pair_meets_in_the_tray() -> void:
	var model := _apart(PackedStringArray(["dots_1", "bamboo_2", "dots_1", "bamboo_2"]))
	var tray := TileTray.new()
	var first := tray.take(model, 0)
	assert_false(first.matched(), "the first tile waits")
	assert_eq(tray.tiles, [0] as Array[int], "in the tray")
	assert_true(model.is_removed(0) and model.remaining == 3, "it left the board")
	var second := tray.take(model, 2)
	assert_true(second.matched() and second.partner == 0 and second.slot == 0, "its match takes it away")
	assert_true(tray.is_empty(), "both leave the tray")
	assert_eq(model.remaining, 2, "both left the board")


func test_flowers_match_any_flower() -> void:
	var model := _apart(PackedStringArray(["flowers_plum", "flowers_orchid"]))
	var tray := TileTray.new()
	tray.take(model, 0)
	assert_true(tray.take(model, 1).matched(), "two different flowers match")
	assert_true(model.is_cleared(), "board cleared")


func test_a_full_tray_stops_the_level() -> void:
	var model := _apart(PackedStringArray(["dots_1", "dots_2", "dots_3", "dots_4", "dots_1", "dots_2", "dots_3", "dots_4"]))
	var tray := TileTray.new()
	assert_false(tray.take(model, 0).close_call, "one waiting is fine")
	tray.take(model, 1)
	assert_true(tray.take(model, 2).close_call, "three waiting is a close call")
	var last := tray.take(model, 3)
	assert_true(last.full and tray.is_full(), "four without a pair fill the tray")
	assert_eq(tray.take(model, 4), null, "nothing more fits")
	assert_false(model.is_removed(4), "and the tile stays on the board")


func test_only_free_tiles_can_be_taken() -> void:
	var model := _row(PackedStringArray(["dots_1", "dots_2", "dots_1"]))
	var tray := TileTray.new()
	assert_eq(tray.take(model, 1), null, "a tile blocked on both sides")
	assert_true(tray.is_empty() and not model.is_removed(1), "nothing changes")
	tray.take(model, 0)
	assert_true(model.is_free(1), "taking a neighbour frees it")


func test_undo_puts_everything_back() -> void:
	var model := _apart(PackedStringArray(["dots_1", "dots_2", "dots_1", "dots_2"]))
	var tray := TileTray.new()
	var placed := tray.take(model, 1)
	tray.take(model, 0)
	var matched := tray.take(model, 2)
	assert_eq(tray.tiles, [1] as Array[int], "dots_1 pair left, dots_2 waits")
	tray.undo(model, matched)
	assert_eq(tray.tiles, [1, 0] as Array[int], "the partner returns to its slot")
	assert_false(model.is_removed(2), "the tile returns to the board")
	assert_true(model.is_removed(0), "the partner stays off the board")
	tray.undo(model, tray.take(model, 3))
	assert_eq(tray.tiles, [1, 0] as Array[int], "undoing a match from the first slot")
	tray.undo(model, placed)
	assert_eq(tray.tiles, [0] as Array[int], "a waiting tile leaves the tray")
	assert_false(model.is_removed(1), "and returns to the board")


func test_second_chance_and_shuffle_send_tiles_back() -> void:
	var model := _apart(PackedStringArray(["dots_1", "dots_2", "dots_3", "dots_4", "dots_1", "dots_2", "dots_3", "dots_4"]))
	var tray := TileTray.new()
	for i in 4:
		tray.take(model, i)
	assert_eq(tray.send_back(model, 2), [3, 2] as Array[int], "the two newest go back")
	assert_eq(tray.tiles, [0, 1] as Array[int], "two still wait")
	assert_false(model.is_removed(2) or model.is_removed(3), "back on the board")
	tray.empty_into(model)
	assert_true(tray.is_empty() and model.remaining == 8, "a shuffle starts from an empty tray")


func test_hint_finds_the_partner_of_a_waiting_tile() -> void:
	var model := _apart(PackedStringArray(["dots_1", "dots_2", "dots_1", "dots_2"]))
	var tray := TileTray.new()
	assert_eq(tray.free_match(model), -1, "empty tray: nothing to finish")
	tray.take(model, 1)
	assert_eq(tray.free_match(model), 3, "the other dots_2")
