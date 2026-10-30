extends TestCase
## Tile collections: manifests, validation, symbol assignment and skins.

const FIXTURES := "res://tests/fixtures/collections/"
const SHIPPED_IDS: PackedStringArray = ["zen_garden", "classic", "animals", "fruits", "vegetables", "alphabet", "mixed"]


func _library() -> TileCollectionLibrary:
	return TileCollectionLibrary.discover(PackedStringArray([TileCollectionLibrary.SHIPPED_DIR, FIXTURES]))


func _load(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


func _level_faces(number: int) -> PackedStringArray:
	var level := LevelCatalog.get_level(number)
	return BoardGenerator.generate(level.load_layout().build_geometry(), level.face_pool(), level.deal_seed).faces


func test_every_shipped_collection_loads() -> void:
	var library := TileCollectionLibrary.discover()
	var ids := PackedStringArray()
	for collection in library.all():
		ids.append(collection.id)
		assert_false(collection.display_name.is_empty(), "%s has a name" % collection.id)
		assert_true(collection.version >= 1, "%s has a version" % collection.id)
		assert_true(TileCollection.KINDS.has(collection.kind), "%s kind is known" % collection.id)
		if collection.kind == "symbols":
			assert_true(TileCollection.ASSIGNMENTS.has(collection.assignment), "%s assignment is known" % collection.id)
			assert_false(collection.thumbnail_path.is_empty(), "%s declares a thumbnail" % collection.id)
		# Structure must be valid; only artwork defects may be reported.
		for error in collection.validate(TileArtSet.active()):
			if not error.contains("look the same"):
				failures.append("%s: %s" % [collection.id, error])
	assert_eq(ids, SHIPPED_IDS, "seven collections in menu order")


func test_symbol_counts_cover_levels() -> void:
	var library := TileCollectionLibrary.discover()
	for collection_id in ["animals", "mixed"]:
		assert_eq(library.get_collection(collection_id).symbol_count(), 36, "%s can cover every match group" % collection_id)
	assert_eq(library.get_collection("vegetables").symbol_count(), 23, "vegetables has 23 while 13 copies are held back")
	assert_eq(library.get_collection("fruits").symbol_count(), 35, "fruits has 35 while plum is held back")
	assert_eq(library.get_collection("alphabet").symbol_count(), 26, "alphabet has A-Z")
	for level in LevelCatalog.levels():
		var needed := TileCatalog.groups_in(_level_faces(level.number)).size()
		assert_true(needed <= 26, "level %d needs %d symbols, within the alphabet's 26" % [level.number, needed])


func test_classic_is_complete_and_maps_every_face() -> void:
	var classic := TileCollectionLibrary.discover().get_collection("classic")
	assert_true(classic.is_complete(TileArtSet.active()), "classic validates: %s" % ", ".join(classic.validate(TileArtSet.active())))
	var built := TileSkin.build(classic, TileArtSet.active(), TileCatalog.all_faces(), 1, _load)
	assert_true(built.skin != null, "classic skins every face")
	for face in TileCatalog.all_faces():
		assert_true(built.skin.tile_texture(face) != null, "classic image for %s" % face)


func test_premium_collections_validated() -> void:
	var library := TileCollectionLibrary.discover()
	for collection_id in ["animals", "alphabet", "mixed", "fruits", "vegetables"]:
		var collection := library.get_collection(collection_id)
		assert_true(collection.is_complete(TileArtSet.active()),
			"%s is enabled: %s" % [collection_id, ", ".join(collection.validate(TileArtSet.active()))])
	# A collection with two files holding the same picture is refused.
	var lookalike := TileCollection.load_manifest(FIXTURES + "test_lookalike.json")
	assert_true(lookalike.has_all_files() and not lookalike.is_complete(TileArtSet.active()), "look-alike fixture is refused")
	assert_true(TileSkin.build(lookalike, TileArtSet.active(), _level_faces(1), 1, _load).skin == null, "look-alike fixture cannot be shown")


func test_reused_drawings_are_detected() -> void:
	# Known defects in the premium pack: the same drawing with only the caption changed.
	var library := TileCollectionLibrary.discover()
	var fruits := library.get_collection("fruits")
	assert_true(fruits.validate(TileArtSet.active()).is_empty(), "fruits: no look-alikes left (batch 1 + plum held back)")
	assert_true(fruits.held_back.has("plum") and not fruits.symbol_ids.has("plum"), "fruits: plum held back until replaced")
	# Plum is still the same picture as fig: held back for a real reason.
	var with_plum := TileCollection.from_dict({"id": "fruits_with_plum", "kind": "symbols",
		"tile_style": fruits.tile_style_path, "body": fruits.body_path, "symbol_region": [52, 28, 154, 152],
		"symbols": [{"id": "fig", "file": fruits.symbol_paths[fruits.symbol_ids.find("fig")]},
			{"id": "plum", "file": "res://assets/collections/fruits/fruit_31_plum.png"}]})
	assert_true(" ".join(with_plum.validate(TileArtSet.active())).contains("look the same"), "fruits: plum still looks like fig")
	var vegetables := library.get_collection("vegetables")
	assert_true(vegetables.validate(TileArtSet.active()).is_empty(), "vegetables: no look-alikes left with 13 copies held back")
	assert_eq(vegetables.held_back.size(), 13, "vegetables: 13 copies held back")
	# The held-back copies really are look-alikes of the symbols that stay.
	var pairs := [["kale", "asparagus"], ["cabbage", "lettuce"], ["leek", "spinach"], ["cauliflower", "broccoli"],
		["zucchini", "cucumber"], ["radish", "chili"], ["red_pepper", "green_pepper"]]
	for pair in pairs:
		var copy := TileCollection.from_dict({"id": "veg_pair", "kind": "symbols", "tile_style": vegetables.tile_style_path,
			"body": vegetables.body_path, "symbol_region": [56, 34, 144, 140], "symbols": [
				{"id": pair[0], "file": "res://assets/collections/vegetables/%s" % _vegetable_file(pair[0])},
				{"id": pair[1], "file": vegetables.symbol_paths[vegetables.symbol_ids.find(pair[1])]}]})
		assert_true(" ".join(copy.validate(TileArtSet.active())).contains("look the same"),
			"vegetables: %s is still the same picture as %s" % pair)


func test_similar_but_different_letters_pass() -> void:
	# Guards the look-alike threshold against false alarms (I/T and B/D are close).
	var alphabet := TileCollectionLibrary.discover().get_collection("alphabet")
	assert_true(alphabet.validate(TileArtSet.active()).is_empty(), "all 26 letters count as distinct")


func test_ivory_body_style_matches_body_art() -> void:
	var style := TileArtSet.load_manifest("res://data/tile_art/ivory_body_v1.json")
	assert_true(style.validate().is_empty(), "body style geometry is valid: %s" % ", ".join(style.validate()))
	var body: Texture2D = load("res://assets/tiles/bodies/tile_body_ivory.png")
	assert_eq(Vector2(body.get_size()), style.image_size, "style size matches the body PNG")
	var animals := TileCollectionLibrary.discover().get_collection("animals")
	assert_eq(animals.style(TileArtSet.active()).id, "ivory_body_v1", "symbol collections draw on the ivory body style")


func test_captions_are_cropped_from_symbols() -> void:
	var library := TileCollectionLibrary.discover()
	var faces := _level_faces(1)
	var animals := TileSkin.build(library.get_collection("animals"), TileArtSet.active(), faces, 1, _load).skin
	var shown := animals.symbol_texture(faces[0])
	assert_true(shown is AtlasTexture, "animal symbols show a region of the PNG")
	if shown is AtlasTexture:
		assert_true((shown as AtlasTexture).region.end.y <= 200.0, "caption below y=200 is left out")
	var letters := TileSkin.build(library.get_collection("alphabet"), TileArtSet.active(), faces, 1, _load).skin
	assert_false(letters.symbol_texture(faces[0]) is AtlasTexture, "letters have no caption and show whole")


func test_flowers_share_one_symbol_in_symbol_collections() -> void:
	var faces := PackedStringArray(["flowers_plum", "flowers_orchid", "flowers_chrysanthemum", "flowers_bamboo",
		"seasons_spring", "seasons_winter", "bamboo_1", "bamboo_1"])
	var skin := TileSkin.build(TileCollectionLibrary.discover().get_collection("animals"), TileArtSet.active(),
		faces, 1, _load).skin
	assert_eq(skin.visual_key("flowers_plum"), skin.visual_key("flowers_bamboo"), "all flowers show the same animal")
	assert_true(skin.visual_key("flowers_plum") != skin.visual_key("seasons_spring"), "flowers and seasons differ")
	assert_true(skin.visual_key("seasons_spring") != skin.visual_key("bamboo_1"), "seasons and bamboo differ")


func test_no_two_match_groups_look_alike() -> void:
	var library := _library()
	for collection_id in ["classic", "animals", "alphabet", "mixed", "fruits", "vegetables", "test_symbols", "test_mixed"]:
		var collection := library.get_collection(collection_id)
		for level in _sample_levels():
			var faces := _level_faces(level.number)
			var skin := TileSkin.build(collection, TileArtSet.active(), faces, level.deal_seed, _load).skin
			assert_true(skin != null, "%s skins level %d" % [collection_id, level.number])
			if skin == null:
				continue
			var owner := {}
			for face in faces:
				var key := skin.visual_key(face)
				var group := TileCatalog.match_group(face)
				assert_false(key.is_empty(), "%s: %s has an image" % [collection_id, face])
				if owner.has(key) and owner[key] != group:
					failures.append("%s level %d: %s and %s share %s" % [collection_id, level.number, owner[key], group, key])
				owner[key] = group


## The hand-made levels plus every 50th generated one: generated levels
## reuse the same layouts and suit sets with new seeds, so a spread sample
## covers them without skinning all 1000 boards in every collection.
func _sample_levels() -> Array[LevelCatalog.LevelDefinition]:
	var sample: Array[LevelCatalog.LevelDefinition] = []
	for level in LevelCatalog.levels():
		if level.number <= 10 or level.number % 50 == 0:
			sample.append(level)
	return sample


func test_fixture_symbol_images_are_distinct() -> void:
	var collection := _library().get_collection("test_symbols")
	var hashes := {}
	for path in collection.symbol_paths:
		var image := (load(path) as Texture2D).get_image()
		var h := hash(image.get_data())
		assert_false(hashes.has(h), "%s looks identical to %s" % [path, hashes.get(h, "")])
		hashes[h] = path


func test_validator_rejects_identical_pictures_under_different_names() -> void:
	# Found in the asset pack: these two files hold the same picture.
	var collection := TileCollection.from_dict({"id": "dupes", "kind": "symbols",
		"body": "res://assets/tiles/backs/tile_back_sage.png", "symbols": [
			{"id": "music", "file": "res://assets/ui/icons/icon_music.png"},
			{"id": "sound_off", "file": "res://assets/ui/icons/icon_sound_off.png"}]})
	var errors := collection.validate(TileArtSet.active())
	assert_true(not errors.is_empty() and errors[0].contains("same picture"), "duplicate picture caught: %s" % ", ".join(errors))


func _vegetable_file(symbol_id: String) -> String:
	for file in DirAccess.get_files_at("res://assets/collections/vegetables/"):
		if file.ends_with("_%s.png" % symbol_id):
			return file
	return ""


func test_fixed_assignment_with_fewer_symbols_than_groups() -> void:
	# 3 symbols, fixed: groups 0-2 keep their own symbol; a later group takes
	# the lowest symbol this board doesn't use. Never an index past the list.
	var short := TileCollection.from_dict({"id": "short", "kind": "symbols", "assignment": "fixed",
		"symbols": [{"id": "a", "file": "x"}, {"id": "b", "file": "y"}, {"id": "c", "file": "z"}]})
	var faces := PackedStringArray(["bamboo_1", "bamboo_3", "seasons_spring"])
	var mapping := short.assign_symbols(faces, 1)
	assert_eq(mapping.get("bamboo_1"), 0, "group 0 keeps symbol 0")
	assert_eq(mapping.get("bamboo_3"), 2, "group 2 keeps symbol 2")
	assert_eq(mapping.get("seasons"), 1, "seasons (group 35) takes the unused symbol 1")
	assert_eq(short.assign_symbols(faces, 999), mapping, "same mapping for the same board")
	assert_true(short.assign_symbols(PackedStringArray(["bamboo_1", "bamboo_2", "bamboo_3", "bamboo_4"]), 1).is_empty(),
		"a board needing more symbols than exist is refused")
	var fruits := TileCollectionLibrary.discover().get_collection("fruits")
	for level in LevelCatalog.levels():
		for index: int in fruits.assign_symbols(_level_faces(level.number), level.deal_seed).values():
			assert_true(index >= 0 and index < fruits.symbol_count(), "fruits level %d uses a real symbol (%d)" % [level.number, index])


func test_fixed_assignment_is_the_same_on_every_board() -> void:
	var collection := _library().get_collection("test_symbols")
	var a := collection.assign_symbols(_level_faces(1), 1101)
	var b := collection.assign_symbols(_level_faces(5), 1505)
	for group: String in a:
		if b.has(group):
			assert_eq(a[group], b[group], "%s keeps its symbol across levels" % group)


func test_mixed_mapping_is_stable() -> void:
	var faces := _level_faces(4)
	var first := _library().get_collection("test_mixed").assign_symbols(faces, 1404)
	var reloaded := _library().get_collection("test_mixed").assign_symbols(faces, 1404)
	assert_eq(first, reloaded, "same board gives the same mixed mapping after reloading")
	var shuffled := faces.duplicate()
	shuffled.reverse()
	assert_eq(_library().get_collection("test_mixed").assign_symbols(shuffled, 1404), first,
		"rearranging the same tiles (shuffle) keeps the mapping")
	var other := _library().get_collection("test_mixed").assign_symbols(faces, 9999)
	assert_true(other != first, "a different board seed gives a different mix")


func test_too_few_symbols_is_rejected() -> void:
	var letters := _library().get_collection("test_letters")
	var faces := _level_faces(3)
	assert_true(TileCatalog.groups_in(faces).size() > letters.symbol_count(), "fixture board needs more than 5 symbols")
	var built := TileSkin.build(letters, TileArtSet.active(), faces, 1, _load)
	assert_true(built.skin == null and built.error.contains("needs"), "skin refused: %s" % built.error)


func test_missing_assets_are_reported_not_shown() -> void:
	var broken := _library().get_collection("test_broken")
	var errors := broken.validate(TileArtSet.active())
	assert_true(errors.size() == 1 and errors[0].contains("ghost"), "the missing symbol is named: %s" % ", ".join(errors))
	var built := TileSkin.build(broken, TileArtSet.active(), PackedStringArray(["bamboo_1", "bamboo_1"]), 1, _load)
	assert_true(built.skin == null, "no skin is built from incomplete artwork")


func test_skins_never_touch_the_board() -> void:
	var level := LevelCatalog.get_level(2)
	var geometry := level.load_layout().build_geometry()
	var deal := BoardGenerator.generate(geometry, level.face_pool(), level.deal_seed)
	var model := BoardModel.new(geometry, deal.faces)
	model.remove_pair(deal.solution[0].x, deal.solution[0].y)
	var faces := model.faces.duplicate()
	var removed := model.removed.duplicate()
	for collection_id in ["classic", "test_symbols", "test_mixed"]:
		TileSkin.build(_library().get_collection(collection_id), TileArtSet.active(), model.faces, level.deal_seed, _load)
	assert_eq(model.faces, faces, "faces unchanged by skinning")
	assert_eq(model.removed, removed, "removed tiles unchanged by skinning")


func test_user_settings_round_trip() -> void:
	var path := "user://test_settings_unit.cfg"
	SafeConfig.remove_all(path)
	assert_eq(UserSettings.new(path).get_value("tiles", "collection", "classic"), "classic", "defaults when no file")
	UserSettings.new(path).set_value("tiles", "collection", "fruits")
	assert_eq(UserSettings.new(path).get_value("tiles", "collection"), "fruits", "value survives reload")
	SafeConfig.remove_all(path)
