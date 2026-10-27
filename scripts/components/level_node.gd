class_name LevelNode
extends Control
## One stop on the journey map: a marker disc with the level number, the
## stars earned so far, the level's name and its difficulty.

signal pressed(level_number: int)

const MARKER_OPEN := preload("res://assets/progression/node_available.png")
const MARKER_DONE := preload("res://assets/progression/node_complete.png")
const MARKER_LOCKED := preload("res://assets/progression/node_locked.png")
const STAR := preload("res://assets/ui/icons/icon_star.png")

var level_number := 0
var unlocked := false

var _pulse: Tween

@onready var _marker: TextureButton = %Marker
@onready var _number: Label = %Number
@onready var _stars: HBoxContainer = %Stars
@onready var _title: Label = %Title
@onready var _difficulty: Label = %Difficulty


func _ready() -> void:
	_marker.pressed.connect(func() -> void: pressed.emit(level_number))


func setup(level: LevelCatalog.LevelDefinition, earned_stars: int, is_unlocked: bool, is_current: bool) -> void:
	level_number = level.number
	unlocked = is_unlocked
	_number.text = str(level.number)
	_title.text = level.title
	_difficulty.text = LevelRating.difficulty_label(level.difficulty).to_upper() if is_unlocked else "LOCKED"
	if not is_unlocked:
		_marker.texture_normal = MARKER_LOCKED
	elif earned_stars > 0:
		_marker.texture_normal = MARKER_DONE
	else:
		_marker.texture_normal = MARKER_OPEN
	_number.modulate.a = 1.0 if is_unlocked else 0.45
	_title.modulate.a = 1.0 if is_unlocked else 0.6
	for child in _stars.get_children():
		child.queue_free()
	for i in LevelRating.MAX_STARS:
		var star := TextureRect.new()
		star.texture = STAR
		star.custom_minimum_size = Vector2(84, 84)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.modulate = Color.WHITE if i < earned_stars else Color(0.25, 0.25, 0.25, 0.55)
		_stars.add_child(star)
	_stars.visible = is_unlocked
	if _pulse:
		_pulse.kill()
	_marker.scale = Vector2.ONE
	if is_current:
		# The level to play next gently breathes.
		_marker.pivot_offset = _marker.size / 2.0
		_pulse = create_tween().set_loops()
		_pulse.tween_property(_marker, "scale", Vector2(1.08, 1.08), 0.8).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(_marker, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)


## Centre of the marker disc, in this node's coordinates (the path runs through it).
func marker_center() -> Vector2:
	return _marker.position + _marker.size / 2.0


func play_locked_nudge() -> void:
	var tween := create_tween()
	for offset in [10.0, -10.0, 6.0, 0.0]:
		tween.tween_property(_marker, "position:x", _marker.position.x + offset, 0.05)


func play_unlock() -> void:
	_marker.pivot_offset = _marker.size / 2.0
	_marker.scale = Vector2(0.6, 0.6)
	create_tween().tween_property(_marker, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
