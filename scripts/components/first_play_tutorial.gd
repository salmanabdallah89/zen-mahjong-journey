class_name FirstPlayTutorial
extends PanelContainer
## First-play tutorial on level 1, played on the real board: three short
## steps in the message lane (never over the tiles), with Skip always visible.
##   1. MATCH: a free, matching pair glows; the player taps both.
##   2. FREE:  what makes a tile free; the player finds a pair on their own.
##   3. TOOLS: Hint, Shuffle and Undo; any next move (or the button) ends it.
## The game screen feeds it the player's moves and pauses the clock and
## hearts while it runs. It only highlights; it never changes the board, so
## it cannot make a level unsolvable (the highlighted pair is chosen so the
## board stays solvable after it).

signal finished(skipped: bool)

enum Step { MATCH, FREE, TOOLS, DONE }

const TEXT_MATCH := "These two glowing tiles match and are free. Tap both!"
const TEXT_PARTNER := "Now tap its glowing partner."
const TEXT_FREE := "A tile is free when nothing is on top and a side is open. Find a pair yourself!"
const TEXT_TOOLS := "Stuck? Hint finds a pair, Shuffle mixes the tiles, Undo steps back."
## Seconds a passing remark (mistake, blocked tap) replaces the step text.
const REMARK_SECONDS := 2.6

var step := Step.MATCH
## The pair highlighted in step 1 (tile indices).
var pair := Vector2i(-1, -1)

var _board: BoardView
var _label: Label
var _button: Button
var _remark_tween: Tween


func _ready() -> void:
	theme_type_variation = &"CoachPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	add_child(row)
	_label = Label.new()
	_label.theme_type_variation = &"ToastLabel"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_label)
	_button = Button.new()
	_button.theme_type_variation = &"SecondaryButton"
	_button.custom_minimum_size = Vector2(220, 120)
	_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(_on_button_pressed)
	row.add_child(_button)


## Starts on `board`, highlighting `match_pair`.
func begin(board: BoardView, match_pair: Vector2i) -> void:
	_board = board
	pair = match_pair
	_set_step(Step.MATCH)
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, Motion.duration(0.25))


func is_active() -> bool:
	return step != Step.DONE


func text() -> String:
	return _label.text


## The player picked (or let go of) a tile.
func on_selected(index: int) -> void:
	if step != Step.MATCH:
		return
	_label.text = TEXT_PARTNER if index == pair.x or index == pair.y else TEXT_MATCH
	_glow_pair()


## Any pair was matched.
func on_matched(_a: int, _b: int) -> void:
	match step:
		Step.MATCH:
			_clear_pair_glow()
			_set_step(Step.FREE)
		Step.FREE:
			_set_step(Step.TOOLS)
		Step.TOOLS:
			_finish(false)


## A passing remark (a mismatch, a blocked tile) shown for a moment.
func remark(text_now: String) -> void:
	if step == Step.DONE:
		return
	if _remark_tween:
		_remark_tween.kill()
	_label.text = text_now
	_remark_tween = create_tween()
	_remark_tween.tween_interval(REMARK_SECONDS)
	_remark_tween.tween_callback(_restore_text)


## The player used a tool (Hint, Shuffle, Undo): in the last step that is
## the lesson learned.
func on_tool_used() -> void:
	if step == Step.TOOLS:
		_finish(false)


func skip() -> void:
	_finish(true)


func _set_step(next: Step) -> void:
	step = next
	_restore_text()
	_button.text = "Start Playing" if step == Step.TOOLS else "Skip"
	_button.theme_type_variation = &"" if step == Step.TOOLS else &"SecondaryButton"
	if step == Step.MATCH:
		_glow_pair()


func _restore_text() -> void:
	match step:
		Step.MATCH:
			_label.text = TEXT_MATCH
		Step.FREE:
			_label.text = TEXT_FREE
		Step.TOOLS:
			_label.text = TEXT_TOOLS


## Keeps the step-1 pair glowing (the tile the player picked shows the gold
## selection instead).
func _glow_pair() -> void:
	for i in [pair.x, pair.y]:
		if i >= 0 and _board.tile(i).visible and _board.tile(i).highlight() == TileView.Highlight.NONE:
			_board.set_highlight(i, TileView.Highlight.HINT)


func _clear_pair_glow() -> void:
	for i in [pair.x, pair.y]:
		if i >= 0 and _board.tile(i).highlight() == TileView.Highlight.HINT:
			_board.set_highlight(i, TileView.Highlight.NONE)


func _on_button_pressed() -> void:
	_finish(step != Step.TOOLS)


func _finish(skipped: bool) -> void:
	if step == Step.DONE:
		return
	if step == Step.MATCH:
		_clear_pair_glow()
	step = Step.DONE
	if _remark_tween:
		_remark_tween.kill()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, Motion.duration(0.2))
	tween.tween_callback(hide)
	finished.emit(skipped)
