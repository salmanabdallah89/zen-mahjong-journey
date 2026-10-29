# Ads (AdMob)

Ads run **only in the Android/iOS app**. AdMob does not serve ads in browsers, so the web build
on GitHub Pages has none. Without ads, hints and shuffles are always free and there is no ad-based second
chance; the game is otherwise identical.

## Placements

| Placement | When | Player gets |
|-----------|------|-------------|
| Rewarded: second chance | After losing (time or hearts), once per attempt | +60 s on the clock, or +1 heart, and the same board continues |
| Rewarded: hint | After the 1 free hint per level is used | One hint per watched ad |
| Rewarded: shuffle | After the 1 free shuffle per level is used | One shuffle per watched ad |
| Interstitial | After every 2nd finished level, cleared or lost: when the player leaves the Level Complete popup (Next Level / Replay / Levels) or the loss popup (Retry / Levels). Never during play, and never within 30 s of another ad (e.g. a second-chance ad) | Nothing |
| Banner | Bottom of the journey map only, never during play | Nothing |

Skipping a rewarded ad early gives no reward. The level clock and all game sound pause while an
ad shows. Leaving a level mid-ad closes the ad. All numbers are in `data/ads.json`:
`free_hints_per_level`, `free_shuffles_per_level`, `second_chance_seconds`, `second_chance_hearts`,
`second_chances_per_attempt`, `interstitial_every_levels` and `interstitial_min_gap_seconds`.

## How it works

`AdsManager` (autoload, `scripts/autoload/ads_manager.gd`) is the only code that knows about ads.
Screens call `show_rewarded(placement, on_done)`, `after_level_complete(then)`, `show_banner()`
and `hide_banner()`. It picks a provider:

| Provider | Where | Status |
|----------|-------|--------|
| `simulated` | Desktop debug runs (editor, tests) | ✅ Working: stand-in test ads drawn by the game, so every placement can be played and tested |
| `admob` | Android (iOS later) through godot-admob v7 + `scripts/ads/admob_bridge.gd` | ✅ Installed with **test ids**; not yet tried on a phone |
| `none` | Web build, release desktop builds, phones without the plugin | ✅ Game works without ads |

With AdMob, ad offers (Ad Hint, Ad Shuffle, Watch Ad second chance) appear only while a rewarded ad is loaded,
and an interstitial is skipped when none is loaded, so an offline phone plays like the web build.

Tests: `tests/integration/ads_test.tscn` (86 checks; AdMob routing through a stand-in bridge).

## Ad unit ids

Release builds on phones use the **real** ids in `data/ads_release.json` (the Zen Mahjong Journey
app in AdMob); debug builds, tests and the desktop always use the test ids below.

`data/ads.json` holds **Google's official test ids** (`ca-app-pub-3940256099942544/...`). They
always show test ads and never pay. **Never test with your real ids:** clicking your own real ads
can get the AdMob account banned.

## Steps to real ads

**Current status and checklist: `docs/ADMOB_SETUP.md`** (godot-admob v7 for Godot 4.7, installed).
The steps below are the original outline; steps 2–4 are done.

1. **AdMob account**: create one at admob.google.com, add the app (Android), and create a Banner,
   an Interstitial and a Rewarded ad unit. Put the App ID and the three unit ids in
   `data/ads.json` for release builds. Keep the test ids while developing.
2. **Plugin**: install a Godot 4 AdMob plugin (for example Poing Studios' "Godot AdMob" plugin)
   into `addons/` and the Android build template (Project → Install Android Build Template).
   Then enable Gradle build in the Android export preset (`gradle_build/use_gradle_build=true`).
   The plugin also needs the App ID in its settings / AndroidManifest.
3. **Provider code**: implement the `admob` branches in `ads_manager.gd` (load, show and callbacks).
   They are marked in the code.
4. **Consent**: EU/UK players must see a consent form before personalized ads (GDPR). Use Google's
   User Messaging Platform (UMP), which the AdMob plugins include. Add a privacy policy link to the
   store listing.
5. **Store**: declare "Contains ads" in Google Play Console, and add `app-ads.txt` to the
   developer website (AdMob shows its content).
