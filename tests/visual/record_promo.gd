extends Node
## Films a short promo of the real game playing itself, for social media.
## Run in Godot's movie mode (not headless), then cut and encode with ffmpeg:
##   godot --path . --write-movie <dir>/promo.avi --fixed-fps 60 res://tests/visual/record_promo.tscn [-- words]
## with a temporary override.cfg that sets the window to 1080 x 1920.
## It prints "KEEP <start> <end>" (seconds) for every part worth keeping; the
## parts start and end on a plain forest frame, so they join without a seam.
## Music is muted here (each screen would restart it) and laid under the
## finished film instead.

const STARTUP_SCENE := preload("res://scenes/screens/startup_screen.tscn")
const GAME_SCENE := preload("res://scenes/screens/game_screen.tscn")
const FOREST := Color("354F44")
const NIGHT := Color("273B50")
const FPS := 60.0

var _frame := 0
var _keep_from := 0.0
var _fade: ColorRect
var _layer: CanvasLayer
var _taps: Control


func _process(_delta: float) -> void:
	_frame += 1


func _ready() -> void:
	# The film must not touch the player's journey or settings.
	GameSession.progress = ProgressStore.new("user://promo_progress.cfg")
	GameSession.progress.reset()
	GameSession.tutorial_settings_path = "user://promo_tutorial.cfg"
	GameSession.set_tutorial_seen("completed")
	GameSession.badge_reveals_enabled = false
	GameSession.pause_on_focus_loss = false
	AdsManager.provider = "none"
	var manager := TileCollectionManager
	var real_settings := manager.settings_path
	manager.settings_path = "user://promo_settings.cfg"
	SafeConfig.remove_all(manager.settings_path)
	manager.restore()
	for number in range(1, 13):
		GameSession.progress.record_clear(number, 3 if number % 4 != 0 else 2, 90.0, 10)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	# The desktop shrinks a window taller than the monitor; keep the phone's
	# 9:16 canvas whatever the window became, or the sides are cut off.
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_build_overlay()
	await _frames(8)

	if OS.get_cmdline_user_args().has("words"):
		await _film_words(OS.get_cmdline_user_args().has("ar"))
	else:
		await _film_main()

	manager.select("classic")
	SafeConfig.remove_all(manager.settings_path)
	manager.settings_path = real_settings
	manager.restore()
	GameSession.badge_reveals_enabled = true
	GameSession.pause_on_focus_loss = true
	GameSession.progress.reset()
	SafeConfig.remove_all(GameSession.progress.path)
	GameSession.progress = ProgressStore.new()
	SafeConfig.remove_all(GameSession.tutorial_settings_path)
	GameSession.tutorial_settings_path = UserSettings.DEFAULT_PATH
	get_tree().quit()


## The main film: home, a combo run, another collection, a Perfect Clear,
## the journey map and the end card.
func _film_main() -> void:
	var manager := TileCollectionManager
	# 1. The home screen.
	var home := STARTUP_SCENE.instantiate()
	add_child(home)
	await _frames(20)
	await _open()
	await _wait(2.0)
	await _close()
	home.queue_free()

	# 2. A run of quick matches in the Zen Garden: the combo climbs.
	manager.select("zen_garden")
	await _play_board(13, 7, 0.30, 0.60)

	# 3. Another collection.
	manager.select("animals")
	await _play_board(24, 4, 0.32, 0.70)

	# 4. The last pairs of a Perfect Clear, and its stars.
	manager.select("zen_garden")
	GameSession.current_level = 5
	var clear: Control = GAME_SCENE.instantiate()
	add_child(clear)
	await _wait(0.6)
	var level := LevelCatalog.get_level(5)
	var solution: Array = BoardGenerator.generate(level.load_layout().build_geometry(), level.face_pool(), level.deal_seed).solution
	for i in solution.size() - 2:
		clear.call("_on_tile_pressed", solution[i].x)
		clear.call("_on_tile_pressed", solution[i].y)
	await _wait(2.4)
	await _open()
	for i in range(solution.size() - 2, solution.size()):
		clear.set("_elapsed", 132.0)
		clear.set("_time_left", float(level.time_limit) - 132.0)
		await _tap(clear, solution[i].x)
		await _wait(0.34)
		await _tap(clear, solution[i].y)
		await _wait(0.8)
	await _wait(3.0)
	await _close()
	clear.queue_free()

	# 5. The journey map.
	var journey: Control = load("res://scenes/screens/journey_screen.tscn").instantiate()
	add_child(journey)
	await _frames(30)
	await _open()
	await _wait(1.8)
	await _close()
	journey.queue_free()

	# 6. The end card over the home screen.
	manager.select("zen_garden")
	var last := STARTUP_SCENE.instantiate()
	add_child(last)
	var card := _end_card([["Zen Mahjong", &"title"], ["Journey", &"title"], ["", &""],
		["Free on Google Play", &"line"], ["Play free in your browser too", &"small"]])
	await _frames(20)
	await _open()
	await _wait(2.6)
	await _close()
	card.queue_free()
	last.queue_free()


## The Word Garden film (add "-- words" to the command): learning a language
## by matching each picture with its word. With "-- words ar" it is made for
## Arabic speakers: Arabic cards, learning English, and a stage whose words
## pair with their Arabic meaning.
func _film_words(arabic: bool) -> void:
	var learn := "en" if arabic else "es"
	var speak := "ar" if arabic else "en"
	var cards: Array = [["Learn a language", "while you play"], ["Match each picture", "with its word"],
		["Spanish · French", "Arabic · English"]]
	var ending: Array = [["Word Garden", &"title"], ["", &""], ["in Zen Mahjong Journey", &"line"],
		["Free on Google Play", &"line"], ["Play free in your browser too", &"small"]]
	if arabic:
		cards = [["تعلّم لغة جديدة", "وأنت تلعب"], ["طابق كل صورة", "مع كلمتها"],
			["وكل كلمة", "مع معناها بالعربية"]]
		ending = [["Word Garden", &"title"], ["", &""], ["الإنجليزية · الفرنسية · الإسبانية", &"line"],
			["مجانًا على Google Play", &"line"], ["في لعبة Zen Mahjong Journey", &"small"]]
	TileCollectionManager.select("zen_garden")
	var native := GameSession.word_native
	GameSession.word_native = speak
	await _card(cards[0], 2.0)

	# The language choice.
	var words: Control = load(GameSession.WORDS_SCENE).instantiate()
	words.settings_path = "user://promo_words.cfg"
	var word_settings := UserSettings.new(words.settings_path)
	word_settings.set_value(words.SETTINGS_SECTION, words.SETTINGS_KEY, learn)
	word_settings.set_value(words.SETTINGS_SECTION, words.SETTINGS_KEY_NATIVE, speak)
	for stage in range(1, 8):
		GameSession.progress.record_word_stage(learn, stage, 3 if stage % 3 != 0 else 2, PackedStringArray(), PackedStringArray())
	add_child(words)
	await _frames(30)
	words.get_node("%LanguagePanel").show()
	await _frames(10)
	await _open()
	await _wait(2.4)
	await _close()
	words.queue_free()

	await _card(cards[1], 1.8)
	await _play_words(learn, 1, 6, false)
	await _card(cards[2], 1.8)
	if arabic:
		# Stage 12 teaches They, Yes, No and Please: words without a picture.
		await _play_words(learn, 12, 4, true)
	else:
		await _play_words("fr", 1, 4, false)

	# The map of stages.
	GameSession.word_language = ""
	var stages: Control = load(GameSession.WORDS_SCENE).instantiate()
	stages.settings_path = "user://promo_words.cfg"
	add_child(stages)
	await _frames(30)
	await _open()
	await _wait(2.0)
	await _close()
	stages.queue_free()

	var card := _end_card(ending)
	await _frames(20)
	await _open()
	await _wait(2.8)
	await _close()
	card.queue_free()
	GameSession.word_native = native
	GameSession.word_language = ""
	SafeConfig.remove_all("user://promo_words.cfg")


## Opens a Word Garden stage and matches pictures with their words, picture
## first, slowly enough to read each word.
func _play_words(language: String, stage: int, pairs: int, meanings_first: bool) -> void:
	GameSession.word_language = language
	GameSession.word_stage = stage
	var screen: Control = GAME_SCENE.instantiate()
	add_child(screen)
	await _frames(20)
	await _open()
	await _wait(1.2)
	var model: BoardModel = screen.get("_model")
	for i in pairs:
		var matches := model.available_matches()
		if matches.is_empty():
			break
		var pair: Vector2i = matches[0]
		if meanings_first:
			for candidate: Vector2i in matches:
				if not WordCatalog.has_picture(WordCatalog.id_of(model.face_of(candidate.x))):
					pair = candidate
					break
		var first := pair.x if WordCatalog.is_picture(model.face_of(pair.x)) else pair.y
		var second := pair.y if first == pair.x else pair.x
		await _tap(screen, first)
		await _wait(0.55)
		await _tap(screen, second)
		await _wait(1.0)
	await _wait(0.4)
	await _close()
	screen.queue_free()


## A line or two of text on the plain forest frame between two parts.
func _card(lines: Array, seconds: float) -> void:
	_keep_from = _frame / FPS
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	box.modulate.a = 0.0
	_layer.add_child(box)
	for text: String in lines:
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("F6EEDF"))
		label.add_theme_font_size_override("font_size", 84)
		box.add_child(label)
	await _frames(4)
	var tween := create_tween()
	tween.tween_property(box, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(seconds)
	tween.tween_property(box, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	await tween.finished
	box.queue_free()
	await _frames(4)
	print("KEEP %.3f %.3f" % [_keep_from, _frame / FPS])


## Opens a level and plays the first pairs of its solution at a human pace.
func _play_board(number: int, pairs: int, between_taps: float, between_pairs: float) -> void:
	GameSession.current_level = number
	var screen: Control = GAME_SCENE.instantiate()
	add_child(screen)
	await _frames(20)
	await _open()
	await _wait(1.3)
	var level := LevelCatalog.get_level(number)
	var solution: Array = BoardGenerator.generate(level.load_layout().build_geometry(), level.face_pool(), level.deal_seed).solution
	for i in mini(pairs, solution.size()):
		await _tap(screen, solution[i].x)
		await _wait(between_taps)
		await _tap(screen, solution[i].y)
		await _wait(between_pairs)
	await _wait(0.6)
	await _close()
	screen.queue_free()


## A tap on a tile, with a soft ring where the finger lands.
func _tap(screen: Control, index: int) -> void:
	var board: BoardView = screen.get_node("%Board")
	var view := board.tile(index)
	_ring(view.get_global_transform() * view.face_center())
	await _frames(4)
	screen.call("_on_tile_pressed", index)


func _ring(point: Vector2) -> void:
	var ring := TapRing.new()
	ring.position = point
	_taps.add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "progress", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(ring.queue_free)


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_taps = Control.new()
	_taps.set_anchors_preset(Control.PRESET_FULL_RECT)
	_taps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_taps)
	_fade = ColorRect.new()
	_fade.color = FOREST
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)


func _end_card(lines: Array) -> Control:
	var veil := ColorRect.new()
	veil.color = Color(NIGHT, 1.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(veil)
	_layer.move_child(veil, 0)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 36)
	veil.add_child(box)
	for line: Array in lines:
		var label := Label.new()
		label.text = str(line[0])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if line[1] == &"title":
			label.theme_type_variation = &"TitleLabel"
		elif line[1] != &"":
			# A film-only card, not game UI: sized here instead of in the theme.
			label.add_theme_color_override("font_color", Color("F6EEDF"))
			label.add_theme_font_size_override("font_size", 64 if line[1] == &"line" else 40)
		box.add_child(label)
	return veil


func _open() -> void:
	_keep_from = _frame / FPS
	await _frames(4)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	await tween.finished


func _close() -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	await tween.finished
	await _frames(4)
	print("KEEP %.3f %.3f" % [_keep_from, _frame / FPS])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


class TapRing extends Control:
	var progress := 0.0:
		set(value):
			progress = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var alpha := 1.0 - progress
		draw_circle(Vector2.ZERO, 26.0 + 30.0 * progress, Color(0.965, 0.933, 0.875, 0.30 * alpha))
		draw_arc(Vector2.ZERO, 30.0 + 44.0 * progress, 0.0, TAU, 48, Color(0.78, 0.647, 0.416, 0.9 * alpha), 6.0, true)
