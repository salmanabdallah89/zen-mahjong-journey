extends Control
## Gameplay screen: deals the current level, turns tile presses into moves and
## drives the HUD, tools (Hint / Shuffle / Undo), pause and end-of-level
## dialogs. Rules live in BoardModel; this script only orchestrates.

const HINT_SEARCH_BUDGET := 20000
const TOAST_SECONDS := 2.6

enum UndoKind { MATCH, SHUFFLE }

var _level: LevelCatalog.LevelDefinition
var _model: BoardModel
var _selected := -1
var _hint := Vector2i(-1, -1)
## Entries: {"kind": UndoKind, "pair": Vector2i} or {"kind": UndoKind, "faces": PackedStringArray}
var _undo_stack: Array[Dictionary] = []
var _matches := 0
var _hints_used := 0
var _shuffles := 0
var _started_ms := 0
var _paused_ms := 0
var _pause_began_ms := -1
var _toast_tween: Tween

@onready var _background: TextureRect = %Background
@onready var _board: BoardView = %Board
@onready var _tiles_value: Label = %TilesValue
@onready var _level_value: Label = %LevelValue
@onready var _level_caption: Label = %LevelCaption
@onready var _pause_button: Button = %PauseButton
@onready var _hint_button: Button = %HintButton
@onready var _shuffle_button: Button = %ShuffleButton
@onready var _undo_button: Button = %UndoButton
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel
@onready var _dialog: ModalDialog = %Dialog


func _ready() -> void:
	_board.tile_pressed.connect(_on_tile_pressed)
	_pause_button.pressed.connect(_open_pause_menu)
	_hint_button.pressed.connect(_on_hint_pressed)
	_shuffle_button.pressed.connect(_on_shuffle_pressed)
	_undo_button.pressed.connect(_on_undo_pressed)
	_toast.hide()
	_dialog.hide()
	_start_level()


func _notification(what: int) -> void:
	# Android back button and the app going to the background both pause.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready() and not _dialog.visible and _model and not _model.is_cleared():
			_open_pause_menu()


func _start_level() -> void:
	_level = LevelCatalog.get_level(GameSession.current_level)
	if _level == null:
		push_error("GameScreen: level %d does not exist" % GameSession.current_level)
		GameSession.go_home()
		return
	_background.texture = load(_level.background_path())
	var geometry := _level.load_layout().build_geometry()
	var deal := BoardGenerator.generate(geometry, _level.face_pool(), _level.deal_seed)
	if not deal.ok:
		push_error("GameScreen: could not deal a solvable board for level %d" % _level.number)
		GameSession.go_home()
		return
	_model = BoardModel.new(geometry, deal.faces)
	_selected = -1
	_hint = Vector2i(-1, -1)
	_undo_stack.clear()
	_matches = 0
	_hints_used = 0
	_shuffles = 0
	_started_ms = Time.get_ticks_msec()
	_paused_ms = 0
	_pause_began_ms = -1
	_board.show_board(_model)
	_update_hud()


func _on_tile_pressed(index: int) -> void:
	if _dialog.visible or _model.is_cleared():
		return
	if not _model.is_free(index):
		_board.tile(index).play_blocked_nudge()
		return
	_clear_hint()
	if _selected == index:
		_set_selected(-1)
		return
	if _selected >= 0 and _model.can_remove_pair(_selected, index):
		_remove_pair(_selected, index)
		return
	_set_selected(index)


func _remove_pair(a: int, b: int) -> void:
	_set_selected(-1)
	_clear_hint()
	_model.remove_pair(a, b)
	_undo_stack.append({"kind": UndoKind.MATCH, "pair": Vector2i(a, b)})
	_matches += 1
	_board.play_removal(a, b)
	_board.refresh_free_states()
	_update_hud()
	if _model.is_cleared():
		_show_level_complete.call_deferred()
	elif not _model.has_moves():
		_show_no_moves()


func _on_hint_pressed() -> void:
	if _model.is_cleared():
		return
	var search := BoardSolver.solve(_model, HINT_SEARCH_BUDGET)
	var pair := Vector2i(-1, -1)
	if search.solved and not search.moves.is_empty():
		pair = search.moves[0]
	else:
		var matches := _model.available_matches()
		if matches.is_empty():
			_show_no_moves()
			return
		pair = matches[0]
		if not search.exhausted:
			_show_toast("This board can no longer be cleared. Try Undo or Shuffle.")
	_set_selected(-1)
	_clear_hint()
	_hint = pair
	_board.set_highlight(pair.x, TileView.Highlight.HINT)
	_board.set_highlight(pair.y, TileView.Highlight.HINT)
	_hints_used += 1


func _on_shuffle_pressed() -> void:
	if _model.is_cleared():
		return
	var result := BoardGenerator.reshuffle(_model, _level.deal_seed + 7919 * (_shuffles + 1))
	if not result.ok:
		_show_toast("These tiles can't be rearranged into a solvable board. Try Undo.")
		return
	_undo_stack.append({"kind": UndoKind.SHUFFLE, "faces": _model.faces.duplicate()})
	_model.set_faces(result.faces)
	_shuffles += 1
	_set_selected(-1)
	_clear_hint()
	_board.refresh_all()
	_update_hud()
	_show_toast("Tiles shuffled")


func _on_undo_pressed() -> void:
	if _undo_stack.is_empty():
		return
	var entry: Dictionary = _undo_stack.pop_back()
	_set_selected(-1)
	_clear_hint()
	if entry["kind"] == UndoKind.MATCH:
		var pair: Vector2i = entry["pair"]
		_model.restore_pair(pair.x, pair.y)
		_matches -= 1
		_board.play_restore(pair.x, pair.y)
	else:
		_model.set_faces(entry["faces"])
		_board.refresh_all()
	_update_hud()


func _set_selected(index: int) -> void:
	if _selected >= 0:
		_board.set_highlight(_selected, TileView.Highlight.NONE)
	_selected = index
	if _selected >= 0:
		_board.set_highlight(_selected, TileView.Highlight.SELECTED)


func _clear_hint() -> void:
	if _hint.x >= 0:
		_board.set_highlight(_hint.x, TileView.Highlight.NONE)
		_board.set_highlight(_hint.y, TileView.Highlight.NONE)
	_hint = Vector2i(-1, -1)
	if _selected >= 0:
		_board.set_highlight(_selected, TileView.Highlight.SELECTED)


func _update_hud() -> void:
	_tiles_value.text = str(_model.remaining)
	_level_value.text = "Level %d" % _level.number
	_level_caption.text = _level.title.to_upper()
	_undo_button.disabled = _undo_stack.is_empty()
	_hint_button.disabled = _model.is_cleared()
	_shuffle_button.disabled = _model.is_cleared()


func _open_pause_menu() -> void:
	_pause_began_ms = Time.get_ticks_msec()
	_dialog.open("Paused", "Level %d · %s" % [_level.number, _level.title])
	_dialog.add_action("Resume", _resume, true)
	_dialog.add_action("Restart", _restart)
	_dialog.add_action("Home", GameSession.go_home)


func _resume() -> void:
	if _pause_began_ms >= 0:
		_paused_ms += Time.get_ticks_msec() - _pause_began_ms
		_pause_began_ms = -1


func _restart() -> void:
	_start_level()


func _show_no_moves() -> void:
	_dialog.open("No More Moves", "There are no free matching pairs left.")
	_dialog.add_action("Shuffle", _on_shuffle_pressed, true)
	_dialog.add_action("Undo", _on_undo_pressed)
	_dialog.add_action("Restart", _restart)


func _show_level_complete() -> void:
	var seconds := int((Time.get_ticks_msec() - _started_ms - _paused_ms) / 1000.0)
	var summary := "%s cleared in %d:%02d\n%s · %s · %s" % [
		_level.title, floori(seconds / 60.0), seconds % 60, _count(_matches, "match", "matches"),
		_count(_hints_used, "hint", "hints"), _count(_shuffles, "shuffle", "shuffles")]
	if GameSession.has_next_level():
		_dialog.open("Level Complete!", summary)
		_dialog.add_action("Next Level", GameSession.play_next_level, true)
	else:
		_dialog.open("Journey Complete!", summary + "\nYou have finished every introductory level.")
	_dialog.add_action("Replay", _restart, not GameSession.has_next_level())
	_dialog.add_action("Home", GameSession.go_home)


func _count(amount: int, singular: String, plural: String) -> String:
	return "%d %s" % [amount, singular if amount == 1 else plural]


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.show()
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_toast.hide)
