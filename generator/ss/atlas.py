"""Geometry plumbing through the ancestor chain, and the density conversion.

The skin's parent is YataiDONNijiiro (1920x1080), which inherits PyTaikoGreen (1280x720). The engine
resolves every texture key per subset from the nearest skin that ships it (texture.json entry plus
`<key>.png` or a `<key>/` frame folder): our skin, then Nijiiro (scale 1), then Green (scale 1.5).
This module mirrors that resolution so our replacements get exactly the geometry the engine would
have used:

  LOGICAL size/position = int(ancestor value x ancestor scale)   (the engine truncates the same way)
  PHYSICAL (our PNGs and our texture.json x/y/x2/y2/crop) = logical x style.D

Only geometry is read from the ancestors (sizes, crops, positions), never pixels, except `ref_bbox`
(where an ancestor's shape sits inside its frame, returned in logical px) for placement.

Quirk modelled from texture.cpp: a key that Nijiiro lists in its texture.json without shipping a
PNG only re-reads the numbers of Green's already loaded texture with scale 1, so it is drawn at
Green's raw pixel size; `resolve()` reports that as source "nijiiro-pos"."""
from __future__ import annotations

import json
import os
import shutil
from dataclasses import dataclass, field
from functools import lru_cache

from PIL import Image

from . import style
from .style import blank

SKINS = os.environ.get("SS_SKINS", r"D:/ClaudeWorks/TaikoSimulator/Z-DON/build/bin/Skins")
NIJIIRO = SKINS + "/YataiDONNijiiro"
GREEN = SKINS + "/PyTaikoGreen"
NIJIIRO_G = NIJIIRO + "/Graphics"
GREEN_G = GREEN + "/Graphics"
# nearest first: (name, Graphics dir, Scripts dir, scale into our 1920x1080 logical space)
ANCESTORS = [("nijiiro", NIJIIRO_G, NIJIIRO + "/Scripts", 1.0),
             ("green", GREEN_G, GREEN + "/Scripts", 1920 / 1280)]

# files written by this build run: {path: "crisp" | "smooth"}; tokens.scan_palette() reads it
WRITTEN: dict[str, str] = {}


def _first(v):
    return v[0] if isinstance(v, list) and v else v


@lru_cache(maxsize=None)
def anc_json(gdir: str, screen: str, subset: str) -> dict | None:
    p = f"{gdir}/{screen}/{subset}/texture.json"
    if not os.path.isfile(p):
        return None
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def _ships(gdir, screen, subset, key):
    """The engine's overridden_names(): a key counts only with <key>.png or a <key>/ folder."""
    d = f"{gdir}/{screen}/{subset}"
    return os.path.isfile(f"{d}/{key}.png") or os.path.isdir(f"{d}/{key}")


def _image_of(gdir, screen, subset, key, entry):
    """(kind, file path or frame paths) of the PNG(s) an ancestor entry loads, or None."""
    d = f"{gdir}/{screen}/{subset}"
    v = _first(entry)
    fo = v.get("file") if isinstance(v, dict) else None
    if fo:
        p = f"{d}/{fo}"
        return ("file", p) if os.path.isfile(p) else None
    if os.path.isdir(f"{d}/{key}"):
        frames = sorted((f for f in os.listdir(f"{d}/{key}") if f.endswith(".png")), key=lambda s: (len(s), s))
        return ("dir", [f"{d}/{key}/{f}" for f in frames])
    if os.path.isfile(f"{d}/{key}.png"):
        return ("file", f"{d}/{key}.png")
    return None


@lru_cache(maxsize=None)
def _img_size(path):
    with Image.open(path) as im:
        return im.size


def _crops(entry):
    v = _first(entry)
    c = v.get("crop") if isinstance(v, dict) else None
    return [tuple(r) for r in c] if c else None


@dataclass
class Geo:
    """Resolved geometry of one key. `frames` are LOGICAL (w, h) per frame."""
    screen: str
    subset: str
    key: str
    source: str                 # nijiiro | green | nijiiro-pos
    scale: float                # scale applied to the numbers of `entry`
    entry: object               # the ancestor's raw texture.json value
    kind: str                   # file | crops | dir
    frames: list = field(default_factory=list)
    names: list = field(default_factory=list)   # frame file names (dir) for our own frame folder
    path: str = ""              # ancestor image (file / crops) or first frame (dir)
    raw_crops: list | None = None
    img_scale: float = 1.0      # ancestor px -> logical for ref_bbox

    @property
    def size(self):
        return self.frames[0] if self.frames else (0, 0)


def lg(v, scale):
    """ancestor number -> logical int, exactly like the engine (static_cast<int>(v * scale))."""
    return max(0, int(v * scale)) if v >= 0 else int(v * scale)


@lru_cache(maxsize=None)
def resolve(screen: str, subset: str, key: str) -> Geo | None:
    """Geometry of `key` as the engine would load it from the ancestors (None if nobody has it)."""
    found = []
    for name, gdir, _, scale in ANCESTORS:
        j = anc_json(gdir, screen, subset)
        if j is None or key not in j:
            continue
        found.append((name, gdir, scale, j[key]))
    if not found:
        return None
    # nearest ancestor that actually ships the image wins the texture
    for i, (name, gdir, scale, entry) in enumerate(found):
        img = _image_of(gdir, screen, subset, key, entry)
        if img is None:
            continue
        g = _geo(screen, subset, key, name, scale, entry, img)
        # a nearer ancestor that only lists the key re-reads the numbers with its own scale
        if i > 0:
            n_name, _, n_scale, n_entry = found[0]
            g2 = _geo(screen, subset, key, n_name + "-pos", n_scale, n_entry, img,
                      fallback_crops=_crops(entry))
            g2.img_scale = n_scale
            return g2
        return g
    return None


def _geo(screen, subset, key, source, scale, entry, img, fallback_crops=None):
    kind, p = img
    crops = _crops(entry) or fallback_crops
    if kind == "dir":
        sizes = [_img_size(f) for f in p]
        frames = [(lg(w, scale), lg(h, scale)) for w, h in sizes]
        return Geo(screen, subset, key, source, scale, entry, "dir", frames,
                   [os.path.basename(f) for f in p], p[0] if p else "", None, scale)
    if crops:
        frames = [(lg(c[2], scale), lg(c[3], scale)) for c in crops]
        return Geo(screen, subset, key, source, scale, entry, "crops", frames, [], p, crops, scale)
    w, h = _img_size(p)
    return Geo(screen, subset, key, source, scale, entry, "file", [(lg(w, scale), lg(h, scale))], [], p,
               None, scale)


def subset_keys(screen, subset):
    """Every key any ancestor lists for a subset (nearest first order of appearance)."""
    keys = []
    for _, gdir, _, _ in ANCESTORS:
        j = anc_json(gdir, screen, subset)
        for k in (j or {}):
            if k not in keys:
                keys.append(k)
    return keys


def screens():
    out = set()
    for _, gdir, _, _ in ANCESTORS:
        for s in os.listdir(gdir):
            if os.path.isdir(f"{gdir}/{s}"):
                out.add(s)
    return sorted(out)


def subsets(screen):
    out = set()
    for _, gdir, _, _ in ANCESTORS:
        d = f"{gdir}/{screen}"
        if os.path.isdir(d):
            for s in os.listdir(d):
                if os.path.isfile(f"{d}/{s}/texture.json"):
                    out.add(s)
    return sorted(out)


@lru_cache(maxsize=None)
def ref_bbox(screen, subset, key, frame=0, thresh=128):
    """LOGICAL alpha bbox (frame-local) of the ancestor's art: where a shape sits in its frame."""
    g = resolve(screen, subset, key)
    if g is None:
        return None
    if g.kind == "dir":
        path, crop = os.path.join(os.path.dirname(g.path), g.names[frame]), None
    else:
        path, crop = g.path, (g.raw_crops[frame] if g.raw_crops else None)
    with Image.open(path) as im:
        im = im.convert("RGBA")
        if crop:
            x, y, w, h = crop
            im = im.crop((x, y, x + w, y + h))
        a = im.getchannel("A").point(lambda v: 255 if v >= thresh else 0)
        bb = a.getbbox()
    if bb is None:
        return None
    s = g.img_scale
    return tuple(int(v * s) for v in bb)


def to_phys_entry(entry, scale):
    """An ancestor texture.json value with x/y/x2/y2 turned into PHYSICAL px; 'file'/'crop' dropped
    (the writer sets its own)."""
    def conv(e):
        if not isinstance(e, dict):
            return e
        o = {}
        for k, v in e.items():
            if k in ("file", "crop"):
                continue
            if k in ("x", "y", "x2", "y2") and isinstance(v, (int, float)):
                o[k] = lg(v, scale) * style.D
            else:
                o[k] = v
        return o
    if isinstance(entry, list):
        return [conv(e) for e in entry]
    return conv(entry)


def phys_xy(e):
    """A logical {'x':..,'y':..,'x2':..,'y2':..} dict -> physical."""
    return {k: (int(round(v * style.D)) if k in ("x", "y", "x2", "y2") else v) for k, v in e.items()}


def _save(im, path, mode):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, optimize=True)
    WRITTEN[os.path.normpath(path)] = mode


def _check(im, w, h, what):
    W, H = style.px(w), style.px(h)
    if im.size != (W, H):
        raise ValueError(f"{what}: draw returned {im.size}, expected PHYSICAL {(W, H)} for logical {(w, h)}")
    return im


class SubsetWriter:
    """Replaces ancestor keys of one subset 1:1.

        w = SubsetWriter(ctx.G, "song_select", "box")
        w.put("box_bg", lambda i, n, w, h: my_image(w, h))   # w, h LOGICAL -> PHYSICAL image
        w.write()

    Every key is written as `<key>.png` (single image) or a `<key>/` frame folder (several frames, or
    an ancestor frame folder / crop strip). Frame folders sample each frame as a whole texture, so
    the engine's 1 px crop inset never blurs our pixel art. Pass layout="crops" to keep a crop strip
    (only needed if a script reads the crop rects themselves)."""

    GAP = 2   # phys px between crop-strip frames (the engine trims each crop by 1 px)

    def __init__(self, out_graphics: str, screen: str, subset: str):
        self.screen, self.subset = screen, subset
        self.dir = f"{out_graphics}/{screen}/{subset}"
        self.keys: dict[str, object] = {}
        self.out: dict[str, tuple] = {}      # key -> ("file", im) | ("dir", [(name, im)]) | ("crops", im)
        self.mode: dict[str, str] = {}

    def geo(self, key) -> Geo:
        g = resolve(self.screen, self.subset, key)
        if g is None:
            raise KeyError(f"{self.screen}/{self.subset}/{key}: no ancestor ships this key")
        return g

    def put(self, key, draw, entry=None, layout="auto", smooth=False):
        """draw(i, n, w, h) -> PHYSICAL RGBA image for frame i of n; w, h are LOGICAL.
        entry: a LOGICAL texture.json value to use instead of the ancestor's (x/y/x2/y2 converted).
        smooth=True marks the PNG as anti-aliased (notes/lane): the palette scan skips it."""
        g = self.geo(key)
        n = len(g.frames)
        ims = [_check(draw(i, n, w, h), w, h, f"{self.screen}/{self.subset}/{key}[{i}]")
               for i, (w, h) in enumerate(g.frames)]
        if entry is not None:
            e = [phys_xy(x) for x in entry] if isinstance(entry, list) else phys_xy(entry)
        else:
            e = to_phys_entry(g.entry, g.scale)
        if layout == "auto":
            layout = "file" if (g.kind == "file" and n == 1) else "dir"
        if layout == "file":
            self.out[key] = ("file", ims[0])
        elif layout == "dir":
            names = g.names if g.kind == "dir" else [f"{i}.png" for i in range(n)]
            self.out[key] = ("dir", list(zip(names, ims)))
        else:   # crops: one strip, our own physical crop rects
            W = sum(im.width for im in ims) + self.GAP * (n - 1)
            H = max(im.height for im in ims)
            strip = blank(W, H)
            crops, x = [], 0
            for im in ims:
                strip.alpha_composite(im, (x, 0))
                crops.append([x, 0, im.width, im.height])
                x += im.width + self.GAP
            self.out[key] = ("crops", strip)
            if isinstance(e, list):
                e = [dict(x) for x in e]
                e[0]["crop"] = crops
            else:
                e = dict(e)
                e["crop"] = crops
        self.keys[key] = e
        self.mode[key] = "smooth" if smooth else "crisp"

    def put_blank(self, key):
        self.put(key, lambda i, n, w, h: style.blank_l(w, h))

    def write(self):
        if os.path.isdir(self.dir):
            shutil.rmtree(self.dir)
        os.makedirs(self.dir)
        n = 0
        for key, (kind, data) in self.out.items():
            mode = self.mode[key]
            if kind in ("file", "crops"):
                _save(data, f"{self.dir}/{key}.png", mode)
                n += 1
            else:
                for f, im in data:
                    _save(im, f"{self.dir}/{key}/{f}", mode)
                    n += 1
        with open(f"{self.dir}/texture.json", "w", encoding="utf-8", newline="\n") as f:
            json.dump(self.keys, f, ensure_ascii=False, indent=2)
            f.write("\n")
        return n


class OwnSubset:
    """A subset no ancestor has (our own Lua draws it). Frames are PHYSICAL images; x/y LOGICAL.
    Several frames go into a `<key>/` frame folder (crisp: no crop inset); layout="crops" packs a
    strip with a 2 px gap instead."""

    def __init__(self, out_graphics: str, screen: str, subset: str):
        self.dir = f"{out_graphics}/{screen}/{subset}"
        self.keys: dict[str, tuple] = {}

    def add(self, key, frames, x=0, y=0, layout="auto", smooth=False):
        frames = list(frames)
        for f in frames:
            if f.width % style.D or f.height % style.D:
                raise ValueError(f"{key}: frame {f.size} is not a whole number of logical px")
        if layout == "auto":
            layout = "file" if len(frames) == 1 else "dir"
        self.keys[key] = (frames, {"x": x, "y": y}, layout, "smooth" if smooth else "crisp")

    def write(self):
        if os.path.isdir(self.dir):
            shutil.rmtree(self.dir)
        os.makedirs(self.dir)
        meta = {}
        for key, (frames, pos, layout, mode) in self.keys.items():
            entry = phys_xy(pos)
            if layout == "file":
                _save(frames[0], f"{self.dir}/{key}.png", mode)
            elif layout == "dir":
                for i, f in enumerate(frames):
                    _save(f, f"{self.dir}/{key}/{i}.png", mode)
            else:
                w = max(f.width for f in frames)
                h = max(f.height for f in frames)
                gap, n = 2, len(frames)
                atlas = blank(n * w + (n - 1) * gap, h)
                crops = []
                for i, f in enumerate(frames):
                    atlas.alpha_composite(f, (i * (w + gap), 0))
                    crops.append([i * (w + gap), 0, w, h])
                _save(atlas, f"{self.dir}/{key}.png", mode)
                entry["crop"] = crops
            meta[key] = entry
        with open(f"{self.dir}/texture.json", "w", encoding="utf-8", newline="\n") as f:
            json.dump(meta, f, ensure_ascii=False, indent=2)
            f.write("\n")
        return len(self.keys)


# ---------------------------------------------------------------- ancestor Lua
def ancestor_script(rel):
    """Path of the nearest ancestor's copy of Scripts/<rel> (Nijiiro first), or None."""
    for _, _, sdir, _ in ANCESTORS:
        p = os.path.join(sdir, rel)
        if os.path.isfile(p):
            return p
    return None
