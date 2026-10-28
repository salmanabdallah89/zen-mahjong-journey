extends Node2D
## One-shot effect played where a matched pair meets: a soft golden flash and
## a few drifting sakura petals. Combos (matches in a row) add a widening gold
## ring and a few more sparkles; it stays small so it never covers the board.
## Frees itself when done.

const LIFETIME := 1.3
## Combo from which the ring appears, and from which it is at its fullest.
const RING_COMBO := 3
const BIG_COMBO := 5

## Matches in a row, counting this one (set before adding to the tree).
var strength := 1
## Seconds to wait before playing (the pair is still gliding together).
var delay := 0.0
## False for small accents (level-complete stars): sparkles only, no petals.
var with_petals := true

@onready var _flash: Sprite2D = %Flash
@onready var _petals: CPUParticles2D = %Petals
@onready var _sparkles: CPUParticles2D = %Sparkles


func _ready() -> void:
	visible = false
	var big := strength >= BIG_COMBO
	if Motion.reduced:
		_sparkles.amount = 6
		_petals.amount = 2
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
	_flash.scale = Vector2(0.4, 0.4)
	_flash.modulate.a = 0.9
	var tween := create_tween().set_parallel()
	tween.tween_property(_flash, "scale", Vector2(reach, reach), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	if strength >= RING_COMBO and not Motion.reduced:
		_add_ring(strength >= BIG_COMBO)


## A thin gold ring that widens and fades: the combo accent.
func _add_ring(big: bool) -> void:
	var ring := Sprite2D.new()
	ring.texture = _ring_texture()
	ring.scale = Vector2(0.5, 0.5)
	ring.modulate = Color(1, 0.9, 0.62, 0.9)
	add_child(ring)
	var size := 3.4 if big else 2.6
	var tween := create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector2(size, size), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)


static var _ring: GradientTexture2D


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
