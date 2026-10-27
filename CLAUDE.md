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
GODOT --path . --write-movie <scratch>/f.png --fixed-fps 30 --quit-after 60   # render frames to look at
```
Grep the output for `ERROR`, `WARNING`, `SCRIPT ERROR`, `Parse Error`. A fresh clone shows
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
  backgrounds/ tiles/faces/ tiles/backs/ ui/buttons/ ui/icons/ ui/panels/
  progression/ effects/ branding/ fonts/ audio/
scenes/screens/    one scene per full screen (startup_screen.tscn, home_screen.tscn, ...)
scenes/components/ reusable pieces (tile.tscn, hud_bar.tscn, modal.tscn, ...)
scripts/screens/   scripts attached to screen scenes (same base name as the scene)
scripts/components/ reusable Control/Node scripts with class_name
scripts/autoload/  singletons registered in project.godot
scripts/core/      pure game logic, no Nodes (board model, rules, solver, layout loader)
data/layouts/      board layouts as data (JSON or .tres), never hardcoded in scenes
themes/            Theme resources
docs/              reference material, ignored by Godot
```

## Naming conventions
- Files and folders: `snake_case` (`startup_screen.tscn`, `safe_area_container.gd`).
- A scene and its script share a base name in parallel folders.
- Nodes: `PascalCase` (`PlayButton`, `TitleBlock`); mark nodes accessed from script as unique
  (`%PlayButton`) instead of long `$A/B/C` paths.
- GDScript: `class_name PascalCase`, functions/vars `snake_case`, constants `UPPER_SNAKE`,
  private members `_leading_underscore`, signals past-tense (`tile_matched`), handlers
  `_on_<node>_<signal>`. Static typing everywhere (`var x: int`, `:=`, typed returns).
- Assets keep their pack names: `bg_*`, `tile_<suit>_<rank>`, `tile_back_*`, `btn_*_empty`,
  `icon_*`, `panel_*_empty`, `node_*`, `petal_NN`.
- Tile face IDs = file name without `tile_` prefix: `bamboo_1..9`, `dots_1..9`,
  `characters_1..9`, `winds_east|south|west|north`, `dragons_red|green|white`,
  `flowers_plum|orchid|chrysanthemum|bamboo`, `seasons_spring|summer|autumn|winter`.

## Architecture (approved direction)
- **Logic separate from visuals.** `scripts/core/` holds plain classes (`RefCounted`/`Resource`):
  board model (tiles with id, face_id, grid x/y/z), free-tile rules, match rules (flowers match
  any flower, seasons match any season), shuffle, solvability-aware deal, undo stack. Testable
  without scenes.
- **Views render the model.** `Tile` component scene shows face/back textures looked up by
  `face_id`; board view positions tiles from model coordinates and forwards taps.
- **Autoloads (add only when the first feature needs them):** `SceneRouter` (screen changes +
  fades), `SaveManager` (`user://save.cfg` via ConfigFile/JSON: progress, stars, coins,
  settings), `AudioManager` (music/SFX buses), `GameState` (current level/session).
- Signals flow up, calls flow down; screens don't reach into each other.
- Levels/layouts are data in `data/layouts/`.

## Roadmap (do in order, verify each)
1. ✅ Project setup, portrait config, theme, startup screen (background + title + Play).
2. Home screen (Play / Daily Challenge / Journey Map / Settings / Shop buttons — real Controls).
3. Tile component + board model + one playable layout (select, match, free-tile rules, win/lose).
4. Gameplay HUD (level, timer, tiles left, pause) + Hint / Shuffle / Undo.
5. Level complete modal, Journey map with progression nodes, save/load.
6. Settings (music, SFX, vibration), audio, petal effects.
7. Android export preset, icon/adaptive icon, device testing.
8. Monetization (AdMob) — only when explicitly requested.

## Known asset issues
- CJK glyphs failed to render in the pack: `tile_characters_*`, `tile_winds_*`, `tile_dragons_*`
  show an empty box (□) instead of 萬/東/南/西/北/中/發. Winds have an English label; the red and
  green dragons are distinguishable only by color, and characters only by numeral. These need
  replacement art before release (README also asks for a visual review).
- `bg_sakura_garden.png` contains the baked title logo (see Hard rules).
- `branding/app_icon_*` are RGB with no transparency; Android adaptive icons need separate
  foreground/background layers.
- No fonts, sounds or music are supplied.
