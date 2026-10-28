# Phase 2: tile animations and sound (October 2026)

Goal: make every tile interaction feel smooth, satisfying and calm, in the game's own style.
Built on the existing systems (TileView, BoardView, MatchBurst, ModalDialog, AudioManager); no
working system was rewritten. Nothing was copied from other games: all motion is code and every
new sound and music file is synthesised by the project's own scripts.

## 1. Implemented features

### Tile interactions
| Interaction | What the player sees and hears | Reduced animations |
|-------------|--------------------------------|--------------------|
| Select | Tile lifts 12 px and swells to 105 % with a slight overshoot, gold glow, deeper shadow; wood-block tick; 10 ms haptic tick | Lift and glow, no swell |
| Match | Pair swells, **glides together** until the faces touch (0.16 to 0.30 s, longer for far pairs), then blooms and fades; burst plays where they meet; next melody bell | Quick fade in place |
| Mistake | Both tiles do a soft damped shake (7 px) with a brief rose outline; two muted knocks; 60 ms haptic | Rose outline only |
| Blocked tap | Smaller nudge, blockers outlined (unchanged rules) | Outline only |
| Newly uncovered | Tiles freed by a match brighten and swell 4.5 % as the pair meets, then settle | Veil fades only |
| Hint | Sakura glow and the tile breathe together (1.4 s cycle) | Steady glow |
| Shuffle | Tiles gather toward the centre (slight tilt), change faces while gathered, spread back out with a soft overshoot; rattle, then a wooden patter as they land. Taps wait about 0.6 s until it settles | Fade out, swap, fade in |
| Undo (match) | Exact reverse: the pair appears where it met and glides back home | Fade in |
| Undo (shuffle) | The same gather and spread, back to the previous faces | Fade |

### Visual effects
- **Combos:** matches within 8 s of each other count as a combo (the existing match-melody window).
  From 3 in a row: floating gold "Combo ×N" where the pair met, a widening gold ring, more
  sparkles and petals (5 or more: bigger), and a quiet shimmer at 3, 5, 8 and 10 in a row, with a
  35 ms haptic.
- **Level complete:** the dialog panel settles in, stars pop one by one (with a small sparkle,
  a bell chord D6, F#6, A6, and a light haptic each), and a gentle shower of sakura petals falls
  behind the dialog.
- **Dialogs:** every dialog fades in and its panel settles from 92 % with a soft overshoot.
- **Screen transitions:** a 0.22 s fade to forest green, then 0.32 s back, between every screen;
  taps are blocked while it runs.
- **Background:** title and game backgrounds breathe very slowly (4.5 % zoom and 18 px drift over
  48 s). The journey map keeps its existing parallax and petals.

### Sound
| Event | Sound | Status |
|-------|-------|--------|
| Select | Bamboo wood block, A5 | existing |
| Match | Temple bell, climbing D major pentatonic (combo progression) | existing |
| Combo milestone | High shimmer A6 D7 F#7 A7 | **new** `sfx_combo.wav` |
| Mistake / blocked | Two muted off-key knocks / low thud | existing |
| Hint / shuffle / undo | Wind chimes / bamboo rattle / koto step down | existing |
| Shuffle landing | Soft wooden patter | **new** `sfx_shuffle_land.wav` |
| Level complete | Bell run and D chord, then one bell per star | existing + new `star` event |
| Music | Menu (58 s) and gameplay (99 s) loops | **new**, previously missing |

### Settings (all saved between sessions)
Music volume, Sound Effects volume, Nature Ambience volume, Vibration on/off, **Reduced Animations
on/off (new)**, All Sound on/off. Reduced Animations is stored in `user://settings.cfg` (section
`display`) through the crash-safe `SafeConfig`. On the web its default follows the browser's
`prefers-reduced-motion`.

## 2. Modified files

| File | Change |
|------|--------|
| `scripts/autoload/motion.gd` (**new**, autoload `Motion`) | Reduced-animations setting, persistence, web system preference |
| `scripts/components/tile_view.gd` | All tile motion: select pop, match glide, reverse restore, shuffle gather/return, reveal, mistake shake, breathing hint; `home_position`; one reset that stops everything |
| `scripts/components/board_view.gd` | Meeting points, travel times, combo bursts, reveal timing, animated shuffle with `is_busy()`, `shuffle_spreading` signal |
| `scripts/components/match_burst.gd` | Delay, combo strength (ring, more particles), petals optional, reduced mode |
| `scripts/components/background_drift.gd` (**new**) | Slow background breathing |
| `scripts/components/modal_dialog.gd` | Panel pop-in, star sparkles, `star_popped` signal, earned-star count that works in every mode |
| `scripts/components/audio_settings_panel.gd`, `scenes/components/audio_settings.tscn` | Reduced Animations toggle |
| `scripts/screens/game_screen.gd` | Combo display and sounds, haptics, star chimes, petal shower, shuffle/undo animations, taps and tools wait for a shuffle |
| `scripts/screens/startup_screen.gd` | Background drift |
| `scripts/autoload/game_session.gd` | Fade transitions between screens |
| `scripts/core/audio_catalog.gd` | `combo`, `star`, `shuffle_land` events |
| `themes/zen_theme.tres` | `ComboLabel` style (gold with forest outline) |
| `project.godot` | `Motion` autoload |
| `tools/audio/generate_audio.sh` | Combo shimmer and shuffle landing |
| `tools/audio/generate_music.py` (**new**) | Music synthesiser |
| `tests/integration/playthrough_test.gd`, `audio_test.gd` | New animation tests; updated for animated shuffle, installed music and star chimes |
| `docs/AUDIO_ASSETS.md`, `CLAUDE.md` | Asset status and licensing, motion rules |

## 3. New audio and visual assets

| Asset | Source | Licence |
|-------|--------|---------|
| `assets/audio/music/music_main_menu.ogg` (340 KB) | Synthesised by `tools/audio/generate_music.py` | Original, project-owned |
| `assets/audio/music/music_gameplay.ogg` (464 KB) | Same | Original, project-owned |
| `assets/audio/sfx/sfx_combo.wav`, `sfx_shuffle_land.wav` | `tools/audio/generate_audio.sh` (ffmpeg tone synthesis) | Original, project-owned |
| Combo ring, sparkle and flash textures | Gradients generated in code | Original |
| Petals | Existing `assets/effects/petal_02.png` from the project's asset pack | Unchanged, same licence as the pack |

No asset was replaced or edited. Before this phase every existing sound was already original
(generated by our own script from pure tones); none came from a third party.

## 4. Performance considerations

- **Only moving tiles animate.** A match tweens 2 tiles; selection, hint and reveal touch 1 or 2.
  Shuffle tweens every tile for about 0.6 s (at most 118 on level 10), using Godot's built-in
  tweens: no per-frame scripts.
- **Particles are small and few:** up to 14 sparkles and 6 petals per match (30 and 10 on a big
  combo), 26 petals for the level-complete shower, all CPU particles with tiny textures, all freed
  when done.
- **No shaders, no new textures to load,** no extra draw passes. Glows are the existing style
  boxes and appear only on selected, hinted or flashed tiles.
- **Background drift** is one looping tween on one texture. It means the screen changes every
  frame; Godot redraws every frame anyway unless low-processor mode is on (it isn't).
- **Music** is streamed Ogg at 37 to 46 kbps; the new effects add 0.17 MB to the preloaded set.
- **Logic never waits for animations.** The model is updated first; tiles leaving the board stop
  taking taps at once; only a shuffle blocks taps (about 0.6 s, while faces are swapping).
- **Interruptions are safe:** every tile animation runs on TileView's own tweens. `reset_visual()`
  stops them all and puts the tile at its home spot, unscaled, visible and tappable. Undo, Shuffle
  and the end of every shuffle go through it; Restart and a collection with a different tile size
  rebuild the board; a collection change of the same size only swaps art and leaves running
  animations alone. Bursts live under the board, so leaving a level frees them.

## 5. Test results

| Suite | Result |
|-------|--------|
| Import, editor, main scene (`--quit-after 120`) | Clean: no errors or warnings |
| Unit tests | 69 passed, 0 failed |
| Playthrough (integration) | 226 checks, 0 failed (was 200: 26 new) |
| Audio (integration) | 72 checks, 0 failed |
| Ads (integration) | 48 checks, 0 failed |
| Screenshots (61) | Reviewed: selection, match mid-glide, settings, level complete, all collections |

New checks cover:
- the select lift and swell, and deselect settling
- 9 rapid taps on one tile
- the matched pair gliding together, and leaving tiles ignoring taps
- undo starting at the meeting point and ending at home
- the mistake shake settling
- the hint breathing stopping when cleared
- interruptions: a shuffle while a pair is still gliding, then two undos, leaving every tile home and tappable
- taps and tools waiting for a shuffle
- Combo ×3 text and shimmer
- one chime per earned star, and the petal shower
- reduced animations: saved and restored, no swell, fade in place, quick shuffle

These checks were already in place and still pass:
- all six collections dealing and clearing
- match detection
- time, mistakes and stars
- saves and progress, including the damaged-file recovery
- the back button
- every ad placement

Existing saves and settings files are unchanged in format; Reduced Animations is a new key with a
default, so old files load as before.

The screenshot tool reports a few objects still in use when it quits (it exits mid-animation).
This is tool-only; the game and test runs exit clean.

### Needs a real device (not testable here)
- 60 FPS on a mid-range Android phone, especially a shuffle on level 10 (118 tiles) and a big
  combo burst. Use Godot's remote debugger (Monitors → FPS, Process time).
- How the haptic ticks feel (10, 15, 35 and 60 ms) on different phones; some phones ignore very
  short vibrations.
- Listening to the music and new sounds on phone speakers and headphones. Nobody has heard the
  generated audio yet (levels, seams and pitch were measured, not listened to).
- Android's system "Remove animations" setting is not read (Godot needs a plugin for it); players
  use the in-game toggle.
- Screen fades and the back button during a fade.

## 6. Remaining improvements

- **Listen and tune:** the bell and koto timbres, music mix against tile sounds, the combo shimmer
  level. Replace any generated sound with recorded or commissioned audio under the same file name.
- **Bird ambience** is still missing (`ambient_birds.ogg`).
- **Frame-rate and battery tuning** on a device: consider a 60 fps cap or low-processor mode on
  menus once measured.
- **Tile art readability** (from the audit): classic captions, missing CJK faces, Fruits and
  Vegetables look-alikes.
- **Rewards:** the level-complete screen celebrates stars only; a coin or collection-progress
  reward would need a design decision first.
- **Journey map:** marker label overlap (audit L11) and a richer unlock moment.
- Optional: more varied match bursts per collection (leaves for Vegetables, sparkles for
  Letters).
