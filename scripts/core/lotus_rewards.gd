class_name LotusRewards
extends RefCounted
## Lotus Gifts and Perfect Clears (docs/LOTUS_REWARDS.md).
##
## Every EVERY levels a lotus bud waits on the journey path. Clearing that
## level lets the player open it for a few saved hints and shuffles, which the
## game spends before it ever offers an ad for one. Gifts depend on the level
## number only, so every player meets the same ones. A Perfect Clear is a clear
## with no mistakes, no hints and no shuffles.

const EVERY := 5
## The gift at the end of each chapter is a little bigger.
const CHAPTER_GIFT := {"hints": 2, "shuffles": 2}
## Gifts within a chapter, in turn.
const GIFTS: Array[Dictionary] = [
	{"hints": 1, "shuffles": 1},
	{"hints": 2, "shuffles": 0},
	{"hints": 3, "shuffles": 0},
]
## Saved tools never grow past this, so a long journey cannot replace every ad.
const MAX_SAVED := 9


static func is_gift_level(level: int) -> bool:
	return level > 0 and level % EVERY == 0


## The gift of a gift level: {"hints": int, "shuffles": int}.
static func gift_for(level: int) -> Dictionary:
	if level % LevelRecipe.CHAPTER_SIZE == 0:
		return CHAPTER_GIFT.duplicate()
	var turn := ((level % LevelRecipe.CHAPTER_SIZE) / EVERY - 1) % GIFTS.size()
	return GIFTS[turn].duplicate()


## The next gift level after `level` (the level itself if it is one).
static func next_gift_level(level: int) -> int:
	return ceili(maxf(level, 1) / float(EVERY)) * EVERY


## "2 hints and 1 shuffle"
static func describe(gift: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in ["hints", "shuffles"]:
		var amount := int(gift.get(key, 0))
		if amount > 0:
			var word: String = key if amount != 1 else key.trim_suffix("s")
			parts.append("%d %s" % [amount, word])
	return " and ".join(parts) if not parts.is_empty() else "nothing"


## No mistakes, no hints and no shuffles.
static func is_perfect(mistakes: int, hints: int, shuffles: int) -> bool:
	return mistakes == 0 and hints == 0 and shuffles == 0
