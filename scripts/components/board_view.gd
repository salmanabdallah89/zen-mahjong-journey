class_name BoardView
extends Control
## Renders a BoardModel as TileView nodes and scales the whole board to fit the
## space this Control is given, leaving the garden visible around it. Tile
## spacing and layer raise come from the active TileArtSet; what each face
## looks like comes from a TileSkin, which can be swapped without touching the
## model. Forwards tile presses by index and plays match effects.

signal tile_pressed(index: int)

const TILE_SCENE := preload("res://scenes/components/tile_view.tscn")
const BURST_SCENE := preload("res://scenes/components/match_burst.tscn")
## Largest on-screen width of a tile's top face, in canvas pixels. Keeps small
## boards from filling the screen.
const MAX_FACE_WIDTH := 148.0
## Share of the available width / height the board may use.
const FIT_WIDTH := 0.9
const FIT_HEIGHT := 0.94

var _model: BoardModel
var _art: TileArtSet
var _skin: TileSkin
var _tiles: Array[TileView] = []
var _layer: Control
var _backdrop: TextureRect
var _effects: Control
var _content := Rect2()


func _ready() -> void:
	resized.connect(_fit)


func show_board(model: BoardModel, skin: TileSkin) -> void:
	_model = model
	_skin = skin
	_art = skin.style
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
	_backdrop.texture = _backdrop_texture()
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_backdrop)

	_content = Rect2()
	for i: int in order:
		var view: TileView = TILE_SCENE.instantiate()
		view.style = _art
		view.index = i
		view.position = tile_origin(i)
		view.pressed.connect(_on_tile_pressed)
		_layer.add_child(view)
		view.set_layer(model.geometry.positions[i].z, top_layer)
		_tiles[i] = view
		var rect := Rect2(view.position + _art.body_rect.position, _art.body_rect.size)
		_content = rect if _content.size == Vector2.ZERO else _content.merge(rect)

	var pad := _content.size * 0.18
	_backdrop.position = _content.position - pad
	_backdrop.size = _content.size + pad * 2.0

	_effects = Control.new()
	_effects.name = "Effects"
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects.z_index = 2
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


## Updates only the blocked/free look of tiles still on the board.
func refresh_free_states() -> void:
	for i in _tiles.size():
		if not _model.is_removed(i):
			_tiles[i].set_free(_model.is_free(i))


func set_highlight(index: int, highlight: TileView.Highlight) -> void:
	if index >= 0 and index < _tiles.size():
		_tiles[index].set_highlight(highlight)


func clear_highlights() -> void:
	for view in _tiles:
		view.set_highlight(TileView.Highlight.NONE)


func play_removal(a: int, b: int) -> void:
	for i in [a, b]:
		var view := _tiles[i]
		view.play_removal()
		var burst: Node2D = BURST_SCENE.instantiate()
		burst.position = view.position + view.face_center()
		_effects.add_child(burst)


func play_restore(a: int, b: int) -> void:
	for i in [a, b]:
		_apply_art(i)
		_tiles[i].play_restore()
	refresh_free_states()


## On-screen width of one tile's top face, in canvas pixels.
func face_width_on_screen() -> float:
	return _layer.scale.x * _art.face_rect.size.x if _layer else 0.0


func _fit() -> void:
	if not _layer or _content.size == Vector2.ZERO or size.x <= 0.0 or size.y <= 0.0:
		return
	var fit := minf(size.x * FIT_WIDTH / _content.size.x, size.y * FIT_HEIGHT / _content.size.y)
	var board_scale := minf(fit, MAX_FACE_WIDTH / _art.face_rect.size.x)
	_layer.scale = Vector2(board_scale, board_scale)
	_layer.position = (size - _content.size * board_scale) / 2.0 - _content.position * board_scale


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


## Soft dark pool of shade under the board so tiles stand out from busy art.
static func _backdrop_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(0.1, 0.14, 0.13, 0.42),
		Color(0.1, 0.14, 0.13, 0.26), Color(0.1, 0.14, 0.13, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


func _apply_art(index: int) -> void:
	var face := _model.face_of(index)
	_tiles[index].set_art(_skin.tile_texture(face), _skin.symbol_texture(face), _skin.symbol_padding)


func _on_tile_pressed(view: TileView) -> void:
	tile_pressed.emit(view.index)
