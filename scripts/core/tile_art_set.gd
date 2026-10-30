class_name TileArtSet
extends RefCounted
## One complete collection of tile artwork, described by a JSON manifest in
## data/tile_art/ (format: docs/TILE_ART_SPEC.md). Every visual fact about
## tiles comes from here: the PNG used for each face ID, the image size, where
## the tile body and top face sit inside the image, how tightly tiles pack and
## how far each layer is raised. Gameplay code never names a PNG.
##
## The active collection is chosen by the project setting
## "zen_mahjong/tiles/art_set", so a new collection is installed by adding a
## manifest and changing that one setting.

const SETTING := "zen_mahjong/tiles/art_set"
const DEFAULT_MANIFEST := "res://data/tile_art/classic_v1.json"

var id: String = ""
var display_name: String = ""
var manifest_path: String = ""
## Full size of every face image, in pixels.
var image_size := Vector2.ZERO
## The visible tile (top face plus drawn edge) inside the image.
var body_rect := Rect2()
## The flat top face inside the image. Also the tap area.
var face_rect := Rect2()
## How much neighbouring tiles overlap, so their edges tuck under each other.
var grid_overlap := Vector2.ZERO
## Drawing offset added per layer; negative values raise tiles up-left.
var layer_shift := Vector2.ZERO
## False for body-only styles used by symbol collections (no face images).
var has_faces := true
## Full tile image (same frame as the body) for face-down tiles; empty: the
## board crops a garden's tile back instead.
var mystery_back := ""

var _face_folder: String = ""
var _face_pattern: String = ""
var _face_overrides: Dictionary = {}
var _unverified: Dictionary = {}
var _back_folder: String = ""
var _back_pattern: String = ""
var _backs: PackedStringArray = PackedStringArray()

static var _active: TileArtSet
static var _loaded := {}


## The collection selected in project settings, loaded once.
static func active() -> TileArtSet:
	if _active == null:
		_active = load_manifest(str(ProjectSettings.get_setting(SETTING, DEFAULT_MANIFEST)))
	return _active


## A style loaded once per manifest path (used by symbol collections).
static func cached(path: String) -> TileArtSet:
	if not _loaded.has(path):
		_loaded[path] = load_manifest(path) if FileAccess.file_exists(path) else null
	return _loaded[path]


## Replaces the active collection (used by tests and tools).
static func set_active(art: TileArtSet) -> void:
	_active = art


static func load_manifest(path: String) -> TileArtSet:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("TileArtSet: cannot parse manifest '%s'" % path)
		return null
	var art := from_dict(data)
	art.manifest_path = path
	return art


static func from_dict(data: Dictionary) -> TileArtSet:
	var art := TileArtSet.new()
	art.id = str(data.get("id", ""))
	art.display_name = str(data.get("name", art.id))
	art.image_size = _vec2(data.get("image_size", [0, 0]))
	art.face_rect = _rect(data.get("face_rect", [0, 0, 0, 0]))
	art.body_rect = _rect(data.get("body_rect", data.get("face_rect", [0, 0, 0, 0])))
	art.grid_overlap = _vec2(data.get("grid_overlap", [0, 0]))
	art.layer_shift = _vec2(data.get("layer_shift", [0, 0]))
	art.has_faces = bool(data.get("has_faces", true))
	art.mystery_back = str(data.get("mystery_back", ""))
	art._face_folder = str(data.get("face_folder", ""))
	art._face_pattern = str(data.get("face_file_pattern", "tile_{face}.png"))
	art._face_overrides = data.get("face_overrides", {})
	for face: String in data.get("unverified_faces", []):
		art._unverified[face] = true
	art._back_folder = str(data.get("back_folder", ""))
	art._back_pattern = str(data.get("back_file_pattern", "tile_back_{style}.png"))
	art._backs = PackedStringArray(data.get("backs", []))
	return art


func face_path(face_id: String) -> String:
	var file := str(_face_overrides.get(face_id, _face_pattern.replace("{face}", face_id)))
	return file if file.begins_with("res://") else _face_folder.path_join(file)


func face_texture(face_id: String) -> Texture2D:
	return load(face_path(face_id))


func back_styles() -> PackedStringArray:
	return _backs


func back_path(style: String) -> String:
	return _back_folder.path_join(_back_pattern.replace("{style}", style))


## False for faces whose artwork is known to be wrong. Such faces are kept off
## generated boards until corrected art is installed.
func is_verified(face_id: String) -> bool:
	return not _unverified.has(face_id)


## Distance between half-tile grid steps, in image pixels.
func half_step() -> Vector2:
	return (face_rect.size - grid_overlap) / 2.0


## Problems that would stop this collection working; empty when it is usable.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if image_size.x <= 0 or image_size.y <= 0:
		errors.append("image_size must be positive")
	var bounds := Rect2(Vector2.ZERO, image_size)
	if not bounds.encloses(body_rect):
		errors.append("body_rect %s lies outside the image" % body_rect)
	if not body_rect.encloses(face_rect) or face_rect.size.x <= 0 or face_rect.size.y <= 0:
		errors.append("face_rect %s must be non-empty and inside body_rect" % face_rect)
	if not has_faces:
		return errors
	for face in TileCatalog.all_faces():
		var path := face_path(face)
		if not ResourceLoader.exists(path):
			errors.append("missing art for %s (%s)" % [face, path])
			continue
		var texture: Texture2D = load(path)
		if Vector2(texture.get_size()) != image_size:
			errors.append("%s is %s, manifest says %s" % [path, texture.get_size(), image_size])
	for face: String in _unverified:
		if not TileCatalog.is_known_face(face):
			errors.append("unverified_faces lists unknown face '%s'" % face)
	for style in _backs:
		if not ResourceLoader.exists(back_path(style)):
			errors.append("missing back art '%s'" % back_path(style))
	return errors


static func _vec2(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))


static func _rect(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
