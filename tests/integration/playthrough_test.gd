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


func _ready() -> void:
	_frame = Control.new()
	_frame.size = SCREEN_SHAPES[0]
	add_child(_frame)
	await _test_full_playthrough(1)
	await _test_tools_and_pause(3)
	await _test_full_playthrough(10)
	await _test_responsive_layout(10)
	await _test_small_board_keeps_margins(1)
	await _test_alternate_art_set(2)
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
	var free_tile := deal.solution[0].x
	await _click_tile(screen, free_tile)
	_check(int(screen.get("_selected")) == -1, "board ignores taps while paused")
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
			var r := view.get_global_transform() * TileArtSet.active().body_rect
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
			var r := board.tile(i).get_global_transform() * TileArtSet.active().body_rect
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
