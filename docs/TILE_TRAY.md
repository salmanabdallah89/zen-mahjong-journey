# Tile tray (4 slots)

Every level, the Daily Challenge included, plays with a tray above the board. Word Garden keeps
the classic two-tap rule (it is a learning mode). There are no hearts.

## Rules (TileTray, unit-tested)
- Tap a free tile: it leaves the board and waits in the tray (`CAPACITY` 4).
- When a tile's match (same match group: any flower with any flower, any season with any
  season) is waiting, the tapped tile joins it and both leave. Points, combo bells, praise,
  golden lotus x2 and milestones work as before.
- Four tiles without a pair fill the tray: **Tray Full**, the level stops.
  - "Watch Ad: Free 2 Places" (the rewarded second chance, once per attempt) sends the two
    newest tiles back to the board. The undo history is cleared then.
  - "Replay" restarts the level (an interstitial may show, as after any finished level).
  - "Levels" / "Calendar" leaves.
- Three tiles waiting is a **close call**: a toast warns "one place left", the tray rim warms to
  rose and the last slot shows "!" (not colour alone). Close calls count as mistakes for stars
  (2 stars: at most one; 3 stars: none and half the time left), for the score's flawless bonus,
  Perfect Clear and the Daily stars.
- Deals are unchanged and every deal stays solvable: playing the deal's solution pair by pair
  never holds more than one tile in the tray.

## Tools
- **Hint:** a free tile whose partner waits in the tray (both glow), else a free pair on the board.
  Nothing to show: a toast, and no hint is spent.
- **Shuffle:** the waiting tiles go back to the board first, then the board is reshuffled.
- **Magnet:** pulls the match of the oldest waiting tile out of the board into the tray, even from
  under other tiles (buried matches first); with an empty tray it takes a free tile and pulls its match
  once that tile lands. One free per level (`free_magnets_per_level`), then one per rewarded ad
  (placement `magnet`). Counts as a tool: no Perfect Clear, no Quiet Hands. Undo puts the tile back.
- **Undo:** a waiting tile flies home; undoing a match sends the tapped tile home and puts its
  partner back in its slot (points taken back); undoing a close call removes it. Undoing a shuffle
  puts the waiting tiles back in the tray.

## Look and motion (TrayBar)
- Forest panel with a gold rim and four soft slots, between the score and the board.
- A tapped tile flies to its slot along a gentle arc and settles with a small bounce.
- A match: the tile flies to its partner, both swell with a warm gold flash, then bloom away in
  petals and gold (MatchBurst), and the remaining tiles slide together.
- The pair's picture is released (`MatchEmblem`): it lifts out of the tray into the middle of the
  screen as a glowing medallion with turning light rays, a halo and orbiting sparkles (more and
  bigger with the combo, gold for a golden lotus pair), holds a breath, then shoots into the score,
  which pulses, and bursts into a little shower of light. One at a time: a new match sends the
  previous one straight to the score. Not on the last pair (Level Complete takes over). It never
  takes taps.
- Reduced animations: tiles fade in and out in place; no flight, burst or sliding. The emblem only fades in beside the tray.

## Code
| Piece | File |
|---|---|
| Rules | `scripts/core/tile_tray.gd`, tests `tests/unit/test_tile_tray.gd` |
| Board model | `BoardModel.take_tile`, `return_tile`, `set_taken` |
| Tray view | `scripts/components/tray_bar.gd` (`%Tray` in game_screen.tscn) |
| Board view | `BoardView.play_take`, `play_return`, `make_copy` |
| Game screen | `_take_into_tray`, `_tray_match`, `_finish_match`, `_give_tray_hint`, `_undo_tray`, `LossReason.TRAY` |
| Tests | playthrough (tools, tray full, animations), ads (saved tools, tray second chance), audio |
