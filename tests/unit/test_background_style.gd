extends TestCase
## Per-background shading table.


func test_every_level_background_is_tuned() -> void:
	for level in LevelCatalog.levels():
		assert_true(BackgroundStyle.STYLES.has(level.background), "%s has its own shading" % level.background)


func test_shading_stays_gentle() -> void:
	for background: String in BackgroundStyle.STYLES:
		var tint := BackgroundStyle.scenery_tint(background)
		assert_true(tint.r >= 0.8 and tint.r <= 1.0, "%s scenery dimmed at most 20 %%" % background)
		var shade := BackgroundStyle.board_shade(background)
		assert_true(shade >= 0.4 and shade <= 0.75, "%s board shade in 0.4..0.75" % background)


func test_brighter_backgrounds_get_more_shade() -> void:
	assert_true(BackgroundStyle.board_shade("bg_golden_sakura") > BackgroundStyle.board_shade("bg_moonlight_sanctuary"),
		"bright sakura is shaded more than dark moonlight")
	assert_true(BackgroundStyle.scenery_tint("bg_bamboo_forest").r < BackgroundStyle.scenery_tint("bg_moonlight_sanctuary").r,
		"busy bamboo is dimmed more than moonlight")
