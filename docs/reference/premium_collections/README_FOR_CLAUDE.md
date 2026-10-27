# Zen Mahjong Journey — Customizable Tile Artwork

This package supplies individual transparent PNGs for 36 Animals, 36 Fruits, 36 Vegetables, 26 Alphabet symbols, 36 Mixed copies (reusing symbols), five collection thumbnails, an ivory tile body, selection/blocked overlays, and previews.

**Important:** The illustration sheet (`previews/visual_art_direction_reference.png`) is a design reference. The individual collection images are rendered from open-source Noto Color Emoji icon glyphs for a consistent immediately usable first pass, while the Alphabet and tile body are rendered separately. They are not bespoke hand-painted art from the illustration sheet. Some rare fruits/vegetables use substitute pictograms; every icon includes a distinct English name label to disambiguate similar images. Inspect before commercial release and commission custom art for truly unique pictograms.

## Integration

1. Back up/commit your project.
2. Copy the contents of `assets/` into Godot `res://assets/` (merge folders; do not delete originals).
3. Read `docs/asset_manifest.json` to find each image and its unique `face_XX` ID.
4. **Do not overwrite Claude's existing `data/collections/*.json` blindly.** Ask Claude Code to map these files onto its existing manifest schema; the exact manifest definitions from the local project were not supplied in this chat.
5. Keep logical Mahjong faces, flower matching groups, deterministic Mixed mapping, tile bodies, gameplay rules, and saved levels unchanged.
6. Keep images transparent in imported textures, configure mipmaps where useful and test on-device.
7. Show preview thumbnails in picker, switch collections while playing, and run existing test suite.

## Images

- Symbol art: 256 × 256 RGBA PNG.
- Tile body: 256 × 320 RGBA PNG.
- Thumbnails: 512 × 512 RGBA PNG.
- Collection files are standalone symbol overlays, not complete tile faces.
- `mixed/` stores 36 copies of chosen symbols for straightforward integration, although a manifest can reference originals instead.

## Licensing note

Pictogram art is based on **Noto Color Emoji** artwork (Google), licensed under SIL Open Font License 1.1 / Apache 2.0 as applicable to source artwork; verify applicable licenses and attribution before distributing commercially. Original font binaries are **not included**. See https://github.com/googlefonts/noto-emoji for licensing. You may replace these pictograms with bespoke commercial artwork at any time without changing file structure.

## Known asset limitations

- The system-ready images are clean transparent face overlays with a consistent visual style, but they are illustrative draft assets, not individually painted premium originals.
- There are not 36 universally recognized emoji for each category; a handful of fruits and vegetables use repeated or stand-in glyphs. The included English labels disambiguate them, but replace stand-ins with unique, recognizable graphics before publishing. Claude should validate that all complete face overlays are distinct.
- Alphabet contains 26 faces; if a board needs >26 distinct face IDs, keep Alphabet disabled for that board or use an explicitly validated mapping approach.
