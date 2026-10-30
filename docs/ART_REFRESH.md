# Art refresh: "Vivid zen" backgrounds (prompt pack)

Goal: richer, more colourful, higher-resolution garden backgrounds that still feel calm and
premium. Same four gardens, same names, so levels, saves and sounds keep working. The original
pack stays untouched; new art goes in as **new files**.

Live motion (petals, fireflies, light rays, mist) is added in code by `GardenAmbience`, so the
images themselves should be **still** paintings with room for that motion.

## What to make

| File name (exactly) | Garden | Used for |
|---|---|---|
| `bg_golden_sakura_hd.png` | Sakura Garden | levels, start screen, journey chapters |
| `bg_bamboo_forest_hd.png` | Bamboo Forest | levels, journey chapters |
| `bg_misty_temple_hd.png` | Misty Temple | levels, journey map |
| `bg_moonlight_sanctuary_hd.png` | Moonlight Sanctuary | levels, journey chapters |

Make 3–4 versions of each, pick the best one.

## Size and format

- **Portrait 9:16, 2160 × 3840 px** (4K) PNG, the master copy. Most tools make about 900 × 1600,
  so **upscale 2×–4×** to reach this size: the tool's own upscaler (Midjourney *Upscale*,
  Leonardo *Universal Upscaler*) or the free app Upscayl. Then crop to exactly 2160 × 3840.
- I make the in-game copy (about 1440 × 2560, still sharper than phone screens) from your
  master; you only send the masters.
- No text, letters, logos, signatures or watermarks anywhere in the image.

## Composition rule (important)

The tile board covers the **middle 70 %** of the screen and the score bar sits at the top. So:

- **Top 15 % and bottom 15 %**: the most beautiful detail (blossom branches, lanterns, the moon,
  a koi pond, a bridge).
- **Middle**: soft, calm, low-detail (open sky, mist, soft water, out-of-focus foliage) with no
  strong lines or bright spots. Tiles must stay easy to read on top of it.
- Light source in the **upper corner** (warm sun or moon), so the code's light rays match.

## Licence

Use a tool and plan that allow **commercial use** of what you generate (for example Midjourney
paid plans, Leonardo paid plans). Keep the receipt/plan name. Don't upload other games' art or
screenshots as references.

## Prompts

Paste the **style line** after every prompt. In Midjourney add `--ar 9:16 --style raw --v 7`
(or the newest version); in other tools choose a 9:16 portrait size.

**Style line:**
> painterly digital illustration, Japanese garden fantasy, vivid but harmonious colours, rich
> saturated jewel tones, soft glowing light, atmospheric depth, luminous, highly detailed edges and
> soft calm centre, premium mobile game background, serene, no people, no text, no watermark

**Negative prompt** (tools that support it):
> text, letters, kanji, logo, watermark, signature, people, characters, animals in the centre,
> mahjong tiles, user interface, buttons, frame, border, harsh contrast, cluttered centre, neon,
> cartoon, low resolution, blurry, jpeg artefacts

### 1. Sakura Garden — `bg_golden_sakura_hd.png`
> Vertical view of a magical cherry blossom garden at golden hour. Lush pink and magenta sakura
> branches frame the top of the image, glowing in warm sunlight from the upper left corner. At
> the bottom, a clear turquoise koi pond with orange and white koi, round stepping stones and a
> small red wooden bridge, pink petals floating on the water. The middle is soft warm haze and
> distant pastel blossom trees, out of focus and calm. Golden light, peach and rose sky.

### 2. Bamboo Forest — `bg_bamboo_forest_hd.png`
> Vertical view of a sunlit emerald bamboo forest. Tall bright green and jade bamboo stalks frame
> both sides, fresh leaves at the top glowing yellow-green in the sun coming from the upper right.
> At the bottom, a mossy stone path with glowing stone lanterns and small blue hydrangeas beside a
> clear stream. The middle is a soft misty green clearing with gentle light, low detail and calm.
> Emerald, jade, lime and warm gold colours.

### 3. Misty Temple — `bg_misty_temple_hd.png`
> Vertical view of a Japanese mountain temple at sunrise above the clouds. At the top, a
> vermilion pagoda roof and torii gate on a cliff edge with maple trees in crimson and orange,
> lit by a rising sun in the upper left. At the bottom, stone steps and red lanterns fading into
> rolling clouds. The middle is a wide sea of soft lavender, peach and pink mist, calm and open.
> Lavender, coral, vermilion and soft gold colours.

### 4. Moonlight Sanctuary — `bg_moonlight_sanctuary_hd.png`
> Vertical view of a moonlit shrine garden at night. At the top, a large glowing full moon in the
> upper right with deep indigo and violet sky and a few bright stars, wisteria branches with
> glowing purple blossoms hanging down. At the bottom, a still reflecting pond with floating
> lanterns and lotus flowers, a small stone shrine with warm amber light. The middle is deep calm
> blue night air with a soft glow, low detail. Indigo, violet, teal and warm amber accents.

## Checklist before sending

- [ ] 2160 × 3840, PNG, portrait
- [ ] Middle area calm, details at top and bottom
- [ ] No text, signatures, watermarks, people
- [ ] Looks good shrunk to phone size (check the thumbnail)
- [ ] Commercial licence

Put the four files in a new folder next to the project, for example
`ZenMahjongJourney/ArtRefresh_Incoming/`. Then tell the developer.

## How it is wired (developer)

- In-game copies go in `res://assets/backgrounds/hd/` (derived files, never overwriting the
  originals). `LevelCatalog.background_path_for(name)` uses `hd/<name>_hd.png` when it exists,
  otherwise the original pack file, so each garden can be swapped one at a time.
- After adding a garden, re-measure it and update its `BackgroundStyle` entry (dim and board
  shade) so the tiles stay readable. Then check the screenshots.
- Motion per garden: `AmbienceStyle` (core) and `GardenAmbience` (component).
