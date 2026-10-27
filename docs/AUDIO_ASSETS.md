# Audio assets

All sounds are referenced by id in `scripts/core/audio_catalog.gd`. A missing file is skipped
silently, so the game runs, without that sound, until the file is installed. Drop a file in
place under the exact name below and it is used automatically. No code change is needed.

## Checklist

| File | Status | Format | Duration | Notes |
|------|--------|--------|----------|-------|
| `assets/audio/music/music_main_menu.ogg` | ❌ **missing** | Ogg Vorbis, 44.1 kHz stereo, ~128–160 kbps | 2–3 min, seamless loop | Calm koto/shakuhachi/pads, no loud percussion |
| `assets/audio/music/music_gameplay.ogg` | ❌ **missing** | Ogg Vorbis, 44.1 kHz stereo | 3–4 min, seamless loop | Even calmer than the menu, unobtrusive under tile sounds |
| `assets/audio/ambient/ambient_waterfall.ogg` | ✅ generated | Ogg Vorbis, 44.1 kHz mono | 30 s loop | Filtered pink noise |
| `assets/audio/ambient/ambient_wind.ogg` | ✅ generated | Ogg Vorbis, 44.1 kHz mono | 30 s loop | Filtered brown noise with a slow 0.1 Hz swell |
| `assets/audio/ambient/ambient_birds.ogg` | ❌ **missing** | Ogg Vorbis, 44.1 kHz stereo | 30–60 s loop | Sparse, distant songbirds. Not synthesized: fake birdsong sounds artificial |
| `assets/audio/sfx/sfx_tile_select.wav` | ✅ generated | WAV 16-bit 44.1 kHz mono | 0.16 s | Soft wooden tap |
| `assets/audio/sfx/sfx_tile_match.wav` | ✅ generated | WAV | 1.10 s | Two-partial bell chime (E6 + B6); played with ±6 % pitch variation |
| `assets/audio/sfx/sfx_tile_blocked.wav` | ✅ generated | WAV | 0.22 s | Muted low thud |
| `assets/audio/sfx/sfx_hint.wav` | ✅ generated | WAV | 0.95 s | Rising three-note sparkle (C6 E6 G6) |
| `assets/audio/sfx/sfx_shuffle.wav` | ✅ generated | WAV | 0.55 s | Soft whoosh |
| `assets/audio/sfx/sfx_undo.wav` | ✅ generated | WAV | 0.45 s | Two descending notes |
| `assets/audio/sfx/sfx_button_click.wav` | ✅ generated | WAV | 0.08 s | Tiny bamboo tick |
| `assets/audio/sfx/sfx_level_complete.wav` | ✅ generated | WAV | 2.60 s | Plucked pentatonic arpeggio |
| `assets/audio/sfx/sfx_reward.wav` | ✅ generated | WAV | 1.20 s | Bright double chime. **Not triggered yet:** the game has no rewards |
| `assets/audio/sfx/sfx_unlock.wav` | ✅ generated | WAV | 1.80 s | Soft gong. **Not triggered yet:** nothing is locked/unlocked |

"Generated" files are original and procedural (pure tones, envelopes and filtered noise via
ffmpeg, no samples), so there are no third-party rights. Regenerate or tweak them with
`bash tools/audio/generate_audio.sh` from the project root. They were checked for duration,
peak level (−4 to −9 dBFS, no clipping) and loudness, but **nobody has listened to them
yet**. Audition them, and replace any you don't like with recorded or commissioned sounds
under the same names.

For release, use only original audio or tracks whose licence explicitly allows commercial use
in a mobile game. Keep the licence file or invoice with the project.

## Specs for replacements

- **Music:** Ogg Vorbis (`.ogg`), stereo, peaks around −1 dBFS and integrated loudness around
  −18 LUFS (the game mixes music down further). Seamless loop: end and start must join without
  a click; Godot loops the whole file.
- **Ambience:** Ogg Vorbis, seamless loop, quiet (around −30 LUFS). Several layers play at once.
- **Effects:** WAV 16-bit 44.1 kHz mono, short, no leading silence, peaks −3 to −6 dBFS.
  Effects are preloaded, so keep the total under about 3 MB.
- In the Godot Import dock, set `.ogg` files to **Loop** (the game also forces looping in code).

## How the mix works

| Bus | Carries | Slider |
|-----|---------|--------|
| Music | menu and gameplay tracks (crossfade 1.5 s; ducked during the level-complete celebration) | Music |
| Ambience | waterfall / birds / wind layers, mix chosen per level background (`AMBIENCE_FOR_BACKGROUND`), slow gentle swells | Nature Ambience |
| SFX | tile, hint, shuffle, undo, level complete, reward, unlock | Sound Effects |
| UI | button clicks | Sound Effects |
| Master | everything | All Sound (mute) |

Limits that keep rapid play clean: 6 shared effect voices (the oldest is reused), at most 2
copies of one effect at once, and a minimum gap per effect (e.g. 50 ms for tile select). Only
successful actions make sounds. The final match of a level plays the level-complete sound
instead of the match chime.
