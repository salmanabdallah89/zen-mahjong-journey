extends Node2D
## One-shot effect played where a matched tile disappears: a soft golden flash
## and a few drifting sakura petals. Frees itself when done.

const LIFETIME := 1.3

@onready var _flash: Sprite2D = %Flash
@onready var _petals: CPUParticles2D = %Petals
@onready var _sparkles: CPUParticles2D = %Sparkles


func _ready() -> void:
	_petals.emitting = true
	_sparkles.emitting = true
	_flash.scale = Vector2(0.4, 0.4)
	_flash.modulate.a = 0.9
	var tween := create_tween().set_parallel()
	tween.tween_property(_flash, "scale", Vector2(1.6, 1.6), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_flash, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)
