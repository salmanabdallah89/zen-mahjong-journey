extends Control
## Gameplay screen: deals the current level, turns tile presses into moves and
## drives the HUD, tools (Hint / Shuffle / Undo), pause and end-of-level
## dialogs. Rules live in BoardModel; this script only orchestrates.

const HINT_SEARCH_BUDGET := 20000
## Undos allowed per attempt (a restart gives them back).
const UNDOS_PER_LEVEL := 3
const TOAST_SECONDS := 2.6
## How many times per level a blocked tap explains the rule in words.
const MAX_BLOCKED_EXPLANATIONS := 3
## The clock turns red for the last this-many seconds.
const TIME_WARNING_SECONDS := 30.0
## Longest step the clock takes in one frame, so a stall (a hidden browser
## tab, a slow device) can't cost the player a big chunk of time at once.
const MAX_CLOCK_STEP := 0.25
const HEART_TEXTURE := preload("res://assets/ui/icons/icon_heart.png")
## Hearts sit in the top bar under the level name.
const HEART_SIZE := 54.0
const PETAL_TEXTURE := preload("res://assets/effects/petal_02.png")
## "Zen Master!" (the top praise tier) also glows softly at the screen edges.
const EDGE_GLOW_SECONDS := 1.1
## Level-complete stars ring a rising D major chord: D6, F#6, A6 (melody notes).
const STAR_NOTES: Array[int] = [5, 7, 8]
## Seconds between the last pair touching and the level-complete dialog.
const LAST_PAIR_PAUSE := 0.3
## Match bells ring in match order and at least this far apart, even when a
## later pair (shorter glide) touches before an earlier one.
const BELL_SPACING := 0.09
## Longest the Level Complete dialog waits for queued bells after the last
## pair touches (only very fast play builds a queue).
const MAX_BELL_WAIT := 0.25
## Tiles a rewarded second chance sends back from a full tray.
const TRAY_SECOND_CHANCE := 2
## Milestones: "Last 10 tiles!" on boards larger than twice this.
const FINAL_TILES := 10
## A milestone waits for the match's own praise to be read first.
const MILESTONE_DELAY := 0.9
const SWEEP_SECONDS := 1.2
## The last pair blooms like a top combo.
const FINALE_BURST := 10
## Burst size (as a combo) for a golden lotus match.
const GOLDEN_BURST := 6
## Seconds gliding points take to reach the score.
const POINTS_RISE := 0.55
const TIME_NORMAL := Color(0.20784314, 0.30980393, 0.26666668)
const TIME_WARNING := Color(0.72, 0.22, 0.25)

enum LossReason { TIME, MISTAKES, TRAY }

enum UndoKind { MATCH, SHUFFLE, TRAY }

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
## Badge facts of this attempt.
var _best_multiplier := 1
var _golden_matched := false
var _revealed_count := 0
var _failed := false
## Ads: free hints and shuffles left this attempt, and second chances used this attempt.
var _free_hints := 0
var _free_shuffles := 0
var _free_magnets := 0
## Magnets used this attempt (a tool, like hints and shuffles).
var _magnets := 0
var _undos_left := 0
var _second_chances := 0
var _last_loss := LossReason.TIME
var _pause_open := false
## When the latest scheduled match bell rings (Time.get_ticks_msec seconds).
var _last_bell_at := -1.0
## Petals, motes, light rays and mist over the garden (GardenAmbience).
var _ambience: GardenAmbience
## Mystery (face-down) and golden lotus (double points) tiles of this board.
var _specials := TileSpecials.new()
var _earned_badges: Array[Dictionary] = []
@onready var _badge_reveal: BadgeReveal = %BadgeReveal
## Word Garden: words on this board and those mixed up this attempt.
var _word_ids := PackedStringArray()
var _words_missed := PackedStringArray()
## Tray levels (every mode but Word Garden): a tapped tile waits in the tray
## until its match joins it (TileTray, docs/TILE_TRAY.md).
var _tray := TileTray.new()
@onready var _tray_bar: TrayBar = %Tray
@onready var _magnet_button: Button = %MagnetButton
@onready var _magnet_label: Label = %MagnetLabel

@onready var _background: TextureRect = %Background
@onready var _board: BoardView = %Board
@onready var _tiles_value: Label = %TilesValue
@onready var _time_value: Label = %TimeValue
@onready var _hearts: HBoxContainer = %Hearts
@onready var _hint_label: Label = $SafeArea/Layout/Toolbar/HintTool/HintLabel
@onready var _shuffle_label: Label = $SafeArea/Layout/Toolbar/ShuffleTool/ShuffleLabel
@onready var _undo_label: Label = $SafeArea/Layout/Toolbar/UndoTool/UndoLabel
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
@onready var _lane: Control = %FeedbackLane
var _praise: ComboFeedback
@onready var _score_meter: ScoreMeter = %ScoreMeter
var _score := LevelScore.new()
var _final_score := 0
var _half_reached := false
var _final_reached := false
var _tutorial: FirstPlayTutorial


func _ready() -> void:
	_board.tile_pressed.connect(_on_tile_pressed)
	_board.shuffle_spreading.connect(func() -> void: AudioManager.play_sfx("shuffle_land"))
	_pause_button.pressed.connect(_open_pause_menu)
	_hint_button.pressed.connect(_on_hint_pressed)
	_shuffle_button.pressed.connect(_on_shuffle_pressed)
	_undo_button.pressed.connect(_on_undo_pressed)
	_magnet_button.pressed.connect(_on_magnet_pressed)
	_magnet_button.set_meta("custom_sound", true)
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
	_dialog.star_popped.connect(_on_star_popped)
	_dialog.score_counted.connect(func() -> void: AudioManager.play_sfx("reward"))
	# Praise and messages share the lane below the board; nothing in it ever
	# reaches over the tiles.
	_lane.clip_contents = true
	_board.footer = _lane
	_praise = ComboFeedback.new()
	_praise.name = "Praise"
	_lane.add_child(_praise)
	_tutorial = FirstPlayTutorial.new()
	_tutorial.name = "Tutorial"
	_lane.add_child(_tutorial)
	_tutorial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial.step = FirstPlayTutorial.Step.DONE
	_tutorial.hide()
	_tutorial.finished.connect(_on_tutorial_finished)
	BackgroundDrift.start(_background)
	_ambience = GardenAmbience.add_over(_background)
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
	if _badge_reveal.visible:
		_badge_reveal.next()
	elif _settings.visible:
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
	if _daily():
		_level = DailyChallenge.level_for(GameSession.daily_day)
	else:
		_level = WordCatalog.level_for(GameSession.word_stage) if _learning() else LevelCatalog.get_level(GameSession.current_level)
	if _level == null:
		push_error("GameScreen: level %d does not exist" % GameSession.current_level)
		GameSession.go_home()
		return
	_background.texture = load(_level.background_path())
	# Per-background shading keeps the tiles the focus (BackgroundStyle).
	_background.modulate = BackgroundStyle.scenery_tint(_level.background)
	_board.set_backdrop_strength(BackgroundStyle.board_shade(_level.background))
	_ambience.setup(_level.background)
	AudioManager.play_music("gameplay")
	AudioManager.reset_melody()
	AudioManager.set_ambience(AudioCatalog.AMBIENCE_FOR_BACKGROUND.get(_level.background, AudioCatalog.MENU_AMBIENCE))
	var geometry := _level.load_layout().build_geometry()
	if _learning():
		_word_ids = WordCatalog.stage_words(GameSession.word_stage, GameSession.progress.word_review(GameSession.word_language))
		_words_missed.clear()
	var pool := WordCatalog.faces_for(_word_ids) if _learning() else _level.face_pool()
	var deal := BoardGenerator.generate(geometry, pool, _level.deal_seed)
	if not deal.ok:
		push_error("GameScreen: could not deal a solvable board for level %d" % _level.number)
		GameSession.go_home()
		return
	_model = BoardModel.new(geometry, deal.faces)
	var specials_level := DailyChallenge.SPECIALS_LEVEL if _daily() else _level.number
	_specials = TileSpecials.plan(specials_level, _level.difficulty, _model, deal.solution, _level.deal_seed)
	_board.specials = _specials
	_board.mystery_back = load(TileArtSet.active().back_path(BackgroundStyle.tile_back(_level.background)))
	_selected = -1
	_hint = Vector2i(-1, -1)
	_tray = TileTray.new()
	_undo_stack.clear()
	_matches = 0
	_hints_used = 0
	_free_hints = int(AdsManager.setting("free_hints_per_level", 1))
	_free_shuffles = int(AdsManager.setting("free_shuffles_per_level", 1))
	_free_magnets = int(AdsManager.setting("free_magnets_per_level", 1))
	_magnets = 0
	_undos_left = UNDOS_PER_LEVEL
	_score = LevelScore.new()
	_final_score = 0
	_half_reached = false
	_final_reached = false
	_score_meter.reset()
	_second_chances = 0
	_shuffles = 0
	_blocked_explanations = 0
	_time_left = float(_level.time_limit)
	_shown_seconds = -1
	_mistakes = 0
	_best_multiplier = 1
	_golden_matched = false
	_revealed_count = 0
	_failed = false
	_elapsed = 0.0
	_pause_open = false
	_last_bell_at = -1.0
	_build_hearts()
	_show_learning_hud()
	_board.show_board(_model, _board_skin())
	_tray_bar.visible = _tray_mode()
	%MagnetTool.visible = _tray_mode()
	_tray_bar.sync(_tray.tiles, _board)
	_update_hud()
	_show_collection_notice()
	_introduce_specials()
	if GameSession.should_show_tutorial(_level.number):
		_tutorial.begin(_board, _tutorial_pair(deal.solution[0]))
	elif _tutorial.is_active():
		_tutorial.step = FirstPlayTutorial.Step.DONE
		_tutorial.hide()


## The first level with each kind of special tile says what it does.
func _introduce_specials() -> void:
	if _level.number == TileSpecials.FIRST_GOLDEN_LEVEL:
		_show_toast("Golden lotus tiles score double points. Find their pair!")
	elif _level.number == TileSpecials.FIRST_MYSTERY_LEVEL:
		_show_toast("Face-down tiles turn over when you uncover them.")


func _learning() -> bool:
	return not GameSession.word_language.is_empty()


## Every mode but Word Garden plays with the tray (and without hearts).
func _tray_mode() -> bool:
	return not _learning()


## Tile indices waiting in the tray (tests).
func tray_tiles() -> Array[int]:
	return _tray.tiles


func _daily() -> bool:
	return GameSession.daily_day >= 0 and not _learning()


## Modes without clock, hearts or score.
func _calm() -> bool:
	return _learning() or _daily()


func _board_skin() -> TileSkin:
	if _learning():
		return WordSkin.for_words(_word_ids, GameSession.word_language, GameSession.word_native)
	return TileCollectionManager.skin_for_board(_model.faces, _level.deal_seed)


## Word Garden has no clock, hearts or score to watch.
func _show_learning_hud() -> void:
	%TimeBox.visible = not _calm()
	%HeartsPill.visible = not _calm() and not _tray_mode()
	_score_meter.visible = not _calm()
	if _learning():
		_toast_label.theme_type_variation = &"ToastWordLabel"
		_praise.use_word_font()


func tutorial_active() -> bool:
	return _tutorial != null and _tutorial.is_active()


## The pair the tutorial highlights first: free, with identical pictures (so
## it reads as "the same" in every collection, flowers and seasons included),
## and leaving a board that can still be cleared. Falls back to the deal's
## own first move, which always can.
func _tutorial_pair(fallback: Vector2i) -> Vector2i:
	for candidate in _model.available_matches():
		if _model.face_of(candidate.x) != _model.face_of(candidate.y):
			continue
		_model.remove_pair(candidate.x, candidate.y)
		var still_solvable := BoardSolver.solve(_model, HINT_SEARCH_BUDGET).solved
		_model.restore_pair(candidate.x, candidate.y)
		if still_solvable:
			return candidate
	return fallback


func _on_tutorial_finished(skipped: bool) -> void:
	GameSession.set_tutorial_seen("skipped" if skipped else "completed")


func _on_tile_pressed(index: int) -> void:
	if _failed or _dialog.visible or _picker.visible or _settings.visible or _model.is_cleared() or AdsManager.is_showing():
		return
	# Faces change mid-shuffle; wait until the tiles have settled.
	if _board.is_busy():
		return
	if not _model.is_free(index):
		_explain_blocked(index)
		return
	_clear_hint()
	if _tray_mode():
		_take_into_tray(index)
		return
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
	AudioManager.vibrate(10)


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


## The model changes at once; the bell, the haptic and any combo text land
## when the gliding pair actually touches (BoardView.play_removal's contact).
func _remove_pair(a: int, b: int) -> void:
	_set_selected(-1)
	_clear_hint()
	_model.remove_pair(a, b)
	var revealed := _specials.reveal_free(_model)
	var factor := _specials.factor(a, b)
	_revealed_count += revealed.size()
	_golden_matched = _golden_matched or factor > 1
	_matches += 1
	if tutorial_active():
		_tutorial.on_matched(a, b)
	var cleared := _model.is_cleared()
	# The last pair is celebrated by the level-complete sound instead.
	var step := AudioManager.melody_step() if cleared else AudioManager.next_match_step()
	var combo := step + 1
	var points := _score.add_match(combo, factor)
	_best_multiplier = maxi(_best_multiplier, LevelScore.multiplier(combo))
	_undo_stack.append({"kind": UndoKind.MATCH, "pair": Vector2i(a, b), "points": points})
	var burst := FINALE_BURST if cleared else (maxi(combo, GOLDEN_BURST) if factor > 1 else combo)
	var contact := _board.play_removal(a, b, burst, revealed)
	if not revealed.is_empty():
		_after(contact, AudioManager.play_sfx.bind("star"))
	_finish_match(a, contact, step, combo, cleared, factor, points, _board.meeting_point_global(a, b))


## A tapped free tile leaves the board for the tray: it waits there, or meets
## its waiting match and both burst away. Four tiles without a pair stop the
## level. Three waiting is a close call (it counts like a mistake for stars).
func _take_into_tray(index: int) -> void:
	if _tray.is_full():
		return
	var move := _tray.take(_model, index)
	if move == null:
		return
	var revealed := _specials.reveal_free(_model)
	_revealed_count += revealed.size()
	_board.play_take(index, revealed)
	if not revealed.is_empty():
		_after(0.15, AudioManager.play_sfx.bind("star"))
	if move.matched():
		_tray_match(move)
		return
	_undo_stack.append({"kind": UndoKind.TRAY, "move": move})
	var lands := _tray_bar.fly_in(index, _board)
	AudioManager.play_sfx("tile_select")
	AudioManager.vibrate(10)
	if tutorial_active():
		_tutorial.on_selected(index)
	if move.close_call:
		_mistakes += 1
	_update_hud()
	if move.full:
		_after(lands + 0.2, _lose.bind(LossReason.TRAY))
	elif move.close_call and not tutorial_active():
		_show_toast("Careful: one place left in the tray.")


## The tapped tile flies to its waiting partner; they meet in the tray and
## burst into petals and gold. Scoring, bells and praise as on the board.
func _tray_match(move: TileTray.Move) -> void:
	var a := move.partner
	var b := move.tile
	var factor := _specials.factor(a, b)
	_golden_matched = _golden_matched or factor > 1
	_matches += 1
	if tutorial_active():
		_tutorial.on_matched(a, b)
	var cleared := _model.is_cleared()
	var step := AudioManager.melody_step() if cleared else AudioManager.next_match_step()
	var combo := step + 1
	var points := _score.add_match(combo, factor)
	_best_multiplier = maxi(_best_multiplier, LevelScore.multiplier(combo))
	_undo_stack.append({"kind": UndoKind.TRAY, "move": move, "points": points})
	var burst := FINALE_BURST if cleared else (maxi(combo, GOLDEN_BURST) if factor > 1 else combo)
	var meet := _tray_bar.slot_center_global(move.slot)
	var contact := _tray_bar.fly_match(b, move.slot, _board, burst)
	_finish_match(a, contact, step, combo, cleared, factor, points, meet)
	# The pair's picture lifts out as a glowing emblem and shoots into the
	# score (the last pair leaves the stage to Level Complete).
	if not cleared:
		var picture := _board.face_picture(b)
		_after(contact, func() -> void:
			var target := _score_meter.target_global() if _score_meter.is_visible_in_tree() else meet
			MatchEmblem.release(self, picture, meet, target, combo, factor > 1, _score_meter.pulse))


## What follows every match, on the board or in the tray, once the pair
## touches (`contact` seconds from now): points, bells, praise, milestones and
## the end of the level.
func _finish_match(a: int, contact: float, step: int, combo: int, cleared: bool, factor: int, points: int, meet: Vector2) -> void:
	if not _calm():
		_after(contact, _land_points.bind(points, meet))
	if cleared:
		_after(contact, _play_edge_glow)
	_update_hud()
	var now := Time.get_ticks_msec() / 1000.0
	var ring_in := maxf(contact, _last_bell_at + BELL_SPACING - now)
	_last_bell_at = now + ring_in
	_after(ring_in, _on_pair_met.bind(step, combo, cleared, factor > 1))
	if _learning():
		_after(ring_in, _say_word.bind(WordCatalog.id_of(_model.face_of(a))))
	elif not cleared and not _daily():
		_check_milestones(ring_in)
	if cleared:
		# Let the last pair meet and bloom (and a short bell queue finish) first.
		var settle := minf(ring_in, contact + MAX_BELL_WAIT)
		_after(settle + (0.0 if Motion.reduced else LAST_PAIR_PAUSE), _show_level_complete)
	elif not _tray_mode() and not _model.has_moves():
		_show_no_moves()


func _on_pair_met(step: int, combo: int, cleared: bool, golden := false) -> void:
	# Once Level Complete is up, late bells and praise would only distract.
	if cleared or (_model.is_cleared() and _dialog.visible):
		return
	AudioManager.play_match_step(step)
	if golden:
		_toast.hide()
		_praise.show_message("Golden Lotus ×%d!" % TileSpecials.GOLDEN_FACTOR)
		AudioManager.play_sfx("reward")
		AudioManager.vibrate(30)
		return
	if not _learning():
		_show_combo(combo)


## A matched word appears under the board and is read aloud.
func _say_word(word_id: String) -> void:
	if _dialog.visible:
		return
	var text := WordCatalog.text(word_id, GameSession.word_language)
	_toast.hide()
	_praise.show_message(text)
	WordVoice.speak(text, GameSession.word_language)


## Points rise from where the pair met and glide into the score, which counts
## up as they land. Reduced animations: the score just counts up.
func _land_points(points: int, from: Vector2) -> void:
	if Motion.reduced:
		_score_meter.set_score(_current_score())
		return
	var label := Label.new()
	label.name = "Points"
	label.text = "+%d" % points
	label.theme_type_variation = &"FloatingPointsLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	move_child(label, _dialog.get_index())
	label.size = label.get_combined_minimum_size()
	label.pivot_offset = label.size / 2.0
	label.position = from - get_global_position() - label.size / 2.0
	var target := _score_meter.target_global() - get_global_position() - label.size / 2.0
	label.scale = Vector2(0.5, 0.5)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2(1.1, 1.1), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 40.0, 0.25).set_trans(Tween.TRANS_SINE)
	tween.set_parallel()
	tween.chain().tween_property(label, "position", target, POINTS_RISE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "scale", Vector2(0.55, 0.55), POINTS_RISE).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "modulate:a", 0.4, POINTS_RISE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		_score_meter.set_score(_current_score())
		_score_meter.pulse()
		label.queue_free())


## Halfway, and the last 10 tiles on bigger boards: each once per attempt.
func _check_milestones(delay: float) -> void:
	var total := _model.tile_count()
	if not _half_reached and _model.remaining * 2 <= total:
		_half_reached = true
		_after(delay + MILESTONE_DELAY, _play_milestone.bind("Halfway there!", false))
	elif not _final_reached and total > FINAL_TILES * 2 and _model.remaining <= FINAL_TILES:
		_final_reached = true
		_after(delay + MILESTONE_DELAY, _play_milestone.bind("Last %d tiles!" % FINAL_TILES, true))


## A milestone: words in the lane, a chord, a light sweep over the board and,
## for the last tiles, the music swells until the level ends.
func _play_milestone(text: String, final: bool) -> void:
	if _model.is_cleared() or _failed or _dialog.visible or tutorial_active():
		return
	_toast.hide()
	_praise.show_message(text)
	AudioManager.play_sfx("milestone_final" if final else "milestone")
	AudioManager.vibrate(30)
	if final:
		AudioManager.lift_music_for(maxf(_time_left, 10.0))
	_play_board_sweep()


## A soft band of golden light crossing the board once.
func _play_board_sweep() -> void:
	if Motion.reduced:
		return
	var area := _board.get_global_rect()
	var clip := Control.new()
	clip.name = "Sweep"
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.position = area.position - get_global_position()
	clip.size = area.size
	add_child(clip)
	move_child(clip, _dialog.get_index())
	var band := TextureRect.new()
	band.texture = _sweep_texture()
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	band.material = additive
	band.size = Vector2(area.size.x * 0.4, area.size.y * 1.3)
	band.pivot_offset = band.size / 2.0
	band.rotation = deg_to_rad(14.0)
	band.position = Vector2(-band.size.x * 1.2, -area.size.y * 0.15)
	band.modulate.a = 0.55
	clip.add_child(band)
	var tween := clip.create_tween()
	tween.tween_property(band, "position:x", area.size.x + band.size.x * 0.2, SWEEP_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(clip.queue_free)


static var _sweep_gradient: GradientTexture2D


static func _sweep_texture() -> GradientTexture2D:
	if _sweep_gradient == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		gradient.colors = PackedColorArray([Color(0.98, 0.88, 0.62, 0.0), Color(0.98, 0.88, 0.62, 0.45), Color(0.98, 0.88, 0.62, 0.0)])
		_sweep_gradient = GradientTexture2D.new()
		_sweep_gradient.gradient = gradient
		_sweep_gradient.width = 64
		_sweep_gradient.height = 8
	return _sweep_gradient


## Runs `action` after `seconds` (next frame for 0), unless this screen is gone.
func _after(seconds: float, action: Callable) -> void:
	if seconds <= 0.0:
		action.call_deferred()
		return
	var tween := create_tween()
	tween.tween_interval(seconds)
	tween.tween_callback(action)


## Matches in a row, counting the last one: the match melody's step, which
## climbs while matches come within AudioManager.melody_window of each other.
func combo_count() -> int:
	return AudioManager.melody_step() + 1


## Praise for matches in a row, in the feedback lane below the board: a cue
## when a new tier is reached ("Nice!" … "Zen Master!"), a buzz that grows
## with the tier, and a soft edge glow for the top tier.
func _show_combo(combo: int) -> void:
	# The tutorial's coach panel owns the lane while it runs.
	if tutorial_active():
		AudioManager.vibrate()
		return
	var tier := _praise.show_combo(combo)
	if tier == 0:
		AudioManager.vibrate()
		return
	_toast.hide()
	if ComboFeedback.reaches_tier(combo):
		# A new tier is never silent: its cue cuts off the oldest one still ringing.
		AudioManager.play_sfx("combo", AudioCatalog.COMBO_CUES[tier - 1], true)
		if tier == ComboFeedback.TIERS.size():
			_play_edge_glow()
	AudioManager.vibrate(20 + 8 * tier)


## A soft golden glow around the screen edges, never over the middle.
func _play_edge_glow() -> void:
	if Motion.reduced:
		return
	var glow := TextureRect.new()
	glow.name = "EdgeGlow"
	glow.texture = _edge_glow_texture()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.modulate.a = 0.0
	add_child(glow)
	move_child(glow, _dialog.get_index())
	var tween := glow.create_tween()
	tween.tween_property(glow, "modulate:a", 1.0, EDGE_GLOW_SECONDS * 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(glow, "modulate:a", 0.0, EDGE_GLOW_SECONDS * 0.7).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(glow.queue_free)


static var _edge_texture: GradientTexture2D


static func _edge_glow_texture() -> GradientTexture2D:
	if _edge_texture == null:
		var gradient := Gradient.new()
		# Clear over the board; only the outer rim (and the corners) warms up.
		gradient.offsets = PackedFloat32Array([0.0, 0.86, 1.0])
		gradient.colors = PackedColorArray([Color(1, 0.85, 0.5, 0), Color(1, 0.85, 0.5, 0), Color(1, 0.82, 0.45, 0.26)])
		_edge_texture = GradientTexture2D.new()
		_edge_texture.gradient = gradient
		_edge_texture.fill = GradientTexture2D.FILL_RADIAL
		_edge_texture.fill_from = Vector2(0.5, 0.5)
		_edge_texture.fill_to = Vector2(1.0, 0.5)
		_edge_texture.width = 64
		_edge_texture.height = 64
	return _edge_texture


func _on_hint_pressed() -> void:
	if _model.is_cleared() or _failed or _dialog.visible or _board.is_busy():
		return
	# Never spend a free hint or ask for an ad when there is nothing to show.
	if _tray_mode() and _tray.free_match(_model) < 0 and not _model.has_moves():
		_show_toast("No free pair right now. Shuffle can help.")
		return
	if not _tray_mode() and not _model.has_moves():
		_show_no_moves()
		return
	# With ads: a free hint per level, then saved Lotus Gift hints, then one
	# hint per rewarded ad. Without ads (web build) hints stay free.
	if AdsManager.is_available() and _free_hints <= 0 and GameSession.progress.spend_saved_tool("hints"):
		_update_hud()
		_give_hint()
		return
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
	if _tray_mode() and _give_tray_hint():
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
	if tutorial_active():
		_tutorial.on_tool_used()


## Tray hint: a free tile whose partner waits in the tray glows with that
## slot. False when no waiting tile has a free partner (a board pair is shown
## instead).
func _give_tray_hint() -> bool:
	var lone := _tray.free_match(_model)
	if lone < 0:
		return false
	_clear_hint()
	_hint = Vector2i(lone, -1)
	_board.set_highlight(lone, TileView.Highlight.HINT)
	_tray_bar.highlight_slot(_tray.tiles.find(_tray.partner_for(_model, lone)))
	_hints_used += 1
	AudioManager.play_sfx("hint")
	if tutorial_active():
		_tutorial.on_tool_used()
	return true


## Magnet: pulls the match of a waiting tile out of the board (even from under
## other tiles) into the tray; with an empty tray it takes a free tile and pulls
## its match. A free magnet per level, then one per rewarded ad.
func _on_magnet_pressed() -> void:
	if not _tray_mode() or _model.is_cleared() or _failed or _dialog.visible or _board.is_busy():
		return
	if _tray.magnet_target(_model).y < 0:
		_show_toast("Nothing for the magnet to pull right now.")
		return
	if AdsManager.is_available() and _free_magnets <= 0:
		_dialog.open("Need a Magnet?", "Watch a short ad to pull a matching tile into the tray.")
		_dialog.add_action("Watch Ad", func() -> void:
			AdsManager.show_rewarded("magnet", _on_magnet_ad_done), true)
		_dialog.add_action("No Thanks", func() -> void: pass)
		return
	if AdsManager.is_available():
		_free_magnets -= 1
	_use_magnet()


func _on_magnet_ad_done(rewarded: bool) -> void:
	if not rewarded:
		_show_toast("Watch the whole ad to use the magnet.")
	elif not (_model.is_cleared() or _failed):
		_use_magnet()


func _use_magnet() -> void:
	var target := _tray.magnet_target(_model)
	if target.y < 0:
		return
	_clear_hint()
	_magnets += 1
	AudioManager.play_sfx("hint")
	if tutorial_active():
		_tutorial.on_tool_used()
	if target.x < 0:
		_magnet_pull(target.y)
		return
	# Empty tray: a free tile goes first; its match is pulled once it lands.
	_take_into_tray(target.x)
	_after(Motion.duration(TrayBar.FLIGHT + 0.12), _magnet_pull.bind(target.y))


func _magnet_pull(index: int) -> void:
	if _failed or _model.is_cleared():
		return
	var move := _tray.pull(_model, index)
	if move == null:
		return
	var revealed := _specials.reveal_free(_model)
	_revealed_count += revealed.size()
	_board.play_take(index, revealed)
	_tray_match(move)


## Magnets used this attempt (tests).
func magnets_used() -> int:
	return _magnets


func _on_shuffle_pressed() -> void:
	if _model.is_cleared() or _failed or _dialog.visible or _board.is_busy():
		return
	# With ads: a free shuffle per level, then saved Lotus Gift shuffles, then
	# one shuffle per rewarded ad. Without ads (web build, or no ad loaded)
	# shuffles stay free.
	if AdsManager.is_available() and _free_shuffles <= 0 and GameSession.progress.saved_tools("shuffles") > 0:
		if _shuffle_tiles():
			GameSession.progress.spend_saved_tool("shuffles")
			_update_hud()
		return
	if AdsManager.is_available() and _free_shuffles <= 0:
		_dialog.open("Need a Shuffle?", "Watch a short ad to shuffle the tiles.")
		_dialog.add_action("Watch Ad", func() -> void:
			AdsManager.show_rewarded("shuffle", _on_shuffle_ad_done), true)
		_dialog.add_action("No Thanks", func() -> void: pass)
		return
	if _shuffle_tiles() and AdsManager.is_available():
		_free_shuffles -= 1
		_update_hud()


func _on_shuffle_ad_done(rewarded: bool) -> void:
	if not rewarded:
		_show_toast("Watch the whole ad to shuffle.")
	elif not (_model.is_cleared() or _failed):
		_shuffle_tiles()


## Rearranges the tiles left; false when no solvable arrangement exists.
func _shuffle_tiles() -> bool:
	# Tiles waiting in the tray go back to the board and are shuffled with it.
	var waiting := _tray.tiles.duplicate()
	_tray.empty_into(_model)
	var result := BoardGenerator.reshuffle(_model, _level.deal_seed + 7919 * (_shuffles + 1))
	if not result.ok:
		for index in waiting:
			_model.set_taken(index)
		_tray.tiles = waiting
		_show_toast("These tiles can't be rearranged into a solvable board. Try Undo.")
		return false
	_undo_stack.append({"kind": UndoKind.SHUFFLE, "faces": _model.faces.duplicate(), "tray": waiting})
	_tray_bar.sync(_tray.tiles, _board)
	_model.set_faces(result.faces)
	_shuffles += 1
	AudioManager.play_sfx("shuffle")
	if tutorial_active():
		_tutorial.on_tool_used()
	AudioManager.reset_melody()
	_set_selected(-1)
	_clear_hint()
	_board.play_shuffle()
	_update_hud()
	_show_toast("Tiles shuffled")
	return true


func _on_undo_pressed() -> void:
	if _failed or _dialog.visible or _model.is_cleared() or _board.is_busy():
		return
	# With ads: past the undos of this attempt, one more undo per rewarded ad.
	if undo_ad_offered():
		_dialog.open("Need an Undo?", "Watch a short ad to take back your last move.")
		_dialog.add_action("Watch Ad", func() -> void:
			AdsManager.show_rewarded("undo", _on_undo_ad_done), true)
		_dialog.add_action("No Thanks", func() -> void: pass)
		return
	if not can_undo():
		return
	var entry: Dictionary = _undo_stack.pop_back()
	_undos_left -= 1
	AudioManager.play_sfx("undo")
	if tutorial_active():
		_tutorial.on_tool_used()
	_set_selected(-1)
	_clear_hint()
	if entry["kind"] == UndoKind.TRAY:
		_undo_tray(entry)
	elif entry["kind"] == UndoKind.MATCH:
		AudioManager.melody_step_back()
		var pair: Vector2i = entry["pair"]
		_model.restore_pair(pair.x, pair.y)
		_matches -= 1
		_score.take_back(int(entry.get("points", 0)))
		_score_meter.set_score(_current_score())
		_board.play_restore(pair.x, pair.y)
	else:
		_model.set_faces(entry["faces"])
		var waiting: Array[int] = []
		waiting.assign(entry.get("tray", []))
		if waiting.is_empty():
			_board.play_shuffle()
		else:
			# The tiles that waited in the tray go back into it.
			for index in waiting:
				_model.set_taken(index)
			_tray.tiles = waiting
			_board.refresh_all()
			_tray_bar.sync(_tray.tiles, _board)
	_update_hud()


## Undo in the tray: the tile goes home; a matched partner returns to its slot
## with the points taken back; a close call no longer counts.
func _undo_tray(entry: Dictionary) -> void:
	var move: TileTray.Move = entry["move"]
	_tray.undo(_model, move)
	if move.matched():
		AudioManager.melody_step_back()
		_matches -= 1
		_score.take_back(int(entry.get("points", 0)))
		_score_meter.set_score(_current_score())
	elif move.close_call:
		_mistakes = maxi(_mistakes - 1, 0)
	_board.play_return(move.tile)
	_tray_bar.sync(_tray.tiles, _board)


func _on_undo_ad_done(rewarded: bool) -> void:
	if not rewarded:
		_show_toast("Watch the whole ad to undo.")
	elif not (_model.is_cleared() or _failed):
		_undos_left += 1
		_update_hud()
		_on_undo_pressed()


func _set_selected(index: int) -> void:
	if _selected >= 0:
		_board.set_highlight(_selected, TileView.Highlight.NONE)
	_selected = index
	if _selected >= 0:
		_board.set_highlight(_selected, TileView.Highlight.SELECTED)
	if tutorial_active():
		_tutorial.on_selected(index)


func _clear_hint() -> void:
	_tray_bar.clear_highlight()
	if _hint.x >= 0:
		_board.set_highlight(_hint.x, TileView.Highlight.NONE)
		_board.set_highlight(_hint.y, TileView.Highlight.NONE)
	_hint = Vector2i(-1, -1)
	if _selected >= 0:
		_board.set_highlight(_selected, TileView.Highlight.SELECTED)


func _update_hud() -> void:
	_tiles_value.text = str(_model.remaining)
	if AdsManager.is_available():
		# Free ones of this level plus saved Lotus Gift ones.
		var hints := _free_hints + GameSession.progress.saved_tools("hints")
		var shuffles := _free_shuffles + GameSession.progress.saved_tools("shuffles")
		_hint_label.text = "Hint (%d)" % hints if hints > 0 else "Ad Hint"
		_shuffle_label.text = "Shuffle (%d)" % shuffles if shuffles > 0 else "Ad Shuffle"
	else:
		_hint_label.text = "Hint"
		_shuffle_label.text = "Shuffle"
	_undo_label.text = "Ad Undo" if undo_ad_offered() else "Undo (%d)" % _undos_left
	if AdsManager.is_available():
		_magnet_label.text = "Magnet (%d)" % _free_magnets if _free_magnets > 0 else "Ad Magnet"
	else:
		_magnet_label.text = "Magnet"
	_magnet_button.disabled = _model.is_cleared()
	_update_timer_label()
	_level_value.text = _level_name()
	_level_caption.text = _level.title.to_upper()
	_undo_button.disabled = not (can_undo() or undo_ad_offered())
	_hint_button.disabled = _model.is_cleared()
	_shuffle_button.disabled = _model.is_cleared()


func _open_pause_menu() -> void:
	# A cleared board is about to show Level Complete.
	if _model and _model.is_cleared():
		return
	_pause_open = true
	_dialog.open("Paused", "%s · %s" % [_level_name(), _level.title])
	_dialog.add_action("Resume", _resume, true)
	_dialog.add_action("Settings", _open_settings)
	if not _learning():
		_dialog.add_action("Tile Collection", _open_collection_picker)
	_dialog.add_action("Restart", _restart)
	_dialog.add_action("Stages" if _learning() else ("Calendar" if _daily() else "Levels"), _go_to_list)


func _level_name() -> String:
	if _daily():
		return "Daily"
	return "Stage %d" % GameSession.word_stage if _learning() else "Level %d" % _level.number


func _go_to_list() -> void:
	if _learning():
		GameSession.go_words()
	elif _daily():
		GameSession.go_daily()
	else:
		GameSession.go_levels()


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
	if _model and not _learning():
		_set_selected(-1)
		_clear_hint()
		_board.apply_skin(TileCollectionManager.skin_for_board(_model.faces, _level.deal_seed))
		_tray_bar.sync(_tray.tiles, _board)
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
	if can_undo() or undo_ad_offered():
		_dialog.add_action("Undo", _on_undo_pressed)
	_dialog.add_action("Restart", _restart)


func _show_level_complete() -> void:
	_praise.dismiss()
	AudioManager.play_sfx("level_complete")
	AudioManager.duck_music_for(3.0)
	if _learning():
		_show_stage_complete()
		return
	if _daily():
		_show_daily_complete()
		return
	var seconds := int(_elapsed)
	var summary := "%s cleared in %d:%02d with %s left\n%s · %s · %s" % [
		_level.title, floori(seconds / 60.0), seconds % 60, _clock(_time_left),
		_mistake_count(), _count(_hints_used, "hint", "hints"),
		_count(_shuffles, "shuffle", "shuffles")]
	var earned := LevelRating.stars(_time_left, _level.time_limit, _mistakes)
	_final_score = _score.total(_time_left, _mistakes)
	_score_meter.set_score(_final_score)
	var record := GameSession.progress.record_clear(_level.number, earned, _time_left, LevelCatalog.count(), _final_score)
	GameSession.just_unlocked = record.unlocked
	if _final_score > record.previous_score:
		PlayGames.submit_total(GameSession.progress.total_score(LevelCatalog.count()))
	if record.new_best_score:
		summary += "\nNew best score!"
	elif record.new_best_stars and record.previous_stars > 0:
		summary += "\nNew best: %d stars!" % earned
	elif record.new_best_time:
		summary += "\nNew best time!"
	if earned < LevelRating.MAX_STARS:
		summary += "\n" + _next_star_tip(earned)
	var perfect := LotusRewards.is_perfect(_mistakes, _hints_used + _magnets, _shuffles)
	if perfect:
		GameSession.progress.record_perfect(_level.number)
	if GameSession.progress.is_lotus_ready(_level.number):
		summary += "\nA Lotus Gift has bloomed on your journey map."
	var title := "Perfect Clear!" if perfect else "Level Complete!"
	if GameSession.has_next_level():
		_dialog.open(title, summary)
		_dialog.add_action("Next Level", func() -> void: AdsManager.after_level_complete(GameSession.play_next_level), true)
	else:
		_dialog.open("Journey Complete!", summary + "\nYou have finished every introductory level.")
	_dialog.set_stars(earned, LevelRating.MAX_STARS, true)
	_dialog.set_score(_final_score, _score_breakdown(), earned)
	_dialog.add_action("Replay", func() -> void: AdsManager.after_level_complete(_restart), not GameSession.has_next_level())
	_dialog.add_action("Levels", func() -> void: AdsManager.after_level_complete(GameSession.go_levels))
	_report_rank()
	_play_celebration()
	if perfect:
		_play_perfect_bloom()
	AudioManager.vibrate(60)
	_award_level_badges()
	_reveal_badges(0.65 + 0.32 * earned + (0.3 if Motion.reduced else 1.5))


## Word Garden's end of stage: the words of the board, then on to the next.
func _show_stage_complete() -> void:
	var language := GameSession.word_language
	var earned := WordCatalog.stars(_mistakes)
	GameSession.progress.record_word_stage(language, GameSession.word_stage, earned, _word_ids, _words_missed)
	var shown := PackedStringArray()
	for word_id in _word_ids:
		shown.append(WordCatalog.text(word_id, language))
	_dialog.open("Stage Complete!", "%d words today\n%s" % [_word_ids.size(), " · ".join(shown)])
	_dialog.use_word_font()
	if GameSession.word_stage < WordCatalog.stage_count():
		_dialog.add_action("Next Stage", func() -> void:
			AdsManager.after_level_complete(GameSession.play_word_stage.bind(language, GameSession.word_stage + 1)), true)
	_dialog.add_action("Replay", func() -> void: AdsManager.after_level_complete(_restart), GameSession.word_stage == WordCatalog.stage_count())
	_dialog.add_action("Stages", func() -> void: AdsManager.after_level_complete(GameSession.go_words))
	_dialog.set_stars(earned, LevelRating.MAX_STARS, true)
	_play_celebration()
	AudioManager.vibrate(60)
	GameSession.progress.record_badge_facts({}, BadgeBook.today())
	_earned_badges = BadgeBook.award(GameSession.progress, LevelCatalog.count())
	_reveal_badges(0.65 + 0.32 * earned + 0.4)


## What this clear adds to the counted badges, then any ranks it reached.
func _award_level_badges() -> void:
	var facts := {}
	if _mistakes == 0:
		facts["still_mind"] = 1
	if _time_left >= _level.time_limit * 0.75:
		facts["swift_stream"] = 1
	if _hints_used == 0 and _shuffles == 0 and _magnets == 0:
		facts["quiet_hands"] = 1
	# On tray levels: cleared after the tray had only one place left.
	if (_tray_mode() and _mistakes > 0) or (not _tray_mode() and _level.mistake_limit > 1 and hearts_left() == 1):
		facts["last_petal"] = 1
	if _best_multiplier >= LevelScore.MAX_MULTIPLIER:
		facts["flowing_river"] = 1
	if _golden_matched:
		facts["golden_lotus"] = 1
	if _revealed_count > 0:
		facts["veil_lifter"] = _revealed_count
	GameSession.progress.record_badge_facts(facts, BadgeBook.today())
	_earned_badges = BadgeBook.award(GameSession.progress, LevelCatalog.count())


## Plays the reveal once the end-of-level dialog has had its moment. A player
## who leaves first still finds the badge marked new on the Badges page.
func _reveal_badges(delay: float) -> void:
	if _earned_badges.is_empty() or not GameSession.badge_reveals_enabled:
		return
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		if _dialog.visible:
			_badge_reveal.play(_earned_badges))


## The end of a Daily Challenge: the day, the streak and the month's trophy.
func _show_daily_complete() -> void:
	var store := GameSession.progress
	var day := GameSession.daily_day
	var today := BadgeBook.today()
	var earned := DailyChallenge.stars(_mistakes)
	var month_days := DailyChallenge.days_in_month(day)
	var trophy_before := DailyChallenge.trophy_rank(DailyChallenge.month_count(store, day), month_days)
	store.record_daily(day, earned, day == today)
	var cleared := DailyChallenge.month_count(store, day)
	var trophy := DailyChallenge.trophy_rank(cleared, month_days)
	var month: String = DailyChallenge.MONTH_NAMES[int(DailyChallenge.date_of(day).month) - 1]
	var lines := PackedStringArray([_level.title, "%d of %d days in %s" % [cleared, month_days, month]])
	if day == today:
		lines.append("%d day streak" % store.daily_streak(today))
	if trophy > trophy_before:
		lines.append("%s Trophy: %s!" % [month, BadgeBook.RANK_NAMES[trophy]])
	_dialog.open("Daily Complete!", "\n".join(lines))
	_dialog.add_action("Calendar", func() -> void: AdsManager.after_level_complete(GameSession.go_daily), true)
	_dialog.add_action("Replay", func() -> void: AdsManager.after_level_complete(_restart))
	_dialog.set_stars(earned, LevelRating.MAX_STARS, true)
	_play_celebration()
	AudioManager.vibrate(60)
	store.record_badge_facts({}, today)
	_earned_badges = BadgeBook.award(store, LevelCatalog.count())
	_reveal_badges(0.65 + 0.32 * earned + 0.4)


## Counts the clear for the week and shows the world rank when it arrives.
func _report_rank() -> void:
	var week := GlobalRankService.week_number(int(Time.get_unix_time_from_system()))
	var week_points := GameSession.progress.add_week_points(_final_score, week)
	if not GlobalRank.is_available():
		return
	_dialog.set_rank("Finding your world rank...")
	GlobalRank.report(GameSession.progress.total_score(LevelCatalog.count()), week_points, _on_rank_reported)


func _on_rank_reported(answer: Dictionary) -> void:
	if _dialog.visible:
		_dialog.set_rank(GlobalRankService.rank_text(answer))


## Ranks the last clear earned, best first ({id, rank}).
func earned_badges() -> Array[Dictionary]:
	return _earned_badges


func _on_star_popped(index: int) -> void:
	var note: int = STAR_NOTES[mini(index, STAR_NOTES.size() - 1)]
	AudioManager.play_sfx("star", AudioCatalog.MATCH_NOTES[note])
	AudioManager.vibrate(15)


## A gentle shower of sakura petals over the whole screen, behind the dialog.
func _play_celebration() -> void:
	if Motion.reduced:
		return
	var shower := CPUParticles2D.new()
	shower.name = "Celebration"
	shower.texture = PETAL_TEXTURE
	shower.amount = 26
	shower.lifetime = 4.0
	shower.one_shot = true
	shower.explosiveness = 0.35
	shower.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	shower.emission_rect_extents = Vector2(size.x / 2.0, 20.0)
	shower.position = Vector2(size.x / 2.0, -40.0)
	shower.direction = Vector2(0.2, 1.0)
	shower.spread = 25.0
	shower.gravity = Vector2(0, 90)
	shower.initial_velocity_min = 120.0
	shower.initial_velocity_max = 260.0
	shower.angular_velocity_min = -90.0
	shower.angular_velocity_max = 90.0
	shower.angle_min = -180.0
	shower.angle_max = 180.0
	shower.scale_amount_min = 0.45
	shower.scale_amount_max = 0.8
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.1, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	shower.color_ramp = fade
	# Above the board, below the dialog (which is drawn later in the tree).
	add_child(shower)
	move_child(shower, _dialog.get_index())
	shower.emitting = true
	var tween := shower.create_tween()
	tween.tween_interval(shower.lifetime + 1.0)
	tween.tween_callback(shower.queue_free)


## A Perfect Clear: a gold lotus opens as a crest on top of the dialog, with
## a soft chime (reduced animations: it fades in already open).
func _play_perfect_bloom() -> void:
	var bloom := LotusMark.new()
	bloom.name = "PerfectBloom"
	bloom.tint = Color(1.0, 0.92, 0.66)
	bloom.size = Vector2(176, 176)
	bloom.pivot_offset = bloom.size / 2.0
	# Above the dialog (z 20), placed once its panel has settled.
	bloom.z_index = 21
	bloom.modulate.a = 0.0
	add_child(bloom)
	var tween := bloom.create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(func() -> void:
		var panel := _dialog.get_node("%Panel") as Control
		var top := get_global_transform().affine_inverse() * panel.get_global_rect().position
		bloom.position = Vector2(size.x / 2.0 - bloom.size.x / 2.0, top.y - bloom.size.y * 0.62)
		AudioManager.play_sfx("reward"))
	if Motion.reduced:
		tween.tween_property(bloom, "modulate:a", 1.0, 0.3)
	else:
		bloom.openness = 0.0
		bloom.scale = Vector2.ONE * 0.6
		tween.tween_property(bloom, "modulate:a", 1.0, 0.3)
		tween.parallel().tween_property(bloom, "openness", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(bloom, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# The crest stays while the dialog is open; it leaves with the screen.


## "Matches 1,800 · Time +340 · Flawless +500"
func _score_breakdown() -> String:
	var parts := ["Matches %s" % ScoreMeter.format_points(_score.match_points),
		"Time +%s" % ScoreMeter.format_points(LevelScore.time_bonus(_time_left))]
	if LevelScore.flawless_bonus(_mistakes) > 0:
		parts.append("Flawless +%s" % ScoreMeter.format_points(LevelScore.FLAWLESS_BONUS))
	return " · ".join(parts)


func _next_star_tip(earned: int) -> String:
	if _tray_mode():
		if earned == 1:
			return "For 2 stars: let the tray fill to 3 tiles at most once."
		return "For 3 stars: never fill the tray to 3 tiles, and keep half the time."
	if earned == 1:
		return "For 2 stars: make at most 1 mistake."
	return "For 3 stars: no mistakes and half the time left."


## "0 mistakes", or on tray levels "1 close call" (the tray reached 3 tiles).
func _mistake_count() -> String:
	if _tray_mode():
		return _count(_mistakes, "close call", "close calls")
	return _count(_mistakes, "mistake", "mistakes")


func _exit_tree() -> void:
	# Leaving the level mid-ad must not leave the ad covering the next screen.
	if AdsManager.is_showing():
		AdsManager.cancel()


func _process(delta: float) -> void:
	if _model:
		_score_meter.set_combo(LevelScore.multiplier(combo_count()),
			AudioManager.melody_time_left() / maxf(AudioManager.melody_window, 0.001))
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
	return _model != null and _level.time_limit > 0 and not _failed and not _model.is_cleared() and not tutorial_active() \
		and not _dialog.visible and not _picker.visible and not _settings.visible and not AdsManager.is_showing()


## Picking two free tiles that don't match costs a heart.
func _register_mistake(a: int, b: int) -> void:
	if tutorial_active():
		# While learning, a wrong pair costs nothing: just gentle feedback.
		_set_selected(-1)
		_clear_hint()
		_board.tile(a).play_mistake()
		_board.tile(b).play_mistake()
		AudioManager.play_sfx("mistake")
		_tutorial.remark("Those two don't match. Look for two identical tiles.")
		return
	if _learning():
		_word_mistake(a, b)
		return
	if _daily():
		_soft_mistake(a, b)
		return
	_mistakes += 1
	_set_selected(-1)
	_clear_hint()
	_board.tile(a).play_mistake()
	_board.tile(b).play_mistake()
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


## No hearts in a Daily Challenge: a mistake only costs stars.
func _soft_mistake(a: int, b: int) -> void:
	_mistakes += 1
	_set_selected(-1)
	_clear_hint()
	_board.tile(a).play_mistake()
	_board.tile(b).play_mistake()
	AudioManager.play_sfx("mistake")
	_show_toast("Those tiles don't match.")


## No hearts to lose: the tiles shake softly, the picked word is shown again
## and both words come back in a later stage.
func _word_mistake(a: int, b: int) -> void:
	_mistakes += 1
	_set_selected(-1)
	_clear_hint()
	_board.tile(a).play_mistake()
	_board.tile(b).play_mistake()
	AudioManager.play_sfx("mistake")
	for index in [a, b]:
		var word_id := WordCatalog.id_of(_model.face_of(index))
		if not _words_missed.has(word_id):
			_words_missed.append(word_id)
	var shown := a if WordCatalog.is_picture(_model.face_of(a)) else b
	if WordCatalog.is_picture(_model.face_of(shown)):
		var word_id := WordCatalog.id_of(_model.face_of(shown))
		var text := WordCatalog.text(word_id, GameSession.word_language)
		_show_toast("%s: %s" % ["That picture is" if WordCatalog.has_picture(word_id) else "In this language", text])
		WordVoice.speak(text, GameSession.word_language)
	else:
		_show_toast("Match each word with its picture or meaning.")


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
	var title: String = {LossReason.TIME: "Out of Time", LossReason.MISTAKES: "Too Many Mistakes",
		LossReason.TRAY: "Tray Full"}[reason]
	var why: String = {LossReason.TIME: "The clock ran out.",
		LossReason.MISTAKES: "You used all %d hearts." % _level.mistake_limit,
		LossReason.TRAY: "%d tiles are waiting without a pair." % TileTray.CAPACITY}[reason]
	_dialog.open(title, "%s\n%s · %s: %d of %d pairs matched." % [
		why, _level_name(), _level.title, _matches, pairs])
	_last_loss = reason
	var offer_second_chance := AdsManager.is_available() \
		and _second_chances < int(AdsManager.setting("second_chances_per_attempt", 1))
	if offer_second_chance:
		var label: String = {LossReason.TIME: "Watch Ad: +%d s" % int(AdsManager.setting("second_chance_seconds", 60)),
			LossReason.MISTAKES: "Watch Ad: +1 Heart",
			LossReason.TRAY: "Watch Ad: Free %d Places" % TRAY_SECOND_CHANCE}[reason]
		_dialog.add_action(label, func() -> void: AdsManager.show_rewarded("second_chance", _on_second_chance_done), true)
	_dialog.add_action("Replay" if reason == LossReason.TRAY else "Retry",
		func() -> void: AdsManager.after_level_lost(_restart), not offer_second_chance)
	_dialog.add_action("Calendar" if _daily() else "Levels", func() -> void: AdsManager.after_level_lost(_go_to_list))


## Rewarded second chance: continue the same board with more time or a heart.
func _on_second_chance_done(rewarded: bool) -> void:
	if not rewarded:
		_lose_again_dialog()
		return
	_second_chances += 1
	_failed = false
	if _last_loss == LossReason.TRAY:
		var sent := _tray.send_back(_model, TRAY_SECOND_CHANCE)
		for index in sent:
			_board.play_return(index)
		_tray_bar.release_last(sent.size())
		# Undo entries for the tiles sent back no longer apply.
		_undo_stack.clear()
		_update_hud()
		_show_toast("%d tiles went back to the board. Keep going!" % sent.size())
	elif _last_loss == LossReason.TIME:
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


## What the score pill should show: the final score once cleared (points
## still gliding in from the last pair must not count it back down).
func _current_score() -> int:
	return _final_score if _final_score > 0 else _score.match_points


## Mystery and golden lotus tiles of the current board.
func specials() -> TileSpecials:
	return _specials


## Points from matches so far this attempt.
func match_points() -> int:
	return _score.match_points


## The score of the last clear (0 until the level is cleared).
func final_score() -> int:
	return _final_score


func free_hints_left() -> int:
	return _free_hints


func free_shuffles_left() -> int:
	return _free_shuffles


func undos_left() -> int:
	return _undos_left


func can_undo() -> bool:
	return _undos_left > 0 and not _undo_stack.is_empty()


## True when the undos of this attempt are used up and an ad can buy one more.
func undo_ad_offered() -> bool:
	return _undos_left <= 0 and not _undo_stack.is_empty() and AdsManager.is_available()


func _build_hearts() -> void:
	for child in _hearts.get_children():
		child.queue_free()
	for i in _level.mistake_limit:
		var heart := TextureRect.new()
		heart.texture = HEART_TEXTURE
		heart.custom_minimum_size = Vector2(HEART_SIZE, HEART_SIZE)
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
	if tutorial_active():
		_tutorial.remark(text)
		return
	if _praise:
		_praise.dismiss()
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
