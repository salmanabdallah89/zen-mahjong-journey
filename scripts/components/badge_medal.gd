class_name BadgeMedal
extends Control
## One badge, drawn as vectors so it stays crisp at any size: a lotus-edged
## metal rim, a dark enamel centre and the family's picture struck in the same
## metal. Rank shows as metal AND as one to three pips under the picture, so
## it never depends on colour alone. Locked medals are unlit stone.

const GLYPH_SHADER := preload("res://themes/badge_glyph.gdshader")
const PETALS := 16
## Light and shade of each rank's metal: locked, Bronze, Silver, Gold.
const METAL_LIGHT: Array[Color] = [Color("6f7a78"), Color("e6b98a"), Color("f2f1ea"), Color("ffe6a3")]
const METAL_MID: Array[Color] = [Color("4a5553"), Color("b57a4a"), Color("b9c0bd"), Color("d9a944")]
const METAL_DARK: Array[Color] = [Color("2e3736"), Color("6b4128"), Color("6c7775"), Color("8a5f1f")]
const ENAMEL := {
	"Journey": Color("24463a"),
	"Mastery": Color("22364d"),
	"Discoveries": Color("4a2a44"),
	"Word Garden": Color("1f4a50"),
	"Daily": Color("5a3226"),
}
const ENAMEL_LOCKED := Color("1c2423")
const GLYPH_SHARE := 0.56

var _rank := 0
var _enamel := ENAMEL_LOCKED
var _glyph: TextureRect
var _material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_place_glyph)
	_ensure_glyph()
	_place_glyph()


func setup(entry: Dictionary, rank: int) -> void:
	_ensure_glyph()
	_rank = clampi(rank, 0, BadgeBook.MAX_RANK)
	_enamel = ENAMEL.get(entry.group, ENAMEL_LOCKED) if _rank > 0 else ENAMEL_LOCKED
	_glyph.texture = load(BadgeBook.picture_path(entry))
	_material.set_shader_parameter("light", METAL_LIGHT[_rank])
	_material.set_shader_parameter("mid", METAL_MID[_rank])
	_material.set_shader_parameter("dark", METAL_DARK[_rank])
	_material.set_shader_parameter("sheen_on", 1.0 if _rank == BadgeBook.MAX_RANK and not Motion.reduced else 0.0)
	queue_redraw()


func rank() -> int:
	return _rank


func _ensure_glyph() -> void:
	if _glyph != null:
		return
	_material = ShaderMaterial.new()
	_material.shader = GLYPH_SHADER
	_glyph = TextureRect.new()
	_glyph.name = "Glyph"
	_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.material = _material
	add_child(_glyph)


func _place_glyph() -> void:
	var side := minf(size.x, size.y) * GLYPH_SHARE
	_glyph.size = Vector2(side, side)
	# A little above the middle: the pips sit under the picture.
	_glyph.position = (size - _glyph.size) / 2.0 - Vector2(0, side * 0.07)
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) / 2.0 * 0.96
	var centre := size / 2.0
	var light := METAL_LIGHT[_rank]
	var mid := METAL_MID[_rank]
	var dark := METAL_DARK[_rank]
	# Soft shadow under the medal.
	for i in 5:
		draw_circle(centre + Vector2(0, radius * 0.05), radius * (1.0 - i * 0.012), Color(0, 0, 0, 0.09))
	_draw_rim(centre, radius, light, mid, dark)
	draw_circle(centre, radius * 0.79, dark)
	draw_circle(centre, radius * 0.76, mid)
	draw_circle(centre, radius * 0.73, _enamel.darkened(0.35))
	draw_circle(centre - Vector2(0, radius * 0.02), radius * 0.70, _enamel)
	# Glaze: a soft light on the enamel's upper edge.
	draw_arc(centre, radius * 0.66, deg_to_rad(205), deg_to_rad(335), 32, Color(1, 1, 1, 0.09), radius * 0.05, true)
	_draw_pips(centre, radius, light, dark)


## Lotus edge: rounded petals lit from the upper left.
func _draw_rim(centre: Vector2, radius: float, light: Color, mid: Color, dark: Color) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var steps := PETALS * 8
	var sun := Vector2(-0.5, -0.86)
	for i in steps:
		var angle := TAU * i / steps
		var wave := absf(cos(angle * PETALS / 2.0))
		var out := Vector2.from_angle(angle)
		points.append(centre + out * radius * (0.90 + 0.10 * wave))
		var shine := (out.dot(sun) + 1.0) / 2.0
		var base := dark.lerp(mid, minf(shine * 2.0, 1.0))
		colors.append(base.lerp(light, maxf(shine * 2.0 - 1.0, 0.0) * 0.9 + wave * 0.1))
	draw_polygon(points, colors)
	points.append(points[0])
	draw_polyline(points, dark, maxf(radius * 0.012, 1.0), true)


## One to three diamonds at the foot of the enamel; hollow ones are ranks to come.
func _draw_pips(centre: Vector2, radius: float, light: Color, dark: Color) -> void:
	var side := radius * 0.055
	var gap := side * 3.1
	var foot := centre + Vector2(0, radius * 0.55)
	for i in BadgeBook.MAX_RANK:
		var at := foot + Vector2((i - 1) * gap, 0)
		var diamond := PackedVector2Array([at + Vector2(0, -side), at + Vector2(side, 0), at + Vector2(0, side), at + Vector2(-side, 0)])
		if i < _rank:
			draw_colored_polygon(diamond, light)
		else:
			diamond.append(diamond[0])
			draw_polyline(diamond, Color(light, 0.45) if _rank > 0 else dark.lightened(0.25), maxf(side * 0.3, 1.0), true)
