class_name WordSkin
extends TileSkin
## The look of a Word Garden board: Zen Garden porcelain tiles. Word tiles show
## the word in the language being learned; their partner shows its picture, or
## for words without one, the translation in the player's own language.
## Keyed by face, so shuffles and undo keep the look.

const BODY_COLLECTION := "zen_garden"

var _language := ""
var _native := ""


static func for_words(words: PackedStringArray, language: String, native: String) -> WordSkin:
	var zen := TileCollectionManager.get_collection(BODY_COLLECTION)
	var skin := WordSkin.new()
	skin.collection_id = BODY_COLLECTION
	skin.kind = "symbols"
	skin.style = zen.style(TileArtSet.active())
	skin.body = load(zen.body_path)
	skin.symbol_padding = zen.symbol_padding
	skin.set_languages(language, native)
	for word_id in words:
		if WordCatalog.has_picture(word_id):
			skin._textures[word_id] = WordCatalog.picture(word_id, load)
	return skin


func set_languages(language: String, native: String) -> void:
	_language = language
	_native = native


func symbol_texture(face_id: String) -> Texture2D:
	return _textures.get(WordCatalog.id_of(face_id)) if WordCatalog.is_picture(face_id) else null


func word_text(face_id: String) -> String:
	var word_id := WordCatalog.id_of(face_id)
	if not WordCatalog.is_picture(face_id):
		return WordCatalog.text(word_id, _language)
	return "" if WordCatalog.has_picture(word_id) else WordCatalog.text(word_id, _native)
