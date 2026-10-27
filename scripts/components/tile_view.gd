class_name TileView
extends Control
## One tile on the board: its face art, a dimmed tint while blocked, and an
## outline while selected or hinted. Only the top face of the art responds to
## presses, so a tile's drawn edge never steals taps from its neighbours.

signal pressed(tile: TileView)

enum Highlight { NONE, SELECTED, HINT }

const TILE_SIZE := Vector2(192, 240)
## Top face of the tile art; the rest of the image is the drawn tile edge.
const FACE_RECT := Rect2(8, 8, 162, 204)
const FREE_TINT := Color(1, 1, 1)
const BLOCKED_TINT := Color(0.56, 0.55, 0.53)
const SELECTED_TINT := Color(1.0, 0.97, 0.86)
## Deeper than the palette's sakura so the outline reads against cream tiles.
const SAKURA := Color(0.86, 0.45, 0.53)
const FOREST := Color(0.20784314, 0.30980393, 0.26666668)

var index: int = -1

var _free := true
var _highlight := Highlight.NONE
var _pulse: Tween

@onready var _face: TextureRect = %Face
@onready var _outline: Panel = %Outline


func _ready() -> void:
	pivot_offset = FACE_RECT.get_center()
	_apply_look()


func set_face(texture: Texture2D) -> void:
	_face.texture = texture


func set_free(value: bool) -> void:
	if _free != value:
		_free = value
		_apply_look()


func set_highlight(value: Highlight) -> void:
	if _highlight != value:
		_highlight = value
		_apply_look()


## Resets any animation state so the tile shows plainly.
func reset_visual() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 1.0
	scale = Vector2.ONE
	_face.position = Vector2.ZERO


func play_removal() -> void:
	# Stop taking taps at once so the fading tile never hides the one beneath.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_highlight(Highlight.NONE)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(hide)


func play_restore() -> void:
	reset_visual()
	modulate.a = 0.0
	scale = Vector2(1.12, 1.12)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)


## Small sideways shake telling the player a blocked tile cannot be picked.
func play_blocked_nudge() -> void:
	var tween := create_tween()
	for offset in [10.0, -10.0, 6.0, 0.0]:
		tween.tween_property(_face, "position:x", offset, 0.05)


func _has_point(point: Vector2) -> bool:
	return FACE_RECT.has_point(point)


func _gui_input(event: InputEvent) -> void:
	# Touch arrives as emulated mouse input, so one handler serves both.
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit(self)


func _apply_look() -> void:
	if not is_node_ready():
		return
	if _pulse:
		_pulse.kill()
		_pulse = null
	_outline.modulate.a = 1.0
	match _highlight:
		Highlight.SELECTED:
			_face.modulate = SELECTED_TINT
			_outline.add_theme_stylebox_override("panel", _outline_style(SAKURA))
			_outline.visible = true
		Highlight.HINT:
			_face.modulate = FREE_TINT
			_outline.add_theme_stylebox_override("panel", _outline_style(FOREST))
			_outline.visible = true
			_pulse = create_tween().set_loops()
			_pulse.tween_property(_outline, "modulate:a", 0.55, 0.45).set_trans(Tween.TRANS_SINE)
			_pulse.tween_property(_outline, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
		_:
			_face.modulate = FREE_TINT if _free else BLOCKED_TINT
			_outline.visible = false


static var _styles := {}


static func _outline_style(color: Color) -> StyleBoxFlat:
	if not _styles.has(color):
		var style := StyleBoxFlat.new()
		style.draw_center = false
		style.border_color = color
		style.set_border_width_all(12)
		style.set_corner_radius_all(20)
		style.set_expand_margin_all(4)
		_styles[color] = style
	return _styles[color]
