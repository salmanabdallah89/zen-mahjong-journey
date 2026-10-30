class_name TileView
extends Control
## One tile on the board, built from the active TileArtSet: a soft drop shadow,
## the face image, an ivory veil that washes out blocked tiles, and a glow for
## selection or hints. Only the art's top face responds to presses, so a
## tile's drawn edge never steals taps from its neighbours.
##
## Motion: every animation runs on one of a few tweens that reset_visual()
## kills, and the tile always returns to `home_position`, so an interrupted
## animation (Undo, Shuffle, Restart mid-flight) can never leave a tile stuck,
## hidden or out of place. With Motion.reduced, travel, bounce and pulses
## become short fades.
##
## Special tiles (TileSpecials): a mystery tile shows a tile back over its face
## until play_flip() turns it over; a golden lotus tile has a warm gold rim
## that shimmers slowly and a "x2" badge.

signal pressed(tile: TileView)

enum Highlight { NONE, SELECTED, HINT }

const IVORY := Color(0.9647059, 0.93333334, 0.8745098)
const GOLD := Color(0.93, 0.76, 0.42)
const SAKURA := Color(0.92, 0.42, 0.56)
## Soft rose outline for a mismatched pair (gentler than a red warning).
const ROSE := Color(0.86, 0.45, 0.45)
## Outline for tiles that block the one the player just tapped.
const BLOCKER := Color(0.2, 0.36, 0.3)
## Blocked tiles are dimmed and slightly cooled, not washed out, so their
## symbols stay readable for planning ahead while free tiles clearly stand out.
## Strength of the soft ivory film over blocked faces (takes the edge off saturation).
const BLOCKED_VEIL_ALPHA := 0.14
## Brightness of a blocked tile's whole body, edge included.
const BLOCKED_BODY := Color(0.85, 0.845, 0.84)
## Darkening per layer below the top one, so stacks read as raised.
const LAYER_DARKEN := 0.05
const SELECTED_LIFT := 12.0
const SELECTED_SCALE := 1.05
const HINT_SCALE := 1.035
const STATE_FADE := 0.22
## Draw order while a matched tile travels, above resting tiles and glows.
const FLIGHT_Z := 10
## Match: a quick dip-and-swell before the glide (seconds), the extra height
## of the glide's arc, and the soft squash when the pair touches.
const MATCH_ANTICIPATION := 0.09
const MATCH_ARC := 18.0
const CONTACT_SQUASH := Vector2(1.12, 0.92)
## Golden lotus rim and its slow shimmer (seconds per half breath).
const GOLDEN := Color(1.0, 0.8, 0.36)
const GOLDEN_SHIMMER := 1.6
## Face width the rim and badge are sized for; larger tile art scales them up.
const GOLDEN_BASE_WIDTH := 232.0
## Flip of a mystery tile: seconds for each half (edge-on at the middle).
const FLIP_HALF := 0.13

var index: int = -1
## Tile geometry to build from; set before the tile enters the tree.
## Defaults to the active TileArtSet.
var style: TileArtSet
## Resting position on the board; every animation returns here.
var home_position := Vector2.ZERO

var _art: TileArtSet
var _free := true
var _highlight := Highlight.NONE
var _layer_tint := Color.WHITE
var _base_shadow_offset := Vector2.ZERO
var _pulse: Tween
var _state_tween: Tween
## Travel, match, restore and shuffle moves of the whole tile.
var _motion_tween: Tween
## Shakes and the "just uncovered" pop of the art inside the tile.
var _accent_tween: Tween
var _golden_tween: Tween
## Tile back over the face of a mystery tile, the golden rim and its badge.
var _cover: TextureRect
var _gilding: Panel
var _badge: Label

@onready var _shadow: Panel = %Shadow
@onready var _lift: Control = %Lift
@onready var _face: TextureRect = %Face
@onready var _symbol: TextureRect = %Symbol
@onready var _veil: Panel = %Veil
@onready var _glow: Panel = %Glow


func _ready() -> void:
	_art = style if style else TileArtSet.active()
	size = _art.image_size
	custom_minimum_size = _art.image_size
	pivot_offset = _art.face_rect.get_center()
	_lift.size = _art.image_size
	_lift.pivot_offset = _art.face_rect.get_center()
	_face.size = _art.image_size
	_place(_veil, _art.face_rect)
	_place(_glow, _art.face_rect)
	_place(_shadow, _art.body_rect)
	_veil.add_theme_stylebox_override("panel", _veil_style())
	_build_specials()
	_apply_look(false)


## Places the tile at its resting spot on the board.
func place_at(point: Vector2) -> void:
	home_position = point
	position = point


## Shadow depth and a slight darkening grow toward the bottom layer, so stacks
## read as physically raised.
func set_layer(z: int, top_layer: int) -> void:
	var depth := top_layer - z
	_layer_tint = Color.WHITE.darkened(LAYER_DARKEN * depth)
	_base_shadow_offset = Vector2(6, 10) + Vector2(3, 4) * z
	_shadow.add_theme_stylebox_override("panel", _shadow_style(z))
	_shadow.position = _art.body_rect.position + _base_shadow_offset
	_apply_look(false)


## `tile` is the full tile image (or blank body); `symbol` is drawn on its top
## face for symbol collections and is null for full-tile collections.
func set_art(tile: Texture2D, symbol: Texture2D = null, padding := 0.0) -> void:
	_face.texture = tile
	_symbol.texture = symbol
	_symbol.visible = symbol != null
	if symbol:
		var inset := _art.face_rect.size * padding
		_place(_symbol, Rect2(_art.face_rect.position + inset, _art.face_rect.size - inset * 2.0))


## `back` shows face-down (a tile back over the face); null shows the face.
## `whole_tile`: `back` is a full tile image in the same frame as the body.
func set_mystery(back: Texture2D, whole_tile := false) -> void:
	_cover.texture = back
	_cover.visible = back != null
	_place(_cover, Rect2(Vector2.ZERO, _art.image_size) if whole_tile else _art.face_rect)
	_cover.modulate.a = 1.0


func is_face_down() -> bool:
	return _cover.visible


## A mystery tile turns over: it narrows to its edge, the face replaces the
## back, and it widens again with a warm flash. Reduced animations: the back
## fades away. Runs on the accent tween, so reset_visual() can stop it.
func play_flip(delay := 0.0) -> void:
	if not _cover.visible:
		return
	_restart_accent()
	_accent_tween.tween_interval(delay)
	if Motion.reduced:
		_accent_tween.tween_property(_cover, "modulate:a", 0.0, 0.12)
		_accent_tween.tween_callback(set_mystery.bind(null))
		return
	_accent_tween.tween_property(_lift, "scale:x", 0.0, FLIP_HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_accent_tween.tween_callback(set_mystery.bind(null))
	_accent_tween.tween_property(_lift, "scale:x", 1.0, FLIP_HALF).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_accent_tween.parallel().tween_property(self, "modulate", Color(1.25, 1.2, 1.05), FLIP_HALF)
	_accent_tween.tween_property(self, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_SINE)


func set_golden(value: bool) -> void:
	if value == _gilding.visible:
		return
	_gilding.visible = value
	_badge.visible = value
	if _golden_tween:
		_golden_tween.kill()
		_golden_tween = null
	_gilding.modulate.a = 1.0
	if value and not Motion.reduced:
		_golden_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_golden_tween.tween_property(_gilding, "modulate:a", 0.7, GOLDEN_SHIMMER)
		_golden_tween.tween_property(_gilding, "modulate:a", 1.0, GOLDEN_SHIMMER)


func is_golden() -> bool:
	return _gilding.visible


func has_art() -> bool:
	return _face.texture != null and (not _symbol.visible or _symbol.texture != null)


## `reveal_delay` >= 0 plays the "just uncovered" pop after that many seconds
## when the tile becomes free.
func set_free(value: bool, animate := true, reveal_delay := -1.0) -> void:
	if _free != value:
		_free = value
		_apply_look(animate)
		if value and animate and reveal_delay >= 0.0:
			play_reveal(reveal_delay)


func is_free_look() -> bool:
	return _free


func set_highlight(value: Highlight) -> void:
	if _highlight != value:
		_highlight = value
		_apply_look(true)


func highlight() -> Highlight:
	return _highlight


## Stops every animation and shows the tile plainly at its resting spot.
func reset_visual() -> void:
	_stop_motion()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color.WHITE
	scale = Vector2.ONE
	rotation = 0.0
	position = home_position
	z_index = 0
	_face.position = Vector2.ZERO
	_lift.position.x = 0.0


## True while a match animation is playing (the tile is leaving the board).
func is_removing() -> bool:
	return _motion_tween != null and _motion_tween.is_running() and mouse_filter == Control.MOUSE_FILTER_IGNORE


## True while any whole-tile move (match, restore, shuffle) is playing.
func is_moving() -> bool:
	return _motion_tween != null and _motion_tween.is_running()


## Match: a quick dip-and-swell, a short glide along a gentle arc to `meet`
## (where it touches its partner), a soft squash on contact with a bright
## flash, then both bloom and fade together. `travel` is the glide time; the
## pair touches MATCH_ANTICIPATION + travel seconds after this call.
func play_match(meet: Vector2, travel: float) -> void:
	_stop_motion()
	# Stop taking taps at once so the leaving tile never hides the one beneath.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight = Highlight.SELECTED
	_apply_look(false)
	# No gold outline while gliding: several quick matches would otherwise
	# stack glows; the contact flash marks the moment instead.
	_glow.visible = false
	z_index = FLIGHT_Z
	_motion_tween = create_tween()
	if Motion.reduced:
		_motion_tween.tween_property(self, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE)
	else:
		var half := MATCH_ANTICIPATION / 2.0
		_motion_tween.tween_property(self, "scale", Vector2(0.95, 0.95), half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_motion_tween.tween_property(self, "scale", Vector2(1.07, 1.07), half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if travel > 0.0:
			_motion_tween.tween_property(self, "position", meet, travel).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			# The art rises and settles during the glide: a gentle arc.
			var rest_y := _lift.position.y
			_accent_tween = create_tween()
			_accent_tween.tween_interval(MATCH_ANTICIPATION)
			_accent_tween.tween_property(_lift, "position:y", rest_y - MATCH_ARC, travel / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_accent_tween.tween_property(_lift, "position:y", rest_y, travel / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		# Contact: a soft squash and a warm flash, then bloom away.
		_motion_tween.tween_property(self, "scale", CONTACT_SQUASH, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_motion_tween.parallel().tween_property(self, "modulate", Color(1.35, 1.28, 1.12), 0.05)
		_motion_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.17).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_motion_tween.parallel().tween_property(self, "modulate", Color(1.35, 1.28, 1.12, 0.0), 0.17).set_trans(Tween.TRANS_SINE)
	_motion_tween.tween_callback(_finish_removal)


## Undo: the reverse of play_match. The tile appears where the pair met and
## glides back to its spot.
func play_restore(from: Vector2, travel: float) -> void:
	reset_visual()
	_highlight = Highlight.NONE
	_apply_look(false)
	_motion_tween = create_tween()
	if Motion.reduced:
		modulate.a = 0.0
		_motion_tween.tween_property(self, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
		return
	z_index = FLIGHT_Z
	position = from
	scale = Vector2(1.14, 1.14)
	modulate = Color(1.2, 1.12, 1.0, 0.0)
	_motion_tween.tween_property(self, "modulate", Color.WHITE, 0.14).set_trans(Tween.TRANS_SINE)
	_motion_tween.parallel().tween_property(self, "scale", Vector2(1.04, 1.04), 0.14).set_trans(Tween.TRANS_SINE)
	_motion_tween.tween_property(self, "position", home_position, travel).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_motion_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_callback(func() -> void: z_index = 0)


## Shuffle, first half: glide toward `gather` and shrink a little. The board
## swaps the art while tiles are gathered, then calls shuffle_return().
func shuffle_gather(gather: Vector2, delay: float, seconds: float) -> void:
	reset_visual()
	_motion_tween = create_tween()
	if Motion.reduced:
		_motion_tween.tween_property(self, "modulate:a", 0.0, seconds).set_trans(Tween.TRANS_SINE)
		return
	_motion_tween.tween_interval(delay)
	_motion_tween.tween_property(self, "position", gather, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_motion_tween.parallel().tween_property(self, "scale", Vector2(0.86, 0.86), seconds).set_trans(Tween.TRANS_SINE)
	_motion_tween.parallel().tween_property(self, "rotation", deg_to_rad(6.0 if index % 2 == 0 else -6.0), seconds)


## Shuffle, second half: spread back out to the resting spot.
func shuffle_return(delay: float, seconds: float) -> void:
	if _motion_tween:
		_motion_tween.kill()
	_motion_tween = create_tween()
	if Motion.reduced:
		_motion_tween.tween_property(self, "modulate:a", 1.0, seconds).set_trans(Tween.TRANS_SINE)
		return
	_motion_tween.tween_interval(delay)
	_motion_tween.tween_property(self, "position", home_position, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.parallel().tween_property(self, "rotation", 0.0, seconds).set_trans(Tween.TRANS_SINE)


## A blocked tile can't be picked: a small sideways nudge.
func play_blocked_nudge() -> void:
	if Motion.reduced:
		return
	_shake([6.0, -5.0, 3.0, 0.0], 0.05)


## A mismatched pair: a soft, damped shake and a brief rose outline. No harsh
## flash or colour change of the tile itself.
func play_mistake() -> void:
	if not Motion.reduced:
		_shake([7.0, -6.0, 4.0, -2.0, 0.0], 0.065)
	_flash_outline(ROSE, 0.25, 0.4)


## A tile that just became free brightens and swells slightly, then settles.
func play_reveal(delay := 0.0) -> void:
	if Motion.reduced:
		return
	_restart_accent()
	_accent_tween.tween_interval(delay)
	_accent_tween.tween_property(_lift, "scale", Vector2(1.045, 1.045), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_accent_tween.parallel().tween_property(self, "modulate", Color(1.1, 1.08, 1.02), 0.14)
	_accent_tween.tween_property(_lift, "scale", _rest_scale(), 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_accent_tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.26)


## Briefly outlines this tile as the reason another tile is blocked. The
## outline draws above every tile, so a blocker hidden under a raised tile
## still shows.
func play_blocker_flash() -> void:
	if _highlight != Highlight.NONE:
		return
	_flash_outline(BLOCKER, 0.5, 0.5)


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


func _build_specials() -> void:
	_cover = TextureRect.new()
	_cover.name = "Cover"
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cover.stretch_mode = TextureRect.STRETCH_SCALE
	_cover.visible = false
	_lift.add_child(_cover)
	_lift.move_child(_cover, _veil.get_index())
	_place(_cover, _art.face_rect)
	_gilding = Panel.new()
	_gilding.name = "Gilding"
	_gilding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var golden_scale := maxf(_art.face_rect.size.x / GOLDEN_BASE_WIDTH, 1.0)
	_gilding.add_theme_stylebox_override("panel", _gilding_style(golden_scale))
	_gilding.visible = false
	_lift.add_child(_gilding)
	_lift.move_child(_gilding, _glow.get_index())
	_place(_gilding, _art.face_rect)
	_badge = Label.new()
	_badge.name = "GoldenBadge"
	_badge.text = "×%d" % TileSpecials.GOLDEN_FACTOR
	_badge.theme_type_variation = &"GoldenBadgeLabel"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.visible = false
	_lift.add_child(_badge)
	_lift.move_child(_badge, _glow.get_index())
	_badge.size = _badge.get_combined_minimum_size()
	_badge.scale = Vector2(golden_scale, golden_scale)
	var badge_size := _badge.size * golden_scale
	# Top-right corner of the face, inside the rim: neighbours drawn later
	# never cover it.
	var corner := Vector2(_art.face_rect.end.x, _art.face_rect.position.y)
	_badge.position = corner + Vector2(-badge_size.x - _art.face_rect.size.x * 0.02, -badge_size.y * 0.12)


func _finish_removal() -> void:
	hide()
	z_index = 0
	_highlight = Highlight.NONE
	_apply_look(false)


func _stop_motion() -> void:
	for tween: Tween in [_motion_tween, _accent_tween]:
		if tween:
			tween.kill()
	_motion_tween = null
	_accent_tween = null
	if is_node_ready():
		_lift.scale = _rest_scale()


## Kills the running accent (shake or reveal), puts the art back to rest and
## starts a fresh accent tween.
func _restart_accent() -> void:
	if _accent_tween:
		_accent_tween.kill()
	_lift.position.x = 0.0
	_lift.scale = _rest_scale()
	if mouse_filter != Control.MOUSE_FILTER_IGNORE:
		modulate = Color.WHITE
	_accent_tween = create_tween()


func _shake(offsets: Array, step: float) -> void:
	_restart_accent()
	for offset: float in offsets:
		_accent_tween.tween_property(_lift, "position:x", offset, step).set_trans(Tween.TRANS_SINE)


func _flash_outline(color: Color, hold: float, fade: float) -> void:
	if _highlight != Highlight.NONE:
		return
	if _pulse:
		_pulse.kill()
	_glow.add_theme_stylebox_override("panel", _glow_style(color))
	_glow.visible = true
	_glow.modulate.a = 1.0
	_pulse = create_tween()
	_pulse.tween_interval(hold)
	_pulse.tween_property(_glow, "modulate:a", 0.0, fade).set_trans(Tween.TRANS_SINE)
	_pulse.tween_callback(_apply_look.bind(false))


func _rest_scale() -> Vector2:
	return Vector2(SELECTED_SCALE, SELECTED_SCALE) if _highlight == Highlight.SELECTED and not Motion.reduced else Vector2.ONE


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
	var shadow_offset := _base_shadow_offset + (Vector2(4, 9) if lifted else Vector2.ZERO)
	var lift_scale := _rest_scale()

	if _state_tween:
		_state_tween.kill()
	if animate:
		_state_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
		_state_tween.tween_property(_veil, "modulate:a", veil_alpha, STATE_FADE)
		_state_tween.tween_property(_face, "modulate", face_tint, STATE_FADE)
		var lift_time := Motion.duration(0.16)
		# Picking a tile pops it up with a little overshoot; letting go settles.
		var pop := _state_tween.tween_property(_lift, "scale", lift_scale, lift_time)
		var rise := _state_tween.tween_property(_lift, "position:y", lift_y, lift_time)
		if lifted:
			pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			rise.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_state_tween.tween_property(_shadow, "position", _art.body_rect.position + shadow_offset, lift_time)
	else:
		_veil.modulate.a = veil_alpha
		_face.modulate = face_tint
		_lift.position.y = lift_y
		_lift.scale = lift_scale
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
			if not Motion.reduced:
				# Soft breathing: the glow and the tile swell together.
				_pulse = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
				_pulse.tween_property(_glow, "modulate:a", 0.55, 0.7)
				_pulse.parallel().tween_property(_lift, "scale", Vector2(HINT_SCALE, HINT_SCALE), 0.7)
				_pulse.tween_property(_glow, "modulate:a", 1.0, 0.7)
				_pulse.parallel().tween_property(_lift, "scale", Vector2.ONE, 0.7)
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


static func _gilding_style(size_scale: float) -> StyleBoxFlat:
	var key := "gilding_%.2f" % size_scale
	if not _styles.has(key):
		var style := StyleBoxFlat.new()
		style.draw_center = false
		style.border_color = GOLDEN
		style.set_border_width_all(roundi(11.0 * size_scale))
		style.set_corner_radius_all(roundi(16.0 * size_scale))
		style.shadow_color = Color(GOLDEN, 0.75)
		style.shadow_size = roundi(26.0 * size_scale)
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
		style.bg_color = Color(0.06, 0.08, 0.07, 0.45)
		style.set_corner_radius_all(18)
		style.shadow_color = Color(0.04, 0.06, 0.05, 0.5)
		style.shadow_size = 12 + z * 4
		style.anti_aliasing = true
		_styles[key] = style
	return _styles[key]
