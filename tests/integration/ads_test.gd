extends Node
## Ads integration test, using the simulated (stand-in) ad provider:
## free then ad-based hints, rewarded second chance (time and heart),
## interstitial every Nth clear, journey banner, clock and audio paused during
## ads, skipped ads never pay, and a no-ads build (web) keeps the game whole.
## AdsManager's AdMob routing is checked with a stand-in bridge (_FakeBridge):
## the real plugin only runs on a phone.
##   godot --headless --path . res://tests/integration/ads_test.tscn

const GAME_SCENE := preload("res://scenes/screens/game_screen.tscn")
const JOURNEY_SCENE := preload("res://scenes/screens/journey_screen.tscn")
const STARTUP_SCENE := preload("res://scenes/screens/startup_screen.tscn")
const AD_SECONDS := 0.4

var _failures := PackedStringArray()
var _checks := 0
var _frame: Control


## Stands in for scripts/ads/admob_bridge.gd: same methods, ads finished by hand.
## Stand-in for the GodotPlayGameServices Android plugin: same method and
## signal names, answers at once.
class _FakePlayGames extends Object:
	signal userAuthenticated(is_authenticated: bool)
	signal scoreSubmitted(is_submitted: bool, leaderboard_id: String)
	var accept_sign_in := false
	var calls: Array[String] = []

	func isAuthenticated() -> void:
		calls.append("isAuthenticated")
		userAuthenticated.emit(false)

	func signIn() -> void:
		calls.append("signIn")
		userAuthenticated.emit(accept_sign_in)

	func submitScore(board: String, score: int) -> void:
		calls.append("submitScore %s %d" % [board, score])
		scoreSubmitted.emit(true, board)

	func showLeaderboard(board: String) -> void:
		calls.append("showLeaderboard %s" % board)


class _FakeBridge extends Node:
	signal banner_changed
	var rewarded_loaded := false
	var interstitial_loaded := false
	var banner_visible := false
	var privacy := false
	var pending := Callable()

	func rewarded_ready() -> bool:
		return rewarded_loaded

	func interstitial_ready() -> bool:
		return interstitial_loaded

	func show_rewarded(on_done: Callable) -> void:
		pending = on_done

	func show_interstitial(on_done: Callable) -> void:
		pending = on_done

	## Closes the "ad": `rewarded` says whether the reward was earned.
	func finish(rewarded: bool) -> void:
		var callback := pending
		pending = Callable()
		callback.call(rewarded)

	func show_banner() -> void:
		pass

	func hide_banner() -> void:
		banner_visible = false
		banner_changed.emit()

	func banner_height(_canvas_height: float) -> float:
		return 150.0 if banner_visible else 0.0

	func privacy_options_available() -> bool:
		return privacy

	func show_privacy_options() -> void:
		pass


func _ready() -> void:
	# A returning player: the first-play tutorial has its own test.
	GameSession.tutorial_settings_path = "user://test_ads_tutorial.cfg"
	GameSession.set_tutorial_seen("completed")
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
	# Release builds: real ids, complete, not Google's test ids, and the App ID
	# the export writes into the manifest is the same app's.
	var release := AdsManager.release_ids("android")
	_check(not release.is_empty() and not str(release["rewarded"]).begins_with("ca-app-pub-3940256099942544/"),
		"release builds have their own complete set of AdMob ids")
	var publisher := str(release.get("app_id", "")).get_slice("~", 0)
	_check(["banner", "interstitial", "rewarded"].all(func(k: String) -> bool:
		return str(release[k]).begins_with(publisher + "/")), "release ad units belong to the release app's account")
	var export_cfg := ConfigFile.new()
	_check(export_cfg.load("res://addons/AdmobPlugin/android_export.cfg") == OK
		and bool(export_cfg.get_value("General", "is_real", false))
		and str(export_cfg.get_value("Release", "app_id", "")) == str(release["app_id"]),
		"the exported manifest carries the release App ID")
	_check(AdsManager.release_ids("ios").is_empty(), "no real iOS ids yet, so iOS stays on test ads")
	_check(AdsManager.admob_installed(), "the AdMob plugin and bridge are installed")
	var bridge_script: Variant = load(AdsManager.ADMOB_BRIDGE)
	_check(bridge_script is GDScript and (bridge_script as GDScript).can_instantiate(), "the AdMob bridge compiles")
	_check(not AdsManager.privacy_options_available(), "no privacy options button without AdMob")
	await _test_hints()
	await _test_shuffles()
	await _test_second_chance_time()
	await _test_second_chance_heart()
	await _test_interstitial_cadence()
	await _test_banner()
	await _test_without_ads()
	await _test_leaving_during_ad()
	await _test_admob_routing()
	await _test_play_games()

	GameSession.progress.reset()
	for path in ["user://test_ads_progress.cfg", "user://test_ads_audio.cfg"]:
		SafeConfig.remove_all(path)
	GameSession.progress = ProgressStore.new()
	AudioManager.settings_path = UserSettings.DEFAULT_PATH
	AudioManager.restore()
	for failure in _failures:
		print("  FAIL  " + failure)
	print("ads: %d checks, %d failed" % [_checks, _failures.size()])
	SafeConfig.remove_all("user://test_ads_tutorial.cfg")
	GameSession.tutorial_settings_path = UserSettings.DEFAULT_PATH
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


func _test_shuffles() -> void:
	var screen := await _open_level(3)
	var model: BoardModel = screen.get("_model")
	var board: BoardView = screen.get_node("%Board")
	var dialog: ModalDialog = screen.get_node("%Dialog")
	var label: Label = screen.get_node("SafeArea/Layout/Toolbar/ShuffleTool/ShuffleLabel")
	_check(label.text == "Shuffle (1)", "one free shuffle per level (%s)" % label.text)
	var before := model.faces.duplicate()
	screen.call("_on_shuffle_pressed")
	_check(model.faces != before and not dialog.visible, "the free shuffle happens at once")
	_check(label.text == "Ad Shuffle", "after the free shuffle the button offers an ad shuffle")
	while board.is_busy():
		await _frames(1)

	before = model.faces.duplicate()
	screen.call("_on_shuffle_pressed")
	_check(dialog.visible and (dialog.get_node("%Title") as Label).text == "Need a Shuffle?", "next shuffle asks to watch an ad")
	_check(model.faces == before, "asking does not shuffle")
	await _press(dialog, "Watch Ad")
	AdsManager.press_simulated_close()
	await _frames(2)
	_check(model.faces == before, "skipping the ad gives no shuffle")

	screen.call("_on_shuffle_pressed")
	await _press(dialog, "Watch Ad")
	await _wait(AD_SECONDS + 0.3)
	AdsManager.press_simulated_close()
	await _frames(2)
	_check(model.faces != before, "watching the whole ad shuffles the tiles")
	_check(AdsManager.history[-1]["placement"] == "shuffle" and AdsManager.history[-1]["rewarded"], "shuffle ad recorded as rewarded")
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
	var every := int(AdsManager.setting("interstitial_every_levels", 2))
	_check(every == 2, "an interstitial is due every 2nd finished level")
	AdsManager.levels_ended = 0
	AdsManager.last_ad_ended_msec = -1
	var ran := [0]
	var interstitials := func() -> int:
		return AdsManager.history.filter(func(e: Dictionary) -> bool: return e["kind"] == "interstitial").size()
	var before: int = interstitials.call()
	AdsManager.after_level_complete(func() -> void: ran[0] += 1)
	_check(ran[0] == 1 and interstitials.call() == before and not AdsManager.is_showing(), "no ad after the 1st clear")
	AdsManager.after_level_complete(func() -> void: ran[0] += 1)
	_check(AdsManager.is_showing() and ran[0] == 1, "an interstitial shows after the 2nd clear, before moving on")
	await _wait(AD_SECONDS + 0.3)
	AdsManager.press_simulated_close()
	await _frames(2)
	_check(ran[0] == 2 and interstitials.call() == before + 1, "after the interstitial the game moves on")

	# Never two full-screen ads back to back: a due interstitial is skipped
	# within the minimum gap after another ad.
	AdsManager.levels_ended = every - 1
	AdsManager.after_level_complete(func() -> void: ran[0] += 1)
	_check(ran[0] == 3 and not AdsManager.is_showing(), "no interstitial right after another ad")

	# Losses count too: leaving a lost level with Retry shows the due ad first.
	AdsManager.levels_ended = every - 1
	AdsManager.last_ad_ended_msec = -1
	var lost := await _open_level(2)
	lost.set("_time_left", 0.15)
	await _wait(0.4)
	var lost_dialog: ModalDialog = lost.get_node("%Dialog")
	(_button(lost_dialog, "Retry") as Button).emit_signal("pressed")
	await _frames(2)
	_check(AdsManager.is_showing() and bool(lost.get("_failed")), "Retry after a loss shows the due interstitial first")
	await _wait(AD_SECONDS + 0.3)
	AdsManager.press_simulated_close()
	await _frames(3)
	_check(AdsManager.history[-1]["placement"] == "level_lost" and not bool(lost.get("_failed")),
		"after the interstitial the level restarts")
	AdsManager.levels_ended = 0
	lost.set("_time_left", 0.15)
	await _wait(0.4)
	GameSession.scene_changes_enabled = false
	GameSession.last_requested_scene = ""
	(_button(lost_dialog, "Levels") as Button).emit_signal("pressed")
	await _frames(2)
	_check(not AdsManager.is_showing() and GameSession.last_requested_scene == GameSession.JOURNEY_SCENE,
		"a loss that is not due goes straight to the map")
	GameSession.scene_changes_enabled = true
	await _close(lost)

	# In play: clearing a level and pressing Next Level goes through the cadence.
	AdsManager.levels_ended = every - 1
	AdsManager.last_ad_ended_msec = -1
	var screen := await _open_level(1)
	var level := LevelCatalog.get_level(1)
	for pair in BoardGenerator.generate(level.load_layout().build_geometry(), level.face_pool(), level.deal_seed).solution:
		screen.call("_on_tile_pressed", pair.x)
		screen.call("_on_tile_pressed", pair.y)
	# Level Complete opens once the last pair has met.
	await _wait(1.5)
	var dialog: ModalDialog = screen.get_node("%Dialog")
	GameSession.scene_changes_enabled = false
	GameSession.last_requested_scene = ""
	(_button(dialog, "Next Level") as Button).emit_signal("pressed")
	await _frames(2)
	_check(AdsManager.is_showing() and GameSession.last_requested_scene == "",
		"Next Level when an ad is due shows the interstitial first")
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
	var model: BoardModel = screen.get("_model")
	var board: BoardView = screen.get_node("%Board")
	for i in 2:
		while board.is_busy():
			await _frames(1)
		var faces := model.faces.duplicate()
		screen.call("_on_shuffle_pressed")
		_check(model.faces != faces, "without ads every shuffle is free (%d)" % (i + 1))
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


## AdsManager with the AdMob provider: offers only while an ad is ready,
## rewards only when earned, interstitials skipped when none is loaded, and
## the map's banner gap follows the real banner.
func _test_admob_routing() -> void:
	var fake := _FakeBridge.new()
	AdsManager.add_child(fake)
	fake.banner_changed.connect(AdsManager.banner_changed.emit)
	AdsManager.set("_admob", fake)
	AdsManager.provider = "admob"

	_check(not AdsManager.is_available(), "AdMob: no ad loaded means no ad offers")
	var result := [null]
	AdsManager.show_rewarded("hint", func(r: bool) -> void: result[0] = r)
	_check(result[0] == false and not AdsManager.is_showing(), "AdMob: asking without a ready ad pays nothing")
	AdsManager.levels_ended = 1
	AdsManager.last_ad_ended_msec = -1
	var ran := [false]
	AdsManager.after_level_complete(func() -> void: ran[0] = true)
	_check(ran[0] and not AdsManager.is_showing(), "AdMob: no interstitial loaded, the game moves on at once")

	fake.rewarded_loaded = true
	_check(AdsManager.is_available(), "AdMob: a loaded rewarded ad brings the offers back")
	result[0] = null
	AdsManager.show_rewarded("hint", func(r: bool) -> void: result[0] = r)
	_check(AdsManager.is_showing() and AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),
		"AdMob: the game is silent while the ad shows")
	fake.finish(false)
	_check(result[0] == false and not AdsManager.is_showing(), "AdMob: closing early pays nothing")
	AdsManager.show_rewarded("second_chance", func(r: bool) -> void: result[0] = r)
	fake.finish(true)
	_check(result[0] == true and AdsManager.history[-1]["rewarded"], "AdMob: an earned reward pays")
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "AdMob: sound returns after the ad")

	fake.interstitial_loaded = true
	AdsManager.levels_ended = 1
	AdsManager.last_ad_ended_msec = -1
	ran[0] = false
	AdsManager.after_level_complete(func() -> void: ran[0] = true)
	_check(AdsManager.is_showing() and not ran[0], "AdMob: a due clear shows the interstitial first")
	fake.finish(false)
	_check(ran[0] and not AdsManager.is_showing(), "AdMob: the game moves on after the interstitial")

	var journey: Control = JOURNEY_SCENE.instantiate()
	_frame.add_child(journey)
	await _frames(3)
	var gap := journey.get_node("%BannerGap") as Control
	_check(gap.custom_minimum_size.y == 0.0, "AdMob: no gap before the banner has loaded")
	fake.banner_visible = true
	fake.banner_changed.emit()
	_check(gap.custom_minimum_size.y == 150.0, "AdMob: the map makes room when the banner appears")
	journey.queue_free()
	await _frames(2)
	_check(not AdsManager.is_banner_visible(), "AdMob: the banner goes away with the map")
	fake.privacy = true
	_check(AdsManager.privacy_options_available(), "AdMob: consent regions get a privacy options button")

	AdsManager.provider = "simulated"
	AdsManager.set("_admob", null)
	fake.queue_free()
	await _frames(1)


func _test_play_games() -> void:
	_check(not PlayGames.is_available(), "Play Games is off on the desktop")
	PlayGames.show_leaderboard()
	PlayGames.submit_total(5000)
	_check(PlayGames.submitted.is_empty(), "without Play Games nothing is sent")
	var startup: Control = STARTUP_SCENE.instantiate()
	_frame.add_child(startup)
	await _frames(2)
	_check(not (startup.get_node("%LeaderboardButton") as Button).visible, "no Leaderboard button without Play Games")
	startup.queue_free()
	await _frames(2)

	var fake := _FakePlayGames.new()
	var real_id := PlayGames.leaderboard_id
	PlayGames.leaderboard_id = "TEST_BOARD"
	PlayGames.use_plugin(fake)
	GameSession.progress.reset()
	GameSession.progress.record_clear(1, 3, 100.0, LevelCatalog.count(), 4200)
	_check(PlayGames.is_available() and not PlayGames.signed_in, "with the plugin: available, not signed in yet")
	PlayGames.submit_total(4200)
	_check(PlayGames.submitted.is_empty(), "a score waits for sign-in")
	startup = STARTUP_SCENE.instantiate()
	_frame.add_child(startup)
	await _frames(2)
	var button: Button = startup.get_node("%LeaderboardButton")
	_check(button.visible and button.size.y >= 120, "the start screen shows a Leaderboard button")
	fake.accept_sign_in = true
	button.pressed.emit()
	_check(PlayGames.signed_in, "Leaderboard signs the player in")
	_check(PlayGames.submitted == [4200], "after sign-in the total score is sent (%s)" % [PlayGames.submitted])
	_check(fake.calls.has("showLeaderboard TEST_BOARD"), "then Google's leaderboard opens")
	startup.queue_free()
	await _frames(2)

	# Clearing a level with a better score sends the new total.
	var screen := await _open_level(2)
	var model: BoardModel = screen.get("_model")
	var level := LevelCatalog.get_level(2)
	for pair in BoardGenerator.generate(model.geometry, level.face_pool(), level.deal_seed).solution:
		screen.call("_on_tile_pressed", pair.x)
		screen.call("_on_tile_pressed", pair.y)
		while (screen.get_node("%Board") as BoardView).is_busy():
			await _frames(1)
	var dialog: ModalDialog = screen.get_node("%Dialog")
	# Level Complete waits for the last pair and the bell queue: allow a slow run.
	for i in 300:
		if dialog.visible:
			break
		await _frames(2)
	var total := GameSession.progress.total_score(LevelCatalog.count())
	_check(total > 4200 and PlayGames.submitted.back() == total, "a new best score sends the new total (%d)" % total)
	await _close(screen)

	PlayGames.use_plugin(null)
	PlayGames.leaderboard_id = real_id
	PlayGames.submitted.clear()
	fake.free()
	GameSession.progress.reset()


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
