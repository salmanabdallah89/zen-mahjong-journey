class_name MatchBurst
extends Node2D
## One-shot effect played where a matched pair meets: a soft golden flash, a
## small shockwave, four-point glints and a few drifting sakura petals. Combos
## (matches in a row) widen the ring and add glints; it stays small so it never
## covers the board. Lives in the board layer, so it scales with the tiles on
## every screen size. Frees itself when done.

const LIFETIME := 1.3
## Combo from which the ring appears, and from which it is at its fullest.
const RING_COMBO := 3
const BIG_COMBO := 5
## Major combo: a second, later ring and a few more petals (still small).
const MAJOR_COMBO := 8
## Rings on screen at once, across all bursts: quick streaks stay calm.
const MAX_RINGS := 2

## Matches in a row, counting this one (set before adding to the tree).
var strength := 1
## Seconds to wait before playing (the pair is still gliding together).
var delay := 0.0
## False for small accents (level-complete stars): sparkles only, no petals.
var with_petals := true
## Compact accent for the message lane: glints only, no flash or rings, and
## short enough to stay inside the lane.
var compact := false

## Rings currently on screen (all bursts).
static var active_rings := 0

@onready var _flash: Sprite2D = %Flash
@onready var _petals: CPUParticles2D = %Petals
@onready var _sparkles: CPUParticles2D = %Sparkles


func _ready() -> void:
	visible = false
	_sparkles.texture = _glint_texture()
	var big := strength >= BIG_COMBO
	if compact:
		_sparkles.amount = 10
		_sparkles.initial_velocity_min = 50.0
		_sparkles.initial_velocity_max = 110.0
		_sparkles.emission_sphere_radius = 20.0
		_petals.amount = 4
		_petals.initial_velocity_min = 30.0
		_petals.initial_velocity_max = 70.0
		_petals.gravity = Vector2(0, 40)
		_petals.direction = Vector2(1, 0)
		_petals.spread = 180.0
		_flash.hide()
	elif Motion.reduced:
		_sparkles.amount = 6
		_petals.amount = 2
	elif strength >= MAJOR_COMBO:
		_sparkles.amount = 34
		_petals.amount = 12
	elif strength >= RING_COMBO:
		_sparkles.amount = 30 if big else 22
		_petals.amount = 10 if big else 8
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(_play)
	tween.tween_interval(LIFETIME)
	tween.tween_callback(queue_free)


func _play() -> void:
	visible = true
	_petals.emitting = with_petals
	_sparkles.emitting = true
	var reach := 1.6 if strength < RING_COMBO else (2.2 if strength < BIG_COMBO else 2.6)
	if compact:
		return
	_flash.scale = Vector2(0.4, 0.4)
	_flash.modulate.a = 0.9
	var tween := create_tween().set_parallel()
	tween.tween_property(_flash, "scale", Vector2(reach, reach), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	if Motion.reduced:
		return
	# Every match: a quick, faint shockwave. Combos: a wider, brighter ring.
	_add_ring(1.7, 0.55, 0.32)
	if strength >= RING_COMBO:
		_add_ring(3.4 if strength >= BIG_COMBO else 2.6, 0.9, 0.6)
	if strength >= MAJOR_COMBO:
		var echo := create_tween()
		echo.tween_interval(0.14)
		echo.tween_callback(_add_ring.bind(4.2, 0.6, 0.75))


## A thin gold ring that widens to `reach` and fades. Skipped while
## MAX_RINGS are already showing.
func _add_ring(reach: float, alpha: float, seconds: float) -> void:
	if active_rings >= MAX_RINGS:
		return
	active_rings += 1
	var ring := Sprite2D.new()
	ring.texture = _ring_texture()
	ring.scale = Vector2(0.5, 0.5)
	ring.modulate = Color(1, 0.9, 0.62, alpha)
	add_child(ring)
	var tween := create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector2(reach, reach), seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, seconds).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(_ring_done.bind(ring))
	# A burst freed early (the level ends) must still release its ring.
	ring.tree_exiting.connect(_release_ring.bind(ring), CONNECT_ONE_SHOT)


func _ring_done(ring: Sprite2D) -> void:
	ring.queue_free()


func _release_ring(ring: Sprite2D) -> void:
	if not ring.has_meta("released"):
		ring.set_meta("released", true)
		active_rings = maxi(active_rings - 1, 0)


static var _ring: GradientTexture2D
static var _glint: ImageTexture


## A soft four-point glint (original, drawn once): two thin light streaks
## crossing over a small warm glow.
static func _glint_texture() -> ImageTexture:
	if _glint == null:
		var size := 48
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var half := (size - 1) / 2.0
		for y in size:
			for x in size:
				var dx := absf(x - half) / half
				var dy := absf(y - half) / half
				var streaks := maxf(exp(-dx * 9.0) * exp(-dy * 2.2), exp(-dy * 9.0) * exp(-dx * 2.2))
				var glow := exp(-(dx * dx + dy * dy) * 6.0) * 0.6
				var a := clampf(streaks + glow, 0.0, 1.0)
				image.set_pixel(x, y, Color(1.0, 0.97, 0.86, a))
		_glint = ImageTexture.create_from_image(image)
	return _glint


static func _ring_texture() -> GradientTexture2D:
	if _ring == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.72, 0.84, 0.92, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0),
			Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		_ring = GradientTexture2D.new()
		_ring.gradient = gradient
		_ring.fill = GradientTexture2D.FILL_RADIAL
		_ring.fill_from = Vector2(0.5, 0.5)
		_ring.fill_to = Vector2(1.0, 0.5)
		_ring.width = 128
		_ring.height = 128
	return _ring
