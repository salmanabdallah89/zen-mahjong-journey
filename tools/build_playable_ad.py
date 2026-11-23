"""Builds the playable-ad versions of the Word Garden demo page (site/try).

    python -I tools/build_playable_ad.py

The demo page loads its pictures and font from files. Ad networks want one
self-contained file, so this inlines every picture as base64 and drops the
font (the page falls back to the device's serif font).

Output (store/ads/):
  word_garden_playable.html        one file, nothing loaded from the network
                                   (Meta / Facebook and most other networks)
  word_garden_playable_google.zip  index.html plus Google's ExitApi script tag
                                   (Google Ads HTML5 playable for app campaigns)

The page's "Get the game" button calls the network's own store-opening call
(FbPlayableAd.onCTAClick, ExitApi.exit, mraid.open) when it exists.
Check each network's current size limits when you upload; their preview
tools reject a file that does not fit.
"""
import base64
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAGE = ROOT / "site" / "try"
OUT = ROOT / "store" / "ads"
MIME = {".png": "image/png", ".jpg": "image/jpeg"}


def data_uri(name: str) -> str:
    path = PAGE / name
    return "data:%s;base64,%s" % (MIME[path.suffix], base64.b64encode(path.read_bytes()).decode("ascii"))


def build() -> None:
    html = (PAGE / "index.html").read_text(encoding="utf-8")
    html = re.sub(r"/\*FONT\*/.*?/\*/FONT\*/\n", "", html, flags=re.S)
    assert "Fraunces.ttf" not in html
    html = html.replace('url("img/bg.jpg")', 'url("%s")' % data_uri("img/bg.jpg"))
    html = html.replace('url("img/tile.png")', 'url("%s")' % data_uri("img/tile.png"))
    pictures = {p.stem[2:]: data_uri("img/" + p.name) for p in sorted((PAGE / "img").glob("w_*.png"))}
    table = "var PICS = {%s};" % ",".join('"%s":"%s"' % item for item in pictures.items())
    marker = 'img.src = "img/w_" + t.w.id + ".png";'
    assert marker in html
    html = html.replace(marker, "img.src = PICS[t.w.id];")
    html = html.replace('  var PAIRS = 6;', "  " + table + "\n  var PAIRS = 6;", 1)
    assert "img/" not in html, "a picture is still loaded from a file"
    OUT.mkdir(parents=True, exist_ok=True)
    single = OUT / "word_garden_playable.html"
    single.write_text(html, encoding="utf-8", newline="\n")
    google = html.replace("</title>", '</title>\n<script src="https://tpc.googlesyndication.com/pagead/gadgets/html5/api/exitapi.js"></script>', 1)
    archive = OUT / "word_garden_playable_google.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
        bundle.writestr("index.html", google)
    for path in (single, archive):
        print("%s  %d KB" % (path.relative_to(ROOT), path.stat().st_size // 1024))


if __name__ == "__main__":
    build()
