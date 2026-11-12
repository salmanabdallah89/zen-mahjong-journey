extends Node
## Renders the real screens at several phone/tablet window shapes and saves
## PNG screenshots for visual review. Needs a rendering window (not headless):
##   godot --path . res://tests/visual/capture_screens.tscn -- <output_dir>

const STARTUP_SCENE := preload("res://scenes/screens/startup_screen.tscn")
const GAME_SCENE := preload("res://scenes/screens/game_screen.tscn")
## Window sizes; with the 1080-wide canvas these give 9:16, 9:19.5 and 3:4.
const SHAPES := {"phone_9x16": Vector2i(540, 960), "phone_9x19": Vector2i(540, 1170),
	"tablet_3x4": Vector2i(720, 960), "w320x568": Vector2i(320, 568), "w375x812": Vector2i(375, 812),
	"w390x844": Vector2i(390, 844), "w768x1024": Vector2i(768, 1024)}

var _out_dir := "user://screens"


func _ready() -> void:
	# Screenshots must not write stars into the player's real journey.
	GameSession.progress = ProgressStore.new("user://capture_progress.cfg")
	GameSession.progress.reset()
	# Returning player, except in the tutorial shots.
	GameSession.tutorial_settings_path = "user://capture_tutorial.cfg"
	GameSession.set_tutorial_seen("completed")
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	if args.size() > 1 and args[1] == "store":
		await _capture_store()
		_finish()
		return
	if args.size() > 1 and args[1] == "lotus":
		get_window().size = SHAPES["phone_9x16"]
		await _capture_lotus()
		_finish()
		return
	for shape: String in SHAPES:
		get_window().size = SHAPES[shape]
		await _frames(4)
		await _capture_startup(shape)
		await _capture_level(shape, 1, true)
		await _capture_combo(shape)
		await _capture_tutorial(shape)
		if shape == "phone_9x16":
			for level in [3, 5, 8, 10]:
				await _capture_level(shape, level, false)
	get_window().size = SHAPES["phone_9x16"]
	await _capture_losing()
	await _capture_update_notice()
	await _capture_remove_ads()
	await _capture_daily()
	await _capture_badges()
	await _capture_words()
	await _capture_collections()
	await _capture_zen_small()
	await _measure_frame_times(10)
	await _capture_journey()
	await _capture_lotus()
	await _capture_ads()
	_finish()


func _capture_update_notice() -> void:
	var home: Control = load("res://scenes/screens/startup_screen.tscn").instantiate()
	add_child(home)
	await _frames(10)
	home.get_node("%UpdateNotice").present({"latest": "1.0.8", "notes": PackedStringArray([
		"Daily Challenge with a calendar and monthly trophies", "Badges to earn on your journey"])})
	await get_tree().create_timer(1.0).timeout
	await _save("phone_9x16_update_notice")
	home.get_node("%UpdateNotice").present_ready()
	await get_tree().create_timer(1.0).timeout
	await _save("phone_9x16_update_ready")
	home.queue_free()
	await _frames(2)


## A stand-in Google Play that sells Remove Ads (the real one needs a phone).
class _ShopBilling extends PlayBillingBridge:
	func is_available() -> bool:
		return true

	func start() -> void:
		connected.emit()

	func query_product(product: String) -> void:
		product_found.emit(product, "$3.99", "Remove Ads")

	func query_purchases() -> void:
		purchases_listed.emit([])


func _capture_remove_ads() -> void:
	Purchases.settings_path = "user://capture_purchases.cfg"
	SafeConfig.remove_all(Purchases.settings_path)
	Purchases.restore()
	var shop := _ShopBilling.new()
	Purchases.use_bridge(shop)
	var home: Control = load("res://scenes/screens/startup_screen.tscn").instantiate()
	add_child(home)
	await _frames(10)
	var settings: AudioSettingsPanel = home.get_node("%AudioSettings")
	settings.open()
	await _wait(0.4)
	var scroll: ScrollContainer = settings.get_node("%Scroll")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _wait(0.2)
	await _save("phone_9x16_settings_remove_ads")
	settings.close()
	for i in PurchaseRules.OFFER_AFTER_INTERSTITIALS:
		AdsManager.ad_finished.emit("interstitial", "level_complete", false)
	Purchases.offer_if_due()
	await _wait(0.6)
	await _save("phone_9x16_remove_ads_offer")
	Purchases.close_dialog()
	shop.purchase_updated.emit(PurchaseRules.OK, [{"products": [PurchaseRules.REMOVE_ADS], "state": PurchaseRules.PURCHASED, "token": "capture", "acknowledged": true}])
	await _wait(0.6)
	await _save("phone_9x16_remove_ads_thanks")
	Purchases.close_dialog()
	settings.open()
	await _wait(0.4)
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _wait(0.2)
	await _save("phone_9x16_settings_ads_removed")
	settings.close()
	home.queue_free()
	await _frames(2)
	SafeConfig.remove_all(Purchases.settings_path)
	Purchases.settings_path = UserSettings.DEFAULT_PATH
	Purchases.use_bridge(PlayBillingBridge.new())
	Purchases.restore()


func _capture_daily() -> void:
	var store := GameSession.progress
	var today := 20759 + 12
	for day in range(today - 13, today):
		if day % 5 != 0:
			store.record_daily(day, 1 + day % 3, true)
	var page: Control = load(GameSession.DAILY_SCENE).instantiate()
	page.today = today
	add_child(page)
	await _frames(8)
	await _save("phone_9x16_daily_calendar")
	page.queue_free()
	await _frames(2)
	GameSession.daily_day = today
	var game: Control = GAME_SCENE.instantiate()
	add_child(game)
	await _frames(30)
	await _save("phone_9x16_daily_board")
	game.call("_show_daily_complete")
	await _frames(30)
	await _save("phone_9x16_daily_complete")
	game.queue_free()
	await _frames(2)
	GameSession.daily_day = -1
	store.reset()


func _capture_badges() -> void:
	var store := GameSession.progress
	for level in range(1, 46):
		store.record_clear(level, 3 if level % 2 == 0 else 2, 100.0, LevelCatalog.count(), 1800)
	store.record_badge_facts({"still_mind": 57, "flowing_river": 2, "golden_lotus": 9, "last_petal": 1}, 100)
	var page: Control = load(GameSession.BADGES_SCENE).instantiate()
	add_child(page)
	await _frames(8)
	await _save("phone_9x16_badges_page")
	page.get_node("SafeArea/Content/Scroll").scroll_vertical = 1400
	await _frames(4)
	await _save("phone_9x16_badges_page_end")
	page.open_card("still_mind")
	await _frames(20)
	await _save("phone_9x16_badges_card")
	page.queue_free()
	await _frames(2)
	var game: Control = GAME_SCENE.instantiate()
	add_child(game)
	await _frames(10)
	var reveal: BadgeReveal = game.get_node("%BadgeReveal")
	reveal.play([{"id": "still_mind", "rank": 3}, {"id": "pathfinder", "rank": 1}])
	await get_tree().create_timer(2.5).timeout
	await _save("phone_9x16_badges_reveal_gold")
	reveal.next()
	await get_tree().create_timer(2.5).timeout
	await _save("phone_9x16_badges_reveal_bronze")
	game.queue_free()
	await _frames(2)
	store.reset()


func _capture_words() -> void:
	var page: Control = load(GameSession.WORDS_SCENE).instantiate()
	page.settings_path = "user://capture_words.cfg"
	add_child(page)
	await _frames(6)
	await _save("phone_9x16_words_languages")
	page.get_node("%LanguagePanel").hide()
	await _frames(4)
	await _save("phone_9x16_words_page")
	page.queue_free()
	GameSession.word_language = "es"
	for stage in [8, 40]:
		GameSession.word_stage = stage
		var screen: Control = GAME_SCENE.instantiate()
		add_child(screen)
		await _frames(30)
		await _save("phone_9x16_words_stage%d" % stage)
		if stage == 40:
			screen.call("_show_stage_complete")
			await _frames(30)
			await _save("phone_9x16_words_complete")
		screen.queue_free()
		await _frames(2)
	GameSession.word_language = "ar"
	GameSession.word_native = "en"
	GameSession.word_stage = 12
	var arabic: Control = GAME_SCENE.instantiate()
	add_child(arabic)
	await _frames(30)
	await _save("phone_9x16_words_arabic")
	arabic.queue_free()
	await _frames(2)
	GameSession.word_native = "ar"
	GameSession.word_language = ""
	SafeConfig.remove_all("user://capture_words.cfg")


func _finish() -> void:
	GameSession.progress.reset()
	SafeConfig.remove_all(GameSession.progress.path)
	GameSession.progress = ProgressStore.new()
	SafeConfig.remove_all(GameSession.tutorial_settings_path)
	GameSession.tutorial_settings_path = UserSettings.DEFAULT_PATH
	print("Screenshots written to ", ProjectSettings.globalize_path(_out_dir))
	get_tree().quit()


## Google Play phone screenshots at the full 1080x1920 canvas, without ads:
##   godot --path . res://tests/visual/capture_screens.tscn -- <dir> store
func _capture_store() -> void:
	AdsManager.provider = "none"
	get_window().size = Vector2i(1080, 1920)
	await _frames(4)
	var manager := TileCollectionManager
	var real_settings := manager.settings_path
	manager.settings_path = "user://capture_settings.cfg"
	SafeConfig.remove_all(manager.settings_path)
	manager.restore()
	for number in range(1, 13):
		GameSession.progress.record_clear(number, 3 if number % 4 != 0 else 2, 90.0, 10)

	var startup := STARTUP_SCENE.instantiate()
	add_child(startup)
	await _wait(1.5)
	await _save("store_01_home")
	var picker: CollectionPicker = startup.get_node("%CollectionPicker")
	picker.open()
	picker.highlight("animals")
	await _wait(0.6)
	await _save("store_05_collections")
	startup.queue_free()
	await _frames(2)

	var shots := [["classic", 13, "store_02_board"], ["animals", 24, "store_03_animals"], ["fruits", 40, "store_04_fruits"]]
	for shot: Array in shots:
		manager.select(str(shot[0]))
		GameSession.current_level = int(shot[1])
		var screen: Control = GAME_SCENE.instantiate()
		add_child(screen)
		await _wait(0.8)
		var model: BoardModel = screen.get("_model")
		screen.call("_on_tile_pressed", model.available_matches()[0].x)
		await _wait(0.5)
		await _save(str(shot[2]))
		screen.queue_free()
		await _frames(2)

	var journey: Control = load("res://scenes/screens/journey_screen.tscn").instantiate()
	add_child(journey)
	await _wait(1.0)
	await _save("store_06_journey")
	journey.queue_free()
	await _frames(2)

	manager.select("classic")
	SafeConfig.remove_all(manager.settings_path)
	manager.settings_path = real_settings
	manager.restore()


## The journey map with some progress, a level card, and a 3-star clear.
func _capture_journey() -> void:
	get_window().size = SHAPES["phone_9x16"]
	GameSession.progress.reset()
	GameSession.progress.record_clear(1, 3, 120.0, 10)
	GameSession.progress.record_clear(2, 2, 60.0, 10)
	GameSession.progress.record_clear(3, 1, 20.0, 10)
	# The map at each requested size (locked, unplayed and cleared stops).
	for shape: String in ["w320x568", "w375x812", "w390x844", "w768x1024"]:
		get_window().size = SHAPES[shape]
		await _frames(4)
		var map: Control = load("res://scenes/screens/journey_screen.tscn").instantiate()
		add_child(map)
		await _wait(0.8)
		await _save("%s_journey" % shape)
		map.queue_free()
		await _frames(2)
	get_window().size = SHAPES["phone_9x16"]
	await _frames(4)
	var journey: Control = load("res://scenes/screens/journey_screen.tscn").instantiate()
	add_child(journey)
	await _wait(0.8)
	await _save("phone_9x16_journey")
	journey.call("_open_card", 2)
	await _wait(0.4)
	await _save("phone_9x16_journey_card")
	journey.queue_free()
	await _frames(2)
	GameSession.current_level = 4
	var screen: Control = GAME_SCENE.instantiate()
	add_child(screen)
	await _wait(0.4)
	var level := LevelCatalog.get_level(4)
	for pair in BoardGenerator.generate(level.load_layout().build_geometry(), level.face_pool(), level.deal_seed).solution:
		screen.call("_on_tile_pressed", pair.x)
		screen.call("_on_tile_pressed", pair.y)
	await _wait(1.6)
	await _save("phone_9x16_level_complete_stars")
	screen.queue_free()
	await _frames(2)


## Lotus Gifts on the map (ready, then opened), Perfect Clear stamps, and the
## Perfect Clear dialog of a gift level with its bloom.
func _capture_lotus() -> void:
	get_window().size = SHAPES["phone_9x16"]
	await _frames(4)
	var store := GameSession.progress
	store.reset()
	for level in range(1, 5):
		store.record_clear(level, 3 if level != 3 else 2, 60.0, LevelCatalog.count())
	store.record_perfect(1)
	store.record_perfect(2)
	store.record_perfect(4)
	GameSession.current_level = 5
	var screen: Control = GAME_SCENE.instantiate()
	add_child(screen)
	await _wait(0.4)
	var level := LevelCatalog.get_level(5)
	for pair in BoardGenerator.generate(level.load_layout().build_geometry(), level.face_pool(), level.deal_seed).solution:
		screen.call("_on_tile_pressed", pair.x)
		screen.call("_on_tile_pressed", pair.y)
	await _wait(3.4)
	await _save("phone_9x16_perfect_clear")
	screen.queue_free()
	await _frames(2)
	GameSession.just_unlocked = 0
	var journey: Control = load("res://scenes/screens/journey_screen.tscn").instantiate()
	add_child(journey)
	await _wait(0.6)
	var world: JourneyWorld = journey.get_node("%World")
	world.focus_level(5, false)
	await _wait(0.4)
	await _save("phone_9x16_lotus_gift_ready")
	journey.call("_on_gift_pressed", 5)
	await _wait(1.6)
	await _save("phone_9x16_lotus_gift_opened")
	journey.queue_free()
	await _frames(2)
	store.reset()


## Stand-in ads: second-chance offer, a rewarded ad, the hint offer, the banner.
func _capture_ads() -> void:
	AdsManager.config["simulated_ad_seconds"] = 3.0
	GameSession.current_level = 4
	var screen: Control = GAME_SCENE.instantiate()
	add_child(screen)
	await _wait(0.4)
	screen.set("_time_left", 0.1)
	await _wait(0.6)
	await _save("phone_9x16_ad_second_chance")
	var dialog: ModalDialog = screen.get_node("%Dialog")
	for button in dialog.get_node("%Buttons").get_children():
		if (button as Button).text.begins_with("Watch Ad"):
			button.emit_signal("pressed")
	await _wait(1.2)
	await _save("phone_9x16_ad_rewarded")
	AdsManager.press_simulated_close()
	await _wait(0.3)
	screen.call("_restart")
	await _wait(0.3)
	screen.call("_on_hint_pressed")
	screen.call("_clear_hint")
	screen.call("_on_hint_pressed")
	await _wait(0.4)
	await _save("phone_9x16_ad_hint_offer")
	screen.queue_free()
	await _frames(2)
	var journey: Control = load("res://scenes/screens/journey_screen.tscn").instantiate()
	add_child(journey)
	await _wait(0.6)
	await _save("phone_9x16_ad_banner")
	journey.queue_free()
	await _frames(2)


## Hearts, a mistake, the low-time warning and both loss popups.
func _capture_losing() -> void:
	GameSession.current_level = 4
	var screen: Control = GAME_SCENE.instantiate()
	add_child(screen)
	await _wait(0.5)
	var model: BoardModel = screen.get("_model")
	var free := model.free_tiles()
	var wrong := Vector2i(-1, -1)
	for a in free:
		for b in free:
			if wrong.x < 0 and a != b and not TileCatalog.faces_match(model.faces[a], model.faces[b]):
				wrong = Vector2i(a, b)
	screen.call("_on_tile_pressed", wrong.x)
	screen.call("_on_tile_pressed", wrong.y)
	screen.set("_time_left", 24.0)
	await _wait(0.5)
	await _save("phone_9x16_mistake_low_time")
	screen.set("_time_left", 0.1)
	await _wait(0.6)
	await _save("phone_9x16_out_of_time")
	(screen.get_node("%Dialog") as ModalDialog).close()
	screen.call("_restart")
	await _wait(0.3)
	for i in model.tile_count():
		if int(screen.call("hearts_left")) <= 0:
			break
		screen.call("_on_tile_pressed", wrong.x)
		screen.call("_on_tile_pressed", wrong.y)
		await _wait(0.05)
	await _wait(0.5)
	await _save("phone_9x16_too_many_mistakes")
	screen.queue_free()
	await _frames(2)


## The collection picker and every enabled collection on real boards, plus
## a stand-in fixture board (file names marked "fixture").
## Zen Garden at the smallest window, where tiles are their tiniest.
func _capture_zen_small() -> void:
	var manager := TileCollectionManager
	var real_settings := manager.settings_path
	manager.settings_path = "user://capture_settings.cfg"
	SafeConfig.remove_all(manager.settings_path)
	manager.restore()
	manager.select("zen_garden")
	get_window().size = SHAPES["w320x568"]
	await _frames(4)
	for number in [5, 10]:
		GameSession.current_level = number
		var screen: Control = GAME_SCENE.instantiate()
		add_child(screen)
		await _wait(0.6)
		await _save("w320x568_zen_level%02d" % number)
		screen.queue_free()
		await _frames(2)
	get_window().size = SHAPES["phone_9x16"]
	await _frames(4)
	SafeConfig.remove_all(manager.settings_path)
	manager.settings_path = real_settings
	manager.restore()


func _capture_collections() -> void:
	var manager := TileCollectionManager
	var real_settings := manager.settings_path
	manager.settings_path = "user://capture_settings.cfg"
	SafeConfig.remove_all(manager.settings_path)
	manager.restore()
	var startup := STARTUP_SCENE.instantiate()
	add_child(startup)
	await _wait(1.2)
	var start_picker: CollectionPicker = startup.get_node("%CollectionPicker")
	start_picker.open()
	await _wait(0.4)
	await _save("phone_9x16_collection_picker")
	start_picker.highlight("animals")
	await _wait(0.2)
	await _save("phone_9x16_collection_picker_animals")
	start_picker.highlight("fruits")
	await _wait(0.2)
	await _save("phone_9x16_collection_picker_needs_fixes")
	start_picker.hide()
	await _save("phone_9x16_startup_menu")
	var settings: AudioSettingsPanel = startup.get_node("%AudioSettings")
	settings.open()
	await _wait(0.4)
	await _save("phone_9x16_settings")
	(settings.get_node("%CreditsPanel") as CreditsPanel).open()
	await _wait(0.2)
	await _save("phone_9x16_credits")
	settings.close()
	settings.hide()
	startup.queue_free()
	await _frames(2)

	for collection_id in ["zen_garden", "classic", "animals", "alphabet", "mixed", "fruits", "vegetables"]:
		manager.select(collection_id)
		for number in [5, 10]:
			GameSession.current_level = number
			var screen: Control = GAME_SCENE.instantiate()
			add_child(screen)
			await _wait(0.5)
			await _save("phone_9x16_%s_level%02d" % [collection_id, number])
			if number == 5 and collection_id != "classic":
				var model: BoardModel = screen.get("_model")
				screen.call("_on_tile_pressed", model.available_matches()[0].x)
				await _wait(0.3)
				await _save("phone_9x16_%s_level05_selected" % collection_id)
			screen.queue_free()
			await _frames(2)

	manager.reload_library(PackedStringArray([TileCollectionLibrary.SHIPPED_DIR, "res://tests/fixtures/collections/"]))
	manager.select("test_symbols")
	GameSession.current_level = 4
	var fixture_screen: Control = GAME_SCENE.instantiate()
	add_child(fixture_screen)
	await _wait(0.4)
	await _save("phone_9x16_fixture_board_symbols")
	fixture_screen.queue_free()
	await _frames(2)
	manager.select("classic")
	SafeConfig.remove_all(manager.settings_path)
	manager.settings_path = real_settings
	manager.reload_library(PackedStringArray([TileCollectionLibrary.SHIPPED_DIR]))
	manager.restore()


## Plays matches on a level for a few seconds while timing every frame, then
## prints average FPS and the slowest frame. Vsync stays on, as on devices.
func _measure_frame_times(number: int) -> void:
	GameSession.current_level = number
	var screen: Control = GAME_SCENE.instantiate()
	add_child(screen)
	await _wait(0.5)
	var level := LevelCatalog.get_level(number)
	var deal := BoardGenerator.generate(level.load_layout().build_geometry(), level.face_pool(), level.deal_seed)
	var frame_times: Array[float] = []
	var last := Time.get_ticks_usec()
	var next_move := 0
	var started := last
	while Time.get_ticks_usec() - started < 6_000_000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frame_times.append((now - last) / 1000.0)
		last = now
		# One match every ~0.3 s keeps tweens and particles running throughout.
		if next_move < deal.solution.size() and frame_times.size() % 18 == 0:
			screen.call("_on_tile_pressed", deal.solution[next_move].x)
			screen.call("_on_tile_pressed", deal.solution[next_move].y)
			next_move += 1
	frame_times.sort()
	var total := 0.0
	for t in frame_times:
		total += t
	var p99 := frame_times[int(frame_times.size() * 0.99)]
	print("PERF level %d: %d frames, avg %.1f fps, 99th pct frame %.1f ms, worst %.1f ms, %d matches" % [
		number, frame_times.size(), 1000.0 * frame_times.size() / total, p99, frame_times[-1], next_move])
	screen.queue_free()
	await _frames(2)


func _capture_startup(shape: String) -> void:
	var screen := STARTUP_SCENE.instantiate()
	add_child(screen)
	await _wait(1.5)
	await _save("%s_startup" % shape)
	screen.queue_free()
	await _frames(2)


func _capture_level(shape: String, number: int, with_states: bool) -> void:
	GameSession.current_level = number
	var screen: Control = GAME_SCENE.instantiate()
	add_child(screen)
	await _wait(0.4)
	await _save("%s_level%02d" % [shape, number])
	if with_states:
		var model: BoardModel = screen.get("_model")
		var matches := model.available_matches()
		screen.call("_on_hint_pressed")
		await _wait(0.3)
		await _save("%s_level%02d_hint" % [shape, number])
		screen.call("_on_tile_pressed", matches[-1].x)
		await _wait(0.3)
		await _save("%s_level%02d_selected" % [shape, number])
		# Blocked tap whose blocker hides under a raised tile, if the board has one.
		screen.call("_set_selected", -1)
		screen.call("_on_tile_pressed", _blocked_tile_to_show(model))
		await _wait(0.3)
		await _save("%s_level%02d_blocked_feedback" % [shape, number])
		await _wait(1.2)
		var level_def := LevelCatalog.get_level(number)
		var first: Vector2i = BoardGenerator.generate(level_def.load_layout().build_geometry(),
			level_def.face_pool(), level_def.deal_seed).solution[0]
		screen.call("_set_selected", -1)
		screen.call("_on_tile_pressed", first.x)
		screen.call("_on_tile_pressed", first.y)
		await _wait(0.16)
		await _save("%s_level%02d_match_effect" % [shape, number])
		await _wait(0.6)
		screen.call("_on_undo_pressed")
		await _wait(0.3)
		# A selected tile under the pause menu: its glow must stay behind the dialog.
		screen.call("_on_tile_pressed", first.x)
		await _wait(0.2)
		screen.call("_open_pause_menu")
		await _wait(0.4)
		await _save("%s_level%02d_paused" % [shape, number])
		(screen.get_node("%Dialog") as ModalDialog).close()
		screen.call("_resume")
		var level := LevelCatalog.get_level(number)
		var deal := BoardGenerator.generate(level.load_layout().build_geometry(), level.face_pool(), level.deal_seed)
		for pair in deal.solution:
			screen.call("_on_tile_pressed", pair.x)
			screen.call("_on_tile_pressed", pair.y)
		# Level Complete opens once the last pair has met, then the stars pop.
		await _wait(1.8)
		await _save("%s_level%02d_complete" % [shape, number])
	screen.queue_free()
	await _frames(2)


## First-play tutorial: step 1 (glowing pair) and step 2, as a new player.
func _capture_tutorial(shape: String) -> void:
	# A brand-new player: no tutorial state and no progress (a cleared
	# level 1 counts as a returning player).
	SafeConfig.remove_all(GameSession.tutorial_settings_path)
	GameSession.progress.reset()
	GameSession.current_level = 1
	var screen: Control = GAME_SCENE.instantiate()
	add_child(screen)
	await _wait(0.7)
	await _save("%s_tutorial_step1" % shape)
	var tutorial: FirstPlayTutorial = screen.get_node("%FeedbackLane").get_node("Tutorial")
	screen.call("_on_tile_pressed", tutorial.pair.x)
	screen.call("_on_tile_pressed", tutorial.pair.y)
	await _wait(0.8)
	await _save("%s_tutorial_step2" % shape)
	tutorial.skip()
	screen.queue_free()
	await _frames(2)


## Combo praise in the message lane below the board: "Nice!" at 2 in a row,
## "Zen Master!" at 10, and a toast, to check nothing overlaps the tiles.
func _capture_combo(shape: String) -> void:
	GameSession.current_level = 4
	var screen: Control = GAME_SCENE.instantiate()
	add_child(screen)
	await _wait(0.4)
	var level := LevelCatalog.get_level(4)
	var deal := BoardGenerator.generate(level.load_layout().build_geometry(), level.face_pool(), level.deal_seed)
	AudioManager.reset_melody()
	for k in 2:
		screen.call("_on_tile_pressed", deal.solution[k].x)
		screen.call("_on_tile_pressed", deal.solution[k].y)
	await _wait(0.55)
	await _save("%s_combo_nice" % shape)
	for k in range(2, 10):
		screen.call("_on_tile_pressed", deal.solution[k].x)
		screen.call("_on_tile_pressed", deal.solution[k].y)
		await _wait(0.12)
	await _wait(0.45)
	await _save("%s_combo_zen_master" % shape)
	await _wait(1.0)
	screen.call("_show_toast", "A tile can be picked when its left or right side is open.")
	await _wait(0.3)
	await _save("%s_toast_lane" % shape)
	screen.queue_free()
	await _frames(2)


## A side-blocked tile, preferring one whose blocker is hidden under a raised tile.
func _blocked_tile_to_show(model: BoardModel) -> int:
	var fallback := -1
	for i in model.tile_count():
		var blockers := model.blockers(i)
		if blockers.is_empty() or model.geometry.positions[blockers[0]].z > model.geometry.positions[i].z:
			continue
		if fallback < 0:
			fallback = i
		for j in blockers:
			if not model.is_free(j) and not model.blockers(j).is_empty() \
					and model.geometry.positions[model.blockers(j)[0]].z > model.geometry.positions[j].z:
				return i
	return fallback


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_out_dir.path_join(name + ".png"))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
