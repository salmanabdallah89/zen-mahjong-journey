# Telling players about an update

On Android the start screen checks for an update once per launch. Nothing is ever held up: no
connection means no notice.

## Installs from Google Play (from version 1.0.12)
The game asks Google Play itself (In-App Updates, `PlayUpdateBridge` and our own plugin
`addons/zen_play_update`). Play knows which version each player can get on their track
(closed testing or production), so **nothing has to be published by hand**.

1. Play says an update exists → the notice shows ("A new version is ready", or the notes below).
2. "Update Now" opens Play's own small update screen; the download runs in the background while
   the player keeps playing.
3. When it has downloaded, the notice shows "Update Ready" → "Restart" installs it and reopens
   the game (progress is kept). "Later" offers it again on the next visit to the start screen.
4. "Later" on step 1 keeps that build quiet for 3 days.

Play can take a few hours after a release goes live before it offers it in-app. A build installed
from Android Studio, adb or Godot (not from Play) always gets "no update" from Play.

**Testing:** install the older build from the Play testing track, publish a newer build to the
same track, wait until Play lists it, then open the game. (Play Console's "Internal app sharing"
also works for quick tests.)

## Notes (optional) and installs not from Play
`site/version.json` on GitHub Pages:
- gives the notice its "What's new" lines whenever its `latest` is newer than the installed version;
- is the only update check for installs that did not come from Play (and for versions before 1.0.12).

Change it only after the release is live on Google Play: set `latest` and up to 4 short `notes`, then push.

## Releasing an update
1. Raise the version in `export_presets.cfg` (2 places) and `project.godot`, and build the AAB.
2. Publish it on Google Play.
3. When it is live, optionally update `site/version.json` with the notes and push.

## The plugin
Java source: `android_plugins/play_update/src/`. Rebuild the AAR after changing it:
`bash android_plugins/play_update/build.sh` (needs JDK 17, the Android SDK, the installed Android
build template and Play's app-update 2.1.0 in the Gradle cache).
