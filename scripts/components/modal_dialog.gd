class_name ModalDialog
extends Control
## Full-screen modal: dims and blocks the screen behind it and shows a panel
## with a title, a message and a column of action buttons.

const BUTTON_SIZE := Vector2(560, 136)

@onready var _panel: PanelContainer = %Panel
@onready var _title: Label = %Title
@onready var _message: Label = %Message
@onready var _buttons: VBoxContainer = %Buttons


func open(title: String, message: String) -> void:
	_title.text = title
	_message.text = message
	_message.visible = not message.is_empty()
	for child in _buttons.get_children():
		child.queue_free()
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)


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
