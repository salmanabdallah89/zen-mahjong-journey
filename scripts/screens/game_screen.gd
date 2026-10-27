extends Control
## Gameplay screen: deals the current level, turns tile presses into moves and
## drives the HUD, tools (Hint / Shuffle / Undo), pause and end-of-level
## dialogs. Rules live in BoardModel; this script only orchestrates.

const HINT_SEARCH_BUDGET := 20000
const TOAST_SECONDS := 2.6
## How many times per level a blocked tap explains the rule in words.
const MAX_BLOCKED_EXPLANATIONS := 3
## The clock turns red for the last this-many seconds.
const TIME_WARNING_SECONDS := 30.0
const HEART_TEXTURE := preload("res://assets/ui/icons/icon_heart.png")
const TIME_NORMAL := Color(0.20784314, 0.30980393, 0.26666668)
const TIME_WARNING := Color(0.72, 0.22, 0.25)

enum LossReason { TIME, MISTAKES }

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
var _blocked_explanations := 0
var _time_left := 0.0
var _shown_seconds := -1
var _mistakes := 0
var _failed := false

@onready var _background: TextureRect = %Background
@onready var _board: BoardView = %Board
@onready var _tiles_value: Label = %TilesValue
@onready var _time_value: Label = %TimeValue
@onready var _hearts: HBoxContainer = %Hearts
@onready var _level_value: Label = %LevelValue
@onready var _level_caption: Label = %LevelCaption
@onready var _pause_button: Button = %PauseButton
@onready var _hint_button: Button = %HintButton
@onready var _shuffle_button: Button = %ShuffleButton
@onready var _undo_button: Button = %UndoButton
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel
@onready var _dialog: ModalDialog = %Dialog
@onready var _picker: CollectionPicker = %CollectionPicker
@onready var _settings: AudioSettingsPanel = %AudioSettings


func _ready() -> void:
	_board.tile_pressed.connect(_on_tile_pressed)
	_pause_button.pressed.connect(_open_pause_menu)
	_hint_button.pressed.connect(_on_hint_pressed)
	_shuffle_button.pressed.connect(_on_shuffle_pressed)
	_undo_button.pressed.connect(_on_undo_pressed)
	# These buttons play their own sound, and only when the action succeeds.
	for button in [_hint_button, _shuffle_button, _undo_button]:
		button.set_meta("custom_sound", true)
	_toast.hide()
	_dialog.hide()
	_picker.hide()
	_picker.closed.connect(_on_picker_closed)
	_settings.hide()
	_settings.closed.connect(_on_picker_closed)
	TileCollectionManager.collection_changed.connect(_on_collection_changed)
	_start_level()


func _notification(what: int) -> void:
	# Android back button and the app going to the background both pause.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_node_ready() and not _dialog.visible and _model and not _model.is_cleared() and not _failed:
			_open_pause_menu()


func _start_level() -> void:
	_level = LevelCatalog.get_level(GameSession.current_level)
	if _level == null:
		push_error("GameScreen: level %d does not exist" % GameSession.current_level)
		GameSession.go_home()
		return
	_background.texture = load(_level.background_path())
	AudioManager.play_music("gameplay")
	AudioManager.reset_melody()
	AudioManager.set_ambience(AudioCatalog.AMBIENCE_FOR_BACKGROUND.get(_level.background, AudioCatalog.MENU_AMBIENCE))
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
	_blocked_explanations = 0
	_time_left = float(_level.time_limit)
	_shown_seconds = -1
	_mistakes = 0
	_failed = false
	_build_hearts()
	_started_ms = Time.get_ticks_msec()
	_paused_ms = 0
	_pause_began_ms = -1
	_board.show_board(_model, TileCollectionManager.skin_for_board(_model.faces, _level.deal_seed))
	_update_hud()
	_show_collection_notice()


func _on_tile_pressed(index: int) -> void:
	if _failed or _dialog.visible or _picker.visible or _settings.visible or _model.is_cleared():
		return
	if not _model.is_free(index):
		_explain_blocked(index)
		return
	_clear_hint()
	if _selected == index:
		_set_selected(-1)
		return
	if _selected >= 0 and _model.can_remove_pair(_selected, index):
		_remove_pair(_selected, index)
		return
	if _selected >= 0:
		_register_mistake(_selected, index)
		return
	_set_selected(index)
	AudioManager.play_sfx("tile_select")


## Shakes a blocked tile and outlines what is blocking it, including tiles
## hidden beneath raised ones. The first few times, a message says why.
func _explain_blocked(index: int) -> void:
	_board.tile(index).play_blocked_nudge()
	AudioManager.play_sfx("tile_blocked")
	var blockers := _model.blockers(index)
	var covered := false
	var hidden_blocker := false
	for j in blockers:
		_board.tile(j).play_blocker_flash()
		covered = covered or _model.geometry.positions[j].z > _model.geometry.positions[index].z
		hidden_blocker = hidden_blocker or _covered_now(j)
	if _blocked_explanations >= MAX_BLOCKED_EXPLANATIONS:
		return
	_blocked_explanations += 1
	if covered:
		_show_toast("That tile is covered by a tile above it.")
	elif hidden_blocker:
		_show_toast("Blocked on both sides. One neighbour is hidden under a raised tile.")
	else:
		_show_toast("A tile can be picked when its left or right side is open.")


func _covered_now(index: int) -> bool:
	for j in _model.geometry.covered_by[index]:
		if not _model.is_removed(j):
			return true
	return false


func _remove_pair(a: int, b: int) -> void:
	_set_selected(-1)
	_clear_hint()
	_model.remove_pair(a, b)
	_undo_stack.append({"kind": UndoKind.MATCH, "pair": Vector2i(a, b)})
	_matches += 1
	_board.play_removal(a, b)
	_board.refresh_free_states()
	_update_hud()
	AudioManager.vibrate()
	# The last pair is celebrated by the level-complete sound instead.
	if not _model.is_cleared():
		AudioManager.play_match_note()
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
	AudioManager.play_sfx("hint")


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
	AudioManager.play_sfx("shuffle")
	AudioManager.reset_melody()
	_set_selected(-1)
	_clear_hint()
	_board.refresh_all()
	_update_hud()
	_show_toast("Tiles shuffled")


func _on_undo_pressed() -> void:
	if _undo_stack.is_empty():
		return
	var entry: Dictionary = _undo_stack.pop_back()
	AudioManager.play_sfx("undo")
	_set_selected(-1)
	_clear_hint()
	if entry["kind"] == UndoKind.MATCH:
		AudioManager.melody_step_back()
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
	_update_timer_label()
	_level_value.text = "Level %d" % _level.number
	_level_caption.text = _level.title.to_upper()
	_undo_button.disabled = _undo_stack.is_empty()
	_hint_button.disabled = _model.is_cleared()
	_shuffle_button.disabled = _model.is_cleared()


func _open_pause_menu() -> void:
	_pause_began_ms = Time.get_ticks_msec()
	_dialog.open("Paused", "Level %d · %s" % [_level.number, _level.title])
	_dialog.add_action("Resume", _resume, true)
	_dialog.add_action("Settings", _open_settings)
	_dialog.add_action("Tile Collection", _open_collection_picker)
	_dialog.add_action("Restart", _restart)
	_dialog.add_action("Home", GameSession.go_home)


func _open_settings() -> void:
	_settings.open("Return to Game")


func _open_collection_picker() -> void:
	_picker.open("Return to Game")


func _on_picker_closed() -> void:
	_resume()


## Re-skins the board in place: same tiles, same state, new artwork.
func _on_collection_changed(_collection_id: String) -> void:
	if _model:
		_set_selected(-1)
		_clear_hint()
		_board.apply_skin(TileCollectionManager.skin_for_board(_model.faces, _level.deal_seed))
		_show_collection_notice()


func _show_collection_notice() -> void:
	var text := TileCollectionManager.take_notice()
	if not text.is_empty():
		_show_toast(text)


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
	AudioManager.play_sfx("level_complete")
	AudioManager.duck_music_for(3.0)
	var seconds := int(_level.time_limit - _time_left)
	var summary := "%s cleared in %d:%02d with %s left\n%s · %s · %s" % [
		_level.title, floori(seconds / 60.0), seconds % 60, _clock(_time_left),
		_count(_mistakes, "mistake", "mistakes"), _count(_hints_used, "hint", "hints"),
		_count(_shuffles, "shuffle", "shuffles")]
	if GameSession.has_next_level():
		_dialog.open("Level Complete!", summary)
		_dialog.add_action("Next Level", GameSession.play_next_level, true)
	else:
		_dialog.open("Journey Complete!", summary + "\nYou have finished every introductory level.")
	_dialog.add_action("Replay", _restart, not GameSession.has_next_level())
	_dialog.add_action("Home", GameSession.go_home)


func _process(delta: float) -> void:
	if not _clock_running():
		return
	_time_left = maxf(_time_left - delta, 0.0)
	_update_timer_label()
	if _time_left <= 0.0:
		_lose(LossReason.TIME)


## The clock only runs while the player is actually playing.
func _clock_running() -> bool:
	return _model != null and not _failed and not _model.is_cleared() \
		and not _dialog.visible and not _picker.visible and not _settings.visible


## Picking two free tiles that don't match costs a heart.
func _register_mistake(a: int, b: int) -> void:
	_mistakes += 1
	_set_selected(-1)
	_clear_hint()
	_board.tile(a).play_blocked_nudge()
	_board.tile(b).play_blocked_nudge()
	AudioManager.play_sfx("mistake")
	AudioManager.vibrate(60)
	_update_hearts()
	var left := _level.mistake_limit - _mistakes
	if left <= 0:
		_lose(LossReason.MISTAKES)
	elif left == 1:
		_show_toast("Those tiles don't match. One mistake left!")
	else:
		_show_toast("Those tiles don't match. %d mistakes left." % left)


func _lose(reason: LossReason) -> void:
	if _failed:
		return
	_failed = true
	_set_selected(-1)
	_clear_hint()
	_update_timer_label()
	if _toast_tween:
		_toast_tween.kill()
	_toast.hide()
	AudioManager.play_sfx("level_failed")
	AudioManager.duck_music_for(3.0)
	var pairs := int(_model.tile_count() / 2.0)
	var title := "Out of Time" if reason == LossReason.TIME else "Too Many Mistakes"
	var why := "The clock ran out." if reason == LossReason.TIME else "You used all %d hearts." % _level.mistake_limit
	_dialog.open(title, "%s\nLevel %d · %s: %d of %d pairs matched." % [
		why, _level.number, _level.title, _matches, pairs])
	_dialog.add_action("Retry", _restart, true)
	_dialog.add_action("Home", GameSession.go_home)


func _build_hearts() -> void:
	for child in _hearts.get_children():
		child.queue_free()
	for i in _level.mistake_limit:
		var heart := TextureRect.new()
		heart.texture = HEART_TEXTURE
		heart.custom_minimum_size = Vector2(76, 76)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hearts.add_child(heart)
	_update_hearts()


## Hearts still available are bright; spent ones fade.
func _update_hearts() -> void:
	var hearts := _hearts.get_children().filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())
	for i in hearts.size():
		var spent := i >= _level.mistake_limit - _mistakes
		(hearts[i] as Control).modulate = Color(1, 1, 1, 0.25) if spent else Color.WHITE
	if _mistakes > 0 and _mistakes <= hearts.size():
		var lost: Control = hearts[_level.mistake_limit - _mistakes]
		lost.pivot_offset = lost.size / 2.0
		var tween := create_tween()
		tween.tween_property(lost, "scale", Vector2(1.35, 1.35), 0.12)
		tween.tween_property(lost, "scale", Vector2.ONE, 0.2)


func hearts_left() -> int:
	return _level.mistake_limit - _mistakes


func _update_timer_label() -> void:
	var whole := ceili(_time_left)
	if whole == _shown_seconds:
		return
	_shown_seconds = whole
	_time_value.text = _clock(_time_left)
	var warning := _time_left <= TIME_WARNING_SECONDS
	_time_value.add_theme_color_override("font_color", TIME_WARNING if warning else TIME_NORMAL)


func _clock(seconds: float) -> String:
	var whole := ceili(seconds)
	return "%d:%02d" % [floori(whole / 60.0), whole % 60]


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
