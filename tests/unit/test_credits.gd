extends TestCase
## The credits page carries every required credit and licence text.


func test_required_credits_are_on_the_page() -> void:
	var page := Credits.text()
	for credit: String in AudioCatalog.MUSIC_CREDITS:
		assert_true(page.contains(credit), "music credit: " + credit)
	for name_needed: String in ["Fraunces", "Noto Naskh Arabic", "Noto Emoji", "Godot Engine", "godot-admob", "Godot Play Game Services"]:
		assert_true(page.contains(name_needed), "credit: " + name_needed)


func test_licence_texts_ship_with_the_engine() -> void:
	var page := Credits.text()
	assert_true(page.contains(Engine.get_license_text()), "MIT text")
	assert_true(page.contains("The goals of the Open Font License"), "OFL text")
	assert_true(page.contains("Apache License"), "Apache text")
