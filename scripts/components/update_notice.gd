class_name UpdateNotice
extends Control
## Tells the player a new version is ready: a gold medal, what is new, and
## buttons to update or come back later. The check runs once per app launch
## on Android and never holds anything up.
##
## An install from Google Play asks Play itself (PlayUpdateBridge, In-App
## Updates): "Update Now" downloads in the background while the player keeps
## playing, and once it is ready the notice offers "Restart". Anywhere else
## (sideloaded builds) the published site/version.json decides and "Update
## Now" opens the store page. No connection or a damaged file shows nothing.
## "Later" keeps that version quiet for a few days.

const MEDAL := {"group": "Journey", "picture": "seedling"}
const TIMEOUT := 6.0
const SETTINGS_SECTION := "update"

static var _checked := false
## Shared for the whole launch: the download outlives the start screen.
static var _play: PlayUpdateBridge
static var _downloaded := false

var settings_path := UserSettings.DEFAULT_PATH
## func() -> Dictionary answering {"code": int, "data": Variant}. Tests replace it.
var transport: Callable = _http
## func(url: String). Tests replace it.
var opener: Callable = OS.shell_open
var _latest := ""
## What "Update Now" does: open the store, start Play's flexible or immediate
## flow, or (once downloaded) restart into the new version.
enum Action { STORE, FLEXIBLE, IMMEDIATE, RESTART }
var _action := Action.STORE

@onready var _panel: Control = %UpdatePanel
@onready var _medal: BadgeMedal = %UpdateMedal
@onready var _title: Label = $Center/UpdatePanel/Column/Title
@onready var _version: Label = %UpdateVersion
@onready var _notes: Label = %UpdateNotesLabel
@onready var _now: Button = %UpdateNowButton
@onready var _later: Button = %UpdateLaterButton


func _ready() -> void:
	_now.pressed.connect(update_now)
	_later.pressed.connect(later)
	hide()


## Checks once per launch, on phones only: the web game is always current. A
## download finished earlier in this launch is offered again on every visit.
func check() -> void:
	if not OS.has_feature("android"):
		return
	if _play == null:
		_play = PlayUpdateBridge.from_engine()
	if _downloaded:
		present_ready()
		return
	if _checked:
		return
	_checked = true
	if _play.is_available():
		use_play(_play)
		_play.check()
	else:
		await look_for_update(_current_version(), BadgeBook.today())


## Listens to Play (the real bridge, or a test stand-in) for this notice.
func use_play(play: PlayUpdateBridge) -> void:
	_play = play
	if not play.checked.is_connected(_on_play_checked):
		play.checked.connect(_on_play_checked)
		play.status_changed.connect(_on_play_status)


## Shows the notice if the published version is newer and not snoozed.
func look_for_update(current: String, today: int) -> void:
	var reply: Dictionary = await transport.call()
	if int(reply.get("code", 0)) != 200 or not is_inside_tree():
		return
	var published := UpdateNotes.parse(reply.get("data"))
	if published.is_empty():
		return
	var settings := UserSettings.new(settings_path)
	var snoozed_version := str(settings.get_value(SETTINGS_SECTION, "version", ""))
	var snoozed_day := int(settings.get_value(SETTINGS_SECTION, "day", 0))
	if UpdateNotes.should_show(published.latest, current, snoozed_version, snoozed_day, today):
		_action = Action.STORE
		present(published)


## Play answered. The notes come from the published file when it describes a
## newer version; otherwise the notice simply says an update is ready.
func _on_play_checked(available: bool, flexible: bool, immediate: bool, version_code: int, _staleness_days: int) -> void:
	if not available or not (flexible or immediate) or not is_inside_tree():
		return
	var key := "play_%d" % version_code
	var settings := UserSettings.new(settings_path)
	if not UpdateNotes.should_show_play(key, str(settings.get_value(SETTINGS_SECTION, "version", "")),
			int(settings.get_value(SETTINGS_SECTION, "day", 0)), BadgeBook.today()):
		return
	var reply: Dictionary = await transport.call()
	if not is_inside_tree():
		return
	var published := UpdateNotes.parse(reply.get("data")) if int(reply.get("code", 0)) == 200 else {}
	if published.is_empty() or not UpdateNotes.is_newer(published.latest, _current_version()):
		published = {"latest": "", "notes": PackedStringArray()}
	_action = Action.FLEXIBLE if flexible else Action.IMMEDIATE
	present(published)
	_latest = key


func _on_play_status(status: int, _downloaded_bytes: int, _total: int) -> void:
	if status == PlayUpdateBridge.DOWNLOADED:
		_downloaded = true
		if is_inside_tree():
			present_ready()


func present(published: Dictionary) -> void:
	_latest = published.latest
	_title.text = "A New Update"
	_now.text = "Update Now"
	_medal.setup(MEDAL, BadgeBook.MAX_RANK)
	_version.text = "Version %s is ready" % _latest if not _latest.is_empty() else "A new version is ready"
	var lines := PackedStringArray()
	for note: String in published.notes:
		lines.append("· " + note)
	_notes.text = "\n".join(lines)
	_notes.visible = not lines.is_empty()
	_open()


## The update has downloaded in the background: restarting installs it.
func present_ready() -> void:
	_action = Action.RESTART
	_title.text = "Update Ready"
	_now.text = "Restart"
	_medal.setup(MEDAL, BadgeBook.MAX_RANK)
	_version.text = "Downloaded and ready"
	_notes.text = "Restart the game to start using the new version. Your progress is kept."
	_notes.visible = true
	_open()


func _open() -> void:
	show()
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, Motion.duration(0.3)).set_trans(Tween.TRANS_SINE)
	if not Motion.reduced:
		_rise_panel.call_deferred()


func _rise_panel() -> void:
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.92, 0.92)
	_panel.create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func update_now() -> void:
	hide()
	match _action:
		Action.RESTART:
			_play.complete()
		Action.FLEXIBLE, Action.IMMEDIATE:
			# Play's own screen; if it will not open, the store page still works.
			if not _play.start(_action == Action.IMMEDIATE):
				opener.call(UpdateNotes.STORE_URL)
		_:
			opener.call(UpdateNotes.STORE_URL)


## "Later" on a downloaded update just closes: it is offered again next time.
func later() -> void:
	if _action != Action.RESTART:
		var settings := UserSettings.new(settings_path)
		settings.set_value(SETTINGS_SECTION, "version", _latest)
		settings.set_value(SETTINGS_SECTION, "day", BadgeBook.today())
	hide()


## Which action "Update Now" takes (tests).
func action() -> Action:
	return _action


## Forgets this launch's check (tests).
static func reset_launch() -> void:
	_checked = false
	_play = null
	_downloaded = false


func _current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version"))


func _http() -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = TIMEOUT
	add_child(request)
	if request.request(UpdateNotes.VERSION_URL) != OK:
		request.queue_free()
		return {}
	var result: Array = await request.request_completed
	request.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {}
	return {"code": int(result[1]), "data": JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())}
