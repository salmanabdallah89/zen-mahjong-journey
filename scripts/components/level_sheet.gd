class_name LevelSheet
extends Control
## The level card: a sheet that slides up from the bottom of the journey map,
## with the level's tile, its stars, what it asks of the player and how to earn
## each star. Tapping the dimmed map or Not Now closes it. With reduced
## animations it fades in place.

signal play_requested(level_number: int)

const STAR := preload("res://assets/ui/icons/icon_star.png")
const TILE := preload("res://assets/tiles/bodies/tile_body_zen_ivory.png")
const DIM := Color(0.15294118, 0.23137255, 0.3137255, 0.62)
const STAR_DARK := Color(0.25, 0.25, 0.25, 0.4)
const SLIDE_SECONDS := 0.32

## Room to keep free under the sheet (the banner ad).
var bottom_gap := 0.0

var _level_number := 0
var _stars_earned := 0
var _summary := ""
var _dim: ColorRect
var _panel: PanelContainer
var _symbol: TextureRect
var _caption: Label
var _title: Label
var _difficulty: Label
var _stars: Array[TextureRect] = []
var _goal_stars: Array[TextureRect] = []
var _tiles_value: Label
var _time_value: Label
var _hearts_value: Label
var _best: Label
var _play: Button
var _tween: Tween


func _ready() -> void:
	_build()
	hide()


## Shows a level: stars earned so far and the best time left (negative: not
## cleared yet).
func open(level: LevelCatalog.LevelDefinition, tile_count: int, earned_stars: int, best_time_left: float) -> void:
	_level_number = level.number
	_stars_earned = earned_stars
	_caption.text = "LEVEL %d" % level.number
	_title.text = level.title
	var difficulty := LevelRating.difficulty_label(level.difficulty)
	_difficulty.text = difficulty.to_upper()
	_symbol.texture = LevelNode.symbol_for(level.number)
	_symbol.modulate.a = 1.0 if earned_stars > 0 else LevelNode.UNEARNED_SYMBOL_ALPHA
	var clock := "%d:%02d" % [floori(level.time_limit / 60.0), level.time_limit % 60]
	_tiles_value.text = str(tile_count)
	_time_value.text = clock
	_hearts_value.text = str(level.mistake_limit)
	for i in LevelRating.MAX_STARS:
		var lit := i < earned_stars
		_stars[i].modulate = Color.WHITE if lit else STAR_DARK
		_goal_stars[i].modulate = Color.WHITE if lit else STAR_DARK
	if best_time_left >= 0.0:
		var whole := ceili(best_time_left)
		_best.text = "Best: %d of 3 stars, %d:%02d left" % [earned_stars, floori(whole / 60.0), whole % 60]
	else:
		_best.text = "Not cleared yet"
	_summary = "%s · %d tiles · %s · %d hearts\n%s" % [difficulty, tile_count, clock, level.mistake_limit, _best.text]
	show()
	_slide_in()


func close() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	hide()


func title_text() -> String:
	return "Level %d · %s" % [_level_number, _title.text]


func summary_text() -> String:
	return _summary


func stars_shown() -> int:
	return _stars_earned


func play_button() -> Button:
	return _play


func _slide_in() -> void:
	if _tween:
		_tween.kill()
	var height := _panel.get_combined_minimum_size().y
	_place_panel(0.0, height)
	_tween = create_tween().set_parallel()
	_tween.tween_property(_dim, "modulate:a", 1.0, Motion.duration(SLIDE_SECONDS))
	if Motion.reduced:
		_place_panel(1.0, height)
		_panel.modulate.a = 0.0
		_tween.tween_property(_panel, "modulate:a", 1.0, Motion.duration(SLIDE_SECONDS))
	else:
		_panel.modulate.a = 1.0
		_tween.tween_method(_place_panel.bind(height), 0.0, 1.0, SLIDE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## `shown` 0: just below the screen, 1: resting above the gap.
func _place_panel(shown: float, height: float) -> void:
	var rest := -bottom_gap
	var bottom := lerpf(height, rest, shown)
	_panel.offset_bottom = bottom
	_panel.offset_top = bottom - height


func _on_dim_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		close()


func _on_play_pressed() -> void:
	close()
	play_requested.emit(_level_number)


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = DIM
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.theme_type_variation = &"SheetPanel"
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 26)
	_panel.add_child(column)
	column.add_child(_build_head())
	column.add_child(_build_stats())
	column.add_child(_build_goals())
	_best = _label("", &"HudCaptionLabel")
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_best)
	column.add_child(_build_buttons())


func _build_head() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	var tile := TextureRect.new()
	tile.name = "Tile"
	tile.texture = TILE
	tile.custom_minimum_size = Vector2(186, 211)
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tile.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	row.add_child(tile)
	_symbol = TextureRect.new()
	_symbol.name = "Symbol"
	_symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_symbol.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_symbol.position = Vector2(22, 32)
	_symbol.size = Vector2(135, 135)
	tile.add_child(_symbol)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	_caption = _label("", &"HudCaptionLabel")
	words.add_child(_caption)
	_title = _label("", &"HudValueLabel")
	words.add_child(_title)
	_difficulty = _label("", &"HudCaptionLabel")
	words.add_child(_difficulty)
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 0)
	words.add_child(stars)
	for i in LevelRating.MAX_STARS:
		var star := _star(72.0)
		_stars.append(star)
		stars.add_child(star)
	return row


func _build_stats() -> Control:
	var row := HBoxContainer.new()
	_tiles_value = _stat(row, "TILES")
	_time_value = _stat(row, "TIME")
	_hearts_value = _stat(row, "HEARTS")
	return row


func _stat(row: HBoxContainer, caption: String) -> Label:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", -4)
	row.add_child(box)
	var value := _label("", &"HudValueLabel")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	var name_label := _label(caption, &"HudCaptionLabel")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	return value


## One line per star, from LevelRating's rules, with that star lit once earned.
func _build_goals() -> Control:
	var goals := VBoxContainer.new()
	goals.add_theme_constant_override("separation", 6)
	var rules := LevelRating.RULES.split("\n")
	for i in LevelRating.MAX_STARS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		goals.add_child(row)
		var star := _star(52.0)
		_goal_stars.append(star)
		row.add_child(star)
		var line := _label(rules[i], &"DialogBodyLabel")
		line.add_theme_font_size_override("font_size", 36)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(line)
	return goals


func _build_buttons() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var later := Button.new()
	later.name = "NotNow"
	later.text = "Not Now"
	later.theme_type_variation = &"SecondaryButton"
	later.custom_minimum_size = Vector2(300, 136)
	later.pressed.connect(close)
	row.add_child(later)
	_play = Button.new()
	_play.name = "Play"
	_play.text = "Play"
	_play.custom_minimum_size = Vector2(300, 136)
	_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play.pressed.connect(_on_play_pressed)
	row.add_child(_play)
	return row


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label


func _star(side: float) -> TextureRect:
	var star := TextureRect.new()
	star.texture = STAR
	star.custom_minimum_size = Vector2(side, side)
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return star
