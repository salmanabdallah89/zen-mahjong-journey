# Google Play Games: sign-in and leaderboard

Status (2026-10-29): **switched on** from version 1.0.2 (code 3). Play Games project id
`342484810040` (export presets), leaderboard *Total Score* `CgkIuPK97fsJEAIQAg`
(`data/play_games.json`). Android credentials exist for the app signing key and the upload key.
On web and desktop the Leaderboard button stays hidden.

## What players get

- A **Leaderboard** button on the start screen (Android app only). Tapping it signs the player in
  to Google Play Games if needed, then opens Google's leaderboard screen.
- The leaderboard ranks the **total score**: every level's best score added up
  (`ProgressStore.total_score`, points rules in `LevelScore`). It is sent after sign-in and after
  every clear that beats that level's best. Google keeps each player's highest total.

## How it is built

| Part | Where |
|------|-------|
| Plugin (v3.4.0, unmodified, MIT) | `addons/GodotPlayGameServices/` from github.com/godot-sdk-integrations/godot-play-game-services |
| Game code | autoload `PlayGames` (`scripts/autoload/play_games.gd`) talks to the Android plugin directly |
| Leaderboard id | `data/play_games.json` → `leaderboard_total_score` |
| Game (project) id | Android export presets → `godot_play_game_services/game_id` (appears once the plugin is enabled) |
| Tests | `tests/integration/ads_test.tscn`, `_test_play_games` (stand-in plugin) |

`PlayGames.is_available()` is true only on Android, with the plugin compiled in and a leaderboard
id set. **Do not enable the plugin without the game id:** its manifest entry then points to a
missing string and the Android build fails.

## Steps (you, in Play Console)

1. **Upload a build first** (Internal testing) so Play App Signing creates the app signing key.
2. Play Console → your app → **Grow users → Play Games Services → Setup and management →
   Configuration** → *No, my game doesn't use Google APIs* → name it *Zen Mahjong Journey* →
   Create. Copy the **Project ID** (a number, e.g. `123456789012`).
3. Same page → **Credentials → Add credential → Android**. It asks you to set up the
   **OAuth consent screen** in Google Cloud (External, app name, your email) — then back in Play
   Console create the Android credential twice, one per certificate:
   - **App signing key**: Play Console → Test and release → Setup → **App signing**, copy its
     SHA-1.
   - **Upload key** (for builds installed from your PC): SHA-1
     `A2:BF:66:A3:46:58:ED:38:96:2F:08:B0:2D:42:23:F2:8B:6E:2A:7D`.
   Package name `com.zenmahjongjourney.game`.
4. **Leaderboards → Add leaderboard**: name *Total Score*, format *Numeric*, no decimals,
   ordering *Larger is better*, icon optional. Save and copy its **ID** (starts with `CgkI…`).
5. **Testers**: add your Google account so you can sign in before publishing.
6. **Publish** the Play Games Services configuration (Review and publish). Changes to it can take
   a few hours to reach phones.
7. Send the developer the **Project ID** and the **leaderboard ID**.

## Steps (developer, after the ids arrive)

1. `data/play_games.json`: set `leaderboard_total_score`.
2. Project → Project Settings → Plugins → enable **GodotPlayGameServices** (adds its autoload).
3. Project → Export → both Android presets → `godot_play_game_services/game_id` = Project ID.
4. Raise `version/code`, run all checks, export, install on the phone, test sign-in and the board.
5. Data safety: Play Games adds the player's game account (user IDs, gameplay). Update the
   Data safety form and `site/privacy.html` before that release.
