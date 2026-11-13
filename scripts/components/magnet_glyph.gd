@tool
class_name MagnetGlyph
extends Control
## A horseshoe magnet drawn as vectors, in the style of the supplied icon set
## (gold fill, brown edge; ivory pole tips), for the Magnet tool.

const FILL := ShuffleGlyph.FILL
const EDGE := ShuffleGlyph.EDGE
const TIP := Color(0.965, 0.933, 0.875)


func _draw() -> void:
	var s := minf(size.x, size.y) / 128.0
	var origin := (size - Vector2(128, 128) * s) / 2.0
	var center := origin + Vector2(64, 60) * s
	var radius := 32.0 * s
	var width := 22.0 * s
	# The bend (open at the top), drawn edge first, then fill.
	for pass_index in 2:
		var color := EDGE if pass_index == 0 else FILL
		var grow := 6.0 * s if pass_index == 0 else 0.0
		draw_arc(center, radius, 0.0, PI, 32, color, width + grow, true)
		for side in [-1.0, 1.0]:
			var x: float = center.x + side * radius
			draw_line(Vector2(x, center.y + 1.0), Vector2(x, origin.y + 22.0 * s), color, width + grow, true)
	# Ivory pole tips.
	for side in [-1.0, 1.0]:
		var x: float = center.x + side * radius
		var tip := Rect2(Vector2(x - width / 2.0, origin.y + 14.0 * s), Vector2(width, 16.0 * s))
		draw_rect(tip.grow(3.0 * s), EDGE)
		draw_rect(tip, TIP)
