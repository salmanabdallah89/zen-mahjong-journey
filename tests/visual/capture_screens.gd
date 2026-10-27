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
	print("Screenshots written to ", ProjectSettings.globalize_path(_out_dir))
	get_tree().quit()


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


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_out_dir.path_join(name + ".png"))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
