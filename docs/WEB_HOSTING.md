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

## Loading page

`web/shell.html` is the Web preset's custom HTML shell (`html/custom_html_shell`). It is an
original loading page:
- forest-green background, matching the game's boot colour, so there is no flash on hand-over;
- the title in the game's colours, a few CSS petals (hidden under `prefers-reduced-motion`);
- a progress bar that shows a percentage only when the download size is known, otherwise a soft sheen.

Its engine start-up script is Godot 4.7.2's `full-size.html`, unchanged apart from driving that bar.

**Audio:** browsers only allow sound after the player interacts with the page. The shell resumes the
game's audio on the first tap or key press anywhere (normally the title screen's Play button), so no
separate "Tap to Start" step is needed and nothing plays before the player acts.

**Diagnostics:** `window.__zenLoad` records `downloaded` and `started` (milliseconds since the page
opened), and `window.__zenAudioContexts` lists the audio contexts and their state.

GitHub Pages already serves `index.wasm` and `index.pck` gzip-compressed (measured: about 10 MB and
7 MB on the wire, both downloaded about 3.6 s after the page opened on a fast connection).

## Word Garden demo page (`site/try/`)
A small hand-written page (no Godot, about 650 KB with its font) where a visitor plays one Word
Garden round (6 picture-and-word pairs) and then gets a "Get the free game" button to Google Play.
Published with the rest of `site/` at `<pages url>/try/`. It is the landing page for paid ads.
- `?speak=ar&learn=en` skips the language choice (`speak` and `learn`: `en`, `es`, `fr`, `ar`);
  without them the page follows the browser language and asks what to learn.
- Pictures in `site/try/img/` are small copies made from `assets/` (the originals are untouched);
  the words are copied from `data/words/words.json`: keep the two in step.
- `python -I tools/build_playable_ad.py` writes the single-file playable ads to `store/ads/`
  (one HTML for Meta and others, a zip for Google Ads). Rebuild after changing the page.
