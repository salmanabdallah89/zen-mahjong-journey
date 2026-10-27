class_name BoardGeometry
extends RefCounted
## Tile positions and the precomputed blocking relations between them.
##
## Coordinates are in half-tile units: a tile at (x, y, z) covers the area
## x..x+2 by y..y+2 on layer z. A tile is free when no tile on a higher layer
## overlaps it and at least one of its long sides (left or right) is open.

var positions: Array[Vector3i] = []
## For each tile, the tiles on higher layers that overlap it.
var covered_by: Array[PackedInt32Array] = []
## For each tile, the same-layer tiles directly touching its left / right side.
var left_neighbors: Array[PackedInt32Array] = []
var right_neighbors: Array[PackedInt32Array] = []
## For each tile, how many other tiles it covers or flanks. Used to rank moves.
var blocking_weight: PackedInt32Array = PackedInt32Array()


func _init(p_positions: Array[Vector3i]) -> void:
	positions = p_positions
	var n := positions.size()
	blocking_weight.resize(n)
	for i in n:
		covered_by.append(PackedInt32Array())
		left_neighbors.append(PackedInt32Array())
		right_neighbors.append(PackedInt32Array())

	for i in n:
		var a := positions[i]
		for j in n:
			if i == j:
				continue
			var b := positions[j]
			if absi(a.y - b.y) >= 2:
				continue
			if b.z > a.z:
				if absi(a.x - b.x) < 2:
					covered_by[i].append(j)
					blocking_weight[j] += 1
			elif b.z == a.z:
				if b.x == a.x - 2:
					left_neighbors[i].append(j)
					blocking_weight[j] += 1
				elif b.x == a.x + 2:
					right_neighbors[i].append(j)
					blocking_weight[j] += 1


func size() -> int:
	return positions.size()


## `removed` holds one byte per tile; non-zero means the tile is gone.
func is_free(index: int, removed: PackedByteArray) -> bool:
	if removed[index] != 0:
		return false
	for j in covered_by[index]:
		if removed[j] == 0:
			return false
	var left_open := true
	for j in left_neighbors[index]:
		if removed[j] == 0:
			left_open = false
			break
	if left_open:
		return true
	for j in right_neighbors[index]:
		if removed[j] == 0:
			return false
	return true


func free_tiles(removed: PackedByteArray) -> PackedInt32Array:
	var result := PackedInt32Array()
	for i in positions.size():
		if is_free(i, removed):
			result.append(i)
	return result
