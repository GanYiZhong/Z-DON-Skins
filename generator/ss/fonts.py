"""Fonts shipped with the skin: Fusion Pixel Font 12px proportional (SIL OFL 1.1), one file per
language variant, vendored unmodified in fonts_src/ with its licences.

The engine picks Fonts/font_<lang>.ttf, then font_<family>.ttf (zh->cn, zh_tw->tw, ko->kr, ja->jp),
then font.ttf (global_data.cpp load_skin), each looked up in the skin and then its parent. So:
  font.ttf     Fusion Pixel 12px, ja variant (default for ja and everything else)
  font_en.ttf  the same ja variant: Nijiiro ships a font_en.ttf (smooth), which would win for en otherwise
  font_tw.ttf  zh_tw variant (Traditional Chinese glyph forms)
  font_cn.ttf  zh_hans variant (Simplified Chinese)
  font_kr.ttf  ko variant
The baked textures use the same files (style.font), so in-texture and engine text match."""
from __future__ import annotations

import os
import shutil

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(HERE, "fonts_src")
PIXEL_PX = 12   # design grid of the font: render at multiples of this for crisp pixels

# out name -> source file in fonts_src
FONTS = {
    "font.ttf": "fusion-pixel-12px-proportional-ja.ttf",
    # en: the engine tries Fonts/font_en.ttf first, in this skin AND its parents; Nijiiro ships one (a
    # smooth display font), so without our own copy English text would use Nijiiro's font
    "font_en.ttf": "fusion-pixel-12px-proportional-ja.ttf",
    "font_tw.ttf": "fusion-pixel-12px-proportional-zh_tw.ttf",
    "font_cn.ttf": "fusion-pixel-12px-proportional-zh_hans.ttf",
    "font_kr.ttf": "fusion-pixel-12px-proportional-ko.ttf",
}


def path(lang="ja"):
    return os.path.join(SRC, FONTS.get({"ja": "font.ttf", "tw": "font_tw.ttf", "cn": "font_cn.ttf",
                                         "kr": "font_kr.ttf"}.get(lang, "font.ttf")))


def _glyph_key(font, gname):
    """What a glyph looks like and how it advances: outline points, contour ends, flags, metrics."""
    g = font["glyf"][gname]
    if g.isComposite():
        g = font["glyf"][gname]    # composites compared by their components below
        comps = tuple((c.glyphName, c.x, c.y) for c in g.components)
        return ("c", comps, font["hmtx"][gname])
    if g.numberOfContours == 0:
        return ("e", font["hmtx"][gname])
    return ("s", tuple(g.coordinates), tuple(g.endPtsOfContours), bytes(g.flags), font["hmtx"][gname])


def write_overlay(base_path, lang_path, out_path):
    """The language font with only the codepoints whose glyph differs from the base font's (outline or
    metrics) or that the base lacks: Z-DON (screen.font_base) draws every other codepoint from the base,
    so no glyph is lost. Vertical metrics must match the base (one raster scale for both)."""
    from fontTools import subset
    from fontTools.ttLib import TTFont
    base, lang = TTFont(base_path), TTFont(lang_path)
    for t, k in (("head", "unitsPerEm"), ("hhea", "ascent"), ("hhea", "descent"), ("hhea", "lineGap")):
        if getattr(base[t], k) != getattr(lang[t], k):
            raise SystemExit(f"fonts: {lang_path} {t}.{k} differs from the base font: no overlay")
    bmap, lmap = base.getBestCmap(), lang.getBestCmap()
    keep = [cp for cp, g in lmap.items() if cp not in bmap or _glyph_key(lang, g) != _glyph_key(base, bmap[cp])]
    opts = subset.Options()
    opts.layout_features = []
    opts.notdef_outline = True
    opts.name_IDs = ["*"]
    opts.name_languages = ["*"]
    opts.glyph_names = False
    opts.drop_tables += ["vhea", "vmtx", "GSUB", "GPOS"]
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=keep)
    sub.subset(lang)
    for t, k in (("hhea", "ascent"), ("hhea", "descent"), ("head", "unitsPerEm")):
        assert getattr(base[t], k) == getattr(lang[t], k), (out_path, t, k)
    lang.save(out_path)
    return len(keep)


def install(fonts_dir, cache_dir=None, jp_path=None, zdon=False):
    """zdon (the density-2 build, Z-DON only): no font_en.ttf (Z-DON looks for every font candidate in the
    skin itself before its parents, so English falls to our font.ttf), and font_tw / cn / kr are overlays
    on font.ttf (skin_config screen.font_base): only the glyphs that differ from the ja variant."""
    os.makedirs(fonts_dir, exist_ok=True)
    base_src = os.path.join(SRC, FONTS["font.ttf"])
    for name, src in FONTS.items():
        if zdon and name == "font_en.ttf":
            continue
        if zdon and name in ("font_tw.ttf", "font_cn.ttf", "font_kr.ttf"):
            write_overlay(base_src, os.path.join(SRC, src), os.path.join(fonts_dir, name))
            continue
        shutil.copy2(os.path.join(SRC, src), os.path.join(fonts_dir, name))
    lic = os.path.join(fonts_dir, "LICENSES")
    if os.path.isdir(lic):
        shutil.rmtree(lic)
    shutil.copytree(os.path.join(SRC, "LICENSES"), lic)
    with open(os.path.join(SRC, "OFL.txt"), encoding="utf-8") as f:
        body = f.read()
    head = ["Fonts in this folder: Fusion Pixel Font 12px proportional (https://github.com/TakWolf/fusion-pixel-font),",
            "release 2026.10.25, licensed under the SIL Open Font License, Version 1.1."]
    if zdon:
        head += ["font.ttf is unmodified (only renamed). font_tw.ttf, font_cn.ttf and font_kr.ttf are Modified",
                 "Versions: each keeps only the glyphs that differ from font.ttf (the engine draws every other",
                 "glyph from font.ttf), with the layout and vertical-metrics tables removed. No glyph was redrawn.", ""]
        head += [f"  {name} <- {src}" for name, src in FONTS.items() if name != "font_en.ttf"]
    else:
        head += ["Files are unmodified and only renamed so the engine finds them:", ""]
        head += [f"  {name} = {src}" for name, src in FONTS.items()]
    head += ["", "Glyph sources bundled by Fusion Pixel Font keep their own licences in LICENSES/.",
             "The full licence text follows.", "", ""]
    with open(os.path.join(fonts_dir, "OFL.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(head) + body)
