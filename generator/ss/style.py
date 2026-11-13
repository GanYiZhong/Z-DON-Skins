"""SimpleStyle v2 palette, grid and Canvas.

Units (see SCREEN_GUIDE_V2.md):
  * LOGICAL px: Nijiiro's 1920x1080 design space. Every coordinate a module passes is logical.
  * PHYSICAL px: what the PNGs hold, logical x density (`D`, 2 for the 4K build, 1 for 1080p).
  * U = 3 logical (6 phys at D=2) is the chrome unit: every chrome coordinate, border, shadow,
    notch and gap is a multiple of U.

Two Canvas paths:
  * crisp (ss=1, the default): drawn straight onto the physical grid with no anti-aliasing.
    All pixel chrome, pixel text, sprites and decoration use this. Chrome helpers refuse ss>1.
  * smooth (ss=SS): supersampled and LANCZOS-downscaled; only for the flat notes, roll bodies
    and the lane (user decision: those stay flat and smooth).

Nothing is copied from another skin; only geometry (frame sizes, positions) follows the parents.
"""
from __future__ import annotations

import math
import os
from functools import lru_cache

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SS = 4          # supersampling factor of the smooth path (notes / lane only)
D = 2           # texture density: physical px per logical px (build.py --density)
U = 3           # chrome unit in LOGICAL px (6 phys at D=2)
TEXT_SIZES = (18, 24, 36, 48)   # the only logical text sizes (Fusion Pixel 12 px font at x1.5/x2/x3/x4)
MASCOT_K = {"tiny": 3, "menu": 6, "portrait": 6, "scene": 9}   # logical px per sprite px (6/12/18 phys)
# Engine text (skin_config font_size, text.create_raw_text / create_text size) for each text role: the
# engine (raylib LoadFontData) scales the font so ascent+descent = size, i.e. the em is 0.75 x size for
# Fusion Pixel (1600 / 1200 units). So engine size = role x 4/3: 24/32/48/64 render exactly like baked
# 18/24/36/48 (3/4/6/8 phys px per font px at D=2). Any other engine size gives uneven font pixels.
# Owner 10-30 (text hard to read on a 1440p screen: the 4K frame is shown at 2/3): the smallest role is
# drawn at the 24 size everywhere. Role 18 stays as a name (layout code still asks for it) but renders,
# measures and sizes engine text exactly like 24.
MIN_TEXT = 24
ENGINE_TEXT = {18: 32, 24: 32, 36: 48, 48: 64}
K_ALLOWED = (3, 6, 9)
DEBUG = os.environ.get("SS_DEBUG", "") not in ("", "0")   # off-grid chrome raises instead of snapping


def set_density(d: int):
    global D
    if d not in (1, 2):
        raise SystemExit(f"--density must be 1 or 2, got {d}")
    D = d


def px(v) -> int:
    """logical -> physical (rounded)."""
    return int(round(v * D))


def on_grid(v, unit=U) -> bool:
    return abs(v / unit - round(v / unit)) < 1e-6


def snap(v, unit=U) -> int:
    """Nearest multiple of `unit` (logical). With SS_DEBUG=1 an off-grid value raises instead."""
    if DEBUG and not on_grid(v, unit):
        raise ValueError(f"off-grid value {v} (unit {unit})")
    return int(round(v / unit) * unit)


# ---------------------------------------------------------------- palette
def hexc(h: str, a: int = 255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


P = {
    # neutrals (light "paper" theme, 8-bit UI; notes and lane stay flat)
    "bg0": "#FFF6E5",      # screen background (cream paper)
    "bg1": "#FFFFFF",      # panels / windows
    "bg2": "#F2E8D5",      # lane, raised cards, buttons
    "bg3": "#E9DAC0",      # chips, grooves
    "line": "#D2BFA2",     # hairline dividers (decoration)
    "mute": "#8C7B82",     # tertiary text, inactive (large text only)
    "text2": "#6A5862",    # secondary text
    "text": "#3A2633",     # primary text (ink)
    "ink": "#3A2633",      # 8-bit outlines and hard shadows
    "paper": "#FFFFFF",    # white: note rims, highlights
    "sky": "#BFE6F7",      # sky band
    "pink": "#F7A8BE",     # Momo
    "mint": "#D9EBCB",     # Momo's belly / soft green chips
    # scene (house horizon + festival stage); every decoration colour is a token so the scan sees it
    "cloud2": "#DFF0FA",   # underside row of a pixel cloud
    "grass": "#4FAE5E",
    "grass2": "#388C48",
    "wood": "#C98E5E",     # taiko barrel, stand
    "wood2": "#9A6440",
    # gameplay sky (v2_stage "stagelux"): stepped dither gradient, distant town, GOGO dusk
    "sky_hi": "#8ECBEA",   # top of the day sky
    "sky_mid": "#A6D8F0",  # middle band; also the far mountains by day
    "haze2": "#86BAD8",    # the distant town silhouette by day
    "glow": "#FCE6C4",     # warm horizon once the gauge is over the clear line; GOGO horizon
    "dusk0": "#7376C1",    # GOGO dusk sky, top
    "dusk1": "#9A84CA",    # GOGO dusk, middle band; the mountains at dusk
    "dusk2": "#DB95B9",    # GOGO dusk, low band; cloud tops at dusk
    "dusk_t": "#5E4F8C",   # the town silhouette at dusk
    # text-strength accents (accent hues darkened to pass 4.5:1 on paper/cream/chips)
    "gold_t": "#7E4F00",
    "blue_t": "#1F5E9E",
    "red_t": "#B32D25",
    # notes (flat)
    "don": "#E8453A",
    "ka": "#2F86D6",
    "roll": "#F5B21E",
    "balloon": "#F07A2A",
    "kusu": "#F5B21E",
    # judgements
    "good": "#7E4F00",
    "ok": "#6A5862",
    "bad": "#2F6FB0",
    # gauge
    "p1": "#E8453A",
    "p2": "#2F86D6",
    "clear": "#F5B21E",
    # difficulty accents
    "easy": "#F2A93B",
    "normal": "#4FAE5E",
    "hard": "#5BA3E6",
    "oni": "#EC6AA3",
    "ura": "#8A5BE0",
    "tower": "#C98E5E",
    "dan": "#D9B23F",
    # branches
    "br_normal": "#8C7B82",
    "br_expert": "#2F86D6",
    "br_master": "#E2508F",
    # gogo
    "gogo": "#F07A2A",
    # play lane (owner 10-29: a grey lane like the arcade / Nijiiro, not the cream band)
    "lane": "#4B484C",     # note band
    "lane_hi": "#625E63",  # hit-circle big-note ring on the band
    "lane2": "#C3BFC2",    # moji strip under the band (ink note names)
    # song_info/genre template: the engine's colortransform shader maps exactly this colour to the
    # song's genre colour (song_info.cpp GENRE_PLATE_TEMPLATE_COLOR); never shown as itself
    "genre_tpl": "#3C6700",
}
# Role tokens that the light theme draws with ink / paper, split out so the dark theme can colour them on
# their own (in the light theme they equal ink / paper, so the light build is unchanged):
#   shade    hard drop shadows (dark in both themes)
#   on_acc   text and outlines ON a bright accent fill (course chips)
#   focus    the focused button and dialog title band fill (gold in light; deep amber with light text in dark)
#   hint_bg  the control-hint bar
#   n_ink / n_rim  the notes' outline and white rim (notes look the same in both themes)
P.update({"focus": P["clear"], "cloud": P["paper"], "star": P["sky"], "star2": P["sky"], "shade": P["ink"], "on_acc": P["ink"], "hint_bg": P["ink"], "n_ink": P["ink"], "n_rim": P["paper"]})

THEME = os.environ.get("SS_THEME", "light")
# YataiDONSimpleStyleDark: a night version. ink and paper swap roles: windows are dark (paper), their
# borders and the text on them light (ink / text); shadows stay dark (shade); accents keep their hues.
DARK = {
    "bg0": "#1B1724",      # screen background (night)
    "bg1": "#2C2638",
    "paper": "#2C2638",    # windows / panels
    "bg2": "#3A3348",      # raised cards, buttons
    "bg3": "#4A4259",      # chips, grooves
    "line": "#A096B4",     # dividers
    "mute": "#A99CB4",
    "text2": "#D2C7DA",
    "text": "#F6F0F8",
    "ink": "#EEE6F2",      # borders, outlines, ink text: light
    "shade": "#0B0910",    # hard shadows
    "on_acc": "#241C2C",   # dark text on gold / course chips
    "focus": "#8A5A0C",    # focused buttons and dialog title bands: deep amber under light text
    "hint_bg": "#0B0910",
    "n_ink": "#3A2633",
    "n_rim": "#FFFFFF",
    "sky": "#22305A",      # the sky band at night
    "cloud": "#3B4A80",    # pixel clouds at night
    "cloud2": "#2E3D6E",
    "star": "#F6F0F8",     # stars in the night sky band (the light theme draws none)
    "star2": "#F7C65A",
    "grass": "#2F7A3F",
    "grass2": "#225C2F",
    "wood": "#9A6A45",
    "wood2": "#6E4730",
    "sky_hi": "#0F1736",
    "sky_mid": "#1A2650",
    "haze2": "#2A3868",
    "glow": "#5B4A7E",
    "dusk0": "#2E2C66",
    "dusk1": "#4B3F80",
    "dusk2": "#7A4F80",
    "dusk_t": "#1E1A40",
    "gold_t": "#F7C65A",
    "blue_t": "#8CC4F5",
    "red_t": "#FF8E86",
    "good": "#F7C65A",
    "ok": "#D2C7DA",
    "bad": "#8CC4F5",
    "lane2": "#34303A",    # moji strip: light note names on dark
}
if THEME == "dark":
    P.update(DARK)
elif THEME != "light":
    raise SystemExit(f"SS_THEME must be light or dark, got {THEME!r}")
C = {k: hexc(v) for k, v in P.items()}


def alpha(c, a):
    return (c[0], c[1], c[2], int(a))


def mix(c1, c2, t):
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(4))


# ---------------------------------------------------------------- fonts
# Fusion Pixel Font 12px (OFL), the same file the engine uses (ss/fonts.py). One weight.
# Logical sizes 18/24/36/48 = 36/48/72/96 phys at D=2: every font pixel is 3/4/6/8 whole phys px.
PIXEL_PX = 12
FONT_PIXEL = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "fonts_src",
                          "fusion-pixel-12px-proportional-ja.ttf")


def phys_font_px(size: float) -> int:
    """Physical pixel size for a logical text size: a whole multiple of the 12 px font grid (never below
    the MIN_TEXT role)."""
    size = max(size, MIN_TEXT)
    return max(PIXEL_PX, PIXEL_PX * int(round(size * D / PIXEL_PX)))


@lru_cache(maxsize=None)
def font_phys(size_px: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_PIXEL, int(size_px))


def font(size: float, weight: int = 700) -> ImageFont.FreeTypeFont:
    """The pixel font at a LOGICAL size (rendered at its physical size)."""
    return font_phys(phys_font_px(size))


_WARNED = set()


def check_text_size(size):
    """Text is 18/24/36/48 logical only (bible 2.1/2.5). Raises with SS_DEBUG=1, else warns once."""
    if size not in TEXT_SIZES:
        msg = f"text size {size} is not one of {TEXT_SIZES}"
        if DEBUG:
            raise ValueError(msg)
        if size not in _WARNED:
            _WARNED.add(size)
            print("warning:", msg)


def text_mask(s: str, size: float, outline: float = 0):
    """Crisp 1-bit text as L masks (no anti-aliasing): (fill mask, fill+outline mask, outline phys px).
    The text origin inside the masks is (o, o).
    `outline` is LOGICAL (1U = 3 -> a square ring of 6 phys px at D=2)."""
    f = font(size)
    o = px(outline)
    asc, desc = f.getmetrics()
    w = int(math.ceil(f.getlength(s))) + 2 * o + 2
    h = asc + desc + 2 * o
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.fontmode = "1"
    d.text((o, o), s, font=f, fill=255)
    if o:
        ring = m.filter(ImageFilter.MaxFilter(2 * o + 1))
    else:
        ring = m
    return m, ring, o


# ---------------------------------------------------------------- canvas
class Canvas:
    """RGBA canvas in LOGICAL units whose result is PHYSICAL (x D).

    ss=1 (default): crisp, drawn on the physical pixel grid (round(v*D)). Use for everything 8-bit.
    ss=SS: smooth supersampled path, LANCZOS-downscaled in result(). Notes / lane only."""

    def __init__(self, w, h, bg=(0, 0, 0, 0), ss: int = 1):
        self.w, self.h, self.ss = w, h, ss
        self.k = D * ss                      # image px per logical px
        self.W, self.H = px(w), px(h)        # physical result size
        self.im = Image.new("RGBA", (self.W * ss, self.H * ss), bg)
        self.d = ImageDraw.Draw(self.im)

    @property
    def crisp(self):
        return self.ss == 1

    def _v(self, v):
        return int(round(v * self.k)) if self.crisp else v * self.k

    def _s(self, *v):
        return [self._v(x) for x in v]

    # basic shapes (x1/y1 are EXCLUSIVE edges: rect(0,0,3,3) covers 3x3 logical px) -------------
    def rect(self, x0, y0, x1, y1, fill):
        X0, Y0, X1, Y1 = self._s(x0, y0, x1, y1)
        if X1 <= X0 or Y1 <= Y0:
            return
        if self.crisp:
            self.d.rectangle((X0, Y0, X1 - 1, Y1 - 1), fill=fill)
        else:
            self.d.rectangle((X0, Y0, X1, Y1), fill=fill)

    def prect(self, X0, Y0, X1, Y1, fill):
        """Rectangle in PHYSICAL px of the result (exclusive edges); crisp canvases only."""
        assert self.crisp
        if X1 > X0 and Y1 > Y0:
            self.d.rectangle((X0, Y0, X1 - 1, Y1 - 1), fill=fill)

    def rrect(self, x0, y0, x1, y1, r, fill=None, outline=None, width=0):
        self.d.rounded_rectangle(self._s(x0, y0, x1, y1), radius=r * self.k, fill=fill,
                                 outline=outline, width=int(round(width * self.k)))

    def circle(self, cx, cy, r, fill=None, outline=None, width=0):
        self.d.ellipse(self._s(cx - r, cy - r, cx + r, cy + r), fill=fill, outline=outline,
                       width=int(round(width * self.k)))

    def ring(self, cx, cy, r_out, r_in, fill):
        """Annulus drawn as a separate layer so it never erases what is below."""
        layer = Image.new("L", self.im.size, 0)
        dl = ImageDraw.Draw(layer)
        dl.ellipse(self._s(cx - r_out, cy - r_out, cx + r_out, cy + r_out), fill=255)
        dl.ellipse(self._s(cx - r_in, cy - r_in, cx + r_in, cy + r_in), fill=0)
        self.paint(layer, fill)

    def arc(self, cx, cy, r, start, end, fill, width):
        self.d.arc(self._s(cx - r, cy - r, cx + r, cy + r), start, end, fill=fill,
                   width=int(round(width * self.k)))

    def pieslice(self, cx, cy, r, start, end, fill):
        self.d.pieslice(self._s(cx - r, cy - r, cx + r, cy + r), start, end, fill=fill)

    def poly(self, pts, fill):
        self.d.polygon([(self._v(x), self._v(y)) for x, y in pts], fill=fill)

    def line(self, pts, fill, width):
        self.d.line([(self._v(x), self._v(y)) for x, y in pts], fill=fill,
                    width=max(1, int(round(width * self.k))), joint="curve")

    def capsule(self, x0, y0, x1, y1, fill):
        r = min(x1 - x0, y1 - y0) / 2
        self.rrect(x0, y0, x1, y1, r, fill=fill)

    def paint(self, mask: Image.Image, color):
        """Composite `color` through an L mask of canvas size."""
        solid = Image.new("RGBA", self.im.size, color[:3] + (255,))
        a = mask if color[3] == 255 else mask.point(lambda v: v * color[3] // 255)
        solid.putalpha(a)
        self.im.alpha_composite(solid)

    def mask(self):
        m = Image.new("L", self.im.size, 0)
        return m, ImageDraw.Draw(m)

    def paste(self, im: Image.Image, x, y):
        """Alpha-composite a PHYSICAL image at logical (x, y) (crisp: snapped to a whole phys px)."""
        assert self.crisp, "paste() of pixel art needs a crisp canvas"
        self.im.alpha_composite(im, (int(round(x * D)), int(round(y * D))))

    # text (crisp pixel font) --------------------------------------------------------------
    def text(self, x, y, s, size, fill, anchor="mm", outline=0, outline_fill=None, max_w=None, **_):
        """Pixel text at a LOGICAL size (18/24/36/48). The glyph box is snapped to whole phys px and
        drawn 1-bit, so every font pixel is a whole number of physical px. `outline` (logical, 1U = 3)
        is a square ink ring, never a soft stroke. max_w shrinks by whole grid steps (24 -> 18)."""
        if not self.crisp:
            raise ValueError("Canvas.text needs a crisp canvas (ss=1)")
        check_text_size(size)
        if max_w is not None:
            sizes = [t for t in TEXT_SIZES if t <= size][::-1] or [size]
            for t in sizes:
                size = t
                if self.text_width(s, t) <= max_w:
                    break
        m, ring, o = text_mask(s, size, outline)
        f = font(size)
        asc, desc = f.getmetrics()
        tw = int(math.ceil(f.getlength(s)))
        th = asc + desc
        X, Y = x * D, y * D
        ax, ay = anchor[0], anchor[1]
        X -= {"l": 0, "m": tw / 2, "r": tw}[ax]
        # vertical: "m" centres the em box (ascent+descent), "t" top, "b" bottom, "s" baseline
        Y -= {"t": 0, "m": th / 2, "b": th, "s": asc}[ay]
        X, Y = int(round(X)) - o, int(round(Y)) - o
        if o:
            col = Image.new("RGBA", ring.size, (outline_fill or C["ink"])[:3] + (255,))
            col.putalpha(ring)
            self._comp(col, X, Y)
        col = Image.new("RGBA", m.size, fill[:3] + (255,))
        col.putalpha(m if fill[3] == 255 else m.point(lambda v: v * fill[3] // 255))
        self._comp(col, X, Y)

    def _comp(self, im, X, Y):
        """alpha_composite that tolerates negative offsets (crops the source)."""
        sx, sy = max(0, -X), max(0, -Y)
        if sx or sy:
            im = im.crop((sx, sy, im.width, im.height))
        self.im.alpha_composite(im, (max(0, X), max(0, Y)))

    def text_width(self, s, size, *_a, **_k) -> float:
        """Advance width in LOGICAL px."""
        return font(size).getlength(s) / D

    # finish -----------------------------------------------------------
    def result(self) -> Image.Image:
        if self.crisp:
            return self.im.copy()
        return self.im.resize((self.W, self.H), Image.LANCZOS)


def blank(w, h):
    """A transparent PHYSICAL image of w x h phys px."""
    return Image.new("RGBA", (int(w), int(h)), (0, 0, 0, 0))


def blank_l(w, h):
    """A transparent image for a LOGICAL w x h frame (physical size)."""
    return blank(px(w), px(h))


def lerp(a, b, t):
    return a + (b - a) * t


# ---------------------------------------------------------------- shared constants
COURSES = [("easy", "かんたん", "Easy"), ("normal", "ふつう", "Normal"), ("hard", "むずかしい", "Hard"),
           ("oni", "おに", "Oni"), ("ura", "おに(裏)", "Ura"), ("tower", "タワー", "Tower"), ("dan", "段位", "Dan")]
