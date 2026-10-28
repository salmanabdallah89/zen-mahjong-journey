extends Node
## Integration test: plays real levels on the actual game screen by pushing
## mouse clicks at tile positions, exercises Hint / Undo / Shuffle / Pause /
## Restart, checks the layout at several screen shapes and expects the Level
## Complete dialog at the end. Run:
##   godot --headless --path . res://tests/integration/playthrough_test.tscn
## Exits with code 1 on any failure.

const GAME_SCENE := preload("res://scenes/screens/game_screen.tscn")
## Canvas sizes for common phone shapes (9:16, 9:19.5, 9:21) and a tablet (3:4).
const SCREEN_SHAPES: Array[Vector2] = [Vector2(1080, 1920), Vector2(1080, 2340),
	Vector2(1080, 2520), Vector2(1440, 1920)]

var _failures := PackedStringArray()
var _checks := 0
var _frame: Control


const ISOLATED_SETTINGS := "user://test_settings_playthrough.cfg"
const ISOLATED_PROGRESS := "user://test_progress_playthrough.cfg"
const JOURNEY_SCENE := preload("res://scenes/screens/journey_screen.tscn")
const STARTUP_SCENE := preload("res://scenes/screens/startup_screen.tscn")


func _ready() -> void:
	# Never read or write the player's real preferences; start on Classic.
	SafeConfig.remove_all(ISOLATED_SETTINGS)
	TileCollectionManager.settings_path = ISOLATED_SETTINGS
	TileCollectionManager.restore()
	# Ads have their own test (ads_test); keep these flows ad-free and fixed.
	AdsManager.provider = "none"
	# Never touch the player's real journey either.
	GameSession.progress = ProgressStore.new(ISOLATED_PROGRESS)
	GameSession.progress.reset()
	_frame = Control.new()
	_frame.size = SCREEN_SHAPES[0]
	add_child(_frame)
	await _test_full_playthrough(1)
	await _test_tools_and_pause(3)
	await _test_full_playthrough(10)
	await _test_responsive_layout(10)
	await _test_small_board_keeps_margins(1)
	await _test_alternate_art_set(2)
	await _test_tile_collections(2)
	await _test_premium_collections(5)
	await _test_time_and_mistakes(2)
	await _test_journey_and_stars()
	await _test_audit_fixes(3)
	SafeConfig.remove_all(ISOLATED_SETTINGS)
	GameSession.progress.reset()
	SafeConfig.remove_all(ISOLATED_PROGRESS)
	GameSession.progress = ProgressStore.new()
	for failure in _failures:
		print("  FAIL  " + failure)
	print("playthrough: %d checks, %d failed" % [_checks, _failures.size()])
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _test_full_playthrough(level_number: int) -> void:
	var screen := await _open_level(level_number)
	var deal := _expected_deal(level_number)
	var model: BoardModel = screen.get("_model")
	_check(model.faces == deal.faces, "level %d: game deals the seeded board" % level_number)
	for pair in deal.solution:
		await _click_tile(screen, pair.x)
		await _click_tile(screen, pair.y)
		if not (model.is_removed(pair.x) and model.is_removed(pair.y)):
			_check(false, "level %d: clicking pair %s removed it" % [level_number, pair])
			break
	_check(model.is_cleared(), "level %d: board cleared by clicking" % level_number)
	await _frames(3)
	var dialog: ModalDialog = screen.get_node("%Dialog")
	_check(dialog.visible, "level %d: completion dialog shown" % level_number)
	var title: Label = dialog.get_node("%Title")
	var expected := "Level Complete!" if level_number < LevelCatalog.count() else "Journey Complete!"
	_check(title.text == expected, "level %d: dialog title is '%s' (got '%s')" % [level_number, expected, title.text])
	_check((screen.get_node("%TilesValue") as Label).text == "0", "level %d: HUD shows 0 tiles" % level_number)
	screen.queue_free()
	await _frames(2)


func _test_tools_and_pause(level_number: int) -> void:
	var screen := await _open_level(level_number)
	var model: BoardModel = screen.get("_model")
	var deal := _expected_deal(level_number)
	var tiles_label: Label = screen.get_node("%TilesValue")
	var undo: Button = screen.get_node("%UndoButton")
	_check(undo.disabled, "undo starts disabled")
	_check(tiles_label.text == str(model.tile_count()), "HUD shows full tile count")
	_check((screen.get_node("%LevelValue") as Label).text == "Level %d" % level_number, "HUD shows level number")

	# A blocked tile cannot be selected.
	var blocked := -1
	for i in model.tile_count():
		if not model.is_free(i):
			blocked = i
			break
	await _click_tile(screen, blocked)
	_check(int(screen.get("_selected")) == -1, "clicking a blocked tile selects nothing")
	_check((screen.get_node("%Toast") as Control).visible, "blocked tap explains why")
	_check(not model.blockers(blocked).is_empty(), "blocked tile reports its blockers")

	# Selecting then re-clicking deselects.
	var first := deal.solution[0]
	await _click_tile(screen, first.x)
	_check(int(screen.get("_selected")) == first.x, "clicking a free tile selects it")
	await _click_tile(screen, first.x)
	_check(int(screen.get("_selected")) == -1, "clicking it again deselects")

	# Hint highlights a legal pair.
	await _click_control(screen.get_node("%HintButton"))
	var hint: Vector2i = screen.get("_hint")
	_check(hint.x >= 0 and model.can_remove_pair(hint.x, hint.y), "hint shows a removable pair")

	# Match, then undo.
	await _click_tile(screen, first.x)
	await _click_tile(screen, first.y)
	_check(model.remaining == model.tile_count() - 2, "pair removed")
	_check(tiles_label.text == str(model.remaining), "HUD tile count updates")
	_check(not undo.disabled, "undo enabled after a match")
	await _click_control(undo)
	_check(model.remaining == model.tile_count(), "undo restores the pair")
	_check(not model.is_removed(first.x) and not model.is_removed(first.y), "undone tiles are back")

	# Shuffle keeps the board solvable and is undoable.
	var before := model.faces.duplicate()
	await _click_control(screen.get_node("%ShuffleButton"))
	_check(model.faces != before, "shuffle changes the arrangement")
	_check(BoardSolver.solve(model, 200000).solved, "shuffled board is solvable")
	await _click_control(undo)
	_check(model.faces == before, "undo reverts the shuffle")

	# Pause blocks the board; Restart deals the same board again.
	await _click_control(screen.get_node("%PauseButton"))
	var dialog: ModalDialog = screen.get_node("%Dialog")
	_check(dialog.visible, "pause menu opens")
	var free_tile := _tile_clear_of_buttons(screen, dialog)
	_check(free_tile >= 0, "found a tile not under a pause-menu button")
	await _click_tile(screen, free_tile)
	_check(int(screen.get("_selected")) == -1, "board ignores taps while paused")
	_check(dialog.visible, "pause menu still open after tapping the board")
	var restart: Button = _dialog_button(dialog, "Restart")
	_check(restart != null, "pause menu has Restart")
	if restart:
		await _click_control(restart)
	var restarted: BoardModel = screen.get("_model")
	_check(not dialog.visible, "dialog closes on restart")
	_check(restarted.faces == deal.faces and restarted.remaining == restarted.tile_count(), "restart deals the same full board")
	screen.queue_free()
	await _frames(2)


func _test_responsive_layout(level_number: int) -> void:
	var screen := await _open_level(level_number)
	var board: BoardView = screen.get_node("%Board")
	var hud: Control = screen.get_node("SafeArea/Layout/Hud")
	var toolbar: Control = screen.get_node("SafeArea/Layout/Toolbar")
	for shape in SCREEN_SHAPES:
		_frame.size = shape
		await _frames(3)
		var board_rect := board.get_global_rect()
		var tiles_rect := Rect2()
		var model: BoardModel = screen.get("_model")
		for i in model.tile_count():
			var view := board.tile(i)
			var r := view.get_global_transform() * board.skin().style.body_rect
			tiles_rect = r if tiles_rect.size == Vector2.ZERO else tiles_rect.merge(r)
		var tile_width := board.face_width_on_screen()
		_check(board_rect.grow(1.0).encloses(tiles_rect), "%s: all tiles inside the board area" % shape)
		_check(not tiles_rect.intersects(hud.get_global_rect()), "%s: tiles clear of the HUD" % shape)
		_check(not tiles_rect.intersects(toolbar.get_global_rect()), "%s: tiles clear of the toolbar" % shape)
		_check(tile_width >= 100.0, "%s: tiles stay tappable (%.0f px wide)" % [shape, tile_width])
		_check(screen.get_global_rect().encloses(toolbar.get_global_rect()), "%s: toolbar on screen" % shape)
	_frame.size = SCREEN_SHAPES[0]
	screen.queue_free()
	await _frames(2)


func _test_small_board_keeps_margins(level_number: int) -> void:
	var screen := await _open_level(level_number)
	var board: BoardView = screen.get_node("%Board")
	for shape in SCREEN_SHAPES:
		_frame.size = shape
		await _frames(3)
		_check(board.face_width_on_screen() <= BoardView.MAX_FACE_WIDTH + 0.5,
			"%s: level %d tiles capped at %.0f px" % [shape, level_number, BoardView.MAX_FACE_WIDTH])
		var model: BoardModel = screen.get("_model")
		var tiles_rect := Rect2()
		for i in model.tile_count():
			var r := board.tile(i).get_global_transform() * board.skin().style.body_rect
			tiles_rect = r if tiles_rect.size == Vector2.ZERO else tiles_rect.merge(r)
		_check(tiles_rect.size.x <= shape.x * 0.9, "%s: garden visible beside the board" % shape)
		var center_offset := absf(tiles_rect.get_center().x - shape.x / 2.0)
		_check(center_offset < 4.0, "%s: board centred (%.1f px off)" % [shape, center_offset])
	_frame.size = SCREEN_SHAPES[0]
	screen.queue_free()
	await _frames(2)


## Swaps in a differently laid out tile collection and plays a level through,
## proving art can be replaced without touching gameplay code.
func _test_alternate_art_set(level_number: int) -> void:
	var original := TileArtSet.active()
	var alt := TileArtSet.load_manifest("res://tests/fixtures/alt_tile_art.json")
	TileArtSet.set_active(alt)
	var screen := await _open_level(level_number)
	var board: BoardView = screen.get_node("%Board")
	var model: BoardModel = screen.get("_model")
	var raised := -1
	for i in model.tile_count():
		if model.geometry.positions[i].z > 0:
			raised = i
			break
	var p := model.geometry.positions[raised]
	var expected := Vector2(p.x * alt.half_step().x, p.y * alt.half_step().y) + alt.layer_shift * p.z
	_check(board.tile(raised).position == expected, "alternate art: layout uses its spacing and layer raise")
	var deal := _expected_deal(level_number)
	for pair in deal.solution:
		await _click_tile(screen, pair.x)
		await _click_tile(screen, pair.y)
	_check(model.is_cleared(), "alternate art: level %d still playable by clicking" % level_number)
	screen.queue_free()
	await _frames(2)
	TileArtSet.set_active(original)


## Collection switching during a live level, persistence and fallbacks. Uses
## fixture collections (stand-in art) and a throwaway settings file.
func _test_tile_collections(level_number: int) -> void:
	var manager := TileCollectionManager
	var dirs := PackedStringArray([TileCollectionLibrary.SHIPPED_DIR, "res://tests/fixtures/collections/"])
	var real_settings := manager.settings_path
	var test_settings := "user://test_settings_integration.cfg"
	SafeConfig.remove_all(test_settings)
	manager.settings_path = test_settings
	manager.reload_library(dirs)
	manager.restore()
	_check(manager.selected_id == "classic", "collections: fresh settings start on Classic")

	var screen := await _open_level(level_number)
	var board: BoardView = screen.get_node("%Board")
	var model: BoardModel = screen.get("_model")
	var deal := _expected_deal(level_number)
	var first := deal.solution[0]
	await _click_tile(screen, first.x)
	await _click_tile(screen, first.y)
	var faces_before := model.faces.duplicate()
	var removed_before := model.removed.duplicate()

	# Switch mid-level through the real picker opened from the pause menu.
	await _click_control(screen.get_node("%PauseButton"))
	var dialog: ModalDialog = screen.get_node("%Dialog")
	var open_picker := _dialog_button(dialog, "Tile Collection")
	_check(open_picker != null, "pause menu offers Tile Collection")
	if open_picker:
		await _click_control(open_picker)
	var picker: CollectionPicker = screen.get_node("%CollectionPicker")
	_check(picker.visible, "picker opens from the pause menu")
	picker.highlight("test_lookalike")
	await _frames(2)
	_check((picker.get_node("%ApplyButton") as Button).disabled, "collections with invalid art cannot be applied")
	picker.highlight("test_symbols")
	await _frames(2)
	await _click_control(picker.get_node("%ApplyButton"))
	await _frames(2)
	_check(not picker.visible, "apply returns to the game")
	_check(manager.selected_id == "test_symbols", "apply selects the collection")
	_check(board.skin().collection_id == "test_symbols", "board re-skinned without restarting")
	_check(model == screen.get("_model"), "same board object after switching")
	_check(model.faces == faces_before and model.removed == removed_before, "switching keeps board state")
	_check(_all_tiles_have_art(board, model), "every tile shows complete art after switching")

	# Play on after switching: undo, then shuffle, then undo again.
	await _click_control(screen.get_node("%UndoButton"))
	_check(not model.is_removed(first.x) and not model.is_removed(first.y), "undo works after switching")
	_check(_all_tiles_have_art(board, model), "restored tiles show the new art")
	var symbol_of := board.skin().symbol_texture(model.faces[first.x])
	await _click_control(screen.get_node("%ShuffleButton"))
	_check(board.skin().symbol_texture(model.faces[first.x]) != null, "shuffle keeps tiles skinned")
	await _click_control(screen.get_node("%UndoButton"))
	_check(board.skin().symbol_texture(model.faces[first.x]) == symbol_of, "same symbol for the same tile after undoing shuffle")

	# Unavailable choices are refused with a message.
	_check(not manager.select("test_lookalike") and manager.take_notice().contains("needs fixes"), "invalid art refused with a message")
	_check(not manager.select("test_broken"), "broken collection refused")
	_check(manager.selected_id == "test_symbols", "refusals leave the choice unchanged")

	# Saved choice survives a restart of the manager.
	var restarted: Node = load("res://scripts/autoload/tile_collection_manager.gd").new()
	restarted.settings_path = test_settings
	restarted.reload_library(dirs)
	restarted.restore()
	_check(restarted.selected_id == "test_symbols", "saved collection restored on startup")
	restarted.free()

	# Mixed: stable mapping for the same board across a reload.
	_check(manager.select("test_mixed"), "mixed fixture selectable")
	await _frames(2)
	var mixed_keys := _visual_keys(board, model)
	manager.reload_library(dirs)
	manager.restore()
	screen.call("_on_collection_changed", "test_mixed")
	await _frames(2)
	_check(_visual_keys(board, model) == mixed_keys, "mixed mapping identical after reloading collections")

	# A collection with too few symbols falls back to Classic for this board.
	_check(manager.select("test_letters"), "short fixture selectable")
	await _frames(2)
	_check(board.skin().collection_id == "classic", "board too big for 5 symbols shows Classic")
	_check((screen.get_node("%Toast") as Control).visible, "fallback is explained")
	_check(_all_tiles_have_art(board, model), "fallback board fully drawn")

	# A saved collection that has lost its art falls back safely on startup.
	UserSettings.new(test_settings).set_value("tiles", "collection", "test_broken")
	manager.restore()
	_check(manager.selected_id == "classic" and not manager.take_notice().is_empty(), "missing art on startup falls back to Classic")

	screen.queue_free()
	await _frames(2)
	SafeConfig.remove_all(test_settings)
	manager.settings_path = real_settings
	manager.reload_library(PackedStringArray([TileCollectionLibrary.SHIPPED_DIR]))
	manager.restore()


## Real premium art: switch a live level (with flowers) to each enabled
## collection, check state, layout and art, then clear the level by clicks
## in Animals. Fruits and Vegetables must be refused.
func _test_premium_collections(level_number: int) -> void:
	var manager := TileCollectionManager
	var screen := await _open_level(level_number)
	var board: BoardView = screen.get_node("%Board")
	var model: BoardModel = screen.get("_model")
	var deal := _expected_deal(level_number)
	var has_flowers := false
	for face in model.faces:
		has_flowers = has_flowers or TileCatalog.suit_of(face) == "flowers"
	_check(has_flowers, "premium: level %d deals flowers" % level_number)
	await _click_tile(screen, deal.solution[0].x)
	await _click_tile(screen, deal.solution[0].y)
	var faces_before := model.faces.duplicate()
	var removed_before := model.removed.duplicate()

	for collection_id in ["animals", "alphabet", "mixed", "fruits", "vegetables"]:
		_check(manager.select(collection_id), "premium: %s can be applied" % collection_id)
		await _frames(3)
		_check(board.skin().collection_id == collection_id, "premium: board shows %s" % collection_id)
		_check(board.skin().style.id == "ivory_body_v1", "premium: %s laid out on the ivory body" % collection_id)
		_check(model.faces == faces_before and model.removed == removed_before, "premium: %s keeps board state" % collection_id)
		_check(_all_tiles_have_art(board, model), "premium: %s draws every tile" % collection_id)
		var flower_keys := {}
		for i in model.tile_count():
			if TileCatalog.suit_of(model.faces[i]) == "flowers":
				flower_keys[board.skin().visual_key(model.faces[i])] = true
		_check(flower_keys.size() == 1, "premium: %s shows one symbol for all flowers" % collection_id)
		_check(board.face_width_on_screen() <= BoardView.MAX_FACE_WIDTH + 0.5, "premium: %s respects tile size cap" % collection_id)


	# Back to Classic restores the Classic layout; then finish in Animals by clicking.
	_check(manager.select("classic"), "premium: back to Classic")
	await _frames(3)
	_check(board.skin().style == TileArtSet.active(), "premium: Classic layout restored")
	_check(manager.select("animals"), "premium: Animals again")
	await _frames(3)
	await _click_control(screen.get_node("%UndoButton"))
	_check(model.remaining == model.tile_count(), "premium: undo after switching restores the pair")
	await _click_control(screen.get_node("%ShuffleButton"))
	_check(_all_tiles_have_art(board, model), "premium: shuffle in Animals keeps every tile drawn")
	await _click_control(screen.get_node("%UndoButton"))
	_check(model.faces == faces_before, "premium: undo reverts the shuffle")
	for pair in deal.solution:
		await _click_tile(screen, pair.x)
		await _click_tile(screen, pair.y)
	_check(model.is_cleared(), "premium: level %d cleared by clicking in Animals (flowers matched)" % level_number)

	# The choice persists for the next launch.
	var restarted: Node = load("res://scripts/autoload/tile_collection_manager.gd").new()
	restarted.settings_path = manager.settings_path
	restarted.reload_library(PackedStringArray([TileCollectionLibrary.SHIPPED_DIR]))
	restarted.restore()
	_check(restarted.selected_id == "animals", "premium: Animals restored on next launch")
	restarted.free()
	manager.select("classic")
	screen.queue_free()
	await _frames(2)


## Losing: the clock counts down only while playing, non-matching pairs cost
## hearts, and running out of either ends the level with Retry / Home.
func _test_time_and_mistakes(level_number: int) -> void:
	var level := LevelCatalog.get_level(level_number)
	var screen := await _open_level(level_number)
	var model: BoardModel = screen.get("_model")
	var time_label: Label = screen.get_node("%TimeValue")
	var dialog: ModalDialog = screen.get_node("%Dialog")
	_check(time_label.text == "%d:%02d" % [level.time_limit / 60, level.time_limit % 60], "clock starts at the level's limit (%s)" % time_label.text)
	_check((screen.get_node("%Hearts") as Control).get_child_count() == level.mistake_limit, "one heart per allowed mistake")
	var start := float(screen.get("_time_left"))
	await get_tree().create_timer(1.1).timeout
	var after := float(screen.get("_time_left"))
	_check(start - after > 0.9 and start - after < 1.5, "clock counts down while playing (%.2f s)" % (start - after))
	await _click_control(screen.get_node("%PauseButton"))
	var paused_at := float(screen.get("_time_left"))
	await get_tree().create_timer(0.8).timeout
	_check(absf(float(screen.get("_time_left")) - paused_at) < 0.05, "clock stops while paused")
	(_dialog_button(dialog, "Resume") as Button).emit_signal("pressed")
	await _frames(2)

	# A wrong pair costs a heart; re-tapping the selected tile is free.
	var wrong := _non_matching_free_pair(model)
	_check(wrong.x >= 0, "board has two free tiles that don't match")
	await _click_tile(screen, wrong.x)
	await _click_tile(screen, wrong.x)
	_check(int(screen.get("_mistakes")) == 0, "deselecting is not a mistake")
	await _click_tile(screen, wrong.x)
	await _click_tile(screen, wrong.y)
	_check(int(screen.get("_mistakes")) == 1, "a non-matching pair is a mistake")
	_check(int(screen.get("_selected")) == -1, "a mistake clears the selection")
	_check(int(screen.call("hearts_left")) == level.mistake_limit - 1, "a heart is spent")
	var blocked := -1
	for i in model.tile_count():
		if not model.is_removed(i) and not model.is_free(i):
			blocked = i
			break
	await _click_tile(screen, blocked)
	_check(int(screen.get("_mistakes")) == 1, "tapping a blocked tile is not a mistake")
	await _click_control(screen.get_node("%UndoButton"))
	_check(int(screen.get("_mistakes")) == 1, "undo does not refund a mistake")

	for i in level.mistake_limit - 1:
		await get_tree().create_timer(0.25).timeout
		await _click_tile(screen, wrong.x)
		await _click_tile(screen, wrong.y)
	_check(dialog.visible and (dialog.get_node("%Title") as Label).text == "Too Many Mistakes", "last heart loses the level")
	_check(_dialog_button(dialog, "Retry") != null and _dialog_button(dialog, "Levels") != null, "loss offers Retry and Levels")
	var frozen := float(screen.get("_time_left"))
	await get_tree().create_timer(0.5).timeout
	_check(absf(float(screen.get("_time_left")) - frozen) < 0.05, "clock stops after losing")
	await _click_control(_dialog_button(dialog, "Retry"))
	await _frames(2)
	_check(int(screen.get("_mistakes")) == 0 and not bool(screen.get("_failed")), "retry restores every heart")
	_check(float(screen.get("_time_left")) > level.time_limit - 1.0, "retry restores the clock")
	var retried: BoardModel = screen.get("_model")
	_check(retried.remaining == retried.tile_count(), "retry deals the full board again")

	# Running out of time loses the level.
	screen.set("_time_left", 0.3)
	await get_tree().create_timer(0.6).timeout
	_check(dialog.visible and (dialog.get_node("%Title") as Label).text == "Out of Time", "clock reaching zero loses the level")
	_check(time_label.text == "0:00", "clock shows 0:00")
	var deal := _expected_deal(level_number)
	await _click_tile(screen, deal.solution[0].x)
	_check(int(screen.get("_selected")) == -1, "board is locked after losing")
	screen.queue_free()
	await _frames(2)


## The journey map, stars earned on clears, unlocking and best results.
func _test_journey_and_stars() -> void:
	GameSession.progress.reset()
	var journey: Control = JOURNEY_SCENE.instantiate()
	_frame.add_child(journey)
	await _frames(4)
	var dialog: ModalDialog = journey.get_node("%Dialog")
	_check((journey.get_node("%StarsValue") as Label).text == "0 / 30", "fresh journey shows 0 / 30 stars")
	var level_one: LevelNode = journey.call("level_node", 1)
	var level_three: LevelNode = journey.call("level_node", 3)
	_check(level_one.unlocked and not (journey.call("level_node", 2) as LevelNode).unlocked, "only level 1 is open")
	await _click_at(level_three.get_global_transform() * level_three.marker_center())
	_check(not dialog.visible and (journey.get_node("%Toast") as Control).visible, "a locked level explains instead of opening")
	await _click_at(level_one.get_global_transform() * level_one.marker_center())
	_check(dialog.visible and (dialog.get_node("%Title") as Label).text == "Level 1 · Lotus Pond", "tapping level 1 opens its card")
	var card_text := (dialog.get_node("%Message") as Label).text
	_check(card_text.contains("Easy") and card_text.contains("24 tiles") and card_text.contains("3:00") and card_text.contains("5 hearts"),
		"card shows difficulty, size, time and hearts")
	_check(card_text.contains("Not cleared yet") and dialog.call("stars_shown") == 0, "card shows no stars before a clear")
	_check(_dialog_button(dialog, "Play") != null, "card offers Play")
	dialog.close()
	journey.queue_free()
	await _frames(2)

	# Clear level 1 perfectly: 3 stars, level 2 unlocked.
	await _clear_level_by_clicking(1, 0)
	_check(GameSession.progress.stars(1) == 3, "a perfect clear earns 3 stars")
	_check(GameSession.progress.is_unlocked(2) and GameSession.just_unlocked == 2, "clearing level 1 unlocks level 2")
	# Clear level 2 with one mistake: 2 stars.
	await _clear_level_by_clicking(2, 1)
	_check(GameSession.progress.stars(2) == 2, "one mistake earns 2 stars (got %d)" % GameSession.progress.stars(2))
	# Replay level 1 with two mistakes: best stays 3.
	await _clear_level_by_clicking(1, 2)
	_check(GameSession.progress.stars(1) == 3, "a worse replay keeps the best stars")

	GameSession.just_unlocked = 3
	journey = JOURNEY_SCENE.instantiate()
	_frame.add_child(journey)
	await _frames(4)
	_check((journey.get_node("%StarsValue") as Label).text == "5 / 30", "journey total shows 5 stars")
	_check((journey.call("level_node", 3) as LevelNode).unlocked, "level 3 is open after clearing level 2")
	_check((journey.get_node("%Toast") as Control).visible and GameSession.just_unlocked == 0, "a new unlock is announced once")
	# Dragging up pushes the path away: travel back. Dragging down travels forward.
	var world: JourneyWorld = journey.get_node("%World")
	var level_two: LevelNode = journey.call("level_node", 2)
	_check(not world.is_level_visible(1), "level 2 is behind the camera when the journey is at level 3")
	var camera_before := world.camera
	await _drag(world.get_global_rect().get_center(), Vector2(0, 420))
	_check(world.camera < camera_before - 0.5, "swiping up travels back along the path (%.2f -> %.2f)" % [camera_before, world.camera])
	var back_at := world.camera
	await _drag(world.get_global_rect().get_center(), Vector2(0, -300))
	_check(world.camera > back_at + 0.3, "swiping down travels forward (%.2f -> %.2f)" % [back_at, world.camera])
	_check(not (journey.get_node("%Dialog") as ModalDialog).visible, "a swipe that starts on the map opens no card")
	world.focus_level(2, false)
	await _frames(2)
	_check(world.is_level_visible(1), "level 2 comes into view")
	var near_scale := level_two.scale.x
	var far_scale := (journey.call("level_node", 5) as LevelNode).scale.x
	_check(near_scale > far_scale * 1.5, "nearer levels are drawn larger (%.2f vs %.2f)" % [near_scale, far_scale])
	await _click_at(level_two.get_global_transform() * level_two.marker_center())
	dialog = journey.get_node("%Dialog")
	_check(dialog.call("stars_shown") == 2 and (dialog.get_node("%Message") as Label).text.contains("Best: 2 of 3 stars"),
		"card shows the best result")
	journey.queue_free()
	await _frames(2)


## Regression checks for the October 2026 audit fixes (docs/AUDIT.md).
func _test_audit_fixes(level_number: int) -> void:
	var screen := await _open_level(level_number)
	var board: BoardView = screen.get_node("%Board")
	var model: BoardModel = screen.get("_model")
	var dialog: ModalDialog = screen.get_node("%Dialog")
	var pair: Vector2i = _expected_deal(level_number).solution[0]

	# Undo straight after a match, while the match animation still plays.
	await _click_tile(screen, pair.x)
	await _click_tile(screen, pair.y)
	_check(board.tile(pair.x).is_removing(), "the match animation is playing")
	screen.call("_on_undo_pressed")
	await get_tree().create_timer(0.5).timeout
	var restored := true
	for i in [pair.x, pair.y]:
		var view := board.tile(i)
		restored = restored and view.visible and view.modulate.a > 0.99 and view.mouse_filter == Control.MOUSE_FILTER_STOP
	_check(restored and not model.is_removed(pair.x), "undo during the match animation leaves both tiles visible and tappable")
	await _click_tile(screen, pair.x)
	_check(int(screen.get("_selected")) == pair.x, "a restored tile can be picked again")
	await _click_tile(screen, pair.x)

	# The clock: a long stall costs at most one step, and play time is counted
	# separately from the countdown (which a second chance resets).
	var before := float(screen.get("_time_left"))
	screen.call("_process", 5.0)
	_check(before - float(screen.get("_time_left")) <= 0.26, "a stalled frame costs at most a quarter second")
	var played := float(screen.call("elapsed_seconds"))
	screen.set("_time_left", 60.0)
	screen.call("_process", 0.2)
	_check(absf(float(screen.call("elapsed_seconds")) - played - 0.2) < 0.01, "play time keeps counting after the clock is reset")

	# Losing focus (another tab, split screen, notification shade) pauses.
	screen.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(dialog.visible and (dialog.get_node("%Title") as Label).text == "Paused", "losing focus pauses the level")
	var paused_at := float(screen.get("_time_left"))
	screen.call("_process", 0.2)
	_check(float(screen.get("_time_left")) == paused_at, "the clock stops while paused")
	# Android back: resumes from Pause, pauses from the board.
	screen.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not dialog.visible, "back on the pause menu resumes")
	screen.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(dialog.visible and (dialog.get_node("%Title") as Label).text == "Paused", "back during play pauses")
	(_dialog_button(dialog, "Settings") as Button).emit_signal("pressed")
	await _frames(1)
	var settings: Control = screen.get_node("%AudioSettings")
	_check(settings.visible, "settings open from pause")
	screen.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not settings.visible and not dialog.visible, "back closes settings and returns to the game, no pause menu underneath")
	screen.queue_free()
	await _frames(2)

	# Title screen: back closes the tile picker first.
	GameSession.scene_changes_enabled = false
	var startup: Control = STARTUP_SCENE.instantiate()
	_frame.add_child(startup)
	await _frames(2)
	var picker: Control = startup.get_node("%CollectionPicker")
	(startup.get_node("%CollectionButton") as Button).emit_signal("pressed")
	_check(picker.visible, "tile picker opens on the title screen")
	startup.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not picker.visible, "back closes the tile picker")
	startup.queue_free()
	GameSession.scene_changes_enabled = true
	await _frames(2)

	# Journey: repeated taps on a locked level don't push its marker away,
	# and swiping inside the level card doesn't move the map behind it.
	GameSession.progress.reset()
	var journey: Control = JOURNEY_SCENE.instantiate()
	_frame.add_child(journey)
	await _frames(4)
	var locked: LevelNode = journey.call("level_node", 2)
	var marker: Control = locked.get_node("%Marker")
	var home_x := marker.position.x
	for i in 3:
		locked.play_locked_nudge()
		await get_tree().create_timer(0.07).timeout
	await get_tree().create_timer(0.4).timeout
	_check(is_equal_approx(marker.position.x, home_x), "a locked marker returns to its spot after repeated taps")
	var world: JourneyWorld = journey.get_node("%World")
	var level_one: LevelNode = journey.call("level_node", 1)
	await _click_at(level_one.get_global_transform() * level_one.marker_center())
	var card: ModalDialog = journey.get_node("%Dialog")
	_check(card.visible, "level card is open")
	var camera_before := world.camera
	await _drag(world.get_global_rect().get_center(), Vector2(0, -300))
	_check(is_equal_approx(world.camera, camera_before), "swiping on the open card leaves the map still")
	journey.queue_free()
	await _frames(2)


func _drag(from: Vector2, delta: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	get_viewport().push_input(press, true)
	await _frames(1)
	var steps := 10
	for k in steps:
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.relative = -delta / steps
		motion.position = from - delta * (k + 1) / steps
		motion.global_position = motion.position
		get_viewport().push_input(motion, true)
		await _frames(1)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = from - delta
	release.global_position = release.position
	get_viewport().push_input(release, true)
	await _frames(2)


## Plays a level to the end by clicking, making `mistakes` wrong pairs first.
func _clear_level_by_clicking(level_number: int, mistakes: int) -> void:
	var screen := await _open_level(level_number)
	var model: BoardModel = screen.get("_model")
	for i in mistakes:
		var wrong := _non_matching_free_pair(model)
		await _click_tile(screen, wrong.x)
		await _click_tile(screen, wrong.y)
		await get_tree().create_timer(0.25).timeout
	for pair in _expected_deal(level_number).solution:
		await _click_tile(screen, pair.x)
		await _click_tile(screen, pair.y)
	await _frames(3)
	var dialog: ModalDialog = screen.get_node("%Dialog")
	var expected := LevelRating.stars(float(screen.get("_time_left")), LevelCatalog.get_level(level_number).time_limit, mistakes)
	_check(dialog.call("stars_shown") == expected, "level %d complete dialog shows %d stars" % [level_number, expected])
	_check(_dialog_button(dialog, "Levels") != null, "level complete offers Levels")
	screen.queue_free()
	await _frames(2)


func _non_matching_free_pair(model: BoardModel) -> Vector2i:
	var free := model.free_tiles()
	for a in free:
		for b in free:
			if a != b and not TileCatalog.faces_match(model.faces[a], model.faces[b]):
				return Vector2i(a, b)
	return Vector2i(-1, -1)


func _all_tiles_have_art(board: BoardView, model: BoardModel) -> bool:
	for i in model.tile_count():
		if not model.is_removed(i) and not board.tile(i).has_art():
			return false
	return true


func _visual_keys(board: BoardView, model: BoardModel) -> PackedStringArray:
	var keys := PackedStringArray()
	for face in model.faces:
		keys.append(board.skin().visual_key(face))
	return keys


func _open_level(level_number: int) -> Control:
	GameSession.current_level = level_number
	var screen: Control = GAME_SCENE.instantiate()
	_frame.add_child(screen)
	await _frames(3)
	return screen


func _expected_deal(level_number: int) -> BoardGenerator.Result:
	var level := LevelCatalog.get_level(level_number)
	return BoardGenerator.generate(level.load_layout().build_geometry(), level.face_pool(), level.deal_seed)


func _click_tile(screen: Control, index: int) -> void:
	var board: BoardView = screen.get_node("%Board")
	var view := board.tile(index)
	await _click_at(view.get_global_transform() * view.face_center())


func _click_control(control: Control) -> void:
	await _click_at(control.get_global_rect().get_center())


func _click_at(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		get_viewport().push_input(event, true)
	await _frames(1)


func _tile_clear_of_buttons(screen: Control, dialog: ModalDialog) -> int:
	var board: BoardView = screen.get_node("%Board")
	var model: BoardModel = screen.get("_model")
	var buttons: Array[Rect2] = []
	for button in dialog.get_node("%Buttons").get_children():
		if button is Control and not button.is_queued_for_deletion():
			buttons.append((button as Control).get_global_rect().grow(8.0))
	for i in model.tile_count():
		if not model.is_free(i):
			continue
		var point := board.tile(i).get_global_transform() * board.tile(i).face_center()
		var under_button := false
		for rect in buttons:
			under_button = under_button or rect.has_point(point)
		if not under_button:
			return i
	return -1


func _dialog_button(dialog: ModalDialog, text: String) -> Button:
	for button in dialog.get_node("%Buttons").get_children():
		if button is Button and (button as Button).text == text and not button.is_queued_for_deletion():
			return button
	return null


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
