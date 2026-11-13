"""Post-build pass: store blocky textures at 1x (Z-DON per-texture density, src/libs/texture.cpp).

The skin is built at density 2 (every logical px = 2x2 physical). Most of its art is pixel chrome on
the logical grid, so many images are exact 2x2 blocks: halving them loses nothing. For each texture.json
entry whose PNG(s) are all exact 2x2 blocks (RGBA, every frame), the image is rewritten at half size and
the entry gets "density": 1; the engine then takes its size as logical and draws it point-filtered, so the
screen is pixel-identical and the texture needs a quarter of the memory and upload time.

Skipped: entries with a crop (crop rects are image pixels), stretched entries (x2 / y2), images under
MIN_AREA physical px, and entries already marked. Idempotent: a marked entry is never halved twice.
"""
import json
import os

import numpy as np
from PIL import Image

MIN_AREA = 256 * 256
# drawn by the engine at a sub-pixel x during play (A/B on the GOGO frame showed a seam point-filtered)
SKIP = {("game/lane", "1p_lane_cover"), ("game/lane", "2p_lane_cover"), ("game/lane", "dan_lane_cover"),
        ("game/lane", "ai_lane_cover")}


def _first(entry):
    if isinstance(entry, list):
        return entry[0] if entry and isinstance(entry[0], dict) else None
    return entry if isinstance(entry, dict) else None


def _frames(folder, name):
    single = os.path.join(folder, name + ".png")
    if os.path.isfile(single):
        return [single]
    d = os.path.join(folder, name)
    if os.path.isdir(d):
        return [os.path.join(d, f) for f in sorted(os.listdir(d)) if f.endswith(".png")]
    return []


def _half_if_blocky(path):
    """The half-size image if `path` is exact 2x2 blocks and big enough, else None."""
    im = Image.open(path)
    w, h = im.size
    if w % 2 or h % 2 or w * h < MIN_AREA:
        return None
    a = np.asarray(im.convert("RGBA"))
    q = a[::2, ::2]
    if not (np.array_equal(q, a[1::2, ::2]) and np.array_equal(q, a[::2, 1::2]) and
            np.array_equal(q, a[1::2, 1::2])):
        return None
    return Image.fromarray(q, "RGBA")


def dedupe_frames(out_dir):
    """Frame folders (0.png, 1.png, ...) keep each distinct image once, renumbered in first-use order, and
    the entry gets "frame_order" (the engine's own reorder, texture.cpp apply_frame_order: duplicates may
    repeat) mapping every original frame to its image: fewer files to open and decode, same frames on
    screen. Only dict entries (a list entry applies frame_order once per position)."""
    import hashlib
    graphics = os.path.join(out_dir, "Graphics")
    n_dirs = removed = 0
    for root, _dirs, files in os.walk(graphics):
        if "texture.json" not in files:
            continue
        tj = os.path.join(root, "texture.json")
        with open(tj, encoding="utf-8") as f:
            data = json.load(f)
        changed = False
        for name, entry in data.items():
            if not isinstance(entry, dict) or entry.get("crop"):
                continue
            d = os.path.join(root, name)
            if not os.path.isdir(d):
                continue
            pngs = [f for f in os.listdir(d) if f.endswith(".png")]
            if len(pngs) < 2 or not all(f[:-4].isdigit() for f in pngs) or \
                    len(pngs) != len(os.listdir(d)):
                continue
            pngs.sort(key=lambda f: int(f[:-4]))
            blobs = [open(os.path.join(d, f), "rb").read() for f in pngs]
            first_of, order = {}, []
            for b in blobs:
                h = hashlib.sha1(b).hexdigest()
                if h not in first_of:
                    first_of[h] = len(first_of)
                order.append(first_of[h])
            if len(first_of) == len(blobs):
                continue
            old_order = entry.get("frame_order")
            if old_order is not None:
                order = [order[int(i)] for i in old_order]
            uniq = {}
            for b in blobs:
                h = hashlib.sha1(b).hexdigest()
                uniq.setdefault(first_of[h], b)
            for f in pngs:
                os.remove(os.path.join(d, f))
            for i, b in uniq.items():
                with open(os.path.join(d, f"{i}.png"), "wb") as f:
                    f.write(b)
            entry["frame_order"] = order
            removed += len(blobs) - len(uniq)
            n_dirs += 1
            changed = True
        if changed:
            with open(tj, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
                f.write("\n")
    return n_dirs, removed


def run(out_dir, only=None):
    """only: a predicate on the texture.json folder (path relative to Graphics, "/"-separated), for A/B
    checks of a subset."""
    graphics = os.path.join(out_dir, "Graphics")
    n_tex = saved = 0
    for root, _dirs, files in os.walk(graphics):
        if "texture.json" not in files:
            continue
        if only is not None and not only(os.path.relpath(root, graphics).replace(os.sep, "/")):
            continue
        tj = os.path.join(root, "texture.json")
        with open(tj, encoding="utf-8") as f:
            data = json.load(f)
        changed = False
        for name, entry in data.items():
            first = _first(entry)
            # stretched entries (x2 / y2: the engine scales the image to a set size) stay 2x: point
            # filtering a stretch is not the same picture as the bilinear one
            if first is None or "density" in first or first.get("crop") or "x2" in first or "y2" in first:
                continue
            if (os.path.relpath(root, graphics).replace(os.sep, "/"), name) in SKIP:
                continue
            paths = _frames(root, name)
            if not paths:
                continue
            halves = []
            for p in paths:
                hi = _half_if_blocky(p)
                if hi is None:
                    break
                halves.append((p, hi))
            if len(halves) != len(paths):
                continue
            for p, hi in halves:
                w, h = hi.size
                saved += (4 * w * h) * 3          # RGBA bytes: the 2x image had 4x the pixels
                hi.save(p, optimize=True)
            first["density"] = 1
            changed = True
            n_tex += 1
        if changed:
            with open(tj, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
                f.write("\n")
    return n_tex, saved
