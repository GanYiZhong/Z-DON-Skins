"""Scene decoration, one shared set (bible 2.4). All crisp, LOGICAL coordinates, U-grid cells.

  cells(...)            draw a character grid (rows of strings) with a palette, optional ink outline
  cloud(cv, x, y, "S"|"M")   the one cloud sprite, 2 sizes; only inside the sky band, 2-3 per screen
  sparkle_burst(cv, cx, cy, frame)   the 4-frame event burst (dot -> plus -> 4-point -> dot, 66 ms each)
  sparkle_frames()      the 4 frames as PHYSICAL images (for an OwnSubset + Lua)
  sky(cv, x0, y0, x1, y1)        sky band ending in the 2-row horizon checker
  horizon_dither(cv, x0, y, x1)  the 2-row sky -> cream checker alone
  ground(cv, x0, y, x1, y1)      1U ink line, grass, brick strip (the player split line never goes here)
  taiko(cv, cx, foot)            the one festival prop: a taiko on a stand, standing on `foot`
  lanterns(cv, x0, x1, y, n)     lantern string on the horizon line
  pixdisc(cv, cx, cy, r, ...)    a disc of U cells with an ink ring (combo disc, medals, icons)
  pixtext(cv, x, y, s, cell)     5x7 block letters (logo / GAME OVER / stamps) with ink outline + shadow

No static sparkles anywhere: sparkles exist only as the burst on an event.
"""
from __future__ import annotations

from . import style
from .style import C, U, snap

INK = C["ink"]
PAPER = C["paper"]


def cells(cv, x, y, rows, pal, cell=U, outline=None, shadow=0):
    """Draw rows of characters (pal maps char -> colour; '.' and unknown = empty) with the top-left at
    (x, y). outline: an ink ring 1 cell wide around the shape; shadow: a hard drop shadow (logical)."""
    x, y = snap(x), snap(y)
    filled = {(i, j) for j, r in enumerate(rows) for i, ch in enumerate(r) if ch in pal}
    if shadow:
        for i, j in filled:
            for di in (-1, 0, 1):
                for dj in (-1, 0, 1):
                    if outline is None and (di or dj):
                        continue
                    cv.rect(x + (i + di) * cell + shadow, y + (j + dj) * cell + shadow,
                            x + (i + di + 1) * cell + shadow, y + (j + dj + 1) * cell + shadow, INK)
    if outline is not None:
        for i, j in filled:
            for di, dj in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, -1), (-1, 1), (1, 1)):
                if (i + di, j + dj) not in filled:
                    cv.rect(x + (i + di) * cell, y + (j + dj) * cell, x + (i + di + 1) * cell,
                            y + (j + dj + 1) * cell, outline)
    for j, r in enumerate(rows):
        for i, ch in enumerate(r):
            if ch in pal:
                cv.rect(x + i * cell, y + j * cell, x + (i + 1) * cell, y + (j + 1) * cell, pal[ch])


def size_of(rows, cell=U):
    return len(rows[0]) * cell, len(rows) * cell


# ---------------------------------------------------------------- clouds
CLOUD_S = ["....XXX.....",
           "..XXXXXXX...",
           ".XXXXXXXXXX.",
           "SSSSSSSSSSSS"]
CLOUD_M = ["......XXXX........",
           "...XXXXXXXXX.XXX..",
           ".XXXXXXXXXXXXXXXX.",
           "XXXXXXXXXXXXXXXXXX",
           "SSSSSSSSSSSSSSSSSS"]
CLOUD_CELL = 3 * U


def cloud(cv, x, y, size="M"):
    """Pixel cloud (paper, cloud2 underside), cells of 3U: S = 108x36, M = 162x45 logical."""
    rows = CLOUD_S if size == "S" else CLOUD_M
    cells(cv, x, y, rows, {"X": C["cloud"], "S": C["cloud2"]}, CLOUD_CELL)
    return size_of(rows, CLOUD_CELL)


# ---------------------------------------------------------------- sparkle burst (events only)
BURST = [
    [".....", ".....", "..X..", ".....", "....."],
    [".....", "..X..", ".XXX.", "..X..", "....."],
    ["..X..", "..X..", "XXWXX", "..X..", "..X.."],
    [".....", ".....", "..W..", ".....", "....."],
]
BURST_MS = 50   # 3 refreshes at 60 Hz (66 held 4/3 unevenly)


def sparkle_burst(cv, cx, cy, frame, cell=2 * U):
    """Frame 0..3 of the event burst, centred on (cx, cy); 5x5 cells + ink outline."""
    rows = BURST[frame]
    w = 5 * cell
    cells(cv, snap(cx - w / 2), snap(cy - w / 2), rows, {"X": C["clear"], "W": PAPER}, cell, outline=INK)


def sparkle_frames(cell=2 * U):
    """The 4 burst frames as PHYSICAL images of 7x7 cells (outline included)."""
    out = []
    for f in range(4):
        cv = style.Canvas(7 * cell, 7 * cell)
        sparkle_burst(cv, 3.5 * cell, 3.5 * cell, f, cell)
        out.append(cv.result())
    return out


# ---------------------------------------------------------------- horizon, sky, ground
def horizon_dither(cv, x0, y, x1, cell=4 * U, top=None, bottom=None):
    """The house horizon: a 2-row checker from sky (above) into cream (below), starting at y.
    Row 0 is sky with every other cell cream; row 1 is cream with the other cells sky."""
    top, bottom = top or C["sky"], bottom or C["bg0"]
    x0, y, x1 = snap(x0), snap(y), snap(x1)
    cv.rect(x0, y, x1, y + cell, top)
    cv.rect(x0, y + cell, x1, y + 2 * cell, bottom)
    for r, col in ((0, bottom), (1, top)):
        yy = y + r * cell
        for xx in range(x0 + r * cell, x1, 2 * cell):
            cv.rect(xx, yy, min(xx + cell, x1), yy + cell, col)
    return y + 2 * cell


def sky(cv, x0, y0, x1, y1, cell=4 * U):
    """Sky band from y0 to y1; its last 2 cells are the horizon checker into cream."""
    cv.rect(x0, y0, x1, y1 - 2 * cell, C["sky"])
    if style.THEME == "dark":
        stars(cv, x0, y0, x1, y1 - 2 * cell)
    horizon_dither(cv, x0, y1 - 2 * cell, x1, cell)


def stars(cv, x0, y0, x1, y1):
    """Night sky (dark theme): a fixed scatter of 1U stars and a few 3U twinkles (+), on the U grid."""
    import random
    rnd = random.Random(7)
    x0, y0, x1, y1 = snap(x0), snap(y0), snap(x1), snap(y1)
    if y1 - y0 < 6 * U:
        return
    n = max(4, (x1 - x0) * (y1 - y0) // (2400 * U * U))
    for i in range(n):
        x = x0 + 2 * U + rnd.randrange((x1 - x0 - 4 * U) // U) * U
        y = y0 + 2 * U + rnd.randrange(max(1, (y1 - y0 - 4 * U) // U)) * U
        col = C["star2"] if i % 5 == 0 else C["star"]
        if i % 7 == 0:   # a small plus-shaped twinkle
            cv.rect(x - U, y, x + 2 * U, y + U, col)
            cv.rect(x, y - U, x + U, y + 2 * U, col)
        else:
            cv.rect(x, y, x + U, y + U, col)


BRICK_W, BRICK_H = 12 * U, 4 * U


def ground(cv, x0, y, x1, y1):
    """Ground strip from y (the grass line the characters stand on) to y1: 1U ink line, 2U grass,
    1U dark grass, then bg3 bricks with `line` mortar (1U)."""
    x0, y, x1, y1 = snap(x0), snap(y), snap(x1), snap(y1)
    cv.rect(x0, y, x1, y + U, INK)
    cv.rect(x0, y + U, x1, y + 3 * U, C["grass"])
    cv.rect(x0, y + 3 * U, x1, y + 4 * U, C["grass2"])
    by = y + 4 * U
    cv.rect(x0, by, x1, y1, C["line"])
    r = 0
    while by < y1:
        off = 0 if r % 2 == 0 else BRICK_W // 2
        for bx in range(x0 - off, x1, BRICK_W):
            cv.rect(max(x0, bx), by, min(x1, bx + BRICK_W - U), min(y1, by + BRICK_H - U), C["bg3"])
        by += BRICK_H
        r += 1
    return y


# ---------------------------------------------------------------- festival props
TAIKO = [
    "....KKKKKKKKKKKK....",
    "..KKWWWWWWWWWWWWKK..",
    ".KWWWWWWWWWWWWWWWWK.",
    ".KKWWWWWWWWWWWWWWKK.",
    ".KRKKKKKKKKKKKKKKRK.",
    "KRRRRRRRRRRRRRRRRRRK",
    "KRGRRRRRRRRRRRRRRGRK",
    "KRRRRRRRRRRRRRRRRRRK",
    "KRRRRRRRRRRRRRRRRRRK",
    "KRGRRRRRRRRRRRRRRGRK",
    "KRRRRRRRRRRRRRRRRRRK",
    ".KRRRRRRRRRRRRRRRRK.",
    ".KKKKKKKKKKKKKKKKKK.",
    "...KwK........KwK...",
    "...KwK........KwK...",
    "..KwwK........KwwK..",
    "..KwK..........KwK..",
    ".KwwK..........KwwK.",
    ".KwK............KwK.",
    "KKKK............KKKK",
]
TAIKO_PAL = {"K": INK, "W": PAPER, "R": C["don"], "G": C["clear"], "w": C["wood"]}


def taiko(cv, cx, foot, cell=3 * U):
    """The one festival prop: a taiko on a stand (20x20 cells; 3U cells = 180 logical), centred on cx,
    standing on the ground line `foot`."""
    w, h = size_of(TAIKO, cell)
    cells(cv, snap(cx - w / 2), snap(foot - h), TAIKO, TAIKO_PAL, cell)
    return w, h


LANTERN = [
    ".KGK.",
    "KRRRK",
    "KRWRK",
    "KRRRK",
    "KRWRK",
    "KRRRK",
    ".KGK.",
]
LANTERN_PAL = {"K": INK, "R": C["don"], "W": PAPER, "G": C["clear"]}


def lanterns(cv, x0, x1, y, n=6, cell=2 * U):
    """Lantern string on the horizon line y: a 1U ink rope with n lanterns hanging from it."""
    x0, x1, y = snap(x0), snap(x1), snap(y)
    cv.rect(x0, y, x1, y + U, INK)
    w, _ = size_of(LANTERN, cell)
    for i in range(n):
        cx = x0 + (x1 - x0) * (i + 0.5) / n
        cells(cv, snap(cx - w / 2), y + U, LANTERN, LANTERN_PAL, cell)


# ---------------------------------------------------------------- discs and block text
def disc_cells(r):
    """Cells of a pixel disc of radius r cells (diameter 2r)."""
    return {(x, y) for x in range(2 * r) for y in range(2 * r)
            if (x + .5 - r) ** 2 + (y + .5 - r) ** 2 <= r * r}


def pixdisc(cv, cx, cy, r, fill, ring=None, ring_w=1, cell=U, inner_ring=None):
    """A disc of radius r cells (cell = U by default) centred on (cx, cy): ink ring ring_w cells wide
    around it, optional inner_ring=(colour, width cells) just inside (e.g. the gold ring at 100+)."""
    ring = INK if ring is None else ring
    R = r + ring_w
    x0, y0 = snap(cx - R * cell), snap(cy - R * cell)
    outer = disc_cells(R)
    inner = {(x + ring_w, y + ring_w) for x, y in disc_cells(r)}
    for x, y in outer:
        col = fill if (x, y) in inner else ring
        cv.rect(x0 + x * cell, y0 + y * cell, x0 + (x + 1) * cell, y0 + (y + 1) * cell, col)
    if inner_ring:
        col, w = inner_ring
        core = {(x + ring_w + w, y + ring_w + w) for x, y in disc_cells(r - w)}
        for x, y in inner:
            if (x, y) not in core:
                cv.rect(x0 + x * cell, y0 + y * cell, x0 + (x + 1) * cell, y0 + (y + 1) * cell, col)
    return 2 * R * cell


FONT5 = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
    "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    "!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
    "?": ["01110", "10001", "00001", "00010", "00100", "00000", "00100"],
    "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    ".": ["00000", "00000", "00000", "00000", "00000", "00000", "00100"],
    ":": ["00000", "00100", "00000", "00000", "00000", "00100", "00000"],
    "/": ["00001", "00001", "00010", "00100", "01000", "10000", "10000"],
    "+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
    " ": ["00000"] * 7,
}


def pixtext_rows(s, gap=1):
    rows = [""] * 7
    for k, ch in enumerate(s.upper()):
        g = FONT5.get(ch, FONT5["?"])
        for j in range(7):
            rows[j] += g[j].replace("1", "X").replace("0", ".") + ("." * gap if k < len(s) - 1 else "")
    return rows


def pixtext_width(s, cell=U, outline=True):
    return (len(pixtext_rows(s)[0]) + (2 if outline else 0)) * cell


def pixtext(cv, x, y, s, cell=U, fill=None, outline=INK, shadow=0):
    """5x7 block letters (A-Z 0-9 ! ? - . : / +). (x, y) = top-left of the outline; each letter pixel
    is `cell` (a multiple of U). Ink outline 1 cell, optional hard shadow (logical, multiple of U)."""
    rows = pixtext_rows(s)
    off = cell if outline is not None else 0
    cells(cv, x + off, y + off, rows, {"X": fill or C["clear"]}, cell, outline=outline, shadow=shadow)
    return pixtext_width(s, cell, outline is not None)
