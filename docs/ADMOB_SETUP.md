# AdMob setup plan (Android first)

Status: **preparation done; AdMob not installed yet.** The game's ad placements, test IDs and
stand-in ads are ready (`docs/ADS.md`). This file lists what is still needed, who does it, and in
what order. iOS can follow the same path later.

## Plugin

**godot-admob** by Cengiz, published by godot-sdk-integrations: https://github.com/godot-sdk-integrations/godot-admob
- **Version and licence:** v7.0 (released 2026-05-27), **requires Godot 4.7+** (we use 4.7.2), MIT licence, free.
- **Formats:** banner (adaptive), interstitial, rewarded, rewarded interstitial, app open, native.
- **Consent:** Google's User Messaging Platform (UMP) is built in, for EU/UK consent and US state privacy.
- **API:**
  - an `Admob` node, `initialize()`, `initialization_completed`;
  - `load_rewarded_ad(LoadAdRequest)` then `show_rewarded_ad(ad_id)`, the reward on `rewarded_ad_user_earned_reward`;
  - interstitial and banner follow the same pattern;
  - consent: `get_consent_status()`, `update_consent_info()`, `load_consent_form()`, `show_consent_form()`.
- **Android:** needs the **export templates** and **Use Gradle Build**. The App ID goes in
  `addons/AdmobPlugin/android_export.cfg` (Debug and Release sections), with `is_real` choosing test or real ads.
- **Caution:** the publisher labels v7.0 "unstable" (no changelog). We test it on a device with test ads
  before release. v6.0 exists but targets older Godot versions.
- **Docs:** https://godot-sdk-integrations.github.io/godot-admob

## What you need to do

1. **AdMob account:** create one at https://admob.google.com if you don't have one.
2. **Add the app:** Android, "Zen Mahjong Journey". It can be added before it is on Google Play and linked later.
3. **Create three ad units:** **Banner** (journey map), **Interstitial** (between levels) and **Rewarded**
   (hint and second chance). Send me the App ID (`ca-app-pub-…~…`) and the three unit IDs
   (`ca-app-pub-…/…`). They go in only for release builds; development keeps Google's test IDs.
4. **Privacy & messaging in AdMob:** create a **European regulations (GDPR)** message, and a
   **US state regulations** message if you want US coverage. The plugin shows these automatically.
5. **Privacy policy:** AdMob and Google Play require a public URL. I can write it and host it free on the
   game's GitHub Pages site. I need the name to show as the developer and a contact email.
6. **Approve two downloads** (they go only into Godot's own folders and the project):
   - Godot 4.7.2 export templates: `Godot_v4.7.2-stable_export_templates.tpz`, about **1.2 GB**, from
     https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable
   - Plugin: `AdmobPlugin-Android-v7.0.zip`, **0.25 MB**, from
     https://github.com/godot-sdk-integrations/godot-admob/releases/tag/v7.0
7. **Later, before publishing:**
   - Create an **upload keystore** and keep a safe backup. Losing it blocks updates.
   - In **Google Play Console**: declare "Contains ads"; fill in **Data safety** (advertising ID, device and
     usage data collected by the ads SDK); declare the **Advertising ID** use; complete the content rating;
     add the privacy policy URL.
   - **app-ads.txt:** AdMob gives a line to publish on your developer website's root. GitHub Pages can
     host it if the developer site is `salmanabdallah89.github.io`; that needs a repository named
     `salmanabdallah89.github.io`.

## What I will do (after the downloads are approved)

1. Install the export templates, then **Project → Install Android Build Template** (creates `android/`).
2. Android preset:
   - turn on **Use Gradle Build**;
   - export **AAB** for Google Play (APK stays possible for testing on your phone);
   - keep the default min/target SDK of Godot 4.7.
   - The internet and network-state permissions are **already on** (done now).
3. Install the plugin into `addons/AdmobPlugin`. Write `android_export.cfg`: the Debug section gets Google's
   test App ID, the Release section gets your App ID, and `is_real` is false until release.
4. Write `scripts/ads/admob_bridge.gd`, which connects the plugin to our existing `AdsManager`. No game
   screen changes are needed: hints, second chances, interstitials and the map banner already go
   through `AdsManager`.
   - **Start-up:** consent first (update the consent info, show the form if required), then `initialize()`,
     then preload one rewarded and one interstitial ad.
   - **Rewarded:** pays only on `rewarded_ad_user_earned_reward`. If it fails to load or show, the game
     continues without the reward, as the stand-in ads do now. A new ad loads after each one closes.
   - **Banner:** adaptive, at the bottom of the journey map only, never during play.
   - **Settings:** a "Privacy options" button appears when the consent rules require it, so players can
     change their choice.
   - **Mute:** game audio is muted while an ad plays (already handled by `AdsManager`).
5. Test on your phone with **test ads only**:
   - every placement: hint, second chance, interstitial every 3rd clear, map banner;
   - the consent form, using a test device set to the EEA;
   - offline behaviour (no ads, game still works).

## Rules we keep (AdMob policy)

- **Testing:** use test IDs while developing. **Never tap your own real ads.**
- **Interstitial timing:** interstitials only between levels, after the Level Complete screen, at most every 3rd clear,
  and never during play or on app start.
- **Rewarded ads are optional:** the player chooses "Watch Ad", and the reward is stated before the ad.
- **Banner placement:** banner on the journey map only, never over the tile board or buttons.
- **Kids:** the game is not aimed at children; the Play content rating must say so (otherwise ads need the
  child-directed setting).
