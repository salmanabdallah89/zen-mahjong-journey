extends TestCase
## Tile collections: manifests, validation, symbol assignment and skins.

const FIXTURES := "res://tests/fixtures/collections/"
const SHIPPED_IDS: PackedStringArray = ["classic", "animals", "fruits", "vegetables", "alphabet", "mixed"]


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
		# Only missing files are acceptable problems; structure must be valid.
		for error in collection.validate(TileArtSet.active()):
			if not error.begins_with("missing"):
				failures.append("%s: %s" % [collection.id, error])
	assert_eq(ids, SHIPPED_IDS, "six collections in menu order")


func test_symbol_counts_cover_levels() -> void:
	var library := TileCollectionLibrary.discover()
	for collection_id in ["animals", "fruits", "vegetables", "mixed"]:
		assert_eq(library.get_collection(collection_id).symbol_count(), 36, "%s can cover every match group" % collection_id)
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


func test_collections_without_art_are_unavailable() -> void:
	var library := TileCollectionLibrary.discover()
	for collection_id in ["animals", "fruits", "vegetables", "alphabet", "mixed"]:
		var collection := library.get_collection(collection_id)
		assert_false(collection.is_complete(TileArtSet.active()), "%s waits for artwork" % collection_id)
		var built := TileSkin.build(collection, TileArtSet.active(), _level_faces(1), 1, _load)
		assert_true(built.skin == null and not built.error.is_empty(), "%s cannot build a skin yet" % collection_id)


func test_no_two_match_groups_look_alike() -> void:
	var library := _library()
	for collection_id in ["classic", "test_symbols", "test_mixed"]:
		var collection := library.get_collection(collection_id)
		for level in LevelCatalog.levels():
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
	assert_true(errors.size() == 1 and errors[0].contains("same picture"), "duplicate picture caught: %s" % ", ".join(errors))


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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_eq(UserSettings.new(path).get_value("tiles", "collection", "classic"), "classic", "defaults when no file")
	UserSettings.new(path).set_value("tiles", "collection", "fruits")
	assert_eq(UserSettings.new(path).get_value("tiles", "collection"), "fruits", "value survives reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
