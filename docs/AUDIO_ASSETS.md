# Audio assets

All sounds are referenced by id in `scripts/core/audio_catalog.gd`. A missing file is skipped
silently, so the game runs, without that sound, until the file is installed. Drop a file in
place under the exact name below and it is used automatically. No code change is needed.

## Checklist

| File | Status | Format | Duration | Notes |
|------|--------|--------|----------|-------|
| `assets/audio/music/music_main_menu.ogg` | ✅ **licensed** | Ogg Vorbis q3, 44.1 kHz stereo | 2:34 seamless loop | **"In the place far away" by HarumachiMusic** (Pixabay), koto over soft pads. Licence: **Pixabay Content License**, no credit required (credited in Settings as a courtesy). Source: the owner downloaded it from the Pixabay track page on 2026-10-28. Prepared: cut at 2:42 before the fade-out, the 8 s before that blended into the first 8 s (equal-power crossfade) for a seamless loop (seam jump 25 vs typical step 638), −2.9 dB to −19.0 LUFS, peaks −5.1 dBTP. Plays on the title screen and the journey map |
| `assets/audio/music/music_gameplay.ogg` | ✅ **licensed** | Ogg Vorbis q3, 44.1 kHz stereo | 3:17 seamless loop | **"Ripples" by Kevin MacLeod** (incompetech.com), solo koto. Licence: **CC BY 4.0**, credit shown in Settings (`AudioCatalog.MUSIC_CREDITS`). Source: `Ripples.mp3` from incompetech.com, downloaded 2026-10-28. Prepared: trailing silence trimmed, the last 4 s of ring-out crossfaded over the opening so the loop is seamless (seam jump 229 vs typical step 798), −1.5 dB to −19.3 LUFS, peaks −1.6 dBTP |
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
| `assets/audio/sfx/sfx_reward.wav` | ✅ generated | WAV | 1.20 s | Bright double chime: rewarded ad pays out (second chance) |
| `assets/audio/sfx/sfx_unlock.wav` | ✅ generated | WAV | 1.80 s | Soft gong: a new level opens on the journey map |
| `assets/audio/sfx/sfx_combo_1.wav` … `sfx_combo_5.wav` | ✅ generated | WAV | 1.0–2.4 s | Combo tier cues for Nice! (2 in a row), Great! (3), Amazing! (5), Excellent! (7), Zen Master! (10): rolled D major chords, each richer and higher; peaks −11 to −8 dBFS, under the match bells |
| `assets/audio/sfx/sfx_shuffle_land.wav` | ✅ generated | WAV | 0.6 s | Soft low wooden patter as shuffled tiles settle back |
| (level-complete stars) | ✅ reuses melody bells | — | — | Effect id `star`: each earned star rings D6, F#6, A6 (a D major chord) |

"Generated" files are original and procedural (pure tones, envelopes and filtered noise via
ffmpeg; music synthesised note by note in Python; no samples, loops or presets from anyone
else), so there are no third-party rights. Regenerate or tweak them from the project root with
`bash tools/audio/generate_audio.sh` (effects, ambience) and `python tools/audio/generate_music.py`
(music; deterministic seeds, about 20 s). Re-running rewrites the `.ogg` files with new stream
serial numbers even when the audio is identical, so restore unchanged ones with `git checkout`. They were checked for duration,
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


## Licensed music

| Track | Used as | Author | Licence | Credit required | Source page |
|-------|---------|--------|---------|-----------------|-------------|
| Ripples | Gameplay | Kevin MacLeod | CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/) | Yes: `"Ripples" Kevin MacLeod (incompetech.com), Licensed under Creative Commons: By Attribution 4.0` (shown in Settings) | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100691 |
| In the place far away | Title screen and journey map | HarumachiMusic | Pixabay Content License (https://pixabay.com/service/license-summary/) | No (credited in Settings anyway) | https://pixabay.com/music/ambient-in-the-place-far-away-japanese-koto-inspirational-calm-music-151182/ |

**Pixabay note:** the licence allows use in games and apps (it only forbids selling or distributing
the track on its own). This track is **registered with YouTube Content ID**, so trailers or gameplay
videos posted to YouTube with this music may get a claim; it does not affect the game itself.

Keep the credit in `AudioCatalog.MUSIC_CREDITS` (Settings shows it) and in the store listing's credits.
A paid licence from incompetech removes the credit requirement.

The earlier generated music is no longer shipped. `tools/audio/generate_music.py` now writes to
`tools/audio/generated/`, which is excluded from exports.
