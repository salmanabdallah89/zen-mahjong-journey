class_name TileSpecials
extends RefCounted
## Special tiles on a board (pure rules, no Nodes):
##   - Mystery tiles lie face-down until they first become free, then turn
##     over and stay face-up (undo does not hide them again). Only tiles that
##     start blocked are chosen, so they never hide a move the player could
##     make, and the solver and hints see the real faces.
##   - Golden lotus tiles score double: a match that includes one earns
##     GOLDEN_FACTOR times its points. One matching pair is gilded per level.
## The choice belongs to board positions (indexes), so shuffles keep it. It
## is drawn from its own RNG seeded from the level's deal seed: same level,
## same specials, and the deal itself is untouched.

const FIRST_GOLDEN_LEVEL := 3
const FIRST_MYSTERY_LEVEL := 4
const GOLDEN_FACTOR := 2
## Share of the tiles that start blocked which lie face-down, by difficulty.
const MYSTERY_SHARE := {1: 0.2, 2: 0.3, 3: 0.4, 4: 0.5}
## Mixed into the deal seed so this RNG never follows the deal's.
const SEED_SALT := 0x5EC1A1

## index -> true while the tile is face-down.
var mystery := {}
## index -> true for gilded tiles.
var golden := {}


## Specials for a fresh board of level `level_number`. `solution` is the
## deal's verified removal order (its pairs match, so a gilded pair always can).
static func plan(level_number: int, difficulty: int, model: BoardModel, solution: Array[Vector2i], deal_seed: int) -> TileSpecials:
	var specials := TileSpecials.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = deal_seed ^ SEED_SALT
	if level_number >= FIRST_GOLDEN_LEVEL and not solution.is_empty():
		# Not among the very first or last moves: found mid-game, never trivial.
		var low := floori(solution.size() * 0.25)
		var high := maxi(low, floori(solution.size() * 0.75) - 1)
		var pair := solution[rng.randi_range(low, high)]
		specials.golden[pair.x] = true
		specials.golden[pair.y] = true
	if level_number >= FIRST_MYSTERY_LEVEL:
		var blocked: Array[int] = []
		for i in model.tile_count():
			if not model.is_removed(i) and not model.is_free(i) and not specials.golden.has(i):
				blocked.append(i)
		var share := float(MYSTERY_SHARE.get(clampi(difficulty, 1, 4), 0.2))
		var count := roundi(blocked.size() * share)
		# Partial Fisher-Yates on our own RNG (never the global one).
		for k in count:
			var j := rng.randi_range(k, blocked.size() - 1)
			var swap := blocked[k]
			blocked[k] = blocked[j]
			blocked[j] = swap
			specials.mystery[blocked[k]] = true
	return specials


func is_mystery(index: int) -> bool:
	return mystery.has(index)


func is_golden(index: int) -> bool:
	return golden.has(index)


## Points factor for matching `a` with `b`.
func factor(a: int, b: int) -> int:
	return GOLDEN_FACTOR if golden.has(a) or golden.has(b) else 1


## Turns over every face-down tile that is now free and returns them.
func reveal_free(model: BoardModel) -> PackedInt32Array:
	var revealed := PackedInt32Array()
	for index: int in mystery.keys():
		if not model.is_removed(index) and model.is_free(index):
			revealed.append(index)
	revealed.sort()
	for index in revealed:
		mystery.erase(index)
	return revealed
