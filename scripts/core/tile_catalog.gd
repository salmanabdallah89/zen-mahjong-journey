class_name TileCatalog
extends RefCounted
## The rules side of tile faces: every face ID, its suit and its match group.
## Face IDs are suit_rank strings (e.g. "bamboo_3", "winds_east"). Artwork is
## not described here. TileArtSet maps face IDs to images.

## Suits whose tiles match any other tile of the same suit (not just copies).
const GROUP_MATCH_SUITS: PackedStringArray = ["flowers", "seasons"]

const SUIT_FACES := {
	"bamboo": ["bamboo_1", "bamboo_2", "bamboo_3", "bamboo_4", "bamboo_5",
		"bamboo_6", "bamboo_7", "bamboo_8", "bamboo_9"],
	"dots": ["dots_1", "dots_2", "dots_3", "dots_4", "dots_5",
		"dots_6", "dots_7", "dots_8", "dots_9"],
	"characters": ["characters_1", "characters_2", "characters_3", "characters_4",
		"characters_5", "characters_6", "characters_7", "characters_8", "characters_9"],
	"winds": ["winds_east", "winds_south", "winds_west", "winds_north"],
	"dragons": ["dragons_red", "dragons_green", "dragons_white"],
	"flowers": ["flowers_plum", "flowers_orchid", "flowers_chrysanthemum", "flowers_bamboo"],
	"seasons": ["seasons_spring", "seasons_summer", "seasons_autumn", "seasons_winter"],
}


static func all_faces() -> PackedStringArray:
	var result := PackedStringArray()
	for suit: String in SUIT_FACES:
		for face: String in SUIT_FACES[suit]:
			result.append(face)
	return result


static func is_known_face(face_id: String) -> bool:
	return SUIT_FACES.has(suit_of(face_id)) and (SUIT_FACES[suit_of(face_id)] as Array).has(face_id)


static func suit_of(face_id: String) -> String:
	return face_id.get_slice("_", 0)


## Two faces match when their match groups are equal.
static func match_group(face_id: String) -> String:
	var suit := suit_of(face_id)
	return suit if GROUP_MATCH_SUITS.has(suit) else face_id


static func faces_match(a: String, b: String) -> bool:
	return match_group(a) == match_group(b)


static func faces_for_suits(suits: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for suit in suits:
		if not SUIT_FACES.has(suit):
			push_error("TileCatalog: unknown suit '%s'" % suit)
			continue
		for face: String in SUIT_FACES[suit]:
			result.append(face)
	return result
