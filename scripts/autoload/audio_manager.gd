extends Node
## Autoload "AudioManager": music with crossfades, layered nature ambience,
## pooled sound effects, volume/mute/vibration settings, and pausing while
## the app is in the background. Sounds are referenced by id (AudioCatalog);
## a missing file is skipped silently, so the game runs without audio assets.
##
## Volumes are stored linear (0..1) in user settings, section "audio".

signal settings_changed

const SETTINGS_SECTION := "audio"
const CROSSFADE_SECONDS := 1.5
const AMBIENCE_FADE_SECONDS := 2.0
## Effect players shared by SFX and UI; the oldest is reused when all are busy.
const EFFECT_VOICES := 6
## Default cap on copies of one effect sounding together (AudioCatalog can override).
const MAX_SAME_EFFECT := 2
## Music level while the level-complete celebration plays (linear).
const CELEBRATION_DUCK := 0.35
const MUSIC_DB := -6.0
const AMBIENCE_DB := -12.0
const HISTORY_LIMIT := 64
const DEFAULTS := {"music": 0.7, "sfx": 0.8, "ambience": 0.5, "muted": false, "vibration": true}

var settings_path := UserSettings.DEFAULT_PATH
var music_volume: float = DEFAULTS["music"]
var sfx_volume: float = DEFAULTS["sfx"]
var ambience_volume: float = DEFAULTS["ambience"]
var muted: bool = DEFAULTS["muted"]
var vibration: bool = DEFAULTS["vibration"]

## Id of the music track that is (or would be, if its file existed) playing.
var current_music := ""
## Recent sound events, newest last: {"seq", "id", "kind", "played"}. Used by
## tests and debugging; "played" is false when the file is missing or the
## play was limited. `seq` keeps counting when old entries are dropped.
var history: Array[Dictionary] = []
var event_seq := 0
## Sound files that were requested but don't exist (checked once each).
var missing := {}

var _music_players: Array[AudioStreamPlayer] = []
var _active_music := 0
var _music_tween: Tween
var _duck := 1.0
var _duck_tween: Tween
var _ambience_players := {}
var _ambience_tweens := {}
var _effect_players: Array[AudioStreamPlayer] = []
var _effect_ids: PackedStringArray = PackedStringArray()
var _effect_started: PackedFloat64Array = PackedFloat64Array()
var _last_played := {}
var _streams := {}
var _rng := RandomNumberGenerator.new()
## Match melody: matches within this many seconds of the last one climb the
## scale; a longer pause starts again from the lowest note.
var melody_window := 8.0
var _melody_step := -1
var _last_match_time := -1000.0
## Slider drags change values many times a second; write settings once they settle.
var _save_timer: Timer
var _settings_dirty := false
## Headless runs (tests, CI) have no audio device; the dummy driver never
## releases playbacks, so everything except actually starting playback runs.
var _audible := DisplayServer.get_name() != "headless"
## Music/ambience players currently in use (true even when not audible).
var _active := {}
var _suspended := false
## Game audio is silenced while an ad plays (the ad has its own sound).
var _ad_playing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		player.volume_db = -80.0
		add_child(player)
		_music_players.append(player)
	for ambience_id: String in AudioCatalog.AMBIENCE:
		var player := AudioStreamPlayer.new()
		player.bus = &"Ambience"
		player.volume_db = -80.0
		add_child(player)
		_ambience_players[ambience_id] = player
	for i in EFFECT_VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_effect_players.append(player)
		_effect_ids.append("")
		_effect_started.append(-1000.0)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.4
	_save_timer.timeout.connect(flush_settings)
	add_child(_save_timer)
	get_tree().node_added.connect(_on_node_added)
	# Effects are small (~1 MB together); loading them now avoids a hitch the
	# first time each one plays. Music and ambience load when first needed.
	for entry: Array in AudioCatalog.EFFECTS.values():
		_stream(str(entry[0]), false)
	for note in AudioCatalog.MATCH_NOTES:
		_stream(note, false)
	restore()


# --- Music -----------------------------------------------------------------

## Crossfades to a track. Asking for the track already playing does nothing,
## so pausing or opening settings never restarts the music.
func play_music(track_id: String) -> void:
	if track_id == current_music:
		return
	current_music = track_id
	var stream := _stream(str(AudioCatalog.MUSIC.get(track_id, "")), true)
	_record(track_id, "music", stream != null)
	var outgoing := _music_players[_active_music]
	_active_music = 1 - _active_music
	var incoming := _music_players[_active_music]
	if _music_tween:
		_music_tween.kill()
	if not _is_active(outgoing) and stream == null:
		return
	# Both fades run together; the old track stops once it is silent.
	_music_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	if stream:
		incoming.stream = stream
		incoming.volume_db = -80.0
		_start(incoming)
		_music_tween.tween_property(incoming, "volume_db", _music_target_db(), CROSSFADE_SECONDS)
	if _is_active(outgoing):
		_music_tween.tween_property(outgoing, "volume_db", -80.0, CROSSFADE_SECONDS)
		_music_tween.chain().tween_callback(_stop.bind(outgoing))


func stop_music() -> void:
	current_music = ""
	for player in _music_players:
		_stop(player)


## The music player currently fading in or playing, if any.
func active_music_player() -> AudioStreamPlayer:
	var player := _music_players[_active_music]
	return player if _is_active(player) else null


func music_player_count() -> int:
	var count := 0
	for player in _music_players:
		if _is_active(player):
			count += 1
	return count


## Lowers the music for a celebration, then brings it back.
func duck_music_for(seconds: float) -> void:
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck, _duck, CELEBRATION_DUCK, 0.3)
	_duck_tween.tween_interval(seconds)
	_duck_tween.tween_method(_set_duck, CELEBRATION_DUCK, 1.0, 1.2)


func music_duck() -> float:
	return _duck


func _set_duck(value: float) -> void:
	_duck = value
	var player := _music_players[_active_music]
	if _is_active(player) and not (_music_tween and _music_tween.is_running()):
		player.volume_db = _music_target_db()


func _music_target_db() -> float:
	return MUSIC_DB + linear_to_db(maxf(_duck, 0.0001))


# --- Ambience --------------------------------------------------------------

## Fades each ambience layer to its level (0..1); layers not listed fade out.
func set_ambience(levels: Dictionary) -> void:
	for ambience_id: String in _ambience_players:
		var player: AudioStreamPlayer = _ambience_players[ambience_id]
		var level := float(levels.get(ambience_id, 0.0))
		if _ambience_tweens.has(ambience_id):
			(_ambience_tweens[ambience_id] as Tween).kill()
			_ambience_tweens.erase(ambience_id)
		if level <= 0.0:
			if _is_active(player):
				var fade_out := create_tween().set_trans(Tween.TRANS_SINE)
				fade_out.tween_property(player, "volume_db", -80.0, AMBIENCE_FADE_SECONDS)
				fade_out.tween_callback(_stop.bind(player))
				_ambience_tweens[ambience_id] = fade_out
			continue
		var stream := _stream(str(AudioCatalog.AMBIENCE[ambience_id]), true)
		_record(ambience_id, "ambience", stream != null)
		if stream == null:
			continue
		var tween := create_tween().set_trans(Tween.TRANS_SINE)
		_ambience_tweens[ambience_id] = tween
		if not _is_active(player):
			player.stream = stream
			player.volume_db = -80.0
			# Start each layer somewhere different so loops don't line up.
			_start(player, _rng.randf_range(0.0, maxf(stream.get_length() - 1.0, 0.0)))
		var target := AMBIENCE_DB + linear_to_db(level)
		tween.tween_property(player, "volume_db", target, AMBIENCE_FADE_SECONDS)
		# Gentle slow swell so the garden feels alive.
		tween.tween_property(player, "volume_db", target - 2.5, 7.0 + _rng.randf() * 4.0)
		tween.tween_property(player, "volume_db", target, 7.0 + _rng.randf() * 4.0)
		tween.set_loops()


func ambience_level_db(ambience_id: String) -> float:
	var player: AudioStreamPlayer = _ambience_players.get(ambience_id)
	return player.volume_db if player and _is_active(player) else -80.0


# --- Effects ---------------------------------------------------------------

## Plays an effect. Repeats within the effect's minimum gap, and more than its
## overlap cap, are dropped. `file_override` plays another file under the same
## id and limits (used for melody notes). With `steal`, a sound over its cap
## cuts off its own oldest copy instead of being dropped. Returns true if it played.
func play_sfx(effect_id: String, file_override := "", steal := false) -> bool:
	if not AudioCatalog.EFFECTS.has(effect_id):
		_record(effect_id, "sfx", false)
		return false
	var entry: Array = AudioCatalog.EFFECTS[effect_id]
	var cap := int(entry[4]) if entry.size() > 4 else MAX_SAME_EFFECT
	var now := Time.get_ticks_msec() / 1000.0
	var over_cap := _count_playing(effect_id) >= cap
	if now - float(_last_played.get(effect_id, -1000.0)) < float(entry[3]) or (over_cap and not steal):
		_record(effect_id, "sfx_limited", false)
		return false
	var file := file_override if not file_override.is_empty() else str(entry[0])
	var stream := _stream(file, false)
	if stream == null:
		_record(effect_id, "sfx", false)
		return false
	var voice := _oldest_voice_of(effect_id) if over_cap else _free_voice()
	var player := _effect_players[voice]
	player.stop()
	player.stream = stream
	player.bus = StringName(entry[1])
	var spread := float(entry[2])
	player.pitch_scale = 1.0 + _rng.randf_range(-spread, spread)
	if _audible:
		player.play()
	_effect_ids[voice] = effect_id
	_effect_started[voice] = now
	_last_played[effect_id] = now
	_record(effect_id, "sfx", true, file)
	return true


## A matched pair: the next bell of the melody. Quick successive matches climb
## the scale (holding on the top note); a pause restarts from the bottom.
func play_match_note() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_match_time > melody_window:
		_melody_step = 0
	else:
		_melody_step = mini(_melody_step + 1, AudioCatalog.MATCH_NOTES.size() - 1)
	_last_match_time = now
	# A melody note is never skipped: if too many bells ring, the oldest is damped.
	return play_sfx("tile_match", AudioCatalog.MATCH_NOTES[_melody_step], true)


## Undoing a match takes the melody back one note.
func melody_step_back() -> void:
	_melody_step = maxi(_melody_step - 1, -1)


## Next match starts the melody from the lowest note (new level, shuffle).
func reset_melody() -> void:
	_melody_step = -1
	_last_match_time = -1000.0


func melody_step() -> int:
	return _melody_step


## Short haptic tick on phones, if the player allows vibration.
func vibrate(milliseconds := 25) -> void:
	if vibration and not muted and OS.has_feature("mobile"):
		Input.vibrate_handheld(milliseconds)


## Buttons opt out of the generic click with set_meta("custom_sound", true)
## when they play their own effect.
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(_on_button_pressed.bind(node))


func _on_button_pressed(button: BaseButton) -> void:
	if not button.has_meta("custom_sound"):
		play_sfx("button_click")


func _count_playing(effect_id: String) -> int:
	var count := 0
	for i in _effect_players.size():
		if _effect_ids[i] == effect_id and _voice_busy(i):
			count += 1
	return count


## A voice is busy until its sound has had time to finish (works headless too).
func _voice_busy(voice: int) -> bool:
	var player := _effect_players[voice]
	if player.stream == null:
		return false
	var seconds := player.stream.get_length() / maxf(player.pitch_scale, 0.01)
	return Time.get_ticks_msec() / 1000.0 - _effect_started[voice] < seconds


func _oldest_voice_of(effect_id: String) -> int:
	var oldest := -1
	for i in _effect_players.size():
		if _effect_ids[i] == effect_id and _voice_busy(i):
			if oldest < 0 or _effect_started[i] < _effect_started[oldest]:
				oldest = i
	return oldest if oldest >= 0 else _free_voice()


func _free_voice() -> int:
	var oldest := 0
	for i in _effect_players.size():
		if not _voice_busy(i):
			return i
		if _effect_started[i] < _effect_started[oldest]:
			oldest = i
	return oldest


# --- Settings --------------------------------------------------------------

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_and_save("music", music_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_and_save("sfx", sfx_volume)


func set_ambience_volume(value: float) -> void:
	ambience_volume = clampf(value, 0.0, 1.0)
	_apply_and_save("ambience", ambience_volume)


func set_muted(value: bool) -> void:
	muted = value
	_apply_and_save("muted", muted)


func set_vibration(value: bool) -> void:
	vibration = value
	_apply_and_save("vibration", vibration)


func restore() -> void:
	var settings := UserSettings.new(settings_path)
	music_volume = float(settings.get_value(SETTINGS_SECTION, "music", DEFAULTS["music"]))
	sfx_volume = float(settings.get_value(SETTINGS_SECTION, "sfx", DEFAULTS["sfx"]))
	ambience_volume = float(settings.get_value(SETTINGS_SECTION, "ambience", DEFAULTS["ambience"]))
	muted = bool(settings.get_value(SETTINGS_SECTION, "muted", DEFAULTS["muted"]))
	vibration = bool(settings.get_value(SETTINGS_SECTION, "vibration", DEFAULTS["vibration"]))
	_apply_buses()


## Bus volume in dB for a 0..1 slider value; 0 is silent.
static func slider_to_db(value: float) -> float:
	return -80.0 if value <= 0.001 else linear_to_db(value)


func _apply_and_save(_key: String, _value: Variant) -> void:
	_apply_buses()
	_settings_dirty = true
	_save_timer.start()
	settings_changed.emit()


## Writes pending setting changes now (also done on app pause and quit).
func flush_settings() -> void:
	if not _settings_dirty:
		return
	_settings_dirty = false
	var settings := UserSettings.new(settings_path)
	settings.set_value(SETTINGS_SECTION, "music", music_volume)
	settings.set_value(SETTINGS_SECTION, "sfx", sfx_volume)
	settings.set_value(SETTINGS_SECTION, "ambience", ambience_volume)
	settings.set_value(SETTINGS_SECTION, "muted", muted)
	settings.set_value(SETTINGS_SECTION, "vibration", vibration)


func _apply_buses() -> void:
	_set_bus("Music", music_volume)
	_set_bus("Ambience", ambience_volume)
	_set_bus("SFX", sfx_volume)
	_set_bus("UI", sfx_volume)
	var master := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(master, muted or _ad_playing)


func _set_bus(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, slider_to_db(value))
	AudioServer.set_bus_mute(index, value <= 0.001)


# --- App lifecycle ---------------------------------------------------------

func _start(player: AudioStreamPlayer, from := 0.0) -> void:
	_active[player] = true
	if _audible:
		player.play(from)


func _stop(player: AudioStreamPlayer) -> void:
	_active.erase(player)
	player.stop()


func _is_active(player: AudioStreamPlayer) -> bool:
	return _active.has(player)


func _exit_tree() -> void:
	flush_settings()
	for tween: Tween in _ambience_tweens.values():
		tween.kill()
	_ambience_tweens.clear()
	for tween in [_music_tween, _duck_tween]:
		if tween:
			(tween as Tween).kill()
	for child in get_children():
		var player := child as AudioStreamPlayer
		if player == null:
			continue
		player.stop()
		player.stream = null
	_streams.clear()


func _notification(what: int) -> void:
	# Phones: nothing keeps playing while the game is in the background.
	if what == NOTIFICATION_APPLICATION_PAUSED:
		flush_settings()
		_set_all_paused(true)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush_settings()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_set_all_paused(false)


func _set_all_paused(paused: bool) -> void:
	_suspended = paused
	var players: Array = []
	players.append_array(_music_players)
	players.append_array(_effect_players)
	players.append_array(_ambience_players.values())
	for player: AudioStreamPlayer in players:
		player.stream_paused = paused


func set_ad_playing(playing: bool) -> void:
	_ad_playing = playing
	_apply_buses()


func is_suspended() -> bool:
	return _suspended


# --- Loading ---------------------------------------------------------------

## Substitutes a stream for a catalog path (tests, or previewing a track
## before its file is installed). Pass null to go back to the file on disk.
func use_stream(path: String, stream: AudioStream) -> void:
	if stream == null:
		_streams.erase(path)
		missing.erase(path)
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_streams[path] = stream

func _stream(path: String, looping: bool) -> AudioStream:
	if path.is_empty():
		return null
	if _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		if not missing.has(path):
			missing[path] = true
			print_verbose("AudioManager: %s not installed; skipping" % path)
		_streams[path] = null
		return null
	var stream: AudioStream = load(path)
	if looping and stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif looping and stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_streams[path] = stream
	return stream


func _record(sound_id: String, kind: String, played: bool, file := "") -> void:
	history.append({"seq": event_seq, "id": sound_id, "kind": kind, "played": played, "file": file})
	event_seq += 1
	if history.size() > HISTORY_LIMIT:
		history.pop_front()


## Plays of `sound_id` that actually sounded, among events numbered >= `since_seq`.
func count_played(sound_id: String, since_seq := 0) -> int:
	var count := 0
	for event in history:
		if int(event["seq"]) >= since_seq and event["id"] == sound_id and event["played"]:
			count += 1
	return count


## Requests for `sound_id` (played or not) among events numbered >= `since_seq`.
func count_requested(sound_id: String, since_seq := 0) -> int:
	var count := 0
	for event in history:
		if int(event["seq"]) >= since_seq and event["id"] == sound_id:
			count += 1
	return count
