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
  "body": "res://assets/tiles/bodies/tile_body_ivory.png",   // blank tile drawn under every symbol
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

- A collection with any missing or invalid file is **unavailable**. It shows "Coming soon" in the
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
| Tile body | `assets/tiles/bodies/tile_body_ivory.png`: blank tile, same size and face position as the active tile style (currently 192 × 240, face at 8, 8, 162 × 204; premium style 256 × 320 per `docs/TILE_ART_SPEC.md`) |
| Thumbnail | `thumbnail.png`, 512 × 512, shown in the picker once supplied |
| Fonts/emoji | Never rely on system fonts or emoji. Letters for Alphabet must be drawn artwork |

## Missing artwork (as of this commit)

Nothing below exists yet, so those collections show "Coming soon". Each folder's `README.md`
lists the exact file names.

| Collection | Needed | Folder |
|------------|--------|--------|
| Shared tile body | `tile_body_ivory.png` | `assets/tiles/bodies/` |
| Cute Animals | 36 symbols + thumbnail | `assets/collections/animals/` |
| Fruits | 36 symbols + thumbnail | `assets/collections/fruits/` |
| Vegetables | 36 symbols + thumbnail | `assets/collections/vegetables/` |
| Alphabet | 26 letters + thumbnail | `assets/collections/alphabet/` |
| Mixed | thumbnail only; reuses 9 each of animals, fruits, vegetables, letters | `assets/collections/mixed/` |
| Classic | complete, but 16 faces held back pending replacement (see `KNOWN_ISSUES.md`) | `assets/tiles/faces/` |

## Tests

- `tests/unit/test_collections.gd` covers: loading every manifest, Classic covering all faces, no
  shared pictures across groups, fixed and Mixed mapping stability, too-few-symbols refusal,
  missing-asset refusal, skins not touching board state, and settings round trip.
- `tests/integration/playthrough_test.gd::_test_tile_collections` covers: switching mid-level
  through the pause menu picker, unchanged board state, undo and shuffle after switching,
  refusals, restore on a fresh manager, the Mixed mapping after a reload, and fallbacks.
- Fixture collections in `tests/fixtures/collections/` reuse existing icon, petal and tile-back
  images as stand-in symbols. They are test-only and never shipped or shown to players.
