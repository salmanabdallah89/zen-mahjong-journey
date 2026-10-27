class_name BoardSolver
extends RefCounted
## Depth-first search for a full clearing sequence from a board's current
## state. Used for hints and to independently confirm generated boards.
##
## Pruning: when every remaining tile of a match group is free, removing a pair
## of them can never hurt (removal only frees tiles), so that move is taken
## without branching. Failed states are memoised. The search stops after
## `node_budget` states so it can safely run on the main thread.

const DEFAULT_BUDGET := 20000


class Result extends RefCounted:
	var solved: bool = false
	## True when the budget ran out before an answer was proven either way.
	var exhausted: bool = false
	var moves: Array[Vector2i] = []
	var nodes: int = 0


static func solve(model: BoardModel, node_budget := DEFAULT_BUDGET) -> Result:
	var search := _Search.new(model.geometry, model.faces, model.removed, node_budget)
	var result := Result.new()
	result.solved = search.run(model.remaining)
	result.exhausted = search.out_of_budget
	result.moves = search.path
	result.nodes = search.nodes
	return result


class _Search extends RefCounted:
	var geometry: BoardGeometry
	var groups: PackedStringArray = PackedStringArray()
	var removed: PackedByteArray
	var budget: int
	var nodes: int = 0
	var out_of_budget: bool = false
	var path: Array[Vector2i] = []
	var _dead := {}

	func _init(p_geometry: BoardGeometry, faces: PackedStringArray, p_removed: PackedByteArray, p_budget: int) -> void:
		geometry = p_geometry
		removed = p_removed.duplicate()
		budget = p_budget
		groups.resize(faces.size())
		for i in faces.size():
			groups[i] = TileCatalog.match_group(faces[i])

	func run(left: int) -> bool:
		if left == 0:
			return true
		nodes += 1
		if nodes > budget:
			out_of_budget = true
			return false
		var key := removed.hex_encode()
		if _dead.has(key):
			return false
		for move in _candidate_moves():
			removed[move.x] = 1
			removed[move.y] = 1
			path.append(move)
			if run(left - 2):
				return true
			path.pop_back()
			removed[move.x] = 0
			removed[move.y] = 0
			if out_of_budget:
				return false
		_dead[key] = true
		return false

	func _candidate_moves() -> Array[Vector2i]:
		var free_by_group := {}
		var remaining_by_group := {}
		for i in removed.size():
			if removed[i] != 0:
				continue
			var g := groups[i]
			remaining_by_group[g] = int(remaining_by_group.get(g, 0)) + 1
			if geometry.is_free(i, removed):
				if not free_by_group.has(g):
					free_by_group[g] = []
				(free_by_group[g] as Array).append(i)

		var moves: Array[Vector2i] = []
		for g: String in free_by_group:
			var tiles: Array = free_by_group[g]
			if tiles.size() < 2:
				continue
			if tiles.size() == int(remaining_by_group[g]):
				return [Vector2i(tiles[0], tiles[1])] as Array[Vector2i]
			for x in tiles.size():
				for y in range(x + 1, tiles.size()):
					moves.append(Vector2i(tiles[x], tiles[y]))
		moves.sort_custom(_by_unblocking)
		return moves

	func _by_unblocking(a: Vector2i, b: Vector2i) -> bool:
		return _score(a) > _score(b)

	func _score(move: Vector2i) -> int:
		return geometry.blocking_weight[move.x] + geometry.blocking_weight[move.y] \
			+ geometry.positions[move.x].z + geometry.positions[move.y].z
