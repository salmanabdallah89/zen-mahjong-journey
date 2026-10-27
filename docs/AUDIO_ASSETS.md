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
| `assets/audio/sfx/sfx_match_01.wav` … `sfx_match_10.wav` | ✅ generated | WAV 16-bit 44.1 kHz mono | 1.9 s each | **Match melody:** temple bells on D major pentatonic (D5 E5 F#5 A5 B5 D6 E6 F#6 A6 B6), checked in tune. Quick successive matches climb the notes |
| `assets/audio/sfx/sfx_tile_select.wav` | ✅ generated | WAV | 0.3 s | Bamboo wood block tuned to A5 (in key) |
| `assets/audio/sfx/sfx_tile_blocked.wav` | ✅ generated | WAV | 0.22 s | Muted low thud (deliberately outside the melody) |
| `assets/audio/sfx/sfx_hint.wav` | ✅ generated | WAV | 1.6 s | Wind-chime flurry (A6 D7 B6 E7) |
| `assets/audio/sfx/sfx_shuffle.wav` | ✅ generated | WAV | 0.7 s | Bamboo rattle (six knocks) over a soft whoosh |
| `assets/audio/sfx/sfx_undo.wav` | ✅ generated | WAV | 1.0 s | Koto-style pluck stepping down (A5 to F#5) |
| `assets/audio/sfx/sfx_mistake.wav` | ✅ generated | WAV | 0.5 s | Two dull off-key wood knocks: a wrong pair |
| `assets/audio/sfx/sfx_level_failed.wav` | ✅ generated | WAV | 2.3 s | Gentle koto line falling to low D, soft bell |
| `assets/audio/sfx/sfx_button_click.wav` | ✅ generated | WAV | 0.08 s | Tiny bamboo tick |
| `assets/audio/sfx/sfx_level_complete.wav` | ✅ generated | WAV | 3.7 s | Bell run up the scale resolving on a D chord with a low koto D |
| `assets/audio/sfx/sfx_reward.wav` | ✅ generated | WAV | 1.20 s | Bright double chime. **Not triggered yet:** the game has no rewards |
| `assets/audio/sfx/sfx_unlock.wav` | ✅ generated | WAV | 1.80 s | Soft gong. **Not triggered yet:** nothing is locked/unlocked |

"Generated" files are original and procedural (pure tones, envelopes and filtered noise via
ffmpeg, no samples), so there are no third-party rights. Regenerate or tweak them with
`bash tools/audio/generate_audio.sh` from the project root. They were checked for duration,
peak level (normalized to −3 … −6 dBFS, no clipping) and the bells' pitch (each 20–110× stronger
at its note than a semitone away), but **nobody has listened to them yet**. Audition them, and replace any you don't like with recorded or commissioned sounds
under the same names.

For release, use only original audio or tracks whose licence explicitly allows commercial use
in a mobile game. Keep the licence file or invoice with the project.

## Specs for replacements

- **Music:** Ogg Vorbis (`.ogg`), stereo, peaks around −1 dBFS and integrated loudness around
  −18 LUFS (the game mixes music down further). Seamless loop: end and start must join without
  a click; Godot loops the whole file.
- **Ambience:** Ogg Vorbis, seamless loop, quiet (around −30 LUFS). Several layers play at once.
- **Effects:** WAV 16-bit 44.1 kHz mono, short, no leading silence, peaks −3 to −6 dBFS.
  Effects are preloaded, so keep the total under about 3 MB (currently about 2.6 MB).
- **Melody notes:** replacements must keep the same ten pitches, in order, to stay in key.
- In the Godot Import dock, set `.ogg` files to **Loop** (the game also forces looping in code).

## How the mix works

| Bus | Carries | Slider |
|-----|---------|--------|
| Music | menu and gameplay tracks (crossfade 1.5 s; ducked during the level-complete celebration) | Music |
| Ambience | waterfall / birds / wind layers, mix chosen per level background (`AMBIENCE_FOR_BACKGROUND`), slow gentle swells | Nature Ambience |
| SFX | tile, hint, shuffle, undo, level complete, reward, unlock | Sound Effects |
| UI | button clicks | Sound Effects |
| Master | everything | All Sound (mute) |

## Musical tile feedback

Every pair rings the next bell of a D major pentatonic scale, so any sequence sounds
consonant, and a quick streak plays a rising melody:

- A match within 8 s of the previous one (`AudioManager.melody_window`) climbs one note. It
  holds on the top note (B6) after ten.
- A longer pause, a shuffle or a new level starts again from D5.
- Undoing a match steps the melody back one note, so the next match replays it.
- Select (A5 wood block), hint (chimes), undo (koto) and the level-complete cadence are all in
  the same key. The blocked thud is deliberately not.

Limits that keep rapid play clean: 6 shared effect voices, a per-effect overlap cap (match
bells 4, most others 1–2) and a minimum gap per effect (e.g. 50 ms for tile select). A melody
note is never skipped: when 4 bells already ring, the oldest is cut off. Only successful
actions make sounds. The final match of a level plays the level-complete cadence instead of a
bell.
