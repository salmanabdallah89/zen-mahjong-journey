extends Control
## The Daily Challenge calendar: today's puzzle, the streak, a month of days
## and the month's trophy. Earlier days of this month can be caught up; other
## months are for looking back.

const CELL_SIZE := Vector2(144, 144)
const STAR := preload("res://assets/ui/icons/icon_star.png")
const STAR_SIZE := Vector2(32, 32)
const MONTHS_BACK := 12

## Set before adding the screen to show another date (tests).
var today := BadgeBook.today()
var _shown_month := 0
var _months_back := 0

@onready var _back: Button = %BackButton
@onready var _streak: Label = %StreakLabel
@onready var _previous: Button = %PreviousButton
@onready var _next: Button = %NextButton
@onready var _month: Label = %MonthLabel
@onready var _weekdays: GridContainer = %Weekdays
@onready var _days: GridContainer = %Days
@onready var _trophy_medal: BadgeMedal = %TrophyMedal
@onready var _trophy_name: Label = %TrophyName
@onready var _trophy_goal: Label = %TrophyGoal
@onready var _trophy_bar: ProgressBar = %TrophyBar
@onready var _play: Button = %PlayButton


func _ready() -> void:
	_back.pressed.connect(GameSession.go_home)
	_previous.pressed.connect(show_month.bind(-1))
	_next.pressed.connect(show_month.bind(1))
	_play.pressed.connect(func() -> void: GameSession.play_daily(today))
	for weekday in DailyChallenge.WEEKDAY_NAMES:
		var label := Label.new()
		label.text = weekday
		label.custom_minimum_size = Vector2(CELL_SIZE.x, 0)
		label.theme_type_variation = &"CardStatusLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_weekdays.add_child(label)
	_shown_month = DailyChallenge.first_of_month(today)
	var streak := GameSession.progress.daily_streak(today)
	_streak.text = "%d day streak" % streak if streak > 0 else "Start a streak today"
	var done := GameSession.progress.daily_stars(today) > 0
	_play.text = "Play Again" if done else "Play Today"
	_show_shown_month()
	AudioManager.play_music("main_menu")
	AudioManager.set_ambience(AudioCatalog.MENU_AMBIENCE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		GameSession.go_home()


## Moves the calendar by whole months (-1 back, 1 forward).
func show_month(step: int) -> void:
	_months_back = clampi(_months_back - step, 0, MONTHS_BACK)
	_shown_month = DailyChallenge.first_of_month(today)
	for i in _months_back:
		_shown_month = DailyChallenge.previous_month(_shown_month)
	_show_shown_month()


## The button of `day` in the shown month, or null.
func day_cell(day: int) -> Button:
	return _days.get_node_or_null(str(day))


func _show_shown_month() -> void:
	_month.text = DailyChallenge.month_title(_shown_month)
	_next.disabled = _months_back == 0
	_previous.disabled = _months_back == MONTHS_BACK
	for child in _days.get_children():
		_days.remove_child(child)
		child.queue_free()
	for i in int(DailyChallenge.date_of(_shown_month).weekday):
		var gap := Control.new()
		gap.custom_minimum_size = CELL_SIZE
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_days.add_child(gap)
	for offset in DailyChallenge.days_in_month(_shown_month):
		_days.add_child(_make_cell(_shown_month + offset, offset + 1))
	_show_trophy()


func _make_cell(day: int, number: int) -> Button:
	var earned := GameSession.progress.daily_stars(day)
	var playable := DailyChallenge.is_playable(day, today)
	var cell := Button.new()
	cell.name = str(day)
	cell.custom_minimum_size = CELL_SIZE
	cell.focus_mode = Control.FOCUS_NONE
	cell.theme_type_variation = &"DayCellToday" if day == today else &"DayCell"
	cell.disabled = not playable
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	if playable:
		cell.pressed.connect(GameSession.play_daily.bind(day))
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	cell.add_child(column)
	var label := Label.new()
	label.text = str(number)
	label.theme_type_variation = &"CardTitleLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)
	if earned > 0:
		column.add_child(_star_row(earned))
	else:
		var status := Label.new()
		status.theme_type_variation = &"CardStatusLabel"
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status.text = "Today" if day == today else ("Play" if playable else " ")
		column.add_child(status)
	if not playable and earned == 0:
		cell.modulate = Color(1, 1, 1, 0.5)
	return cell


func _star_row(earned: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)
	for i in earned:
		var star := TextureRect.new()
		star.texture = STAR
		star.custom_minimum_size = STAR_SIZE
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(star)
	return row


func _show_trophy() -> void:
	var month_days := DailyChallenge.days_in_month(_shown_month)
	var cleared := DailyChallenge.month_count(GameSession.progress, _shown_month)
	var rank := DailyChallenge.trophy_rank(cleared, month_days)
	_trophy_medal.setup(DailyChallenge.TROPHY, rank)
	var month: String = DailyChallenge.MONTH_NAMES[int(DailyChallenge.date_of(_shown_month).month) - 1]
	_trophy_name.text = "%s Trophy · %s" % [month, BadgeBook.RANK_NAMES[rank]]
	_trophy_bar.max_value = month_days
	_trophy_bar.value = cleared
	if rank >= BadgeBook.MAX_RANK:
		_trophy_goal.text = "Every day cleared"
	else:
		var goal := DailyChallenge.next_trophy_goal(rank, month_days)
		_trophy_goal.text = "%d of %d days for %s" % [cleared, goal, BadgeBook.RANK_NAMES[rank + 1]]
