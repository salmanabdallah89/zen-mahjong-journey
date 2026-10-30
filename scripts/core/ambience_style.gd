class_name AmbienceStyle
extends RefCounted
## The living layer each garden gets on top of its painting (GardenAmbience):
## falling petals or leaves, glowing motes or fireflies, warm light rays from
## the painting's light source and slow mist. Counts stay small so older
## phones and the web build keep a steady frame rate.
##
## Keys: "petals" (count), "petal_tint", "motes" (count), "mote_tint",
## "rays" (strength 0..1), "ray_tint", "ray_side" (-1 = light from the upper
## left, 1 = upper right), "mist" (strength 0..1), "mist_tint".

## Upper bound for petals + motes on one screen (tested).
const MAX_PARTICLES := 48

const STYLES := {
	"bg_golden_sakura": {"petals": 16, "petal_tint": "#FFFFFF", "motes": 14, "mote_tint": "#FFE2A0",
		"rays": 0.2, "ray_tint": "#FFE4B0", "ray_side": -1, "mist": 0.0, "mist_tint": "#FFF1DE"},
	"bg_sakura_garden": {"petals": 16, "petal_tint": "#FFFFFF", "motes": 12, "mote_tint": "#FFE2A0",
		"rays": 0.18, "ray_tint": "#FFE4B0", "ray_side": -1, "mist": 0.0, "mist_tint": "#FFF1DE"},
	"bg_bamboo_forest": {"petals": 7, "petal_tint": "#C9E39A", "motes": 22, "mote_tint": "#EAF7A6",
		"rays": 0.22, "ray_tint": "#F4F2B8", "ray_side": 1, "mist": 0.1, "mist_tint": "#E6F2DA"},
	"bg_misty_temple": {"petals": 8, "petal_tint": "#F4A27E", "motes": 10, "mote_tint": "#FFD6BF",
		"rays": 0.16, "ray_tint": "#FFD9B8", "ray_side": -1, "mist": 0.24, "mist_tint": "#F6E4EE"},
	"bg_moonlight_sanctuary": {"petals": 0, "petal_tint": "#FFFFFF", "motes": 26, "mote_tint": "#FFE7A3",
		"rays": 0.12, "ray_tint": "#C4D6FF", "ray_side": 1, "mist": 0.12, "mist_tint": "#A9BCE3"},
}
const DEFAULT := {"petals": 10, "petal_tint": "#FFFFFF", "motes": 12, "mote_tint": "#FFE2A0",
	"rays": 0.15, "ray_tint": "#FFE4B0", "ray_side": -1, "mist": 0.0, "mist_tint": "#FFF1DE"}


static func of(background: String) -> Dictionary:
	return STYLES.get(background, DEFAULT)


static func petals(background: String) -> int:
	return int(of(background)["petals"])


static func motes(background: String) -> int:
	return int(of(background)["motes"])


static func rays(background: String) -> float:
	return float(of(background)["rays"])


static func mist(background: String) -> float:
	return float(of(background)["mist"])


static func ray_side(background: String) -> int:
	return int(of(background)["ray_side"])


## Colour of "petal_tint", "mote_tint", "ray_tint" or "mist_tint".
static func tint(background: String, key: String) -> Color:
	return Color(str(of(background)[key]))
