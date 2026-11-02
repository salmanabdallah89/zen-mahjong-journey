extends Control
## The Badges page: how many ranks are earned, the badge closest to its next
## rank, and every family by group. Tapping a medal opens its card with all
## three ranks. Opening the page shows what is new, then marks it seen.

const MEDAL_SIZE := Vector2(208, 208)
const CELL_WIDTH := 320.0
const ROW_MEDAL_SIZE := Vector2(96, 96)

## Family ids that were new when the page opened.
var _fresh := PackedStringArray()
var _cells := {}
var _card_id := ""

@onready var _back: Button = %BackButton
@onready var _count: Label = %CountLabel
@onready var _bar: ProgressBar = %CountBar
@onready var _sections: VBoxContainer = %Sections
@onready var _next_card: Button = %NextCard
@onready var _next_medal: BadgeMedal = %NextMedal
@onready var _next_name: Label = %NextName
@onready var _next_goal: Label = %NextGoal
@onready var _next_bar: ProgressBar = %NextBar
@onready var _card: Control = %BadgeCard
@onready var _card_panel: Control = %CardPanel
@onready var _card_medal: BadgeMedal = %CardMedal
@onready var _card_name: Label = %CardName
@onready var _card_rank: Label = %CardRank
@onready var _card_ranks: VBoxContainer = %CardRanks
@onready var _card_close: Button = %CardClose


func _ready() -> void:
	_back.pressed.connect(GameSession.go_home)
	_card_close.pressed.connect(close_card)
	_card.hide()
	var store := GameSession.progress
	BadgeBook.award(store, LevelCatalog.count())
	_fresh = store.new_badges()
	store.clear_new_badges()
	var earned := BadgeBook.earned_ranks(store)
	_count.text = "%d of %d earned" % [earned, BadgeBook.total_ranks()]
	_bar.max_value = BadgeBook.total_ranks()
	_bar.value = earned
	_show_next()
	for group in BadgeBook.GROUPS:
		_add_section(group)
	AudioManager.play_music("main_menu")
	AudioManager.set_ambience(AudioCatalog.MENU_AMBIENCE)


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or not is_node_ready():
		return
	if _card.visible:
		close_card()
	else:
		GameSession.go_home()


## The button for a family's medal (tests press it).
func cell(family_id: String) -> Button:
	return _cells.get(family_id)


func card_id() -> String:
	return _card_id if _card.visible else ""


func close_card() -> void:
	_card.hide()


func _show_next() -> void:
	var entry := BadgeBook.closest(GameSession.progress, LevelCatalog.count())
	_next_card.visible = not entry.is_empty()
	if entry.is_empty():
		return
	var rank := GameSession.progress.badge_rank(entry.id)
	var value := BadgeBook.value_of(entry, GameSession.progress, LevelCatalog.count())
	var goal := BadgeBook.next_goal(entry, rank)
	_next_medal.setup(entry, rank)
	_next_name.text = "%s · %s" % [entry.name, BadgeBook.RANK_NAMES[rank + 1]]
	_next_goal.text = "%s  (%s of %s)" % [BadgeBook.goal_text(entry, rank + 1),
		ScoreMeter.format_points(value), ScoreMeter.format_points(goal)]
	_next_bar.value = BadgeBook.next_share(entry, value, rank) * 100.0
	_next_card.pressed.connect(open_card.bind(str(entry.id)))


func _add_section(group: String) -> void:
	var heading := Label.new()
	heading.text = group
	heading.theme_type_variation = &"CardTitleLabel"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sections.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 20)
	_sections.add_child(grid)
	for entry in BadgeBook.families_in(group):
		var button := _make_cell(entry)
		grid.add_child(button)
		_cells[entry.id] = button


func _make_cell(entry: Dictionary) -> Button:
	var store := GameSession.progress
	var rank := store.badge_rank(entry.id)
	var button := Button.new()
	button.name = str(entry.id)
	button.theme_type_variation = &"BadgeCell"
	button.custom_minimum_size = Vector2(CELL_WIDTH, 340)
	button.focus_mode = Control.FOCUS_NONE
	# Lets a swipe that starts on a medal scroll the page.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(open_card.bind(str(entry.id)))
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	button.add_child(column)
	var medal := BadgeMedal.new()
	medal.custom_minimum_size = MEDAL_SIZE
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(medal)
	medal.setup(entry, rank)
	var title := Label.new()
	title.text = str(entry.name)
	title.theme_type_variation = &"BadgeNameLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var status := Label.new()
	status.theme_type_variation = &"CardStatusLabel"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.text = _status_text(entry, rank)
	column.add_child(status)
	if _fresh.has(str(entry.id)):
		_mark_new(button, medal)
	return button


func _status_text(entry: Dictionary, rank: int) -> String:
	if _fresh.has(str(entry.id)):
		return "NEW · " + BadgeBook.RANK_NAMES[rank].to_upper()
	if rank >= BadgeBook.MAX_RANK:
		return "GOLD"
	var share := BadgeBook.next_share(entry, BadgeBook.value_of(entry, GameSession.progress, LevelCatalog.count()), rank)
	if rank == 0:
		return "%d%%" % floori(share * 100.0)
	return "%s · %d%%" % [BadgeBook.RANK_NAMES[rank].to_upper(), floori(share * 100.0)]


## New medals breathe once or twice as the page opens.
func _mark_new(_button: Button, medal: BadgeMedal) -> void:
	if Motion.reduced:
		return
	medal.pivot_offset = MEDAL_SIZE / 2.0
	var tween := medal.create_tween().set_loops(3)
	tween.tween_property(medal, "scale", Vector2(1.07, 1.07), 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(medal, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


func open_card(family_id: String) -> void:
	var entry := BadgeBook.family(family_id)
	var store := GameSession.progress
	var rank := store.badge_rank(family_id)
	var value := BadgeBook.value_of(entry, store, LevelCatalog.count())
	_card_id = family_id
	_card_medal.setup(entry, rank)
	_card_name.text = str(entry.name)
	_card_rank.text = "Not earned yet" if rank == 0 else "%s Badge" % BadgeBook.RANK_NAMES[rank]
	for child in _card_ranks.get_children():
		child.free()
	for level in range(1, BadgeBook.MAX_RANK + 1):
		_card_ranks.add_child(_rank_row(entry, level, rank, value))
	_card.show()
	_card_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_card_panel, "modulate:a", 1.0, Motion.duration(0.25)).set_trans(Tween.TRANS_SINE)


## "Silver · Earned" and its goal beside a small medal, unlit until earned; the
## next rank shows the count so far.
func _rank_row(entry: Dictionary, level: int, rank: int, value: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var medal := BadgeMedal.new()
	medal.custom_minimum_size = ROW_MEDAL_SIZE
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(medal)
	medal.setup(entry, level if level <= rank else 0)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", -2)
	row.add_child(text)
	var title := Label.new()
	title.text = BadgeBook.RANK_NAMES[level] + (" · Earned" if level <= rank else "")
	title.theme_type_variation = &"DialogRankLabel"
	text.add_child(title)
	var goal := Label.new()
	goal.text = BadgeBook.goal_text(entry, level)
	if level == rank + 1:
		goal.text += " (%s so far)" % ScoreMeter.format_points(value)
	goal.theme_type_variation = &"DialogBodyLabel"
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(goal)
	return row
