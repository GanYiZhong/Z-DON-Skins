"""8-bit pixel-art mascots: "Momo" (pink rabbit plush, 1P / main) and "Hoshi" (husky in a grey hoodie,
buddy / 2P). The user's own plush toys.

Each sprite is drawn on a 32x32 design grid (inside a 34x34 canvas with a 1-cell margin) with integer
shapes, auto-outlined, then scaled with NEAREST by a whole factor k (sprite px -> image px).
Palette characters:
  . transparent   K outline   E eye/nose (near black)   W white   B blush / tongue
  P/p rabbit pink / shade   I inner ear   G/g belly mint / shade
  H/h hoodie grey / shade   F face white   M husky mask grey   Y/y horn yellow / bachi wood
  Z zipper   T tear / sweat

Frames (EXPR; the first eight keep their v1 indices):
  idle idle1 (breathe: body 1 row lower, arms 1 lower, head + feet fixed)
  blink blink_half (lid row K over the eye row)
  good combo sad gogo clear fail
  drum_l drum_r (holding two bachi: one arm raised to ear height, stick 45 deg up; the other down,
                 tip at the bottom edge; Hoshi's horn dips 1 px)
  cheer (both arms straight up, mouth open 3x2 with a tongue row, ears/horn 1 px up)
  turn (3/4 view facing right: face 3 px right, far ear without inner colour, Hoshi's zipper 2 px off
        centre; mirror at runtime to face left)
  sad / fail / sit_fail: Momo keeps her tall ears, laid back ~40 deg outward (her silhouette)
  sit_fail (seated: head 3 rows lower, a taller seated body, legs forward showing the soles, x x eyes,
            a 2x3 sweat drop top-right; 3 rows taller than the v2.0 bean so it reads at k=9)
"""
from __future__ import annotations

from PIL import Image

from .style import hexc

N = 34          # canvas: the 32x32 drawing area plus a 1-cell margin so outlines never clip
M = 1           # margin: drawing coordinates are shifted by this many cells

PAL = {
    "K": hexc("#3A2633"), "E": hexc("#221A20"), "W": hexc("#FFFFFF"), "B": hexc("#FF8FA8"),
    "P": hexc("#F7A8BE"), "p": hexc("#E2849F"), "I": hexc("#FFD3DE"),
    "G": hexc("#D9EBCB"), "g": hexc("#B9D3A8"),
    "H": hexc("#AEB4BE"), "h": hexc("#8B929E"), "F": hexc("#FAFAF7"), "M": hexc("#6F7782"),
    "Y": hexc("#FFD23F"), "y": hexc("#E0A81E"), "Z": hexc("#D7DBE2"), "T": hexc("#7CC6F2"),
}

EXPR = ["idle", "blink", "good", "combo", "sad", "gogo", "clear", "fail",
        "idle1", "blink_half", "drum_l", "drum_r", "cheer", "turn", "sit_fail"]

# expression -> (face, pose overrides)
POSES = {
    "idle": ("idle", {}),
    "blink": ("blink", {}),
    "good": ("good", {}),
    "combo": ("combo", {}),
    "sad": ("sad", {}),
    "gogo": ("gogo", {}),
    "clear": ("clear", {}),
    "fail": ("fail", {}),
    "idle1": ("idle", {"body_dy": 1}),
    "blink_half": ("blink_half", {}),
    "drum_l": ("drum", {"arms": "drum", "side": -1}),
    "drum_r": ("drum", {"arms": "drum", "side": 1}),
    "cheer": ("cheer", {"arms": "cheer", "ear_dy": -1}),
    "turn": ("idle", {"turn": 1}),
    "sit_fail": ("fail", {"sit": 3}),
}


class Grid:
    """N x N cells; drawing calls use 32x32 design coordinates, offset by the margin M."""

    def __init__(self, n=N):
        self.n = n
        self.g = [["."] * n for _ in range(n)]

    def px(self, x, y, c):
        x, y = x + M, y + M
        if 0 <= x < self.n and 0 <= y < self.n:
            self.g[y][x] = c

    def get(self, x, y):
        x, y = x + M, y + M
        return self.g[y][x] if 0 <= x < self.n and 0 <= y < self.n else "."

    def ell(self, cx, cy, rx, ry, c, only=None):
        cx, cy = cx + M, cy + M
        for y in range(self.n):
            for x in range(self.n):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    if only is None or self.g[y][x] in only:
                        self.g[y][x] = c

    def ell_rot(self, cx, cy, rx, ry, ang, c):
        """Ellipse with its ry axis tilted by `ang` degrees (positive = top leans right)."""
        import math
        ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
        cx, cy = cx + M, cy + M
        for y in range(self.n):
            for x in range(self.n):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                u, v = dx * ca + dy * sa, -dx * sa + dy * ca
                if (u / rx) ** 2 + (v / ry) ** 2 <= 1.0:
                    self.g[y][x] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, c)

    def shade(self, base, dark, cx, cy, rx, ry):
        """Darken the lower-right rim of an ellipse area that is still `base`."""
        cx, cy = cx + M, cy + M
        for y in range(self.n):
            for x in range(self.n):
                if self.g[y][x] != base:
                    continue
                d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
                if d > 0.62 and (x + 0.5 - cx) / rx + (y + 0.5 - cy) / ry > 0.55:
                    self.g[y][x] = dark

    def ringed(self, cells, col):
        """Paint `cells` (design coords) in col with a 1-cell K ring around them, so a limb or stick
        that overlaps the body still reads as a separate shape."""
        cells = set(cells)
        for x, y in cells:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (x + dx, y + dy) not in cells:
                    self.px(x + dx, y + dy, "K")
        for x, y in cells:
            self.px(x, y, col)

    def outline(self, col="K"):
        src = [row[:] for row in self.g]
        for y in range(self.n):
            for x in range(self.n):
                if src[y][x] != ".":
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < self.n and 0 <= yy < self.n and src[yy][xx] not in (".", col):
                        self.g[y][x] = col
                        break

    def image(self, scale=8):
        im = Image.new("RGBA", (self.n, self.n), (0, 0, 0, 0))
        for y, row in enumerate(self.g):
            for x, c in enumerate(row):
                if c != ".":
                    im.putpixel((x, y), PAL[c])
        return im.resize((self.n * scale, self.n * scale), Image.NEAREST)


def ell_cells(cx, cy, rx, ry):
    out = []
    for y in range(-2, 34):
        for x in range(-2, 34):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                out.append((x, y))
    return out


def _face(g, expr, lx, rx, ey, my, mouth_x, big=False):
    """Eyes at (lx, ey) and (rx, ey); mouth centred on mouth_x at row my. big = 2x2 shiny eyes."""
    E = "E"
    if big and expr in ("idle", "combo", "drum"):
        for x in (lx, rx):
            g.rect(x, ey, x + 1, ey + 1, E)
            g.px(x, ey, "W")
        if expr == "combo":
            for x in (lx, rx):
                g.px(x + 1, ey + 1, "W")
    elif big and expr == "blink_half":           # lid row over the lower eye row
        for x in (lx, rx):
            g.rect(x, ey, x + 1, ey, "K")
            g.rect(x, ey + 1, x + 1, ey + 1, E)
    elif expr in ("idle", "combo", "drum"):
        for x in (lx, rx):
            g.px(x, ey, E); g.px(x, ey + 1, E)
        if expr == "combo":  # sparkle highlights
            g.px(lx, ey, "W"); g.px(rx, ey, "W")
            for x in (lx, rx):
                g.px(x - 1, ey, E); g.px(x - 1, ey + 1, E)
    elif expr == "blink_half":
        for x in (lx, rx):
            g.px(x - 1, ey, "K"); g.px(x, ey, "K")
            g.px(x, ey + 1, E)
    elif expr == "blink":
        for x in (lx, rx):
            g.px(x - 1, ey + 1, E); g.px(x, ey + 1, E)
    elif expr in ("good", "clear", "cheer"):          # ^ ^
        for x in (lx, rx):
            g.px(x - 1, ey + 1, E); g.px(x, ey, E); g.px(x + 1, ey + 1, E)
    elif expr == "gogo":                     # > <
        g.px(lx - 1, ey - 1, E); g.px(lx, ey, E); g.px(lx - 1, ey + 1, E)
        g.px(rx + 1, ey - 1, E); g.px(rx, ey, E); g.px(rx + 1, ey + 1, E)
    elif expr == "sad":
        for x in (lx, rx):
            g.px(x, ey + 1, E); g.px(x, ey + 2, E)
        g.px(lx - 1, ey - 1, E); g.px(rx + 1, ey - 1, E)
    elif expr == "fail":                     # x x
        for x in (lx, rx):
            g.px(x - 1, ey - 1, E); g.px(x + 1, ey - 1, E); g.px(x, ey, E)
            g.px(x - 1, ey + 1, E); g.px(x + 1, ey + 1, E)
    m = mouth_x
    if expr == "cheer":                              # wide open: 3x2 with a tongue row
        g.rect(m - 1, my, m + 1, my + 1, "E")
        g.px(m - 1, my + 1, "B"); g.px(m, my + 1, "B"); g.px(m + 1, my + 1, "B")
    elif expr in ("good", "clear", "gogo", "combo", "drum"):   # open mouth
        g.rect(m - 1, my, m, my + 1, "E")
        g.px(m - 1, my + 1, "B"); g.px(m, my + 1, "B")
    elif expr in ("sad", "fail"):                    # frown
        g.px(m - 2, my + 1, "E"); g.px(m - 1, my, "E"); g.px(m, my, "E"); g.px(m + 1, my + 1, "E")
    else:                                            # smile
        g.px(m - 2, my, "E"); g.px(m - 1, my + 1, "E"); g.px(m, my + 1, "E"); g.px(m + 1, my, "E")
    if expr in ("sad", "fail"):
        g.px(lx - 1, ey + 3, "T"); g.px(lx - 1, ey + 4, "T")


def _sticks(g, side, paw_hi, paw_lo):
    """Two bachi (2 wide, ~10 long, wood y, K ring, 2x2 W tip). paw_hi: the raised paw (stick 45 deg up
    and outward), paw_lo: the lowered paw (stick straight down to the bottom edge)."""
    hx, hy = paw_hi
    up = []
    for i in range(0, 5):          # 5 diagonal steps: the longest that stays inside the 34-cell canvas
        x = hx + side * i
        up += [(x, hy - i), (x + side, hy - i)]
    tip = up[-2:]
    tx, ty = min(p[0] for p in tip), tip[0][1]
    g.ringed(up + [(tx, ty - 1), (tx + 1, ty - 1)], "y")
    g.rect(tx, ty - 1, tx + 1, ty, "W")
    lx, ly = paw_lo
    down = [(x, y) for y in range(ly, 31) for x in (lx, lx + 1)]
    g.ringed(down + [(lx, 31), (lx + 1, 31)], "y")
    g.rect(lx, 30, lx + 1, 31, "W")


def rabbit(expr="idle", frame=0, outfit=None):
    """Momo: pink rabbit with a mint belly patch. `frame` is unused (v1 squash; idle1 replaces it).
    outfit: None (the plush as is) or an id from OUTFITS["momo"]."""
    face, pose = POSES[expr]
    g = Grid()
    bd = pose.get("body_dy", 0)
    sit = pose.get("sit", 0)
    ed = pose.get("ear_dy", 0) + sit
    tx = 3 * pose.get("turn", 0)                       # face shift toward the facing side
    hd = sit                                           # head drop
    droop = face in ("sad", "fail")
    # ears (droop sideways when sad)
    if droop:     # the tall ears stay (they are her silhouette), laid back ~40 deg outward
        for side in (-1, 1):
            ang = 40 * side
            g.ell_rot(16 + side * 7.6, 6.2 + ed, 2.8, 6.8, ang, "P")
        for side in (-1, 1):
            g.ell_rot(16 + side * 8.0, 6.6 + ed, 1.1, 4.6, 40 * side, "I")
    else:
        g.ell(11.5, 7 + ed, 2.8, 7, "P"); g.ell(20.5, 7 + ed, 2.8, 7, "P")
        if not tx:
            g.ell(11.5, 7.5 + ed, 1.1, 5, "I")
        g.ell(20.5, 7.5 + ed, 1.1, 5, "I")
    # head + body (one bean)
    g.ell(16, 16 + hd, 10.5, 7.5, "P")
    if sit:
        g.ell(16, 25.5, 8.5, 5.5, "P")                 # seated torso (narrower than the head), rows 20-31
    else:
        g.ell(16, 23 + bd, 9.5, 7, "P")
    arms = pose.get("arms")
    up = face in ("good", "clear", "gogo", "combo")
    if arms is None and sit:     # paws resting on the knees (drawn after the belly, ringed)
        pass
    elif arms is None:
        ay = (18 if up else 22) + bd
        g.ell(5.5, ay, 2.2, 2.4, "P"); g.ell(26.5, ay, 2.2, 2.4, "P")
    # feet / legs
    if not sit:
        g.ell(11.5, 29.5, 3.2, 1.8, "P"); g.ell(20.5, 29.5, 3.2, 1.8, "P")
    g.shade("P", "p", 16, 21, 11, 10)
    # belly
    bcy = 26 if sit else 24 + bd
    bry = 3.0 if sit else 4.6
    g.ell(16, bcy, 5.2, bry, "G")
    g.shade("G", "g", 16, bcy, 5.2, bry)
    c = None
    if outfit:
        neck = 24 if sit else 22
        tc = (16, 25.5, 8.5, 5.5) if sit else (16, 23 + bd, 9.5, 7)
        for y in range(neck - 1):                      # the belly patch peeking above the clothes
            for x in range(32):
                if g.get(x, y) in ("G", "g"):
                    g.px(x, y, "P")
        cells = {p for p in ell_cells(*tc) + ell_cells(16, 16 + hd, 10.5, 7.5) if p[1] >= neck}
        if not sit:
            cells -= set(ell_cells(11.5, 29.5, 3.2, 1.8) + ell_cells(20.5, 29.5, 3.2, 1.8))
        c = dict(char="momo", face=face, pose=pose, arms=arms, side=pose.get("side", 0), up=up, bd=bd,
                 sit=sit, hd=hd, ed=ed, tx=tx, ox=2 * pose.get("turn", 0), droop=droop,
                 lx=12 + tx, rx=19 + tx, ey=14 + hd, my=18 + hd, mx=16 + tx, neck=neck, tc=tc,
                 torso=cells, head=(16, 16 + hd, 10.5, 7.5), top=8 + hd, ay=(18 if up else 22) + bd,
                 skin="P", skin_d="p")
        _wear(g, outfit, "torso", c)
    if sit:   # legs forward over the belly edge, soles (inner-ear pink) toward the viewer
        for fx in (10.5, 21.5):
            g.ringed(ell_cells(fx, 29.5, 3.0, 1.8), "P")
            g.rect(int(fx) - 1 + (1 if fx > 16 else 0), 29, int(fx) + (1 if fx > 16 else 0), 29, "I")
        for ax in (8, 24):
            g.ringed(ell_cells(ax + 0.5, 25.5, 2.0, 2.0), "P")
    if c:
        _wear(g, outfit, "head", c)
        _limbs(g, pose, arms, OUTFIT_SLEEVE[outfit], OUTFIT_PAW.get(outfit, "P"), bd)
    else:
        _limbs(g, pose, arms, "P", "P", bd)
    _face(g, face, 12 + tx, 19 + tx, 14 + hd, 18 + hd, 16 + tx)
    g.px(15 + tx, 16 + hd, "E"); g.px(16 + tx, 16 + hd, "E")            # nose
    if not droop:
        if not tx:
            g.px(10, 17 + hd, "B")
        g.px(22 + tx, 17 + hd, "B")                                     # cheeks
    if c:
        _wear(g, outfit, "top", c)
    if sit:
        _sweat(g, 25, 8 + hd)
    g.outline()
    return g


def _limbs(g, pose, arms, sleeve, paw, bd):
    """Posed arms (cheer / drum) drawn over the body with a K ring; sleeve + paw colours."""
    if arms == "cheer":
        for x in (5, 27):
            g.ringed(ell_cells(x + 0.5, 9.5, 2.0, 4.0), sleeve)
            g.ringed(ell_cells(x + 0.5, 6.5, 2.0, 1.8), paw)
    elif arms == "drum":
        side = pose["side"]
        hi_x = 6 if side < 0 else 26          # raised paw at ear height on the `side`
        lo_x = 26 if side < 0 else 6
        g.ringed(ell_cells(hi_x + 0.5, 12.5, 2.0, 2.6), sleeve)
        g.ringed(ell_cells(hi_x + 0.5 + side, 10.5, 1.6, 1.6), paw)
        g.ringed(ell_cells(lo_x + 0.5, 23.5, 2.0, 2.4), sleeve)
        g.ringed(ell_cells(lo_x + 0.5, 25.5, 1.6, 1.4), paw)
        _sticks(g, side, (hi_x + side + (0 if side < 0 else -1), 9), (lo_x - (1 if side < 0 else 0), 26))


def _sweat(g, x, y):
    """2x3 sweat drop (T) with a K ring, top-right of the head."""
    g.ringed([(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1), (x, y + 2), (x + 1, y + 2)], "T")
    g.px(x, y, "W")


def husky(expr="idle", frame=0, outfit=None):
    """Hoshi: husky pup in a grey hoodie with round ears and a yellow horn. `frame` is unused.
    outfit: None (the hoodie) or an id from OUTFITS["hoshi"] (the hood stays, the body is re-dressed)."""
    face, pose = POSES[expr]
    g = Grid()
    bd = pose.get("body_dy", 0)
    sit = pose.get("sit", 0)
    hd = sit
    ed = pose.get("ear_dy", 0)
    turn = pose.get("turn", 0)
    tx = 3 * turn
    horn_dy = ed + hd + (1 if pose.get("arms") == "drum" else 0)
    # tail (curled, behind)
    if not sit:
        g.ell(27, 21 + bd, 2.6, 3.2, "H"); g.ell(27.5, 18.5 + bd, 1.6, 1.6, "Z")
    else:
        g.ell(27, 26.5, 2.6, 2.6, "H"); g.ell(27.5, 24.5, 1.6, 1.4, "Z")
    # body hoodie
    if sit:
        g.ell(16, 25.5, 9, 5.5, "H")                   # seated torso, rows 20-31
    else:
        g.ell(16, 24 + bd, 9, 6.5, "H")
    # hood + ears + horn
    g.ell(16, 13 + hd, 10.5, 9, "H")
    g.ell(7.5, 5.5 + hd + ed, 3.2, 3.2, "H"); g.ell(24.5, 5.5 + hd + ed, 3.2, 3.2, "H")
    if not tx:
        g.ell(7.5, 5.5 + hd + ed, 1.6, 1.6, "F")
    g.ell(24.5, 5.5 + hd + ed, 1.6, 1.6, "F")
    for i, w in enumerate((0, 1, 1, 2)):
        g.rect(16 - w, 1 + i + horn_dy, 15 + w, 1 + i + horn_dy, "Y")
    g.px(15, 4 + horn_dy, "y"); g.px(16, 4 + horn_dy, "y")
    g.shade("H", "h", 16, 17, 11, 12)
    # face opening + husky mask (the opening shifts 2, the features 3 when turned)
    ox = 2 * turn
    g.ell(16 + ox, 15 + hd, 7.2, 6.2, "F")
    g.ell(16 + ox, 10.5 + hd, 7, 3.6, "M", only="F")
    g.px(12 + tx, 12 + hd, "F"); g.px(19 + tx, 12 + hd, "F")            # brow spots
    for x in (15, 16):
        g.px(x + tx, 11 + hd, "F"); g.px(x + tx, 12 + hd, "F")
    # zipper + paws
    zx = 16 + 2 * turn
    if sit:
        g.rect(zx, 24, zx, 29, "Z")
    else:
        g.rect(zx, 20 + bd, zx, 28 + bd, "Z")
    arms = pose.get("arms")
    up = face in ("good", "clear", "gogo", "combo")
    c = None
    if outfit:
        neck = 24 if sit else 22
        tc = (16, 25.5, 9, 5.5) if sit else (16, 24 + bd, 9, 6.5)
        cells = {p for p in ell_cells(*tc) + ell_cells(16, 13 + hd, 10.5, 9) if p[1] >= neck}
        c = dict(char="hoshi", face=face, pose=pose, arms=arms, side=pose.get("side", 0), up=up, bd=bd,
                 sit=sit, hd=hd, ed=ed, tx=tx, ox=ox, turn=turn, horn_dy=horn_dy,
                 lx=12 + tx, rx=18 + tx, ey=14 + hd, my=18 + hd, mx=16 + tx, neck=neck, tc=tc,
                 torso=cells, head=(16, 13 + hd, 10.5, 9), top=4 + hd, ay=(19 if up else 24) + bd,
                 skin="F", skin_d="Z")
        _wear(g, outfit, "torso", c)
    if arms is None:
        ay = (19 if up else 24) + bd + (3 if sit else 0)
        g.ell(7, ay, 2.2, 2.2, "F"); g.ell(25, ay, 2.2, 2.2, "F")
    if sit:   # legs forward, grey paw pads toward the viewer
        for fx in (10.5, 21.5):
            g.ringed(ell_cells(fx, 30, 3.0, 1.7), "F")
            g.rect(int(fx) - 1 + (1 if fx > 16 else 0), 30, int(fx) + (1 if fx > 16 else 0), 30, "h")
    else:
        g.ell(11.5, 30, 2.8, 1.7, "F"); g.ell(20.5, 30, 2.8, 1.7, "F")
    if c:
        _wear(g, outfit, "head", c)
        _limbs(g, pose, arms, OUTFIT_SLEEVE[outfit], OUTFIT_PAW.get(outfit, "F"), bd)
    else:
        _limbs(g, pose, arms, "H", "F", bd)
    _face(g, face, 12 + tx, 18 + tx, 14 + hd, 18 + hd, 16 + tx, big=True)
    g.px(15 + tx, 16 + hd, "E"); g.px(16 + tx, 16 + hd, "E")
    if c:
        _wear(g, outfit, "top", c)
    if sit:
        _sweat(g, 25, 9 + hd)
    g.outline()
    return g


def _led_face(g, expr, lx, rx, ey, my, mx):
    """The robot's face: LED marks (L, W glint) on its dark visor. Same expression set as _face."""
    L = "L"
    if expr in ("idle", "combo", "drum"):
        for x in (lx, rx):
            g.rect(x, ey, x + 1, ey + 1, L)
        if expr == "combo":
            for x in (lx, rx):
                g.px(x, ey, "W")
    elif expr == "blink_half":
        for x in (lx, rx):
            g.rect(x, ey + 1, x + 1, ey + 1, L)
    elif expr == "blink":
        for x in (lx, rx):
            g.rect(x - 1, ey + 1, x + 2, ey + 1, L)
    elif expr in ("good", "clear", "cheer"):          # ^ ^
        for x in (lx, rx):
            g.px(x - 1, ey + 1, L); g.px(x, ey, L); g.px(x + 1, ey, L); g.px(x + 2, ey + 1, L)
    elif expr == "gogo":                              # > <
        g.px(lx - 1, ey - 1, L); g.px(lx, ey, L); g.px(lx + 1, ey, L); g.px(lx - 1, ey + 1, L)
        g.px(rx + 2, ey - 1, L); g.px(rx + 1, ey, L); g.px(rx, ey, L); g.px(rx + 2, ey + 1, L)
    elif expr == "sad":
        for x in (lx, rx):
            g.rect(x, ey + 1, x + 1, ey + 1, L)
        g.px(lx - 1, ey - 1, L); g.px(rx + 2, ey - 1, L)
    elif expr == "fail":                              # x x
        for x in (lx, rx):
            g.px(x - 1, ey - 1, L); g.px(x + 1, ey - 1, L); g.px(x, ey, L)
            g.px(x - 1, ey + 1, L); g.px(x + 1, ey + 1, L)
    m = mx
    if expr == "cheer":
        g.rect(m - 2, my, m + 1, my + 1, L)
    elif expr in ("good", "clear", "gogo", "combo", "drum"):
        g.rect(m - 1, my, m, my + 1, L)
    elif expr in ("sad", "fail"):
        g.px(m - 2, my + 1, L); g.px(m - 1, my, L); g.px(m, my, L); g.px(m + 1, my + 1, L)
    else:
        g.px(m - 2, my, L); g.px(m - 1, my + 1, L); g.px(m, my + 1, L); g.px(m + 1, my, L)


def robot(expr="idle", frame=0):
    """AI: the AI battle's opponent, a little drum robot (steel shell, dark visor with LED eyes, a red
    antenna bulb, a drum-face emblem on the chest). Same frame set as Momo / Hoshi. `frame` is unused."""
    face, pose = POSES[expr]
    g = Grid()
    bd = pose.get("body_dy", 0)
    sit = pose.get("sit", 0)
    hd = sit
    ed = pose.get("ear_dy", 0)
    tx = 3 * pose.get("turn", 0)
    ox = 2 * pose.get("turn", 0)
    # antenna (bobs with the ears' cheer lift, dips on a drum hit)
    ay = ed + hd + (1 if pose.get("arms") == "drum" else 0)
    g.rect(16, 3 + ay, 16, 5 + ay, "S")
    g.ell(16.5, 2.5 + ay, 1.7, 1.7, "O")
    # body
    if sit:
        g.ell(16, 25.5, 8.5, 5.5, "R")
    else:
        g.ell(16, 24 + bd, 8.5, 6.5, "R")
    # head: a wide rounded helmet with bolt "ears"
    g.ell(16, 13 + hd, 11, 8, "R")
    for x in (4.5, 27.5):
        if tx and x < 16:
            continue
        g.ell(x + (tx if x > 16 else 0) * 0, 13 + hd, 1.8, 2.4, "S")
    g.shade("R", "r", 16, 17, 11, 12)
    # visor (corners rounded) + the face on it
    vx0, vx1, vy0, vy1 = 8 + ox, 23 + ox, 9 + hd, 17 + hd
    g.rect(vx0, vy0, vx1, vy1, "V")
    for x, y in ((vx0, vy0), (vx1, vy0), (vx0, vy1), (vx1, vy1)):
        g.px(x, y, "R")
    _led_face(g, face, 11 + tx, 18 + tx, 11 + hd, 14 + hd, 16 + tx)
    # chest: a drum-face emblem (silver rim, red face)
    cy = 26 if sit else 24 + bd
    g.ell(16 + ox, cy, 3.4, 2.8, "S")
    g.ell(16 + ox, cy, 2.0, 1.6, "O")
    # hands / feet
    arms = pose.get("arms")
    up = face in ("good", "clear", "gogo", "combo")
    if arms is None:
        ay2 = (19 if up else 24) + bd + (3 if sit else 0)
        g.ell(6.5, ay2, 2.2, 2.4, "S"); g.ell(25.5, ay2, 2.2, 2.4, "S")
    if sit:
        for fx in (10.5, 21.5):
            g.ringed(ell_cells(fx, 30, 3.0, 1.7), "r")
    else:
        g.ell(11.5, 30, 3.0, 1.7, "r"); g.ell(20.5, 30, 3.0, 1.7, "r")
    _limbs(g, pose, arms, "R", "S", bd)
    if sit:
        _sweat(g, 25, 8 + hd)
    g.outline()
    return g


# the robot's colours (AI battle): steel shell / shade, silver parts, dark visor, cyan LEDs, red bulb
PAL.update({"R": hexc("#A9C1DE"), "r": hexc("#7F98BC"), "S": hexc("#E3EAF2"), "V": hexc("#26344C"),
            "L": hexc("#7CF3FF"), "O": hexc("#F05A4F")})

CHARS = {"momo": ("Momo", rabbit), "hoshi": ("Hoshi", husky), "robo": ("AI", robot)}
# canvas row the character stands on (first row below the feet's outline), per character
FOOT = {"momo": 33, "hoshi": 34, "robo": 34}


def sprite(char, expr="idle", frame=0, scale=8, outfit=None):
    """The sprite as an RGBA image of 34*scale px (NEAREST, crisp). outfit: None or an id from
    OUTFITS[char] (the robot has no outfits)."""
    if outfit:
        if outfit not in OUTFITS.get(char, ()):
            raise ValueError(f"outfit {outfit!r} not available for {char!r}: {OUTFITS.get(char, [])}")
        return CHARS[char][1](expr, frame, outfit).image(scale)
    return CHARS[char][1](expr, frame).image(scale)


# ---------------------------------------------------------------------------------------------------------
# Outfits (costumes). rabbit()/husky() call _wear(g, outfit, stage, c) at three points when outfit is set:
#   "torso" after the body base (belly / zipper), before seated legs and resting paws: the body clothes
#           (c["torso"] = body cells below the neck row) and, for Momo, re-drawn resting arms as sleeves;
#   "head"  before the posed arms and the face: hats, headbands, hair ornaments (Momo's ears and Hoshi's
#           horn poke through: hats sit between / below them, the horn is re-drawn on top);
#   "top"   after the face: things that cover a feature (the pirate's eyepatch).
# Posed arms (cheer / drum) take the outfit's sleeve colour (OUTFIT_SLEEVE) and paw colour (OUTFIT_PAW,
# mittens). Front details shift by c["ox"] (2 px) in the 3/4 turn. outfit=None never reaches this code.
# ---------------------------------------------------------------------------------------------------------
PAL.update({
    "N": hexc("#4F6BB8"), "n": hexc("#3A5296"),     # indigo (happi, sailor collar / skirt)
    "C": hexc("#E8505B"), "c": hexc("#BC3A4B"),     # red (obi, scarf, santa, bow, bandana)
    "U": hexc("#B4DCF4"), "u": hexc("#86BCE4"),     # sky blue (yukata)
    "J": hexc("#6E6896"), "j": hexc("#56507C"),     # ninja purple-grey
    "X": hexc("#68709C"), "x": hexc("#525A84"),     # dark cloth (gakuran, tricorn)
    "A": hexc("#CDB9F5"), "a": hexc("#A994E0"),     # lavender (idol dress)
    "Q": hexc("#56C6AE"), "q": hexc("#3AA08B"),     # teal (winter coat)
})

OUTFITS = {
    "momo": ["happi", "yukata", "school", "chef", "pirate", "winter", "ninja", "santa", "idol"],
    "hoshi": ["happi", "yukata", "school", "chef", "pirate", "winter", "ninja", "santa", "idol"],
}
OUTFIT_SLEEVE = {"happi": "N", "yukata": "U", "school": "W", "chef": "W", "pirate": "C", "winter": "Q",
                 "ninja": "J", "santa": "C", "idol": "A"}
OUTFIT_PAW = {"winter": "C"}          # mittens; other outfits keep the character's own paw colour


def _cloth(g, cells, base, dark=None, tc=None):
    """Ringed fill of `cells`, the lower-right rim (as Grid.shade, over the ellipse tc) in `dark`."""
    cells = set(cells)
    g.ringed(cells, base)
    if dark and tc:
        cx, cy, rx, ry = tc
        for x, y in cells:
            u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if u * u + v * v > 0.62 and u + v > 0.55:
                g.px(x, y, dark)


def _body(g, c, base, dark, sleeve=None):
    _cloth(g, c["torso"], base, dark, c["tc"])
    if c["char"] == "momo" and c["arms"] is None and not c["sit"]:     # resting arms as sleeves + paws
        ay, paw = c["ay"], c.get("paw", "P")
        for ax in (5.5, 26.5):
            cells = ell_cells(ax, ay, 2.2, 2.4)
            g.ringed(cells, sleeve or base)
            for x, y in cells:
                if (y <= ay - 1) if c["up"] else (y >= ay + 1):
                    g.px(x, y, paw)


def _rows(c, y0, y1):
    """Torso cells in rows y0..y1."""
    return {p for p in c["torso"] if y0 <= p[1] <= y1}


def _head_rows(c, y0, y1, x0=-9, x1=99):
    cx, cy, rx, ry = c["head"]
    return {(x, y) for x, y in ell_cells(cx, cy, rx, ry) if y0 <= y <= y1 and x0 <= x <= x1}


def _band_row(c):
    return (10 if c["char"] == "momo" else 6) + c["hd"]


def _band(g, c, col, rows=2, tails=None, x0=-9, x1=99):
    """A headband across the head (Momo) / the hood above the face (Hoshi); tails: -1 / 1 = knot ends
    hanging off that side."""
    b = _band_row(c)
    if c["char"] == "hoshi":
        x0, x1 = max(x0, 9), min(x1, 22)
    cells = _head_rows(c, b, b + rows - 1, x0, x1)
    if tails:
        xs = [x for x, y in cells if y == b + rows - 1]
        e = max(xs) if tails > 0 else min(xs)
        cells |= {(e + tails, b + rows), (e + 2 * tails, b + rows), (e + tails, b + rows + 1),
                  (e + 2 * tails, b + rows + 1) if c["char"] == "hoshi" else (e + tails, b + rows + 2)}
    g.ringed(cells, col)
    return b


def _horn(g, c):
    """Hoshi's horn re-drawn over a hat (it always pokes through)."""
    hy = c["horn_dy"]
    cells = []
    for i, w in enumerate((0, 1, 1, 2)):
        cells += [(x, 1 + i + hy) for x in range(16 - w, 16 + w)]
    g.ringed(cells, "Y")
    g.px(15, 4 + hy, "y"); g.px(16, 4 + hy, "y")


def _mittens(g, c, col):
    """Recolour the resting paws (Hoshi's, Momo's seated ones) drawn by the base."""
    if c["arms"] is not None:
        return
    if c["char"] == "hoshi":
        ay = c["ay"] + (3 if c["sit"] else 0)
        for ax in (7, 25):
            for x, y in ell_cells(ax, ay, 2.2, 2.2):
                if g.get(x, y) in ("F", "Z"):
                    g.px(x, y, col)
    elif c["sit"]:
        for ax in (8.5, 24.5):
            for x, y in ell_cells(ax, 25.5, 2.0, 2.0):
                g.px(x, y, col)


def _v_collar(g, c, col, depth=3, cross=False):
    """Kimono-style V collar from the neck: two diagonal lines meeting at the centre (cross: the left
    line runs on past the centre, left-over-right)."""
    n, o = c["neck"], c["ox"]
    for i in range(depth):
        g.px(13 + o + i, n + i, col)
        if not cross or i < depth - 1:
            g.px(18 + o - i, n + i, col)
    if cross:
        g.px(13 + o + depth, n + depth, col)


def _eyepatch(g, c):
    rx, ey = c["rx"], c["ey"]
    w = 3 if c["char"] == "momo" else 4
    x0 = rx - 1
    g.rect(x0, ey - 1, x0 + w - 1, ey + 1, "E")
    g.rect(x0 + 1, ey + 2, x0 + w - 2, ey + 2, "E")
    for i in range(1, 5):                     # strap up-left and up-right to the head band, inside the head
        for x, y in ((x0 - i, ey - 1 - i), (x0 + w - 1 + i, ey - 1 - i)):
            if g.get(x, y) not in (".", "K"):
                g.px(x, y, "K")


# --- the outfits -----------------------------------------------------------------------------------------
def _o_happi(g, st, c):
    if st == "torso":
        _body(g, c, "N", "n")
        n, o = c["neck"], c["ox"]
        _v_collar(g, c, "W", 3)
        for y in range(n + 3, n + 8):              # the eri band runs on down the front
            if (15 + o, y) in c["torso"]:
                g.px(15 + o, y, "W"); g.px(16 + o, y, "W")
    elif st == "head":
        b = _band(g, c, "W", 2, tails=-1)
        o = c["ox"]
        g.rect(15 + o, b, 16 + o, b + 1, "C")       # the hinomaru on the hachimaki


def _o_yukata(g, st, c):
    if st == "torso":
        _body(g, c, "U", "u")
        for x, y in c["torso"]:
            if (x + 2 * y) % 5 == 0 and x % 2 == 0 and g.get(x, y) in ("U", "u"):
                g.px(x, y, "W")
        _v_collar(g, c, "W", 3, cross=True)
        ob = c["neck"] + (2 if c["sit"] else 3)
        g.ringed(_rows(c, ob, ob + 1), "C")
        o = c["ox"]
        g.rect(15 + o, ob, 16 + o, ob + 1, "Y")
    elif st == "head":                               # a flower on the right (near-side) of the head
        if c["char"] == "momo":
            fx, fy = 21, 10 + c["hd"]
        else:
            fx, fy = 20, 6 + c["hd"]
        g.ringed([(fx, fy), (fx - 1, fy), (fx + 1, fy), (fx, fy - 1), (fx, fy + 1)], "C")
        g.px(fx, fy, "Y")


def _o_school(g, st, c):
    n, o = c["neck"], c["ox"]
    if c["char"] == "momo":                          # sailor uniform
        if st == "torso":
            _body(g, c, "W", "Z", sleeve="W")
            sk = n + (3 if c["sit"] else 5)
            for x, y in _rows(c, sk, 31):            # pleated skirt
                g.px(x, y, "n" if (x - o) % 3 == 0 else "N")
            g.ringed(_rows(c, n, n + 1) - {(x, n) for x in range(14 + o, 18 + o)}
                     - {(15 + o, n + 1), (16 + o, n + 1)}, "N")
            for x, y in _rows(c, n, n + 1):          # white trim line on the collar
                if y == n + 1 and g.get(x, y) == "N" and abs(x + 0.5 - 16 - o) > 3:
                    g.px(x, y, "W")
            g.ringed([(15 + o, n + 2), (16 + o, n + 2), (15 + o, n + 3)], "C")   # the scarf knot
    else:                                            # gakuran + cap
        if st == "torso":
            _body(g, c, "X", "x")
            for x, y in _rows(c, n, n):
                g.px(x, y, "x")                      # stand collar
            for y in range(n + 2, 32, 2):
                if (16 + o, y) in c["torso"] and y <= n + 6:
                    g.px(16 + o, y, "Y")
        elif st == "head":
            t = c["hd"]
            cap = {(x, y) for x, y in ell_cells(16, 6.5 + t, 6.5, 3.0) if y <= 6 + t}
            brim = {(x, 7 + t) for x in range(9, 23)}
            g.ringed(cap | brim, "X")
            for x, y in brim:
                g.px(x, y, "x")
            g.px(15 + o // 2, 6 + t, "Y"); g.px(16 + o // 2, 6 + t, "Y")
            _horn(g, c)


def _o_chef(g, st, c):
    n, o = c["neck"], c["ox"]
    if st == "torso":
        _body(g, c, "W", "Z")
        for y in (n + 2, n + 4):
            for x in (13 + o, 18 + o):
                if (x, y) in c["torso"]:
                    g.px(x, y, "Z")
        g.ringed([(x, n) for x in range(13 + o, 20 + o)] + [(15 + o, n + 1), (16 + o, n + 1)], "C")
    elif st == "head":
        t = c["hd"]
        if c["char"] == "momo":
            band = {(x, y) for x in range(12, 20) for y in (8 + t, 9 + t)}
            puff = set(ell_cells(16, 5 + t, 4.6, 3.4))
            pcy = 5 + t
        else:
            band = {(x, y) for x in range(10, 22) for y in (5 + t, 6 + t, 7 + t)}
            puff = set(ell_cells(16, 2.6 + t, 5.6, 3.0))
            pcy = 2.6 + t
        g.ringed(puff | band, "W")
        btop = min(b[1] for b in band)
        for x, y in puff:
            if (x + 0.5 - 16) / 4 + (y + 0.5 - pcy) / 3 > 0.9 and y < btop:
                g.px(x, y, "Z")
        for x in (14, 17):
            g.px(x, btop, "Z")
        if c["char"] == "hoshi":
            _horn(g, c)


def _o_pirate(g, st, c):
    n, o = c["neck"], c["ox"]
    if st == "torso":
        _body(g, c, "W", "Z", sleeve="C")
        for x, y in c["torso"]:
            if (y - n) % 2 == 1:
                g.px(x, y, "c" if g.get(x, y) == "Z" else "C")
        if not c["sit"]:
            bl = n + 5
            g.ringed(_rows(c, bl, bl), "E")
            g.ringed([(15 + o, bl), (16 + o, bl)], "Y")
    elif st == "head":
        t = c["hd"]
        if c["char"] == "momo":                      # bandana with white dots, knot on the left
            cells = _head_rows(c, 8 + t, 11 + t)
            e = min(x for x, y in cells if y == 11 + t)
            cells |= {(e - 1, 11 + t), (e - 2, 12 + t), (e - 1, 12 + t), (e - 2, 13 + t)}
            g.ringed(cells, "C")
            for x, y in ((13, 9), (18, 10), (16, 8), (11, 10), (20, 9)):
                if (x, y + t) in cells:
                    g.px(x, y + t, "W")
        else:                                        # tricorn with a white skull mark
            crown = {(x, y) for x, y in ell_cells(16, 6.5 + t, 6.5, 3.2) if y <= 6 + t}
            brim = {(x, 7 + t) for x in range(8, 24)} | {(8, 6 + t), (23, 6 + t), (7, 5 + t), (24, 5 + t)}
            g.ringed(crown | brim, "X")
            for x, y in brim:
                g.px(x, y, "x")
            g.rect(15, 5 + t, 16, 6 + t, "W")
            g.px(15, 6 + t, "E")
            _horn(g, c)
    elif st == "top":
        _eyepatch(g, c)


def _o_winter(g, st, c):
    n, o = c["neck"], c["ox"]
    if st == "torso":
        c["paw"] = "C"
        _body(g, c, "Q", "q")
        for y in (n + 3, n + 5):                     # toggles
            if (16 + o, y) in c["torso"]:
                g.px(16 + o, y, "W")
        sc = _rows(c, n, n + 1) | {(19 + o, n + 2), (20 + o, n + 2), (19 + o, n + 3), (20 + o, n + 3),
                                   (19 + o, n + 4), (20 + o, n + 4)}
        g.ringed(sc, "C")
        for x, y in sc:
            if (y >= n + 2 and y % 2 == 0) or (y < n + 2 and x % 3 == 0):
                g.px(x, y, "W")
    elif st == "head":
        t = c["hd"]
        _mittens(g, c, "C")
        if c["char"] == "momo":
            cells = _head_rows(c, 7 + t, 11 + t) | set(ell_cells(16, 9 + t, 6.5, 3.0))
            g.ringed(cells, "C")
            for x, y in cells:
                if y >= 10 + t:
                    g.px(x, y, "W")
                elif (x + y) % 2 == 0 and y >= 8 + t:
                    g.px(x, y, "c")
            g.ringed(ell_cells(16, 5.8 + t, 1.9, 1.9), "W")
        else:
            cells = _head_rows(c, 3 + t, 7 + t, 9, 22)
            g.ringed(cells, "C")
            for x, y in cells:
                if y == 7 + t:
                    g.px(x, y, "W")
                elif (x + y) % 2 == 0 and y >= 5 + t:
                    g.px(x, y, "c")
            _horn(g, c)


def _o_ninja(g, st, c):
    n, o = c["neck"], c["ox"]
    if st == "torso":
        _body(g, c, "J", "j")
        _v_collar(g, c, "j", 3)
        sb = n + (2 if c["sit"] else 3)
        g.ringed(_rows(c, sb, sb), "C")
    elif st == "head":
        b = _band(g, c, "J", 2, tails=1)
        g.rect(14 + o, b, 17 + o, b + 1, "S")
        g.px(15 + o, b, "W")


def _o_santa(g, st, c):
    n, o = c["neck"], c["ox"]
    if st == "torso":
        _body(g, c, "C", "c")
        for x, y in c["torso"]:
            if x == 16 + o or y == n:
                g.px(x, y, "W")
        bl = n + (2 if c["sit"] else 3)
        for x, y in _rows(c, bl, bl):
            g.px(x, y, "E")
        g.rect(15 + o, bl, 17 + o, bl, "Y")
        g.px(16 + o, bl, "E")
    elif st == "head":
        t = c["hd"]
        if c["char"] == "momo":
            fur = {(x, y) for x in range(11, 21) for y in (9 + t, 10 + t)}
            cone = set()
            for i, (a, b) in enumerate(((12, 19), (13, 18), (14, 18), (15, 18), (16, 19), (17, 20))):
                cone |= {(x, 8 + t - i) for x in range(a, b + 1)}
            pom = set(ell_cells(19.5, 1.5 + t, 1.6, 1.6))
        else:
            fur = {(x, 7 + t) for x in range(9, 23)}
            cone = set()
            for i, (a, b) in enumerate(((10, 21), (11, 21), (12, 21), (14, 22), (17, 23))):
                cone |= {(x, 6 + t - i) for x in range(a, b + 1)}
            pom = set(ell_cells(25, 1.5 + t, 1.6, 1.6))
        g.ringed(cone | fur, "C")
        for x, y in cone:
            if x >= max(xx for xx, yy in cone if yy == y):
                g.px(x, y, "c")
        for x, y in fur:
            g.px(x, y, "W")
        g.ringed(pom, "W")
        if c["char"] == "hoshi":
            _horn(g, c)


def _o_idol(g, st, c):
    n, o = c["neck"], c["ox"]
    if st == "torso":
        _body(g, c, "A", "a")
        fr = n + (2 if c["sit"] else 3)
        for x, y in _rows(c, fr, fr):                 # frill: a scalloped white row
            g.px(x, y, "W")
            if x % 2 == 0 and (x, y + 1) in c["torso"]:
                g.px(x, y + 1, "W")
        for x, y in _rows(c, n, n):
            g.px(x, y, "W")
        g.ringed([(15 + o, n + 1), (17 + o, n + 1), (16 + o, n + 1)], "C")
        g.px(16 + o, n + 1, "c")
    elif st == "head":                               # a ribbon bow: knot + two triangular wings
        t = c["hd"]
        cx, cy = (16, 8 + t) if c["char"] == "momo" else (11, 7 + t)
        wings = set()
        for s_ in (-1, 1):
            wings |= {(cx + s_, cy)} | {(cx + s_ * d, cy + dy) for d in (2, 3) for dy in (-1, 0, 1)}
        g.ringed(wings | {(cx, cy)}, "C")
        for s_ in (-1, 1):
            g.px(cx + s_ * 3, cy - 1, "W")
            g.px(cx + s_ * 3, cy + 1, "c")
        g.px(cx, cy, "c")


_OUTFIT_FN = {"happi": _o_happi, "yukata": _o_yukata, "school": _o_school, "chef": _o_chef,
              "pirate": _o_pirate, "winter": _o_winter, "ninja": _o_ninja, "santa": _o_santa,
              "idol": _o_idol}


def _wear(g, outfit, stage, c):
    if outfit not in _OUTFIT_FN:
        raise ValueError(f"unknown outfit {outfit!r}; one of {sorted(_OUTFIT_FN)}")
    _OUTFIT_FN[outfit](g, stage, c)
    if stage == "head" and c["char"] == "hoshi" and c["arms"] is None:
        ay = c["ay"] + (3 if c["sit"] else 0)          # resting paws ringed, so they read over the clothes
        for ax in (7, 25):
            g.ringed(ell_cells(ax, ay, 2.2, 2.2), OUTFIT_PAW.get(outfit, "F"))


def outfits_sheet(char, path, k=6):
    """Review sheet: one row per outfit (the default first), one column per EXPR, at k (k*D phys px per
    sprite px, like mascot.frames_sheet), labelled. Writes `path` (e.g. mockups/outfits_momo.png)."""
    from . import style
    from .style import C, Canvas
    S = N * k
    pad, lab = 12, 150
    rows = [None] + OUTFITS[char]
    W = lab + len(EXPR) * (S + pad) + pad
    H = 70 + len(rows) * (S + pad + 8)
    cv = Canvas(W, H, bg=C["bg0"])
    cv.text(pad, 21, f"{CHARS[char][0]} outfits, k={k} logical ({k * style.D} phys px per sprite px)", 24,
            C["ink"], anchor="lm")
    for i, e in enumerate(EXPR):
        cv.text(lab + pad + i * (S + pad) + S / 2, 52, e, 18, C["text2"])
    for r, o in enumerate(rows):
        y0 = 66 + r * (S + pad + 8)
        cv.text(pad, y0 + S / 2, o or "default", 24, C["ink"], anchor="lm")
        for i, e in enumerate(EXPR):
            x0 = lab + pad + i * (S + pad)
            cv.rect(x0, y0 + S, x0 + S, y0 + S + 3, C["line"])
            cv.paste(sprite(char, e, 0, k * style.D, o), x0, y0 + S - FOOT[char] * k)
    cv.result().save(path)
