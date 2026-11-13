class_name MatchEmblem
extends Control
## The picture of a matched pair, released (docs/TILE_TRAY.md): it lifts out
## of the pair in the tray, swells into a glowing emblem with turning rays of
## light, a halo and orbiting sparkles, holds for a breath, then shoots into
## the score and bursts into a little shower of light. Bigger combos give
## longer rays, more sparkles and a larger emblem; a golden lotus pair glows
## gold. Only one plays at a time: a newer match sends the older one straight
## to the score.
##
## Reduced animations: the picture fades in beside the tray and out again; no
## travel, rays, sparkles or scaling.

const GOLD := Color(1.0, 0.82, 0.42)
const IVORY := Color(0.98, 0.95, 0.88)
const SAKURA := Color(0.95, 0.66, 0.75)
## Seconds: rise and swell, hold, fly to the score.
const RISE := 0.38
const HOLD := 0.34
const FLY := 0.36
## Emblem size (canvas px) at combo 1, and the extra per combo step.
const BASE_SIZE := 300.0
const SIZE_PER_COMBO := 22.0
const MAX_COMBO := 6

## Picture of the pair (a tile face or its symbol).
var picture: Texture2D
## Matches in a row (1 = a single match).
var combo := 1
var golden := false

var _grow := 0.0
var _glow := 0.0
var _spin := 0.0
var _time := 0.0
var _tween: Tween
var _target := Vector2.ZERO
var _done := Callable()

static var _current: MatchEmblem


## Plays an emblem over `host` (screen space) from `from` to the score at
## `to`. `arrived` runs when it reaches the score.
static func release(host: Control, texture: Texture2D, from: Vector2, to: Vector2, combo_count := 1,
		is_golden := false, arrived := Callable()) -> MatchEmblem:
	if texture == null:
		if arrived.is_valid():
			arrived.call()
		return null
	if is_instance_valid(_current):
		_current.hurry()
	var emblem := MatchEmblem.new()
	emblem.picture = texture
	emblem.combo = clampi(combo_count, 1, MAX_COMBO)
	emblem.golden = is_golden
	emblem.name = "MatchEmblem"
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.z_index = 15
	host.add_child(emblem)
	emblem._start(from, to, arrived)
	_current = emblem
	return emblem


## The emblem now playing, or null (tests).
static func current() -> MatchEmblem:
	return _current if is_instance_valid(_current) else null


func _start(from: Vector2, to: Vector2, arrived: Callable) -> void:
	var side := BASE_SIZE + SIZE_PER_COMBO * (combo - 1)
	size = Vector2(side, side) * 2.4
	pivot_offset = size / 2.0
	_target = to
	_done = arrived
	var host := get_parent() as Control
	var local_from := host.get_global_transform().affine_inverse() * from
	position = local_from - size / 2.0
	_tween = create_tween()
	if Motion.reduced:
		_grow = 0.55
		modulate.a = 0.0
		_tween.tween_property(self, "modulate:a", 1.0, 0.15)
		_tween.tween_interval(0.45)
		_tween.tween_property(self, "modulate:a", 0.0, 0.2)
		_tween.tween_callback(_finish)
		return
	# Rise out of the pair into the middle of the screen, just under the
	# tray, and swell, with the light opening around it.
	var rest := Vector2(host.size.x / 2.0, local_from.y + side * 0.85)
	_tween.tween_property(self, "position", rest - size / 2.0, RISE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "_grow", 1.0, RISE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "_glow", 1.0, RISE * 0.8).set_trans(Tween.TRANS_SINE)
	_tween.tween_interval(HOLD)
	_fly()


## A newer match arrived: go to the score now.
func hurry() -> void:
	if Motion.reduced:
		_finish()
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_fly(0.22)


func _fly(seconds := FLY) -> void:
	var host := get_parent() as Control
	var end := host.get_global_transform().affine_inverse() * _target - size / 2.0
	_tween.tween_property(self, "position", end, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(self, "_grow", 0.18, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(self, "_glow", 0.35, seconds)
	_tween.tween_callback(_arrive)


## At the score: a small shower of light, then gone.
func _arrive() -> void:
	if _done.is_valid():
		_done.call()
		_done = Callable()
	var sparks := CPUParticles2D.new()
	sparks.texture = LotusMark.PETAL
	sparks.amount = 10 + combo * 3
	sparks.lifetime = 0.7
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.position = size / 2.0
	sparks.spread = 180.0
	sparks.gravity = Vector2(0, 160)
	sparks.initial_velocity_min = 120.0
	sparks.initial_velocity_max = 260.0
	sparks.scale_amount_min = 0.15
	sparks.scale_amount_max = 0.3
	sparks.color = GOLD if golden else IVORY
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	sparks.color_ramp = fade
	add_child(sparks)
	sparks.emitting = true
	_tween = create_tween()
	_tween.tween_property(self, "_grow", 0.0, 0.12)
	_tween.tween_interval(sparks.lifetime)
	_tween.tween_callback(_finish)


func _finish() -> void:
	if _done.is_valid():
		_done.call()
		_done = Callable()
	if _current == self:
		_current = null
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	_spin += delta * (0.6 + 0.12 * combo)
	queue_redraw()


func _draw() -> void:
	if picture == null or _grow <= 0.0:
		return
	var center := size / 2.0
	var side := (BASE_SIZE + SIZE_PER_COMBO * (combo - 1)) * _grow
	var light := GOLD if golden else IVORY
	var accent := GOLD if golden else SAKURA
	if not Motion.reduced and _glow > 0.0:
		# Turning rays: more and longer with the combo.
		var rays := 8 + combo * 2
		var reach := side * (0.95 + 0.12 * combo) * _glow
		for k in rays:
			var angle := _spin + TAU * k / rays
			var tip := center + Vector2.from_angle(angle) * reach
			var left := center + Vector2.from_angle(angle - 0.07) * side * 0.3
			var right := center + Vector2.from_angle(angle + 0.07) * side * 0.3
			draw_colored_polygon(PackedVector2Array([left, tip, right]), Color(light, 0.32 * _glow))
		# Soft halo and a bright ring.
		for i in 5:
			draw_circle(center, side * (0.8 - i * 0.07), Color(light, 0.11 * _glow))
		draw_arc(center, side * 0.6, 0.0, TAU, 64, Color(accent, 0.85 * _glow), 5.0, true)
		# Sparkles circling the emblem.
		var sparkles := 4 + combo * 2
		for k in sparkles:
			var angle := -_spin * 1.6 + TAU * k / sparkles
			var wobble := sin(_time * 4.0 + k) * side * 0.04
			var point := center + Vector2.from_angle(angle) * (side * 0.72 + wobble)
			var twinkle := 0.5 + 0.5 * sin(_time * 7.0 + k * 1.7)
			_draw_star(point, side * 0.035 * (0.6 + twinkle), Color(light, 0.9 * _glow))
	# The picture on an ivory medallion, slightly larger than on the tile.
	draw_circle(center, side * 0.5, Color(0.08, 0.1, 0.09, 0.35))
	draw_circle(center, side * 0.47, Color(IVORY, 0.97))
	draw_arc(center, side * 0.47, 0.0, TAU, 64, Color(GOLD, 0.95), 4.0, true)
	var art := side * 0.66
	var picture_size := picture.get_size()
	var fit := art / maxf(picture_size.x, picture_size.y)
	var drawn := picture_size * fit
	draw_texture_rect(picture, Rect2(center - drawn / 2.0, drawn), false)


func _draw_star(at: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 8:
		var r := radius if i % 2 == 0 else radius * 0.35
		points.append(at + Vector2.from_angle(TAU * i / 8.0) * r)
	draw_colored_polygon(points, color)
