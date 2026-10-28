class_name JourneyWorld
extends Control
## The journey map seen from above: one long garden that scrolls vertically,
## with a winding stepping-stone path climbing from level 1 at the bottom to
## the last level at the top. Each run of levels that share a background is a
## chapter of that garden (the same painting the levels are played on); a band
## of mist hides each seam and carries the chapter banner. The path behind the
## player is lit with lanterns' warm gold, the path ahead stays plain stone.
## A lotus badge marks the current level.
##
## The whole map is built once on `_map`; scrolling only moves `_map`, so it
## costs almost nothing per frame. Swiping (with momentum) moves the camera;
## markers are ordinary LevelNode controls, so taps work as before.
##
## Positions along the path are in "level units": level N sits at N - 1.
## `camera` is the level unit shown at FOCUS_Y of the screen.

signal camera_moved(camera: float)

## Vertical distance between two levels on the map (canvas px).
const SPACING := 330.0
## Sideways swing of the path, as a share of the map width.
const SWING := 0.25
## Room below level 1 (first chapter banner) and above the last level.
const BOTTOM_PAD := 430.0
const TOP_PAD := 560.0
## The camera's level sits this far down the screen (share of height).
const FOCUS_Y := 0.62
## Markers count as on screen within this margin (canvas px).
const VISIBLE_MARGIN := 160.0
## Swipe: momentum decay per second; a press that moves less stays a tap.
const FRICTION := 4.0
const TAP_SLOP := 18.0

## Stepping stones (seen from above): rim, weathered top, highlight, moss.
const STONE_RIM := Color(0.2, 0.21, 0.18, 0.85)
const STONE_TOP := Color(0.62, 0.61, 0.56)
const STONE_LIGHT := Color(0.86, 0.85, 0.8, 0.55)
const STONE_MOSS := Color(0.45, 0.56, 0.36, 0.4)
## Stones on the path already walked get a warm lantern glow.
const STONE_LIT := Color(0.98, 0.84, 0.52)
const STONES_PER_LEVEL := 4
const PATH_GROUND := Color(0.93, 0.86, 0.7, 0.28)
const MIST := Color(0.95, 0.94, 0.92)
const MIST_HEIGHT := 240.0
const MIST_PEAK := 0.6
const PETAL := preload("res://assets/effects/petal_02.png")

var camera := 0.0
var current_index := 0
## Returns true while something covers the map (a dialog); swipes are ignored then.
var input_blocker := Callable()

var _nodes: Array[LevelNode] = []
var _map: Control
var _ground: Control
var _path: _PathLayer
var _badge: _LotusBadge
var _velocity := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragging := false
var _focus_tween: Tween
var _badge_tween: Tween
var _built_width := -1.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_map = Control.new()
	_map.name = "Map"
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map)
	_ground = Control.new()
	_ground.name = "Ground"
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.add_child(_ground)
	_path = _PathLayer.new()
	_path.world = self
	_path.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.add_child(_path)
	_badge = _LotusBadge.new()
	_badge.name = "LotusBadge"
	_map.add_child(_badge)
	resized.connect(_layout)


func set_nodes(nodes: Array[LevelNode]) -> void:
	_nodes = nodes
	for node in _nodes:
		if node.get_parent() != _map:
			_map.add_child(node)
	_built_width = -1.0
	_layout()


## Total height of the map (canvas px).
func map_height() -> float:
	return BOTTOM_PAD + maxf(_nodes.size() - 1, 0) * SPACING + TOP_PAD


## Map point of path position `t` (level units), in map coordinates.
func map_point(t: float) -> Vector2:
	var x := size.x / 2.0 + SWING * size.x * sin(t * 1.05 + 0.4)
	return Vector2(x, map_height() - BOTTOM_PAD - t * SPACING)


## Where `_map` sits for a given camera: the camera's level at FOCUS_Y.
func _offset_for(value: float) -> float:
	return size.y * FOCUS_Y - (map_height() - BOTTOM_PAD - value * SPACING)


func max_camera() -> float:
	# The map's top edge may not come below the screen's top.
	var limit := (map_height() - BOTTOM_PAD - size.y * FOCUS_Y) / SPACING
	return maxf(limit, min_camera())


func min_camera() -> float:
	# The map's bottom edge may not come above the screen's bottom.
	return (size.y * (1.0 - FOCUS_Y) - BOTTOM_PAD) / SPACING


## Moves the camera so `level_number` is in view.
func focus_level(level_number: int, animate := true) -> void:
	var target := clampf(level_number - 1, min_camera(), max_camera())
	_velocity = 0.0
	if _focus_tween:
		_focus_tween.kill()
	if not animate or Motion.reduced:
		_set_camera(target)
		return
	_focus_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_focus_tween.tween_method(_set_camera, camera, target, 0.9)


## Screen position of path position `t` (for effects and tests).
func project(t: float) -> Dictionary:
	var point := map_point(t) + Vector2(0, _offset_for(camera))
	return {"pos": point, "scale": 1.0, "rel": t - camera}


func is_level_visible(index: int) -> bool:
	var y := map_point(index).y + _offset_for(camera)
	return y > -VISIBLE_MARGIN and y < size.y + VISIBLE_MARGIN


## Puts the lotus badge on `index`; with `from_index` it glides there.
func set_current(index: int, from_index := -1) -> void:
	current_index = index
	_path.queue_redraw()
	if _badge_tween:
		_badge_tween.kill()
	var target := _badge_spot(index)
	if from_index < 0 or from_index == index or Motion.reduced:
		_badge.position = target
		return
	_badge.position = _badge_spot(from_index)
	_badge_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_badge_tween.tween_property(_badge, "position", target, 1.1)


func badge_position() -> Vector2:
	return _badge.position


## Chapters: runs of consecutive levels with the same background, bottom up.
## Each entry: {"background", "first" (index), "last" (index)}.
func chapters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in _nodes.size():
		var level := LevelCatalog.get_level(_nodes[i].level_number)
		var background := level.background if level else ""
		if result.is_empty() or result[-1]["background"] != background:
			result.append({"background": background, "first": i, "last": i})
		else:
			result[-1]["last"] = i
	return result


func _process(delta: float) -> void:
	if absf(_velocity) > 0.001 and not _pressing:
		_set_camera(camera + _velocity * delta)
		_velocity = move_toward(_velocity, 0.0, absf(_velocity) * FRICTION * delta + 0.002)


func _set_camera(value: float) -> void:
	var clamped := clampf(value, min_camera(), max_camera())
	if clamped != value:
		_velocity = 0.0
	if is_equal_approx(clamped, camera) and _map.position.y == _offset_for(clamped):
		return
	camera = clamped
	_map.position.y = _offset_for(camera)
	_update_visibility()
	camera_moved.emit(camera)


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _map == null:
		return
	if not is_equal_approx(_built_width, size.x):
		_build()
	_set_camera(camera)
	_map.position.y = _offset_for(camera)
	_update_visibility()


## Builds the static map: garden chapters, mist seams with banners, the path,
## the level markers and the badge.
func _build() -> void:
	_built_width = size.x
	_map.size = Vector2(size.x, map_height())
	for child in _ground.get_children():
		child.queue_free()
	var parts := chapters()
	for k in parts.size():
		var part: Dictionary = parts[k]
		# A chapter reaches halfway to the neighbouring levels (or the map edge).
		var bottom := map_height() if k == 0 else map_point(part["first"] - 0.5).y
		var top := 0.0 if k == parts.size() - 1 else map_point(part["last"] + 0.5).y
		var garden := TextureRect.new()
		var level := LevelCatalog.get_level(_nodes[part["first"]].level_number)
		garden.texture = load(level.background_path()) if level else null
		garden.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		garden.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		garden.mouse_filter = Control.MOUSE_FILTER_IGNORE
		garden.position = Vector2(0, top)
		garden.size = Vector2(size.x, bottom - top)
		_ground.add_child(garden)
	# Mist over each seam, and a small sign naming the garden ahead, on the
	# side of the map away from the path.
	for k in parts.size():
		var part: Dictionary = parts[k]
		var at: float = -0.75 if k == 0 else part["first"] - 0.5
		var seam := map_point(at).y
		if k > 0:
			_ground.add_child(_mist_band(seam))
		var away := -1 if map_point(at).x > size.x / 2.0 else 1
		_ground.add_child(_garden_sign(k + 1, BackgroundStyle.garden_name(part["background"]), seam, away))
	_path.position = Vector2.ZERO
	_path.size = _map.size
	_path.queue_redraw()
	for i in _nodes.size():
		var node := _nodes[i]
		node.scale = Vector2.ONE
		node.position = map_point(i) - node.marker_center()
		node.set_labels_visible(true)
		# Name plates sit beside the marker, toward the middle of the map.
		node.place_plate(-1 if map_point(i).x > size.x / 2.0 else 1)
	# The badge draws above the markers.
	_map.move_child(_badge, _map.get_child_count() - 1)
	_badge.position = _badge_spot(current_index)


## Lotus badge spot: hovering just above the level's marker.
func _badge_spot(index: int) -> Vector2:
	return map_point(index) + Vector2(0, -132)


func _update_visibility() -> void:
	for i in _nodes.size():
		_nodes[i].visible = is_level_visible(i)


func _mist_band(center_y: float) -> TextureRect:
	var band := TextureRect.new()
	band.texture = _mist_texture()
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.position = Vector2(0, center_y - MIST_HEIGHT / 2.0)
	band.size = Vector2(size.x, MIST_HEIGHT)
	return band


## A small sign at a seam naming the garden that starts there, placed on
## `side` (-1 left, 1 right) of the map.
func _garden_sign(number: int, garden: String, center_y: float, side: int) -> Control:
	var plate := PanelContainer.new()
	plate.theme_type_variation = &"MapLabelPlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Label.new()
	title.text = garden
	title.theme_type_variation = &"ToolLabel"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(title)
	plate.reset_size()
	var margin := 28.0
	var x := margin if side < 0 else size.x - margin - plate.size.x
	plate.position = Vector2(x, center_y - plate.size.y / 2.0)
	plate.name = "Garden%d" % number
	return plate


static var _mist: GradientTexture2D


static func _mist_texture() -> GradientTexture2D:
	if _mist == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.5, 0.65, 1.0])
		gradient.colors = PackedColorArray([Color(MIST, 0.0), Color(MIST, MIST_PEAK * 0.75), Color(MIST, MIST_PEAK),
			Color(MIST, MIST_PEAK * 0.75), Color(MIST, 0.0)])
		_mist = GradientTexture2D.new()
		_mist.gradient = gradient
		_mist.fill_from = Vector2(0.5, 0.0)
		_mist.fill_to = Vector2(0.5, 1.0)
		_mist.width = 8
		_mist.height = 128
	return _mist


# --- Swipe to travel -------------------------------------------------------

## Drags anywhere (including on markers) move the camera; a press that barely
## moves stays a tap for the marker under it. Dragging down travels forward
## (up the map), as the map follows the finger.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if input_blocker.is_valid() and input_blocker.call():
		_pressing = false
		_dragging = false
		return
	var button := event as InputEventMouseButton
	if button:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed and _hit(button.position):
			_nudge(0.35)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed and _hit(button.position):
			_nudge(-0.35)
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed and _hit(button.position):
				_pressing = true
				_dragging = false
				_press_pos = button.position
				_velocity = 0.0
				if _focus_tween:
					_focus_tween.kill()
			elif not button.pressed and _pressing:
				_pressing = false
				if _dragging:
					# A drag is not a tap: keep the marker under the finger from firing.
					get_viewport().set_input_as_handled()
				_dragging = false
		return
	var motion := event as InputEventMouseMotion
	if motion and _pressing and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if not _dragging and motion.position.distance_to(_press_pos) > TAP_SLOP:
			_dragging = true
		if _dragging:
			var step := motion.relative.y / SPACING
			_set_camera(camera + step)
			_velocity = step / maxf(get_process_delta_time(), 0.001)
			_velocity = clampf(_velocity, -8.0, 8.0)


func _nudge(amount: float) -> void:
	if _focus_tween:
		_focus_tween.kill()
	_velocity = 0.0
	_set_camera(camera + amount)


func _hit(point: Vector2) -> bool:
	return get_global_rect().has_point(point)


## The winding path, drawn once on the map: a soft sandy trail with stepping
## stones; stones up to the current level glow warm gold.
class _PathLayer extends Control:
	var world: JourneyWorld

	func _draw() -> void:
		if world == null or world._nodes.is_empty():
			return
		var last := world._nodes.size() - 1
		var trail := PackedVector2Array()
		var t := -0.8
		while t <= last + 0.8:
			trail.append(world.map_point(t))
			t += 0.04
		draw_polyline(trail, JourneyWorld.PATH_GROUND, 150.0, true)
		var step := 1.0 / JourneyWorld.STONES_PER_LEVEL
		var s := -0.75
		while s <= last + 0.75:
			# Stones sit between the markers, not under them.
			if absf(s - roundf(s)) > 0.2:
				_stone(world.map_point(s), s, s <= world.current_index)
			s += step

	func _stone(center: Vector2, t: float, lit: bool) -> void:
		var wobble := sin(t * 12.9) * 0.15
		var radius := Vector2(46.0 * (1.0 + wobble), 34.0 * (1.0 - wobble))
		_ellipse(center + Vector2(0, 5), radius * 1.06, JourneyWorld.STONE_RIM)
		var top := JourneyWorld.STONE_TOP.lerp(JourneyWorld.STONE_LIT, 0.55) if lit else JourneyWorld.STONE_TOP
		_ellipse(center, radius, top)
		_ellipse(center + Vector2(radius.x * 0.3, radius.y * 0.2), radius * Vector2(0.4, 0.45), JourneyWorld.STONE_MOSS)
		_ellipse(center - radius * Vector2(0.25, 0.3), radius * Vector2(0.5, 0.42), JourneyWorld.STONE_LIGHT)
		if lit:
			_ellipse(center, radius * 1.5, Color(JourneyWorld.STONE_LIT, 0.16))

	func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
		var points := PackedVector2Array()
		for k in 20:
			var angle := TAU * k / 20.0
			points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
		draw_colored_polygon(points, color)


## "You are here": a lotus of five sakura petals on an ivory disc with a gold
## ring, gently bobbing (still with reduced animations).
class _LotusBadge extends Control:
	const RADIUS := 52.0
	var _time := 0.0

	func _ready() -> void:
		# Drawn above the markers by child order (not z_index), so dialogs
		# on the screen still cover it.
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if Motion.reduced:
			return
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var bob := Vector2(0, -8.0 * sin(_time * 2.4))
		draw_circle(bob + Vector2(0, 8), RADIUS + 6, Color(0, 0, 0, 0.25))
		draw_circle(bob, RADIUS + 6, Color(0.78, 0.65, 0.42))
		draw_circle(bob, RADIUS, Color(0.96, 0.93, 0.87))
		var petal := JourneyWorld.PETAL
		var petal_size := Vector2(54, 54)
		for k in 5:
			var angle := TAU * k / 5.0 - PI / 2.0
			draw_set_transform(bob + Vector2(cos(angle), sin(angle)) * 18.0, angle + PI / 2.0, Vector2.ONE)
			draw_texture_rect(petal, Rect2(-petal_size / 2.0, petal_size), false, Color(1, 0.86, 0.9))
		draw_set_transform(Vector2.ZERO)
		draw_circle(bob, 9.0, Color(0.93, 0.76, 0.42))
