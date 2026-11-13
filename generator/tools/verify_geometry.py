"""Check the built skin's geometry against the ancestor chain and the density contract.

    python tools/verify_geometry.py [out/YataiDONSimpleStyle]

For every key our skin ships in a subset an ancestor also has:
  * each frame PNG is (ancestor logical frame size) x density   (logical = int(raw * ancestor scale))
  * x / y / x2 / y2 in our texture.json == int(ancestor value * scale) x density
  * a crop strip's rects match its PNG; no "file" pointing elsewhere
For our own subsets (no ancestor): every PNG dimension is a multiple of the density.
skin_config.json: parent, 1920x1080, texture_density == density.
Exit code 1 on any mismatch."""
from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, HERE)

from PIL import Image  # noqa: E402

from ss import atlas  # noqa: E402


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "out", "YataiDONSimpleStyle")
    G = os.path.join(out, "Graphics")
    with open(os.path.join(G, "skin_config.json"), encoding="utf-8") as f:
        scr = json.load(f)["screen"]
    d = scr.get("texture_density", 1)
    errs = []
    if scr.get("parent") != "YataiDONNijiiro" or (scr.get("width"), scr.get("height")) != (1920, 1080):
        errs.append(f"skin_config screen block wrong: {scr}")
    n_keys = n_frames = 0
    for root, _, files in os.walk(G):
        if "texture.json" not in files:
            continue
        rel = os.path.relpath(root, G).replace("\\", "/")
        screen, subset = rel.split("/", 1)
        with open(os.path.join(root, "texture.json"), encoding="utf-8") as f:
            tj = json.load(f)
        for key, entry in tj.items():
            n_keys += 1
            e0 = entry[0] if isinstance(entry, list) else entry
            if isinstance(e0, dict) and "file" in e0:
                errs.append(f"{rel}/{key}: 'file' override (ancestors would not skip the key)")
            if os.path.isdir(os.path.join(root, key)):
                ims = [os.path.join(root, key, f) for f in sorted(os.listdir(os.path.join(root, key)),
                                                                 key=lambda s: (len(s), s)) if f.endswith(".png")]
                sizes = [Image.open(p).size for p in ims]
            else:
                p = os.path.join(root, key + ".png")
                if not os.path.isfile(p):
                    errs.append(f"{rel}/{key}: no PNG / frame folder")
                    continue
                W, H = Image.open(p).size
                crops = e0.get("crop") if isinstance(e0, dict) else None
                if crops:
                    for c in crops:
                        if c[0] + c[2] > W or c[1] + c[3] > H:
                            errs.append(f"{rel}/{key}: crop {c} outside {W}x{H}")
                    sizes = [(c[2], c[3]) for c in crops]
                else:
                    sizes = [(W, H)]
            n_frames += len(sizes)
            for (w, h) in sizes:
                if w % d or h % d:
                    errs.append(f"{rel}/{key}: {w}x{h} not a multiple of density {d}")
            g = atlas.resolve(screen, subset, key)
            if g is None:
                continue        # our own subset
            if len(sizes) != len(g.frames):
                errs.append(f"{rel}/{key}: {len(sizes)} frames, ancestor ({g.source}) has {len(g.frames)}")
            for i, ((w, h), (lw, lh)) in enumerate(zip(sizes, g.frames)):
                if (w, h) != (lw * d, lh * d):
                    errs.append(f"{rel}/{key}[{i}]: {w}x{h}, expected {lw * d}x{lh * d} "
                                f"(logical {lw}x{lh} from {g.source})")
            ours = entry if isinstance(entry, list) else [entry]
            anc = g.entry if isinstance(g.entry, list) else [g.entry]
            for a, o in zip(anc, ours):
                if not isinstance(a, dict):
                    continue
                for k in ("x", "y", "x2", "y2"):
                    if k in a and o.get(k) != atlas.lg(a[k], g.scale) * d:
                        errs.append(f"{rel}/{key}.{k}: {o.get(k)} != {atlas.lg(a[k], g.scale) * d}")
    print(f"density {d}: {n_keys} keys, {n_frames} frames checked")
    for e in errs:
        print("  FAIL", e)
    print("OK" if not errs else f"{len(errs)} problem(s)")
    sys.exit(1 if errs else 0)


if __name__ == "__main__":
    main()
