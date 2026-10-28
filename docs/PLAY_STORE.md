# Google Play release guide

Status (2026-10-28): release build set up with the real AdMob app, signing preset ready, store art
and screenshots made, privacy policy written. **Not uploaded yet.** The upload key must be created by
the developer (step 1). Play Games sign-in and Firebase come later (separate steps).

## What is ready

| Item | Where |
|------|-------|
| Package name (permanent) | `com.zenmahjongjourney.game` |
| Version | name `1.0.0`, code `1` (raise `version/code` by 1 for every upload) |
| AAB preset | **Android Play** in `export_presets.cfg` → `build/zen-mahjong-journey.aab` |
| Debug APK preset (test ads) | **Android** → `build/zen-mahjong-journey-debug.apk` |
| Real AdMob ids (release only) | `data/ads_release.json`; App ID also in `addons/AdmobPlugin/android_export.cfg` |
| App icon 512×512 | `store/play_icon_512.png` |
| Feature graphic 1024×500 | `store/feature_graphic_1024x500.png` |
| Phone screenshots 1080×1920 | `store/screenshots/store_01…06.png` (`capture_screens.tscn -- <dir> store`) |
| Launcher icon (adaptive) | `assets/branding/app_icon_adaptive_*_432.png`, `app_icon_full_512.png` |
| Privacy policy | `site/privacy.html` → https://salmanabdallah89.github.io/zen-mahjong-journey/privacy.html |

Which ads are served: debug builds always request Google's **test** units; release builds request
the real units. Every APK/AAB carries the real App ID in its manifest, which is allowed.
**Never tap real ads on your own phone.** Add your phone as a test device in AdMob
(Settings → Test devices, using the phone's advertising ID) before installing a release build.

## 1. Create the upload key (you, once)

Run this in a terminal and choose a strong password when asked. Keep the file **and** the
password safe and backed up (password manager + a second copy of the file). Never commit it.

```
"C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot\bin\keytool.exe" -genkeypair -v -keystore "C:\Users\Salman Abdallah\keys\zen-mahjong-upload.keystore" -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

(Create the `keys` folder first.) Then in Godot: **Project → Reload Current Project**, open
**Project → Export → Android Play → Keystore → Release**, and fill in the keystore path, user
`upload` and your password. Godot keeps these in `.godot/export_credentials.cfg` (not in git).

Use **Play App Signing** (the default): Google holds the app signing key, your key only signs
uploads. If the upload key is ever lost, Google support can reset it.

## 2. Build the AAB

Godot: Project → Export → **Android Play** → Export Project (release, uncheck "Export With Debug").
Command line (same result):

```
godot --headless --path . --export-release "Android Play" build/zen-mahjong-journey.aab
```

On this PC the Gradle build needs `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=<short folder>`
(docs/ADMOB_SETUP.md).

## 3. Play Console: create the app

Play Console → **Create app**: name *Zen Mahjong Journey*, default language English (US),
**Game**, **Free**, accept the declarations.

### Store listing (copy-paste)

**App name (30):** Zen Mahjong Journey

**Short description (80):**
Relaxing mahjong solitaire: match tiles across 1000 levels in a zen garden.

**Full description (4000):**
```
Slow down and match your way through a peaceful Japanese garden.

Zen Mahjong Journey is a calm mahjong solitaire puzzle game. Tap two matching free tiles to
clear them from the board, uncover the tiles beneath, and empty the board to finish the level.

FEATURES
• 1000 levels across four gardens: golden cherry blossoms, a bamboo forest, a misty temple
  and a moonlit sanctuary
• A winding journey map that follows your progress, with stars to earn on every level
• Six tile collections: Classic Mahjong, Cute Animals, Fruits, Vegetables, Alphabet and Mixed
• Every board is guaranteed to be solvable
• Helpful tools when you need them: Hint, Shuffle and Undo
• Gentle challenge: a relaxed timer and hearts for mistakes, with a second chance if you need one
• Soft music, nature sounds and smooth, calming animations
• Reduced Animations option and large, easy-to-read tiles
• Plays offline

HOW TO PLAY
A tile is free when nothing lies on top of it and its left or right side is open. Match two
free tiles with the same picture. Flowers match any flower, and seasons match any season.

Take a breath, find a match, and enjoy the journey.
```

**Graphics:** icon `store/play_icon_512.png`, feature graphic `store/feature_graphic_1024x500.png`,
phone screenshots `store/screenshots/` (upload 4–6; order 01 → 06).

**Category:** Game → Puzzle (tags: Mahjong, Tile matching, Relaxing). **Contact email:**
salman.abdallah.89@gmail.com. **Privacy policy:** the URL above.

### App content (Policy → App content)

| Form | Answer |
|------|--------|
| Privacy policy | URL above |
| Ads | **Yes, my app contains ads** |
| App access | All functionality available without special access |
| Content rating | IARC questionnaire: category *Game*; no violence, fear, sexuality, language, drugs, gambling, user interaction or sharing; no purchases. Expected: Everyone / PEGI 3 |
| Target audience | **13+ only** (13–15, 16–17, 18+). Do **not** include under 13 (that triggers Families policy and child-directed ads) |
| News app | No |
| Government app | No |
| Financial features | None |
| Health | None |
| Advertising ID | **Yes**, used for **Advertising or marketing** (and Analytics). The manifest already has `AD_ID` |
| Data safety | See below |

### Data safety (AdMob SDK only; the game itself sends nothing)

Check against Google's guide before submitting:
https://developers.google.com/admob/android/privacy/play-data-disclosure

- Does the app collect or share user data? **Yes**
- Encrypted in transit? **Yes**. Way to request deletion? Provide the contact email (the developer
  holds no data; ads data is deleted under Google's policies).
- Data types (all *collected*, *not optional*, purposes **Advertising or marketing**, **Analytics**,
  **Fraud prevention, security, and compliance**):
  - **Location → Approximate location** (from IP address)
  - **App activity → App interactions**
  - **App info and performance → Crash logs, Diagnostics**
  - **Device or other IDs** (advertising ID)
- Shared: per Google's guide, mark data sent to the AdMob SDK as **shared** for Advertising.

## 4. Testing tracks (required order for new personal accounts)

1. **Internal testing** (up to 100 testers, available in minutes): upload the AAB, add your own
   email, install from the opt-in link. Check ads (your phone registered as a test device),
   consent, all screens.
2. **Closed testing:** personal developer accounts created after 13 Nov 2023 need **at least 12
   testers opted in for 14 continuous days** before **Apply for production** unlocks.
3. **Production:** apply, then roll out (staged rollout, e.g. 20%, is a good start).

After the listing is live: AdMob → Apps → Zen Mahjong Journey → **App settings → link to
Google Play** (clears "Requires review"). For **app-ads.txt**, the file must sit at the root of the
developer website listed in Play (e.g. a `salmanabdallah89.github.io` user-site repository).

## Every later release

Raise `version/code` (and `version/name`) in both Android presets, run all checks, export the AAB
with the same upload key, upload to the track, write release notes.
