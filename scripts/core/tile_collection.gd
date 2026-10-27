class_name TileCollection
extends RefCounted
## One player-selectable tile collection, loaded from a manifest in
## data/collections/ (format: docs/TILE_COLLECTIONS.md). A collection only
## decides what tiles LOOK like; matching rules, deals and solvability never
## depend on it.
##
## Two kinds:
##  - "tile_set": complete tile images per face ID, taken from the active
##    TileArtSet (the Classic collection).
##  - "symbols": a list of symbol images drawn onto a shared blank tile body.
##    Each match group on a board is given one symbol by `assignment`:
##      "fixed"         group N of TileCatalog.all_match_groups() gets symbol N
##      "board_ordered" groups present on the board, in canonical order, get
##                      symbols in list order (fits small sets such as A-Z)
##      "board_seeded"  like board_ordered, but the symbol list is first
##                      shuffled with a seed made from the level's deal seed and
##                      the collection id + version (used by Mixed)

const KINDS: PackedStringArray = ["tile_set", "symbols"]
const ASSIGNMENTS: PackedStringArray = ["fixed", "board_ordered", "board_seeded"]
## Two symbols whose shown pictures differ by less than this (mean per-channel
## difference of 16 px wide thumbnails, 0..1) count as the same picture. In
## the premium pack every same-drawing pair measured 0.000, while the closest
## genuinely different pair (letters I and T) measured 0.021. This catches
## reused drawings; pictures that differ only by colour still need a person.
const LOOKALIKE_THRESHOLD := 0.008
const THUMB_SIZE := 16

var id: String = ""
var display_name: String = ""
var description: String = ""
var version: int = 1
var order: int = 0
var kind: String = "symbols"
var assignment: String = "fixed"
var manifest_path: String = ""
var thumbnail_path: String = ""
var body_path: String = ""
## Tile style manifest whose geometry matches `body_path` (symbols only).
## Empty means the active TileArtSet.
var tile_style_path: String = ""
## Part of each symbol image to show, e.g. to leave out a baked-in caption.
## Zero size means the whole image.
var symbol_region := Rect2()
## Share of the face area left empty around a symbol, per side.
var symbol_padding: float = 0.14
## Ordered symbol ids and their image paths ("symbols" kind only).
var symbol_ids: PackedStringArray = PackedStringArray()
var symbol_paths: PackedStringArray = PackedStringArray()
## Symbols listed in the manifest but left out (e.g. waiting for corrected
## art). They are not shown, validated or assigned.
var held_back: PackedStringArray = PackedStringArray()

var _errors: PackedStringArray = PackedStringArray()
var _validated := false


static func load_manifest(path: String) -> TileCollection:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("TileCollection: cannot parse '%s'" % path)
		return null
	var collection := from_dict(data)
	collection.manifest_path = path
	return collection


static func from_dict(data: Dictionary) -> TileCollection:
	var c := TileCollection.new()
	c.id = str(data.get("id", ""))
	c.display_name = str(data.get("name", c.id))
	c.description = str(data.get("description", ""))
	c.version = int(data.get("version", 1))
	c.order = int(data.get("order", 100))
	c.kind = str(data.get("kind", "symbols"))
	c.assignment = str(data.get("assignment", "fixed"))
	c.thumbnail_path = str(data.get("thumbnail", ""))
	c.body_path = str(data.get("body", ""))
	c.symbol_padding = float(data.get("symbol_padding", 0.14))
	c.tile_style_path = str(data.get("tile_style", ""))
	var region: Array = data.get("symbol_region", [0, 0, 0, 0])
	c.symbol_region = Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3]))
	c.held_back = PackedStringArray(data.get("held_back_symbols", []))
	for entry: Variant in data.get("symbols", []):
		if entry is Dictionary:
			var symbol_id := str((entry as Dictionary).get("id", ""))
			if c.held_back.has(symbol_id):
				continue
			c.symbol_ids.append(symbol_id)
			c.symbol_paths.append(str((entry as Dictionary).get("file", "")))
	return c


func symbol_count() -> int:
	return TileCatalog.all_match_groups().size() if kind == "tile_set" else symbol_ids.size()


## The most distinct match groups one board may contain for this collection.
func max_groups() -> int:
	if kind == "tile_set":
		return TileCatalog.all_match_groups().size()
	if assignment == "fixed":
		return mini(symbol_ids.size(), TileCatalog.all_match_groups().size())
	return symbol_ids.size()


## The tile style (geometry) this collection is drawn with.
func style(art: TileArtSet) -> TileArtSet:
	if kind == "tile_set" or tile_style_path.is_empty():
		return art
	return TileArtSet.cached(tile_style_path)


## True when every file the manifest names exists (it may still be invalid).
func has_all_files() -> bool:
	if kind == "tile_set":
		return true
	return missing_symbol_count() == 0 and ResourceLoader.exists(body_path)


## Problems found in the manifest or its files. Empty means every image the
## collection can show exists and is usable. Result is cached.
func validate(art: TileArtSet) -> PackedStringArray:
	if _validated:
		return _errors
	_validated = true
	if id.is_empty():
		_errors.append("manifest has no id")
	if not KINDS.has(kind):
		_errors.append("unknown kind '%s'" % kind)
	if kind == "tile_set":
		for error in art.validate():
			_errors.append(error)
		return _errors
	if not ASSIGNMENTS.has(assignment):
		_errors.append("unknown assignment '%s'" % assignment)
	if symbol_ids.is_empty():
		_errors.append("no symbols listed")
	var tile_style := style(art)
	if tile_style == null:
		_errors.append("missing tile style %s" % tile_style_path)
	elif not ResourceLoader.exists(body_path):
		_errors.append("missing tile body %s" % body_path)
	else:
		var body: Texture2D = load(body_path)
		if Vector2(body.get_size()) != tile_style.image_size:
			_errors.append("tile body is %s, tile style needs %s" % [body.get_size(), tile_style.image_size])
	var seen_ids := {}
	var seen_files := {}
	for i in symbol_ids.size():
		var sid := symbol_ids[i]
		var file := symbol_paths[i]
		if sid.is_empty() or seen_ids.has(sid):
			_errors.append("symbol id '%s' is empty or repeated" % sid)
		if seen_files.has(file):
			_errors.append("%s is used by both '%s' and '%s'" % [file, seen_files[file], sid])
		seen_ids[sid] = true
		seen_files[file] = sid
		if not ResourceLoader.exists(file):
			_errors.append("missing symbol '%s' (%s)" % [sid, file])
	if _errors.is_empty():
		_check_distinct_pictures()
	return _errors


## Different files can still hold the same picture: identical bytes, or the
## same drawing with only a caption changed. Compares the part that is shown.
func _check_distinct_pictures() -> void:
	var seen := {}
	var thumbs: Array[PackedByteArray] = []
	for i in symbol_paths.size():
		var image := (load(symbol_paths[i]) as Texture2D).get_image()
		if image.is_compressed():
			image.decompress()
		var key := hash(image.get_data())
		if seen.has(key):
			_errors.append("symbol '%s' is the same picture as '%s'" % [symbol_ids[i], seen[key]])
		seen[key] = symbol_ids[i]
		if image.detect_alpha() == Image.ALPHA_NONE:
			_errors.append("symbol '%s' has no transparent background" % symbol_ids[i])
		var region := Rect2i(symbol_region) if symbol_region.has_area() else Rect2i(Vector2i.ZERO, image.get_size())
		if not Rect2i(Vector2i.ZERO, image.get_size()).encloses(region):
			_errors.append("symbol_region %s is outside '%s' (%s)" % [region, symbol_ids[i], image.get_size()])
			thumbs.append(PackedByteArray())
			continue
		thumbs.append(_thumbnail(image.get_region(region)))
	for a in thumbs.size():
		for b in range(a + 1, thumbs.size()):
			if thumbs[a].is_empty() or thumbs[b].is_empty():
				continue
			var difference := _difference(thumbs[a], thumbs[b])
			if difference < LOOKALIKE_THRESHOLD:
				_errors.append("symbols '%s' and '%s' look the same (difference %.3f)" % [
					symbol_ids[a], symbol_ids[b], difference])


## Small alpha-premultiplied RGBA copy used for look-alike comparison.
static func _thumbnail(image: Image) -> PackedByteArray:
	var copy := image.duplicate() as Image
	copy.convert(Image.FORMAT_RGBA8)
	var height := maxi(1, roundi(THUMB_SIZE * float(copy.get_height()) / copy.get_width()))
	copy.resize(THUMB_SIZE, height, Image.INTERPOLATE_BILINEAR)
	var data := copy.get_data()
	for i in range(0, data.size(), 4):
		var alpha := data[i + 3]
		for c in 3:
			data[i + c] = int(data[i + c] * alpha / 255.0)
	return data


static func _difference(a: PackedByteArray, b: PackedByteArray) -> float:
	if a.size() != b.size():
		return 1.0
	var total := 0
	for i in a.size():
		total += absi(a[i] - b[i])
	return total / (255.0 * a.size())


func is_complete(art: TileArtSet) -> bool:
	return validate(art).is_empty()


## Count of symbol images that are missing (0 for a complete collection).
func missing_symbol_count() -> int:
	var missing := 0
	for file in symbol_paths:
		if not ResourceLoader.exists(file):
			missing += 1
	return missing


## Maps each match group present in `faces` to the symbol index it shows.
## Returns an empty Dictionary when the board needs more symbols than exist.
func assign_symbols(faces: PackedStringArray, deal_seed: int) -> Dictionary:
	var groups := TileCatalog.groups_in(faces)
	if groups.size() > max_groups():
		return {}
	var result := {}
	match assignment:
		"fixed":
			# Group N keeps symbol N. With fewer symbols than groups, a group past
			# the end takes the lowest symbol this board doesn't use, so the
			# mapping stays deterministic for the board.
			var canonical := TileCatalog.all_match_groups()
			var used := {}
			var overflow := PackedStringArray()
			for group in groups:
				var index := canonical.find(group)
				if index < symbol_ids.size():
					result[group] = index
					used[index] = true
				else:
					overflow.append(group)
			var spare := 0
			for group in overflow:
				while used.has(spare):
					spare += 1
				result[group] = spare
				used[spare] = true
		"board_ordered":
			for k in groups.size():
				result[groups[k]] = k
		"board_seeded":
			var indices := range(symbol_ids.size())
			var rng := RandomNumberGenerator.new()
			rng.seed = deal_seed * 1000003 + _stable_hash("%s#%d" % [id, version])
			for i in range(indices.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var tmp: int = indices[i]
				indices[i] = indices[j]
				indices[j] = tmp
			for k in groups.size():
				result[groups[k]] = indices[k]
	return result


## FNV-1a over UTF-8 bytes: identical on every platform and engine build.
static func _stable_hash(text: String) -> int:
	var h := 2166136261
	for byte in text.to_utf8_buffer():
		h = ((h ^ byte) * 16777619) & 0xFFFFFFFF
	return h
