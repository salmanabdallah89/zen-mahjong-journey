class_name TileView
extends Control
## One tile on the board, built from the active TileArtSet: a soft drop shadow,
## the face image, an ivory veil that washes out blocked tiles, and a glow for
## selection or hints. Only the art's top face responds to presses, so a
## tile's drawn edge never steals taps from its neighbours.

signal pressed(tile: TileView)

enum Highlight { NONE, SELECTED, HINT }

const IVORY := Color(0.9647059, 0.93333334, 0.8745098)
const GOLD := Color(0.93, 0.76, 0.42)
const SAKURA := Color(0.92, 0.42, 0.56)
## Strength of the ivory wash over blocked tiles' faces.
const BLOCKED_VEIL_ALPHA := 0.5
## Brightness of a blocked tile's whole body, edge included.
const BLOCKED_BODY := Color(0.9, 0.88, 0.85)
const SELECTED_LIFT := 10.0
const STATE_FADE := 0.22

var index: int = -1

var _art: TileArtSet
var _free := true
var _highlight := Highlight.NONE
var _layer_tint := Color.WHITE
var _base_shadow_offset := Vector2.ZERO
var _pulse: Tween
var _state_tween: Tween
var _lift_tween: Tween

@onready var _shadow: Panel = %Shadow
@onready var _lift: Control = %Lift
@onready var _face: TextureRect = %Face
@onready var _veil: Panel = %Veil
@onready var _glow: Panel = %Glow


func _ready() -> void:
	_art = TileArtSet.active()
	size = _art.image_size
	custom_minimum_size = _art.image_size
	pivot_offset = _art.face_rect.get_center()
	_lift.size = _art.image_size
	_face.size = _art.image_size
	_place(_veil, _art.face_rect)
	_place(_glow, _art.face_rect)
	_place(_shadow, _art.body_rect)
	_veil.add_theme_stylebox_override("panel", _veil_style())
	_apply_look(false)


## Shadow depth and a slight darkening grow toward the bottom layer, so stacks
## read as physically raised.
func set_layer(z: int, top_layer: int) -> void:
	var depth := top_layer - z
	_layer_tint = Color.WHITE.darkened(0.035 * depth)
	_base_shadow_offset = Vector2(5, 8) + Vector2(2, 3) * z
	_shadow.add_theme_stylebox_override("panel", _shadow_style(z))
	_shadow.position = _art.body_rect.position + _base_shadow_offset
	_apply_look(false)


func set_face(texture: Texture2D) -> void:
	_face.texture = texture


func set_free(value: bool, animate := true) -> void:
	if _free != value:
		_free = value
		_apply_look(animate)


func set_highlight(value: Highlight) -> void:
	if _highlight != value:
		_highlight = value
		_apply_look(true)


## Clears any animation state so the tile shows plainly.
func reset_visual() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color.WHITE
	scale = Vector2.ONE
	_face.position = Vector2.ZERO


## Match: a gentle golden swell, then the tile settles away.
func play_removal() -> void:
	# Stop taking taps at once so the fading tile never hides the one beneath.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight = Highlight.SELECTED
	_apply_look(false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate", Color(1.15, 1.1, 1.0), 0.12)
	tween.tween_property(self, "scale", Vector2(0.86, 0.86), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate", Color(1.15, 1.1, 1.0, 0.0), 0.22)
	tween.tween_callback(_finish_removal)


func play_restore() -> void:
	reset_visual()
	_highlight = Highlight.NONE
	_apply_look(false)
	modulate.a = 0.0
	scale = Vector2(0.9, 0.9)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)


## Small sideways shake telling the player a blocked tile cannot be picked.
func play_blocked_nudge() -> void:
	var tween := create_tween()
	for offset in [8.0, -8.0, 5.0, 0.0]:
		tween.tween_property(_face, "position:x", offset, 0.05)


## Centre of the tap area in this tile's local coordinates.
func face_center() -> Vector2:
	return _art.face_rect.get_center()


func _has_point(point: Vector2) -> bool:
	return _art != null and _art.face_rect.has_point(point)


func _gui_input(event: InputEvent) -> void:
	# Touch arrives as emulated mouse input, so one handler serves both.
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit(self)


func _finish_removal() -> void:
	hide()
	_highlight = Highlight.NONE
	_apply_look(false)


func _apply_look(animate: bool) -> void:
	if not is_node_ready():
		return
	if _pulse:
		_pulse.kill()
		_pulse = null
	var lifted := _highlight == Highlight.SELECTED
	var blocked := not _free and _highlight == Highlight.NONE
	var veil_alpha := BLOCKED_VEIL_ALPHA if blocked else 0.0
	var face_tint := _layer_tint * (BLOCKED_BODY if blocked else Color.WHITE)
	face_tint.a = 1.0
	var lift_y := -SELECTED_LIFT if lifted else 0.0
	var shadow_offset := _base_shadow_offset + (Vector2(4, 8) if lifted else Vector2.ZERO)

	if _state_tween:
		_state_tween.kill()
	if animate:
		_state_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
		_state_tween.tween_property(_veil, "modulate:a", veil_alpha, STATE_FADE)
		_state_tween.tween_property(_face, "modulate", face_tint, STATE_FADE)
		_state_tween.tween_property(_lift, "position:y", lift_y, 0.14)
		_state_tween.tween_property(_shadow, "position", _art.body_rect.position + shadow_offset, 0.14)
	else:
		_veil.modulate.a = veil_alpha
		_face.modulate = face_tint
		_lift.position.y = lift_y
		_shadow.position = _art.body_rect.position + shadow_offset

	match _highlight:
		Highlight.SELECTED:
			_glow.add_theme_stylebox_override("panel", _glow_style(GOLD))
			_glow.visible = true
			_glow.modulate.a = 1.0
		Highlight.HINT:
			_glow.add_theme_stylebox_override("panel", _glow_style(SAKURA))
			_glow.visible = true
			_glow.modulate.a = 1.0
			_pulse = create_tween().set_loops()
			_pulse.tween_property(_glow, "modulate:a", 0.6, 0.55).set_trans(Tween.TRANS_SINE)
			_pulse.tween_property(_glow, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
		_:
			_glow.visible = false


static func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size


static var _styles := {}


static func _glow_style(color: Color) -> StyleBoxFlat:
	var key := "glow_%s" % color.to_html()
	if not _styles.has(key):
		var style := StyleBoxFlat.new()
		style.draw_center = false
		style.border_color = color
		style.set_border_width_all(8)
		style.set_corner_radius_all(18)
		style.set_expand_margin_all(3)
		style.shadow_color = Color(color, 0.75)
		style.shadow_size = 30
		style.anti_aliasing = true
		_styles[key] = style
	return _styles[key]


static func _veil_style() -> StyleBoxFlat:
	if not _styles.has("veil"):
		var style := StyleBoxFlat.new()
		style.bg_color = IVORY
		style.set_corner_radius_all(14)
		_styles["veil"] = style
	return _styles["veil"]


## A transparent box whose soft shadow is the tile's drop shadow.
static func _shadow_style(z: int) -> StyleBoxFlat:
	var key := "shadow_%d" % z
	if not _styles.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.1, 0.09, 0.4)
		style.set_corner_radius_all(18)
		style.shadow_color = Color(0.05, 0.07, 0.06, 0.42)
		style.shadow_size = 10 + z * 3
		style.anti_aliasing = true
		_styles[key] = style
	return _styles[key]
