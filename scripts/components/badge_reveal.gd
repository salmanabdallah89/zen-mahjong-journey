class_name BadgeReveal
extends Control
## The moment a badge is earned, over everything: the screen dims, light opens
## behind the medal, it settles in, and its rank and name follow. Several
## earned at once play one after another (at most MAX_SHOWN; the rest wait on
## the Badges page). A tap moves on. Emits `finished` after the last.

signal finished

const BURST_SCENE := preload("res://scenes/components/match_burst.tscn")
const MEDAL_SIZE := Vector2(440, 440)
const MAX_SHOWN := 3

var _queue: Array[Dictionary] = []
var _extra := 0
var _tween: Tween

@onready var _dim: ColorRect = %RevealDim
@onready var _halo: Control = %RevealHalo
@onready var _medal: BadgeMedal = %RevealMedal
@onready var _rank_label: Label = %RevealRank
@onready var _name_label: Label = %RevealName
@onready var _goal_label: Label = %RevealGoal
@onready var _more_label: Label = %RevealMore
@onready var _continue: Button = %RevealContinue


func _ready() -> void:
	_continue.pressed.connect(next)
	hide()


## Plays `earned` ({id, rank} entries, best first).
func play(earned: Array[Dictionary]) -> void:
	_queue = earned.slice(0, MAX_SHOWN)
	_extra = maxi(earned.size() - MAX_SHOWN, 0)
	_dim.modulate.a = 0.0
	show()
	next()


func next() -> void:
	if _queue.is_empty():
		hide()
		finished.emit()
		return
	var shown: Dictionary = _queue.pop_front()
	var entry := BadgeBook.family(str(shown.id))
	var rank := int(shown.rank)
	_medal.setup(entry, rank)
	_rank_label.text = "%s Badge" % BadgeBook.RANK_NAMES[rank]
	_name_label.text = str(entry.name)
	_goal_label.text = BadgeBook.goal_text(entry, rank)
	_more_label.text = "+%d more on the Badges page" % _extra if _queue.is_empty() and _extra > 0 else ""
	_more_label.visible = not _more_label.text.is_empty()
	_continue.text = "Next Badge" if not _queue.is_empty() else "Wonderful"
	AudioManager.play_sfx("reward")
	AudioManager.vibrate(40)
	_animate()


func shown_name() -> String:
	return _name_label.text


func _animate() -> void:
	if _tween:
		_tween.kill()
	_medal.pivot_offset = MEDAL_SIZE / 2.0
	var texts: Array[Control] = [_rank_label, _name_label, _goal_label, _more_label, _continue]
	_tween = create_tween()
	_tween.tween_property(_dim, "modulate:a", 1.0, Motion.duration(0.25)).set_trans(Tween.TRANS_SINE)
	if Motion.reduced:
		_medal.scale = Vector2.ONE
		_halo.modulate.a = 0.6
		_medal.modulate.a = 0.0
		for text in texts:
			text.modulate.a = 1.0
		_tween.parallel().tween_property(_medal, "modulate:a", 1.0, 0.2)
		return
	for text in texts:
		text.modulate.a = 0.0
	_medal.modulate.a = 1.0
	_medal.scale = Vector2(0.2, 0.2)
	_halo.modulate.a = 0.0
	_tween.parallel().tween_property(_halo, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(_medal, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_sparkle)
	for text in texts:
		_tween.tween_property(text, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)


func _sparkle() -> void:
	var burst: Node2D = BURST_SCENE.instantiate()
	burst.position = MEDAL_SIZE / 2.0
	burst.scale = Vector2(2.2, 2.2)
	_medal.add_child(burst)
