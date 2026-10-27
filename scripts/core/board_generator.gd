class_name BoardGenerator
extends RefCounted
## Deterministic, seed-based dealing that only produces solvable boards.
##
## The deal is built backwards: starting from the full layout, it repeatedly
## picks two tiles that are free and marks them removed, recording the order.
## Each recorded pair then receives two matching faces. Playing the recorded
## pairs forward from the full board is therefore a complete solution; every
## deal is replayed through BoardModel's rules before it is accepted.
##
## Only RandomNumberGenerator seeded from the inputs is used, never the global
## RNG, so the same seed gives the same board on every device.

const MAX_ATTEMPTS := 500


class Result extends RefCounted:
	var ok: bool = false
	var faces: PackedStringArray = PackedStringArray()
	## Pairs in removal order; a verified complete solution when ok is true.
	var solution: Array[Vector2i] = []
	var attempts: int = 0


## Deals a fresh board for `geometry` using faces from `face_pool`.
static func generate(geometry: BoardGeometry, face_pool: PackedStringArray, deal_seed: int) -> Result:
	var result := Result.new()
	var n := geometry.size()
	if n == 0 or n % 2 != 0 or face_pool.is_empty():
		push_error("BoardGenerator: need an even, non-empty layout and a face pool")
		return result
	var removed := PackedByteArray()
	removed.resize(n)
	for attempt in MAX_ATTEMPTS:
		var rng := _rng_for(deal_seed, attempt)
		var order := _deal_order(geometry, removed, rng)
		if order.is_empty():
			continue
		var tokens := _tokens_from_pool(face_pool, order.size(), rng)
		var faces := PackedStringArray()
		faces.resize(n)
		_assign_tokens(faces, order, tokens, rng)
		if verify_solution(geometry, faces, removed, order):
			result.ok = true
			result.faces = faces
			result.solution = order
			result.attempts = attempt + 1
			return result
	result.attempts = MAX_ATTEMPTS
	return result


## Redistributes the faces of the tiles still on `model` so that the remaining
## board is solvable again. The multiset of faces is preserved. Returns a
## Result whose `faces` covers every position (removed tiles keep theirs).
static func reshuffle(model: BoardModel, deal_seed: int) -> Result:
	var result := Result.new()
	var by_group := {}
	for i in model.remaining_tiles():
		var group := TileCatalog.match_group(model.faces[i])
		if not by_group.has(group):
			by_group[group] = []
		(by_group[group] as Array).append(model.faces[i])

	for attempt in MAX_ATTEMPTS:
		var rng := _rng_for(deal_seed, attempt)
		var order := _deal_order(model.geometry, model.removed, rng)
		if order.is_empty():
			continue
		var tokens: Array[PackedStringArray] = []
		for group: String in _sorted_keys(by_group):
			var group_faces := PackedStringArray(by_group[group])
			_shuffle_strings(group_faces, rng)
			for k in range(0, group_faces.size(), 2):
				tokens.append(PackedStringArray([group_faces[k], group_faces[k + 1]]))
		_shuffle_tokens(tokens, rng)
		var faces := model.faces.duplicate()
		_assign_tokens(faces, order, tokens, rng)
		if verify_solution(model.geometry, faces, model.removed, order):
			result.ok = true
			result.faces = faces
			result.solution = order
			result.attempts = attempt + 1
			return result
	result.attempts = MAX_ATTEMPTS
	return result


## Replays `solution` with the real rules. True only if every pair is free and
## matching when played and the board ends empty.
static func verify_solution(geometry: BoardGeometry, faces: PackedStringArray,
		start_removed: PackedByteArray, solution: Array[Vector2i]) -> bool:
	var model := BoardModel.new(geometry, faces, start_removed)
	for pair in solution:
		if not model.remove_pair(pair.x, pair.y):
			return false
	return model.is_cleared()


static func _rng_for(deal_seed: int, attempt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = deal_seed * 1000003 + attempt * 7919 + 17
	return rng


## Removes free pairs from the start state until nothing is left. Returns an
## empty array if it gets stuck (fewer than two free tiles remain).
static func _deal_order(geometry: BoardGeometry, start_removed: PackedByteArray,
		rng: RandomNumberGenerator) -> Array[Vector2i]:
	var removed := start_removed.duplicate()
	var left := removed.count(0)
	var order: Array[Vector2i] = []
	while left > 0:
		var free := geometry.free_tiles(removed)
		if free.size() < 2:
			return [] as Array[Vector2i]
		var a := _pick_weighted(free, geometry, rng, -1)
		var b := _pick_weighted(free, geometry, rng, a)
		removed[a] = 1
		removed[b] = 1
		left -= 2
		order.append(Vector2i(a, b))
	return order


## Prefers high tiles and tiles that block others, which keeps the backwards
## deal from stranding tall stacks with only one free tile.
static func _pick_weighted(candidates: PackedInt32Array, geometry: BoardGeometry,
		rng: RandomNumberGenerator, exclude: int) -> int:
	var total := 0
	for i in candidates:
		if i != exclude:
			total += _weight(i, geometry)
	var roll := rng.randi_range(1, total)
	for i in candidates:
		if i == exclude:
			continue
		roll -= _weight(i, geometry)
		if roll <= 0:
			return i
	return candidates[candidates.size() - 1]


static func _weight(index: int, geometry: BoardGeometry) -> int:
	return 1 + geometry.positions[index].z * 3 + geometry.blocking_weight[index]


## Builds `pairs_needed` matching face pairs. Each normal face contributes two
## pairs (four tiles); flowers and seasons pair different faces of their suit.
## When the pool is too small the faces are reused.
static func _tokens_from_pool(pool: PackedStringArray, pairs_needed: int,
		rng: RandomNumberGenerator) -> Array[PackedStringArray]:
	var bundles: Array = []
	var grouped := {}
	for face in pool:
		var group := TileCatalog.match_group(face)
		if group == face:
			bundles.append([PackedStringArray([face, face]), PackedStringArray([face, face])])
		else:
			if not grouped.has(group):
				grouped[group] = []
			(grouped[group] as Array).append(face)
	for group: String in _sorted_keys(grouped):
		var members := PackedStringArray(grouped[group])
		_shuffle_strings(members, rng)
		var bundle: Array = []
		for k in range(0, members.size() - 1, 2):
			bundle.append(PackedStringArray([members[k], members[k + 1]]))
		if not bundle.is_empty():
			bundles.append(bundle)

	var tokens: Array[PackedStringArray] = []
	while tokens.size() < pairs_needed:
		var round_bundles := bundles.duplicate()
		_shuffle_array(round_bundles, rng)
		for bundle: Array in round_bundles:
			for token: PackedStringArray in bundle:
				if tokens.size() < pairs_needed:
					tokens.append(token)
	_shuffle_tokens(tokens, rng)
	return tokens


static func _assign_tokens(faces: PackedStringArray, order: Array[Vector2i],
		tokens: Array[PackedStringArray], rng: RandomNumberGenerator) -> void:
	for k in order.size():
		var token := tokens[k]
		var flip := rng.randi_range(0, 1) == 1
		faces[order[k].x] = token[1] if flip else token[0]
		faces[order[k].y] = token[0] if flip else token[1]


static func _sorted_keys(dict: Dictionary) -> Array:
	var keys := dict.keys()
	keys.sort()
	return keys


static func _shuffle_strings(values: PackedStringArray, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := values[i]
		values[i] = values[j]
		values[j] = tmp


static func _shuffle_tokens(values: Array[PackedStringArray], rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := values[i]
		values[i] = values[j]
		values[j] = tmp


static func _shuffle_array(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = values[i]
		values[i] = values[j]
		values[j] = tmp
