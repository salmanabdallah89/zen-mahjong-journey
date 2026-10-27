class_name BoardModel
extends RefCounted
## Live state of one board: which face sits on each position and which tiles
## have been removed. Enforces the solitaire rules; knows nothing about Nodes.

var geometry: BoardGeometry
var faces: PackedStringArray
var removed: PackedByteArray = PackedByteArray()
var remaining: int = 0


func _init(p_geometry: BoardGeometry, p_faces: PackedStringArray, p_removed := PackedByteArray()) -> void:
	assert(p_faces.size() == p_geometry.size(), "BoardModel: one face per position required")
	geometry = p_geometry
	faces = p_faces.duplicate()
	if p_removed.is_empty():
		removed.resize(geometry.size())
	else:
		removed = p_removed.duplicate()
	remaining = removed.count(0)


func tile_count() -> int:
	return geometry.size()


func is_removed(index: int) -> bool:
	return removed[index] != 0


func is_free(index: int) -> bool:
	return geometry.is_free(index, removed)


func face_of(index: int) -> String:
	return faces[index]


## Tiles currently stopping `index` from being free: the tiles covering it,
## or, if it is uncovered, the tiles on both its sides. Empty when free.
func blockers(index: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if is_removed(index) or is_free(index):
		return result
	for j in geometry.covered_by[index]:
		if not is_removed(j):
			result.append(j)
	if not result.is_empty():
		return result
	for j in geometry.left_neighbors[index]:
		if not is_removed(j):
			result.append(j)
	for j in geometry.right_neighbors[index]:
		if not is_removed(j):
			result.append(j)
	return result


func can_remove_pair(a: int, b: int) -> bool:
	if a == b or a < 0 or b < 0 or a >= tile_count() or b >= tile_count():
		return false
	return is_free(a) and is_free(b) and TileCatalog.faces_match(faces[a], faces[b])


func remove_pair(a: int, b: int) -> bool:
	if not can_remove_pair(a, b):
		return false
	removed[a] = 1
	removed[b] = 1
	remaining -= 2
	return true


## Puts a previously removed pair back (undo).
func restore_pair(a: int, b: int) -> void:
	assert(is_removed(a) and is_removed(b), "BoardModel: restoring tiles that are present")
	removed[a] = 0
	removed[b] = 0
	remaining += 2


func free_tiles() -> PackedInt32Array:
	return geometry.free_tiles(removed)


## Every pair of free tiles that could be removed right now.
func available_matches() -> Array[Vector2i]:
	var by_group := {}
	for i in free_tiles():
		var group := TileCatalog.match_group(faces[i])
		if not by_group.has(group):
			by_group[group] = []
		(by_group[group] as Array).append(i)
	var result: Array[Vector2i] = []
	for group: String in by_group:
		var tiles: Array = by_group[group]
		for x in tiles.size():
			for y in range(x + 1, tiles.size()):
				result.append(Vector2i(tiles[x], tiles[y]))
	return result


func has_moves() -> bool:
	var seen := {}
	for i in free_tiles():
		var group := TileCatalog.match_group(faces[i])
		if seen.has(group):
			return true
		seen[group] = true
	return false


func is_cleared() -> bool:
	return remaining == 0


func remaining_tiles() -> PackedInt32Array:
	var result := PackedInt32Array()
	for i in removed.size():
		if removed[i] == 0:
			result.append(i)
	return result


## Replaces the faces (shuffle / undo of a shuffle). Removed tiles keep theirs.
func set_faces(new_faces: PackedStringArray) -> void:
	assert(new_faces.size() == faces.size())
	faces = new_faces.duplicate()
