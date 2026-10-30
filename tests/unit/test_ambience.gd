extends TestCase
## Living garden layer (AmbienceStyle) and the HD background lookup.


func test_every_level_background_has_ambience() -> void:
	for level in LevelCatalog.levels():
		assert_true(AmbienceStyle.STYLES.has(level.background), "%s has its own ambience" % level.background)


func test_particles_stay_within_budget() -> void:
	for background: String in AmbienceStyle.STYLES:
		var total := AmbienceStyle.petals(background) + AmbienceStyle.motes(background)
		assert_true(total <= AmbienceStyle.MAX_PARTICLES, "%s: %d particles at most %d" % [background, total, AmbienceStyle.MAX_PARTICLES])


func test_light_and_mist_stay_soft() -> void:
	for background: String in AmbienceStyle.STYLES:
		assert_true(AmbienceStyle.rays(background) <= 0.3, "%s light rays stay soft" % background)
		assert_true(AmbienceStyle.mist(background) <= 0.3, "%s mist keeps the tiles readable" % background)
		assert_true(AmbienceStyle.ray_side(background) in [-1, 1], "%s light comes from a corner" % background)


func test_tints_are_colours() -> void:
	for background: String in AmbienceStyle.STYLES:
		for key in ["petal_tint", "mote_tint", "ray_tint", "mist_tint"]:
			assert_true(Color.html_is_valid(str(AmbienceStyle.of(background)[key])), "%s %s is a colour" % [background, key])


func test_night_has_fireflies_and_no_petals() -> void:
	assert_eq(AmbienceStyle.petals("bg_moonlight_sanctuary"), 0, "no petals at night")
	assert_true(AmbienceStyle.motes("bg_moonlight_sanctuary") > AmbienceStyle.motes("bg_golden_sakura"), "more fireflies at night")


func test_background_path_falls_back_to_original_art() -> void:
	for background: String in BackgroundStyle.STYLES:
		var path := LevelCatalog.background_path_for(background)
		assert_true(ResourceLoader.exists(path), "%s has a painting at %s" % [background, path])
	assert_eq(LevelCatalog.background_path_for("bg_no_such_garden"), "res://assets/backgrounds/bg_no_such_garden.png",
		"without an HD repaint the original path is used")
