class_name AudioCatalog
extends RefCounted
## Every sound the game can play, by id, with its file and bus. The checklist
## in docs/AUDIO_ASSETS.md lists the same files. Missing files are allowed:
## AudioManager skips them silently.

const MUSIC := {
	"main_menu": "res://assets/audio/music/music_main_menu.ogg",
	"gameplay": "res://assets/audio/music/music_gameplay.ogg",
}

const AMBIENCE := {
	"waterfall": "res://assets/audio/ambient/ambient_waterfall.ogg",
	"birds": "res://assets/audio/ambient/ambient_birds.ogg",
	"wind": "res://assets/audio/ambient/ambient_wind.ogg",
}

## id -> [file, bus, pitch variation (+/- share), minimum gap between plays (s)]
const EFFECTS := {
	"tile_select": ["res://assets/audio/sfx/sfx_tile_select.wav", "SFX", 0.04, 0.05],
	"tile_match": ["res://assets/audio/sfx/sfx_tile_match.wav", "SFX", 0.06, 0.08],
	"tile_blocked": ["res://assets/audio/sfx/sfx_tile_blocked.wav", "SFX", 0.03, 0.12],
	"hint": ["res://assets/audio/sfx/sfx_hint.wav", "SFX", 0.0, 0.25],
	"shuffle": ["res://assets/audio/sfx/sfx_shuffle.wav", "SFX", 0.0, 0.25],
	"undo": ["res://assets/audio/sfx/sfx_undo.wav", "SFX", 0.0, 0.1],
	"level_complete": ["res://assets/audio/sfx/sfx_level_complete.wav", "SFX", 0.0, 1.0],
	"reward": ["res://assets/audio/sfx/sfx_reward.wav", "SFX", 0.0, 0.3],
	"unlock": ["res://assets/audio/sfx/sfx_unlock.wav", "SFX", 0.0, 0.5],
	"button_click": ["res://assets/audio/sfx/sfx_button_click.wav", "UI", 0.03, 0.04],
}

## Ambience mix per level background: id -> relative level (0..1).
const AMBIENCE_FOR_BACKGROUND := {
	"bg_golden_sakura": {"waterfall": 0.7, "birds": 0.6, "wind": 0.2},
	"bg_sakura_garden": {"waterfall": 0.7, "birds": 0.6, "wind": 0.2},
	"bg_bamboo_forest": {"waterfall": 0.4, "birds": 0.8, "wind": 0.5},
	"bg_misty_temple": {"waterfall": 0.9, "birds": 0.3, "wind": 0.4},
	"bg_moonlight_sanctuary": {"waterfall": 0.5, "birds": 0.0, "wind": 0.7},
}
const MENU_AMBIENCE := {"waterfall": 0.6, "birds": 0.5, "wind": 0.15}


static func effect_path(effect_id: String) -> String:
	return str((EFFECTS[effect_id] as Array)[0]) if EFFECTS.has(effect_id) else ""


static func all_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for path: String in MUSIC.values():
		paths.append(path)
	for path: String in AMBIENCE.values():
		paths.append(path)
	for entry: Array in EFFECTS.values():
		paths.append(str(entry[0]))
	return paths
