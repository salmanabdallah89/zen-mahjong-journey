# Tile collections

Players choose the pictures on the tiles (Classic, Animals, Fruits, Vegetables, Alphabet, Mixed).
A collection changes **only how tiles look**. Matching rules, deals, solvability, undo and level
progression never depend on it, and switching mid-level re-skins the board without touching it.

## Architecture: what lives where

| Concern | Owner | Notes |
|---------|-------|-------|
| Logical matching identity | `TileCatalog` (`scripts/core/tile_catalog.gd`) | 42 face IDs, 36 match groups (flowers and seasons each count as one group) |
| Board deal | `BoardGenerator`, using the face pool from `LevelCatalog` | Seeded. The face pool follows the tile style's `unverified_faces`, never the chosen collection |
| Tile body and geometry | `TileArtSet` (`data/tile_art/*.json`) | Image size, body/face rects, spacing, layer raise. Shared by all collections |
| Tile symbol artwork | `TileCollection` (`data/collections/*.json`) | Manifest per collection |
| Per-board look | `TileSkin` | Built once per board: face → image. Keyed by match group, so shuffle and undo keep each tile's look |
| Discovery, validation, cache, persistence, notifications | `TileCollectionManager` autoload | Saves the choice in `user://settings.cfg` under `[tiles] collection`, emits `collection_changed` |
| Selection and hint effects | `TileView` | Gold glow, sakura hint, ivory veil. Independent of collections |
| Board theme (background) | `data/levels/levels.json` | Per level. Independent of collections |
| UI | `CollectionPicker` (`scenes/components/collection_picker.tscn`) | Opened from the start screen ("Tile Collection") and the pause menu |

## Manifest format

```jsonc
{
  "id": "animals",               // unique, matches the file name
  "name": "Cute Animals",        // shown in the picker
  "version": 1,                  // bump when symbols change (re-seeds Mixed)
  "order": 2,                    // position in the picker
  "kind": "symbols",             // "tile_set" (complete tile images from the TileArtSet) or "symbols"
  "assignment": "fixed",         // how symbols are given to match groups (below)
  "description": "Illustrated animal faces.",
  "thumbnail": "res://assets/collections/animals/thumbnail.png",
  "tile_style": "res://data/tile_art/ivory_body_v1.json",   // geometry of the body (size, face, spacing)
  "body": "res://assets/tiles/bodies/tile_body_ivory.png",   // blank tile drawn under every symbol
  "symbol_region": [56, 34, 144, 140],   // optional: part of each PNG to show (crops captions)
  "symbol_padding": 0.14,        // share of the face kept clear around the symbol, per side
  "symbols": [
    {"id": "panda", "file": "res://assets/collections/animals/animal_panda.png"},
    {"id": "cat",   "file": "res://assets/collections/animals/animal_cat.png"}
  ]
}
```

Assignment strategies:

| `assignment` | Mapping | Use for |
|--------------|---------|---------|
| `fixed` | Match group N in canonical order (bamboo 1–9, dots 1–9, characters 1–9, winds, dragons, flowers, seasons) gets symbol N. Same on every board | Animals, Fruits, Vegetables. Needs 36 symbols to cover every group |
| `board_ordered` | The groups present on this board, in canonical order, get symbols 1, 2, 3, … | Alphabet (26 letters). Boards with more groups than symbols fall back to Classic with a message |
| `board_seeded` | Like `board_ordered`, but the symbol list is first shuffled using the level's deal seed plus collection id and version | Mixed. Deterministic, so the same board always looks the same, after save/load, restarts and shuffles |

The mapping is derived from the board's full face list and the deal seed, so it is reproducible
without being stored.

Every match group on a board gets its own symbol, and different groups never share one. The
validator rejects repeated files **and** different files containing the same picture.

## Safety rules (what the player can never see)

- A collection with any missing or invalid file, or two symbols that look the same (identical
  pixels, or the same drawing with only a caption changed), is **unavailable**. It shows "Coming soon" in the
  picker and cannot be applied.
- A saved choice that becomes unavailable falls back to Classic on startup, with a message.
- A board needing more symbols than a collection has is shown in Classic, with a message. The
  player's choice is kept for other boards.
- A `TileSkin` is only built when every image it needs has loaded, so no empty or missing texture
  reaches the board.
- Classic must always be complete. It is the guaranteed fallback.

## Performance

- Textures are loaded once per path into the manager's cache, and the cache is cleared when the
  collection changes. Nothing is loaded per frame.
- A skin is built once per board (and on switching). Tiles keep texture references.
- Measured with the visual capture tool: 60 FPS during continuous matches on Level 10 (desktop,
  Intel UHD 630). Not yet measured on Android.

## Adding a new collection

1. Create `assets/collections/<id>/` and add the symbol PNGs plus `thumbnail.png`.
2. Write `data/collections/<id>.json` (copy `animals.json`). Use a unique `id`, an `order`, at
   least as many symbols as the levels need (36 covers everything), and the shared `body`.
3. In Godot's Import dock, enable **Mipmaps > Generate** for the new PNGs.
4. Run the tests (commands in `CLAUDE.md`). `test_collections.gd` checks the structure and that
   every picture is distinct. Then run the capture tool and look at the previews.
5. The collection appears in the picker automatically, with no code changes.

## Artwork requirements

| Item | Requirement |
|------|-------------|
| Symbols | PNG, RGBA, transparent background, **256 × 256** recommended (square), consistent style within a collection |
| Padding | Keep the subject inside the central ~80 % of the image. The game adds `symbol_padding` on top |
| Legibility | Each symbol must be identifiable at **~70 px** (its on-screen size on small phones) and distinct from every other symbol in the collection by shape, not only colour |
| Tile body | `assets/tiles/bodies/tile_body_ivory.png` plus a tile style manifest describing it (`tile_style` in the collection manifest; current: `data/tile_art/ivory_body_v1.json`) |
| Thumbnail | `thumbnail.png`, 512 × 512, shown in the picker once supplied |
| Fonts/emoji | Never rely on system fonts or emoji. Letters for Alphabet must be drawn artwork |

## Artwork status (premium pack v1 integrated)

Source: `ZenMahjongJourney_PremiumCollections` (copy of its README, manifest and previews in
`docs/reference/premium_collections/`). Symbol collections draw on the shared ivory body using
the tile style `data/tile_art/ivory_body_v1.json` (256 × 320, face 8,6 232 × 288). Each manifest's
`symbol_region` frames the drawing and leaves out the English caption baked into each PNG.

| Collection | Status | Why |
|------------|--------|-----|
| Classic | ✅ enabled | 16 faces held back pending replacement (see `KNOWN_ISSUES.md`) |
| Cute Animals | ✅ enabled | 36 distinct symbols, fixed mapping |
| Alphabet | ✅ enabled | 26 distinct letters, board-ordered (boards with more than 26 groups show Classic) |
| Mixed | ✅ enabled | 36 distinct. The pack's `mixed_27_vegetables_07.png` (red pepper) is the same picture as green pepper, so the manifest uses `vegetables/vegetable_10_potato.png` in its place |
| Fruits | ⛔ unavailable | 16 look-alike pairs: the same drawing reused with only the caption changed |
| Vegetables | ⛔ unavailable | 23 look-alike pairs, same cause |

Look-alike groups (each needs distinct art before the collection can be enabled):
- Fruits: lime = melon = papaya = cantaloupe; orange = grapefruit = tangerine;
  cherries = lychee = redcurrant; strawberry = raspberry; blueberries = blackberry;
  peach = nectarine; fig = plum.
- Vegetables: asparagus = kale = turnip = spring onion = okra; cabbage = lettuce = bok choy =
  brussels sprouts; spinach = leek = celery; broccoli = cauliflower; cucumber = zucchini;
  radish = chili; red pepper = green pepper (drawn green).

Stand-in pictures that pass the automatic check but should be reviewed by a person: plain
coloured circles (fruits: fig/plum, pomegranate, passionfruit; vegetables: beetroot, yellow
pepper), a star for starfruit, a hibiscus for dragonfruit and artichoke, a tomato for
persimmon, a green apple for guava. Colour-only differences are hard to tell apart on small
screens.

To enable Fruits or Vegetables, replace the look-alike PNGs **under the same file names**
(`fruit_09_lime.png` etc.) and run the tests. The validator then passes and the collection
appears in the picker with no manifest or code change.

Not used yet: `assets/tiles/bodies/tile_selected_overlay.png` and `tile_blocked_overlay.png`.
The game draws its own gold selection glow and ivory blocked veil, which are tuned and tested.

Licensing: see `assets/collections/LICENSES.md` (Noto Color Emoji origin, attribution needed).

## Tests

- `tests/unit/test_collections.gd` covers: loading every manifest, Classic covering all faces, no
  shared pictures across groups, fixed and Mixed mapping stability, too-few-symbols refusal,
  missing-asset refusal, skins not touching board state, and settings round trip.
- `tests/integration/playthrough_test.gd::_test_tile_collections` covers: switching mid-level
  through the pause menu picker, unchanged board state, undo and shuffle after switching,
  refusals, restore on a fresh manager, the Mixed mapping after a reload, and fallbacks.
- Fixture collections in `tests/fixtures/collections/` reuse existing icon, petal and tile-back
  images as stand-in symbols. They are test-only and never shipped or shown to players.
