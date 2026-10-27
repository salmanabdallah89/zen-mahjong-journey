# Tile artwork specification

For the artist preparing the premium Mahjong tile collection, and for whoever installs it.
The game reads all tile art through a **manifest**: one JSON file per collection in
`data/tile_art/`. Gameplay code never names a PNG, so a complete collection can be replaced
without code changes.

## 1. What to deliver

**42 face images and at least 1 back image**, one PNG per file:

| Suit | Files | What the face must show |
|------|-------|-------------------------|
| Bamboo | `tile_bamboo_1.png` … `tile_bamboo_9.png` | 1–9 bamboo sticks (1 is traditionally a bird) |
| Dots (circles) | `tile_dots_1.png` … `tile_dots_9.png` | 1–9 circles |
| Characters | `tile_characters_1.png` … `tile_characters_9.png` | 一 二 三 四 五 六 七 八 九 above 萬 |
| Winds | `tile_winds_east.png`, `_south`, `_west`, `_north` | 東 南 西 北 |
| Dragons | `tile_dragons_red.png`, `_green`, `_white` | red 中, green 發, white dragon (blank face or framed 白) |
| Flowers | `tile_flowers_plum.png`, `_orchid`, `_chrysanthemum`, `_bamboo` | the four flowers (each a distinct design) |
| Seasons | `tile_seasons_spring.png`, `_summer`, `_autumn`, `_winter` | the four seasons (each a distinct design) |
| Backs | `tile_back_<style>.png`, e.g. `tile_back_forest.png` | patterned tile back (not used in play yet) |

Every symbol must be real artwork, with glyphs outlined or painted into the image. Do not rely on a
font that may be missing on the export machine; that is what broke the v1 pack (empty boxes).

## 2. Image format

| Property | Requirement |
|----------|-------------|
| Size | **256 × 320 px** recommended (4:5). Any size works if every image in the collection is identical and the manifest says so. Minimum 192 × 240. |
| Format | PNG, 32-bit RGBA, sRGB, non-interlaced |
| Background | Fully transparent outside the tile |
| Tile body | The tile is drawn **in the image**: an ivory top face plus a visible thickness/edge on the **right and bottom** (light from the top-left) |
| Edge thickness | About 5–7 % of the tile size (≈ 12–16 px right, 16–20 px bottom at 256 × 320). Keep it identical on every face |
| Drop shadow | **None.** The game draws soft shadows and depth per layer |
| Highlight / selection | **None.** The game draws the gold selection glow and hint glow |
| Safe area | Keep symbols inside the top face with ≥ 10 % padding, and no detail touching the edge |
| Blocked state | Not needed. The game washes blocked tiles with ivory |
| Labels | Optional small English captions (e.g. "EAST") are fine. Keep them legible at 110 px tile width |

Legibility check: shrink a face to **110 px wide**, the smallest the game shows it on phones. Every
face must still be identifiable, and faces of different suits must not be confusable by colour alone.

Suggested palette (from the asset manifest): ivory `#F6EEDF` face, gold `#C7A56A` trim,
forest `#354F44`, sakura `#E8B4BD`, night `#273B50`, classic red for 中 and numerals.

## 3. Measurements the manifest needs

Measure these on any one face (they must be the same on all):

```
 image_size   whole PNG, e.g. [256, 320]
 body_rect    [x, y, w, h] of the visible tile (face + edge), excluding transparent margin
 face_rect    [x, y, w, h] of the flat top face only. This is also the tap area
```

Two layout values tune how tiles sit together:

```
 grid_overlap  [x, y] px by which neighbours overlap; usually the edge thickness is hidden
               under the next tile, so ~[2, 4] for a tight board
 layer_shift   [x, y] px each higher layer is drawn up-left; roughly minus the edge thickness,
               e.g. [-16, -22] at 256 x 320
```

## 4. Installing a new collection

1. Put the PNGs in a new folder, e.g. `assets/tiles/premium_v2/faces/` and `.../backs/`.
   Never overwrite the v1 files.
2. Copy `data/tile_art/classic_v1.json` to `data/tile_art/premium_v2.json` and edit:
   `id`, `name`, `image_size`, `body_rect`, `face_rect`, `grid_overlap`, `layer_shift`,
   `face_folder`, `face_file_pattern` (`{face}` becomes the face ID, e.g. `bamboo_3`),
   `back_folder`, `backs`. Use `face_overrides` for any file that doesn't follow the pattern:
   `{"dragons_white": "res://assets/tiles/premium_v2/faces/white_dragon_alt.png"}`.
3. List faces still awaiting review in `unverified_faces`. Those faces are kept off all
   boards. Leave the list empty once every face has been checked.
4. In `project.godot`, set `[zen_mahjong] tiles/art_set="res://data/tile_art/premium_v2.json"`.
5. In Godot's Import dock, enable **Mipmaps > Generate** for the new PNGs (keeps small tiles crisp).
6. Run the tests (commands in `CLAUDE.md`). `test_tile_art.gd` checks that every face has art, that
   all images match `image_size` and that the rects fit. Then capture screenshots and review.

Note: verifying faces changes which faces each level deals, so seeded boards change too. All
boards remain verified-solvable.

## 5. Face IDs

`TileCatalog` owns the face IDs and matching rules; the art collection only maps IDs to files.

```
bamboo_1..9   dots_1..9   characters_1..9
winds_east winds_south winds_west winds_north
dragons_red dragons_green dragons_white
flowers_plum flowers_orchid flowers_chrysanthemum flowers_bamboo   (any flower matches any flower)
seasons_spring seasons_summer seasons_autumn seasons_winter       (any season matches any season)
```
