class_name TileTray
extends RefCounted
## The tray above the board (docs/TILE_TRAY.md): a tapped free tile leaves the
## board and waits here; when its match arrives, both leave together. Four
## tiles without a pair fill the tray and stop the level. Holds tile indices
## of a BoardModel, in arrival order; the board model treats them as removed.

const CAPACITY := 4
## A tray this full is a close call (it counts like a mistake for stars).
const CLOSE_CALL := 3

var tiles: Array[int] = []


func size() -> int:
	return tiles.size()


func is_empty() -> bool:
	return tiles.is_empty()


func is_full() -> bool:
	return tiles.size() >= CAPACITY


func has(index: int) -> bool:
	return tiles.has(index)


## The waiting tile that matches `index`, or -1.
func partner_for(model: BoardModel, index: int) -> int:
	for waiting in tiles:
		if waiting != index and TileCatalog.faces_match(model.face_of(waiting), model.face_of(index)):
			return waiting
	return -1


## The outcome of taking a free tile into the tray.
class Move extends RefCounted:
	## The tile taken.
	var tile := -1
	## Its waiting partner when they matched (both left the tray), else -1.
	var partner := -1
	## Slot the partner waited in (for undo and the animation), else -1.
	var slot := -1
	## The tray is full of tiles without a pair: the level stops.
	var full := false
	## The tray reached CLOSE_CALL tiles with this move.
	var close_call := false

	func matched() -> bool:
		return partner >= 0


## Takes free tile `index` off the board into the tray; null if it is not free
## or the tray is already full.
func take(model: BoardModel, index: int) -> Move:
	if is_full() or not model.take_tile(index):
		return null
	var move := Move.new()
	move.tile = index
	move.partner = partner_for(model, index)
	if move.matched():
		move.slot = tiles.find(move.partner)
		tiles.remove_at(move.slot)
	else:
		tiles.append(index)
		move.slot = tiles.size() - 1
		move.full = is_full()
		move.close_call = tiles.size() == CLOSE_CALL
	return move


## Takes a move back: the tile returns to the board and a matched partner
## returns to its slot.
func undo(model: BoardModel, move: Move) -> void:
	if move.matched():
		tiles.insert(mini(move.slot, tiles.size()), move.partner)
	else:
		tiles.erase(move.tile)
	model.return_tile(move.tile)


## Sends the newest `count` waiting tiles back to the board (second chance);
## returns them, newest first.
func send_back(model: BoardModel, count: int) -> Array[int]:
	var sent: Array[int] = []
	for i in mini(count, tiles.size()):
		var index: int = tiles.pop_back()
		model.return_tile(index)
		sent.append(index)
	return sent


## Sends every waiting tile back to the board (before a shuffle).
func empty_into(model: BoardModel) -> Array[int]:
	return send_back(model, tiles.size())


## A free board tile whose partner waits in the tray, or -1 (Hint).
func free_match(model: BoardModel) -> int:
	for index in model.free_tiles():
		if partner_for(model, index) >= 0:
			return index
	return -1
