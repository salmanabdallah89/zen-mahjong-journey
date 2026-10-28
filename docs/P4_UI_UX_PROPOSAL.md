# P4 proposal: board, background and screen UX (not implemented)

Status: **all steps implemented** (step 1: P4.1, P4.3; step 2: P4.2 A, P4.4; steps 3–4: P4.5 journey,
P4.6 tutorial, P4.7 web loading page, P4.8 accessibility). See the step sections at the end.
See "Step 1: implemented" at the end. Based on the live web build of `879063c`, tested on
the following viewports:

- a 375 × 812 phone viewport (canvas 1080 × 2338);
- a 412 × 915 tall Android viewport (canvas 1080 × 2398);
- the automated screenshot set (9:16, 9:19.5, 3:4 tablet).

Background figures were measured on the source art, over the part of each background that sits
behind the board.

## What the live test showed (inputs to this proposal)

| # | Observation | Evidence |
|---|-------------|----------|
| O1 | On tall phones the board doesn't use the height. A large empty band sits between the board and the message lane. | 412 × 915, level 2: the board ends at y ≈ 600, the lane starts at y ≈ 790 (about 20 % of the screen is empty garden) |
| O2 | Backgrounds differ a lot behind the board. Golden Sakura and Bamboo Forest are the brightest and busiest; Moonlight Sanctuary is much darker. | Mean brightness 114 / 107 / 113 / 83 (0–255) and edge density 27.4 / 27.3 / 22.7 / 23.8 for golden sakura / bamboo forest / misty temple / moonlight sanctuary |
| O3 | Rapid matches stack their blooms, rings and glows into one bright cluster on the board. | Three or more pairs inside a second, 375 × 812, level 1 |
| O4 | Lane glints are cut by the lane's clip edge, which shows a visible straight line. | Excellent! and Zen Master! at 375 × 812 |
| O5 | Praise is shown only briefly (about 1 s) and is easy to miss during fast play. | The Excellent! tier was visible only mid-fade in the test |
| O6 | Journey: the next level's name and difficulty sit behind the current marker. | "Bamboo Grove" under marker 2 (audit L11) |
| O7 | The first web load takes about 15–20 s before the title buttons appear, with only Godot's default progress bar. | 17 MB download (10 MB engine, 7 MB game data) |
| O8 | The HUD uses two stacked bars (top panel, then the hearts pill), which costs height on short phones. | All shapes |
| O9 | The game screen has no first-time guidance; the rule is explained only after a blocked tap. | Level 1 |

Things that already work well and should be kept:
- the message lane: no overlap on any tested shape;
- large readable tiles;
- warm, dimmed blocked tiles;
- feedback timed to when the tiles touch;
- Level Complete waiting for the last pair;
- reduced animations, persisted across reloads.

## Proposals, in priority order

### P4.1 Use the height on tall phones (layout)
- **Change:** the board area is centred vertically between the hearts and the message lane. The lane
  follows the board's bottom edge, with a maximum gap of about 24 px, instead of being fixed above the
  toolbar. Any spare height goes above and below the board/lane block equally.
- **Also:** let the tile size cap scale with the screen height on tall shapes (for example
  `MAX_FACE_WIDTH` up to about 210 px when height allows), still capped by width.
- **Files:** `game_screen.tscn` (layout containers), `board_view.gd` (fit), `game_screen.gd`.
- **Acceptance:**
  - on 9:16, 9:19.5, 9:21 and 3:4 the empty band between the board and the lane is at most 5 % of the screen height;
  - the lane never overlaps tiles (existing test);
  - tiles are never smaller than today.
- **Risk:** low. The board-fit tests already cover four shapes.

### P4.2 Calm the background behind the board (visual balance)
Three options, cheapest first:

| Option | How | Cost on Android | Look |
|--------|-----|-----------------|------|
| A. Per-background backdrop | Backdrop strength per background: stronger for Golden Sakura and Bamboo Forest, lighter for Moonlight Sanctuary, from a table in `levels.json` or `AudioCatalog`-style data | None | Good; keeps the art crisp |
| B. Pre-blurred derived copies | New files `bg_*_soft.png` (blurred and slightly desaturated copies; **originals untouched**), cross-faded under the board area only | +~1.5 MB download (lossy) | Best "depth of field" feel |
| C. Live blur shader | `BackBufferCopy` and a two-pass blur behind the board | A full-screen read-back every frame: risky on mid-range GL ES 3 devices | Same as B |

- **Recommendation:** A now, with B as an option once the device frame rate is known. Avoid C.
- **Acceptance:** contrast between the free-tile face and the area behind the board ≥ 3:1 on every
  background, measured from screenshots, while the garden stays visible around the board.

### P4.3 Tame rapid-match effects (feel)
- At most 2 board rings at a time (older ones fade faster).
- Flying tiles drop their gold selection glow during the glide (the flash at contact stays).
- Lane glints get a soft vertical fade instead of a hard clip: use a gradient mask texture on the
  lane's glint layer, or keep glint emission inside the lane's middle 60 %.
- Praise from Great! up holds 0.2 s longer; if a higher tier arrives while one is showing, it
  replaces it with a quick swap instead of a full fade-in.
- **Acceptance:** in a 10-match streak captured every 100 ms, no frame shows more than 2 rings, and
  no straight clip line appears in the lane.

### P4.4 Compact HUD (space and clarity)
- Merge the hearts into the top bar (under the level name) to free about 90 canvas px for the board.
- Hint shows its free count as a small badge on the button instead of "Hint (1)" in the label.
- Undo shows a disabled state that is clearly different from enabled (today the difference is subtle).
- Time warning: a soft pulse of the clock in the last 10 s (reduced motion: colour only).
- **Acceptance:** the HUD plus hearts are ≤ 180 canvas px tall (today about 300, measured from the 375 × 812 screenshots); all touch targets ≥ 120 px.

### P4.5 Journey map readability
- Labels for markers further away fade out sooner and never draw over a nearer marker (sort by depth
  and hide labels whose rectangle intersects a nearer marker).
- The current level gets a name plate that always sits above everything.
- **Acceptance:** no label overlaps a marker in the journey screenshots at any of the four shapes.

### P4.6 First-run guidance (onboarding)
- Level 1 only, first time: a three-step, skippable overlay: "Match two identical free tiles",
  "A tile is free when nothing covers it and its left or right side is open" (with a highlighted
  example), "Hints and Shuffle help when you're stuck". Uses the message lane and the existing
  outline effect; no new art.
- Saved as seen in user settings (through `SafeConfig`).
- **Acceptance:** shown once; never covers a tile the player needs to tap in that step.

### P4.7 Web loading screen (web only)
- A custom HTML export shell: the garden colour, the game title and a calm progress bar, replacing
  Godot's default page. Plus a "Tap to start" step, which also unlocks web audio reliably.
- Optional: trim the web download (the engine is 10 MB compressed; check that GitHub Pages serves
  `.wasm` and `.pck` gzip-compressed, and drop unused fonts and locales).
- **Acceptance:** branded loading from the first frame; time to the title on a cold load reported
  before and after.

### P4.8 Accessibility pass
- Classic dots use red and green: check the deuteranopia simulation, and add a shape cue if needed (in
  the art, by the artist).
- Text-size check: every label ≥ 26 canvas px at 1080 width (some captions are 26 today).
- Reduced animations also turns off the background drift and the journey petals (drift already;
  journey petals to verify).

## Suggested order and size

| Step | Items | Size |
|------|-------|------|
| 1 | P4.1 layout + P4.3 effect taming | Small–medium, highest visible gain |
| 2 | P4.2 option A + P4.4 compact HUD | Medium |
| 3 | P4.5 journey labels + P4.6 onboarding | Medium |
| 4 | P4.7 web loading + P4.8 accessibility | Small each |

Every step keeps all collections, levels, saves and settings unchanged. Each step adds regression
checks: layout gaps per shape, overlap checks, ring counts and label overlap, and gets before/after
screenshots.

## Decisions needed from you

1. P4.2: per-background backdrop only (A), or also pre-blurred copies (B, +1.5 MB)?
2. P4.4: OK to merge the hearts into the top bar? It changes the look of the HUD.
3. P4.6: do you want the first-run guidance, or keep level 1 free of overlays?
4. P4.7: is a "Tap to start" step on the web acceptable?


## Step 1: implemented

Before/after (each pair: left before, right after): `docs/screenshots/p4_step1_before_after.png`.

| Item | Change | File |
|------|--------|------|
| P4.1 | The board and the message lane are fitted and centred as one block. The lane sits 24 px under the tiles' real bottom edge, and spare height goes above and below the block instead of between them. | `board_view.gd` (`footer`, `_fit`), `game_screen.tscn` (lane moved under the board), `game_screen.gd` |
| P4.1 | Tall board areas (height ≥ 1.3 × width, as on 9:19.5 and longer) allow tiles up to 210 px (190 elsewhere). The height fit went from 96 % to 98 % so tiles are never smaller than before. | `board_view.gd` (`MAX_FACE_WIDTH_TALL`, `max_face_width()`) |
| P4.3 | At most 2 board rings on screen at once, across all bursts. | `match_burst.gd` (`MAX_RINGS`, `active_rings`) |
| P4.3 | Gliding tiles drop their gold outline; the contact flash marks the match. | `tile_view.gd` |
| P4.3 | Lane glints use a compact style: no flash or rings, short sparkles and gently drifting petals, so nothing reaches the lane's clip edge. | `match_burst.gd` (`compact`), `combo_feedback.gd` |
| P4.3 | Praise from Great! up holds 0.75 s (Nice! 0.55 s). A higher tier arriving while praise shows swaps in quickly instead of fading in from nothing. | `combo_feedback.gd` |

Acceptance, as automated checks on 9:16, 9:19.5, 9:21 and 3:4:
- the gap between the tiles and the lane is at most 5 % of the screen height (it is 24 px);
- the spare height above the board matches the space below the lane (within 40 px);
- tiles are not smaller than the old layout would give;
- a 10-match streak never shows more than 2 rings;
- lane glints are compact;
- gliding tiles show no outline.

Not done in step 1: steps 2 to 4 (background balance, compact HUD, journey labels, onboarding, web
loading, accessibility).


## Step 2: implemented

Decisions applied: per-background shading only (no blurred copies); hearts merged into the top bar.

Before/after at 320 × 568, 375 × 812, 390 × 844 and 768 × 1024 (pairs, left before):
`docs/screenshots/p4_step2_before_after.png`. Hint, Zen Master! and Level Complete at 320 × 568,
390 × 844 and the tablet: `docs/screenshots/p4_step2_states.png`.

| Item | Change | File |
|------|--------|------|
| P4.2 A | `BackgroundStyle`: per-background scenery dim and board-shade strength, tuned from the measured brightness and detail. Golden Sakura and Bamboo Forest: scenery ×0.86, shade 0.68. Misty Temple: ×0.90, 0.62. Moonlight Sanctuary: ×0.97, 0.48 (already dark). Plain colour multiplies on existing nodes: no new textures, nodes or passes. | `scripts/core/background_style.gd` (new), `board_view.gd` (`set_backdrop_strength`), `game_screen.gd` |
| P4.4 | Hearts moved into the top bar, on a slim dark pill under the level name (54 px hearts, which read clearly on the ivory bar). The separate hearts panel is gone, so the board starts higher. | `game_screen.tscn`, `game_screen.gd` (`HEART_SIZE`), theme `HeartsPill` |
| Fix | Combo praise was left-aligned (cut off on tablets) since step 1 moved the lane: it was created before the lane was sized and kept a zero width. It now fills the lane and is centred on every shape. | `combo_feedback.gd` |

Measured on the 9:16 level screenshots, over the board area (tiles included):

| Background | Brightness | Detail (edges) |
|------------|------------|----------------|
| Golden Sakura | −2 % | −8 % |
| Bamboo Forest | −5 % | −9 % |
| Misty Temple | −3 % | −6 % |
| Moonlight Sanctuary | 0 % | +1 % |

The tiles themselves are not shaded (tested).

Acceptance (automated, on 9:16, 9:19.5, 9:21 and 3:4):
- hearts are inside the top bar;
- the top bar is fully on screen and at most 240 px tall;
- no tile reaches the top bar;
- every level background has its own shading within gentle bounds;
- free tiles are never dimmed;
- praise is centred in the lane (within 4 px) and fits inside it.


## Steps 3–4: implemented

Screenshots at 320 × 568, 375 × 812, 390 × 844 and 768 × 1024: `docs/screenshots/p4_steps3_4_four_sizes.png`.
Each row shows the tutorial, a hint, Zen Master!, Level Complete and the journey map. Also:
`p4_tutorial.png`, `p4_journey.png`, `p4_settings_320x568.png`.

### P4.6 First-play tutorial (`scripts/components/first_play_tutorial.gd`)
- **Three interactive steps on the real level-1 board,** in the message lane, so it never covers a tile:
  1. a glowing free pair with identical pictures, which the player taps;
  2. "a tile is free when…", then the player finds a pair alone;
  3. Hint, Shuffle and Undo; the next move or **Start Playing** ends it.
- **Skip** (120 px tall) is always visible.
- **No penalties while it runs:** the clock waits, a wrong pair costs no heart, toasts become coach
  remarks, and combo praise stays out of the lane.
- **Never unsolvable:** the highlighted pair is chosen so the board stays solvable (solver-checked).
  The tutorial only highlights and never changes the board. It works in every collection, because it
  uses identical faces, not specific symbols.
- **Saved** in user settings (`tutorial/level1_done` plus the outcome, completed or skipped). Players who
  already cleared level 1 (including before the tutorial existed) also count as returning. Returning
  players are never interrupted. **How to Play** in Settings replays it on level 1.

### P4.7 Web loading page (`web/shell.html`, details in `docs/WEB_HOSTING.md`)
- An original, branded loading screen; a percentage only when the size is known; reduced-motion aware.
- Audio resumes on the first tap or key press. **No extra Tap to Start:** browsers allow sound after
  the player's first interaction, which is already the title screen's Play tap.
- Measured on the live site before this change: the engine (10 MB) and game data (7 MB) are already
  gzip-compressed and finish downloading about 3.6 s after the page opens. The longer starts seen
  earlier were measured in a hidden, throttled browser pane. `window.__zenLoad` now records the real
  timings.
- **Needs checking after deployment.** Only GitHub's build machine has web export templates, so the
  page has been checked here with a stand-in engine only.

### P4.5 Journey map (`level_node.tscn/.gd`, `journey_world.gd`)
- Name plates (MapLabelPlate) with 40 / 28 px text.
- A farther plate hides when it would touch a nearer marker or plate.
- Locked levels say LOCKED, unplayed levels show only their difficulty, cleared levels show their stars.
- Unlock and progress logic unchanged.

### P4.8 Accessibility
| Check | Result |
|-------|--------|
| Text contrast (WCAG AA 4.5:1) | HUD values / dialog text 7.74; HUD captions 4.67; low-time clock 4.96; primary buttons 7.74; toasts, coach and plates 7.64; hearts on pill 4.93. Locked level names were 3.91 at 60 % opacity, **raised to 80 %** (passes) |
| Touch targets (≥ 120 canvas px) | Settings toggles were 110 and sliders 80, **now 120**. All buttons and sliders on the game screen and in Settings are tested |
| Text size at 320 × 568 (canvas × 0.296) | HUD captions 26 → **30** (8.9 css px); toasts and coach 34 → **36** (10.7 css px); tool labels 38, body 44 and above |
| Not colour alone | Free vs blocked: brightness and veil, plus a nudge when tapped. Hearts: spent hearts fade. Journey: LOCKED text, stars only when cleared, arrow on the current level. Time warning: the number itself |
| Reduced motion | Journey petals now off; previously done: tile travel, bursts, drift, praise pop, loading-page petals |
| Safe areas / aspect ratios | All three screens use `SafeAreaContainer`; the web page pads with `env(safe-area-inset-*)`; layout tested on 9:16, 9:19.5, 9:21 and 3:4 |
