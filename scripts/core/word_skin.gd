class_name WordSkin
extends TileSkin
## The look of a Word Garden board: Zen Garden porcelain tiles, picture tiles
## showing the word's image and word tiles showing its text in the language
## being learned. Keyed by face, so shuffles and undo keep the look.

const BODY_COLLECTION := "zen_garden"

var _language := ""


static func for_words(words: PackedStringArray, language: String) -> WordSkin:
	var zen := TileCollectionManager.get_collection(BODY_COLLECTION)
	var skin := WordSkin.new()
	skin.collection_id = BODY_COLLECTION
	skin.kind = "symbols"
	skin.style = zen.style(TileArtSet.active())
	skin.body = load(zen.body_path)
	skin.symbol_padding = zen.symbol_padding
	skin._language = language
	for word_id in words:
		skin._textures[word_id] = WordCatalog.picture(word_id, load)
	return skin


func symbol_texture(face_id: String) -> Texture2D:
	return _textures.get(WordCatalog.id_of(face_id)) if WordCatalog.is_picture(face_id) else null


func word_text(face_id: String) -> String:
	return "" if WordCatalog.is_picture(face_id) else WordCatalog.text(WordCatalog.id_of(face_id), _language)
