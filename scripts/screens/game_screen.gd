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
## Longest step the clock takes in one frame, so a stall (a hidden browser
## tab, a slow device) can't cost the player a big chunk of time at once.
const MAX_CLOCK_STEP := 0.25
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
## Seconds actually played this attempt (second chances included).
var _elapsed := 0.0
var _toast_tween: Tween
var _blocked_explanations := 0
var _time_left := 0.0
var _shown_seconds := -1
var _mistakes := 0
var _failed := false
## Ads: free hints left this attempt, and second chances used this attempt.
var _free_hints := 0
var _second_chances := 0
var _last_loss := LossReason.TIME
var _pause_open := false

@onready var _background: TextureRect = %Background
@onready var _board: BoardView = %Board
@onready var _tiles_value: Label = %TilesValue
@onready var _time_value: Label = %TimeValue
@onready var _hearts: HBoxContainer = %Hearts
@onready var _hint_label: Label = $SafeArea/Layout/Toolbar/HintTool/HintLabel
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
	if not is_node_ready():
		return
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back_requested()
		# The app going to the background, or the window/tab losing focus
		# (split screen, notification shade, another browser tab), pauses.
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_pause_if_playing()


## Android back: closes whatever is on top; on the board it pauses, and on the
## pause menu it resumes. End-of-level dialogs wait for a choice.
func _on_back_requested() -> void:
	if _settings.visible:
		_settings.close()
	elif _picker.visible:
		_picker.close()
	elif _dialog.visible:
		if _pause_open:
			_dialog.close()
			_resume()
	elif not AdsManager.is_showing():
		_pause_if_playing()


func _pause_if_playing() -> void:
	if _dialog.visible or _picker.visible or _settings.visible or AdsManager.is_showing():
		return
	if _model and not _model.is_cleared() and not _failed:
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
	_free_hints = int(AdsManager.setting("free_hints_per_level", 1))
	_second_chances = 0
	_shuffles = 0
	_blocked_explanations = 0
	_time_left = float(_level.time_limit)
	_shown_seconds = -1
	_mistakes = 0
	_failed = false
	_elapsed = 0.0
	_pause_open = false
	_build_hearts()
	_board.show_board(_model, TileCollectionManager.skin_for_board(_model.faces, _level.deal_seed))
	_update_hud()
	_show_collection_notice()


func _on_tile_pressed(index: int) -> void:
	if _failed or _dialog.visible or _picker.visible or _settings.visible or _model.is_cleared() or AdsManager.is_showing():
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
	if _model.is_cleared() or _failed or _dialog.visible:
		return
	# Never spend a free hint or ask for an ad when there is nothing to show.
	if not _model.has_moves():
		_show_no_moves()
		return
	# With ads: a free hint per level, then one hint per rewarded ad.
	# Without ads (web build) hints stay free.
	if AdsManager.is_available() and _free_hints <= 0:
		_dialog.open("Need a Hint?", "Watch a short ad to reveal a matching pair.")
		_dialog.add_action("Watch Ad", func() -> void:
			AdsManager.show_rewarded("hint", _on_hint_ad_done), true)
		_dialog.add_action("No Thanks", func() -> void: pass)
		return
	if AdsManager.is_available():
		_free_hints -= 1
		_update_hud()
	_give_hint()


func _on_hint_ad_done(rewarded: bool) -> void:
	if rewarded:
		_give_hint()
	else:
		_show_toast("Watch the whole ad to get a hint.")


func _give_hint() -> void:
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
	if _model.is_cleared() or _failed or _dialog.visible:
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
	if _undo_stack.is_empty() or _failed or _dialog.visible or _model.is_cleared():
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
	if AdsManager.is_available():
		_hint_label.text = "Hint (%d)" % _free_hints if _free_hints > 0 else "Ad Hint"
	else:
		_hint_label.text = "Hint"
	_update_timer_label()
	_level_value.text = "Level %d" % _level.number
	_level_caption.text = _level.title.to_upper()
	_undo_button.disabled = _undo_stack.is_empty()
	_hint_button.disabled = _model.is_cleared()
	_shuffle_button.disabled = _model.is_cleared()


func _open_pause_menu() -> void:
	_pause_open = true
	_dialog.open("Paused", "Level %d · %s" % [_level.number, _level.title])
	_dialog.add_action("Resume", _resume, true)
	_dialog.add_action("Settings", _open_settings)
	_dialog.add_action("Tile Collection", _open_collection_picker)
	_dialog.add_action("Restart", _restart)
	_dialog.add_action("Levels", GameSession.go_levels)


## Seconds played this attempt.
func elapsed_seconds() -> float:
	return _elapsed


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


## The clock restarts by itself once nothing covers the board.
func _resume() -> void:
	_pause_open = false


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
	var seconds := int(_elapsed)
	var summary := "%s cleared in %d:%02d with %s left\n%s · %s · %s" % [
		_level.title, floori(seconds / 60.0), seconds % 60, _clock(_time_left),
		_count(_mistakes, "mistake", "mistakes"), _count(_hints_used, "hint", "hints"),
		_count(_shuffles, "shuffle", "shuffles")]
	var earned := LevelRating.stars(_time_left, _level.time_limit, _mistakes)
	var record := GameSession.progress.record_clear(_level.number, earned, _time_left, LevelCatalog.count())
	GameSession.just_unlocked = record.unlocked
	if record.new_best_stars and record.previous_stars > 0:
		summary += "\nNew best: %d stars!" % earned
	elif record.new_best_time:
		summary += "\nNew best time!"
	if earned < LevelRating.MAX_STARS:
		summary += "\n" + _next_star_tip(earned)
	if GameSession.has_next_level():
		_dialog.open("Level Complete!", summary)
		_dialog.add_action("Next Level", func() -> void: AdsManager.after_level_complete(GameSession.play_next_level), true)
	else:
		_dialog.open("Journey Complete!", summary + "\nYou have finished every introductory level.")
	_dialog.set_stars(earned, LevelRating.MAX_STARS, true)
	_dialog.add_action("Replay", func() -> void: AdsManager.after_level_complete(_restart), not GameSession.has_next_level())
	_dialog.add_action("Levels", func() -> void: AdsManager.after_level_complete(GameSession.go_levels))
	get_tree().create_timer(0.9).timeout.connect(func() -> void: AudioManager.play_sfx("reward"))


func _next_star_tip(earned: int) -> String:
	if earned == 1:
		return "For 2 stars: make at most 1 mistake."
	return "For 3 stars: no mistakes and half the time left."


func _exit_tree() -> void:
	# Leaving the level mid-ad must not leave the ad covering the next screen.
	if AdsManager.is_showing():
		AdsManager.cancel()


func _process(delta: float) -> void:
	if not _clock_running():
		return
	var step := minf(delta, MAX_CLOCK_STEP)
	_time_left = maxf(_time_left - step, 0.0)
	_elapsed += step
	_update_timer_label()
	if _time_left <= 0.0:
		_lose(LossReason.TIME)


## The clock only runs while the player is actually playing.
func _clock_running() -> bool:
	return _model != null and not _failed and not _model.is_cleared() \
		and not _dialog.visible and not _picker.visible and not _settings.visible and not AdsManager.is_showing()


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
	_last_loss = reason
	var offer_second_chance := AdsManager.is_available() \
		and _second_chances < int(AdsManager.setting("second_chances_per_attempt", 1))
	if offer_second_chance:
		var label := "Watch Ad: +%d s" % int(AdsManager.setting("second_chance_seconds", 60)) if reason == LossReason.TIME \
			else "Watch Ad: +1 Heart"
		_dialog.add_action(label, func() -> void: AdsManager.show_rewarded("second_chance", _on_second_chance_done), true)
	_dialog.add_action("Retry", _restart, not offer_second_chance)
	_dialog.add_action("Levels", GameSession.go_levels)


## Rewarded second chance: continue the same board with more time or a heart.
func _on_second_chance_done(rewarded: bool) -> void:
	if not rewarded:
		_lose_again_dialog()
		return
	_second_chances += 1
	_failed = false
	if _last_loss == LossReason.TIME:
		_time_left = float(AdsManager.setting("second_chance_seconds", 60))
		_shown_seconds = -1
		_update_timer_label()
		_show_toast("+%d seconds. Keep going!" % int(_time_left))
	else:
		_mistakes = maxi(_mistakes - int(AdsManager.setting("second_chance_hearts", 1)), 0)
		_update_hearts()
		_show_toast("+1 heart. Keep going!")
	AudioManager.play_sfx("reward")


func _lose_again_dialog() -> void:
	_failed = false
	_lose(_last_loss)


## Second chance is spent per attempt, so the loss dialog no longer offers it.
func second_chances_used() -> int:
	return _second_chances


func free_hints_left() -> int:
	return _free_hints


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
