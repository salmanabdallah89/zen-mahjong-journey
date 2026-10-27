class_name BoardView
extends Control
## Renders a BoardModel as TileView nodes and scales the whole board to fit
## whatever space this Control is given. Forwards tile presses by index.

signal tile_pressed(index: int)

const TILE_SCENE := preload("res://scenes/components/tile_view.tscn")
## Distance between half-tile grid steps, in tile-art pixels. Slightly less
## than the face size so neighbouring tiles sit snugly over each other's edge.
const HALF_STEP := Vector2(80, 100)
## Each layer is drawn up and to the left so stacks read as raised.
const LAYER_SHIFT := Vector2(-12, -16)
const MAX_SCALE := 1.25
const FIT_PADDING := 0.96

var _model: BoardModel
var _tiles: Array[TileView] = []
var _layer: Control
var _content := Rect2()


func _ready() -> void:
	resized.connect(_fit)


func show_board(model: BoardModel) -> void:
	_model = model
	if _layer:
		_layer.queue_free()
	_layer = Control.new()
	_layer.name = "TileLayer"
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)

	_tiles.clear()
	_tiles.resize(model.tile_count())
	var order := range(model.tile_count())
	order.sort_custom(_draws_before)
	_content = Rect2()
	for i: int in order:
		var tile: TileView = TILE_SCENE.instantiate()
		tile.index = i
		tile.position = tile_origin(i)
		tile.pressed.connect(_on_tile_pressed)
		_layer.add_child(tile)
		_tiles[i] = tile
		var rect := Rect2(tile.position, TileView.TILE_SIZE)
		_content = rect if _content.size == Vector2.ZERO else _content.merge(rect)
	refresh_all()
	_fit()


func tile_origin(index: int) -> Vector2:
	var p := _model.geometry.positions[index]
	return Vector2(p.x * HALF_STEP.x, p.y * HALF_STEP.y) + LAYER_SHIFT * p.z


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
		view.set_face(_face_texture(_model.face_of(i)))
	refresh_free_states()


## Updates only the blocked/free tint of tiles still on the board.
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
	_tiles[a].play_removal()
	_tiles[b].play_removal()


func play_restore(a: int, b: int) -> void:
	for i in [a, b]:
		_tiles[i].set_face(_face_texture(_model.face_of(i)))
		_tiles[i].play_restore()
	refresh_free_states()


func _fit() -> void:
	if not _layer or _content.size == Vector2.ZERO or size.x <= 0.0 or size.y <= 0.0:
		return
	var fit := minf(size.x / _content.size.x, size.y / _content.size.y) * FIT_PADDING
	var board_scale := minf(fit, MAX_SCALE)
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


func _face_texture(face_id: String) -> Texture2D:
	return load(TileCatalog.face_texture_path(face_id))


func _on_tile_pressed(view: TileView) -> void:
	tile_pressed.emit(view.index)
