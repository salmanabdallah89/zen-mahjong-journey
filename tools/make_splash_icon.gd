extends SceneTree
## Builds assets/branding/splash_icon_1152.png, the icon on Android's launch
## screen, from the full-size icon art (app_icon_concept.png, left untouched).
## Android 12+ shows it 288 dp wide and masks it to a 192 dp circle in the
## middle, so 1152 px stays sharp up to xxxhdpi tablets. The art is cut as a
## circle around the lotus tile; the rest is transparent over the forest
## background set in the export preset.
##   godot --headless --path . -s res://tools/make_splash_icon.gd

const SOURCE := "res://assets/branding/app_icon_concept.png"
const TARGET := "res://assets/branding/splash_icon_1152.png"
const SIZE := 1152
## Diameter of the art circle: a little over Android's 2/3 mask, so no
## transparent rim shows inside it.
const ART := 800
## Centre and diameter of the circle taken from the source (around the tile).
const SOURCE_CENTER := Vector2i(650, 735)
const SOURCE_DIAMETER := 1000


func _init() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	source.convert(Image.FORMAT_RGBA8)
	var half := SOURCE_DIAMETER / 2
	var art := source.get_region(Rect2i(SOURCE_CENTER - Vector2i(half, half), Vector2i(SOURCE_DIAMETER, SOURCE_DIAMETER)))
	art.resize(ART, ART, Image.INTERPOLATE_LANCZOS)
	var icon := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var offset := (SIZE - ART) / 2
	var radius := ART / 2.0
	for y in ART:
		for x in ART:
			var distance := Vector2(x + 0.5 - radius, y + 0.5 - radius).length()
			# One pixel of soft edge.
			var alpha := clampf(radius - distance, 0.0, 1.0)
			if alpha > 0.0:
				var colour := art.get_pixel(x, y)
				colour.a *= alpha
				icon.set_pixel(x + offset, y + offset, colour)
	var error := icon.save_png(ProjectSettings.globalize_path(TARGET))
	print("splash icon: %s (%s)" % [TARGET, error_string(error)])
	quit(0 if error == OK else 1)
