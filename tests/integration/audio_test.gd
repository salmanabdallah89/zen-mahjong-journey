extends Node
## Audio integration test: music, crossfades, ambience, every gameplay sound
## event, settings, persistence, mute, missing files, rapid tapping and app
## backgrounding, on the real screens. Run:
##   godot --headless --path . res://tests/integration/audio_test.tscn
## Headless runs have no audio device, so this checks AudioManager's state and
## event history (what would sound), not the speakers.

const STARTUP_SCENE := preload("res://scenes/screens/startup_screen.tscn")
const GAME_SCENE := preload("res://scenes/screens/game_screen.tscn")
const AUDIO_SETTINGS := "user://test_audio_settings.cfg"
const TILE_SETTINGS := "user://test_audio_tiles.cfg"
## Stand-in for the not-yet-supplied music files, so crossfades can be tested.
const STAND_IN_MUSIC := "res://assets/audio/ambient/ambient_wind.ogg"

var _failures := PackedStringArray()
var _checks := 0
var _frame: Control


func _ready() -> void:
	# A returning player: the first-play tutorial has its own test.
	GameSession.tutorial_settings_path = "user://test_audio_tutorial.cfg"
	GameSession.set_tutorial_seen("completed")
	for path in [AUDIO_SETTINGS, TILE_SETTINGS]:
		SafeConfig.remove_all(path)
	AudioManager.settings_path = AUDIO_SETTINGS
	AudioManager.restore()
	TileCollectionManager.settings_path = TILE_SETTINGS
	TileCollectionManager.restore()
	GameSession.progress = ProgressStore.new("user://test_audio_progress.cfg")
	GameSession.progress.reset()
	_frame = Control.new()
	_frame.size = Vector2(1080, 1920)
	add_child(_frame)

	await _test_missing_files_are_safe()
	for track: String in AudioCatalog.MUSIC.values():
		AudioManager.use_stream(track, load(STAND_IN_MUSIC))
	await _test_music_and_crossfade()
	await _test_gameplay_sounds()
	await _test_level_complete_and_ducking()
	await _test_settings_sliders_and_persistence()
	await _test_rapid_tapping()
	await _test_match_melody()
	await _test_loss_sounds()
	await _test_backgrounding()
	for track: String in AudioCatalog.MUSIC.values():
		AudioManager.use_stream(track, null)

	for path in [AUDIO_SETTINGS, TILE_SETTINGS]:
		SafeConfig.remove_all(path)
	AudioManager.settings_path = UserSettings.DEFAULT_PATH
	AudioManager.restore()
	GameSession.progress.reset()
	SafeConfig.remove_all("user://test_audio_progress.cfg")
	GameSession.progress = ProgressStore.new()
	for failure in _failures:
		print("  FAIL  " + failure)
	print("audio: %d checks, %d failed" % [_checks, _failures.size()])
	SafeConfig.remove_all("user://test_audio_tutorial.cfg")
	GameSession.tutorial_settings_path = UserSettings.DEFAULT_PATH
	get_tree().quit(1 if _failures.size() > 0 else 0)


## 12. Missing audio never crashes and is reported.
func _test_missing_files_are_safe() -> void:
	_check(not AudioManager.play_sfx("no_such_effect"), "unknown effect id is ignored")
	var absent := "res://assets/audio/sfx/no_such_file.wav"
	_check(not AudioManager.play_sfx("hint", absent), "a missing effect file plays nothing")
	_check(AudioManager.missing.has(absent), "a missing effect file is recorded")
	AudioManager.play_music("main_menu")
	_check(AudioManager.current_music == "main_menu" and AudioManager.active_music_player() != null,
		"the installed menu music starts")
	AudioManager.set_ambience({"birds": 1.0})
	_check(AudioManager.missing.has(AudioCatalog.AMBIENCE["birds"]), "missing birds ambience is recorded")
	AudioManager.set_ambience({})
	AudioManager.stop_music()
	await _frames(2)


## 1-3, 13: menu music, gameplay music, 1.5 s crossfade, no restart on pause/settings.
func _test_music_and_crossfade() -> void:
	var startup: Control = STARTUP_SCENE.instantiate()
	_frame.add_child(startup)
	await _frames(3)
	_check(AudioManager.current_music == "main_menu", "1: main menu music plays on the start screen")
	_check(AudioManager.active_music_player() != null, "1: menu music player is running")
	_check(AudioManager.ambience_level_db("waterfall") > -80.0, "menu ambience (waterfall) fades in")
	await _wait(1.7)
	var menu_player := AudioManager.active_music_player()
	_check(absf(menu_player.volume_db - AudioManager.MUSIC_DB) < 0.5, "menu music reaches its level after the fade")

	# Settings on the start screen does not restart the menu music.
	var seq := AudioManager.event_seq
	startup.get_node("%SettingsButton").emit_signal("pressed")
	await _frames(2)
	(startup.get_node("%AudioSettings") as AudioSettingsPanel).call("_close")
	_check(AudioManager.count_requested("main_menu", seq) == 0, "13: opening Settings does not restart menu music")
	_check(AudioManager.active_music_player() == menu_player, "13: same menu player keeps playing")
	startup.queue_free()

	GameSession.current_level = 1
	var screen: Control = GAME_SCENE.instantiate()
	_frame.add_child(screen)
	await _frames(3)
	_check(AudioManager.current_music == "gameplay", "2: gameplay music starts with the level")
	_check(AudioManager.music_player_count() == 2, "3: menu and gameplay tracks overlap during the crossfade")
	await _wait(0.75)
	var mid := AudioManager.active_music_player().volume_db
	_check(mid > -60.0 and mid < AudioManager.MUSIC_DB - 0.5, "3: gameplay music is part-way faded in at 0.75 s (%.1f dB)" % mid)
	await _wait(1.0)
	_check(AudioManager.music_player_count() == 1, "3: menu track has stopped after 1.5 s")
	_check(absf(AudioManager.active_music_player().volume_db - AudioManager.MUSIC_DB) < 0.5, "3: gameplay music at full level")

	# Pause menu and in-game settings keep the same track running.
	var game_player := AudioManager.active_music_player()
	seq = AudioManager.event_seq
	screen.call("_open_pause_menu")
	await _frames(2)
	screen.call("_open_settings")
	await _frames(2)
	(screen.get_node("%AudioSettings") as AudioSettingsPanel).call("_close")
	(screen.get_node("%Dialog") as ModalDialog).close()
	await _frames(2)
	_check(AudioManager.count_requested("gameplay", seq) == 0 and AudioManager.active_music_player() == game_player,
		"13: pausing and opening Settings do not restart gameplay music")
	screen.queue_free()
	await _frames(2)


## 4-7: select, match (once), blocked, hint, shuffle, undo; failed actions are silent.
func _test_gameplay_sounds() -> void:
	GameSession.current_level = 3
	var screen: Control = GAME_SCENE.instantiate()
	_frame.add_child(screen)
	await _frames(3)
	var model: BoardModel = screen.get("_model")
	var level := LevelCatalog.get_level(3)
	var deal := BoardGenerator.generate(level.load_layout().build_geometry(), level.face_pool(), level.deal_seed)
	var pair := deal.solution[0]

	var seq := AudioManager.event_seq
	await _click(screen.get_node("%UndoButton"))
	screen.call("_on_undo_pressed")
	_check(AudioManager.count_requested("undo", seq) == 0, "failed undo (nothing to undo) is silent")

	seq = AudioManager.event_seq
	await _click_tile(screen, pair.x)
	_check(AudioManager.count_played("tile_select", seq) == 1, "4: selecting a tile plays the select sound")
	await _wait(0.1)
	seq = AudioManager.event_seq
	await _click_tile(screen, pair.y)
	# The bell rings when the gliding pair touches.
	await _wait(0.5)
	_check(AudioManager.count_played("tile_match", seq) == 1, "5: a match plays the match sound once")
	_check(AudioManager.count_requested("tile_select", seq) == 0, "5: completing a match plays no select sound")

	var blocked := -1
	for i in model.tile_count():
		if not model.is_removed(i) and not model.is_free(i):
			blocked = i
			break
	await _wait(0.15)
	seq = AudioManager.event_seq
	await _click_tile(screen, blocked)
	_check(AudioManager.count_played("tile_blocked", seq) == 1, "6: blocked tap plays the blocked sound")
	_check(AudioManager.count_requested("tile_select", seq) == 0, "6: blocked tap plays no select sound")

	for tool in [["HintButton", "hint"], ["ShuffleButton", "shuffle"], ["UndoButton", "undo"]]:
		await _wait(0.3)
		# Tools wait for a running shuffle animation to settle.
		while (screen.get_node("%Board") as BoardView).is_busy():
			await _frames(1)
		seq = AudioManager.event_seq
		await _click(screen.get_node("%" + tool[0]))
		_check(AudioManager.count_played(tool[1], seq) == 1, "7: %s plays its sound" % tool[1])
		_check(AudioManager.count_requested("button_click", seq) == 0, "7: %s plays no extra click" % tool[1])

	await _wait(0.1)
	seq = AudioManager.event_seq
	await _click(screen.get_node("%PauseButton"))
	_check(AudioManager.count_played("button_click", seq) == 1, "ordinary buttons play the click")
	(screen.get_node("%Dialog") as ModalDialog).close()
	screen.call("_resume")
	screen.queue_free()
	await _frames(2)


## 8: victory sound, music lowered during the celebration and restored.
func _test_level_complete_and_ducking() -> void:
	GameSession.current_level = 1
	var screen: Control = GAME_SCENE.instantiate()
	_frame.add_child(screen)
	await _frames(3)
	var level := LevelCatalog.get_level(1)
	var deal := BoardGenerator.generate(level.load_layout().build_geometry(), level.face_pool(), level.deal_seed)
	var seq := AudioManager.event_seq
	for pair in deal.solution:
		screen.call("_on_tile_pressed", pair.x)
		screen.call("_on_tile_pressed", pair.y)
		await _wait(0.09)
	await _wait(1.0)
	_check(AudioManager.count_played("level_complete", seq) == 1, "8: level completion plays the victory sound once")
	await _wait(1.0)
	_check(AudioManager.count_played("star", seq) >= 1, "stars on level complete ring a chime each")
	_check(AudioManager.count_requested("tile_match", seq) == deal.solution.size() - 1,
		"8: every match but the last plays the match sound (%d of %d)" % [AudioManager.count_requested("tile_match", seq), deal.solution.size() - 1])
	await _wait(0.5)
	_check(AudioManager.music_duck() < 0.5, "8: music is lowered during the celebration")
	await _wait(4.5)
	_check(AudioManager.music_duck() > 0.99, "8: music returns to normal afterwards")
	screen.queue_free()
	await _frames(2)


## 9-11: sliders drive the right buses, settings persist, mute silences all.
func _test_settings_sliders_and_persistence() -> void:
	var startup: Control = STARTUP_SCENE.instantiate()
	_frame.add_child(startup)
	await _frames(3)
	var panel: AudioSettingsPanel = startup.get_node("%AudioSettings")
	panel.open()
	await _frames(2)
	(panel.get_node("%MusicSlider") as HSlider).value = 0.25
	(panel.get_node("%SfxSlider") as HSlider).value = 0.5
	(panel.get_node("%AmbienceSlider") as HSlider).value = 0.1
	_check(_bus_near("Music", 0.25), "9: music slider sets the Music bus immediately")
	_check(_bus_near("SFX", 0.5) and _bus_near("UI", 0.5), "9: effects slider sets the SFX and UI buses")
	_check(_bus_near("Ambience", 0.1), "9: ambience slider sets the Ambience bus")
	_check(_bus_near("Master", 1.0), "9: sliders leave Master alone")
	(panel.get_node("%AmbienceSlider") as HSlider).value = 0.0
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")), "9: a slider at zero silences its bus")
	(panel.get_node("%AmbienceSlider") as HSlider).value = 0.1

	(panel.get_node("%VibrationToggle") as Button).button_pressed = false
	(panel.get_node("%MuteToggle") as Button).button_pressed = true
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "11: mute silences the Master bus")
	_check(AudioManager.muted, "11: mute is on")
	await _click(panel.get_node("%BackButton"))

	var relaunched: Node = load("res://scripts/autoload/audio_manager.gd").new()
	relaunched.settings_path = AUDIO_SETTINGS
	add_child(relaunched)
	_check(absf(relaunched.music_volume - 0.25) < 0.001 and absf(relaunched.sfx_volume - 0.5) < 0.001
		and absf(relaunched.ambience_volume - 0.1) < 0.001, "10: volumes restored after a relaunch")
	_check(relaunched.muted and not relaunched.vibration, "10: mute and vibration restored after a relaunch")
	relaunched.queue_free()
	await _frames(1)

	AudioManager.set_muted(false)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "11: unmute restores sound")
	AudioManager.set_music_volume(AudioManager.DEFAULTS["music"])
	AudioManager.set_sfx_volume(AudioManager.DEFAULTS["sfx"])
	AudioManager.set_ambience_volume(AudioManager.DEFAULTS["ambience"])
	AudioManager.set_vibration(true)
	AudioManager.flush_settings()
	startup.queue_free()
	await _frames(2)


## 14: rapid taps don't stack up sounds.
func _test_rapid_tapping() -> void:
	await _wait(0.2)
	var seq := AudioManager.event_seq
	for i in 25:
		AudioManager.play_sfx("tile_select")
	_check(AudioManager.count_requested("tile_select", seq) == 25, "14: 25 rapid requests recorded")
	_check(AudioManager.count_played("tile_select", seq) <= 1, "14: rapid taps play at most one copy at once")
	await _wait(0.2)
	seq = AudioManager.event_seq
	for i in 6:
		AudioManager.play_sfx("tile_match")
		await _wait(0.09)
	var match_cap: int = (AudioCatalog.EFFECTS["tile_match"] as Array)[4]
	_check(AudioManager.count_played("tile_match", seq) <= match_cap,
		"14: overlapping match bells are capped at %d (%d played)" % [match_cap, AudioManager.count_played("tile_match", seq)])


## Musical feedback: quick matches climb the pentatonic bells; a pause, a
## shuffle or a new level starts again from the bottom; undo steps back.
func _test_match_melody() -> void:
	AudioManager.melody_window = 1.0
	AudioManager.reset_melody()
	await _wait(0.3)
	var seq := AudioManager.event_seq
	for i in 4:
		AudioManager.play_match_note()
		await _wait(0.15)
	_check(_match_files(seq) == AudioCatalog.MATCH_NOTES.slice(0, 4), "melody climbs one note per quick match")
	AudioManager.melody_step_back()
	seq = AudioManager.event_seq
	AudioManager.play_match_note()
	_check(_match_files(seq) == AudioCatalog.MATCH_NOTES.slice(3, 4), "after undo the next match replays the undone note")
	await _wait(1.2)
	seq = AudioManager.event_seq
	AudioManager.play_match_note()
	_check(_match_files(seq) == AudioCatalog.MATCH_NOTES.slice(0, 1), "a pause restarts the melody from the lowest note")
	await _wait(0.15)
	AudioManager.reset_melody()
	seq = AudioManager.event_seq
	AudioManager.play_match_note()
	_check(_match_files(seq) == AudioCatalog.MATCH_NOTES.slice(0, 1), "reset (shuffle / new level) restarts the melody")
	for i in 14:
		await _wait(0.1)
		AudioManager.play_match_note()
	_check(AudioManager.melody_step() == AudioCatalog.MATCH_NOTES.size() - 1, "a long streak holds on the top note")
	var ringing := 0
	for i in AudioManager.EFFECT_VOICES:
		if AudioManager.get("_effect_ids")[i] == "tile_match" and AudioManager.call("_voice_busy", i):
			ringing += 1
	_check(ringing <= int((AudioCatalog.EFFECTS["tile_match"] as Array)[4]), "a long fast streak still rings at most 4 bells (%d)" % ringing)
	for note in AudioCatalog.MATCH_NOTES:
		_check(ResourceLoader.exists(note), "melody note %s is installed" % note.get_file())
	AudioManager.melody_window = 8.0
	AudioManager.reset_melody()

	# In play: three quick matches on a real board ring three rising notes.
	GameSession.current_level = 4
	var screen: Control = GAME_SCENE.instantiate()
	_frame.add_child(screen)
	await _frames(3)
	var level := LevelCatalog.get_level(4)
	var deal := BoardGenerator.generate(level.load_layout().build_geometry(), level.face_pool(), level.deal_seed)
	seq = AudioManager.event_seq
	for k in 3:
		await _wait(0.12)
		await _click_tile(screen, deal.solution[k].x)
		await _click_tile(screen, deal.solution[k].y)
	await _wait(0.5)
	_check(_match_files(seq) == AudioCatalog.MATCH_NOTES.slice(0, 3), "in play, quick matches ring rising bells")
	await _click(screen.get_node("%UndoButton"))
	_check(AudioManager.melody_step() == 1, "undoing a match steps the melody back")
	await _wait(0.3)
	await _click(screen.get_node("%ShuffleButton"))
	_check(AudioManager.melody_step() == -1, "a shuffle restarts the melody")
	screen.queue_free()
	await _frames(2)


## A wrong pair plays the mistake knock; losing plays the falling koto once.
func _test_loss_sounds() -> void:
	GameSession.current_level = 1
	var screen: Control = GAME_SCENE.instantiate()
	_frame.add_child(screen)
	await _frames(3)
	var model: BoardModel = screen.get("_model")
	var free := model.free_tiles()
	var wrong := Vector2i(-1, -1)
	for a in free:
		for b in free:
			if wrong.x < 0 and a != b and not TileCatalog.faces_match(model.faces[a], model.faces[b]):
				wrong = Vector2i(a, b)
	var seq := AudioManager.event_seq
	screen.call("_on_tile_pressed", wrong.x)
	screen.call("_on_tile_pressed", wrong.y)
	_check(AudioManager.count_played("mistake", seq) == 1, "a wrong pair plays the mistake sound")
	_check(AudioManager.count_requested("tile_select", seq) == 1, "only the first tile played the select sound")
	seq = AudioManager.event_seq
	screen.set("_time_left", 0.2)
	await _wait(0.5)
	_check(AudioManager.count_played("level_failed", seq) == 1, "losing plays the level-failed sound once")
	screen.queue_free()
	await _frames(2)


func _match_files(since_seq: int) -> PackedStringArray:
	var files := PackedStringArray()
	for event in AudioManager.history:
		if int(event["seq"]) >= since_seq and event["id"] == "tile_match" and event["played"]:
			files.append(str(event["file"]))
	return files


## Phones: nothing plays while the app is in the background.
func _test_backgrounding() -> void:
	AudioManager.notification(NOTIFICATION_APPLICATION_PAUSED)
	_check(AudioManager.is_suspended(), "audio pauses when the app goes to the background")
	AudioManager.notification(NOTIFICATION_APPLICATION_RESUMED)
	_check(not AudioManager.is_suspended(), "audio resumes when the app returns")
	await _frames(1)


func _bus_near(bus: String, linear: float) -> bool:
	return absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus)) - linear_to_db(linear)) < 0.05


func _click_tile(screen: Control, index: int) -> void:
	var board: BoardView = screen.get_node("%Board")
	var view := board.tile(index)
	await _click_at(view.get_global_transform() * view.face_center())


func _click(control: Control) -> void:
	await _click_at(control.get_global_rect().get_center())


func _click_at(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		get_viewport().push_input(event, true)
	await _frames(1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
