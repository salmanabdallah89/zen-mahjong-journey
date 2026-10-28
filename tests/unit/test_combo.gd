extends TestCase
## Combo praise tiers.


func test_praise_tiers() -> void:
	assert_eq(ComboFeedback.tier_for(1), 0, "a single match is not a combo")
	assert_eq(ComboFeedback.word_for(ComboFeedback.tier_for(2)), "Nice!", "2 in a row: Nice!")
	assert_eq(ComboFeedback.word_for(ComboFeedback.tier_for(4)), "Great!", "4 in a row stays Great!")
	assert_eq(ComboFeedback.word_for(ComboFeedback.tier_for(5)), "Amazing!", "5 in a row: Amazing!")
	assert_eq(ComboFeedback.word_for(ComboFeedback.tier_for(7)), "Excellent!", "7 in a row: Excellent!")
	assert_eq(ComboFeedback.word_for(ComboFeedback.tier_for(10)), "Zen Master!", "10 in a row: Zen Master!")
	assert_eq(ComboFeedback.word_for(ComboFeedback.tier_for(40)), "Zen Master!", "the top tier holds")


func test_cues_ring_only_on_new_tiers() -> void:
	var reached := []
	for combo in range(1, 13):
		if ComboFeedback.reaches_tier(combo):
			reached.append(combo)
	assert_eq(reached, [2, 3, 5, 7, 10], "cues ring when a new tier is reached")
	assert_eq(AudioCatalog.COMBO_CUES.size(), ComboFeedback.TIERS.size(), "one cue per tier")
	for cue in AudioCatalog.COMBO_CUES:
		assert_true(ResourceLoader.exists(cue), "%s is installed" % cue.get_file())
