"""The skin's two characters, pixel art only (ss/pixel.py): Momo (1P / main) and Hoshi (buddy / 2P).

Size is always a whole sprite scale k, in LOGICAL px per sprite px (k*D phys), chosen BY ROLE
(sprite/sized/paste accept the role name: paste(cv, "momo", "idle", "scene", cx, foot)):
  MASCOT_K = {"tiny": 3, "menu": 6, "portrait": 6, "scene": 9}  ->  6 / 12 / 18 phys at D=2.
A sprite is 34 x 34 cells, so its frame is 34*k logical px. The ground line is frame row
FOOT[char]*k (Momo 33, Hoshi 34): sized()/paste() and the Lua Mascot put that row on the floor.
Never resize a sprite with a filter, never rotate or squash it: motion = hop by whole sprite px
or swap frames (bible 2.6/2.7)."""
from __future__ import annotations

from PIL import Image

from . import pixel, style
from .style import K_ALLOWED, MASCOT_K, blank  # noqa: F401  (MASCOT_K re-exported)

EXPR = pixel.EXPR
CHARS = {"M": "momo", "H": "hoshi", "momo": "momo", "hoshi": "hoshi", "robo": "robo"}
MAIN, BUDDY = "momo", "hoshi"
N = pixel.N
FOOT = pixel.FOOT      # canvas row each character stands on (momo 33, hoshi 34)


def char_of(c):
    return CHARS[c]


def k_of(k):
    """A role name ("tiny" | "menu" | "portrait" | "scene", see MASCOT_K) or a raw k -> logical k.
    Prefer roles: the k per role is the one rule every screen shares."""
    if isinstance(k, str):
        if k not in MASCOT_K:
            raise ValueError(f"mascot role {k!r} not in {sorted(MASCOT_K)}")
        return MASCOT_K[k]
    return k


def check_k(k):
    k = k_of(k)
    if k not in K_ALLOWED:
        raise ValueError(f"mascot k={k} not in {K_ALLOWED} (logical px per sprite px; bible: 6/12/18 phys)")


def sprite(char, expr="idle", k=6, mirror=False, outfit=None) -> Image.Image:
    """PHYSICAL image of one frame: 34*k logical = 34*k*D phys px, crisp. outfit: a pixel.OUTFITS id."""
    k = k_of(k)
    check_k(k)
    im = pixel.sprite(char_of(char), expr, 0, k * style.D, outfit=outfit)
    return im.transpose(Image.FLIP_LEFT_RIGHT) if mirror else im


def sized(char, expr, k, w=None, h=None, mirror=False) -> Image.Image:
    """A sprite at scale k centred on a w x h LOGICAL tile (default 34k square), its ground row on the
    tile's bottom edge (Momo's frame is then shifted down by 1 sprite px; nothing is clipped since her
    last row is empty). Returns a PHYSICAL image."""
    k = k_of(k)
    im = sprite(char, expr, k, mirror)
    S = N * k
    w, h = w or S, h or S
    if w < S or h < S:
        raise ValueError(f"tile {w}x{h} smaller than the k={k} sprite ({S})")
    out = blank(style.px(w), style.px(h))
    out.alpha_composite(im, (style.px((w - S) // 2), style.px(h - FOOT[char_of(char)] * k)))
    return out


def paste(cv, char, expr, k, cx, foot, mirror=False):
    """Draw a sprite on a crisp Canvas, centred on logical cx with the frame bottom on `foot`
    (positions floored to whole logical px, so sprite px stay whole). k: a role name or a raw k."""
    k = k_of(k)
    S = N * k
    cv.paste(sprite(char, expr, k, mirror), int(cx - S // 2), int(foot - FOOT[char_of(char)] * k))


def frames_sheet(path, k=6):
    """Review sheet: every frame of both characters at k, labelled (mockups/v2_mascot_frames.png)."""
    from .style import C, Canvas
    S = N * k
    pad = 12
    cols = len(EXPR)
    W = cols * (S + pad) + pad
    H = 2 * (S + pad + 30) + pad + 36
    cv = Canvas(W, H, bg=C["bg0"])
    cv.text(pad, 21, f"Momo / Hoshi frames, k={k} logical ({k * style.D} phys px per sprite px)", 24,
            C["ink"], anchor="lm")
    for r, ch in enumerate((MAIN, BUDDY)):
        y0 = 42 + r * (S + pad + 30)
        for i, e in enumerate(EXPR):
            x0 = pad + i * (S + pad)
            cv.rect(x0, y0 + S, x0 + S, y0 + S + 3, C["line"])          # floor line under the feet
            cv.paste(sprite(ch, e, k), x0, y0 + S - FOOT[ch] * k)
            cv.text(x0 + S / 2, y0 + S + 15, e, 18, C["text2"])
    cv.result().save(path)
