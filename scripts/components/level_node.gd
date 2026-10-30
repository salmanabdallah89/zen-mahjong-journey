class_name LevelNode
extends Control
## One stop on the journey map: a porcelain mahjong tile with the level number,
## the stars earned so far, and a name plate (level name and difficulty) that
## stays readable over the scenery. Each level's tile carries a Zen Garden
## symbol: faint until the level is cleared, then in full colour, so the path
## fills with the garden the player has collected. Locked levels are jade tile
## backs. States never rely on colour alone: locked levels show a padlock,
## unplayed levels only their difficulty, and cleared levels their stars.

signal pressed(level_number: int)

const MARKER_OPEN := preload("res://assets/tiles/bodies/tile_body_zen_ivory.png")
const MARKER_LOCKED := preload("res://assets/tiles/backs/tile_back_jade_lotus.png")
const STAR := preload("res://assets/ui/icons/icon_star.png")
const SYMBOL_COLLECTION := "zen_garden"
## A symbol waiting to be earned (level not cleared yet).
const UNEARNED_SYMBOL_ALPHA := 0.3

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
@onready var _symbol: TextureRect = %Symbol


var _padlock: Control
## Soft shadow under the tile, and the gold halo of the level to play next.
var _shadow: TextureRect
var _halo: TextureRect

static var _shadow_texture: GradientTexture2D
static var _halo_texture: GradientTexture2D


## The Zen Garden symbol of level `number`, or null without that collection.
static func symbol_for(number: int) -> Texture2D:
	var collection := TileCollectionManager.get_collection(SYMBOL_COLLECTION)
	if collection == null or collection.symbol_paths.is_empty():
		return null
	return load(collection.symbol_paths[(number - 1) % collection.symbol_paths.size()])


func _ready() -> void:
	_shadow = _soft_glow("Shadow", _soft_texture(Color(0.03, 0.05, 0.05, 0.6)), Vector2(250, 262), Vector2(6, 14))
	_halo = _soft_glow("Halo", _soft_texture(Color(1.0, 0.82, 0.42, 0.85)), Vector2(380, 400), Vector2.ZERO)
	_halo.hide()
	_marker.pressed.connect(func() -> void: pressed.emit(level_number))
	# The journey screen plays the right sound (click, or "locked").
	_marker.set_meta("custom_sound", true)
	# Locked levels show a padlock, not only a grey disc (not colour alone).
	_padlock = _Padlock.new()
	_padlock.name = "Padlock"
	_marker.add_child(_padlock)
	_padlock.position = Vector2(_marker.size.x - 58.0, _marker.size.y - 66.0)
	_padlock.hide()


func setup(level: LevelCatalog.LevelDefinition, earned_stars: int, is_unlocked: bool, is_current: bool) -> void:
	level_number = level.number
	unlocked = is_unlocked
	_number.text = str(level.number)
	_title.text = level.title
	_difficulty.text = LevelRating.difficulty_label(level.difficulty).to_upper() if is_unlocked else "LOCKED"
	if not is_unlocked:
		_marker.texture_normal = MARKER_LOCKED
	else:
		_marker.texture_normal = MARKER_OPEN
	_symbol.visible = is_unlocked
	if is_unlocked:
		_symbol.texture = symbol_for(level.number)
		_symbol.modulate.a = 1.0 if earned_stars > 0 else UNEARNED_SYMBOL_ALPHA
	# Locked numbers stay readable; the padlock marks the lock.
	_number.modulate.a = 1.0 if is_unlocked else 0.8
	# Locked names stay readable (contrast above 4.5:1 on the plate).
	_title.modulate.a = 1.0 if is_unlocked else 0.8
	for child in _stars.get_children():
		child.queue_free()
	for i in LevelRating.MAX_STARS:
		var star := TextureRect.new()
		star.texture = STAR
		star.custom_minimum_size = Vector2(62, 62)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.modulate = Color.WHITE if i < earned_stars else Color(0.25, 0.25, 0.25, 0.55)
		_stars.add_child(star)
	_stars.visible = is_unlocked and earned_stars > 0
	_padlock.visible = not is_unlocked
	_plate.visible = is_unlocked
	if _pulse:
		_pulse.kill()
		_pulse = null
	_marker.scale = Vector2.ONE
	_halo.visible = is_current
	_halo.modulate.a = 1.0
	if is_current:
		_start_breathing()


## The level to play next gently breathes in its halo (reduced animations:
## the halo stays still).
func _start_breathing() -> void:
	if Motion.reduced:
		return
	_marker.pivot_offset = _marker.size / 2.0
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_marker, "scale", Vector2(1.06, 1.06), 0.8).set_trans(Tween.TRANS_SINE)
	_pulse.parallel().tween_property(_halo, "modulate:a", 0.55, 0.8).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_marker, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)
	_pulse.parallel().tween_property(_halo, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)


## Name plates show for levels the player can open; locked stops show the
## padlock instead.
func set_labels_visible(value: bool) -> void:
	_plate.visible = value and unlocked


func is_padlocked() -> bool:
	return _padlock.visible


## Puts the name plate beside the marker, toward the middle of the map:
## `side` -1 = left, 1 = right, 0 = under the marker (default layout).
func place_plate(side: int) -> void:
	if side == 0:
		return
	_plate.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_plate.reset_size()
	var marker := Rect2(_marker.position, _marker.size)
	var y := marker.get_center().y - _plate.size.y / 2.0
	var x := marker.end.x + 10.0 if side > 0 else marker.position.x - 10.0 - _plate.size.x
	_plate.position = Vector2(x, y)


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


## A soft round glow behind the marker, centred on it plus `offset`.
func _soft_glow(node_name: String, texture: Texture2D, side: Vector2, offset: Vector2) -> TextureRect:
	var glow := TextureRect.new()
	glow.name = node_name
	glow.texture = texture
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.size = side
	glow.position = _marker.position + _marker.size / 2.0 - side / 2.0 + offset
	add_child(glow)
	move_child(glow, 0)
	return glow


static func _soft_texture(color: Color) -> GradientTexture2D:
	var cached := _shadow_texture if color.r < 0.5 else _halo_texture
	if cached != null:
		return cached
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([color, Color(color, color.a * 0.7), Color(color, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 96
	texture.height = 96
	if color.r < 0.5:
		_shadow_texture = texture
	else:
		_halo_texture = texture
	return texture


## A small padlock drawn on locked markers: gold shackle, ivory body, keyhole.
class _Padlock extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(52, 60)

	func _draw() -> void:
		var gold := Color(0.78, 0.65, 0.42)
		draw_circle(Vector2(26, 34), 30.0, Color(0.15, 0.23, 0.31, 0.92))
		draw_arc(Vector2(26, 26), 11.0, PI, TAU, 16, gold, 5.0, true)
		draw_line(Vector2(15, 26), Vector2(15, 32), gold, 5.0)
		draw_line(Vector2(37, 26), Vector2(37, 32), gold, 5.0)
		draw_rect(Rect2(10, 31, 32, 22), Color(0.96, 0.93, 0.87))
		draw_circle(Vector2(26, 40), 3.5, Color(0.21, 0.31, 0.27))
		draw_line(Vector2(26, 41), Vector2(26, 47), Color(0.21, 0.31, 0.27), 2.5)
