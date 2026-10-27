# Zen Mahjong Journey — Project Instructions

Android-first, portrait Mahjong Solitaire (tile-matching) game with a calm "zen garden journey"
progression. Built with **Godot 4.7.2 (stable)** and **GDScript** only, GL Compatibility renderer.

The Godot project root is this folder (`zen-mahjong-journey/`). The sibling folder
`../ZenMahjongJourney_Assets/` is the **original, untouched asset pack** — treat it as a read-only
archive. Runtime copies live in `res://assets/`.

Godot binary on this machine (not on PATH; the `_console.exe` wrapper fails because the parent
folder name ends in `.exe`, so call the main exe directly):
`C:/Users/Salman Abdallah/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe`

## Verify before reporting work as done
```
GODOT --headless --path . --import          # import new assets, must print no ERROR lines
GODOT --headless --editor --path . --quit   # editor opens: no script/resource errors
GODOT --headless --path . --quit-after 120  # main scene runs
GODOT --headless --path . -s res://tests/run_tests.gd                      # unit tests (exit 1 on failure)
GODOT --headless --path . res://tests/integration/playthrough_test.tscn    # plays levels via simulated clicks
GODOT --headless --path . res://tests/integration/audio_test.tscn         # music, sound events, settings
GODOT --path . --audio-driver Dummy res://tests/visual/capture_screens.tscn -- <scratch_dir>    # screenshots; look at them
```
Grep the output for `ERROR`, `WARNING`, `SCRIPT ERROR`, `Parse Error`. The unit runner cannot
detect a `SCRIPT ERROR` raised inside a test, so grep its output as well. A fresh clone shows
"No loader found" errors on the *first* import only (theme loads before textures are imported);
the second run must be clean.

## Hard rules
- **Never delete, overwrite, re-encode or edit original artwork**, in `../ZenMahjongJourney_Assets/`
  or `res://assets/`. Derived/edited art goes in a new file with a new name.
- `docs/reference/mockups/*.png` are **concept art only**. Never use them in a scene, never place
  invisible buttons over them, never crop UI out of them. Rebuild every screen from real Godot
  Controls (Button, Label, TextureRect, containers) using the separate button/panel/icon PNGs.
  `docs/` has a `.gdignore`, so Godot does not import it.
- All text the player reads is a Godot `Label`/`Button` text (localizable), never baked into art.
  Exception to watch: `bg_sakura_garden.png` has the title logo baked in — do not use it behind
  a Label title; it is only suitable as a splash/marketing image.
- No AdMob, analytics, IAP or network code until explicitly requested.
- Build features in order; do not start a later feature before the current scene works and is
  verified (see roadmap).

## Display & responsive UI
- Base canvas **1080×1920 portrait**, `stretch/mode=canvas_items`, `stretch/aspect=expand`,
  `handheld/orientation=portrait`. Desktop test window is 540×960.
- Layout with anchors + containers, never fixed absolute positions for screen-level UI.
  Wider/taller devices get *more* canvas (expand), so center content and let spacers absorb it.
- Wrap screen content in `SafeAreaContainer` (`scripts/components/safe_area_container.gd`) to keep
  clear of notches/system bars.
- Backgrounds: full-rect `TextureRect`, `expand_mode = Ignore Size`, `stretch_mode = Keep Aspect
  Covered`, `mouse_filter = Ignore`. Add translucent gradient/contrast overlays behind HUD and
  board — the art is busy.
- Touch targets ≥ 120 canvas px (~ 48dp). Mouse emulates touch (`emulate_touch_from_mouse`).
- Default texture filter: linear.

## Art direction
Warm, serene Japanese-garden fantasy: sakura, lanterns, koi ponds, misty temples, golden sunsets.
Soft, painterly, premium; never loud or arcade-like. Motion is slow and eased (sine/quad, 0.2–0.8s).

Palette (from `docs/reference/asset_manifest.json`):
| name   | hex       | use |
|--------|-----------|-----|
| ivory  | `#F6EEDF` | light text on dark buttons, panel fill |
| sage   | `#91A88C` | secondary accents |
| sakura | `#E8B4BD` | highlights, petals, rewards |
| gold   | `#C7A56A` | borders, title, pressed text, stars |
| forest | `#354F44` | primary buttons, dark text on ivory, boot color |
| night  | `#273B50` | dark overlays, night theme |

Typography: serif (currently a `SystemFont` placeholder — Georgia / Noto Serif / serif). A bundled,
licensed font should replace it in `res://assets/fonts/` and be set in the theme only.

## Theme
All styling lives in `res://themes/zen_theme.tres` (project-wide `gui/theme/custom`). Do not set
colors/fonts per node; add a theme type variation instead. Existing variations:
- `Button` (default) — forest primary button `btn_primary_empty.png` as 9-slice `StyleBoxTexture`
- `SecondaryButton` — ivory `btn_secondary_empty.png`, forest text
- `TitleLabel`, `TitleAccentLabel`, `SubtitleLabel` — title lockup styles

Button art is empty by design: text is the Button's own `text`, icons via `icon` or child
`TextureRect`. 9-slice margins for 480×128 buttons: 64 L/R, 40 top, 44 bottom.

## Folder layout
```
assets/            runtime art copied verbatim from the asset pack (same sub-paths)
scenes/screens/    startup_screen.tscn, game_screen.tscn
scenes/components/ tile_view.tscn, modal_dialog.tscn
scripts/screens/   scripts attached to screen scenes (same base name as the scene)
scripts/components/ BoardView, TileView, ModalDialog, SafeAreaContainer, ShuffleGlyph
scripts/autoload/  GameSession (current level, scene changes), TileCollectionManager
scripts/core/      pure game logic, no Nodes (see Architecture)
data/layouts/      board shapes (JSON, format documented in board_layout.gd)
data/levels/       levels.json: order, title, layout, seed, suits, background
tests/unit/        test_*.gd run by tests/run_tests.gd (TestCase base in tests/test_case.gd)
tests/integration/ playthrough_test.tscn: plays the real game screen with simulated clicks
tests/visual/      capture_screens.tscn: screenshot tool
themes/            Theme resources
data/tile_art/     tile style manifests: body geometry + classic faces (classic_v1.json = temporary pack)
data/collections/  player-selectable tile collections (classic + 5 awaiting artwork)
assets/collections/<id>/ symbol art per collection (README.md in each lists the files needed)
docs/              reference material, KNOWN_ISSUES.md, TILE_ART_SPEC.md, TILE_COLLECTIONS.md (ignored by Godot)
```
Export note (for the Android step): JSON in `data/` is not a Godot resource. Add `data/*` to the
export preset's "non-resource files" filter, and exclude `tests/*` from the export.

## Naming conventions
- Files and folders: `snake_case` (`startup_screen.tscn`, `safe_area_container.gd`).
- A scene and its script share a base name in parallel folders.
- Nodes: `PascalCase` (`PlayButton`, `TitleBlock`); mark nodes accessed from script as unique
  (`%PlayButton`) instead of long `$A/B/C` paths.
- GDScript: `class_name PascalCase`, functions/vars `snake_case`, constants `UPPER_SNAKE`,
  private members `_leading_underscore`, signals past-tense (`tile_matched`), handlers
  `_on_<node>_<signal>`. Static typing everywhere (`var x: int`, `:=`, typed returns).
  Don't name variables `seed`, `name`, `scale` etc. (they shadow globals/members and raise warnings).
- Assets keep their pack names: `bg_*`, `tile_<suit>_<rank>`, `tile_back_*`, `btn_*_empty`,
  `icon_*`, `panel_*_empty`, `node_*`, `petal_NN`.
- Tile face IDs = file name without `tile_` prefix: `bamboo_1..9`, `dots_1..9`,
  `characters_1..9`, `winds_east|south|west|north`, `dragons_red|green|white`,
  `flowers_plum|orchid|chrysanthemum|bamboo`, `seasons_spring|summer|autumn|winter`.

## Architecture
- **Core (`scripts/core/`, no Nodes, fully unit-tested):**
  - `TileCatalog`: face IDs, suits, match groups (flowers match any flower, seasons any season).
    Rules only, no art.
  - `TileArtSet`: the active tile art collection, loaded from a manifest in `data/tile_art/` chosen
    by project setting `zen_mahjong/tiles/art_set`. Maps face ID to PNG, gives image/body/face
    rects, grid overlap, layer raise and which faces are unverified. Spec: `docs/TILE_ART_SPEC.md`.
    Never hardcode tile PNG paths or tile pixel sizes anywhere else.
  - `BoardLayout`: loads and validates JSON shapes. `BoardGeometry` holds positions in
    half-tile units (a tile covers x..x+2, y..y+2 on layer z) plus precomputed cover/left/right
    neighbours.
  - `BoardModel`: faces and removed flags. Free = nothing above overlaps it AND its left or right
    side is open. Handles removal and restore (undo) and available matches.
  - `BoardGenerator`: deterministic, seeded deals. Builds the deal backwards by removing free
    pairs from the full layout, then gives each pair matching faces. The removal order is
    replayed through BoardModel's rules before a deal is accepted, so every board ships with a
    verified solution. `reshuffle()` does the same for the tiles left on the board.
  - `BoardSolver`: budgeted DFS with safe-move pruning and memoisation, used for Hint and tests.
  - `LevelCatalog`: reads data/levels/levels.json.
- **Tile collections** (player-chosen look): `TileCollection` (manifest), `TileSkin` (per-board
  face → image, keyed by match group), `TileCollectionLibrary`, `UserSettings`, and the autoload
  `TileCollectionManager` (selection, save/restore, cache, `collection_changed`, Classic fallback).
  The board never depends on the collection. Full design: `docs/TILE_COLLECTIONS.md`. Fixture
  collections in `tests/fixtures/collections/` are test-only stand-ins; never ship or show them.
- **Audio:** autoload `AudioManager` (buses Master/Music/Ambience/SFX/UI in
  `default_bus_layout.tres`; sound ids in `AudioCatalog`). Call `AudioManager.play_sfx(id)` only
  after an action succeeds. Buttons get a click automatically; set meta `custom_sound` on buttons
  that play their own sound. Headless runs don't start playback (no device) but keep all state.
  File checklist: `docs/AUDIO_ASSETS.md`.
- **Randomness:** only `RandomNumberGenerator` seeded from level data. Never `randi()`,
  `Array.shuffle()` or other global-RNG calls in core code, or deals stop being reproducible.
- **GDScript pitfall:** a Packed*Array stored in a Dictionary/Array is a copy. Appending to the
  fetched value does not update the container. Use plain `Array` values for grouping.
- **Views:** `BoardView` builds `TileView`s (draw order: z, then y, then x; each layer shifted
  up-left), adds a soft backdrop and an effects layer, and scales the board to fit
  (`MAX_FACE_WIDTH` caps small boards, `FIT_WIDTH`/`FIT_HEIGHT` keep the garden visible).
  `TileView` layers: drop shadow, then the face, an ivory veil (blocked) and a glow (gold =
  selected with lift, sakura pulse = hint). It hit-tests only `face_rect` and stops taking input
  as soon as its removal starts. `MatchBurst` plays the gold flash and petals on a match.
- **Screen:** `game_screen.gd` orchestrates the model, view, HUD, tools, undo stack and dialogs.
  Rules stay in the core.
- Add new autoloads (SaveManager, AudioManager, a router with fades) only when a feature needs them.

## Roadmap (do in order, verify each)
1. ✅ Project setup, portrait config, theme, startup screen.
2. ✅ Milestone 1: playable solitaire with 10 seeded, verified levels, HUD, Hint / Shuffle / Undo,
   pause, level complete, unit + integration tests.
2b. ✅ Board polish (depth, shadows, ivory veil, gold glow, match effects, sizing) and the tile art
   manifest system. Premium tile art pending from the artist.
2c. ✅ Tile collections: architecture, six manifests, picker (start screen + pause), save/restore,
   fallbacks, tests. Premium pack integrated: Animals, Alphabet, Mixed and Fruits (plum held
   back) enabled; Vegetables unavailable until look-alikes are replaced (docs/TILE_COLLECTIONS.md).
2e. ✅ Lose conditions: per-level countdown (`time_limit`) and mistake hearts (`mistakes`) in
   levels.json; a mistake = picking two free tiles that don't match (blocked taps and deselecting
   are free); clock runs only while playing; Out of Time / Too Many Mistakes → Retry / Home.
2d. ✅ Audio: AudioManager, buses, settings panel (menu + pause), all sound events wired, tests.
   Generated SFX + waterfall/wind; music and birds awaiting files (docs/AUDIO_ASSETS.md).
3. Home screen (Play / Daily Challenge / Journey Map / Settings / Shop as real Controls).
4. Journey map with progression nodes, save/load of progress.
5. Settings (music, SFX, vibration), audio, petal effects.
6. Android export preset, icon/adaptive icon, on-device testing (FPS, touch, safe area).
7. Monetization (AdMob), only when explicitly requested.

## Known asset issues
See `docs/KNOWN_ISSUES.md`. In short: 15 tile faces (characters, winds, red/green dragons) have
missing CJK glyphs and are excluded from boards through `unverified_faces` in the tile art
manifest, with the white dragon also held back pending review. `icon_shuffle.png` is broken (vector stand-in in use), several other
icons don't match their names, the logo is only baked into `bg_sakura_garden.png`, and no
fonts or audio are supplied.
