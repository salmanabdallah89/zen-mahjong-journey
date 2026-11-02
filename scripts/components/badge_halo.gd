class_name BadgeHalo
extends Control
## The soft light behind a revealed medal: warm rings fading outward and slow
## rays that turn gently (still when animations are reduced).

const COLOR := Color(1.0, 0.86, 0.56)
const RAYS := 12
const TURN_SPEED := 0.09

var _turn := 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree() or Motion.reduced:
		return
	_turn = fposmod(_turn + delta * TURN_SPEED, TAU)
	queue_redraw()


func _draw() -> void:
	var centre := size / 2.0
	var radius := minf(size.x, size.y) / 2.0
	for i in RAYS:
		var angle := _turn + TAU * i / RAYS
		var ray := PackedVector2Array([centre, centre + Vector2.from_angle(angle - 0.09) * radius,
			centre + Vector2.from_angle(angle + 0.09) * radius])
		draw_polygon(ray, PackedColorArray([Color(COLOR, 0.3), Color(COLOR, 0.0), Color(COLOR, 0.0)]))
	for i in 9:
		draw_circle(centre, radius * (0.82 - i * 0.05), Color(COLOR, 0.022 + i * 0.004))
