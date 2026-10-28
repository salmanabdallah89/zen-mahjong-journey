class_name BackgroundDrift
extends RefCounted
## A very slow "breathing" zoom and sideways drift for a full-screen
## background, so the garden feels alive without drawing the eye. One looping
## tween on the background itself: no extra nodes or draw calls. Off when the
## player prefers reduced animations.

## Largest zoom (1.0 = none) and the seconds for one half of the cycle.
const ZOOM := 1.045
const DRIFT := 18.0
const HALF_CYCLE := 24.0


static func start(background: Control) -> Tween:
	if Motion.reduced:
		return null
	var center := func() -> void: background.pivot_offset = background.size / 2.0
	center.call()
	background.resized.connect(center)
	var tween := background.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(background, "scale", Vector2(ZOOM, ZOOM), HALF_CYCLE)
	tween.parallel().tween_property(background, "position:x", -DRIFT, HALF_CYCLE)
	tween.tween_property(background, "scale", Vector2.ONE, HALF_CYCLE)
	tween.parallel().tween_property(background, "position:x", 0.0, HALF_CYCLE)
	return tween
