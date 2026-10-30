extends Node
## Autoload "TileCollectionManager": finds the tile collections, remembers the
## player's choice in user settings, builds the TileSkin for each board, caches
## textures for the collection in use, and tells screens when the choice
## changes. Falls back to Classic whenever a collection can't be shown in full.

signal collection_changed(collection_id: String)

const SETTINGS_SECTION := "tiles"
const SETTINGS_KEY := "collection"
## True once the player has picked a collection themself.
const SETTINGS_KEY_CHOSEN := "collection_chosen"
## The look everyone has until they pick another one.
const DEFAULT_ID := "zen_garden"

var settings_path := UserSettings.DEFAULT_PATH
var library: TileCollectionLibrary
## The player's choice (may be unavailable on a particular board).
var selected_id := TileCollectionLibrary.FALLBACK_ID
## Explanation of the last fallback, for screens to show; cleared when read.
var notice := ""

var _textures := {}


func _ready() -> void:
	reload_library(PackedStringArray([TileCollectionLibrary.SHIPPED_DIR]))
	restore()


func reload_library(dirs: PackedStringArray) -> void:
	library = TileCollectionLibrary.discover(dirs)
	_textures.clear()


func collections() -> Array[TileCollection]:
	return library.all()


func get_collection(collection_id: String) -> TileCollection:
	return library.get_collection(collection_id)


## True when every image of the collection exists and is valid.
func is_available(collection_id: String) -> bool:
	var collection := library.get_collection(collection_id)
	return collection != null and collection.is_complete(TileArtSet.active())


## Makes a collection the player's choice. Returns false (and sets `notice`)
## if it is unknown or its artwork is incomplete; the choice is then unchanged.
func select(collection_id: String) -> bool:
	if not is_available(collection_id):
		var collection := library.get_collection(collection_id)
		var label := collection.display_name if collection else collection_id
		if collection and collection.has_all_files():
			notice = "%s artwork needs fixes before it can be used." % label
		else:
			notice = "%s artwork isn't installed yet." % label
		return false
	var settings := UserSettings.new(settings_path)
	settings.set_value(SETTINGS_SECTION, SETTINGS_KEY_CHOSEN, true)
	if collection_id == selected_id:
		settings.set_value(SETTINGS_SECTION, SETTINGS_KEY, selected_id)
		return true
	selected_id = collection_id
	_textures.clear()
	settings.set_value(SETTINGS_SECTION, SETTINGS_KEY, selected_id)
	collection_changed.emit(selected_id)
	return true


## Loads the saved choice. An unknown or incomplete saved collection falls
## back to Classic (the saved value is kept, so it returns once art exists).
## Without a choice of their own, players are on the default; that includes a
## saved Classic with no "chosen" mark, which older versions saved by themselves.
func restore() -> void:
	var settings := UserSettings.new(settings_path)
	var saved := str(settings.get_value(SETTINGS_SECTION, SETTINGS_KEY, ""))
	var chosen := bool(settings.get_value(SETTINGS_SECTION, SETTINGS_KEY_CHOSEN, false))
	var unchosen_classic := saved == TileCollectionLibrary.FALLBACK_ID and not chosen
	if (saved.is_empty() or unchosen_classic) and is_available(DEFAULT_ID):
		saved = DEFAULT_ID
	elif saved.is_empty():
		saved = TileCollectionLibrary.FALLBACK_ID
	if is_available(saved):
		selected_id = saved
	else:
		selected_id = TileCollectionLibrary.FALLBACK_ID
		if saved != TileCollectionLibrary.FALLBACK_ID:
			notice = "Your tile collection isn't available, so Classic is shown."
	_textures.clear()


## The skin for a board whose full face list is `faces` (removed tiles
## included). Uses the selected collection, or Classic when that collection
## can't cover this board, and always returns a complete skin.
func skin_for_board(faces: PackedStringArray, deal_seed: int) -> TileSkin:
	var art := TileArtSet.active()
	var chosen := library.get_collection(selected_id)
	if chosen:
		var built := TileSkin.build(chosen, art, faces, deal_seed, _texture)
		if built.skin:
			return built.skin
		notice = "%s, so Classic is shown for this board." % built.error
	var fallback := TileSkin.build(library.get_collection(TileCollectionLibrary.FALLBACK_ID),
		art, faces, deal_seed, _texture)
	assert(fallback.skin != null, "Classic tile collection must always be complete")
	return fallback.skin


## Returns and clears the pending notice.
func take_notice() -> String:
	var text := notice
	notice = ""
	return text


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		if not ResourceLoader.exists(path):
			return null
		_textures[path] = load(path)
	return _textures[path]
