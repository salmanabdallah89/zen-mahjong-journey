class_name TrayBar
extends Control
## The tile tray above the board (TileTray, docs/TILE_TRAY.md): four slots on a
## forest panel with a gold rim. A tapped tile flies here from the board; when
## its match arrives, the two meet, flash gold and burst into petals, and the
## tiles left slide together. With three tiles waiting the rim warms to a
## soft rose and the empty slot breathes (a warning, never colour alone: the
## last slot shows a "!" when one place is left).
##
## Reduced animations: tiles appear and fade in place, no flight, burst or
## sliding.

const BURST_SCENE := preload("res://scenes/components/match_burst.tscn")
const FOREST := Color(0.20784314, 0.30980393, 0.26666668)
const GOLD := Color(0.78, 0.65, 0.42)
const IVORY := Color(0.96, 0.93, 0.87)
const ROSE := Color(0.86, 0.45, 0.45)
## Panel height (canvas px) and gaps.
const HEIGHT := 160.0
const PAD := 12.0
const GAP := 12.0
## Seconds of a tile's flight from the board.
const FLIGHT := 0.32
## Match: the swell and flash when the pair meets, then the bloom away.
const MEET_SWELL := 0.12
const BLOOM := 0.26
const SLIDE := 0.22
## Lift of the arc a flying tile follows.
const ARC := 70.0

## Tile copies resting in the slots, in tray order.
var _resting: Array[TileView] = []
var _warning := 0.0
var _warning_tween: Tween
var _hint_slot := -1
var _hint_tween: Tween


func _ready() -> void:
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	resized.connect(_layout_resting)


## Slot `i` in this control's coordinates.
func slot_rect(i: int) -> Rect2:
	var inner := Rect2(Vector2(PAD, PAD), size - Vector2(PAD, PAD) * 2.0)
	var width := (inner.size.x - GAP * (TileTray.CAPACITY - 1)) / TileTray.CAPACITY
	var side := minf(width, inner.size.y)
	var x := inner.position.x + i * (width + GAP) + (width - side * 0.82) / 2.0
	return Rect2(Vector2(x, inner.position.y), Vector2(side * 0.82, inner.size.y))


func slot_center_global(i: int) -> Vector2:
	return get_global_transform() * slot_rect(i).get_center()


## How many tiles rest in the tray (tests).
func count() -> int:
	return _resting.size()


## Tile index resting in slot `i` (tests).
func tile_in(i: int) -> int:
	return _resting[i].index if i < _resting.size() else -1


## Rebuilds the slots from the tray's tiles at once (restart, undo, shuffle,
## second chance).
func sync(tiles: Array[int], board: BoardView) -> void:
	for view in _resting:
		view.queue_free()
	_resting.clear()
	for index in tiles:
		var view := board.make_copy(index)
		add_child(view)
		_resting.append(view)
	_layout_resting()
	_update_warning()


## A tile taken from the board flies into the next slot. Returns the seconds
## until it lands.
func fly_in(index: int, board: BoardView) -> float:
	var view := _launch(index, board)
	_resting.append(view)
	var slot := _resting.size() - 1
	var seconds := _fly(view, slot, true)
	_update_warning()
	return seconds


## A tile taken from the board flies to its waiting partner in `slot`; they
## meet, flash and burst. Calls `met` when they touch and returns the seconds
## until then.
func fly_match(index: int, slot: int, board: BoardView, strength := 1, met := Callable()) -> float:
	var partner := _resting[slot]
	_resting.remove_at(slot)
	var view := _launch(index, board)
	var contact := _fly(view, slot, false)
	var tween := create_tween()
	tween.tween_interval(contact)
	tween.tween_callback(func() -> void:
		if met.is_valid():
			met.call()
		_bloom_pair(view, partner, strength)
		_slide_rest())
	_update_warning()
	return contact


## The newest tiles leave the tray for the board (second chance, undo).
func release_last(count_back: int) -> void:
	for i in mini(count_back, _resting.size()):
		var view: TileView = _resting.pop_back()
		_fade_away(view)
	_slide_rest()
	_update_warning()


## Hint: the slot whose tile has a free partner on the board breathes.
func highlight_slot(slot: int) -> void:
	_hint_slot = slot
	if _hint_tween:
		_hint_tween.kill()
		_hint_tween = null
	for i in _resting.size():
		_resting[i].set_highlight(TileView.Highlight.HINT if i == slot else TileView.Highlight.NONE)


func clear_highlight() -> void:
	highlight_slot(-1)


func _launch(index: int, board: BoardView) -> TileView:
	var view := board.make_copy(index)
	add_child(view)
	view.top_level = true
	view.z_index = 30
	view.global_position = board.tile_global_position(index)
	view.scale = Vector2.ONE * board.tile_scale()
	return view


## Flies `view` to `slot` (settling there when `rest`). Returns flight seconds.
func _fly(view: TileView, slot: int, rest: bool) -> float:
	var target := _resting_transform(view, slot)
	if not rest:
		# Lands just beside its partner, so the two visibly meet.
		target["position"] += Vector2(target["size"].x * 0.22, 0)
	if Motion.reduced:
		view.top_level = false
		view.z_index = 0
		view.position = target["position"]
		view.scale = target["scale"]
		view.modulate.a = 0.0
		view.create_tween().tween_property(view, "modulate:a", 1.0, 0.12)
		return 0.12
	var start: Vector2 = view.global_position
	var end: Vector2 = get_global_transform() * target["position"]
	var lift := Vector2(0, -ARC)
	var tween := view.create_tween()
	tween.tween_method(func(t: float) -> void:
		var arc := sin(t * PI)
		view.global_position = start.lerp(end, t) + lift * arc,
		0.0, 1.0, FLIGHT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(view, "scale", target["scale"], FLIGHT).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(view, "rotation", deg_to_rad(-6.0), FLIGHT * 0.5).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_property(view, "rotation", 0.0, 0.08)
	if rest:
		tween.tween_callback(func() -> void:
			view.top_level = false
			view.z_index = 0
			_layout_resting())
		# A soft settle into the slot.
		tween.tween_property(view, "scale", target["scale"] * 1.06, 0.07)
		tween.tween_property(view, "scale", target["scale"], 0.1)
	return FLIGHT + 0.08


## The pair swells together with a warm flash, then blooms into petals and
## gold while fading. Reduced animations: both fade out.
func _bloom_pair(a: TileView, b: TileView, strength: int) -> void:
	b.top_level = false
	b.z_index = 31
	a.z_index = 32
	var middle := ((a.global_position + b.global_position) / 2.0)
	if Motion.reduced:
		for view: TileView in [a, b]:
			var fade := view.create_tween()
			fade.tween_property(view, "modulate:a", 0.0, 0.16)
			fade.tween_callback(view.queue_free)
		return
	var burst: Node2D = BURST_SCENE.instantiate()
	burst.set("strength", maxi(strength, 3))
	burst.set("delay", MEET_SWELL)
	var face := a.face_center() * a.scale.x
	burst.position = get_global_transform().affine_inverse() * (middle + face)
	add_child(burst)
	for view: TileView in [a, b]:
		var base := view.scale
		# Swell around the face centre without moving the tile.
		var pivot := view.face_center()
		view.position -= pivot * (Vector2.ONE - base)
		view.pivot_offset = pivot
		var tween := view.create_tween()
		tween.tween_property(view, "scale", base * 1.16, MEET_SWELL).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(view, "modulate", Color(1.5, 1.38, 1.1), MEET_SWELL)
		tween.tween_property(view, "scale", base * 1.32, BLOOM).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(view, "modulate", Color(1.5, 1.38, 1.1, 0.0), BLOOM).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(view.queue_free)


func _fade_away(view: TileView) -> void:
	if Motion.reduced:
		view.queue_free()
		return
	var tween := view.create_tween()
	tween.tween_property(view, "modulate:a", 0.0, 0.16)
	tween.tween_callback(view.queue_free)


## Tiles left glide into the freed slots.
func _slide_rest() -> void:
	for i in _resting.size():
		var view := _resting[i]
		if view.top_level:
			continue
		var target := _resting_transform(view, i)
		if Motion.reduced:
			view.position = target["position"]
			continue
		view.create_tween().tween_property(view, "position", target["position"], SLIDE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _layout_resting() -> void:
	for i in _resting.size():
		var view := _resting[i]
		if view.top_level:
			continue
		var target := _resting_transform(view, i)
		view.position = target["position"]
		view.scale = target["scale"]
	queue_redraw()


## Position and scale that fit a tile's body into slot `i`.
func _resting_transform(view: TileView, i: int) -> Dictionary:
	var slot := slot_rect(i)
	var art := view.style if view.style else TileArtSet.active()
	var body := art.body_rect
	var fit := minf(slot.size.x / body.size.x, slot.size.y / body.size.y)
	var size_now := body.size * fit
	var top_left := slot.position + (slot.size - size_now) / 2.0 - body.position * fit
	return {"position": top_left, "scale": Vector2(fit, fit), "size": size_now}


## Three tiles waiting: the rim warms and breathes; a full tray stays warm.
func _update_warning() -> void:
	var target := 1.0 if _resting.size() >= TileTray.CLOSE_CALL else 0.0
	if _warning_tween:
		_warning_tween.kill()
	_warning_tween = create_tween()
	_warning_tween.tween_method(_set_warning, _warning, target, 0.3)


func _set_warning(value: float) -> void:
	_warning = value
	queue_redraw()


## Number of tiles the tray holds (resting ones, flights counted).
func warning_level() -> float:
	return _warning


func _draw() -> void:
	var panel := Rect2(Vector2.ZERO, size)
	var rim := GOLD.lerp(ROSE, _warning)
	_draw_round(panel.grow(-2.0), 28.0, Color(0.04, 0.07, 0.06, 0.35))
	_draw_round(panel.grow(-6.0), 26.0, Color(FOREST, 0.92))
	_draw_round_outline(panel.grow(-6.0), 26.0, rim, 4.0)
	for i in TileTray.CAPACITY:
		var slot := slot_rect(i)
		_draw_round(slot, 14.0, Color(0.03, 0.06, 0.05, 0.38))
		_draw_round_outline(slot, 14.0, Color(IVORY, 0.22), 2.0)
	# One place left: a small "!" on the last free slot (not colour alone).
	if _resting.size() == TileTray.CAPACITY - 1:
		var last := slot_rect(TileTray.CAPACITY - 1)
		var font := get_theme_default_font()
		var font_size := 64
		var mark := "!"
		var width := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		draw_string(font, last.get_center() + Vector2(-width / 2.0, font_size * 0.35), mark,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(ROSE, 0.9))


func _draw_round(rect: Rect2, radius: float, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	draw_style_box(box, rect)


func _draw_round_outline(rect: Rect2, radius: float, color: Color, width: float) -> void:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = color
	box.set_border_width_all(int(width))
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	draw_style_box(box, rect)
