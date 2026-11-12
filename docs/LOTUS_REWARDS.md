# Lotus Gifts and Perfect Clears

Two small, calm reasons to keep going: something to look forward to every few levels,
and recognition for a clean clear. No timers, no pressure, nothing bought.

## Lotus Gifts
- A lotus bud sits on the journey path after every 5th level (`LotusRewards.EVERY`),
  beside the thread between that level and the next, toward the middle of the screen.
- **Closed** (level not cleared): a small, dim bud in a gold ring. Tapping it says which
  level opens it and what it holds.
- **Ready** (level cleared, not opened): a larger bud that glows and gently breathes
  (reduced animations: it glows, still). Level Complete says "A Lotus Gift has bloomed on
  your journey map", and the unlock toast on the map says to tap it.
- **Opened**: a small open flower. Tapping it lists the saved hints and shuffles.
- Opening: the bud blooms with a few petals (reduced animations: a short fade), the
  `reward` sound, a light vibration, and a toast naming what was saved.

| Gift | Contents |
|---|---|
| 1st of a chapter (level 5, 25, ...) | 1 hint, 1 shuffle |
| 2nd (10, 30, ...) | 2 hints |
| 3rd (15, 35, ...) | 3 hints |
| Chapter end (20, 40, ...) | 2 hints, 2 shuffles |

- Saved tools are capped at 9 each (`MAX_SAVED`), so they never replace every ad.
- In a level, a hint or shuffle comes from: the free one of the level, then a saved one,
  then a rewarded ad. The tool's count shows free + saved. Without ads (web) tools are free
  and saved ones are not spent.
- Returning players: gifts of levels cleared before this feature count as already opened
  (`baseline` in progress section `rewards`), so nobody is handed a pile of them at once.
- Gifts depend on the level number only. Never change `gift_for` in a way that alters
  earlier gifts.

## Perfect Clear
- A clear with no mistakes, no hints and no shuffles (undo is allowed).
- Level Complete is titled "Perfect Clear!" and a gold lotus crest opens on top of the
  dialog with the `reward` sound (reduced animations: it fades in open).
- Saved per level (`perfect` in the level's section); the level's tile on the map then
  carries a small gold lotus stamp. The stamp is a shape, not only a colour.
- Daily Challenge and Word Garden are unchanged.

## Code
| Piece | File |
|---|---|
| Rules | `scripts/core/lotus_rewards.gd`, tests `tests/unit/test_lotus_rewards.gd` |
| Saves | `ProgressStore` (`open_lotus`, `saved_tools`, `spend_saved_tool`, `record_perfect`) |
| Lotus drawing | `scripts/components/lotus_mark.gd` |
| Gift on the map | `scripts/components/lotus_gift.gd`, placed by `JourneyWorld._update_gifts` |
| Map wiring | `journey_screen.gd` (`_setup_gift`, `_on_gift_pressed`) |
| In a level | `game_screen.gd` (hint/shuffle order, `_play_perfect_bloom`) |
| Tests | ads_test `_test_saved_tools`, playthrough `_test_lotus_gifts` and the Perfect title |

## Later
A painted lotus bud icon (closed, ready, open) would look better than the drawn petals.
