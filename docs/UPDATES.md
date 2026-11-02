# Telling players about an update

On Android, the start screen reads `version.json` from the game's GitHub Pages site once per
launch. If `latest` is newer than the installed version, the player sees the update notice with
the `notes`. "Update Now" opens the Google Play page; "Later" keeps that version quiet for 3 days.
No connection means no notice, and play is never held up. The file holds no player data.

Only versions from 1.0.8 onwards have this check. Older installs never show the notice.

## Releasing an update

1. Raise the version in `export_presets.cfg` (2 places) and `project.godot`, and build the AAB.
2. Publish it on Google Play and wait until the update is live for players.
3. Only then change `site/version.json`: set `latest` and write up to 4 short `notes`.
4. Push. GitHub Pages publishes the file with the web build, usually within minutes.

Do step 3 last: if the file changes first, players tap Update Now and Google Play has nothing new.
