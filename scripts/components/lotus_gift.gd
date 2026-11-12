class_name LotusGift
extends BaseButton
## A Lotus Gift on the journey path (docs/LOTUS_REWARDS.md): a closed bud until
## its level is cleared, a glowing, gently breathing bud while it waits to be
## opened, and a small open flower afterwards. States never rely on colour
## alone: closed buds are small and dim, ready ones glow and breathe (still
## glow with reduced animations), opened ones are open flowers.

enum State { CLOSED, READY, OPENED }

## Touch target (canvas px, at least 120).
const SIDE := 132.0
## The flower is drawn this much larger than the touch area.
const FLOWER := 1.45

var level := 0
var state := State.CLOSED

var _mark: LotusMark
var _breath: Tween
## Strength of the warm glow behind a ready gift (0..1), drawn in _draw.
var glow := 0.0:
	set(value):
		glow = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(SIDE, SIDE)
	size = custom_minimum_size
	pivot_offset = size / 2.0
	focus_mode = Control.FOCUS_NONE
	# The journey screen plays its own sound for each state.
	set_meta("custom_sound", true)
	_mark = LotusMark.new()
	_mark.name = "Mark"
	# A flower on a glow, never a disc: the "you are here" badge is the disc.
	# It is drawn larger than the touch area, which stays SIDE square.
	_mark.disc = false
	_mark.size = size * FLOWER
	_mark.position = (size - _mark.size) / 2.0 + Vector2(0, -size.y * 0.12)
	_mark.pivot_offset = _mark.size / 2.0
	add_child(_mark)


## Soft shade for contrast on any garden, a warm glow when ready, and a thin
## gold ring that marks every gift as something to tap.
func _draw() -> void:
	var center := size / 2.0
	var radius := SIDE * 0.5
	draw_circle(center, radius * 0.95, Color(0.04, 0.07, 0.06, 0.28))
	if glow > 0.0:
		for k in 6:
			draw_circle(center, radius * (1.45 - k * 0.15), Color(1.0, 0.84, 0.5, 0.13 * glow))
	draw_arc(center, radius * 0.95, 0.0, TAU, 48, Color(LotusMark.GOLD, 0.5 + 0.5 * glow), 3.0, true)


func setup(gift_level: int, gift_state: State) -> void:
	level = gift_level
	state = gift_state
	if _breath:
		_breath.kill()
		_breath = null
	scale = Vector2.ONE
	glow = 1.0 if state == State.READY else 0.0
	match state:
		State.CLOSED:
			_mark.openness = 0.0
			_mark.scale = Vector2.ONE * 0.85
			modulate = Color(1, 1, 1, 0.78)
		State.READY:
			_mark.openness = 0.32
			_mark.scale = Vector2.ONE
			modulate = Color.WHITE
			if not Motion.reduced:
				_breath = create_tween().set_loops()
				_breath.tween_property(self, "scale", Vector2.ONE * 1.08, 0.9).set_trans(Tween.TRANS_SINE)
				_breath.parallel().tween_property(self, "glow", 0.6, 0.9).set_trans(Tween.TRANS_SINE)
				_breath.tween_property(self, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)
				_breath.parallel().tween_property(self, "glow", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
		State.OPENED:
			_mark.openness = 1.0
			_mark.scale = Vector2.ONE * 0.8
			modulate = Color(1, 1, 1, 0.85)


## The bud opens into a flower (reduced animations: a short fade), then rests
## as an opened gift.
func play_open() -> void:
	if _breath:
		_breath.kill()
		_breath = null
	state = State.OPENED
	var tween := create_tween()
	if Motion.reduced:
		tween.tween_property(self, "modulate:a", 0.4, 0.15)
		tween.tween_callback(setup.bind(level, State.OPENED))
		tween.tween_property(self, "modulate:a", 0.85, 0.2)
		return
	scale = Vector2.ONE
	tween.tween_property(self, "scale", Vector2.ONE * 1.3, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_mark, "openness", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(self, "glow", 0.0, 0.7)
	tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(setup.bind(level, State.OPENED))
	_burst()


## A few petals drift out of the opening flower.
func _burst() -> void:
	var petals := CPUParticles2D.new()
	petals.texture = LotusMark.PETAL
	petals.amount = 12
	petals.lifetime = 1.6
	petals.one_shot = true
	petals.explosiveness = 0.9
	petals.position = size / 2.0
	petals.direction = Vector2(0, -1)
	petals.spread = 70.0
	petals.gravity = Vector2(0, 60)
	petals.initial_velocity_min = 90.0
	petals.initial_velocity_max = 190.0
	petals.angular_velocity_min = -120.0
	petals.angular_velocity_max = 120.0
	petals.scale_amount_min = 0.3
	petals.scale_amount_max = 0.55
	petals.color = Color(1.0, 0.88, 0.92)
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	petals.color_ramp = fade
	add_child(petals)
	petals.emitting = true
	get_tree().create_timer(petals.lifetime + 0.5).timeout.connect(petals.queue_free)
