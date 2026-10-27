# Artwork fix list: Fruits and Vegetables

For the artist. Replace the files below **under exactly the same file names**, in
`assets/collections/fruits/` and `assets/collections/vegetables/`. No other changes are needed:
once every picture is distinct, the game enables the collection automatically.

## Specs (same as the rest of the pack)

- PNG, RGBA, transparent background, **256 × 256**.
- Keep the drawing inside the same area as the existing symbols: roughly **x 56–200, y 34–174**.
  The game shows only that region (`symbol_region` in the manifest).
- **No caption needed.** The game doesn't show the text under y = 200. You may leave it out.
- Match the existing style (the Noto-like illustrated look of the animals).
- Each picture must be recognisable at **~70 px** and differ from every other symbol in its
  collection **by shape, not only colour**.
- Draw the artwork yourself or use properly licensed art. No system emoji or fonts.

## Must replace (the game stays locked until these are distinct)

### Fruits: 11 files (10 done in batch 1, plum still needed)

Batch 1 (`docs/reference/fruit_fixes_batch1/`) replaced 10 of these. Fruits is **enabled** with
plum held back (`held_back_symbols` in `data/collections/fruits.json`). Send a distinct
**`fruit_31_plum.png`** to bring plum back. Then remove it from `held_back_symbols`.

| File | Should show | Currently |
|------|-------------|-----------|
| ✅ `fruit_09_lime.png` | lime | melon drawing |
| ✅ `fruit_21_papaya.png` | papaya | melon drawing |
| ✅ `fruit_27_cantaloupe.png` | cantaloupe (cut, orange flesh, to differ from melon) | melon drawing |
| ✅ `fruit_32_grapefruit.png` | grapefruit (halved, pink) | orange drawing |
| ✅ `fruit_33_tangerine.png` | tangerine (small, with leaf) | orange drawing |
| ✅ `fruit_24_lychee.png` | lychee (bumpy red shell) | cherries drawing |
| ✅ `fruit_35_redcurrant.png` | redcurrant (cluster on a stem) | cherries drawing |
| ✅ `fruit_25_raspberry.png` | raspberry | strawberry drawing |
| ✅ `fruit_26_blackberry.png` | blackberry | blueberries drawing |
| ✅ `fruit_34_nectarine.png` | nectarine (smooth, red-yellow) | peach drawing |
| ❌ `fruit_31_plum.png` | plum | plain purple circle (same as fig) |

### Vegetables: 14 files

| File | Should show | Currently |
|------|-------------|-----------|
| `vegetable_19_asparagus.png` | asparagus spears | seedling drawing |
| `vegetable_17_kale.png` | kale leaf | seedling drawing |
| `vegetable_23_turnip.png` | turnip (white-purple root) | seedling drawing |
| `vegetable_31_spring_onion.png` | spring onions | seedling drawing |
| `vegetable_34_okra.png` | okra pod | seedling drawing |
| `vegetable_14_cabbage.png` | round cabbage head | leafy-green drawing |
| `vegetable_32_bok_choy.png` | bok choy | leafy-green drawing |
| `vegetable_35_brussels_sprouts.png` | brussels sprouts | leafy-green drawing |
| `vegetable_29_leek.png` | leek | herb-sprig drawing |
| `vegetable_33_celery.png` | celery stalks | herb-sprig drawing |
| `vegetable_18_cauliflower.png` | cauliflower (white head) | broccoli drawing |
| `vegetable_24_zucchini.png` | zucchini | cucumber drawing |
| `vegetable_22_radish.png` | radish (red-white root) | chili drawing |
| `vegetable_07_red_pepper.png` | **red** bell pepper | green bell pepper drawing |

All five seedling files are listed because the seedling drawing isn't right for any of them.
Lettuce, spinach (see below), broccoli, cucumber, chili and green pepper keep their current pictures.

## Review notes after batch 1 (70 px tiles, `docs/screenshots/fruits_70px_after_batch1.png`)

These pass the automatic check but could confuse players on small phones:

- **Tangerine vs orange:** both are an orange citrus with a leaf; only the drawing style differs.
  Consider showing the tangerine peeled or in segments.
- **Red round fruits:** apple, nectarine, persimmon (drawn as a tomato) and pomegranate (a plain
  red circle) are all red and round with a little green on top.
- **Mixed styles:** the batch 1 fruits are painterly and detailed; the rest of the set is flat
  emoji-style. Side by side they don't look like one collection.

## Should replace (pass the automatic check, but are stand-ins)

These don't block the game, but look generic or wrong, and colour-only circles are hard to
tell apart on small phones.

| File | Should show | Currently |
|------|-------------|-----------|
| `fruit_20_fig.png` | fig | plain purple circle |
| `fruit_16_pomegranate.png` | pomegranate | plain red circle |
| `fruit_23_passionfruit.png` | passionfruit | plain orange circle |
| `fruit_28_starfruit.png` | starfruit | star symbol |
| `fruit_22_dragonfruit.png` | dragonfruit | hibiscus flower |
| `fruit_29_persimmon.png` | persimmon | tomato |
| `fruit_30_guava.png` | guava | green apple |
| `vegetable_16_spinach.png` | spinach | herb sprig |
| `vegetable_21_beetroot.png` | beetroot | plain purple circle |
| `vegetable_08_yellow_pepper.png` | yellow bell pepper | plain yellow circle |
| `vegetable_28_artichoke.png` | artichoke | hibiscus flower |

## After replacing

Run the test suite (commands in `CLAUDE.md`). `test_collections.gd` reports any picture that
still looks like another. Then run the capture tool and check the Fruits and Vegetables boards.
Update `test_reused_drawings_are_detected` in `tests/unit/test_collections.gd`: it currently
expects the 16 and 23 defects and will fail (as intended) once they're fixed.
