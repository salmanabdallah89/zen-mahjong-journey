extends Control
## The journey map: every level is a mahjong tile on a gold thread winding over
## the garden, full screen (JourneyWorld, which only builds the stops on screen,
## so the whole 1000-level journey scrolls smoothly). Swipe to travel along it;
## a lotus badge marks where the player is. A floating header names the chapter
## in view and its progress; the Play button starts the next level in one tap;
## tapping any open tile slides up its level sheet.

## The level the journey continues from (1-based).
var _current := 1
var _toast_tween: Tween
## Chapter the header shows (-1: needs refreshing).
var _shown_chapter := -1

@onready var _world: JourneyWorld = %World
@onready var _background: TextureRect = %Background
@onready var _banner_gap: Control = %BannerGap
@onready var _stars_value: Label = %StarsValue
@onready var _back: Button = %BackButton
@onready var _header: Control = %Header
@onready var _title: Label = %Title
@onready var _caption: Label = %Caption
@onready var _chapter_bar: ProgressBar = %ChapterBar
@onready var _play: Button = %PlayButton
@onready var _sheet: LevelSheet = %Sheet
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel


func _ready() -> void:
	_back.pressed.connect(GameSession.go_home)
	_play.pressed.connect(_on_play_pressed)
	_sheet.play_requested.connect(GameSession.play_level)
	_toast.hide()
	AudioManager.play_music("main_menu")
	AudioManager.set_ambience(AudioCatalog.MENU_AMBIENCE)
	# The map paints its own garden backdrop.
	_background.hide()
	# Swipes inside the level sheet must not move the map behind it, and the
	# floating controls are not part of the map.
	_world.input_blocker = func() -> bool: return _sheet.visible
	_world.ui_hit = _covers_map
	_world.camera_moved.connect(_on_camera_moved)
	refresh()
	_world.setup(LevelCatalog.count(), _setup_node)
	_world.focus_level(_current, false)
	_show_chapter()
	_celebrate_unlock.call_deferred()
	# Falling petals are decoration: off with reduced animations.
	($Petals as CPUParticles2D).emitting = not Motion.reduced
	($Petals as CPUParticles2D).visible = not Motion.reduced
	# A real banner arrives after it loads: leave room for it when it does.
	AdsManager.banner_changed.connect(_fit_banner_gap)
	AdsManager.show_banner()
	_fit_banner_gap()


func _exit_tree() -> void:
	AdsManager.hide_banner()


func _fit_banner_gap() -> void:
	_banner_gap.custom_minimum_size.y = AdsManager.banner_height()
	_sheet.bottom_gap = AdsManager.banner_height()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		if _sheet.visible:
			_sheet.close()
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
	_play.text = "Play Level %d" % _current
	_shown_chapter = -1
	_show_chapter()


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


## The level sheet: difficulty, size, limits, best result and the star rules.
func _open_card(number: int) -> void:
	var level := LevelCatalog.get_level(number)
	var progress := GameSession.progress
	_sheet.open(level, level.load_layout().tile_count(), progress.stars(number), progress.best_time_left(number))


func _on_play_pressed() -> void:
	GameSession.play_level(_current)


func _covers_map(point: Vector2) -> bool:
	return _header.get_global_rect().has_point(point) or _play.get_global_rect().has_point(point)


func _on_camera_moved(_camera: float) -> void:
	_show_chapter()


## The header follows the chapter in view: garden name and levels cleared.
func _show_chapter() -> void:
	var chapter := int(_world.chapter_at_camera().x)
	if chapter == _shown_chapter:
		return
	_shown_chapter = chapter
	var count := LevelCatalog.count()
	var first := chapter * LevelRecipe.CHAPTER_SIZE + 1
	var last := mini(first + LevelRecipe.CHAPTER_SIZE - 1, count)
	var cleared := 0
	for number in range(first, last + 1):
		cleared += 1 if GameSession.progress.is_cleared(number) else 0
	_title.text = BackgroundStyle.garden_name(LevelRecipe.garden_of_chapter(chapter))
	_caption.text = "CHAPTER %d · %d OF %d" % [chapter + 1, cleared, last - first + 1]
	_chapter_bar.max_value = last - first + 1
	_chapter_bar.value = cleared


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
