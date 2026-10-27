# Known asset issues

Defects found in the supplied asset pack (`ZenMahjongJourney_Assets` v1.0). The original files are
kept unchanged; replacements should be dropped into `assets/` under the **same file names** so no
code changes are needed beyond the flags noted below.

## 1. Mahjong tiles with missing CJK glyphs (replacement pending)

The pack's generator could not render Chinese characters, so an empty box (□, "tofu") was drawn
where the glyph should be. 15 face images are affected (9 characters, 4 winds, 2 dragons); the white dragon needs review.

| Face file | Should show | Currently shows |
|-----------|-------------|-----------------|
| `tile_characters_1.png` … `tile_characters_9.png` (9 files) | numeral + 萬 | numeral + empty box |
| `tile_winds_east.png` | 東 + "EAST" | empty box + "EAST" |
| `tile_winds_south.png` | 南 + "SOUTH" | empty box + "SOUTH" |
| `tile_winds_west.png` | 西 + "WEST" | empty box + "WEST" |
| `tile_winds_north.png` | 北 + "NORTH" | empty box + "NORTH" |
| `tile_dragons_red.png` | red 中 | red empty box |
| `tile_dragons_green.png` | green 發 | green empty box |
| `tile_dragons_white.png` | white dragon (blank/framed) | green square frame — **review**: may be intended, but matches the defective style |

How the game handles this today:
- The active tile collection's manifest (`data/tile_art/classic_v1.json`) lists these 16 faces
  under `unverified_faces`. Generated boards exclude them. Levels already request characters,
  dragons and winds, so they appear automatically once corrected art is installed and flagged
  verified.
- Nothing is substituted. No font-rendered or redrawn glyph is shown in place of the art.
- `test_levels.gd::test_levels_use_only_verified_art` and `test_tile_art.gd` enforce this.

When corrected art arrives, follow `docs/TILE_ART_SPEC.md`: install it as a new collection
(or replace these PNGs under the same names), then remove the faces from `unverified_faces`.

## 2. UI icons

| File | Problem | Used now? |
|------|---------|-----------|
| `icon_shuffle.png` | empty glyph box instead of a shuffle symbol | Yes. The Shuffle button draws a vector stand-in (`scripts/components/shuffle_glyph.gd`). Replace the PNG, set it as the button icon and delete the `ShuffleGlyph` node. |
| `icon_lock.png` | plain framed square, not a padlock | not yet |
| `icon_trophy.png` | a star, not a trophy | not yet |
| `icon_sound_off.png` | a music note, not a muted speaker | not yet |
| `icon_sound_on.png` | a single music note, not a speaker | not yet |
| `icon_gift.png` | a flower, not a gift box | not yet |
| `icon_shop.png` | a plain diamond | not yet (may be acceptable as a gem) |
| `icon_coin.png` | a plain disc | not yet (acceptable) |

## 3. Other

- `bg_sakura_garden.png` has the title logo baked into the painting. The logo cannot be cleanly
  extracted: there is no alpha, and blossoms and glow overlap the lettering. The startup screen
  uses Godot labels for the title over `bg_golden_sakura.png`. A separate transparent logo PNG
  would be needed to use the illustrated logo.
- `branding/app_icon_*.png` are RGB without transparency. Android adaptive icons need separate
  foreground/background layers.
- No fonts, audio or music are supplied. The UI uses a system serif font as a placeholder.
