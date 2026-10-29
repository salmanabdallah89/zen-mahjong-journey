class_name ComboFeedback
extends Control
## Praise for matches in a row ("Nice!" … "Zen Master!"), shown in the
## feedback lane between the board and the toolbar, so it never covers a
## tile. Each tier is a little larger and warmer; the top tiers add a few
## glints inside the lane. With reduced animations it simply fades in and out.
## The game screen calls show_combo() at the moment the matched pair touches.

## Emitted when praise appears: its tier (1..TIERS.size()) and word.
signal shown(tier: int, word: String)

## Tiers: matches in a row that reach it, word, tint, size.
const TIERS := [
	[2, "Nice!", Color(1.0, 1.0, 1.0), 0.8],
	[3, "Great!", Color(1.0, 0.96, 0.84), 0.88],
	[5, "Amazing!", Color(1.0, 0.9, 0.66), 0.97],
	[7, "Excellent!", Color(1.0, 0.84, 0.86), 1.05],
	[10, "Zen Master!", Color(1.0, 0.86, 0.52), 1.14],
]
const BURST_SCENE := preload("res://scenes/components/match_burst.tscn")
## Seconds the praise stays fully visible: a little longer from "Great!" up,
## so bigger moments aren't missed in fast play.
const HOLD := 0.55
const HOLD_HIGH := 0.75
## How long a milestone message keeps the lane before praise may replace it.
const MESSAGE_HOLD_MSEC := 1400

var _row: HBoxContainer
var _word: Label
var _count: Label
var _tween: Tween
## A milestone message keeps the lane until then (Time.get_ticks_msec).
var _message_until := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fill the lane whatever its size is right now (it is sized later by the
	# board's fit): anchors AND offsets, or a zero-width lane would stick.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row = HBoxContainer.new()
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 18)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_word = Label.new()
	_word.theme_type_variation = &"PraiseLabel"
	_word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_word)
	_count = Label.new()
	_count.theme_type_variation = &"PraiseCountLabel"
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_count)
	hide()


## Highest tier reached by `combo` matches in a row (0 = none yet).
static func tier_for(combo: int) -> int:
	var tier := 0
	for i in TIERS.size():
		if combo >= int(TIERS[i][0]):
			tier = i + 1
	return tier


## True when this match is the one that reaches a new tier.
static func reaches_tier(combo: int) -> bool:
	for entry: Array in TIERS:
		if combo == int(entry[0]):
			return true
	return false


static func word_for(tier: int) -> String:
	return str(TIERS[tier - 1][1]) if tier >= 1 and tier <= TIERS.size() else ""


## Shows praise for `combo` matches in a row; returns its tier (0 = none).
func show_combo(combo: int) -> int:
	var tier := tier_for(combo)
	if tier == 0:
		return 0
	# A milestone is read to the end; the streak's cues still ring.
	if Time.get_ticks_msec() < _message_until:
		return tier
	var entry: Array = TIERS[tier - 1]
	var tint: Color = entry[2]
	var size_scale: float = entry[3]
	_word.text = str(entry[1])
	_count.text = "×%d" % combo
	# A new tier arriving while praise still shows swaps in quickly instead
	# of fading in from nothing.
	var swapping := visible and modulate.a > 0.5
	var hold := HOLD_HIGH if tier >= 2 else HOLD
	if _tween:
		_tween.kill()
	show()
	pivot_offset = size / 2.0
	_row.position.y = 0.0
	modulate = Color(tint, 1.0 if swapping else 0.0)
	_tween = create_tween()
	if Motion.reduced:
		scale = Vector2.ONE * size_scale
		_tween.tween_property(self, "modulate:a", 1.0, 0.1)
		_tween.tween_interval(hold)
		_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	else:
		# Pops in with a small overshoot (a touch of tilt from "Amazing!" up),
		# holds, then drifts up as it fades.
		scale = Vector2.ONE * size_scale * (0.9 if swapping else 0.6)
		rotation = deg_to_rad(-4.0) if tier >= 3 else 0.0
		_tween.set_parallel()
		_tween.tween_property(self, "modulate:a", 1.0, 0.1)
		_tween.tween_property(self, "scale", Vector2.ONE * size_scale * 1.08, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
		_tween.chain().tween_property(self, "scale", Vector2.ONE * size_scale, 0.12).set_trans(Tween.TRANS_SINE)
		_tween.chain().tween_interval(hold)
		_tween.chain().tween_property(self, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
		_tween.tween_property(_row, "position:y", -14.0, 0.3).set_trans(Tween.TRANS_SINE)
		if tier >= 4:
			_add_glints(tier >= TIERS.size())
	_tween.chain().tween_callback(hide)
	shown.emit(tier, str(entry[1]))
	return tier


## A level milestone ("Halfway there!") in the praise style, without a count.
## A combo arriving later simply replaces it.
func show_message(text: String) -> void:
	if _tween:
		_tween.kill()
	_word.text = text
	_count.text = ""
	_message_until = Time.get_ticks_msec() + MESSAGE_HOLD_MSEC
	show()
	pivot_offset = size / 2.0
	_row.position.y = 0.0
	rotation = 0.0
	modulate = Color(1.0, 0.9, 0.92, 0.0)
	_tween = create_tween()
	if Motion.reduced:
		scale = Vector2.ONE * 0.9
		_tween.tween_property(self, "modulate:a", 1.0, 0.1)
	else:
		scale = Vector2.ONE * 0.6
		_tween.set_parallel()
		_tween.tween_property(self, "modulate:a", 1.0, 0.15)
		_tween.tween_property(self, "scale", Vector2.ONE * 0.95, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.chain().tween_interval(0.0)
	_tween.chain().tween_interval(1.1)
	_tween.chain().tween_property(self, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	_tween.chain().tween_callback(hide)


## Hides the praise at once (a toast is taking the lane).
func dismiss() -> void:
	_message_until = 0
	if _tween:
		_tween.kill()
	hide()


func is_showing() -> bool:
	return visible


func text() -> String:
	return _word.text


## A few glints (and petals for "Zen Master!") behind the word, inside the lane.
func _add_glints(with_petals: bool) -> void:
	for side in [-1.0, 1.0]:
		var burst: Node2D = BURST_SCENE.instantiate()
		burst.set("compact", true)
		burst.set("with_petals", with_petals)
		burst.position = size / 2.0 + Vector2(side * 260.0, 0.0)
		get_parent().add_child(burst)
