class_name TileSkin
extends RefCounted
## How one particular board looks under one collection: the image for every
## face ID on it, plus the shared body image for symbol collections. Built
## once per board and never changes while the board is shown, so a tile's
## art is stable. Keyed by match group, so shuffles and undo keep the look.
## Built only when every image it needs loads, so a skin never shows a
## missing texture.

var collection_id: String = ""
## Tile geometry this skin's images are drawn for (Classic style or the
## collection's own body style). BoardView lays the board out with it.
var style: TileArtSet
## "tile_set" (full tile images) or "symbols" (symbol on a body).
var kind: String = "tile_set"
var body: Texture2D
var symbol_padding: float = 0.0
## Match group -> Texture2D (symbols) or face ID -> Texture2D (tile_set).
var _textures := {}


class BuildResult extends RefCounted:
	var skin: TileSkin
	var error: String = ""


## `loader` is a Callable(path: String) -> Texture2D, so callers can cache.
static func build(collection: TileCollection, art: TileArtSet, faces: PackedStringArray,
		deal_seed: int, loader: Callable) -> BuildResult:
	var result := BuildResult.new()
	if not collection.is_complete(art):
		result.error = "%s artwork is incomplete" % collection.display_name
		return result
	var skin := TileSkin.new()
	skin.collection_id = collection.id
	skin.kind = collection.kind
	skin.style = collection.style(art)
	if collection.kind == "tile_set":
		for face in faces:
			if skin._textures.has(face):
				continue
			var texture: Texture2D = loader.call(art.face_path(face))
			if texture == null:
				result.error = "missing tile image for %s" % face
				return result
			skin._textures[face] = texture
		result.skin = skin
		return result

	var assignment := collection.assign_symbols(faces, deal_seed)
	var groups_needed := TileCatalog.groups_in(faces).size()
	if assignment.is_empty() and groups_needed > 0:
		result.error = "%s has %d symbols, this board needs %d" % [
			collection.display_name, collection.max_groups(), groups_needed]
		return result
	skin.body = loader.call(collection.body_path)
	skin.symbol_padding = collection.symbol_padding
	if skin.body == null:
		result.error = "missing tile body"
		return result
	for group: String in assignment:
		var texture: Texture2D = loader.call(collection.symbol_paths[int(assignment[group])])
		if texture == null:
			result.error = "missing symbol for %s" % group
			return result
		if collection.symbol_region.has_area():
			var shown := AtlasTexture.new()
			shown.atlas = texture
			shown.region = collection.symbol_region
			texture = shown
		skin._textures[group] = texture
	result.skin = skin
	return result


## Full tile image (tile_set) or the tile body (symbols).
func tile_texture(face_id: String) -> Texture2D:
	return _textures.get(face_id) if kind == "tile_set" else body


## The symbol drawn on the body, or null for tile_set collections.
func symbol_texture(face_id: String) -> Texture2D:
	return null if kind == "tile_set" else _textures.get(TileCatalog.match_group(face_id))


## Image identity per match group, for checking that no two groups look alike.
func visual_key(face_id: String) -> String:
	var texture := symbol_texture(face_id) if kind == "symbols" else tile_texture(face_id)
	if texture is AtlasTexture:
		texture = (texture as AtlasTexture).atlas
	return texture.resource_path if texture else ""
