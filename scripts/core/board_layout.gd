class_name BoardLayout
extends RefCounted
## A board shape loaded from data/layouts/*.json.
##
## Format: {"id": "...", "layers": [{"z": 0, "offset": [hx, hy], "rows": ["XX.X", ...]}]}
## Each "X" is a tile. Rows/columns are whole tiles; "offset" is in half-tile
## units so a layer can sit between the tiles below it. "z" defaults to the
## layer's index. Positions are normalised so the top-left tile starts at 0,0.

var id: String = ""
var positions: Array[Vector3i] = []


static func load_json(path: String) -> BoardLayout:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("BoardLayout: cannot read '%s'" % path)
		return null
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("BoardLayout: '%s' is not a JSON object" % path)
		return null
	return from_dict(data)


static func from_dict(data: Dictionary) -> BoardLayout:
	var layout := BoardLayout.new()
	layout.id = str(data.get("id", ""))
	var layers: Array = data.get("layers", [])
	for layer_index in layers.size():
		var layer: Dictionary = layers[layer_index]
		var z := int(layer.get("z", layer_index))
		var offset: Array = layer.get("offset", [0, 0])
		var rows: Array = layer.get("rows", [])
		for r in rows.size():
			var row := str(rows[r])
			for c in row.length():
				if row[c] == "X":
					layout.positions.append(Vector3i(int(offset[0]) + c * 2, int(offset[1]) + r * 2, z))
	layout._normalize()
	return layout


func tile_count() -> int:
	return positions.size()


func layer_count() -> int:
	var top := -1
	for p in positions:
		top = maxi(top, p.z)
	return top + 1


## Returns human-readable problems; empty when the layout is usable.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if positions.is_empty():
		errors.append("layout has no tiles")
	if positions.size() % 2 != 0:
		errors.append("odd tile count %d" % positions.size())
	for i in positions.size():
		var a := positions[i]
		var supported := a.z == 0
		for j in positions.size():
			if i == j:
				continue
			var b := positions[j]
			var overlaps := absi(a.x - b.x) < 2 and absi(a.y - b.y) < 2
			if overlaps and b.z == a.z and j > i:
				errors.append("tiles %s and %s overlap" % [a, b])
			if overlaps and b.z == a.z - 1:
				supported = true
		if not supported:
			errors.append("tile %s floats with nothing beneath it" % a)
	return errors


func build_geometry() -> BoardGeometry:
	return BoardGeometry.new(positions)


func _normalize() -> void:
	if positions.is_empty():
		return
	var min_x := positions[0].x
	var min_y := positions[0].y
	for p in positions:
		min_x = mini(min_x, p.x)
		min_y = mini(min_y, p.y)
	for i in positions.size():
		positions[i] -= Vector3i(min_x, min_y, 0)
