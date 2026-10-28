extends Node
## Ads integration test, using the simulated (stand-in) ad provider:
## free then ad-based hints, rewarded second chance (time and heart),
## interstitial every Nth clear, journey banner, clock and audio paused during
## ads, skipped ads never pay, and a no-ads build (web) keeps the game whole.
##   godot --headless --path . res://tests/integration/ads_test.tscn

const GAME_SCENE := preload("res://scenes/screens/game_screen.tscn")
const JOURNEY_SCENE := preload("res://scenes/screens/journey_screen.tscn")
const AD_SECONDS := 0.4

var _failures := PackedStringArray()
var _checks := 0
var _frame: Control


func _ready() -> void:
	GameSession.progress = ProgressStore.new("user://test_ads_progress.cfg")
	GameSession.progress.reset()
	AudioManager.settings_path = "user://test_ads_audio.cfg"
	AudioManager.restore()
	AdsManager.config["simulated_ad_seconds"] = AD_SECONDS
	_frame = Control.new()
	_frame.size = Vector2(1080, 1920)
	add_child(_frame)

	_check(AdsManager.provider == "simulated", "desktop debug runs use stand-in test ads (%s)" % AdsManager.provider)
	_check(AdsManager.unit_id("rewarded").begins_with("ca-app-pub-3940256099942544/"), "configured ids are Google's test ids")
	await _test_hints()
	await _test_second_chance_time()
	await _test_second_chance_heart()
	await _test_interstitial_cadence()
	await _test_banner()
	await _test_without_ads()
	await _test_leaving_during_ad()

	GameSession.progress.reset()
	for path in ["user://test_ads_progress.cfg", "user://test_ads_audio.cfg"]:
		SafeConfig.remove_all(path)
	GameSession.progress = ProgressStore.new()
	AudioManager.settings_path = UserSettings.DEFAULT_PATH
	AudioManager.restore()
	for failure in _failures:
		print("  FAIL  " + failure)
	print("ads: %d checks, %d failed" % [_checks, _failures.size()])
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _test_hints() -> void:
	var screen := await _open_level(3)
	var hint_label: Label = screen.get_node("SafeArea/Layout/Toolbar/HintTool/HintLabel")
	_check(hint_label.text == "Hint (1)", "one free hint per level (%s)" % hint_label.text)
	screen.call("_on_hint_pressed")
	_check((screen.get("_hint") as Vector2i).x >= 0, "the free hint is shown at once")
	_check(hint_label.text == "Ad Hint", "after the free hint the button offers an ad hint")
	screen.call("_clear_hint")

	var dialog: ModalDialog = screen.get_node("%Dialog")
	screen.call("_on_hint_pressed")
	_check(dialog.visible and (dialog.get_node("%Title") as Label).text == "Need a Hint?", "next hint asks to watch an ad")
	await _press(dialog, "Watch Ad")
	_check(AdsManager.is_showing(), "the ad is showing")
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "game audio is silent during the ad")
	var clock := float(screen.get("_time_left"))
	await _wait(0.2)
	_check(absf(float(screen.get("_time_left")) - clock) < 0.01, "the level clock stops during the ad")
	AdsManager.press_simulated_close()
	await _frames(2)
	_check(not AdsManager.is_showing() and (screen.get("_hint") as Vector2i).x < 0, "skipping the ad gives no hint")
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "game audio returns after the ad")

	screen.call("_on_hint_pressed")
	await _press(dialog, "Watch Ad")
	await _wait(AD_SECONDS + 0.3)
	AdsManager.press_simulated_close()
	await _frames(2)
	_check((screen.get("_hint") as Vector2i).x >= 0, "watching the whole ad reveals a hint")
	_check(AdsManager.history[-1]["placement"] == "hint" and AdsManager.history[-1]["rewarded"], "hint ad recorded as rewarded")
	await _close(screen)


func _test_second_chance_time() -> void:
	var screen := await _open_level(2)
	var dialog: ModalDialog = screen.get_node("%Dialog")
	screen.set("_time_left", 0.15)
	await _wait(0.4)
	_check(dialog.visible and _button(dialog, "Watch Ad: +60 s") != null, "running out of time offers +60 s for an ad")
	await _press(dialog, "Watch Ad: +60 s")
	await _wait(AD_SECONDS + 0.3)
	AdsManager.press_simulated_close()
	await _frames(3)
	_check(not bool(screen.get("_failed")) and not dialog.visible, "after the ad the level continues")
	_check(absf(float(screen.get("_time_left")) - 60.0) < 1.0, "the clock gets 60 seconds (%.1f)" % float(screen.get("_time_left")))
	var model: BoardModel = screen.get("_model")
	_check(model.remaining == model.tile_count(), "the same board continues")
	screen.set("_time_left", 0.15)
	await _wait(0.4)
	_check(dialog.visible and _button(dialog, "Watch Ad: +60 s") == null and _button(dialog, "Retry") != null,
		"only one second chance per attempt")
	await _press(dialog, "Retry")
	_check(int(screen.call("second_chances_used")) == 0, "Retry restores the second chance")
	await _close(screen)


func _test_second_chance_heart() -> void:
	var screen := await _open_level(4)
	var model: BoardModel = screen.get("_model")
	var dialog: ModalDialog = screen.get_node("%Dialog")
	var limit := LevelCatalog.get_level(4).mistake_limit
	var wrong := _non_matching_free_pair(model)
	for i in limit:
		screen.call("_on_tile_pressed", wrong.x)
		screen.call("_on_tile_pressed", wrong.y)
		await _wait(0.25)
	_check(dialog.visible and _button(dialog, "Watch Ad: +1 Heart") != null, "losing all hearts offers +1 heart for an ad")
	await _press(dialog, "Watch Ad: +1 Heart")
	AdsManager.press_simulated_close()
	await _frames(3)
	_check(dialog.visible and bool(screen.get("_failed")), "skipping the ad keeps the level lost")
	await _press(dialog, "Watch Ad: +1 Heart")
	await _wait(AD_SECONDS + 0.3)
	AdsManager.press_simulated_close()
	await _frames(3)
	_check(not bool(screen.get("_failed")) and int(screen.call("hearts_left")) == 1, "a watched ad gives back one heart")
	await _close(screen)


func _test_interstitial_cadence() -> void:
	AdsManager.levels_completed = 0
	var ran := [0]
	var interstitials := func() -> int:
		return AdsManager.history.filter(func(e: Dictionary) -> bool: return e["kind"] == "interstitial").size()
	var before: int = interstitials.call()
	for i in 2:
		AdsManager.after_level_complete(func() -> void: ran[0] += 1)
	_check(ran[0] == 2 and interstitials.call() == before and not AdsManager.is_showing(), "no ad after the 1st and 2nd clears")
	AdsManager.after_level_complete(func() -> void: ran[0] += 1)
	_check(AdsManager.is_showing() and ran[0] == 2, "an interstitial shows after every 3rd clear, before moving on")
	await _wait(AD_SECONDS + 0.3)
	AdsManager.press_simulated_close()
	await _frames(2)
	_check(ran[0] == 3 and interstitials.call() == before + 1, "after the interstitial the game moves on")

	# In play: clearing a level and pressing Next Level goes through the cadence.
	AdsManager.levels_completed = 2
	var screen := await _open_level(1)
	var level := LevelCatalog.get_level(1)
	for pair in BoardGenerator.generate(level.load_layout().build_geometry(), level.face_pool(), level.deal_seed).solution:
		screen.call("_on_tile_pressed", pair.x)
		screen.call("_on_tile_pressed", pair.y)
	await _frames(3)
	var dialog: ModalDialog = screen.get_node("%Dialog")
	GameSession.scene_changes_enabled = false
	GameSession.last_requested_scene = ""
	(_button(dialog, "Next Level") as Button).emit_signal("pressed")
	await _frames(2)
	_check(AdsManager.is_showing() and GameSession.last_requested_scene == "",
		"Next Level after the 3rd clear shows the interstitial first")
	await _wait(AD_SECONDS + 0.3)
	AdsManager.press_simulated_close()
	await _frames(2)
	_check(GameSession.last_requested_scene == GameSession.GAME_SCENE and GameSession.current_level == 2,
		"after the interstitial the next level opens")
	GameSession.scene_changes_enabled = true
	await _close(screen)


func _test_banner() -> void:
	var journey: Control = JOURNEY_SCENE.instantiate()
	_frame.add_child(journey)
	await _frames(3)
	_check(AdsManager.is_banner_visible(), "the journey map shows a banner")
	_check((journey.get_node("%BannerGap") as Control).custom_minimum_size.y >= AdsManager.BANNER_HEIGHT,
		"the map leaves room for the banner")
	journey.queue_free()
	await _frames(2)
	_check(not AdsManager.is_banner_visible(), "the banner goes away with the map")
	var screen := await _open_level(1)
	_check(not AdsManager.is_banner_visible(), "no banner during play")
	await _close(screen)


func _test_without_ads() -> void:
	AdsManager.provider = "none"
	var screen := await _open_level(3)
	var hint_label: Label = screen.get_node("SafeArea/Layout/Toolbar/HintTool/HintLabel")
	_check(hint_label.text == "Hint", "without ads the hint button is plain")
	for i in 3:
		screen.call("_clear_hint")
		screen.call("_on_hint_pressed")
		_check((screen.get("_hint") as Vector2i).x >= 0, "without ads every hint is free (%d)" % (i + 1))
	var dialog: ModalDialog = screen.get_node("%Dialog")
	screen.set("_time_left", 0.15)
	await _wait(0.4)
	_check(dialog.visible and _button(dialog, "Watch Ad: +60 s") == null and _button(dialog, "Retry") != null,
		"without ads a loss offers Retry, no ad")
	await _close(screen)
	AdsManager.show_banner()
	_check(not AdsManager.is_banner_visible(), "without ads there is no banner")
	AdsManager.hide_banner()
	var ran := [false]
	AdsManager.after_level_complete(func() -> void: ran[0] = true)
	_check(ran[0] and not AdsManager.is_showing(), "without ads levels continue straight away")
	AdsManager.provider = "simulated"


## Leaving a level while its ad is showing closes the ad safely.
func _test_leaving_during_ad() -> void:
	var screen := await _open_level(2)
	screen.set("_time_left", 0.15)
	await _wait(0.4)
	await _press(screen.get_node("%Dialog"), "Watch Ad: +60 s")
	_check(AdsManager.is_showing(), "second-chance ad is showing")
	await _close(screen)
	_check(not AdsManager.is_showing(), "leaving the level closes the ad")
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "game audio is back after leaving")


func _open_level(number: int) -> Control:
	GameSession.current_level = number
	var screen: Control = GAME_SCENE.instantiate()
	_frame.add_child(screen)
	await _frames(3)
	return screen


func _close(screen: Control) -> void:
	screen.queue_free()
	await _frames(2)


func _button(dialog: ModalDialog, text: String) -> Button:
	for button in dialog.get_node("%Buttons").get_children():
		if button is Button and (button as Button).text == text and not button.is_queued_for_deletion():
			return button
	return null


func _press(dialog: ModalDialog, text: String) -> void:
	var button := _button(dialog, text)
	_check(button != null, "dialog has '%s'" % text)
	if button:
		button.emit_signal("pressed")
	await _frames(2)


func _non_matching_free_pair(model: BoardModel) -> Vector2i:
	var free := model.free_tiles()
	for a in free:
		for b in free:
			if a != b and not TileCatalog.faces_match(model.faces[a], model.faces[b]):
				return Vector2i(a, b)
	return Vector2i(-1, -1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
