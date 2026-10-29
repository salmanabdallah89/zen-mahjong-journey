class_name ScoreMeter
extends PanelContainer
## The score pill under the HUD: the level's points, the combo multiplier
## ("×3") and a thin combo bar that drains while the next match can still
## keep the streak going. Points glide in from matches (game screen) and the
## number counts up when they land. Reduced animations: no pops, quick counts.

const BAR_HEIGHT := 10.0
const BAR_WIDTH := 380.0
const GOLD := Color(0.78, 0.65, 0.42)
const SAKURA := Color(0.91, 0.71, 0.74)
## Below this share of the combo window the bar turns sakura and the
## multiplier dims, as a "hurry" cue (the bar's length tells it too).
const HURRY_SHARE := 0.3

var _value: Label
var _multiplier: Label
var _bar: Control
var _shown := 0.0
var _target := 0
var _count_tween: Tween
var _pop_tween: Tween
var _fraction := 0.0
var _shown_multiplier := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = &"ScorePill"
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	var caption := Label.new()
	caption.text = "SCORE"
	caption.theme_type_variation = &"ScoreCaptionLabel"
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	_value = Label.new()
	_value.name = "ScoreValue"
	_value.theme_type_variation = &"ScoreValueLabel"
	_value.custom_minimum_size = Vector2(190, 0)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_value)
	_multiplier = Label.new()
	_multiplier.name = "Multiplier"
	_multiplier.theme_type_variation = &"ScoreMultiplierLabel"
	_multiplier.custom_minimum_size = Vector2(80, 0)
	_multiplier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_multiplier)
	_bar = Control.new()
	_bar.name = "ComboBar"
	_bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	column.add_child(_bar)
	reset()


## A new attempt: zero points, no combo.
func reset() -> void:
	if _count_tween:
		_count_tween.kill()
	_target = 0
	_set_shown(0.0)
	set_combo(1, 0.0)


## Shows `value`, counting up (or down, after an undo) from what is shown.
func set_score(value: int) -> void:
	_target = value
	if _count_tween:
		_count_tween.kill()
	var seconds := clampf(absf(value - _shown) / 1500.0, 0.25, 0.7)
	if Motion.reduced:
		seconds = 0.15
	_count_tween = create_tween()
	_count_tween.tween_method(_set_shown, _shown, float(value), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Points arriving: a small swell of the number.
func pulse() -> void:
	if Motion.reduced:
		return
	if _pop_tween:
		_pop_tween.kill()
	_value.pivot_offset = _value.size / 2.0
	_pop_tween = create_tween()
	_pop_tween.tween_property(_value, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_SINE)
	_pop_tween.tween_property(_value, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)


## Combo state, called every frame: the multiplier of the streak and the share
## of its window left (0 = no streak running).
func set_combo(multiplier: int, fraction: float) -> void:
	fraction = clampf(fraction, 0.0, 1.0)
	var active := fraction > 0.0 and multiplier > 1
	var shown_multiplier := multiplier if active else 1
	if shown_multiplier != _shown_multiplier or (_multiplier.text.is_empty() == active):
		var grew := shown_multiplier > _shown_multiplier
		_shown_multiplier = shown_multiplier
		_multiplier.text = "×%d" % shown_multiplier if active else ""
		if grew and not Motion.reduced:
			_multiplier.pivot_offset = _multiplier.size / 2.0
			_multiplier.scale = Vector2(1.5, 1.5)
			_multiplier.create_tween().tween_property(_multiplier, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_multiplier.modulate.a = 1.0 if fraction >= HURRY_SHARE else 0.75
	if not is_equal_approx(fraction, _fraction):
		_fraction = fraction
		_bar.queue_redraw()


## Where gliding points land (screen position).
func target_global() -> Vector2:
	return _value.get_global_rect().get_center()


func score_shown() -> int:
	return roundi(_shown)


func target_score() -> int:
	return _target


func multiplier_text() -> String:
	return _multiplier.text


func combo_fraction() -> float:
	return _fraction


func _set_shown(value: float) -> void:
	_shown = value
	_value.text = format_points(roundi(value))


## 12345 -> "12,345".
static func format_points(points: int) -> String:
	var digits := str(absi(points))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if points < 0 else "") + digits + out


func _draw_bar() -> void:
	var track := Rect2(Vector2.ZERO, _bar.size)
	var radius := BAR_HEIGHT / 2.0
	_draw_round(track, Color(0.96, 0.93, 0.87, 0.18), radius)
	if _fraction <= 0.0:
		return
	var fill := Rect2(track.position, Vector2(maxf(track.size.x * _fraction, BAR_HEIGHT), track.size.y))
	_draw_round(fill, SAKURA if _fraction < HURRY_SHARE else GOLD, radius)


func _draw_round(rect: Rect2, color: Color, radius: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	_bar.draw_style_box(box, rect)
