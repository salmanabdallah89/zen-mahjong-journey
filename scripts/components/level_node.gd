class_name LevelNode
extends Control
## One stop on the journey map: a marker disc with the level number, the
## stars earned so far, and a name plate (level name and difficulty) that
## stays readable over the scenery. States never rely on colour alone:
## locked levels say LOCKED, unplayed levels show only their difficulty, and
## cleared levels show their stars.

signal pressed(level_number: int)

const MARKER_OPEN := preload("res://assets/progression/node_available.png")
const MARKER_DONE := preload("res://assets/progression/node_complete.png")
const MARKER_LOCKED := preload("res://assets/progression/node_locked.png")
const STAR := preload("res://assets/ui/icons/icon_star.png")

var level_number := 0
var unlocked := false

var _pulse: Tween
var _nudge: Tween
## Marker x before any nudge, so repeated taps can't push it off its spot.
var _marker_home_x := NAN

@onready var _marker: TextureButton = %Marker
@onready var _number: Label = %Number
@onready var _stars: HBoxContainer = %Stars
@onready var _title: Label = %Title
@onready var _difficulty: Label = %Difficulty
@onready var _plate: Control = %Plate


func _ready() -> void:
	_marker.pressed.connect(func() -> void: pressed.emit(level_number))
	# The journey screen plays the right sound (click, or "locked").
	_marker.set_meta("custom_sound", true)


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
	_stars.visible = is_unlocked and earned_stars > 0
	if _pulse:
		_pulse.kill()
		_pulse = null
	_marker.scale = Vector2.ONE
	if is_current:
		_start_breathing()


## The level to play next gently breathes.
func _start_breathing() -> void:
	_marker.pivot_offset = _marker.size / 2.0
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_marker, "scale", Vector2(1.08, 1.08), 0.8).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_marker, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)


func set_labels_visible(value: bool) -> void:
	_plate.visible = value


func labels_shown() -> bool:
	return _plate.visible


## On-screen rectangles of the name plate and the marker disc (overlap checks).
func label_rect() -> Rect2:
	return _plate.get_global_rect()


func marker_rect() -> Rect2:
	return _marker.get_global_rect()


## Centre of the marker disc, in this node's coordinates (the path runs through it).
func marker_center() -> Vector2:
	return _marker.position + _marker.size / 2.0


func play_locked_nudge() -> void:
	if is_nan(_marker_home_x):
		_marker_home_x = _marker.position.x
	if _nudge:
		_nudge.kill()
	_nudge = create_tween()
	for offset in [10.0, -10.0, 6.0, 0.0]:
		_nudge.tween_property(_marker, "position:x", _marker_home_x + offset, 0.05)


## Pops the marker in; a breathing (current) marker resumes afterwards.
func play_unlock() -> void:
	var was_breathing := _pulse != null
	if _pulse:
		_pulse.kill()
		_pulse = null
	_marker.pivot_offset = _marker.size / 2.0
	_marker.scale = Vector2(0.6, 0.6)
	var tween := create_tween()
	tween.tween_property(_marker, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if was_breathing:
		tween.tween_callback(_start_breathing)
