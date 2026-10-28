class_name ModalDialog
extends Control
## Full-screen modal: dims and blocks the screen behind it and shows a panel
## with a title, an optional row of stars, a message and a column of action
## buttons. Opening it fades the screen and gently pops the panel in.

## An earned star finished popping in (index from 0), for its chime.
signal star_popped(index: int)

const BURST_SCENE := preload("res://scenes/components/match_burst.tscn")
const BUTTON_SIZE := Vector2(560, 136)
const STAR := preload("res://assets/ui/icons/icon_star.png")
const STAR_SIZE := Vector2(110, 110)

@onready var _panel: PanelContainer = %Panel
@onready var _title: Label = %Title
@onready var _message: Label = %Message
@onready var _buttons: VBoxContainer = %Buttons
@onready var _stars: HBoxContainer = %Stars


func open(title: String, message: String) -> void:
	_title.text = title
	_message.text = message
	_message.visible = not message.is_empty()
	for child in _buttons.get_children():
		child.queue_free()
	_stars.hide()
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
