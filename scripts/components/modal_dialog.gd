class_name ModalDialog
extends Control
## Full-screen modal: dims and blocks the screen behind it and shows a panel
## with a title, an optional row of stars, a message and a column of action
## buttons.

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
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)


## Shows `earned` of `total` stars under the title. With `animate`, earned
## stars pop in one after another.
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
		_stars.add_child(star)
		if animate and i < earned:
			star.scale = Vector2.ZERO
			var tween := create_tween()
			tween.tween_interval(0.35 + 0.28 * i)
			tween.tween_property(star, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stars.show()


func stars_shown() -> int:
	var count := 0
	for child in _stars.get_children():
		if not child.is_queued_for_deletion() and (child as Control).modulate == Color.WHITE:
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
