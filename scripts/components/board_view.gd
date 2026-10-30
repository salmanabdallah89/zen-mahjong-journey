class_name BoardView
extends Control
## Renders a BoardModel as TileView nodes and scales the whole board to fit the
## space this Control is given, leaving the garden visible around it. Tile
## spacing and layer raise come from the active TileArtSet; what each face
## looks like comes from a TileSkin, which can be swapped without touching the
## model. Forwards tile presses by index and plays the board's animations:
## matched pairs gliding together, undo reversing that, and shuffles that
## gather the tiles and spread them out again. The model is always updated
## first; animations only show it, and every one can be interrupted.

signal tile_pressed(index: int)
## A shuffle has swapped the faces and the tiles start spreading back out.
signal shuffle_spreading

const TILE_SCENE := preload("res://scenes/components/tile_view.tscn")
const BURST_SCENE := preload("res://scenes/components/match_burst.tscn")
## Largest on-screen width of a tile's top face, in canvas pixels. Keeps small
## boards from filling the screen.
const MAX_FACE_WIDTH := 190.0
## On tall board areas (height at least TALL_RATIO × width, as on 9:19.5 and
## longer phones) tiles may grow a little more.
const MAX_FACE_WIDTH_TALL := 210.0
const TALL_RATIO := 1.3
## Gap between the board's bottom edge and the footer (the message lane).
const FOOTER_GAP := 24.0
## Share of the available width / height the board may use.
const FIT_WIDTH := 0.98
const FIT_HEIGHT := 0.98
## Every level uses the tile size that fits this board, so tiles are the same
## size on all levels: boards stay within REFERENCE_GRID whole tiles and big
## levels stack upward instead of spreading. Only the lowest REFERENCE_LAYERS
## layers may span the full grid; higher ones must sit inset, or they widen the board.
const REFERENCE_GRID := Vector2(6, 6)
const REFERENCE_LAYERS := 3
## Glide time of a matched pair: short hops are quick, long ones a bit slower.
const MATCH_TRAVEL_MIN := 0.16
const MATCH_TRAVEL_MAX := 0.3
## Newly uncovered tiles pop once the matched pair has met.
const REVEAL_DELAY := 0.24
## Shuffle: gather, swap faces, spread out again.
const SHUFFLE_GATHER := 0.24
const SHUFFLE_SPREAD := 0.34
const SHUFFLE_STAGGER := 0.12
## Face of the 192 x 240 tile back images (assets/tiles/backs), without the edge.
const BACK_FACE_REGION := Rect2(7, 5, 165, 209)

var _model: BoardModel
var _art: TileArtSet
var _skin: TileSkin
var _tiles: Array[TileView] = []
var _layer: Control
var _backdrop: TextureRect
var _effects: Control
var _content := Rect2()
var _shuffle_tween: Tween
## Optional strip shown right under the tiles (the game's message lane). The
## board and the footer are fitted and centred together, so on tall screens
## the spare height goes above and below the pair instead of between them.
var footer: Control
## Centre strength of the shade pool behind the tiles (BackgroundStyle). Set
## before show_board(), or call set_backdrop_strength() any time.
var backdrop_strength := 0.56
## Mystery and golden lotus tiles of the current board (null: none). Set
## before show_board(); the game screen updates it, the board only shows it.
var specials: TileSpecials
## Tile back shown on face-down mystery tiles.
var mystery_back: Texture2D


func _ready() -> void:
	resized.connect(_fit)


func show_board(model: BoardModel, skin: TileSkin) -> void:
	_model = model
	_skin = skin
	_art = skin.style
	if _shuffle_tween:
		_shuffle_tween.kill()
		_shuffle_tween = null
	if _layer:
		_layer.queue_free()
	_layer = Control.new()
	_layer.name = "TileLayer"
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)

	_tiles.clear()
	_tiles.resize(model.tile_count())
	var top_layer := 0
	for p in model.geometry.positions:
		top_layer = maxi(top_layer, p.z)
	var order := range(model.tile_count())
	order.sort_custom(_draws_before)

	_backdrop = TextureRect.new()
	_backdrop.texture = _backdrop_texture(backdrop_strength)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_backdrop)

	_content = Rect2()
	for i: int in order:
		var view: TileView = TILE_SCENE.instantiate()
		view.style = _art
		view.index = i
		view.place_at(tile_origin(i))
		view.pressed.connect(_on_tile_pressed)
		_layer.add_child(view)
		view.set_layer(model.geometry.positions[i].z, top_layer)
		_tiles[i] = view
		var rect := Rect2(view.position + _art.body_rect.position, _art.body_rect.size)
		_content = rect if _content.size == Vector2.ZERO else _content.merge(rect)

	var pad := _content.size * 0.22
	_backdrop.position = _content.position - pad
	_backdrop.size = _content.size + pad * 2.0

	_effects = Control.new()
	_effects.name = "Effects"
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Above resting tiles, glows (z 1) and flying tiles (TileView.FLIGHT_Z).
	_effects.z_index = TileView.FLIGHT_Z + 1
	_layer.add_child(_effects)

	refresh_all()
	_fit()


func tile_origin(index: int) -> Vector2:
	var p := _model.geometry.positions[index]
	var step := _art.half_step()
	return Vector2(p.x * step.x, p.y * step.y) + _art.layer_shift * p.z


func tile(index: int) -> TileView:
	return _tiles[index]


## Syncs every tile with the model: visibility, face art and free state.
func refresh_all() -> void:
	for i in _tiles.size():
		var view := _tiles[i]
		if _model.is_removed(i):
			view.hide()
			continue
		view.reset_visual()
		_apply_art(i)
		view.set_free(_model.is_free(i), false)


## Shows the board in another collection's art. Board state is untouched;
## a different tile style (size, spacing) rebuilds the layout from the model.
func apply_skin(skin: TileSkin) -> void:
	if skin.style != _art:
		show_board(_model, skin)
		return
	_skin = skin
	for i in _tiles.size():
		_apply_art(i)


func skin() -> TileSkin:
	return _skin


## Updates only the blocked/free look of tiles still on the board. With
## `reveal_delay` >= 0, tiles that just became free pop after that delay.
func refresh_free_states(reveal_delay := -1.0) -> void:
	for i in _tiles.size():
		if not _model.is_removed(i):
			_tiles[i].set_free(_model.is_free(i), true, reveal_delay)


## True while a shuffle is playing; the board ignores taps until it settles.
func is_busy() -> bool:
	return _shuffle_tween != null and _shuffle_tween.is_running()


func set_highlight(index: int, highlight: TileView.Highlight) -> void:
	if index >= 0 and index < _tiles.size():
		_tiles[index].set_highlight(highlight)


func clear_highlights() -> void:
	for view in _tiles:
		view.set_highlight(TileView.Highlight.NONE)


## A matched pair glides together, touches and blooms away; the burst grows
## with the combo (matches in a row). Tiles uncovered by it pop afterwards, and
## the face-down tiles in `revealed` turn over. Returns the seconds until the
## pair touches, so sound and haptics can land on that moment.
func play_removal(a: int, b: int, combo := 1, revealed := PackedInt32Array()) -> float:
	var meet := meeting_points(a, b)
	var travel := _travel_time(a, b)
	_tiles[a].play_match(meet[0], travel)
	_tiles[b].play_match(meet[1], travel)
	var contact := 0.0 if Motion.reduced else TileView.MATCH_ANTICIPATION + travel
	var burst: Node2D = BURST_SCENE.instantiate()
	burst.set("strength", combo)
	burst.set("delay", contact)
	burst.position = (meet[0] + meet[1]) / 2.0 + _tiles[a].face_center()
	_effects.add_child(burst)
	refresh_free_states(contact)
	for index in revealed:
		_tiles[index].play_flip(contact)
	return contact


## Undo of a match: the pair reappears where it met and glides back home.
func play_restore(a: int, b: int) -> void:
	var meet := meeting_points(a, b)
	var travel := _travel_time(a, b)
	for k in 2:
		var i: int = [a, b][k]
		_apply_art(i)
		_tiles[i].play_restore(meet[k], travel)
	refresh_free_states()


## Where tiles `a` and `b` meet when matched: side by side (or one above the
## other) at the midpoint between them. Tiles already touching stay put.
func meeting_points(a: int, b: int) -> Array[Vector2]:
	var home_a := _tiles[a].home_position
	var home_b := _tiles[b].home_position
	var apart := home_b - home_a
	var face := _art.face_rect.size
	if apart.length() < 1.0:
		return [home_a, home_b]
	var along := apart.normalized()
	# Distance between centres when the faces just touch along that direction.
	var touch := minf(face.x / maxf(absf(along.x), 0.001), face.y / maxf(absf(along.y), 0.001)) * 0.92
	if apart.length() <= touch:
		return [home_a, home_b]
	var middle := (home_a + home_b) / 2.0
	return [middle - along * touch / 2.0, middle + along * touch / 2.0]


## Screen position where a pair meets (for combo text and effects).
func meeting_point_global(a: int, b: int) -> Vector2:
	var meet := meeting_points(a, b)
	return _layer.get_global_transform() * ((meet[0] + meet[1]) / 2.0 + _tiles[a].face_center())


## Shuffle: tiles still on the board gather toward the centre, change faces
## while gathered, and spread back out. Taps wait until it settles (is_busy).
func play_shuffle() -> void:
	if _shuffle_tween:
		_shuffle_tween.kill()
	var center := _content.get_center() - _art.face_rect.get_center()
	var gather := Motion.duration(SHUFFLE_GATHER)
	var spread := Motion.duration(SHUFFLE_SPREAD)
	var stagger := 0.0 if Motion.reduced else SHUFFLE_STAGGER
	var count := maxi(_tiles.size() - 1, 1)
	for i in _tiles.size():
		if _model.is_removed(i):
			continue
		var view := _tiles[i]
		# Pull each tile 70 % of the way in, so the pile keeps a loose shape.
		var target := view.home_position.lerp(center, 0.7)
		view.shuffle_gather(target, stagger * i / count, gather)
	_shuffle_tween = create_tween()
	_shuffle_tween.tween_interval(gather + stagger)
	_shuffle_tween.tween_callback(_swap_and_spread.bind(spread, stagger))
	_shuffle_tween.tween_interval(spread + stagger)
	_shuffle_tween.tween_callback(func() -> void: refresh_all())


func _swap_and_spread(spread: float, stagger: float) -> void:
	shuffle_spreading.emit()
	var count := maxi(_tiles.size() - 1, 1)
	for i in _tiles.size():
		if _model.is_removed(i):
			continue
		_apply_art(i)
		_tiles[i].set_free(_model.is_free(i), false)
		_tiles[i].shuffle_return(stagger * (count - i) / count, spread)


func _travel_time(a: int, b: int) -> float:
	if Motion.reduced:
		return 0.0
	var apart := _tiles[a].home_position.distance_to(_tiles[b].home_position)
	var reach := clampf(apart / (_art.face_rect.size.x * 6.0), 0.0, 1.0)
	return lerpf(MATCH_TRAVEL_MIN, MATCH_TRAVEL_MAX, reach)


## On-screen width of one tile's top face, in canvas pixels.
func face_width_on_screen() -> float:
	return _layer.scale.x * _art.face_rect.size.x if _layer else 0.0


func _fit() -> void:
	if not _layer or _content.size == Vector2.ZERO or size.x <= 0.0 or size.y <= 0.0:
		return
	var reserve := footer.custom_minimum_size.y + FOOTER_GAP if footer else 0.0
	var room := Vector2(size.x, maxf(size.y - reserve, 1.0))
	var reference := _reference_size()
	# A board larger than the standard one still fits (never expected in play).
	var box := Vector2(maxf(reference.x, _content.size.x), maxf(reference.y, _content.size.y))
	var fit := minf(room.x * FIT_WIDTH / box.x, room.y * FIT_HEIGHT / box.y)
	var board_scale := minf(fit, max_face_width() / _art.face_rect.size.x)
	_layer.scale = Vector2(board_scale, board_scale)
	var board_size := _content.size * board_scale
	var top := (size.y - board_size.y - reserve) / 2.0
	_layer.position = Vector2((size.x - board_size.x) / 2.0, top) - _content.position * board_scale
	if footer:
		footer.position = Vector2(0.0, top + board_size.y + FOOTER_GAP)
		footer.size = Vector2(size.x, footer.custom_minimum_size.y)


## Bounding box of a full standard board, before scaling.
func _reference_size() -> Vector2:
	var step := _art.half_step() * 2.0
	var depth := _art.layer_shift.abs() * (REFERENCE_LAYERS - 1)
	return step * (REFERENCE_GRID - Vector2.ONE) + _art.body_rect.size + depth


## Size of the tiles' bounding box before scaling (tests, layout checks).
func content_size() -> Vector2:
	return _content.size


## Largest on-screen tile face width for the current board area.
func max_face_width() -> float:
	var reserve := footer.custom_minimum_size.y + FOOTER_GAP if footer else 0.0
	return MAX_FACE_WIDTH_TALL if size.y - reserve >= size.x * TALL_RATIO else MAX_FACE_WIDTH


## Lower layers first; within a layer top-to-bottom then left-to-right, so
## each tile overlaps the drawn edge of the tile before it.
func _draws_before(a: int, b: int) -> bool:
	var pa := _model.geometry.positions[a]
	var pb := _model.geometry.positions[b]
	if pa.z != pb.z:
		return pa.z < pb.z
	if pa.y != pb.y:
		return pa.y < pb.y
	return pa.x < pb.x


func set_backdrop_strength(strength: float) -> void:
	backdrop_strength = strength
	if _backdrop:
		_backdrop.texture = _backdrop_texture(strength)


## Soft dark pool of shade under the board so tiles stand out from busy art.
## `strength` is the centre alpha; the middle ring keeps the same proportion.
static func _backdrop_texture(strength: float) -> GradientTexture2D:
	var key := snappedf(strength, 0.01)
	if _backdrops.has(key):
		return _backdrops[key]
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(0.08, 0.11, 0.1, key),
		Color(0.08, 0.11, 0.1, key * 0.64), Color(0.08, 0.11, 0.1, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	_backdrops[key] = texture
	return texture


static var _backdrops := {}


func _apply_art(index: int) -> void:
	var face := _model.face_of(index)
	var view := _tiles[index]
	view.set_art(_skin.tile_texture(face), _skin.symbol_texture(face), _skin.symbol_padding)
	var face_down := specials != null and specials.is_mystery(index)
	view.set_mystery(_mystery_cover() if face_down else null, not _art.mystery_back.is_empty())
	view.set_golden(specials != null and specials.is_golden(index))


## The tile style's own full back, or the face part of the garden's tile back
## (its rim and edge cropped away), drawn over a mystery tile's face.
func _mystery_cover() -> Texture2D:
	if not _art.mystery_back.is_empty():
		return load(_art.mystery_back)
	if mystery_back == null:
		return null
	if not _covers.has(mystery_back):
		var cover := AtlasTexture.new()
		cover.atlas = mystery_back
		cover.region = BACK_FACE_REGION
		_covers[mystery_back] = cover
	return _covers[mystery_back]


static var _covers := {}


func _on_tile_pressed(view: TileView) -> void:
	tile_pressed.emit(view.index)
