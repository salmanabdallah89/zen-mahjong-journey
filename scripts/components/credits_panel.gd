class_name CreditsPanel
extends Control
## Who made what, and the licence texts: opened from Settings.

@onready var _text: Label = %CreditsText
@onready var _scroll: ScrollContainer = %CreditsScroll
@onready var _back: Button = %CreditsBackButton


func _ready() -> void:
	_back.pressed.connect(hide)


func open() -> void:
	if _text.text.is_empty():
		_text.text = Credits.text()
	_scroll.scroll_vertical = 0
	show()
