extends Control
## The journey map: every level as a stop on a stepping-stone path that
## runs away into the garden in perspective (JourneyWorld). Swipe to travel
## along it. Shows stars, difficulty and what is locked; tapping an open level
## shows its card with a Play button.

const NODE_SCENE := preload("res://scenes/components/level_node.tscn")
## How far the background drifts over the whole journey (parallax).
const PARALLAX := 160.0

var _nodes: Array[LevelNode] = []
var _card_level := 0

@onready var _world: JourneyWorld = %World
@onready var _background: TextureRect = %Background
@onready var _stars_value: Label = %StarsValue
@onready var _back: Button = %BackButton
@onready var _dialog: ModalDialog = %Dialog
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel


func _ready() -> void:
	_back.pressed.connect(GameSession.go_home)
	_dialog.hide()
	_toast.hide()
	AudioManager.play_music("main_menu")
	AudioManager.set_ambience(AudioCatalog.MENU_AMBIENCE)
	for level in LevelCatalog.levels():
		var node: LevelNode = NODE_SCENE.instantiate()
		node.pressed.connect(_on_level_pressed)
		_nodes.append(node)
	_world.set_nodes(_nodes)
	_world.camera_moved.connect(_on_camera_moved)
	refresh()
	_world.focus_level(GameSession.progress.current_level(LevelCatalog.count()), false)
	_on_camera_moved(_world.camera)
	_celebrate_unlock.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		if _dialog.visible:
			_dialog.close()
		else:
			GameSession.go_home()


## Re-reads progress into every stop.
func refresh() -> void:
	var progress := GameSession.progress
	var count := LevelCatalog.count()
	var current := progress.current_level(count)
	for i in _nodes.size():
		var level := LevelCatalog.get_level(i + 1)
		_nodes[i].setup(level, progress.stars(level.number), progress.is_unlocked(level.number), level.number == current)
	_world.current_index = current - 1
	_stars_value.text = "%d / %d" % [progress.total_stars(count), count * LevelRating.MAX_STARS]


func level_node(number: int) -> LevelNode:
	return _nodes[number - 1]


## Background drifts slightly as you travel, for depth.
func _on_camera_moved(camera: float) -> void:
	var span := maxf(_world.max_camera() - _world.min_camera(), 0.001)
	var progress := (camera - _world.min_camera()) / span
	# The background is PARALLAX taller above and below; travelling forward
	# lets the scenery come toward you.
	var shift := lerpf(-PARALLAX, PARALLAX, progress)
	_background.offset_top = -PARALLAX + shift
	_background.offset_bottom = PARALLAX + shift


func _celebrate_unlock() -> void:
	var level := GameSession.just_unlocked
	GameSession.just_unlocked = 0
	if level <= 0 or level > _nodes.size():
		return
	AudioManager.play_sfx("unlock")
	_world.focus_level(level)
	_nodes[level - 1].play_unlock()
	_show_toast("Level %d unlocked: %s" % [level, LevelCatalog.get_level(level).title])


func _on_level_pressed(number: int) -> void:
	var progress := GameSession.progress
	if not progress.is_unlocked(number):
		_nodes[number - 1].play_locked_nudge()
		AudioManager.play_sfx("tile_blocked")
		_show_toast("Clear Level %d to unlock this level." % (number - 1))
		return
	_open_card(number)


## Level card: difficulty, size, limits, best result and the star rules.
func _open_card(number: int) -> void:
	_card_level = number
	var level := LevelCatalog.get_level(number)
	var progress := GameSession.progress
	var tiles := level.load_layout().tile_count()
	var lines := PackedStringArray()
	lines.append("%s · %d tiles · %d:%02d · %d hearts" % [LevelRating.difficulty_label(level.difficulty),
		tiles, floori(level.time_limit / 60.0), level.time_limit % 60, level.mistake_limit])
	var best := progress.best_time_left(number)
	if best >= 0.0:
		var whole := ceili(best)
		lines.append("Best: %d of 3 stars, %d:%02d left" % [progress.stars(number), floori(whole / 60.0), whole % 60])
	else:
		lines.append("Not cleared yet")
	lines.append("")
	lines.append(LevelRating.RULES)
	_dialog.open("Level %d · %s" % [number, level.title], "\n".join(lines))
	_dialog.set_stars(progress.stars(number))
	_dialog.add_action("Play", _play_card_level, true)
	_dialog.add_action("Close", func() -> void: pass)


func _play_card_level() -> void:
	GameSession.play_level(_card_level)


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.show()
	_toast.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tween.tween_interval(2.4)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_toast.hide)
