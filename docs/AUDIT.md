# Project audit: Phase 1 (October 2026)

Scope: the whole Godot project (scenes, scripts, assets, configuration, all six tile collections),
checked against a premium mobile Mahjong benchmark. Method: three read-only reviews (gameplay code,
graphics/assets, Android/AdMob readiness), the full test suite, 72 screenshots at phone and tablet
shapes, and the live web build. Every finding below was confirmed in the code before it was fixed.

Status key: ✅ fixed in this phase · ⏳ needs artwork or the user · 📋 planned for a later phase.

## 1. Existing features

| Area | State |
|------|-------|
| Gameplay | Mahjong Solitaire rules (free = uncovered and a side open), select / match / mistake, Hint, Shuffle, Undo, Pause, Restart, Level Complete, Out of Time, Too Many Mistakes |
| Levels | 10 hand-made layouts, seeded deals built backwards from free pairs and replayed before use, so **every deal ships with a verified solution**; a budgeted solver confirms all 10 in the unit tests |
| Tile collections | Classic, Animals, Fruits, Vegetables, Alphabet ("Letters"), Mixed, all enabled; the picker on the title screen and in Pause; the choice is saved |
| Progress | Stars (1 to 3), best time, unlocks, per level in `user://progress.cfg`; journey map in perspective with swipe travel |
| Audio | 5 buses, settings panel, 12 sound events (all wired and triggered), pentatonic match melody, ambience; music files not yet supplied |
| Effects | Selection lift and gold glow, hint pulse, blocked shake with blocker outline, match swell and petal burst, heart loss pop, star reveal, unlock pop, intro fade |
| Ads | `AdsManager` with stand-in test ads on desktop (rewarded hint, rewarded second chance, interstitial every 3rd clear, journey banner); AdMob plugin not installed |
| Platforms | Web build live on GitHub Pages (CI runs the unit tests first); Android preset exists |
| Tests | 69 unit tests, 3 integration suites (playthrough, audio, ads), screenshot tool |

There is no achievements system in the project, so nothing to preserve there.

## 2. Problems found, by priority

### High
| # | Problem | Status |
|---|---------|--------|
| H1 | **Undo pressed during the 0.34 s match animation left both tiles invisible but still in play.** They kept blocking neighbours, could not be tapped, and Hint could point at them. Only Shuffle or Restart brought them back. | ✅ |
| H2 | **Saved progress could be wiped.** A damaged `progress.cfg` loaded as empty and the next clear saved over it; saves overwrote the file in place, so a kill mid-save corrupted it. Same for `settings.cfg`. | ✅ |
| H3 | **Android export blockers:** no AAB / Gradle build, no `import_etc2_astc` (the exporter refuses Android without it), no release keystore, internet permission off (needed for ads). | ✅ ETC2/ASTC · ⏳ rest |
| H4 | **Backgrounds stored lossless:** about 14 MB of the web download and of the APK (2.5 to 3 MB each). | ✅ |

### Medium
| # | Problem | Status |
|---|---------|--------|
| M1 | **The clock kept running when the game lost focus without the app pausing** (another browser tab, split screen, notification shade). A long frame stall (a hidden tab coming back) could also take a big chunk of time at once. | ✅ |
| M2 | **"Cleared in m:ss" was wrong after a time second chance**: it was computed from the reset countdown. | ✅ |
| M3 | **A hint could be spent for nothing**: the free hint (or a watched ad) was charged before checking that a matching pair existed. | ✅ |
| M4 | **Android back button gaps**: back did nothing on the title screen (no way out of the app, did not close the picker or settings there); in Pause it did not resume; with Settings or the picker open it opened Pause underneath them. | ✅ |
| M5 | **Progress is keyed by level number.** Inserting or reordering levels in `levels.json` would move players' stars to other levels. | 📋 add stable level ids before adding levels |
| M6 | **Unused art ships in every build**: `app_icon_concept.png` (2.4 MB), `bg_sakura_garden.png` (2.5 MB, the logo-baked splash, unused), the orphan `mixed_27_vegetables_07.png`. | ✅ excluded from exports (files kept) |
| M7 | **No adaptive / monochrome launcher icon**: the only icon is a square 512 px image with no safe zone. | ⏳ needs derived icon art |
| M8 | **Android cloud backup was off**, so progress was lost on reinstall or a new phone. | ✅ |

### Low
| # | Problem | Status |
|---|---------|--------|
| L1 | Repeated taps on a locked journey level pushed its marker permanently off its spot. | ✅ |
| L2 | Journey toasts hid each other early (an old fade hid a newer message). | ✅ |
| L3 | The unlock pop on a newly opened level fought the "current level" breathing animation. | ✅ |
| L4 | Swiping inside the level card scrolled the map behind it. | ✅ |
| L5 | Tapping a locked level played the click and the "blocked" sound together. | ✅ |
| L6 | Mute also switched off vibration while the Vibration toggle still read "On". Vibration now follows its own setting. | ✅ |
| L7 | Toolbar buttons could fire from the keyboard while a dialog was open (desktop/web). | ✅ guards added |
| L8 | Classic flower and season captions ("PLUM", "SPRING") are too small to read on a phone. | ⏳ art |
| L9 | Dead clock bookkeeping in `game_screen.gd` (`_started_ms`, `_paused_ms`). | ✅ removed |
| L10 | Low-processor mode / frame cap not set (battery). | 📋 decide during the animation phase, it affects smoothness |
| L11 | Journey map: the name label of the next level ("Pagoda · LOCKED") can sit under the current level's marker. | 📋 screen redesign phase |

## 3. Missing or defective assets (needs the artist)

- **Classic:** 16 faces held back (`characters_1..9`, the 4 winds, red and green dragons: the CJK glyphs render as boxes; white dragon pending review). Boards use bamboo, dots, flowers and seasons only until replaced. See `KNOWN_ISSUES.md`.
- **Fruits:** `plum` is the same drawing as fig (held back). Apple, persimmon, orange and pomegranate are close; worth redrawing for readability.
- **Vegetables:** 13 look-alike copies held back (`ARTWORK_FIX_LIST.md`).
- **UI icons:** `icon_shuffle.png` is broken (vector stand-in used); `icon_music` = `icon_sound_off`, `icon_star` = `icon_trophy`; lock, gift, shop, coin icons don't match their names. None of the wrong ones is used yet; they will matter for Settings / Shop screens.
- **App icon:** adaptive foreground (432 px, art inside the central 66 %), background and monochrome layers; a 512 px Play Store icon.
- **Audio:** `music_main_menu.ogg`, `music_gameplay.ogg`, `ambient_birds.ogg` (`AUDIO_ASSETS.md`).
- **Font:** a bundled, licensed serif to replace the system-font placeholder.

No image is missing, corrupt, transparent or mis-sized; every path in scenes, manifests and the theme
resolves. Level generation is solvable for all 10 levels (verified by replay and by the solver).

## 4. Risks to saved progress

| Risk | Status |
|------|--------|
| Damaged or half-written `progress.cfg` silently reset the journey | ✅ `SafeConfig`: write to `.tmp`, keep the last good file as `.bak`, swap; loading falls back to the temp or backup file and keeps a damaged file as `.damaged` |
| Reinstall / new phone loses progress | ✅ Android backup allowed (`user_data_backup/allow=true`) |
| Progress keyed by level number | 📋 needs stable ids (and a one-time migration) before levels are inserted or reordered. **Until then, only append new levels at the end of `levels.json`.** |
| Save format changes | None in this phase: same files, same keys. Existing saves load unchanged. |
| Web saves live in the browser's storage | Clearing site data resets progress; expected for a web game |

## 5. Android publishing and AdMob readiness

Done now: ETC2/ASTC texture import on, user-data backup on, unused art excluded, back button handled on every screen.

Needs you (cannot be done from here):
1. Install the Android export templates (Godot → Editor → Manage Export Templates) and the Android build template (Project → Install Android Build Template).
2. Then switch the Android preset to Gradle build and AAB (`gradle_build/use_gradle_build=true`, `gradle_build/export_format=1`), pin `target_sdk=35` / `min_sdk=24`.
3. Create an upload keystore, enter it in the Android preset (stored in the git-ignored `.godot/export_credentials.cfg`), enrol in Play App Signing, and back it up.
4. For ads: turn on the internet permission, install the AdMob plugin, real App ID and unit ids, UMP consent, privacy policy, Data safety and "Contains ads" in Play Console (`ADS.md`).

## 6. Files changed in this phase

| File | Change |
|------|--------|
| `scripts/components/tile_view.gd` | Keeps the match tween; any restore/reset kills it (H1); `is_removing()` |
| `scripts/screens/game_screen.gd` | Focus-out pause and stall-capped clock (M1); real play time (M2); hint checks for a pair first (M3); back button (M4); guards on Shuffle/Undo/Hint under dialogs (L7); dead code removed |
| `scripts/screens/startup_screen.gd` | Back closes panels, then leaves the app (M4) |
| `scripts/components/collection_picker.gd`, `audio_settings_panel.gd` | Public `close()` for the back button |
| `scripts/core/safe_config.gd` (new), `progress_store.gd`, `user_settings.gd` | Crash-safe saves with backup (H2) |
| `scripts/components/level_node.gd` | Nudge returns home (L1), unlock pop then breathing (L3), no double sound (L5) |
| `scripts/screens/journey_screen.gd`, `scripts/components/journey_world.gd` | Toast replacement (L2), sound (L5), no map swipe under the card (L4) |
| `scripts/autoload/audio_manager.gd` | Vibration independent of mute (L6) |
| `assets/backgrounds/*.png.import` | Lossy WebP at quality 0.85 (H4). Import setting only; the source PNGs are untouched |
| `project.godot` | `import_etc2_astc=true` (H3) |
| `export_presets.cfg` | Unused art excluded (M6), Android backup allowed (M8) |
| `tests/unit/test_progress.gd`, `tests/integration/playthrough_test.gd`, test cleanups | Regression tests for every fix above; tests remove `.bak`/`.tmp` files too |

## 7. Next phase: tile interaction feel

Not started here, by request. Candidates found during the audit: selection press-down and settle,
a short travel of the matched pair toward each other before they vanish, a softer "no" for mistakes
(separate from the blocked shake), combo pitch already exists in the melody and can drive visuals,
shuffle as a visible swirl instead of an instant swap, haptic patterns per event, and frame-rate /
low-processor tuning measured on a device.
