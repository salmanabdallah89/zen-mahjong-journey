extends TestCase
## When the update notice shows.


func test_versions_compare_by_number() -> void:
	assert_true(UpdateNotes.is_newer("1.0.8", "1.0.7"), "higher patch")
	assert_true(UpdateNotes.is_newer("1.0.10", "1.0.9"), "10 is above 9")
	assert_true(UpdateNotes.is_newer("1.1", "1.0.9"), "shorter version")
	assert_false(UpdateNotes.is_newer("1.0.8", "1.0.8"), "same version")
	assert_false(UpdateNotes.is_newer("1.0.7", "1.0.8"), "older version")


func test_parse_reads_the_file_and_rejects_damage() -> void:
	var good := UpdateNotes.parse({"latest": "1.0.8", "notes": ["a", "b", "c", "d", "e"]})
	assert_eq(good.latest, "1.0.8", "version")
	assert_eq(good.notes.size(), UpdateNotes.MAX_NOTES, "notes are capped")
	assert_true(UpdateNotes.parse(null).is_empty(), "no file")
	assert_true(UpdateNotes.parse({"notes": []}).is_empty(), "no version")
	assert_true(UpdateNotes.parse("nonsense").is_empty(), "not a dictionary")
	assert_true(UpdateNotes.parse({"latest": "soon"}).is_empty(), "not a version")


func test_later_keeps_a_version_quiet_for_a_few_days() -> void:
	assert_true(UpdateNotes.should_show("1.0.8", "1.0.7", "", 0, 100), "first time")
	assert_false(UpdateNotes.should_show("1.0.8", "1.0.8", "", 0, 100), "already current")
	assert_false(UpdateNotes.should_show("1.0.8", "1.0.7", "1.0.8", 100, 102), "snoozed")
	assert_true(UpdateNotes.should_show("1.0.8", "1.0.7", "1.0.8", 100, 103), "snooze ended")
	assert_true(UpdateNotes.should_show("1.0.9", "1.0.7", "1.0.8", 100, 101), "a newer version shows at once")


func test_store_link_is_this_app() -> void:
	assert_true(UpdateNotes.STORE_URL.ends_with("com.zenmahjongjourney.game"), "package id")
