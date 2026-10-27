class_name CollectionPicker
extends Control
## Full-screen chooser for the tile collection: a grid of collection cards,
## live preview tiles for the highlighted collection, Apply and a back/return
## button. Collections whose artwork is incomplete can be looked at but not
## applied. Emits `closed` when dismissed either way.

signal closed

const TILE_SCENE := preload("res://scenes/components/tile_view.tscn")
## Faces used for previews; all have verified Classic art.
const PREVIEW_FACES: PackedStringArray = ["bamboo_5", "dots_7", "flowers_plum", "seasons_spring", "dots_2"]
const CARD_SAMPLE_FACES: PackedStringArray = ["dots_5", "bamboo_3", "flowers_orchid"]
const PREVIEW_SCALE := 0.62
const CARD_TILE_SCALE := 0.34

var _highlighted := ""
var _cards := {}
var _group := ButtonGroup.new()

@onready var _grid: GridContainer = %Grid
@onready var _preview_row: HBoxContainer = %PreviewRow
@onready var _status: Label = %Status
@onready var _apply: Button = %ApplyButton
@onready var _back: Button = %BackButton


func _ready() -> void:
	_apply.pressed.connect(_on_apply_pressed)
	_back.pressed.connect(_close)
	TileCollectionManager.collection_changed.connect(func(_id: String) -> void:
		if visible:
			_refresh_cards())


func open(back_label := "Back") -> void:
	_back.text = back_label
	_highlighted = TileCollectionManager.selected_id
	_build_cards()
	_show_preview(_highlighted)
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)


func highlighted_id() -> String:
	return _highlighted


## Highlights a collection as if its card was tapped (used by tests too).
func highlight(collection_id: String) -> void:
	_highlighted = collection_id
	if _cards.has(collection_id):
		(_cards[collection_id] as Button).button_pressed = true
	_show_preview(collection_id)


func _build_cards() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cards.clear()
	for collection in TileCollectionManager.collections():
		var card := _make_card(collection)
		_grid.add_child(card)
		_cards[collection.id] = card
	_refresh_cards()


func _refresh_cards() -> void:
	for collection_id: String in _cards:
		var card: Button = _cards[collection_id]
		var available := TileCollectionManager.is_available(collection_id)
		var status: Label = card.get_node("Box/Status")
		if collection_id == TileCollectionManager.selected_id:
			status.text = "IN USE"
		elif available:
			status.text = "TAP TO PREVIEW"
		elif TileCollectionManager.get_collection(collection_id).has_all_files():
			status.text = "NEEDS ART FIXES"
		else:
			status.text = "COMING SOON"
		card.modulate = Color.WHITE if available else Color(1, 1, 1, 0.62)
		card.button_pressed = collection_id == _highlighted


func _make_card(collection: TileCollection) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.button_group = _group
	card.theme_type_variation = &"CollectionCard"
	card.custom_minimum_size = Vector2(360, 250)
	card.focus_mode = Control.FOCUS_NONE
	card.pressed.connect(highlight.bind(collection.id))

	var box := VBoxContainer.new()
	box.name = "Box"
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 16.0
	box.offset_top = 14.0
	box.offset_right = -16.0
	box.offset_bottom = -14.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var tiles := HBoxContainer.new()
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tiles.custom_minimum_size = Vector2(0, TileArtSet.active().image_size.y * CARD_TILE_SCALE)
	box.add_child(tiles)
	if TileCollectionManager.is_available(collection.id):
		if ResourceLoader.exists(collection.thumbnail_path):
			var thumbnail := TextureRect.new()
			thumbnail.texture = load(collection.thumbnail_path)
			thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			thumbnail.custom_minimum_size = Vector2(110, 110)
			thumbnail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tiles.add_child(thumbnail)
			tiles.custom_minimum_size.y = 110
		else:
			var skin := _sample_skin(collection, CARD_SAMPLE_FACES)
			if skin:
				for face in CARD_SAMPLE_FACES:
					tiles.add_child(_tile_holder(skin, face, CARD_TILE_SCALE))

	var title := Label.new()
	title.text = collection.display_name
	title.theme_type_variation = &"DialogBodyLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var status := Label.new()
	status.name = "Status"
	status.theme_type_variation = &"HudCaptionLabel"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)
	for child in box.get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _show_preview(collection_id: String) -> void:
	for child in _preview_row.get_children():
		child.queue_free()
	var collection := TileCollectionManager.get_collection(collection_id)
	if collection == null:
		return
	var available := TileCollectionManager.is_available(collection_id)
	_apply.disabled = not available or collection_id == TileCollectionManager.selected_id
	if not available and collection.has_all_files():
		var problems := collection.validate(TileArtSet.active())
		_status.text = "%s\nNot available yet: %d artwork problem%s, such as %s." % [
			collection.description, problems.size(), "" if problems.size() == 1 else "s", problems[0]]
		return
	if not available:
		_status.text ="%s\nArtwork coming soon: %d of %d images still needed." % [
			collection.description, collection.missing_symbol_count() + _missing_extras(collection),
			collection.symbol_paths.size() + 1]
		return
	_status.text = collection.description
	var skin := _sample_skin(collection, PREVIEW_FACES)
	if skin:
		for face in PREVIEW_FACES:
			_preview_row.add_child(_tile_holder(skin, face, PREVIEW_SCALE))


func _missing_extras(collection: TileCollection) -> int:
	return 0 if ResourceLoader.exists(collection.body_path) else 1


func _sample_skin(collection: TileCollection, faces: PackedStringArray) -> TileSkin:
	var built := TileSkin.build(collection, TileArtSet.active(), faces, 1,
		func(path: String) -> Texture2D: return load(path) if ResourceLoader.exists(path) else null)
	return built.skin


func _tile_holder(skin: TileSkin, face: String, tile_scale: float) -> Control:
	# Tile styles differ in pixel size; scale so every preview tile is equally wide.
	var fitted := tile_scale * TileArtSet.active().image_size.x / skin.style.image_size.x
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = skin.style.image_size * fitted
	var view: TileView = TILE_SCENE.instantiate()
	view.style = skin.style
	tile_scale = fitted
	view.scale = Vector2(tile_scale, tile_scale)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Cards are built before they enter the tree; configure once the tile is ready.
	view.ready.connect(func() -> void:
		# Tiles pivot on their face centre for match animations; previews
		# scale from the corner so they stay inside their holder.
		view.pivot_offset = Vector2.ZERO
		view.set_layer(0, 0)
		view.set_art(skin.tile_texture(face), skin.symbol_texture(face), skin.symbol_padding))
	holder.add_child(view)
	return holder


func _on_apply_pressed() -> void:
	if TileCollectionManager.select(_highlighted):
		_close()
	else:
		_status.text = TileCollectionManager.take_notice()


func _close() -> void:
	hide()
	closed.emit()
