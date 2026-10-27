extends Node
## Renders the real screens at several phone/tablet window shapes and saves
## PNG screenshots for visual review. Needs a rendering window (not headless):
##   godot --path . res://tests/visual/capture_screens.tscn -- <output_dir>

const STARTUP_SCENE := preload("res://scenes/screens/startup_screen.tscn")
const GAME_SCENE := preload("res://scenes/screens/game_screen.tscn")
## Window sizes; with the 1080-wide canvas these give 9:16, 9:19.5 and 3:4.
const SHAPES := {"phone_9x16": Vector2i(540, 960), "phone_9x19": Vector2i(540, 1170),
	"tablet_3x4": Vector2i(720, 960)}

var _out_dir := "user://screens"


func _ready() -> void:
	# Screenshots must not write stars into the player's real journey.
	GameSession.progress = ProgressStore.new("user://capture_progress.cfg")
	GameSession.progress.reset()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	for shape: String in SHAPES:
		get_window().size = SHAPES[shape]
		await _frames(4)
		await _capture_startup(shape)
		await _capture_level(shape, 1, true)
		if shape == "phone_9x16":
			for level in [3, 5, 8, 10]:
				await _capture_level(shape, level, false)
	get_window().size = SHAPES["phone_9x16"]
	await _capture_losing()
	await _capture_collections()
	await _measure_frame_times(10)
	await _capture_journey()
	await _capture_ads()
	GameSession.progress.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSession.progress.path))
	GameSession.progress = ProgressStore.new()
	print("Screenshots written to ", ProjectSettings.globalize_path(_out_dir))
	get_tree().quit()


## The journey map with some progress, a level card, and a 3-star clear.
func _capture_journey() -> void:
	get_window().size = SHAPES["phone_9x16"]
	GameSession.progress.reset()
	GameSession.progress.record_clear(1, 3, 120.0, 10)
	GameSession.progress.record_clear(2, 2, 60.0, 10)
	GameSession.progress.record_clear(3, 1, 20.0, 10)
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
func _capture_collections() -> void:
	var manager := TileCollectionManager
	var real_settings := manager.settings_path
	manager.settings_path = "user://capture_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.settings_path))
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
	settings.hide()
	startup.queue_free()
	await _frames(2)

	for collection_id in ["classic", "animals", "alphabet", "mixed", "fruits", "vegetables"]:
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.settings_path))
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
		await _wait(0.6)
		await _save("%s_level%02d_complete" % [shape, number])
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
