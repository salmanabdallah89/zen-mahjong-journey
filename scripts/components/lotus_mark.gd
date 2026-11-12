class_name LotusMark
extends Control
## A lotus drawn from sakura petals: a closed bud (openness 0) that fans out
## into a full flower (openness 1), on an optional ivory disc with a gold ring.
## Used for Lotus Gifts on the journey map, the Perfect Clear stamp and its
## bloom (docs/LOTUS_REWARDS.md).

const PETAL := preload("res://assets/effects/petal_02.png")
const GOLD := Color(0.78, 0.65, 0.42)
const IVORY := Color(0.96, 0.93, 0.87)
const PETALS := 7

## 0 = closed bud, 1 = open flower.
var openness := 1.0:
	set(value):
		openness = clampf(value, 0.0, 1.0)
		queue_redraw()
## Colour of the petals (sakura by default; gold for a Perfect Clear).
var tint := Color(1.0, 0.86, 0.9):
	set(value):
		tint = value
		queue_redraw()
var disc := true:
	set(value):
		disc = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var radius := minf(size.x, size.y) / 2.0
	var center := size / 2.0
	if disc:
		draw_circle(center + Vector2(0, radius * 0.06), radius, Color(0, 0, 0, 0.22))
		draw_circle(center, radius, GOLD)
		draw_circle(center, radius * 0.9, IVORY)
	# Petals fan upward from a base below the centre: narrow as a bud, wide
	# as a flower.
	var base := center + Vector2(0, radius * 0.38)
	var spread := lerpf(0.22, 1.35, openness)
	var length := radius * lerpf(0.78, 0.86, openness)
	var petal_size := Vector2(length * lerpf(0.5, 0.62, openness), length)
	for k in PETALS:
		var side := (k - (PETALS - 1) / 2.0) / ((PETALS - 1) / 2.0)
		var angle := side * spread
		# Outer petals sit lower and a touch darker, like a real flower's.
		var shade := lerpf(1.0, 0.86, absf(side))
		draw_set_transform(base, angle, Vector2.ONE)
		draw_texture_rect(PETAL, Rect2(Vector2(-petal_size.x / 2.0, -petal_size.y), petal_size), false,
			Color(tint.r * shade, tint.g * shade, tint.b * shade, tint.a))
	draw_set_transform(Vector2.ZERO)
	draw_circle(base + Vector2(0, -radius * 0.04), radius * lerpf(0.08, 0.13, openness), GOLD)
