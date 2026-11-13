extends TestCase
## Lotus Gifts (which levels, what they hold, opening and spending them) and
## Perfect Clears.

const PATH := "user://test_lotus.cfg"


func _fresh() -> ProgressStore:
	SafeConfig.remove_all(PATH)
	return ProgressStore.new(PATH)


func _clear(store: ProgressStore, last: int) -> void:
	for level in range(1, last + 1):
		store.record_clear(level, 1, 10.0, 1000)


func test_gift_levels_and_contents() -> void:
	assert_false(LotusRewards.is_gift_level(4), "level 4 has no gift")
	assert_true(LotusRewards.is_gift_level(5), "every fifth level")
	assert_false(LotusRewards.is_gift_level(0), "no level 0")
	assert_eq(LotusRewards.gift_for(5), {"hints": 1, "shuffles": 1}, "first gift")
	assert_eq(LotusRewards.gift_for(10), {"hints": 2, "shuffles": 0}, "second gift")
	assert_eq(LotusRewards.gift_for(15), {"hints": 3, "shuffles": 0}, "third gift")
	assert_eq(LotusRewards.gift_for(20), LotusRewards.CHAPTER_GIFT, "chapter end")
	assert_eq(LotusRewards.gift_for(25), {"hints": 1, "shuffles": 1}, "the next chapter starts again")
	for level in range(5, 1001, 5):
		var gift := LotusRewards.gift_for(level)
		assert_true(int(gift.hints) + int(gift.shuffles) > 0, "gift %d holds something" % level)
	assert_eq(LotusRewards.next_gift_level(1), 5, "next gift from the start")
	assert_eq(LotusRewards.next_gift_level(10), 10, "a gift level is its own next")
	assert_eq(LotusRewards.next_gift_level(11), 15, "next gift ahead")
	assert_eq(LotusRewards.describe({"hints": 2, "shuffles": 1}), "2 hints and 1 shuffle", "described")
	assert_eq(LotusRewards.describe({"hints": 1, "shuffles": 0}), "1 hint", "one kind")


func test_opening_a_gift() -> void:
	var store := _fresh()
	assert_false(store.is_lotus_ready(5), "closed until level 5 is cleared")
	_clear(store, 5)
	assert_true(store.is_lotus_ready(5), "ready once cleared")
	assert_eq(store.open_lotus(5), {"hints": 1, "shuffles": 1}, "opening adds the gift")
	assert_eq(store.saved_tools("hints"), 1, "hint saved")
	assert_eq(store.saved_tools("shuffles"), 1, "shuffle saved")
	assert_false(store.is_lotus_ready(5), "a gift opens once")
	assert_eq(store.open_lotus(5), {"hints": 0, "shuffles": 0}, "opening again adds nothing")
	assert_eq(store.open_lotus(10), {"hints": 0, "shuffles": 0}, "an uncleared gift adds nothing")
	var reloaded := ProgressStore.new(PATH)
	assert_true(reloaded.is_lotus_opened(5) and reloaded.saved_tools("hints") == 1, "saved")
	SafeConfig.remove_all(PATH)


func test_earned_tools_are_saved_up_to_the_cap() -> void:
	var store := _fresh()
	assert_eq(store.add_saved_tool("magnets"), 1, "one magnet earned")
	assert_eq(store.saved_tools("magnets"), 1, "saved")
	assert_eq(store.add_saved_tool("magnets", 20), LotusRewards.MAX_SAVED - 1, "never past the cap")
	assert_eq(ProgressStore.new(PATH).saved_tools("magnets"), LotusRewards.MAX_SAVED, "kept after a restart")
	SafeConfig.remove_all(PATH)


func test_spending_and_the_cap() -> void:
	var store := _fresh()
	_clear(store, 40)
	for level in range(5, 41, 5):
		store.open_lotus(level)
	assert_eq(store.saved_tools("hints"), LotusRewards.MAX_SAVED, "hints stop at the cap")
	assert_true(store.spend_saved_tool("hints"), "spend one")
	assert_eq(store.saved_tools("hints"), LotusRewards.MAX_SAVED - 1, "one fewer")
	var shuffles := store.saved_tools("shuffles")
	for i in shuffles:
		store.spend_saved_tool("shuffles")
	assert_false(store.spend_saved_tool("shuffles"), "none left to spend")
	assert_eq(store.saved_tools("shuffles"), 0, "never below zero")
	SafeConfig.remove_all(PATH)


func test_a_returning_player_is_not_handed_old_gifts() -> void:
	SafeConfig.remove_all(PATH)
	# Progress from before Lotus Gifts existed: no baseline saved.
	var old := ConfigFile.new()
	for level in range(1, 13):
		old.set_value("level_%d" % level, "stars", 2)
	SafeConfig.save(old, PATH)
	var store := ProgressStore.new(PATH)
	assert_false(store.is_lotus_ready(5) or store.is_lotus_ready(10), "earlier gifts count as opened")
	store.record_clear(13, 2, 10.0, 1000)
	store.record_clear(14, 2, 10.0, 1000)
	store.record_clear(15, 2, 10.0, 1000)
	assert_true(store.is_lotus_ready(15), "the next gift is earned")
	assert_eq(ProgressStore.new(PATH).lotus_baseline(), 10, "the baseline is saved")
	SafeConfig.remove_all(PATH)


func test_perfect_clears() -> void:
	assert_true(LotusRewards.is_perfect(0, 0, 0), "nothing used")
	assert_false(LotusRewards.is_perfect(1, 0, 0), "a mistake")
	assert_false(LotusRewards.is_perfect(0, 1, 0), "a hint")
	assert_false(LotusRewards.is_perfect(0, 0, 1), "a shuffle")
	var store := _fresh()
	assert_false(store.is_perfect(3), "not yet")
	assert_true(store.record_perfect(3), "first perfect clear")
	assert_false(store.record_perfect(3), "only the first counts as new")
	assert_true(ProgressStore.new(PATH).is_perfect(3), "saved")
	SafeConfig.remove_all(PATH)
