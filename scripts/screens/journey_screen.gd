extends Control
## The journey map: every level as a stop on a winding stepping-stone path
## over a calm garden backdrop (JourneyWorld, which only builds the stops on
## screen, so the whole 1000-level journey scrolls smoothly). Swipe to travel
## along it; a lotus badge marks where the player is. Shows stars, difficulty
## and what is locked; tapping an open level shows its card with a Play button.

var _card_level := 0
## The level the journey continues from (1-based).
var _current := 1
var _toast_tween: Tween

@onready var _world: JourneyWorld = %World
@onready var _background: TextureRect = %Background
@onready var _banner_gap: Control = %BannerGap
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
	# The map paints its own garden backdrop.
	_background.hide()
	# Swipes inside the level card must not move the map behind it.
	_world.input_blocker = func() -> bool: return _dialog.visible
	refresh()
	_world.setup(LevelCatalog.count(), _setup_node)
	_world.focus_level(_current, false)
	_celebrate_unlock.call_deferred()
	# Falling petals are decoration: off with reduced animations.
	($Petals as CPUParticles2D).emitting = not Motion.reduced
	($Petals as CPUParticles2D).visible = not Motion.reduced
	AdsManager.show_banner()
	_banner_gap.custom_minimum_size.y = AdsManager.banner_height()


func _exit_tree() -> void:
	AdsManager.hide_banner()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		if _dialog.visible:
			_dialog.close()
		else:
			GameSession.go_home()


## Re-reads progress into the stops on screen.
func refresh() -> void:
	var progress := GameSession.progress
	var count := LevelCatalog.count()
	_current = progress.current_level(count)
	_world.set_current(_current - 1)
	_world.refresh_nodes()
	_stars_value.text = "%d / %d" % [progress.total_stars(count), count * LevelRating.MAX_STARS]


## Fills a stop as it comes into view (the map reuses stops while scrolling).
func _setup_node(node: LevelNode, number: int) -> void:
	if not node.has_meta("wired"):
		node.set_meta("wired", true)
		node.pressed.connect(_on_level_pressed)
	var progress := GameSession.progress
	node.setup(LevelCatalog.get_level(number), progress.stars(number), progress.is_unlocked(number), number == _current)


## The stop for level `number` if it is on screen (else null).
func level_node(number: int) -> LevelNode:
	return _world.node_for(number)


func _celebrate_unlock() -> void:
	var level := GameSession.just_unlocked
	GameSession.just_unlocked = 0
	if level <= 0 or level > LevelCatalog.count():
		return
	AudioManager.play_sfx("unlock")
	# The lotus badge walks from the level just cleared to the new one.
	_world.focus_level(level, false)
	_world.set_current(level - 1, level - 2)
	var node := _world.node_for(level)
	if node:
		node.play_unlock()
	_show_toast("Level %d unlocked: %s" % [level, LevelCatalog.get_level(level).title])


func _on_level_pressed(number: int) -> void:
	var progress := GameSession.progress
	if not progress.is_unlocked(number):
		var node := _world.node_for(number)
		if node:
			node.play_locked_nudge()
		AudioManager.play_sfx("tile_blocked")
		_show_toast("Clear Level %d to unlock this level." % (number - 1))
		return
	AudioManager.play_sfx("button_click")
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
	# A new toast replaces the old one, so the old fade can't hide it early.
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_toast.hide)
