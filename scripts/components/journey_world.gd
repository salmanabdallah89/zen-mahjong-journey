class_name JourneyWorld
extends Control
## The journey drawn in perspective: a stepping-stone path running away from
## the viewer toward the horizon, with level markers standing on it. Near
## levels are large at the bottom of the screen, farther ones shrink and fade
## into the mist. Swiping moves the camera along the path (with momentum);
## markers are ordinary LevelNode controls, so taps work as before.
##
## Positions along the path are in "level units": level N sits at N - 1.

signal camera_moved(camera: float)

## Distance (in level units) at which a marker is drawn at full size.
const FOCAL := 2.6
## Where the ground meets the sky, and the nearest ground line, as shares of height.
const HORIZON := 0.1
## Ground line for a level at the camera; its labels hang below this.
const GROUND := 0.8
## Sideways swing of the path at full size (canvas px).
const SWING := 250.0
const PATH_WIDTH := 240.0
## How far ahead and behind the camera markers are drawn.
const VISIBLE_AHEAD := 5.5
const VISIBLE_BEHIND := 0.25
## The current level sits this far ahead of the camera.
const FOCUS_AHEAD := 0.35
## Markers float this high above their shadow at full size.
const LIFT := 26.0
const NODE_SCALE := 1.55
## Swipe: level units travelled per pixel dragged, and momentum decay per second.
const DRAG_SPEED := 0.0034
const FRICTION := 4.0
const TAP_SLOP := 18.0

## Stepping stones: dark underside (thickness), weathered top, soft highlight.
const STONE_SIDE := Color(0.16, 0.17, 0.14, 0.95)
const STONE_TOP := Color(0.55, 0.55, 0.5)
const STONE_LIGHT := Color(0.82, 0.81, 0.76, 0.6)
## Markers smaller than this hide their title and difficulty (too small to read).
const LABEL_MIN_SCALE := 0.85
const STONE_MOSS := Color(0.45, 0.56, 0.36, 0.45)
const STONES_PER_LEVEL := 3
const HAZE := Color(0.86, 0.88, 0.92)
const ARROW := Color(0.96, 0.8, 0.42)
const ARROW_EDGE := Color(0.38, 0.27, 0.12)

var camera := 0.0
var current_index := 0

var _nodes: Array[LevelNode] = []
var _velocity := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragging := false
var _focus_tween: Tween
var _time := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)


func set_nodes(nodes: Array[LevelNode]) -> void:
	_nodes = nodes
	for node in _nodes:
		if node.get_parent() != self:
			add_child(node)
	_layout()


func max_camera() -> float:
	return maxf(0.0, _nodes.size() - 1.0) - FOCUS_AHEAD


func min_camera() -> float:
	return -FOCUS_AHEAD


## Moves the camera so `level_number` is in view, near the bottom.
func focus_level(level_number: int, animate := true) -> void:
	var target := clampf(level_number - 1 - FOCUS_AHEAD, min_camera(), max_camera())
	_velocity = 0.0
	if _focus_tween:
		_focus_tween.kill()
	if not animate:
		_set_camera(target)
		return
	_focus_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_focus_tween.tween_method(_set_camera, camera, target, 0.9)


## Screen position on the ground for path position `t`, and its scale.
func project(t: float) -> Dictionary:
	var rel := t - camera
	var s := FOCAL / maxf(rel + FOCAL, 0.05)
	var horizon := size.y * HORIZON
	var y := horizon + (size.y * GROUND - horizon) * s
	var x := size.x / 2.0 + _lateral(t) * s
	return {"pos": Vector2(x, y), "scale": s, "rel": rel}


func is_level_visible(index: int) -> bool:
	var rel := index - camera
	return rel >= -VISIBLE_BEHIND and rel <= VISIBLE_AHEAD


func _lateral(t: float) -> float:
	return SWING * sin(t * 0.95 + 0.35)


func _process(delta: float) -> void:
	_time += delta
	if absf(_velocity) > 0.001 and not _pressing:
		_set_camera(camera + _velocity * delta)
		_velocity = move_toward(_velocity, 0.0, absf(_velocity) * FRICTION * delta + 0.002)
	# The "you are here" arrow bobs, so keep drawing while it is on screen.
	if is_level_visible(current_index):
		queue_redraw()


func _set_camera(value: float) -> void:
	var clamped := clampf(value, min_camera(), max_camera())
	if clamped != value:
		_velocity = 0.0
	if is_equal_approx(clamped, camera):
		return
	camera = clamped
	_layout()
	camera_moved.emit(camera)


func _layout() -> void:
	_place_nodes()
	queue_redraw()


## Stands each marker on the path at its projected size, far ones behind.
func _place_nodes() -> void:
	if size.y <= 0.0:
		return
	var order: Array = []
	for i in _nodes.size():
		var node := _nodes[i]
		node.visible = is_level_visible(i)
		if not node.visible:
			continue
		var p := project(i)
		var s: float = p["scale"] * NODE_SCALE
		node.scale = Vector2(s, s)
		var foot := Vector2(node.marker_center().x, node.marker_center().y * 2.0)
		node.position = (p["pos"] as Vector2) - Vector2(0, LIFT * s) - foot * s
		# Distant markers fade into the haze.
		var fade := clampf((p["rel"] - 2.5) / (VISIBLE_AHEAD - 2.5), 0.0, 1.0)
		node.modulate = Color.WHITE.lerp(HAZE, fade * 0.55)
		node.modulate.a = 1.0 - fade * 0.65
		node.set_labels_visible(s >= LABEL_MIN_SCALE or i == current_index)
		order.append([p["rel"], node])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for k in order.size():
		move_child(order[k][1], k)


func _draw() -> void:
	if size.y <= 0.0:
		return
	var start := maxf(camera - VISIBLE_BEHIND - 0.3, -0.6)
	var finish := minf(camera + VISIBLE_AHEAD + 1.0, _nodes.size() + 0.4)
	# Stepping stones, far to near so nearer stones overlap farther ones.
	var step := 1.0 / STONES_PER_LEVEL
	var t := ceilf(finish / step) * step
	while t >= start:
		var p := project(t)
		if p["rel"] > -VISIBLE_BEHIND - 0.3:
			_draw_stone(p, t)
		t -= step
	# Ground shadows under the markers.
	for i in _nodes.size():
		if not is_level_visible(i):
			continue
		var p := project(i)
		var s: float = p["scale"]
		_draw_ellipse(p["pos"], Vector2(78, 22) * s, Color(0, 0, 0, 0.32 * clampf(1.4 - p["rel"] * 0.15, 0.3, 1.0)))
	# "You are here" arrow above the current level.
	if is_level_visible(current_index):
		var p := project(current_index)
		var s: float = p["scale"]
		var lift := (LIFT + 150.0 * NODE_SCALE + 14.0 * sin(_time * 3.0)) * s
		var tip := (p["pos"] as Vector2) - Vector2(0, lift)
		var w := 46.0 * s
		var arrow := PackedVector2Array([tip, tip + Vector2(-w, -w * 1.1), tip + Vector2(-w * 0.4, -w * 1.1),
			tip + Vector2(-w * 0.4, -w * 2.1), tip + Vector2(w * 0.4, -w * 2.1), tip + Vector2(w * 0.4, -w * 1.1),
			tip + Vector2(w, -w * 1.1)])
		var outline := arrow.duplicate()
		outline.append(arrow[0])
		draw_colored_polygon(arrow, ARROW)
		draw_polyline(outline, ARROW_EDGE, maxf(3.0 * s, 1.5), true)


## One oval stepping stone lying on the ground: flattened by perspective,
## with a dark rim for thickness, a weathered top and a little moss.
func _draw_stone(p: Dictionary, t: float) -> void:
	var s: float = p["scale"]
	var center: Vector2 = p["pos"]
	var wobble := sin(t * 12.9) * 0.12
	var radius := Vector2(PATH_WIDTH * 0.42 * (1.0 + wobble), PATH_WIDTH * 0.17 * (1.0 - wobble)) * s * Vector2(1.0, clampf(s, 0.45, 1.2))
	var fade := clampf(((p["rel"] as float) - 2.5) / (VISIBLE_AHEAD - 2.0), 0.0, 1.0)
	var keep := 1.0 - fade * 0.55
	_draw_ellipse(center + Vector2(0, radius.y * 0.45), radius * 1.02, _fade(STONE_SIDE, fade, keep))
	_draw_ellipse(center, radius, _fade(STONE_TOP, fade, keep))
	_draw_ellipse(center + Vector2(radius.x * 0.28, radius.y * 0.15), radius * Vector2(0.4, 0.45), _fade(STONE_MOSS, fade, keep))
	_draw_ellipse(center - radius * Vector2(0.25, 0.3), radius * Vector2(0.5, 0.42), _fade(STONE_LIGHT, fade, keep))


func _fade(color: Color, fade: float, keep: float) -> Color:
	var faded := color.lerp(HAZE, fade * 0.6)
	faded.a = color.a * keep
	return faded


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for k in 24:
		var angle := TAU * k / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)


# --- Swipe to travel -------------------------------------------------------

## Drags anywhere (including on markers) move the camera; a press that barely
## moves stays a tap for the marker under it.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
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
			var step := motion.relative.y * DRAG_SPEED
			_set_camera(camera + step)
			_velocity = step / maxf(get_process_delta_time(), 0.001)
			_velocity = clampf(_velocity, -6.0, 6.0)


func _nudge(amount: float) -> void:
	if _focus_tween:
		_focus_tween.kill()
	_velocity = 0.0
	_set_camera(camera + amount)


func _hit(point: Vector2) -> bool:
	return get_global_rect().has_point(point)
