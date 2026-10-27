extends TestCase
## The tile artwork mapping (TileArtSet) and its manifests.

const FIXTURE := "res://tests/fixtures/alt_tile_art.json"


func test_active_collection_is_valid() -> void:
	var art := TileArtSet.active()
	assert_true(art != null, "active manifest loads")
	for error in art.validate():
		failures.append("active collection: " + error)
	assert_eq(art.manifest_path, ProjectSettings.get_setting(TileArtSet.SETTING), "project setting picks the manifest")


func test_every_face_maps_to_its_own_png() -> void:
	var art := TileArtSet.active()
	var seen := {}
	for face in TileCatalog.all_faces():
		var path := art.face_path(face)
		assert_true(ResourceLoader.exists(path), "art for %s exists" % face)
		assert_false(seen.has(path), "%s does not share art with %s" % [face, seen.get(path, "")])
		seen[path] = face
	assert_eq(seen.size(), 42, "42 distinct face images")


func test_defective_faces_are_flagged() -> void:
	var art := TileArtSet.active()
	for face in ["characters_1", "winds_east", "dragons_red", "dragons_green", "dragons_white"]:
		assert_false(art.is_verified(face), "%s is flagged until replaced" % face)
	for face in ["bamboo_1", "dots_9", "flowers_plum", "seasons_winter"]:
		assert_true(art.is_verified(face), "%s is usable" % face)


func test_manifest_drives_paths_and_spacing() -> void:
	var art := TileArtSet.load_manifest(FIXTURE)
	assert_eq(art.id, "test_alt", "fixture loads")
	assert_eq(art.face_path("dots_3"), "res://assets/tiles/faces/tile_dots_3.png", "pattern builds file names")
	assert_eq(art.face_path("bamboo_1"), "res://assets/tiles/faces/tile_bamboo_1.png", "overrides win")
	assert_eq(art.half_step(), Vector2(84, 105), "grid spacing comes from face size and overlap")
	assert_eq(art.layer_shift, Vector2(-20, -26), "layer raise comes from the manifest")
	assert_true(art.validate().is_empty(), "fixture is a valid collection: %s" % ", ".join(art.validate()))


func test_level_pool_follows_collection_flags() -> void:
	var level := LevelCatalog.get_level(1)
	var default_pool := level.face_pool()
	var all_verified := level.face_pool(TileArtSet.load_manifest(FIXTURE))
	assert_false(default_pool.has("characters_1"), "characters held back with v1 art")
	assert_true(all_verified.has("characters_1"), "characters join level 1 once their art is verified")
	assert_true(all_verified.has("dragons_red"), "dragons join level 1 once their art is verified")


func test_validate_reports_bad_manifest() -> void:
	var art := TileArtSet.from_dict({"image_size": [100, 100], "face_rect": [0, 0, 150, 150],
		"face_folder": "res://nowhere/", "unverified_faces": ["not_a_face"]})
	var errors := art.validate()
	assert_true(errors.size() >= 3, "size, missing files and unknown faces reported (%d errors)" % errors.size())
