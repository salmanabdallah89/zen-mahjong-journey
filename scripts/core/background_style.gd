class_name BackgroundStyle
extends RefCounted
## How strongly each level background is shaded so the tiles stay the focus
## while the garden stays beautiful. Tuned from measurements of the art behind
## the board (mean brightness 0-255 / edge density):
##   golden sakura 114 / 27.4, bamboo forest 107 / 27.3 (bright and busy),
##   misty temple 113 / 22.7 (bright, calmer), moonlight sanctuary 83 / 23.8
##   (already dark: barely touched).
## "scenery" multiplies the whole background (1.0 = untouched); "board" is the
## strength of the soft pool of shade right behind the tiles. Both are plain
## colour multiplies on existing nodes: no extra textures or passes.

const STYLES := {
	"bg_golden_sakura": {"scenery": 0.86, "board": 0.68},
	"bg_bamboo_forest": {"scenery": 0.86, "board": 0.68},
	"bg_misty_temple": {"scenery": 0.9, "board": 0.62},
	"bg_moonlight_sanctuary": {"scenery": 0.97, "board": 0.48},
}
const DEFAULT := {"scenery": 0.92, "board": 0.58}


## Colour to multiply the level background with (a touch cooler when dimmed,
## so dimming reads as evening light rather than grey).
static func scenery_tint(background: String) -> Color:
	var v := float(_style(background)["scenery"])
	return Color(v, v, minf(v + 0.02, 1.0))


## Strength (centre alpha) of the shade pool behind the board.
static func board_shade(background: String) -> float:
	return float(_style(background)["board"])


static func _style(background: String) -> Dictionary:
	return STYLES.get(background, DEFAULT)
