class_name ModalDialog
extends Control
## Full-screen modal: dims and blocks the screen behind it and shows a panel
## with a title, an optional row of stars, a message and a column of action
## buttons. Opening it fades the screen and gently pops the panel in.

## An earned star finished popping in (index from 0), for its chime.
signal star_popped(index: int)
## The level score finished counting up (set_score).
signal score_counted

const BURST_SCENE := preload("res://scenes/components/match_burst.tscn")
const BUTTON_SIZE := Vector2(560, 136)
const STAR := preload("res://assets/ui/icons/icon_star.png")
const STAR_SIZE := Vector2(110, 110)

@onready var _panel: PanelContainer = %Panel
@onready var _title: Label = %Title
@onready var _message: Label = %Message
@onready var _buttons: VBoxContainer = %Buttons
@onready var _stars: HBoxContainer = %Stars
var _score: Label
var _score_detail: Label
var _score_tween: Tween


func open(title: String, message: String) -> void:
	_title.text = title
	_message.text = message
	_message.visible = not message.is_empty()
	for child in _buttons.get_children():
		child.queue_free()
	_stars.hide()
	if _score != null:
		if _score_tween:
			_score_tween.kill()
		_score.hide()
		_score_detail.hide()
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, Motion.duration(0.2)).set_trans(Tween.TRANS_SINE)
	if not Motion.reduced:
		_pop_panel.call_deferred()


## The panel settles in from slightly small, after the layout has sized it.
func _pop_panel() -> void:
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.92, 0.92)
	_panel.create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Shows `earned` of `total` stars under the title. With `animate`, earned
## stars pop in one after another, each with a small sparkle and
## `star_popped` (the screen plays its chime).
func set_stars(earned: int, total := LevelRating.MAX_STARS, animate := false) -> void:
	for child in _stars.get_children():
		child.queue_free()
	for i in total:
		var star := TextureRect.new()
		star.texture = STAR
		star.custom_minimum_size = STAR_SIZE
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		star.pivot_offset = STAR_SIZE / 2.0
		star.modulate = Color.WHITE if i < earned else Color(0.35, 0.35, 0.35, 0.45)
		star.set_meta("earned", i < earned)
		_stars.add_child(star)
		if animate and i < earned:
			var tween := create_tween()
			tween.tween_interval(0.45 + 0.32 * i)
			if Motion.reduced:
				star.modulate.a = 0.0
				tween.tween_property(star, "modulate:a", 1.0, 0.12)
			else:
				star.scale = Vector2.ZERO
				tween.tween_property(star, "scale", Vector2(1.18, 1.18), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tween.tween_callback(_sparkle.bind(star))
				tween.tween_property(star, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
			tween.tween_callback(star_popped.emit.bind(i))
	_stars.show()


## Shows a level's score under the stars, counting up from 0 once the
## `earned` stars have popped in, with its breakdown below. Emits
## `score_counted` when the count lands (the screen plays its chime).
func set_score(total: int, detail: String, earned := 0) -> void:
	if _score == null:
		_score = Label.new()
		_score.name = "Score"
		_score.theme_type_variation = &"DialogScoreLabel"
		_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_score_detail = Label.new()
		_score_detail.name = "ScoreDetail"
		_score_detail.theme_type_variation = &"DialogBodyLabel"
		_score_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_score_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_score_detail.custom_minimum_size = Vector2(STAR_SIZE.x * 6.0, 0)
		var content := _stars.get_parent()
		content.add_child(_score)
		content.move_child(_score, _stars.get_index() + 1)
		content.add_child(_score_detail)
		content.move_child(_score_detail, _score.get_index() + 1)
	_score_detail.text = detail
	_score.show()
	_score_detail.show()
	if _score_tween:
		_score_tween.kill()
	_score_tween = create_tween()
	if Motion.reduced:
		_show_score(float(total))
		_score_tween.tween_interval(0.45 + 0.32 * earned)
	else:
		_show_score(0.0)
		_score_tween.tween_interval(0.45 + 0.32 * earned + 0.2)
		_score_tween.tween_method(_show_score, 0.0, float(total), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_score_tween.tween_callback(_pop_score)
	_score_tween.tween_callback(score_counted.emit)


func _show_score(value: float) -> void:
	_score.text = "Score %s" % ScoreMeter.format_points(roundi(value))


func _pop_score() -> void:
	_score.pivot_offset = _score.size / 2.0
	var tween := _score.create_tween()
	tween.tween_property(_score, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_score, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)


## The score text as shown right now ("" when the dialog has no score).
func score_text() -> String:
	return _score.text if _score != null and _score.visible else ""


func _sparkle(star: Control) -> void:
	var burst: Node2D = BURST_SCENE.instantiate()
	burst.position = STAR_SIZE / 2.0
	burst.scale = Vector2(0.8, 0.8)
	burst.set("with_petals", false)
	star.add_child(burst)


func stars_shown() -> int:
	var count := 0
	for child in _stars.get_children():
		if not child.is_queued_for_deletion() and child.get_meta("earned", false):
			count += 1
	return count if _stars.visible else -1


## Adds a button that closes the dialog and then runs `action`.
func add_action(text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not primary:
		button.theme_type_variation = &"SecondaryButton"
	button.pressed.connect(func() -> void:
		close()
		action.call())
	_buttons.add_child(button)
	return button


func close() -> void:
	hide()
