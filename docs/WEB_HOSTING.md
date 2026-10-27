# Web version on GitHub Pages

The game is published as a web page by GitHub, free, with no domain or server:

**https://salmanabdallah89.github.io/zen-mahjong-journey/**

`.github/workflows/pages.yml` runs on GitHub's machines on every push to `main`:

1. Downloads Godot 4.7.2 and its web export templates (cached after the first run).
2. Imports the project and runs the unit tests. **A failing test stops the deploy.**
3. Exports the `Web` preset (`export_presets.cfg`) to `build/web/` and publishes it to Pages.

The web build is single-threaded (`variant/thread_support=false`), because GitHub Pages cannot
send the cross-origin headers that threaded Godot builds need. Progress and settings are saved in
the browser. There are no ads on the web (see `ADS.md`).

## One-time setup in GitHub (needs the repo owner)

Free GitHub accounts can only use Pages with **public** repositories.

1. Repository → **Settings → General → Danger Zone → Change visibility → Public**.
   Everything becomes public, including all code, artwork, docs and commit history (author name
   and e-mail on every commit).
2. Repository → **Settings → Pages → Build and deployment → Source: GitHub Actions**.
3. Repository → **Actions**: run "Build and deploy web game" (or push any commit). The first run
   downloads about 1.3 GB and takes a few minutes; later runs use the cache.

## Phone app (APK) downloads

GitHub can also host the Android APK for download: Repository → **Releases → Draft a new release**,
attach `build/zen-mahjong-journey-debug.apk`. Building the APK needs the export templates on this
PC (Godot → Editor → Manage Export Templates).
