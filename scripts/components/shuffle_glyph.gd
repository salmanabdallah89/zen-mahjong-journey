@tool
class_name ShuffleGlyph
extends Control
## Two crossing arrows drawn as vectors, in the style of the supplied icon set.
## Stand-in because assets/ui/icons/icon_shuffle.png contains an unrendered
## glyph box (see docs/KNOWN_ISSUES.md). Delete this node and set the button's
## icon once corrected art is supplied.

const FILL := Color(0.953, 0.824, 0.541)
const EDGE := Color(0.471, 0.353, 0.196)


func _draw() -> void:
	var s := minf(size.x, size.y) / 128.0
	var origin := (size - Vector2(128, 128) * s) / 2.0
	var lines := [
		PackedVector2Array([Vector2(14, 92), Vector2(42, 92), Vector2(80, 36), Vector2(100, 36)]),
		PackedVector2Array([Vector2(14, 36), Vector2(42, 36), Vector2(80, 92), Vector2(100, 92)]),
	]
	var heads := [Vector2(100, 36), Vector2(100, 92)]
	for pass_index in 2:
		var color := EDGE if pass_index == 0 else FILL
		var grow := 3.0 if pass_index == 0 else 0.0
		for line: PackedVector2Array in lines:
			draw_polyline(_place(line, origin, s), color, (11.0 + grow * 2.0) * s, true)
		for tip: Vector2 in heads:
			var head := PackedVector2Array([tip + Vector2(-4 - grow, -18 - grow * 1.6),
				tip + Vector2(20 + grow * 1.8, 0), tip + Vector2(-4 - grow, 18 + grow * 1.6)])
			draw_colored_polygon(_place(head, origin, s), color)


func _place(points: PackedVector2Array, origin: Vector2, s: float) -> PackedVector2Array:
	var placed := PackedVector2Array()
	for p in points:
		placed.append(origin + p * s)
	return placed
