"""Turn a skin built for Z-DON into the one upstream YataiDON needs, without Z-DON's two skin features:

  * texture density (screen.texture_density = 2: the skin's own pictures at twice the size, its own texture.json
    numbers physical) -> the plain 1080p skin;
  * font overlays (screen.font_base = "font.ttf": Z-DON draws font_<lang>.ttf over the base, which has the
    glyphs the overlay lacks) -> only the base font: upstream would load the overlay alone and miss glyphs.

    python tools/zdon_skin_upstream.py <skin dir> <out dir>

Only the skin's own Graphics change (its parents' files, also those nested in _base/, are 1x already):
  * every texture.json entry: x, y, x2, y2 halved the way the engine reads them (int(n * 1/2));
  * an entry's picture (name.png, or the frames in name/) halved with a box filter, which keeps 2x2 pixel-art
    blocks exact and averages the smooth art; an entry marked "density": 1 keeps its picture (already logical
    size) and loses the mark;
  * skin_config.json: screen.texture_density removed.
Everything else (layouts in skin_config, animation.json, scripts, sounds, fonts) is in logical units already.
A skin with neither feature is copied as it is.
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

from PIL import Image


def half(v):
    return int(v / 2) if isinstance(v, (int, float)) and not isinstance(v, bool) else v


def halve_png(path: Path) -> None:
    with Image.open(path) as im:
        im.load()
        mode = im.mode
        out = im.convert("RGBA").resize((max(1, im.width // 2), max(1, im.height // 2)), Image.Resampling.BOX)
    if mode in ("RGB", "RGBA", "LA", "L"):
        out = out.convert(mode) if mode != "RGBA" else out
    out.save(path, optimize=False)


def convert_folder(folder: Path) -> tuple[int, int]:
    tj = folder / "texture.json"
    data = json.loads(tj.read_text(encoding="utf-8-sig"))
    halved = kept = 0
    for name, value in data.items():
        entries = value if isinstance(value, list) else [value]
        first = entries[0] if entries and isinstance(entries[0], dict) else {}
        logical = first.get("density") == 1
        for e in entries:
            if not isinstance(e, dict):
                continue
            for k in ("x", "y", "x2", "y2"):
                if k in e:
                    e[k] = half(e[k])
            e.pop("density", None)
            if "crop" in e:
                raise SystemExit(f"{tj}: {name} has a crop; not handled")
        if logical:
            kept += 1
            continue
        pics = [folder / f"{name}.png"] if (folder / f"{name}.png").is_file() else sorted((folder / name).glob("*.png"))
        for p in pics:
            halve_png(p)
        halved += len(pics)
    tj.write_text(json.dumps(data, ensure_ascii=False, indent=4) + "\n", encoding="utf-8", newline="\n")
    return halved, kept


def main() -> None:
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(src, out)
    cfg_path = out / "Graphics" / "skin_config.json"
    cfg = json.loads(cfg_path.read_text(encoding="utf-8-sig"))
    screen = cfg.setdefault("screen", {})
    density = screen.pop("texture_density", 1)
    base = screen.pop("font_base", None)
    cfg_path.write_text(json.dumps(cfg, ensure_ascii=False, indent=4) + "\n", encoding="utf-8", newline="\n")
    if base:
        dropped = [f for f in (out / "Fonts").glob("font_*.ttf") if f.name != base]
        for f in dropped:
            f.unlink()
        if base != "font.ttf":
            (out / "Fonts" / base).rename(out / "Fonts" / "font.ttf")
        print(f"{out}: font overlays dropped ({', '.join(f.name for f in dropped)}); {base} is the font")
    if density != 1:
        halved = kept = 0
        for tj in sorted((out / "Graphics").rglob("texture.json")):
            h, k = convert_folder(tj.parent)
            halved += h
            kept += k
        print(f"{out}: {halved} pictures halved, {kept} logical-size textures kept")


if __name__ == "__main__":
    main()
