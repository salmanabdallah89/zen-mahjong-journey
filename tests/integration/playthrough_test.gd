extends Node
## Integration test: plays real levels on the actual game screen by pushing
## mouse clicks at tile positions, exercises Hint / Undo / Shuffle / Pause /
## Restart, checks the layout at several screen shapes and expects the Level
## Complete dialog at the end. Run:
##   godot --headless --path . res://tests/integration/playthrough_test.tscn
## Exits with code 1 on any failure.

const GAME_SCENE := preload("res://scenes/screens/game_screen.tscn")
const GameScreenScript := preload("res://scripts/screens/game_screen.gd")
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
	# Never read or write the player's real preferences; start on Classic
	# (a returning player: see _test_starting_collection for new players).
	SafeConfig.remove_all(ISOLATED_SETTINGS)
	GameSession.tutorial_settings_path = ISOLATED_SETTINGS
	GameSession.set_tutorial_seen("completed")
	TileCollectionManager.settings_path = ISOLATED_SETTINGS
	TileCollectionManager.restore()
	# Reduced-animation preference also goes to the throwaway settings file.
	Motion.settings_path = ISOLATED_SETTINGS
	Motion.restore()
	# These flows assume a returning player; the tutorial has its own test.
	GameSession.tutorial_settings_path = ISOLATED_SETTINGS
	GameSession.set_tutorial_seen("completed")
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
	await _test_score_and_milestones(10)
	await _test_full_playthrough(10)
	await _test_responsive_layout(10)
	await _test_small_board_keeps_margins(1)
	await _test_alternate_art_set(2)
	await _test_tile_collections(2)
	await _test_premium_collections(5)
	await _test_time_and_mistakes(2)
	await _test_journey_and_stars()
	await _test_audit_fixes(3)
	await _test_background_shading()
	await _test_tile_animations(4)
	await _test_reduced_motion(2)
	await _test_combo_feedback(4)
	await _test_special_tiles(5)
	await _test_starting_collection()
	await _test_zen_garden_tiles(10)
	await _test_tutorial()
	await _test_journey_readability()
	await _test_accessibility()
	await _test_long_journey()
	SafeConfig.remove_all(ISOLATED_SETTINGS)
	Motion.settings_path = UserSettings.DEFAULT_PATH
	Motion.restore()
	GameSession.tutorial_settings_path = UserSettings.DEFAULT_PATH
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
	var dialog: ModalDialog = screen.get_node("%Dialog")
	_check(not dialog.visible, "level %d: the last pair finishes before Level Complete" % level_number)
	await _wait_dialog(screen)
	_check(dialog.visible, "level %d: completion dialog shown" % level_number)
	var title: Label = dialog.get_node("%Title")
	var expected := "Level Complete!" if level_number < LevelCatalog.count() else "Journey Complete!"
	_check(title.text == expected, "level %d: dialog title is '%s' (got '%s')" % [level_number, expected, title.text])
	_check((screen.get_node("%TilesValue") as Label).text == "0", "level %d: HUD shows 0 tiles" % level_number)
	screen.queue_free()
	await _frames(2)


## Points, combo multiplier and bar, milestones and the score finale.
func _test_score_and_milestones(level_number: int) -> void:
	var screen := await _open_level(level_number)
	var model: BoardModel = screen.get("_model")
	var meter: ScoreMeter = screen.get_node("%ScoreMeter")
	var praise: ComboFeedback = screen.get_node("%FeedbackLane").get_node("Praise")
	var dialog: ModalDialog = screen.get_node("%Dialog")
	var solution := _expected_deal(level_number).solution
	_check(model.tile_count() > 2 * GameScreenScript.FINAL_TILES, "score test board is big enough for both milestones")
	_check(meter.score_shown() == 0 and meter.multiplier_text() == "", "score starts at 0 with no multiplier")

	await _click_tile(screen, solution[0].x)
	await _click_tile(screen, solution[0].y)
	_check(int(screen.call("match_points")) == 100, "a first match is 100 points")
	await get_tree().create_timer(0.5).timeout
	_check(_has_child_named(screen, "Points"), "points rise from the matched pair")
	await _click_tile(screen, solution[1].x)
	await _click_tile(screen, solution[1].y)
	_check(int(screen.call("match_points")) == 300, "a second match in a row is doubled")
	await _frames(2)
	_check(meter.multiplier_text() == "×2" and meter.combo_fraction() > 0.5, "the pill shows ×2 and a full combo bar")
	await get_tree().create_timer(1.4).timeout
	_check(meter.score_shown() == 300, "the score counts up as the points land (%d)" % meter.score_shown())
	screen.call("_on_undo_pressed")
	_check(int(screen.call("match_points")) == 100, "undo takes the match's points back")
	await _settle(screen)
	await get_tree().create_timer(0.8).timeout
	_check(meter.score_shown() == 100, "the score counts back down after undo")

	var half_seen := false
	var final_seen := false
	for k in range(1, solution.size()):
		var pair: Vector2i = solution[k]
		await _click_tile(screen, pair.x)
		await _click_tile(screen, pair.y)
		var crossed_half := not half_seen and model.remaining * 2 <= model.tile_count()
		var crossed_final := not final_seen and model.remaining == GameScreenScript.FINAL_TILES
		if crossed_half or crossed_final:
			# Bells (and so milestones) queue up behind fast taps: wait for it.
			var wanted := "Halfway there!" if crossed_half else "Last 10 tiles!"
			for t in 60:
				if praise.text() == wanted:
					break
				await get_tree().create_timer(0.1).timeout
			if crossed_half:
				half_seen = true
				_check(praise.text() == "Halfway there!", "halfway milestone shows (%s)" % praise.text())
				_check(_has_child_named(screen, "Sweep"), "a light sweep crosses the board at halfway")
			else:
				final_seen = true
				_check(praise.text() == "Last 10 tiles!", "last-tiles milestone shows (%s)" % praise.text())
				_check(AudioManager.music_duck() > 1.0, "the music swells for the last tiles")
	_check(half_seen and final_seen, "both milestones were reached")
	_check(model.is_cleared(), "score test level cleared")
	await _wait_dialog(screen)
	var time_left := float(screen.get("_time_left"))
	var expected := int(screen.call("match_points")) + LevelScore.time_bonus(time_left) + LevelScore.FLAWLESS_BONUS
	_check(int(screen.call("final_score")) == expected, "final score = matches + time bonus + flawless (%d vs %d)" % [int(screen.call("final_score")), expected])
	_check(GameSession.progress.best_score(level_number) == expected, "the best score is saved for the leaderboard")
	await get_tree().create_timer(3.0).timeout
	_check(dialog.score_text() == "Score %s" % ScoreMeter.format_points(expected), "Level Complete counts up to the score (%s)" % dialog.score_text())
	_check(meter.score_shown() == expected, "the pill ends on the final score, not the last match")
	screen.queue_free()
	await _frames(2)


func _has_child_named(root: Node, prefix: String) -> bool:
	for child in root.get_children():
		if str(child.name).begins_with(prefix):
			return true
	return false


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
	var board_view: BoardView = screen.get_node("%Board")
	_check(board_view.is_busy(), "the shuffle animates")
	await _click_control(undo)
	_check(model.faces != before, "tools wait while the shuffle animates")
	await _settle(screen)
	_check(_tiles_at_rest(board_view, model), "after the shuffle every tile is back in place and tappable")
	await _click_control(undo)
	_check(model.faces == before, "undo reverts the shuffle")
	await _settle(screen)

	# Three undos per attempt: two used, one left, then the button stays off.
	var undo_label: Label = screen.get_node("SafeArea/Layout/Toolbar/UndoTool/UndoLabel")
	_check(undo_label.text == "Undo (1)", "undo shows the undos left (%s)" % undo_label.text)
	await _click_tile(screen, first.x)
	await _click_tile(screen, first.y)
	await _click_control(undo)
	_check(not model.is_removed(first.x), "the last undo still works")
	_check(undo.disabled and undo_label.text == "Undo (0)", "after 3 undos the button is off")
	await _settle(screen)
	await get_tree().create_timer(0.6).timeout
	await _click_tile(screen, first.x)
	await _click_tile(screen, first.y)
	_check(model.is_removed(first.x) and undo.disabled, "no more undos this attempt, even after a new match")
	screen.call("_on_undo_pressed")
	_check(model.is_removed(first.x), "a fourth undo does nothing")
	await _settle(screen)

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
	_check(int(screen.call("undos_left")) == 3 and undo_label.text == "Undo (3)", "restart gives the 3 undos back")
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
		# Hearts live in the top bar, fully visible, with the level and controls.
		var hearts_rect := (screen.get_node("%Hearts") as Control).get_global_rect()
		_check(hud.get_global_rect().encloses(hearts_rect), "%s: hearts sit inside the top bar" % shape)
		_check(screen.get_global_rect().encloses(hud.get_global_rect()), "%s: the top bar is fully on screen" % shape)
		_check(hud.get_global_rect().size.y <= 240.0, "%s: the top bar stays compact (%.0f px)" % [shape, hud.get_global_rect().size.y])
		_check(not tiles_rect.intersects(hud.get_global_rect()), "%s: tiles clear of the top bar and hearts" % shape)
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
		_check(board.face_width_on_screen() <= board.max_face_width() + 0.5 and board.max_face_width() <= BoardView.MAX_FACE_WIDTH_TALL,
			"%s: level %d tiles capped at %.0f px" % [shape, level_number, board.max_face_width()])
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
	await _settle(screen)
	await _click_control(screen.get_node("%UndoButton"))
	await _settle(screen)
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

	for collection_id in ["zen_garden", "animals", "alphabet", "mixed", "fruits", "vegetables"]:
		_check(manager.select(collection_id), "premium: %s can be applied" % collection_id)
		await _frames(3)
		_check(board.skin().collection_id == collection_id, "premium: board shows %s" % collection_id)
		var body_style := "zen_ivory_v1" if collection_id == "zen_garden" else "ivory_body_v1"
		_check(board.skin().style.id == body_style, "premium: %s laid out on its tile body" % collection_id)
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
	await _settle(screen)
	await _click_control(screen.get_node("%UndoButton"))
	_check(model.faces == faces_before, "premium: undo reverts the shuffle")
	await _settle(screen)
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
	# Earlier tests clear level 10, which unlocks level 11: no pending unlock.
	GameSession.just_unlocked = 0
	var journey: Control = JOURNEY_SCENE.instantiate()
	_frame.add_child(journey)
	await _frames(4)
	var dialog: LevelSheet = journey.get_node("%Sheet")
	var total := LevelCatalog.count() * LevelRating.MAX_STARS
	_check((journey.get_node("%StarsValue") as Label).text == "0 / %d" % total, "fresh journey shows 0 / %d stars" % total)
	_check((journey.get_node("%PlayButton") as Button).text == "Play Level 1", "the Play button offers the next level")
	_check((journey.get_node("%Title") as Label).text == "Sakura Garden", "the header names the chapter in view")
	var level_one: LevelNode = journey.call("level_node", 1)
	var level_three: LevelNode = journey.call("level_node", 3)
	_check(level_one.unlocked and not (journey.call("level_node", 2) as LevelNode).unlocked, "only level 1 is open")
	await _click_at(level_three.get_global_transform() * level_three.marker_center())
	_check(not dialog.visible and (journey.get_node("%Toast") as Control).visible, "a locked level explains instead of opening")
	await _click_at(level_one.get_global_transform() * level_one.marker_center())
	_check(dialog.visible and dialog.title_text() == "Level 1 · Lotus Pond", "tapping level 1 opens its card")
	var card_text := dialog.summary_text()
	_check(card_text.contains("Easy") and card_text.contains("24 tiles") and card_text.contains("3:00") and card_text.contains("5 hearts"),
		"card shows difficulty, size, time and hearts")
	_check(card_text.contains("Not cleared yet") and dialog.call("stars_shown") == 0, "card shows no stars before a clear")
	_check(dialog.play_button().is_visible_in_tree(), "card offers Play")
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
	_check((journey.get_node("%StarsValue") as Label).text == "5 / %d" % (LevelCatalog.count() * LevelRating.MAX_STARS),
		"journey total shows 5 stars")
	_check((journey.call("level_node", 3) as LevelNode).unlocked, "level 3 is open after clearing level 2")
	_check((journey.get_node("%Toast") as Control).visible and GameSession.just_unlocked == 0, "a new unlock is announced once")
	# The map opens on the current level, with the lotus badge on it; the
	# badge walked there from the level just cleared (just_unlocked = 3).
	var world: JourneyWorld = journey.get_node("%World")
	var level_two: LevelNode = journey.call("level_node", 2)
	_check(world.is_level_visible(2) and not world.is_level_visible(9), "the map opens on the current level, the far levels off screen")
	await get_tree().create_timer(1.4).timeout
	_check(world.badge_position().distance_to(world.screen_point(2) + Vector2(0, -JourneyWorld.BADGE_LIFT)) < 2.0, "the lotus badge walks to the new level")
	# The path winds: neighbouring levels sit on different sides of the middle.
	var sides := 0
	for i in range(LevelCatalog.count() - 1):
		if signf(world.map_point(i).x - world.size.x / 2.0) != signf(world.map_point(i + 1).x - world.size.x / 2.0):
			sides += 1
	_check(sides >= 3, "the path winds from side to side (%d changes)" % sides)
	# Chapters follow the levels' own backgrounds, bottom up.
	var parts := world.chapters()
	_check(parts.size() >= 2 and parts[0]["first"] == 0 and parts[-1]["last"] == LevelCatalog.count() - 1,
		"the map is made of garden chapters covering every level")
	for part: Dictionary in parts:
		_check(LevelCatalog.get_level(int(part["first"]) + 1).background == part["background"], "chapter %s matches its levels" % part["background"])
	# Dragging up moves back down the map; dragging down travels forward (up).
	world.focus_level(3, false)
	await _frames(2)
	var camera_before := world.camera
	await _drag(world.get_global_rect().get_center(), Vector2(0, 420))
	_check(world.camera < camera_before - 0.5, "swiping up travels back along the path (%.2f -> %.2f)" % [camera_before, world.camera])
	var back_at := world.camera
	await _drag(world.get_global_rect().get_center(), Vector2(0, -300))
	_check(world.camera > back_at + 0.3, "swiping down travels forward (%.2f -> %.2f)" % [back_at, world.camera])
	_check(not (journey.get_node("%Sheet") as LevelSheet).visible, "a swipe that starts on the map opens no card")
	world.focus_level(2, false)
	await _frames(2)
	_check(world.is_level_visible(1), "level 2 comes into view")
	# Stops are reused while scrolling: ask for level 2's stop again.
	level_two = journey.call("level_node", 2)
	_check(level_two != null and level_two.level_number == 2 and level_two.scale.is_equal_approx(Vector2.ONE),
		"level 2 has its own stop, at one size")
	await _click_at(level_two.get_global_transform() * level_two.marker_center())
	dialog = journey.get_node("%Sheet")
	_check(dialog.call("stars_shown") == 2 and dialog.summary_text().contains("Best: 2 of 3 stars"),
		"card shows the best result")
	journey.queue_free()
	await _frames(2)


## Per-background shading: each level's scenery and board shade follow
## BackgroundStyle, and shading never touches the tiles themselves.
func _test_background_shading() -> void:
	for number in [1, 3, 5, 8]:
		var screen := await _open_level(number)
		var level := LevelCatalog.get_level(number)
		var background: TextureRect = screen.get_node("%Background")
		var board: BoardView = screen.get_node("%Board")
		_check(background.modulate.is_equal_approx(BackgroundStyle.scenery_tint(level.background)),
			"level %d: %s scenery shaded" % [number, level.background])
		_check(is_equal_approx(board.backdrop_strength, BackgroundStyle.board_shade(level.background)),
			"level %d: board shade %.2f" % [number, board.backdrop_strength])
		var model: BoardModel = screen.get("_model")
		var free_tile := model.free_tiles()[0]
		_check(board.tile(free_tile).modulate == Color.WHITE, "level %d: free tiles are not dimmed by the shading" % number)
		screen.queue_free()
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
	var card: LevelSheet = journey.get_node("%Sheet")
	_check(card.visible, "level card is open")
	var camera_before := world.camera
	await _drag(world.get_global_rect().get_center(), Vector2(0, -300))
	_check(is_equal_approx(world.camera, camera_before), "swiping on the open card leaves the map still")
	journey.queue_free()
	await _frames(2)


## Phase 2: tile animations show the model without ever blocking or
## corrupting it, and every interruption leaves the board at rest.
func _test_tile_animations(level_number: int) -> void:
	var screen := await _open_level(level_number)
	var board: BoardView = screen.get_node("%Board")
	var model: BoardModel = screen.get("_model")
	var solution := _expected_deal(level_number).solution

	# Select: the tile lifts and swells; picking it again settles it back.
	var pair: Vector2i = solution[0]
	var view := board.tile(pair.x)
	await _click_tile(screen, pair.x)
	await get_tree().create_timer(0.25).timeout
	var lift: Control = view.get_node("%Lift")
	_check(lift.position.y < -5.0 and lift.scale.x > 1.02, "a selected tile lifts and swells")
	await _click_tile(screen, pair.x)
	await get_tree().create_timer(0.25).timeout
	_check(is_zero_approx(lift.position.y) and lift.scale.is_equal_approx(Vector2.ONE), "deselecting settles it back")

	# Rapid taps on one tile never leave it stuck selected or out of place.
	for i in 9:
		await _click_tile(screen, pair.x)
	await get_tree().create_timer(0.3).timeout
	_check(int(screen.get("_selected")) == pair.x and view.highlight() == TileView.Highlight.SELECTED,
		"nine quick taps end selected, as the ninth tap says")
	await _click_tile(screen, pair.x)
	await get_tree().create_timer(0.25).timeout

	# Match: the pair glides together, then leaves; the model is updated at once.
	var b_view := board.tile(pair.y)
	var meet := board.meeting_points(pair.x, pair.y)
	var glides := not meet[0].is_equal_approx(view.home_position)
	var gap_before := view.position.distance_to(b_view.position)
	await _click_tile(screen, pair.x)
	await _click_tile(screen, pair.y)
	_check(model.is_removed(pair.x) and model.is_removed(pair.y), "the model removes the pair at once")
	_check(not (view.get_node("%Glow") as Control).visible, "a gliding tile drops its gold outline")
	await get_tree().create_timer(0.2).timeout
	_check(not glides or view.position.distance_to(b_view.position) < gap_before - 1.0,
		"the matched pair glides toward each other")
	await _click_tile(screen, pair.x)
	_check(int(screen.get("_selected")) != pair.x, "a leaving tile ignores taps")
	await get_tree().create_timer(0.6).timeout
	_check(not view.visible and not b_view.visible and view.z_index == 0, "the pair is gone after the animation")

	# Undo plays the match backwards: from the meeting point back home.
	screen.call("_on_undo_pressed")
	await _frames(2)
	_check(view.visible and (not glides or not view.position.is_equal_approx(view.home_position)),
		"undo starts where the pair met")
	await get_tree().create_timer(0.7).timeout
	_check(_tiles_at_rest(board, model), "after undo both tiles are home and tappable")

	# Mistake feedback settles completely.
	var wrong := _non_matching_free_pair(model)
	if wrong.x >= 0:
		await _click_tile(screen, wrong.x)
		await _click_tile(screen, wrong.y)
		await get_tree().create_timer(0.6).timeout
		var wrong_lift: Control = board.tile(wrong.x).get_node("%Lift")
		_check(is_zero_approx(wrong_lift.position.x) and int(screen.get("_selected")) == -1,
			"a mismatched pair shakes gently and settles, nothing selected")

	# Hint breathes, and clearing it puts the tiles back to rest.
	screen.call("_on_hint_pressed")
	var hint: Vector2i = screen.get("_hint")
	await get_tree().create_timer(0.5).timeout
	_check(hint.x >= 0 and board.tile(hint.x).highlight() == TileView.Highlight.HINT, "hint highlights a pair")
	screen.call("_clear_hint")
	await get_tree().create_timer(0.3).timeout
	if hint.x >= 0:
		var hint_lift: Control = board.tile(hint.x).get_node("%Lift")
		_check(hint_lift.scale.is_equal_approx(Vector2.ONE), "a cleared hint stops breathing")

	# Interruptions: match, then shuffle while the pair is still gliding, then
	# undo twice. The model and the tiles must agree throughout.
	await _click_tile(screen, solution[0].x)
	await _click_tile(screen, solution[0].y)
	screen.call("_on_shuffle_pressed")
	await _settle(screen)
	_check(not board.tile(solution[0].x).visible, "a pair matched just before a shuffle stays gone")
	screen.call("_on_undo_pressed")
	await _settle(screen)
	screen.call("_on_undo_pressed")
	await get_tree().create_timer(0.7).timeout
	_check(model.remaining == model.tile_count() and _tiles_at_rest(board, model),
		"shuffle mid-match and two undos leave every tile home and tappable")

	# Praise: three quick matches in a row show "Great! ×3" in the lane.
	AudioManager.reset_melody()
	var seq := AudioManager.event_seq
	for k in 3:
		var p: Vector2i = solution[k]
		await _click_tile(screen, p.x)
		await _click_tile(screen, p.y)
	# Praise appears when the third pair touches (bells ring in order,
	# spaced apart, so the third lands about 0.6 s after quick taps).
	await get_tree().create_timer(0.8).timeout
	var praise: ComboFeedback = screen.get_node("%FeedbackLane").get_node("Praise")
	_check(int(screen.call("combo_count")) == 3 and praise.text() == "Great!", "three quick matches praise Great!")
	_check(AudioManager.count_played("combo", seq) == 2, "Nice! and Great! each ring their cue")
	screen.queue_free()
	await _frames(2)

	# Level complete: one chime per earned star, as each star pops in.
	screen = await _open_level(1)
	seq = AudioManager.event_seq
	for p: Vector2i in _expected_deal(1).solution:
		screen.call("_on_tile_pressed", p.x)
		screen.call("_on_tile_pressed", p.y)
	await get_tree().create_timer(2.8).timeout
	var dialog: ModalDialog = screen.get_node("%Dialog")
	_check(AudioManager.count_played("star", seq) == int(dialog.call("stars_shown")), "each earned star rings once")
	_check(screen.get_node_or_null("Celebration") != null, "a petal shower celebrates the clear")
	screen.queue_free()
	await _frames(2)


## Reduced animations: no travel or bounce, quick fades, same game; the
## choice is saved and restored.
func _test_reduced_motion(level_number: int) -> void:
	Motion.set_reduced(true)
	Motion.reduced = false
	Motion.restore()
	_check(Motion.reduced, "reduced animations is saved and restored")
	var screen := await _open_level(level_number)
	var board: BoardView = screen.get_node("%Board")
	var model: BoardModel = screen.get("_model")
	var ambience: GardenAmbience = screen.get("_ambience")
	_check(ambience.particle_count() == 0 and ambience.has_rays(), "reduced: the garden keeps its still light, no petals or motes")
	var pair: Vector2i = _expected_deal(level_number).solution[0]
	var view := board.tile(pair.x)
	await _click_tile(screen, pair.x)
	await get_tree().create_timer(0.2).timeout
	_check((view.get_node("%Lift") as Control).scale.is_equal_approx(Vector2.ONE), "reduced: selection lifts without swelling")
	await _click_tile(screen, pair.y)
	await get_tree().create_timer(0.05).timeout
	_check(view.position.is_equal_approx(view.home_position), "reduced: matched tiles fade in place")
	await get_tree().create_timer(0.25).timeout
	_check(not view.visible, "reduced: the fade is quick")
	_check(not _has_child_named(screen, "Points") and int(screen.call("match_points")) > 0, "reduced: points count up without gliding")
	screen.call("_on_shuffle_pressed")
	await get_tree().create_timer(0.35).timeout
	_check(not board.is_busy() and _tiles_at_rest(board, model), "reduced: shuffle is a quick fade")
	Motion.set_reduced(false)
	_check(ambience.particle_count() > 0 and ambience.particle_count() <= AmbienceStyle.MAX_PARTICLES,
		"full motion brings back the petals and motes (%d)" % ambience.particle_count())
	_check(ambience.get_index() == (screen.get_node("%Background") as Node).get_index() + 1,
		"the garden layer sits right above the painting, under the board")
	screen.queue_free()
	await _frames(2)


## P3 combos: praise in the lane below the board, synced to contact, tiers
## that escalate, cues per new tier, and nothing ever over the tiles.
func _test_combo_feedback(level_number: int) -> void:
	var screen := await _open_level(level_number)
	var board: BoardView = screen.get_node("%Board")
	var model: BoardModel = screen.get("_model")
	var lane: Control = screen.get_node("%FeedbackLane")
	var praise: ComboFeedback = lane.get_node("Praise")
	var toast: Control = screen.get_node("%Toast")
	var solution := _expected_deal(level_number).solution

	# The lane sits right under the tiles on every screen shape; the board
	# and lane are centred together, and tiles are never smaller than the
	# old layout (lane fixed above the toolbar) gave them.
	for shape in SCREEN_SHAPES:
		_frame.size = shape
		await _frames(3)
		var tiles := _tiles_rect(board, model)
		var lane_rect := lane.get_global_rect()
		var area := board.get_global_rect()
		_check(not tiles.intersects(lane_rect), "%s: no tile reaches into the message lane" % shape)
		_check(lane_rect.size.y >= 130.0, "%s: the message lane keeps its height" % shape)
		_check(lane_rect.position.y - tiles.end.y <= shape.y * 0.05,
			"%s: lane follows the tiles (gap %.0f px)" % [shape, lane_rect.position.y - tiles.end.y])
		var above := tiles.position.y - area.position.y
		var below := area.end.y - lane_rect.end.y
		_check(absf(above - below) <= 40.0, "%s: spare height split above and below (%.0f / %.0f)" % [shape, above, below])
		_check(area.encloses(lane_rect.grow(-1.0)), "%s: the lane stays inside the board area" % shape)
		var old_scale := minf(minf(area.size.x * 0.95 / board.content_size().x,
			(area.size.y - 140.0) * 0.96 / board.content_size().y), BoardView.MAX_FACE_WIDTH / board.skin().style.face_rect.size.x)
		var old_width := old_scale * board.skin().style.face_rect.size.x
		_check(board.face_width_on_screen() >= old_width - 0.5,
			"%s: tiles not smaller than before (%.0f vs %.0f px)" % [shape, board.face_width_on_screen(), old_width])
	# Praise is centred in the lane and fully inside it on every shape.
	for shape in SCREEN_SHAPES:
		_frame.size = shape
		await _frames(3)
		praise.show_combo(10)
		await get_tree().create_timer(0.4).timeout
		var row: Control = praise.get_child(0)
		var text_rect := (row.get_child(0) as Control).get_global_rect().merge((row.get_child(1) as Control).get_global_rect())
		var lane_rect := lane.get_global_rect()
		_check(absf(text_rect.get_center().x - lane_rect.get_center().x) <= 4.0,
			"%s: praise is centred (%.0f vs %.0f)" % [shape, text_rect.get_center().x, lane_rect.get_center().x])
		_check(text_rect.position.x >= lane_rect.position.x and text_rect.end.x <= lane_rect.end.x,
			"%s: Zen Master! fits inside the lane" % shape)
		praise.dismiss()
	_frame.size = SCREEN_SHAPES[0]
	await _frames(3)

	# Toasts live in the lane too, clear of the tiles.
	screen.call("_show_toast", "A tile can be picked when its left or right side is open.")
	await _frames(2)
	_check(lane.get_global_rect().grow(1.0).encloses(toast.get_global_rect()), "a two-line toast fits inside the lane")
	_check(not toast.get_global_rect().intersects(_tiles_rect(board, model)), "the toast never covers a tile")

	# Ten quick matches: praise climbs Nice! → Great! → Amazing! → Excellent!
	# → Zen Master!, each tier's cue rings once, at contact, never before.
	AudioManager.reset_melody()
	var seq := AudioManager.event_seq
	var words := PackedStringArray()
	praise.shown.connect(func(_tier: int, word: String) -> void:
		if words.is_empty() or words[-1] != word:
			words.append(word))
	await _click_tile(screen, solution[0].x)
	await _click_tile(screen, solution[0].y)
	await _click_tile(screen, solution[1].x)
	await _click_tile(screen, solution[1].y)
	_check(not praise.is_showing(), "praise waits for the pair to touch")
	var most_rings := 0
	for k in range(2, 10):
		await _click_tile(screen, solution[k].x)
		await _click_tile(screen, solution[k].y)
		most_rings = maxi(most_rings, MatchBurst.active_rings)
		# Taps keep working while praise and bursts play.
		_check(model.is_removed(solution[k].x), "rapid match %d registers at once" % (k + 1))
	for f in 100:
		await _frames(1)
		most_rings = maxi(most_rings, MatchBurst.active_rings)
		var lane_bursts := lane.get_children().filter(func(c: Node) -> bool: return c is Node2D)
		for burst: Node in lane_bursts:
			if not burst.get("compact"):
				_check(false, "lane glints use the compact style")
	_check(most_rings <= MatchBurst.MAX_RINGS, "a fast streak never shows more than %d rings (%d)" % [MatchBurst.MAX_RINGS, most_rings])
	await get_tree().create_timer(0.4).timeout
	_check(words == PackedStringArray(["Nice!", "Great!", "Amazing!", "Excellent!", "Zen Master!"]),
		"praise escalates through every tier (%s)" % ", ".join(words))
	_check(AudioManager.count_played("combo", seq) == 5, "each new tier rings its cue once (%d)" % AudioManager.count_played("combo", seq))
	_check(_match_bells(seq) == 10, "every match still rings its bell (%d)" % _match_bells(seq))
	_check(lane.clip_contents, "lane effects are clipped to the lane")

	# Undo, shuffle and hint still behave; praise never blocks them.
	screen.call("_on_undo_pressed")
	await get_tree().create_timer(0.6).timeout
	_check(not model.is_removed(solution[9].x), "undo works after a long combo")
	screen.call("_on_shuffle_pressed")
	await _settle(screen)
	_check(_tiles_at_rest(board, model), "shuffle after a combo leaves every tile at rest")
	screen.call("_on_hint_pressed")
	_check((screen.get("_hint") as Vector2i).x >= 0, "hint works after a combo")
	# A toast takes the lane from praise.
	screen.call("_show_toast", "Tiles shuffled")
	_check(not praise.is_showing() and toast.visible, "a toast replaces praise in the lane")
	screen.queue_free()
	await _frames(2)

	# Reduced animations: praise still appears, as a plain fade.
	Motion.set_reduced(true)
	screen = await _open_level(level_number)
	praise = screen.get_node("%FeedbackLane").get_node("Praise")
	AudioManager.reset_melody()
	for k in 2:
		screen.call("_on_tile_pressed", solution[k].x)
		screen.call("_on_tile_pressed", solution[k].y)
	await get_tree().create_timer(0.3).timeout
	_check(praise.is_showing() and praise.text() == "Nice!" and is_zero_approx(praise.rotation),
		"reduced: praise fades in without pop or tilt")
	screen.queue_free()
	await _frames(2)
	Motion.set_reduced(false)


func _tiles_rect(board: BoardView, model: BoardModel) -> Rect2:
	var rect := Rect2()
	for i in model.tile_count():
		if model.is_removed(i):
			continue
		var view := board.tile(i)
		var r := view.get_global_transform() * board.skin().style.body_rect
		rect = r if rect.size == Vector2.ZERO else rect.merge(r)
	return rect


func _match_bells(since_seq: int) -> int:
	var count := 0
	for event in AudioManager.history:
		if int(event["seq"]) >= since_seq and event["id"] == "tile_match" and event["played"]:
			count += 1
	return count


## First-play tutorial: first-time vs returning players, skip, complete,
## replay, no penalties while learning, every collection, never unsolvable.
func _test_tutorial() -> void:
	const PATH := "user://test_tutorial.cfg"
	var saved_path := GameSession.tutorial_settings_path
	GameSession.tutorial_settings_path = PATH
	SafeConfig.remove_all(PATH)
	# A brand-new player: no progress either.
	GameSession.progress.reset()

	# A first-time player gets the tutorial on level 1, on the real board.
	var screen := await _open_level(1)
	var board: BoardView = screen.get_node("%Board")
	var model: BoardModel = screen.get("_model")
	var tutorial: FirstPlayTutorial = screen.get_node("%FeedbackLane").get_node("Tutorial")
	var lane: Control = screen.get_node("%FeedbackLane")
	_check(bool(screen.call("tutorial_active")) and tutorial.visible, "first play: tutorial starts on level 1")
	var pair := tutorial.pair
	_check(model.is_free(pair.x) and model.is_free(pair.y) and model.face_of(pair.x) == model.face_of(pair.y),
		"tutorial highlights a free, identical pair")
	_check(board.tile(pair.x).highlight() == TileView.Highlight.HINT and board.tile(pair.y).highlight() == TileView.Highlight.HINT,
		"both tiles of the pair glow")
	model.remove_pair(pair.x, pair.y)
	_check(BoardSolver.solve(model, 200000).solved, "the board stays solvable after the tutorial pair")
	model.restore_pair(pair.x, pair.y)
	_check(lane.get_global_rect().grow(1.0).encloses(tutorial.get_global_rect()), "the coach panel stays in the lane")
	_check(not tutorial.get_global_rect().intersects(_tiles_rect(board, model)), "the coach panel never covers tiles")
	var skip_button := _find_button(tutorial, "Skip")
	_check(skip_button != null and skip_button.size.y >= 120.0, "Skip is visible and easy to tap")
	var clock := float(screen.get("_time_left"))
	screen.call("_process", 1.0)
	_check(is_equal_approx(float(screen.get("_time_left")), clock), "the clock waits while the tutorial runs")

	# Step 1: pick one glowing tile, then a wrong one: no heart is lost.
	await _click_tile(screen, pair.x)
	_check(tutorial.text() == FirstPlayTutorial.TEXT_PARTNER, "after the first tile it asks for the partner")
	var wrong := -1
	for i in model.free_tiles():
		if i != pair.x and not TileCatalog.faces_match(model.faces[i], model.faces[pair.x]):
			wrong = i
			break
	await _click_tile(screen, wrong)
	_check(int(screen.call("hearts_left")) == LevelCatalog.get_level(1).mistake_limit, "a wrong pair costs no heart while learning")
	_check(board.tile(pair.y).highlight() == TileView.Highlight.HINT, "the pair keeps glowing after a mistake")
	await _click_tile(screen, pair.x)
	await _click_tile(screen, pair.y)
	_check(tutorial.step == FirstPlayTutorial.Step.FREE and tutorial.text() == FirstPlayTutorial.TEXT_FREE,
		"matching the pair moves on to free tiles")

	# Step 2: the player finds a pair on their own; step 3: the next move ends it.
	var own: Vector2i = model.available_matches()[0]
	await _click_tile(screen, own.x)
	await _click_tile(screen, own.y)
	_check(tutorial.step == FirstPlayTutorial.Step.TOOLS and _find_button(tutorial, "Start Playing") != null,
		"a pair found alone moves on to the tools")
	(_find_button(tutorial, "Start Playing") as Button).emit_signal("pressed")
	_check(not bool(screen.call("tutorial_active")) and GameSession.tutorial_seen(), "Start Playing completes and saves it")
	_check(str(UserSettings.new(PATH).get_value("tutorial", "outcome", "")) == "completed", "outcome saved as completed")
	clock = float(screen.get("_time_left"))
	screen.call("_process", 1.0)
	_check(float(screen.get("_time_left")) < clock, "the clock runs once the tutorial ends")
	screen.queue_free()
	await _frames(2)

	# A returning player is never interrupted; other levels never show it.
	for number in [1, 2]:
		screen = await _open_level(number)
		_check(not bool(screen.call("tutorial_active")), "returning player: no tutorial on level %d" % number)
		screen.queue_free()
		await _frames(2)

	# Skip: saved straight away, the game continues normally.
	SafeConfig.remove_all(PATH)
	screen = await _open_level(1)
	tutorial = screen.get_node("%FeedbackLane").get_node("Tutorial")
	(_find_button(tutorial, "Skip") as Button).emit_signal("pressed")
	await _frames(2)
	_check(not bool(screen.call("tutorial_active")) and GameSession.tutorial_seen(), "Skip ends the tutorial and saves it")
	_check(str(UserSettings.new(PATH).get_value("tutorial", "outcome", "")) == "skipped", "outcome saved as skipped")
	var glowing := 0
	for i in model.tile_count():
		if (screen.get("_model") as BoardModel).is_free(i) and (screen.get_node("%Board") as BoardView).tile(i).highlight() == TileView.Highlight.HINT:
			glowing += 1
	_check(glowing == 0, "skipping clears the tutorial glow")
	screen.queue_free()
	await _frames(2)

	# Replay from Settings: "How to Play" shows it again even though it was seen.
	GameSession.scene_changes_enabled = false
	screen = await _open_level(2)
	var settings: Control = screen.get_node("%AudioSettings")
	settings.call("open")
	(_find_button(settings, "How to Play") as Button).emit_signal("pressed")
	_check(GameSession.tutorial_requested and GameSession.last_requested_scene == GameSession.GAME_SCENE
		and GameSession.current_level == 1, "How to Play opens level 1 with the tutorial")
	screen.queue_free()
	await _frames(2)
	GameSession.scene_changes_enabled = true
	screen = await _open_level(1)
	_check(bool(screen.call("tutorial_active")), "replay: the tutorial runs again")
	(_find_button(screen.get_node("%FeedbackLane").get_node("Tutorial"), "Skip") as Button).emit_signal("pressed")
	_check(not GameSession.tutorial_requested, "the replay request is used once")
	screen.queue_free()
	await _frames(2)

	# A player who cleared level 1 before the tutorial existed (no tutorial
	# state saved) is returning: no interruption. How to Play still shows it.
	SafeConfig.remove_all(PATH)
	GameSession.progress.record_clear(1, 2, 30.0, LevelCatalog.count())
	screen = await _open_level(1)
	_check(not bool(screen.call("tutorial_active")), "existing player who cleared level 1: no tutorial")
	screen.queue_free()
	await _frames(2)
	GameSession.tutorial_requested = true
	screen = await _open_level(1)
	_check(bool(screen.call("tutorial_active")), "existing player: How to Play still shows it")
	(_find_button(screen.get_node("%FeedbackLane").get_node("Tutorial"), "Skip") as Button).emit_signal("pressed")
	screen.queue_free()
	await _frames(2)
	GameSession.progress.reset()

	# Every collection: the highlighted pair shows the same picture.
	var manager: Node = TileCollectionManager
	for collection_id in ["zen_garden", "classic", "animals", "fruits", "vegetables", "alphabet", "mixed"]:
		manager.select(collection_id)
		SafeConfig.remove_all(PATH)
		screen = await _open_level(1)
		board = screen.get_node("%Board")
		model = screen.get("_model")
		tutorial = screen.get_node("%FeedbackLane").get_node("Tutorial")
		var keys := [board.skin().visual_key(model.face_of(tutorial.pair.x)), board.skin().visual_key(model.face_of(tutorial.pair.y))]
		_check(tutorial.visible and keys[0] == keys[1] and board.tile(tutorial.pair.x).has_art(),
			"%s: tutorial pair looks identical" % collection_id)
		screen.queue_free()
		await _frames(2)
	manager.select("classic")
	SafeConfig.remove_all(PATH)
	GameSession.tutorial_settings_path = saved_path


func _find_button(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text and (node as Button).is_visible_in_tree():
			return node
	return null


## A 1000-level journey: only the stops on screen exist, far levels can be
## reached, the backdrop follows the chapter, and nothing breaks at the ends.
func _test_long_journey() -> void:
	GameSession.progress.reset()
	GameSession.just_unlocked = 0
	var journey: Control = JOURNEY_SCENE.instantiate()
	_frame.add_child(journey)
	await _frames(4)
	var world: JourneyWorld = journey.get_node("%World")
	var stops := func() -> int:
		return world.get_children().filter(func(c: Node) -> bool: return c is LevelNode).size()
	_check(world.level_count == LevelRecipe.TOTAL_LEVELS, "the map spans all %d levels" % LevelRecipe.TOTAL_LEVELS)
	var built_at_start: int = stops.call()
	for number in [237, 640, 1000, 1, 512]:
		world.focus_level(number, false)
		await _frames(1)
		var node: LevelNode = journey.call("level_node", number)
		_check(node != null and node.level_number == number, "level %d has its stop when in view" % number)
		var chapter := LevelRecipe.chapter_of(number)
		var back: TextureRect = world.get_node("Backdrop")
		_check(back.texture.resource_path.contains(LevelRecipe.garden_of_chapter(int(world.chapter_at_camera().x))),
			"level %d: the backdrop shows the chapter's garden" % number)
		_check(absi(int(world.chapter_at_camera().x) - chapter) <= 1, "level %d: the camera is in its chapter" % number)
	_check(stops.call() <= built_at_start + 4 and stops.call() <= 16, "stops are reused, not built per level (%d)" % stops.call())
	# Locked far levels say so; tapping one explains instead of opening.
	world.focus_level(640, false)
	await _frames(2)
	var far: LevelNode = journey.call("level_node", 640)
	_check(far.is_padlocked(), "level 640 starts locked")
	await _click_at(far.get_global_transform() * far.marker_center())
	_check(not (journey.get_node("%Sheet") as Control).visible, "a far locked level does not open")
	journey.queue_free()
	await _frames(2)


## Waits for the Level Complete dialog: it opens once the last pair has met.
func _wait_dialog(screen: Control) -> void:
	var dialog: ModalDialog = screen.get_node("%Dialog")
	var waited := 0.0
	while not dialog.visible and waited < 3.0:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	await _frames(2)


## Waits until a running shuffle has settled (tiles ignore taps until then).
func _settle(screen: Control) -> void:
	var board: BoardView = screen.get_node("%Board")
	for i in 120:
		if not board.is_busy():
			break
		await _frames(1)
	await _frames(1)


## Every tile still on the board is visible, unscaled, at its home spot and
## takes taps; no animation left it stuck.
func _tiles_at_rest(board: BoardView, model: BoardModel) -> bool:
	for i in model.tile_count():
		if model.is_removed(i):
			continue
		var view := board.tile(i)
		if not view.visible or view.mouse_filter != Control.MOUSE_FILTER_STOP or view.is_moving() 				or not view.position.is_equal_approx(view.home_position) or not view.scale.is_equal_approx(Vector2.ONE) 				or view.modulate.a < 0.99:
			return false
	return true


## Journey map readability: plates never overlap nearer levels, states are
## told apart without colour, at every screen shape.
func _test_journey_readability() -> void:
	GameSession.progress.reset()
	GameSession.just_unlocked = 0
	GameSession.progress.record_clear(1, 3, 120.0, 10)
	GameSession.progress.record_clear(2, 1, 20.0, 10)
	for shape in SCREEN_SHAPES:
		_frame.size = shape
		var journey: Control = JOURNEY_SCENE.instantiate()
		_frame.add_child(journey)
		await _frames(4)
		var world: JourneyWorld = journey.get_node("%World")
		var shown: Array[LevelNode] = []
		for number in range(1, 40):
			var node: LevelNode = journey.call("level_node", number)
			if node != null and node.visible:
				shown.append(node)
		var clean := true
		for a in shown:
			if not a.labels_shown():
				continue
			for b in shown:
				if b != a and b.get_index() > a.get_index() and b.marker_rect().intersects(a.label_rect()):
					clean = false
		_check(clean, "%s: no name plate sits under a nearer marker" % shape)
		var current: LevelNode = journey.call("level_node", 3)
		_check(current.labels_shown(), "%s: the current level always shows its name" % shape)
		var cleared: LevelNode = journey.call("level_node", 1)
		var locked: LevelNode = journey.call("level_node", 4)
		_check((cleared.get_node("%Stars") as Control).visible, "%s: a cleared level shows its stars" % shape)
		_check(not (current.get_node("%Stars") as Control).visible and (current.get_node("%Difficulty") as Label).text != "LOCKED",
			"%s: an unplayed level shows only its difficulty" % shape)
		_check(locked.is_padlocked() and not locked.labels_shown(), "%s: a locked level shows a padlock (not colour alone)" % shape)
		_check(not current.is_padlocked() and not cleared.is_padlocked(), "%s: open levels have no padlock" % shape)
		_check((current.get_node("%Title") as Label).get_theme_font_size("font_size") >= 36, "%s: level names are large" % shape)
		world.focus_level(3, false)
		journey.queue_free()
		await _frames(2)
	_frame.size = SCREEN_SHAPES[0]
	GameSession.progress.reset()


## Accessibility: touch targets, text size, panels on short screens, and
## decoration that follows Reduced Animations.
func _test_accessibility() -> void:
	var screen := await _open_level(2)
	var settings: Control = screen.get_node("%AudioSettings")
	settings.call("open")
	await _frames(3)
	var small := PackedStringArray()
	for root: Node in [screen.get_node("SafeArea"), settings]:
		for node in root.find_children("*", "BaseButton", true, false):
			var control := node as Control
			if control.is_visible_in_tree() and control.get_global_rect().size.y < 119.5:
				small.append("%s %.0f" % [control.name, control.get_global_rect().size.y])
		for node in root.find_children("*", "Slider", true, false):
			var slider := node as Control
			if slider.is_visible_in_tree() and slider.get_global_rect().size.y < 119.5:
				small.append("%s %.0f" % [slider.name, slider.get_global_rect().size.y])
	_check(small.is_empty(), "every button and slider is at least 120 px tall (%s)" % ", ".join(small))
	var panel: Control = settings.get_node("Center/Panel")
	_check(screen.get_global_rect().encloses(panel.get_global_rect()), "Settings fits the shortest screen (1080 x 1920 canvas, as 320 x 568)")
	var caption: Label = screen.get_node("SafeArea/Layout/Hud/Row/TimeBox/TimeCaption")
	_check(caption.get_theme_font_size("font_size") >= 30, "HUD captions are at least 30 px")
	settings.call("close")
	screen.queue_free()
	await _frames(2)
	Motion.set_reduced(true)
	var journey: Control = JOURNEY_SCENE.instantiate()
	_frame.add_child(journey)
	await _frames(3)
	_check(not (journey.get_node("Petals") as CPUParticles2D).emitting, "journey petals stop with reduced animations")
	journey.queue_free()
	await _frames(2)
	Motion.set_reduced(false)


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
	await _wait_dialog(screen)
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


## Mystery tiles lie face-down until uncovered, then turn over; the golden
## lotus pair glows, wears a badge and scores double.
func _test_special_tiles(level_number: int) -> void:
	var screen := await _open_level(level_number)
	var board: BoardView = screen.get_node("%Board")
	var model: BoardModel = screen.get("_model")
	var specials: TileSpecials = screen.call("specials")
	var deal := _expected_deal(level_number)
	_check(model.faces == deal.faces, "specials: the deal is unchanged")
	var face_down := 0
	var golden := 0
	for i in model.tile_count():
		face_down += 1 if board.tile(i).is_face_down() else 0
		golden += 1 if board.tile(i).is_golden() else 0
		if board.tile(i).is_face_down() and model.is_free(i):
			_check(false, "specials: free tile %d starts face-down" % i)
	_check(face_down > 0 and face_down == specials.mystery.size(), "specials: %d tiles start face-down" % face_down)
	_check(golden == 2, "specials: one golden lotus pair glows (%d)" % golden)
	var badge := board.tile(specials.golden.keys()[0]).get_node("Lift/GoldenBadge") as Label
	_check(badge.visible and badge.text == "×2", "specials: the golden tile wears a ×2 badge")
	var golden_points := 0
	for pair in deal.solution:
		var before := int(screen.call("match_points"))
		await _click_tile(screen, pair.x)
		await _click_tile(screen, pair.y)
		if specials.is_golden(pair.x):
			golden_points = int(screen.call("match_points")) - before
		await get_tree().create_timer(0.05).timeout
		for i in model.tile_count():
			if not model.is_removed(i) and model.is_free(i) and specials.is_mystery(i):
				_check(false, "specials: free tile %d stayed face-down" % i)
				break
	_check(golden_points > 0 and golden_points % (LevelScore.MATCH_POINTS * TileSpecials.GOLDEN_FACTOR) == 0,
		"specials: the golden pair scored double (%d)" % golden_points)
	_check(model.is_cleared() and specials.mystery.is_empty(), "specials: every face-down tile turned over on the way")
	screen.queue_free()
	await _frames(2)


## New players start on Zen Garden; anyone who has played keeps Classic; a
## saved choice always wins. The answer is saved, so it never changes later.
func _test_starting_collection() -> void:
	var manager := TileCollectionManager
	var real_settings := manager.settings_path
	var real_tutorial := GameSession.tutorial_settings_path
	var test_settings := "user://test_settings_starting.cfg"
	manager.settings_path = test_settings
	GameSession.tutorial_settings_path = test_settings

	SafeConfig.remove_all(test_settings)
	GameSession.progress.reset()
	manager.restore()
	_check(manager.selected_id == "zen_garden", "start: a new player gets Zen Garden")
	GameSession.progress.record_clear(1, 3, 100.0, LevelCatalog.count(), 1000)
	GameSession.set_tutorial_seen("completed")
	manager.restore()
	_check(manager.selected_id == "zen_garden", "start: the new player keeps it after playing")

	SafeConfig.remove_all(test_settings)
	manager.restore()
	_check(manager.selected_id == "classic", "start: a returning player who never chose keeps Classic")
	GameSession.progress.reset()
	manager.restore()
	_check(manager.selected_id == "classic", "start: that answer is saved")

	SafeConfig.remove_all(test_settings)
	GameSession.set_tutorial_seen("skipped")
	manager.restore()
	_check(manager.selected_id == "classic", "start: having seen the tutorial counts as returning")

	SafeConfig.remove_all(test_settings)
	UserSettings.new(test_settings).set_value(manager.SETTINGS_SECTION, manager.SETTINGS_KEY, "animals")
	manager.restore()
	_check(manager.selected_id == "animals", "start: a saved choice is kept")

	SafeConfig.remove_all(test_settings)
	manager.settings_path = real_settings
	GameSession.tutorial_settings_path = real_tutorial
	manager.restore()


## Zen Garden: symbols sit on the porcelain body, stacks shift by the tile's
## thickness, and face-down tiles show the whole jade back in the body's frame.
func _test_zen_garden_tiles(level_number: int) -> void:
	var manager := TileCollectionManager
	_check(manager.select("zen_garden"), "zen: Zen Garden can be applied")
	var screen := await _open_level(level_number)
	var board: BoardView = screen.get_node("%Board")
	var model: BoardModel = screen.get("_model")
	var skin := board.skin()
	_check(skin.style.id == "zen_ivory_v1", "zen: the board uses the porcelain style (%s)" % skin.style.id)
	_check(skin.style.layer_shift == Vector2(-15, -24), "zen: layers shift by the tile's edge")
	var seen := {}
	for i in model.tile_count():
		var view := board.tile(i)
		_check(view.has_art(), "zen: tile %d has art" % i)
		if view.is_face_down():
			var cover := view.get_node("Lift/Cover") as TextureRect
			if cover.size != skin.style.image_size or cover.position != Vector2.ZERO:
				_check(false, "zen: tile %d back is out of frame" % i)
		var symbol := skin.symbol_texture(model.face_of(i))
		var group := TileCatalog.match_group(model.face_of(i))
		if seen.has(group) and seen[group] != symbol:
			_check(false, "zen: group %s shows two pictures" % group)
		seen[group] = symbol
	var deal := _expected_deal(level_number)
	_check(model.faces == deal.faces, "zen: the deal does not depend on the look")
	for pair in deal.solution:
		await _click_tile(screen, pair.x)
		await _click_tile(screen, pair.y)
		await get_tree().create_timer(0.03).timeout
	_check(model.is_cleared(), "zen: tiles are tapped exactly where they are drawn")
	screen.queue_free()
	await _frames(2)
	manager.select("classic")


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
