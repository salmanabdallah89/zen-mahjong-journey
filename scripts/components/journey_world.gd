class_name JourneyWorld
extends Control
## The journey map: a winding stepping-stone path climbing up the screen,
## level 1 at the bottom, over a calm garden backdrop. Built for long
## journeys (1000 levels): only the stretch on screen exists.
##
## Backdrop: the painting of the chapter in view stays still behind the map
## (softly dimmed, with a vignette, drifting a little as you travel), and
## blends into the next chapter's garden over its last levels: no crops,
## seams or bands. Chapters are LevelRecipe.CHAPTER_SIZE levels each; a sign
## on the path opens each one.
##
## Markers are pooled LevelNodes, positioned on screen around the camera and
## filled in by `node_setup` (the journey screen) when they come into view;
## the path and stones are drawn for the visible stretch only. A lotus badge
## marks the current level. Swiping (with momentum) moves the camera.
##
## Positions along the path are in "level units": level N sits at N - 1.
## `camera` is the level unit shown at FOCUS_Y of the screen.

signal camera_moved(camera: float)

const NODE_SCENE := preload("res://scenes/components/level_node.tscn")
const PETAL := preload("res://assets/effects/petal_02.png")
## Vertical distance between two levels (canvas px).
const SPACING := 330.0
## Sideways swing of the path, as a share of the width.
const SWING := 0.25
## Room below level 1 and above the last level.
const BOTTOM_PAD := 430.0
const TOP_PAD := 560.0
## The camera's level sits this far down the screen (share of height).
const FOCUS_Y := 0.62
## Extra margin (canvas px) built around the screen.
const VISIBLE_MARGIN := 200.0
const FRICTION := 4.0
const TAP_SLOP := 18.0
## Backdrop: brightness of the painting, its blend into the next chapter over
## the last levels of a chapter, and its gentle drift across one chapter.
const BACKDROP_LIGHT := 0.74
const BLEND_LEVELS := 4.0
const DRIFT := 90.0
## Lotus badge: offset above its level's marker.
const BADGE_LIFT := 132.0

## Path: a soft sandy trail with stepping stones; stones walked glow gold.
const TRAIL := Color(0.96, 0.9, 0.76, 0.32)
const TRAIL_EDGE := Color(0.2, 0.18, 0.12, 0.18)
const STONE_RIM := Color(0.2, 0.21, 0.18, 0.85)
const STONE_TOP := Color(0.66, 0.65, 0.6)
const STONE_LIGHT := Color(0.88, 0.87, 0.82, 0.55)
const STONE_LIT := Color(0.98, 0.84, 0.52)
const STONES_PER_LEVEL := 4

var camera := 0.0
var current_index := 0
var level_count := 0
## Fills a marker for a level: func(node: LevelNode, number: int).
var node_setup := Callable()
## Returns true while something covers the map (a dialog); swipes are ignored then.
var input_blocker := Callable()

var _active := {}
var _pool: Array[LevelNode] = []
var _signs := {}
var _back: TextureRect
var _next_back: TextureRect
var _vignette: TextureRect
var _path: _PathLayer
var _badge: _LotusBadge
var _badge_t := 0.0
var _velocity := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragging := false
var _focus_tween: Tween
var _badge_tween: Tween


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_back = _backdrop_rect("Backdrop")
	_next_back = _backdrop_rect("NextBackdrop")
	_vignette = TextureRect.new()
	_vignette.name = "Vignette"
	_vignette.texture = _vignette_texture()
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_vignette)
	_path = _PathLayer.new()
	_path.world = self
	_path.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_path.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_path)
	_badge = _LotusBadge.new()
	_badge.name = "LotusBadge"
	add_child(_badge)


func _notification(what: int) -> void:
	# Lay out whenever the size changes (also if it was set before _ready).
	if what == NOTIFICATION_RESIZED:
		_layout()


## Sets how many levels the journey has and how to fill their markers.
func setup(count: int, setup_node: Callable) -> void:
	level_count = count
	node_setup = setup_node
	_layout()
	_layout.call_deferred()


func max_camera() -> float:
	return maxf(level_count - 1 - (size.y * FOCUS_Y - TOP_PAD) / SPACING, min_camera())


func min_camera() -> float:
	return (size.y * (1.0 - FOCUS_Y) - BOTTOM_PAD) / SPACING


## Path point of position `t` on screen (this control's coordinates).
func screen_point(t: float) -> Vector2:
	var x := size.x / 2.0 + SWING * size.x * sin(t * 1.05 + 0.4)
	return Vector2(x, size.y * FOCUS_Y + (camera - t) * SPACING)


## The path's shape with the camera at 0 (stable, for layout checks).
func map_point(t: float) -> Vector2:
	return Vector2(size.x / 2.0 + SWING * size.x * sin(t * 1.05 + 0.4), -t * SPACING)


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


func project(t: float) -> Dictionary:
	return {"pos": screen_point(t), "scale": 1.0, "rel": t - camera}


func is_level_visible(index: int) -> bool:
	var y := screen_point(index).y
	return index >= 0 and index < level_count and y > -VISIBLE_MARGIN and y < size.y + VISIBLE_MARGIN


## The marker for level `number`, if it is on screen (else null).
func node_for(number: int) -> LevelNode:
	return _active.get(number - 1)


## Fills every visible marker again (after progress changed).
func refresh_nodes() -> void:
	for index: int in _active:
		_fill(_active[index], index)
	_path.queue_redraw()


## Puts the lotus badge on `index`; with `from_index` it walks there.
func set_current(index: int, from_index := -1) -> void:
	current_index = index
	if _badge_tween:
		_badge_tween.kill()
	if from_index < 0 or from_index == index or Motion.reduced:
		_badge_t = index
		_place_badge()
	else:
		_badge_t = from_index
		_badge_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_badge_tween.tween_method(_move_badge, float(from_index), float(index), 1.1)
	_path.queue_redraw()


## The badge's level position (in level units).
func badge_level() -> float:
	return _badge_t


func badge_position() -> Vector2:
	return _badge.position


## Chapters: {"background", "first" (index), "last" (index)}, bottom up.
func chapters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var chapter := 0
	while chapter * LevelRecipe.CHAPTER_SIZE < level_count:
		var first := chapter * LevelRecipe.CHAPTER_SIZE
		result.append({"background": LevelRecipe.garden_of_chapter(chapter), "first": first,
			"last": mini(first + LevelRecipe.CHAPTER_SIZE, level_count) - 1})
		chapter += 1
	return result


## Chapter (0-based) in view, and how far through it (0..1) the camera is.
func chapter_at_camera() -> Vector2:
	var along := clampf(camera + 0.5, 0.0, maxf(level_count - 0.01, 0.0))
	var chapter := floori(along / LevelRecipe.CHAPTER_SIZE)
	return Vector2(chapter, (along - chapter * LevelRecipe.CHAPTER_SIZE) / LevelRecipe.CHAPTER_SIZE)


func _process(delta: float) -> void:
	if absf(_velocity) > 0.001 and not _pressing:
		_set_camera(camera + _velocity * delta)
		_velocity = move_toward(_velocity, 0.0, absf(_velocity) * FRICTION * delta + 0.002)


func _set_camera(value: float) -> void:
	var clamped := clampf(value, min_camera(), max_camera())
	if clamped != value:
		_velocity = 0.0
	camera = clamped
	_refresh_view()
	camera_moved.emit(camera)


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _path == null:
		return
	_set_camera(camera)


func _refresh_view() -> void:
	_update_backdrop()
	_update_markers()
	_update_signs()
	_place_badge()
	_path.queue_redraw()


# --- Backdrop ----------------------------------------------------------------

func _backdrop_rect(node_name: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate = Color(BACKDROP_LIGHT, BACKDROP_LIGHT, BACKDROP_LIGHT * 1.02)
	add_child(rect)
	return rect


## The chapter's painting, still behind the map; it drifts slightly as the
## player travels and blends into the next garden near the chapter's end.
func _update_backdrop() -> void:
	var at := chapter_at_camera()
	var chapter := int(at.x)
	var through := at.y
	_back.texture = _garden_texture(LevelRecipe.garden_of_chapter(chapter))
	_next_back.texture = _garden_texture(LevelRecipe.garden_of_chapter(chapter + 1))
	var blend_from := 1.0 - BLEND_LEVELS / LevelRecipe.CHAPTER_SIZE
	var has_next := (chapter + 1) * LevelRecipe.CHAPTER_SIZE < level_count
	var blend := smoothstep(blend_from, 1.0, through) if has_next else 0.0
	_next_back.modulate.a = blend
	_next_back.visible = blend > 0.001
	# Slightly taller than the screen so the drift never shows an edge.
	var drift := 0.0 if Motion.reduced else (through - 0.5) * DRIFT
	_back.position = Vector2(0, -DRIFT + drift)
	_back.size = Vector2(size.x, size.y + DRIFT * 2.0)
	_next_back.position = Vector2(0, -DRIFT + drift * 0.5)
	_next_back.size = _back.size


static var _textures := {}


static func _garden_texture(garden: String) -> Texture2D:
	if not _textures.has(garden):
		_textures[garden] = load(LevelCatalog.BACKGROUND_PATTERN % garden)
	return _textures[garden]


static var _vignette_tex: GradientTexture2D


## Soft darkening toward the screen edges, so the eye rests on the path.
static func _vignette_texture() -> GradientTexture2D:
	if _vignette_tex == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		gradient.colors = PackedColorArray([Color(0.08, 0.1, 0.12, 0.0), Color(0.08, 0.1, 0.12, 0.12),
			Color(0.06, 0.08, 0.1, 0.55)])
		_vignette_tex = GradientTexture2D.new()
		_vignette_tex.gradient = gradient
		_vignette_tex.fill = GradientTexture2D.FILL_RADIAL
		_vignette_tex.fill_from = Vector2(0.5, 0.55)
		_vignette_tex.fill_to = Vector2(1.15, 0.55)
		_vignette_tex.width = 64
		_vignette_tex.height = 64
	return _vignette_tex


# --- Markers -----------------------------------------------------------------

## Keeps a marker on every level in view (and frees the rest for reuse).
func _update_markers() -> void:
	if level_count == 0:
		return
	var lo := maxi(floori(camera - (size.y * (1.0 - FOCUS_Y) + VISIBLE_MARGIN) / SPACING), 0)
	var hi := mini(ceili(camera + (size.y * FOCUS_Y + VISIBLE_MARGIN) / SPACING), level_count - 1)
	for index: int in _active.keys():
		if index < lo or index > hi:
			var old: LevelNode = _active[index]
			_active.erase(index)
			old.hide()
			_pool.append(old)
	for index in range(lo, hi + 1):
		var node: LevelNode = _active.get(index)
		if node == null:
			node = _take_node()
			_active[index] = node
			_fill(node, index)
		node.position = screen_point(index) - node.marker_center()
		# Plates face the middle of the screen (re-placed here, as the width
		# may not be known yet when a stop is first filled).
		node.place_plate(-1 if screen_point(index).x > size.x / 2.0 else 1)
		node.visible = true
	# The badge stays above the markers.
	move_child(_badge, get_child_count() - 1)


func _take_node() -> LevelNode:
	if not _pool.is_empty():
		return _pool.pop_back()
	var node: LevelNode = NODE_SCENE.instantiate()
	add_child(node)
	return node


func _fill(node: LevelNode, index: int) -> void:
	node.scale = Vector2.ONE
	if node_setup.is_valid():
		node_setup.call(node, index + 1)
	node.set_labels_visible(true)


# --- Chapter signs -------------------------------------------------------------

## A sign naming each chapter's garden, where the chapter begins.
func _update_signs() -> void:
	var shown := {}
	var middle := int(chapter_at_camera().x)
	for chapter in range(middle - 1, middle + 2):
		if chapter < 0 or chapter * LevelRecipe.CHAPTER_SIZE >= level_count:
			continue
		var at := chapter * LevelRecipe.CHAPTER_SIZE - 0.55
		var point := screen_point(at)
		if point.y < -VISIBLE_MARGIN or point.y > size.y + VISIBLE_MARGIN:
			continue
		shown[chapter] = true
		var plate: Control = _signs.get(chapter)
		if plate == null:
			plate = _make_sign(chapter)
			_signs[chapter] = plate
			add_child(plate)
		var x := 28.0 if point.x > size.x / 2.0 else size.x - 28.0 - plate.size.x
		plate.position = Vector2(x, point.y - plate.size.y / 2.0)
	for chapter: int in _signs.keys():
		if not shown.has(chapter):
			(_signs[chapter] as Control).queue_free()
			_signs.erase(chapter)


func _make_sign(chapter: int) -> Control:
	var plate := PanelContainer.new()
	plate.name = "Chapter%d" % (chapter + 1)
	plate.theme_type_variation = &"MapLabelPlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", -6)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(lines)
	var caption := Label.new()
	caption.text = "CHAPTER %d" % (chapter + 1)
	caption.theme_type_variation = &"ToolLabel"
	caption.add_theme_font_size_override("font_size", 28)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(caption)
	var title := Label.new()
	title.text = BackgroundStyle.garden_name(LevelRecipe.garden_of_chapter(chapter))
	title.theme_type_variation = &"ToolLabel"
	title.add_theme_font_size_override("font_size", 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(title)
	plate.reset_size()
	return plate


# --- Badge ---------------------------------------------------------------------

func _move_badge(t: float) -> void:
	_badge_t = t
	_place_badge()


func _place_badge() -> void:
	if _badge == null:
		return
	var point := screen_point(_badge_t)
	_badge.position = point + Vector2(0, -BADGE_LIFT)
	_badge.visible = point.y > -VISIBLE_MARGIN and point.y < size.y + VISIBLE_MARGIN


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
			_velocity = clampf(_velocity, -12.0, 12.0)


func _nudge(amount: float) -> void:
	if _focus_tween:
		_focus_tween.kill()
	_velocity = 0.0
	_set_camera(camera + amount)


func _hit(point: Vector2) -> bool:
	return get_global_rect().has_point(point)


## The path for the stretch on screen: a soft sandy trail with stepping
## stones between the markers; stones up to the current level glow gold.
class _PathLayer extends Control:
	var world: JourneyWorld

	func _draw() -> void:
		if world == null or world.level_count == 0:
			return
		var reach := (world.size.y + JourneyWorld.VISIBLE_MARGIN) / JourneyWorld.SPACING
		var start := maxf(world.camera - reach, -0.8)
		var finish := minf(world.camera + reach, world.level_count - 1 + 0.8)
		var trail := PackedVector2Array()
		var t := start
		while t <= finish:
			trail.append(world.screen_point(t))
			t += 0.04
		if trail.size() >= 2:
			draw_polyline(trail, JourneyWorld.TRAIL_EDGE, 168.0, true)
			draw_polyline(trail, JourneyWorld.TRAIL, 150.0, true)
		var step := 1.0 / JourneyWorld.STONES_PER_LEVEL
		var s := ceilf(start / step) * step
		while s <= finish:
			if absf(s - roundf(s)) > 0.2 and s > -0.8 and s < world.level_count - 0.2:
				_stone(world.screen_point(s), s, s <= world.current_index)
			s += step

	func _stone(center: Vector2, t: float, lit: bool) -> void:
		var wobble := sin(t * 12.9) * 0.15
		var radius := Vector2(46.0 * (1.0 + wobble), 34.0 * (1.0 - wobble))
		_ellipse(center + Vector2(0, 5), radius * 1.06, JourneyWorld.STONE_RIM)
		var top := JourneyWorld.STONE_TOP.lerp(JourneyWorld.STONE_LIT, 0.55) if lit else JourneyWorld.STONE_TOP
		_ellipse(center, radius, top)
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
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if Motion.reduced or not visible:
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
