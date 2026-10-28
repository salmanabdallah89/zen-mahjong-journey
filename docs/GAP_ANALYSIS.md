# Gap analysis and plan: premium presentation (Phase 3)

## Source material

**No gameplay recordings were available.** No video files exist in the project, the workspace,
or the user's Downloads, Videos or Desktop folders. This analysis therefore does **not** compare
against Vita Mahjong footage. It is based on:

- our own game: code review, 61 screenshots at phone and tablet shapes, and the live web build;
- widely shared conventions of premium mobile tile-matching games: large, high-contrast tiles,
  clear free/blocked states, a tight link between touch, motion, sound and haptics, escalating
  combo feedback, and a staged reward screen.

To compare against the real benchmark, put the recordings (`.mp4`/`.mov`) in
`docs/reference/recordings/` and ask for a frame-by-frame review. Nothing will be copied from
them; they are only a reference for pacing and feel.

## Gaps, by priority

### P1. Tile presentation (implemented in this phase)
| Gap | Evidence (before) | Target |
|-----|-------------------|--------|
| Tiles are small | Faces capped at 148 canvas px; boards use 90 % of the width; level 10 tiles ≈ 110 px on a 1080 px phone | Small boards up to ~190 px, large boards use ~95 % of the width |
| Blocked tiles washed out | 50 % ivory veil flattens the art; hard to plan ahead | Blocked tiles slightly dimmed and cooler, art still readable; free tiles bright |
| Weak depth | Drop shadow uniform; lower layers barely darker | Stronger, softer shadow under raised layers; clearer layer stepping |
| Symbols small on the tile | Symbol collections use 80 % of the face | ≈ 88 % of the face |
| Busy background competes with tiles | Board backdrop at 42 % shade | A deeper, softer pool behind the board (P4 covers the rest) |

### P2. Match feedback (implemented in this phase)
| Gap | Evidence (before) | Target |
|-----|-------------------|--------|
| Sound and touch don't line up with the visual | Bell and haptic fire on the tap; the tiles meet 0.24 to 0.38 s later | Bell and haptic fire at the moment the tiles touch |
| Level complete interrupts the last match | Dialog opens on the same frame the last pair starts gliding | Dialog waits until the last pair has met and bloomed |
| Glide feels mechanical | Straight line, constant scale | A short anticipation, a gentle arc, a soft "clack" squash on contact |
| Burst particles are plain dots | Round gradient blobs | Original four-point glints, plus a small shockwave on every match |

### P3. Combos (next)
- Praise words that escalate (for example "Nice", "Great", "Serene", "Masterful") instead of only
  "Combo ×N"; colour and size steps; a combo meter that drains between matches.
- Original cue per tier (layered bell harmonies) on top of the climbing melody.
- Stronger burst tiers at 5 and 8, a soft screen-edge glow at 10. Reduced motion: text only.

### P4. Background and board balance (next)
- Per-background contrast tuning (some backgrounds are much brighter than others).
- Slight blur or desaturation of the background behind the board area only (one shader, mobile-cheap)
  or a pre-blurred derived copy of each background (new files, originals untouched).
- HUD and toolbar on calmer, more opaque panels.

### P5. Level complete (next)
- Staged sequence: board clears, a banner drops in, stars fill one by one with a meter, then
  stats count up (time, mistakes, best), then buttons appear.
- Show progression: the next level's name and the journey path progress, the stars total
  moving up, and unlocks.
- Reduced motion: a single fade with the same information.

## Constraints kept
Collections, levels, saves and settings untouched in format; everything original; reduced motion
supported; effects scale with the board (they live in the board layer, which is scaled to fit), so
they look the same relative to the tiles on every screen size.

## Phase 3a: what was implemented (P1 tile presentation, P2 match feedback)

Before/after: `docs/screenshots/phase3_tiles_before_after.png` (level 10 Classic and level 5 Mixed;
left before, right after).

| Change | Before | After | File |
|--------|--------|-------|------|
| Largest tile face | 148 px | 190 px (level 1 tiles about 35 % larger) | `board_view.gd` `MAX_FACE_WIDTH` |
| Board width used | 90 % | 95 % (big boards about 5 % larger) | `FIT_WIDTH`, `FIT_HEIGHT` 0.94 → 0.96 |
| Board backdrop | 42 % shade | 56 % shade, wider soft edge | `board_view.gd` |
| Blocked tiles | 50 % ivory veil (washed out) | 14 % veil and a gentle warm dim: art stays readable | `tile_view.gd` |
| Layer depth | 3.5 % darker per layer, shadow 10+3z | 5 % per layer, deeper and softer shadow 12+4z, larger offset | `tile_view.gd` |
| Symbol size | 80 % of the face | 88 % of the face | `data/collections/*.json` `symbol_padding` 0.1 → 0.06 |
| Match motion | swell, straight glide, bloom | dip-and-swell anticipation, glide on a gentle arc, soft squash and warm flash on contact, bloom | `tile_view.gd` `play_match` |
| Match sound and haptic | on the tap | when the tiles touch; bells keep match order, at least 90 ms apart | `game_screen.gd`, `audio_manager.gd` (`next_match_step`, `play_match_step`) |
| Combo text | on the tap | when the pair touches | `game_screen.gd` |
| Last pair | Level Complete covered it on the same frame | Dialog opens 0.3 s after the last pair touches | `game_screen.gd` |
| Particles | round dots | original four-point glints (drawn in code), a faint shockwave on every match, combo ring kept | `match_burst.gd` |

Reduced motion: no anticipation, arc, squash or shockwave; tiles fade in place and sound plays at
once. Effects live in the board layer, so they scale with the tiles on every screen size.

Tests: unit 69 passed; playthrough 228 checks, audio 72, ads 48, all passed. Tests now wait for
the contact moment before checking the bell, combo text or Level Complete. A new check confirms the
dialog does not cover the last pair.

## Still to do

- **P3 combos:** escalating praise words, tiered cues, combo meter.
- **P4 background balance:** per-background contrast, softer background behind the board.
  Toasts (for example the blocked-tile tip) now overlap the bottom tile row more often because
  tiles are larger. Move toasts to a spot that never covers the board.
- **P5 level complete:** staged banner, star meter, stat count-up, journey progress.
- **Tile art itself** (needs the artist): classic captions ("PLUM", "SPRING") are still tiny,
  16 classic faces are unusable, Fruits and Vegetables look-alikes.
- **On a device:** feel of the contact timing (bell lands 0.25 to 0.4 s after the second tap),
  60 FPS with glints on a mid-range phone.
