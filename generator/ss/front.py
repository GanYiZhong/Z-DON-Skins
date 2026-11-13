"""Module "front": title (warning, attract), entry (player entry, mode select, side select, name entry,
costume select), settings, loading. Light 8-bit look (see LIGHT8_GUIDE.md): cream screen, sky band with
pixel clouds, pixboxes with an ink border and a hard shadow, pixel glyphs, and the two mascots Momo
(pink rabbit) and Hoshi (husky pup in a hoodie) standing on a pixel ground strip. Green's layouts and
Lua are kept; every texture is redrawn by code. The block-pixel "YATAI DON" wordmark is drawn here.
Own Lua: lua/front/title/attract_chara.lua (Momo on the title ground strip + blinking cursor); parent
Lua is patched only to drop Green art (advert panels, brown/black text colours) and to stand Momo on the
entry pedestals. Also writes README.md at the skin root."""
from __future__ import annotations

import math
import os

from PIL import Image

from . import mascot, pixel
from .atlas import SubsetWriter, green_json
from .style import C, Canvas, alpha, blank, mix, pixbox, vtext

NAME = "front"
OWNS = ["Graphics/title", "Graphics/entry", "Graphics/settings", "Graphics/loading",
        "Scripts/title", "Scripts/entry", "Videos/op_videos", "Videos/attract_videos", "README.md"]

INK = C["ink"]
PAPER = C["paper"]
CLEAR = (0, 0, 0, 0)
SHADE = (223, 240, 250, 255)         # underside of a pixel cloud
GRASS = (79, 174, 94, 255)
GRASS_D = (56, 140, 72, 255)


# ================================================================== pixel drawing helpers
def cells(rows, ch="X"):
    """('.X.', 'XXX') -> set of (col, row) cells."""
    return {(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == ch}


def blocks(cv, cs, x, y, u, fill, outline=INK, o=None, shadow=0, shade=True):
    """Draw a set of cells (unit u px) with its top-left at (x, y): hard drop shadow, ink outline
    (the shape dilated by o px), fill with a light top edge and a darker bottom edge."""
    o = u // 3 if o is None else o
    x, y, u = int(x), int(y), int(u)
    if shadow:
        for cx, cy in cs:
            cv.rect(x + cx * u - o + shadow, y + cy * u - o + shadow,
                    x + (cx + 1) * u + o + shadow, y + (cy + 1) * u + o + shadow, outline)
    if o:
        for cx, cy in cs:
            cv.rect(x + cx * u - o, y + cy * u - o, x + (cx + 1) * u + o, y + (cy + 1) * u + o, outline)
    for cx, cy in cs:
        cv.rect(x + cx * u, y + cy * u, x + (cx + 1) * u, y + (cy + 1) * u, fill)
    if shade and u >= 3:
        hi, lo, t = mix(fill, PAPER, 0.5), mix(fill, INK, 0.26), max(1, u // 3)
        for cx, cy in cs:
            if (cx, cy - 1) not in cs:
                cv.rect(x + cx * u, y + cy * u, x + (cx + 1) * u, y + cy * u + t, hi)
            if (cx, cy + 1) not in cs:
                cv.rect(x + cx * u, y + (cy + 1) * u - t, x + (cx + 1) * u, y + (cy + 1) * u, lo)


def bbox_w(cs):
    return max(c for c, _ in cs) + 1


GLYPHS = {
    "1": ["..X..", ".XX..", "..X..", "..X..", "..X..", "..X..", ".XXX."],
    "2": [".XXX.", "X...X", "....X", "...X.", "..X..", ".X...", "XXXXX"],
    "A": [".XXX.", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
    "C": [".XXXX", "X....", "X....", "X....", "X....", "X....", ".XXXX"],
    "D": ["XXXX.", "X...X", "X...X", "X...X", "X...X", "X...X", "XXXX."],
    "E": ["XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "XXXXX"],
    "I": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "XXXXX"],
    "L": ["X....", "X....", "X....", "X....", "X....", "X....", "XXXXX"],
    "N": ["X...X", "XX..X", "XX..X", "X.X.X", "X..XX", "X..XX", "X...X"],
    "O": [".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
    "P": ["XXXX.", "X...X", "X...X", "XXXX.", "X....", "X....", "X...."],
    "R": ["XXXX.", "X...X", "X...X", "XXXX.", "X.X..", "X..X.", "X...X"],
    "S": [".XXXX", "X....", "X....", ".XXX.", "....X", "....X", "XXXX."],
    "T": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "..X.."],
    "V": ["X...X", "X...X", "X...X", "X...X", "X...X", ".X.X.", "..X.."],
    "Y": ["X...X", "X...X", ".X.X.", "..X..", "..X..", "..X..", "..X.."],
}


def word_cells(s, gap=1, space=3):
    out, x = set(), 0
    for ch in s:
        if ch == " ":
            x += space
            continue
        g = cells(GLYPHS[ch])
        out |= {(cx + x, cy) for cx, cy in g}
        x += 5 + gap
    return out


def word_w(s, gap=1, space=3):
    return bbox_w(word_cells(s, gap, space))


def pixtext(cv, x, y, s, u, fill, outline=INK, o=None, shadow=0):
    blocks(cv, word_cells(s), x, y, u, fill, outline, o, shadow)
    return word_w(s) * u


def pix_disc(r):
    """Cells of a pixel disc of radius r cells (diameter 2r)."""
    return {(x, y) for x in range(2 * r) for y in range(2 * r)
            if (x + .5 - r) ** 2 + (y + .5 - r) ** 2 <= r * r}


def pix_ring(r, r_in):
    return {(x, y) for x, y in pix_disc(r) if (x + .5 - r) ** 2 + (y + .5 - r) ** 2 > r_in * r_in}


CURSOR = cells(["X....", "XX...", "XXX..", "XXXX.", "XXXXX", "XXXX.", "XXX..", "XX...", "X...."])
PLUS = cells([".X.", "XXX", ".X."])


def cursor(cv, cx, cy, u, fill=None, o=None):
    """Pixel ▶ centred on (cx, cy)."""
    blocks(cv, CURSOR, cx - 5 * u / 2, cy - 9 * u / 2, u, fill or C["roll"], INK, o)


def pixring(cv, x0, y0, x1, y1, px, col):
    """Border only (transparent inside), notched corners."""
    x0, y0, x1, y1 = (int(round(v)) for v in (x0, y0, x1, y1))
    cv.rect(x0 + px, y0, x1 - px, y1, col)
    cv.rect(x0, y0 + px, x1, y1 - px, col)
    cv.rect(x0 + px, y0 + px, x1 - px, y1 - px, CLEAR)


def pbox(cv, x0, y0, x1, y1, fill, px=3, shadow=4, border=None):
    pixbox(cv, x0, y0, x1, y1, fill, border or INK, shadow=shadow, px=px)


def card_img(w, h, fill, inset=(2, 2, 8, 8), px=3, shadow=4, border=None):
    """A pixbox card; inset = (left, top, right, bottom) margins to the outer border edge."""
    cv = Canvas(w, h)
    pbox(cv, inset[0], inset[1], w - inset[2], h - inset[3], fill, px, shadow, border)
    return cv.result()


# a pixel cloud: rows of cells, bottom row shaded
CLOUD = ["..XXXX......",
         ".XXXXXXX.XX.",
         "XXXXXXXXXXXX",
         "XXXXXXXXXXXX"]
CLOUD_S = ["....XXX.....",
           "..XXXXXXX...",
           ".XXXXXXXXXX.",
           "XXXXXXXXXXXX"]


def pcloud(cv, x, y, u, small=False):
    rows = CLOUD_S if small else CLOUD
    for r, row in enumerate(rows):
        for c, ch in enumerate(row):
            if ch == "X":
                cv.rect(x + c * u, y + r * u, x + (c + 1) * u, y + (r + 1) * u,
                        SHADE if r == len(rows) - 1 else PAPER)


def sky_band(cv, x0, y0, x1, y1, step=8):
    """Sky with a checker-dithered lower edge into the cream screen."""
    cv.rect(x0, y0, x1, y1 - 2 * step, C["sky"])
    cv.rect(x0, y1 - 2 * step, x1, y1 - step, C["sky"])
    cv.rect(x0, y1 - step, x1, y1, C["bg0"])
    for yy in range(y1 - 2 * step, y1, step):
        for xx in range(x0 + (((yy - y1) // step) % 2) * step, x1, step * 2):
            cv.rect(xx, yy, min(xx + step, x1), yy + step, C["bg0"])


def ground(cv, x0, y0, x1, y1):
    """Pixel ground strip: ink top line, grass, dirt with a block pattern."""
    cv.rect(x0, y0, x1, y1, C["bg3"])
    blk = mix(C["bg3"], INK, 0.12)
    for yy in range(y0 + 24, y1, 16):
        for xx in range(x0 + (((yy - y0) // 16) % 2) * 24, x1, 48):
            cv.rect(xx, yy, xx + 24, min(yy + 8, y1), blk)
    cv.rect(x0, y0, x1, y0 + 14, GRASS)
    cv.rect(x0, y0 + 10, x1, y0 + 14, GRASS_D)
    for xx in range(x0 + 6, x1, 36):                      # grass tufts
        cv.rect(xx, y0 - 4, xx + 4, y0, GRASS)
        cv.rect(xx + 8, y0 - 8, xx + 12, y0, GRASS)
    cv.rect(x0, y0 - 1, x1, y0 + 2, INK)


def put_sprite(im, char, expr, k, cx, foot, frame=0):
    """Paste a pixel mascot at whole-pixel scale k, centred on cx, feet on row `foot`."""
    s = pixel.sprite(char, expr, frame, k)
    im.alpha_composite(s, (int(cx - s.width / 2), int(foot - s.height)))


def sheet_sprite(concept, expr, size, frame=0):
    return mascot.sized(concept, expr, size, frame)


# ---------------------------------------------------------------- the wordmark
def wordmark(cv, cx, cy, u, shadow=None):
    """Block-pixel 'YATAI DON' (our own design): red YATAI, gold DON, ink outline, hard shadow.
    cx, cy = centre; u = cell size. Returns the total width."""
    a, d = word_cells("YATAI"), word_cells("DON")
    wa, wd, gap = bbox_w(a), bbox_w(d), 3
    total = (wa + gap + wd) * u
    x0, y0 = int(cx - total / 2), int(cy - 7 * u / 2)
    sh = u // 2 if shadow is None else shadow
    for cs, fill, dx in ((a, C["don"], 0), (d, C["roll"], (wa + gap) * u)):
        blocks(cv, cs, x0 + dx, y0, u, fill, INK, max(2, u // 3), sh)
    return total + 2 * max(2, u // 3)


LEFT_CX = 160                    # centre of the left column (wordmark + sub-plate + Momo)
SPARK = cells(["...X...", "...X...", "..XXX..", "XXXXXXX", "..XXX..", "...X...", "...X..."])


def sparkle(cv, x, y, u):
    blocks(cv, SPARK, x - 7 * u // 2, y - 7 * u // 2, u, C["roll"], INK, max(2, u // 2), 0, shade=False)


def wordmark_stack(cv, cx, cy, u):
    """YATAI over DON (both centred on cx), for the left column; the engine speech bubble owns the
    top centre of the screen once it has moved up, so the wordmark lives out of its way."""
    for word, fill, y in (("YATAI", C["don"], cy - 34), ("DON", C["roll"], cy + 34)):
        cs = word_cells(word)
        blocks(cv, cs, int(cx - bbox_w(cs) * u / 2), int(y - 7 * u / 2), u, fill, INK, max(2, u // 3), u // 2)


def subplate(cv, cx, cy, text, h=32):
    """The 'SimpleStyle' sub-plate: a small pink pixbox."""
    w = int(cv.text_width(text, 24, 900, 1.5)) + 40
    x0, y0 = int(cx - w / 2), int(cy - h / 2)
    pbox(cv, x0, y0, x0 + w, y0 + h, C["pink"], px=3, shadow=4)
    cv.text(cx, cy, text, 24, INK, weight=900, tracking=1.5)


def header_pill(text_s):
    """Entry header: a pixbox tag with a red square bullet."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        size = 24
        tw = cv.text_width(text_s, size, 900)
        x1 = int(min(w - 8, 54 + tw + 24))
        pbox(cv, 4, 12, x1, 62, PAPER, px=3, shadow=4)
        cv.rect(18, 31, 30, 43, C["p1"])
        cv.rect(18, 31, 30, 34, mix(C["p1"], PAPER, 0.5))
        cv.text(42, 38, text_s, size, INK, weight=900, anchor="lm", max_w=x1 - 56)
        return cv.result()
    return draw


# ================================================================== title / camera (attract scene)
CAM_WIN = (320, 110, 640, 480)   # the viewport the parent Lua gives the camera (x, y, w, h)
GROUND_Y = 618                   # top of the title ground strip
PLATE = (420, 630, 860, 676)     # the PRESS DON prompt plate


def f_cam_frame(i, n, w, h):
    """The 'title screen' (image 1296x736, drawn at -8,-8): sky band with pixel clouds and the block
    wordmark above the camera window, Hoshi on a pixel ground strip, the PRESS DON plate. Momo is drawn
    by Lua (lua/front/title/attract_chara.lua) on the other side."""
    cv = Canvas(w, h)
    o = 8
    cv.rect(0, 0, w, h, C["bg0"])
    sky_band(cv, 0, 0, w, o + 120)
    for x, y, u, sm in ((70, 18, 8, False), (250, 52, 6, True), (1010, 20, 8, True), (1130, 56, 6, False)):
        pcloud(cv, x + o, y + o, u, sm)
    ground(cv, 0, o + GROUND_Y, w, h)
    # the window around the camera view
    x0, y0, ww, hh = CAM_WIN
    x0, y0 = x0 + o, y0 + o
    cv.rect(x0 - 3 + 6, y0 - 3 + 6, x0 + ww + 3 + 6, y0 + hh + 3 + 6, INK)      # hard shadow
    cv.rect(x0 - 6, y0 - 6, x0 + ww + 6, y0 + hh + 6, INK)
    cv.rect(x0 - 3, y0 - 3, x0 + ww + 3, y0 + hh + 3, PAPER)
    wordmark_stack(cv, o + LEFT_CX, o + 196, 7)
    subplate(cv, o + LEFT_CX, o + 318, "SimpleStyle", 36)
    for x, y, u in ((1090, 170, 5), (1180, 250, 4), (1120, 340, 4), (70, 420, 4)):
        sparkle(cv, x + o, y + o, u)
    # prompt plate
    px0, py0, px1, py1 = (v + o for v in PLATE)
    pbox(cv, px0, py0, px1, py1, PAPER, px=3, shadow=5)
    pixtext(cv, px0 + 62, py0 + 12, "PRESS DON", 3, C["don"], INK, 1)
    cv.rect(px0 + 232, py0 + 11, px0 + 235, py1 - 11, C["bg3"])
    cv.text(px0 + 340, (py0 + py1) / 2 + 1, "ドンでスタート", 24, INK, weight=900, max_w=190)
    im = cv.result()
    im.paste(CLEAR, (x0, y0, x0 + ww, y0 + hh))
    return im


def f_cloud(i, n, w, h):
    """Speech bubble over the camera window: a pixbox with a stair tail."""
    cv = Canvas(w, h)
    bot = h - 52
    pbox(cv, 6, 6, w - 10, bot, PAPER, px=3, shadow=5)
    cx, u = w // 2 - 6, 6
    for r in range(5):                                   # ink stair, then the paper inside it
        half = (4 - r) * u + u
        cv.rect(cx - half - 3, bot + r * u - (3 if r == 0 else 0), cx + half + 3, bot + (r + 1) * u, INK)
    for r in range(5):
        half = (4 - r) * u + u
        cv.rect(cx - half, bot - 3 if r == 0 else bot + r * u, cx + half, bot + (r + 1) * u - (3 if r == 4 else 0) - 3 * (r < 4), PAPER)
    return cv.result()


def f_cloud_text(text_lines, size):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        step = size * 1.38
        y0 = h / 2 - step * (len(text_lines) - 1) / 2
        for k, ln in enumerate(text_lines):
            cv.text(w / 2, y0 + k * step, ln, size, INK, weight=800, max_w=w - 16)
        return cv.result()
    return draw


def f_live_icon(i, n, w, h):
    """Blinking record square (7 frames, steps in whole pixels)."""
    cv = Canvas(w, h)
    k = (3, 3, 2, 2, 2, 3, 3)[i % 7]
    r = k * 4
    blocks(cv, {(x, y) for x in range(2 * k) for y in range(2 * k)}, w / 2 - r, h / 2 - r, 4, C["p1"], INK, 2)
    return cv.result()


def f_live_text(i, n, w, h):
    cv = Canvas(w, h)
    wd = word_w("LIVE") * 3
    pixtext(cv, (w - wd) / 2, h / 2 - 10, "LIVE", 3, PAPER, INK, 1)
    return cv.result()


# ---- the demo scene inside the camera window (own Lua draws it under the camera feed)
DRUM_BODY = cells(["X" * 22] * 12)
DRUM_RIM = cells(["X" * 22, "X" * 22])
DRUM_FACE = cells(["....XXXXXXXXXXXXXX....", ".XXXXXXXXXXXXXXXXXXXX.", "XXXXXXXXXXXXXXXXXXXXXX",
                   ".XXXXXXXXXXXXXXXXXXXX.", "....XXXXXXXXXXXXXX...."])
DRUM_DENT = cells(["......XXXXXXXX......", ".XXXXXXXXXXXXXXXXXX.", "..XXXXXXXXXXXXXXXX..", "......XXXXXXXX......"])
LANE = (16, 170, 624, 266)       # window-local lane box
TARGET = (104, 218)              # window-local hit target centre


def f_scene_window(i, n, w, h):
    from .game import note_disk
    cv = Canvas(w, h)
    cv.rect(0, 0, w, h, C["bg0"])
    sky_band(cv, 0, 0, w, 120)
    for x, y, u, sm in ((40, 22, 6, False), (330, 34, 5, True), (520, 18, 6, False)):
        pcloud(cv, x, y, u, sm)
    gy = 396
    ground(cv, 0, gy, w, h)
    # the lane: a flat strip in an 8-bit frame, with the hit target
    x0, y0, x1, y1 = LANE
    pbox(cv, x0, y0, x1, y1, C["bg3"], px=3, shadow=4)
    cv.rect(x0 + 6, y0 + 6, x1 - 6, y0 + 9, mix(C["bg3"], INK, 0.12))
    tx, ty = TARGET
    cv.circle(tx, ty, 36, fill=INK)
    cv.circle(tx, ty, 33, fill=mix(C["bg3"], PAPER, 0.55))
    cv.circle(tx, ty, 27, fill=C["bg3"])
    # the taiko drum standing on the ground, centred
    u, cx = 6, w // 2
    bx, by = cx - 11 * u, gy - 12 * u + 10
    blocks(cv, DRUM_BODY, bx, by, u, C["don"], INK, 3, 5)
    blocks(cv, DRUM_RIM, bx, by, u, C["roll"], INK, 3, 0)
    blocks(cv, DRUM_RIM, bx, by + 10 * u, u, C["roll"], INK, 3, 0)
    for k in range(4):                                      # studs
        for yy in (3, 6):
            cv.rect(bx + (3 + k * 5) * u, by + yy * u, bx + (4 + k * 5) * u, by + (yy + 1) * u, PAPER)
    fx, fy = bx, by - 5 * u + 2
    blocks(cv, DRUM_FACE, fx, fy, u, C["bg2"], INK, 3, 0, shade=False)
    for c, r in DRUM_DENT:
        cv.rect(fx + (c + 1) * u, fy + r * u + u // 2, fx + (c + 2) * u, fy + (r + 1) * u + u // 2, C["bg3"])
    # LIVE plate (the engine draws the red square + LIVE on it)
    pbox(cv, 494, 428, 626, 464, INK, px=3, shadow=0, border=INK)
    return cv.result()


def f_scene_char(char):
    def draw(i, n, w, h):
        expr = ("idle", "good", "blink", "combo")[i]
        return mascot.sized(mascot.MAIN if char == "momo" else mascot.BUDDY, expr, 170)
    return draw


def build_scene(G):
    from .atlas import OwnSubset
    sub = OwnSubset(G, "title", "ss_scene")
    sub.add("window", [f_scene_window(0, 1, *CAM_WIN[2:])])
    for ch in ("momo", "hoshi"):
        sub.add(ch, [f_scene_char(ch)(k, 4, 170, 170) for k in range(4)])
    from .game import note_disk
    for key, col in (("note_don", C["don"]), ("note_ka", C["ka"])):
        cv = Canvas(64, 64)
        note_disk(cv, 32, 32, 25, col)
        sub.add(key, [cv.result()])
    return sub.write()


def build_camera(G):
    w = SubsetWriter(G, "title", "camera")
    w.put("background", f_cam_frame)
    w.put("camera_cloud", f_cloud)
    w.put("camera_cloud_text_1", f_cloud_text(["カメラにうつってみてね！"], 48))
    w.put("camera_cloud_text_2", f_cloud_text(["たいこをたたいて", "スタート！"], 48))
    w.put("live_icon", f_live_icon)
    w.put("live_text", f_live_text)
    kept = {"background", "camera_cloud", "camera_cloud_text_1", "camera_cloud_text_2", "live_icon", "live_text"}
    for k in green_json("title", "camera"):
        if k not in kept:
            w.put_blank(k)     # advert panels, costume art, parent characters: not used by this style
    return w.write() + build_scene(G)


# ================================================================== title / warning
def f_flat(col):
    def draw(i, n, w, h):
        return Canvas(w, h, bg=col, ss=1).result()
    return draw


FLOOR_Y = 450       # the floor line inside the warning board (screen y)


def f_warning_box(i, n, w, h):
    cv = Canvas(w, h)
    L, T, R, B = 40, 24, 1240, 516
    pbox(cv, L, T, R, B, PAPER, px=3, shadow=6)
    cv.rect(L + 3, T + 3, R - 3, T + 70, C["roll"])                 # header band
    cv.rect(L + 3, T + 70, R - 3, T + 73, INK)
    cv.rect(L + 3, T + 3, R - 3, T + 6, mix(C["roll"], PAPER, 0.5))
    # warning triangle (pixel)
    tri = {(x, y) for y in range(8) for x in range(7 - y, 8 + y)}
    blocks(cv, tri, 556, T + 12, 6, PAPER, INK, 2, shade=False)
    for y in (3, 4, 5):
        cv.rect(556 + 7 * 6, T + 12 + y * 6, 556 + 8 * 6, T + 12 + (y + 1) * 6, INK)
    cv.rect(556 + 7 * 6, T + 12 + 6 * 6 + 3, 556 + 8 * 6, T + 12 + 7 * 6 - 3, INK)
    cv.text(676, T + 37, "注意", 36, INK, weight=900, anchor="lm", tracking=14)
    lines = ["バチ以外で太鼓をたたかないでね。",
             "力まかせにたたかず、リズムを楽しんでね。",
             "まわりに気をつけて、広い場所で遊んでね。",
             "長く遊ぶときは、休けいしてね。"]
    for k, s in enumerate(lines):
        y = 168 + k * 82
        blocks(cv, {(0, 0), (1, 0), (0, 1), (1, 1)}, 584, y - 6, 6, C["p1"], INK, 2, shade=False)
        cv.text(612, y, s, 24, INK, anchor="lm", max_w=598)
    # the floor the mascots stand on
    ground(cv, L + 3, FLOOR_Y + 6, R - 3, B - 3)
    return cv.result()


def f_x(fill, outline):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        k = 13
        u = (min(w, h) - 16) // k
        cs = set()
        for t in range(k):
            for d in (-1, 0, 1):
                for x in (t + d, k - 1 - t + d):
                    if 0 <= x < k:
                        cs.add((x, t))
        blocks(cv, cs, (w - k * u) // 2, (h - k * u) // 2, u, fill, outline, 6, shade=False)
        return cv.result()
    return draw


def f_bachi(i, n, w, h):
    """A pixel drumstick lying at 45 degrees with a round tip."""
    cv = Canvas(w, h)
    u = 12
    stick = {(t + 1 + d, 11 - t) for t in range(9) for d in (0, 1)}
    blocks(cv, stick, 4, 2, u, C["tower"], INK, 4)
    tip = {(x, y) for x in range(3) for y in range(3)}
    blocks(cv, {(x + 9, y) for x, y in tip}, 4, 2, u, mix(C["tower"], PAPER, 0.35), INK, 4)
    return cv.result()


def f_bachi_hit(i, n, w, h):
    cv = Canvas(w, h)
    u = 12
    cs = {(x, 6) for x in range(13)} | {(6, y) for y in range(13)}
    cs |= {(6 + s * k, 6 + t * k) for k in range(1, 5) for s in (-1, 1) for t in (-1, 1)}
    cs |= {(x, y) for x in range(5, 8) for y in range(5, 8)}
    blocks(cv, cs, (w - 13 * u) // 2, (h - 13 * u) // 2, u, C["roll"], INK, 4)
    return cv.result()


def f_shadow(i, n, w, h):
    cv = Canvas(w, h)
    col = mix(C["bg3"], INK, 0.22)
    u = h // 5
    for r, half in enumerate((0.28, 0.44, 0.5, 0.44, 0.28)):
        cv.rect(w / 2 - w * half, r * u, w / 2 + w * half, (r + 1) * u, col)
    return cv.result()


WARN_EXPR0 = ["sad", "sad", "fail"]
WARN_EXPR1 = ["idle", "good", "idle", "combo", "good", "idle", "sad", "fail", "sad"]


def f_chara0(i, n, w, h):
    im = blank(w, h)
    put_sprite(im, "hoshi", WARN_EXPR0[i % 3], 5, w / 2, FLOOR_Y + 16 - 138, frame=i % 2)
    return im


def f_chara1(i, n, w, h):
    im = blank(w, h)
    put_sprite(im, "momo", WARN_EXPR1[i % 9], 7, w / 2, FLOOR_Y + 16 - 96, frame=i % 2)
    return im


def build_warning(G):
    w = SubsetWriter(G, "title", "warning")
    w.put("background", f_flat(C["bg0"]))
    w.put("warning_box", f_warning_box)
    w.put("x_red", f_x(C["p1"], INK))
    w.put("x_lightred", f_x(mix(PAPER, C["p1"], 0.45), mix(PAPER, INK, 0.4)))
    w.put("bachi", f_bachi)
    w.put("bachi_hit", f_bachi_hit)
    w.put("chara_0", f_chara0)
    w.put("chara_1", f_chara1)
    # shadows sit under the feet (centre x of each mascot, just below the floor line)
    w.put("chara_0_shadow", f_shadow, entry={"x": 124 + 88 - 72, "y": FLOOR_Y + 8})
    w.put("chara_1_shadow", f_shadow, entry={"x": 292 + 120 - 72, "y": FLOOR_Y + 8})
    return w.write()


def build_movie(G):
    w = SubsetWriter(G, "title", "movie")
    w.put("background", f_flat(C["bg0"]))     # 8x8 texture stretched by the engine
    return w.write()


# ================================================================== entry
def build_background(G):
    """entry/background: bg is a 16x640 strip the engine stretches; shops_left/right carry the pre-join
    scene (clouds + the two mascots on the ground; the mode boards cover them once a player joins);
    tower = the 'PRESS DON' window; shops_center = the ground strip; the rest is blanked."""
    w = SubsetWriter(G, "entry", "background")

    def bg(i, n, w_, h_):
        cv = Canvas(w_, h_, ss=1)
        cv.rect(0, 0, w_, h_, C["bg0"])
        cv.rect(0, 0, w_, 124, C["sky"])
        cv.rect(0, 124, w_, 132, mix(C["sky"], C["bg0"], 0.5))
        return cv.result()
    w.put("bg", bg)

    def side(char, cx, clouds):
        def draw(i, n, w_, h_):
            cv = Canvas(w_, h_)
            for x, y, u, sm in clouds:
                pcloud(cv, x, y, u, sm)
            im = cv.result()
            put_sprite(im, char, "idle", 6, cx, 548)
            return im
        return draw
    w.put("shops_left", side("momo", 410, [(380, 40, 6, True), (60, 150, 6, False)]))
    w.put("shops_right", side("hoshi", 102, [(250, 92, 6, True), (380, 150, 6, True)]))

    def tower(i, n, w_, h_):
        cv = Canvas(w_, h_)
        pbox(cv, 4, 4, w_ - 10, h_ - 34, PAPER, px=3, shadow=5)
        pixtext(cv, w_ / 2 - word_w("PRESS DON") * 4 / 2, 20, "PRESS DON", 4, C["don"], INK, 2)
        cv.text(w_ / 2, 78, "ドンをたたいて", 24, INK, weight=900, max_w=w_ - 40)
        cv.text(w_ / 2, 106, "エントリー", 24, INK, weight=900, max_w=w_ - 40)
        cv.rect(w_ / 2 - 12, h_ - 34, w_ / 2 + 12, h_ - 31, PAPER)
        cv.rect(w_ / 2 - 12, h_ - 31, w_ / 2 + 12, h_ - 22, INK)
        cv.rect(w_ / 2 - 9, h_ - 31, w_ / 2 + 9, h_ - 25, PAPER)
        cv.rect(w_ / 2 - 6, h_ - 25, w_ / 2 + 6, h_ - 22, PAPER)
        return cv.result()
    w.put("tower", tower)
    w.put("shops_center", lambda i, n, w_, h_: _ground_img(w_, h_), entry={"x": 0, "y": 540})
    for k in ("people", "lights"):
        w.put_blank(k)
    return w.write()


def _ground_img(w, h):
    cv = Canvas(w, h)
    ground(cv, 0, 6, w, h)
    return cv.result()


def build_global(G):
    w = SubsetWriter(G, "entry", "global")
    w.put("player_entry_en", header_pill("Player Entry"))
    w.put("player_entry_ja", header_pill("プレイヤーエントリー"))
    w.put("name_entry_ja", header_pill("ネームエントリー"))
    return w.write()


def build_wait(G):
    w = SubsetWriter(G, "entry", "wait")
    w.put("cloud", lambda i, n, w_, h_: card_img(w_, h_, C["bg2"], (6, 6, 12, 12)))
    return w.write()


# ---- mode select
def slice_piece(width_total, x0, x1, fill, px=3, grey_edge=False):
    def draw(i, n, w, h):
        cv = Canvas(width_total, h)
        pbox(cv, 2, 2, width_total - 6, h - 8, fill, px=px, shadow=4,
             border=mix(INK, PAPER, 0.45) if grey_edge else None)
        return cv.result().crop((x0, 0, x1, h))
    return draw


def build_mode_select(G):
    w = SubsetWriter(G, "entry", "mode_select")
    w.put("box", slice_piece(116, 0, 116, C["sky"]))
    w.put("box_grey", slice_piece(116, 0, 116, C["bg3"], grey_edge=True))
    for pre, fill, ge in (("box_highlight", C["clear"], False), ("box_highlight_grey", C["bg2"], True)):
        w.put(pre + "_left", slice_piece(68, 0, 30, fill, 6, ge))
        w.put(pre + "_center", slice_piece(68, 30, 38, fill, 6, ge))
        w.put(pre + "_right", slice_piece(68, 38, 68, fill, 6, ge))

    def f_arrow(i, n, w_, h_):
        cv = Canvas(w_, h_)
        cursor(cv, w_ / 2, h_ / 2, 6)
        return cv.result()
    w.put("arrow", f_arrow)
    w.put("flash", lambda i, n, w_, h_: Canvas(w_, h_, bg=PAPER, ss=1).result())

    def f_new(i, n, w_, h_):
        cv = Canvas(w_, h_)
        pbox(cv, 6, 6, w_ - 10, h_ - 10, C["p1"], px=3, shadow=4)
        cv.text(w_ / 2 - 2, h_ / 2 - 2, "新", 48, PAPER, anchor="mm")
        return cv.result()
    w.put("badge_new", f_new)

    def f_one(grey):
        def draw(i, n, w_, h_):
            cv = Canvas(w_, h_)
            pbox(cv, 2, 2, w_ - 6, h_ - 6, C["bg3"] if grey else C["p1"], px=3, shadow=3)
            cv.text(w_ / 2 - 1, h_ / 2 - 2, "1人用", 24, INK if grey else PAPER, max_w=w_ - 16)
            return cv.result()
        return draw
    w.put("badge_one_player", f_one(False))
    w.put("badge_one_player_grey", f_one(True))

    def f_two(i, n, w_, h_):
        cv = Canvas(w_, h_)
        pbox(cv, 8, 8, 206, 392, PAPER, px=3, shadow=5)
        for k, (xa, xb) in enumerate(((206, 218), (218, 230), (230, 242))):   # stair tail
            cv.rect(xa, 74 + k * 6, xb + 3, 110 - k * 6, INK)
        for k, (xa, xb) in enumerate(((206, 218), (218, 230), (230, 242))):
            cv.rect(xa - 3 if k == 0 else xa, 77 + k * 6, xb, 107 - k * 6, PAPER)
        vtext(cv, 150, 34, "2人で遊べる！", 36, C["red_t"], max_h=340)
        vtext(cv, 82, 34, "いっしょに演奏しよう！", 24, INK, max_h=346)
        return cv.result()
    w.put("badge_two_player", f_two)

    cols = [C["ka"], C["normal"], C["don"], C["ura"], C["clear"]]

    def f_star(i, n, w_, h_):
        cv = Canvas(w_, h_)
        u = max(3, min(w_, h_) // 4)
        blocks(cv, PLUS, w_ / 2 - 1.5 * u, h_ / 2 - 1.5 * u, u, cols[i % 5], INK, 2, shade=False)
        return cv.result()
    w.put("star", f_star)
    return w.write()


# ---- side select
NINE = {"top_left": (0, 0), "top": (0, 1), "top_right": (0, 2), "left": (1, 0), "center": (1, 1),
        "right": (1, 2), "bottom_left": (2, 0), "bottom": (2, 1), "bottom_right": (2, 2)}


def nine_piece(row, col, fill, border=None, px=3):
    def draw(i, n, w, h):
        cv = Canvas(192, 192)
        pbox(cv, 0, 0, 186, 186, fill, px=px, shadow=4, border=border)
        return cv.result().crop((col * 64, row * 64, col * 64 + 64, row * 64 + 64))
    return draw


def f_pill(fill, ring=False, icon=None):
    """A pixbox pill. icon "1P"/"2P": the engine centres its label away from the middle (left of centre
    for 1P, right for 2P), so a paper disc with the player tag fills the other end."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        if ring:
            pixring(cv, 2, 2, w - 2, h - 2, 6, INK)
        else:
            pbox(cv, 2, 2, w - 6, h - 6, fill, px=3, shadow=4)
            if icon:
                col = C["p1"] if icon == "1P" else C["p2"]
                u, r = 4, 5
                cx = 50 if icon == "1P" else w - 56
                cy = (h - 4) // 2
                blocks(cv, pix_disc(r), cx - r * u, cy - r * u, u, PAPER, INK, 3, shade=False)
                tw = word_w(icon) * 2
                blocks(cv, word_cells(icon), cx - tw // 2, cy - 7, 2, col, INK, 0, shade=False)
        return cv.result()
    return draw


def f_pedestal(col):
    """A short pixel taiko drum the mascot stands on (the cream drumhead is the standing surface)."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pbox(cv, 36, 28, w - 44, 80, col, px=3, shadow=4)
        cv.rect(42, 34, w - 50, 46, C["bg2"])
        cv.rect(42, 46, w - 50, 49, INK)
        cv.rect(42, 70, w - 50, 75, C["roll"])
        for x in range(60, w - 56, 36):
            cv.rect(x, 55, x + 6, 61, PAPER)
        return cv.result()
    return draw


def f_puff(i, n, w, h):
    """Four frames of a one-shot poof, drawn in whole pixel blocks."""
    cv = Canvas(w, h)
    cx, cy, u = w / 2, h / 2, 8

    def blob(x, y, r):
        blocks(cv, pix_disc(r), x - r * u, y - r * u, u, PAPER, INK, 3, shade=False)
    if i == 0:
        for dx, dy, r in ((0, 0, 9), (-62, 20, 5), (60, 22, 5), (-18, -50, 6), (30, 52, 5)):
            blob(cx + dx, cy + dy, r)
    else:
        cnt, rad, r = ((0, 0, 0), (9, 100, 3), (14, 128, 2), (18, 150, 1))[i]
        for k in range(cnt):
            a = 2 * math.pi * k / cnt + i * 0.3
            rr = rad * (0.8 + 0.2 * ((k * 7) % 3) / 2)
            blob(cx + math.cos(a) * rr, cy + math.sin(a) * rr, r)
    return cv.result()


def footer_img(i, n, w, h):
    """The bottom band under the free-play text: ink rule, red/blue player stripe, tan brick dirt."""
    cv = Canvas(w, h)
    cv.rect(0, 0, w, h, C["bg3"])
    blk = mix(C["bg3"], INK, 0.12)
    for yy in range(36, h, 16):
        for xx in range((((yy - 36) // 16) % 2) * 24, w, 48):
            cv.rect(xx, yy, xx + 24, min(yy + 8, h), blk)
    cv.rect(0, 0, w, 3, INK)
    cv.rect(0, 3, w // 2, 15, C["p1"])
    cv.rect(w // 2, 3, w, 15, C["p2"])
    cv.rect(0, 15, w, 18, INK)
    cv.rect(w // 2 - 2, 3, w // 2 + 1, 18, INK)
    return cv.result()


def build_ss_char(G):
    """Hoshi for the 2P pedestal (Momo comes from the shared mascot frames): idle + blink, 170 px."""
    from .atlas import OwnSubset
    sub = OwnSubset(G, "entry", "ss_char")
    sub.add("hoshi", [mascot.sized(mascot.BUDDY, e, 170) for e in ("idle", "blink")])
    return sub.write()


def build_side_select(G):
    w = SubsetWriter(G, "entry", "side_select")

    w.put("footer", footer_img, entry={"x": 0, "y": 590})
    w.put("footer_left", lambda i, n, w_, h_: blank(w_, h_), entry={"x": 0, "y": 601})
    w.put("footer_right", lambda i, n, w_, h_: blank(w_, h_), entry={"x": 640, "y": 601})
    for k, (r, c) in NINE.items():
        w.put("box_" + k, nine_piece(r, c, PAPER))
    w.put("1P", f_pill(C["p1"], icon="1P"))
    w.put("1P_highlight", f_pill(C["clear"], icon="1P"))
    w.put("2P", f_pill(C["p2"], icon="2P"))
    w.put("2P_highlight", f_pill(C["clear"], icon="2P"))
    w.put("1P2P_outline", f_pill(None, ring=True))
    w.put("cancel", f_pill(C["bg3"]))
    w.put("cancel_highlight", f_pill(C["clear"]))
    w.put("cancel_outline", f_pill(None, ring=True))
    w.put("red_drum", f_pedestal(C["p1"]))
    w.put("blue_drum", f_pedestal(C["p2"]))
    w.put("cloud", f_puff)
    return w.write()


# ---- name entry
def build_name_entry(G):
    w = SubsetWriter(G, "entry", "name_entry")

    def disc(fill, r, u, inner=False):
        def draw(i, n, w_, h_):
            cv = Canvas(w_, h_)
            x0, y0 = w_ / 2 - r * u, h_ / 2 - r * u
            blocks(cv, pix_disc(r), x0, y0, u, fill, INK, u // 2 if u > 4 else 3, shade=False)
            if inner:
                blocks(cv, pix_ring(r - 2, r - 3), x0 + 2 * u, y0 + 2 * u, u, mix(fill, PAPER, 0.55), INK, 0, shade=False)
            return cv.result()
        return draw
    w.put("plate_red", disc(C["p1"], 7, 4))
    w.put("plate_yellow", disc(C["clear"], 7, 4))
    w.put("big_red", disc(C["p1"], 6, 7, True))
    w.put("big_yellow", disc(C["clear"], 6, 7, True))

    def ring(i, n, w_, h_):
        cv = Canvas(w_, h_)
        blocks(cv, pix_ring(7, 5), w_ / 2 - 28, h_ / 2 - 28, 4, INK, INK, 0, shade=False)
        return cv.result()
    w.put("ring_outline", ring)
    w.put("banner_1p", lambda i, n, w_, h_: card_img(w_, h_, C["p1"], (10, 20, 16, 28), 3, 5))
    w.put("banner_2p", lambda i, n, w_, h_: card_img(w_, h_, C["p2"], (10, 20, 16, 28), 3, 5))
    w.put("button_red", f_pill(C["p1"]))
    w.put("button_yellow", f_pill(C["clear"]))
    w.put("button_outline", f_pill(None, ring=True))

    def arrow(i, n, w_, h_):
        cv = Canvas(w_, h_)
        cursor(cv, w_ / 2, h_ / 2, 4)
        return cv.result()
    w.put("arrow", arrow)
    return w.write()


# ---- costume select (dress-up dialog; needs an online account, so generic)
def build_costume_select(G):
    w = SubsetWriter(G, "entry", "costume_select")
    for suf, col in (("1p", C["p1"]), ("2p", C["p2"])):
        for k, (r, c) in NINE.items():
            w.put(f"box_{k}_{suf}", nine_piece(r, c, mix(PAPER, col, 0.18)))
        w.put("text_highlight_" + suf, lambda i, n, w_, h_, col=col: card_img(
            w_, h_, mix(PAPER, col, 0.4), (2, 2, 6, 6), 3, 3))
        w.put("item_box_" + suf, lambda i, n, w_, h_, col=col: card_img(
            w_, h_, mix(PAPER, col, 0.25), (4, 4, 10, 10), 3, 4))
    w.put("item_box_highlighted", lambda i, n, w_, h_: card_img(w_, h_, C["clear"], (4, 4, 10, 10), 6, 4))

    def arrow(i, n, w_, h_):
        cv = Canvas(w_, h_)
        cursor(cv, w_ / 2, h_ / 2, 4)
        return cv.result()
    w.put("blue_arrow", arrow)
    w.put("cloud", lambda i, n, w_, h_: card_img(w_, h_, C["bg2"], (6, 6, 12, 12)))

    def shirt(i, n, w_, h_):
        cv = Canvas(w_, h_)
        cs = cells(["XX.....XX", "XXXX.XXXX", "XXXXXXXXX", ".XXXXXXX.", "..XXXXX..", "..XXXXX..", "..XXXXX.."])
        u = max(3, min(w_ // 11, h_ // 9))
        blocks(cv, cs, w_ / 2 - 4.5 * u, h_ / 2 - 3.5 * u, u, C["pink"], INK, 2)
        return cv.result()
    w.put("costume", shirt)

    def head_body(i, n, w_, h_):
        cv = Canvas(w_, h_)
        cs = cells([".XXX.", "XXXXX", "XXXXX", ".XXX.", "XXXXX", "XXXXX"])
        blocks(cv, cs, w_ / 2 - 20, 10, 8, C["normal"], INK, 2)
        return cv.result()
    w.put("head_body", head_body)

    def default(i, n, w_, h_):
        im = blank(w_, h_)
        put_sprite(im, "momo", "idle", max(1, (h_ - 8) // 32), w_ / 2, h_ - 4)
        return im
    w.put("default", default)

    def preset(num, col):
        def draw(i, n, w_, h_):
            cv = Canvas(w_, h_)
            pbox(cv, 4, 4, w_ - 8, h_ - 8, col, px=3, shadow=4)
            cv.text(w_ / 2 - 2, h_ / 2 - 2, str(num), 36, INK if col == C["clear"] else PAPER)
            return cv.result()
        return draw
    w.put("preset_1", preset(1, C["clear"]))
    w.put("preset_2", preset(2, C["p1"]))
    w.put("preset_3", preset(3, C["p2"]))

    def random_(i, n, w_, h_):
        cv = Canvas(w_, h_)
        pbox(cv, 6, 6, w_ - 10, h_ - 10, C["ura"], px=3, shadow=4)
        cv.text(w_ / 2 - 2, h_ / 2 - 2, "?", 48, PAPER)
        return cv.result()
    w.put("random", random_)
    w.put("random_item", lambda i, n, w_, h_: _text_img(w_, h_, "?", 48))
    w.put_blank("costume_example")
    w.put_blank("hiroba_ad")
    return w.write()


def _text_img(w, h, s, size, col=None):
    cv = Canvas(w, h)
    cv.text(w / 2, h / 2, s, size, col or INK)
    return cv.result()


# ================================================================== settings
def build_settings(G):
    w = SubsetWriter(G, "settings", "background")

    def bg(i, n, w_, h_):
        cv = Canvas(w_, h_)
        cv.rect(0, 0, w_, h_, C["bg0"])
        sky_band(cv, 0, 0, w_, 104)
        for x, y, u, sm in ((520, 14, 6, True), (1100, 20, 8, False)):
            pcloud(cv, x, y, u, sm)
        ground(cv, 0, 548, w_, h_)
        for x, y, u in ((640, 330, 4), (1130, 300, 5), (1236, 200, 4)):
            sparkle(cv, x, y, u)
        im = cv.result()
        put_sprite(im, "momo", "idle", 5, 790, 566)       # the two mascots wait on the ground until a card covers them
        put_sprite(im, "hoshi", "idle", 5, 1000, 566)
        return im
    w.put("background", bg)

    w.put("footer", footer_img)
    # the description card: the engine draws its text black, so it stays a white card
    w.put("overlay", lambda i, n, w_, h_: card_img(w_, h_, PAPER, (14, 2, 18, 10), 3, 5))
    w.put("title", lambda i, n, w_, h_: card_img(w_, h_, PAPER, (8, 8, 14, 20), 3, 6))
    w.put("title_highlight", lambda i, n, w_, h_: card_img(w_, h_, C["clear"], (8, 8, 14, 20), 6, 6))

    def arrow(i, n, w_, h_):
        cv = Canvas(w_, h_)
        cursor(cv, w_ / 2 + 2, h_ / 2, 6)
        return cv.result()
    w.put("blue_arrow", arrow)
    n = w.write()

    w = SubsetWriter(G, "settings", "box")
    w.put("box", lambda i, n, w_, h_: card_img(w_, h_, C["sky"], (4, 4, 10, 14)))

    def box_hl(i, n, w_, h_):
        cv = Canvas(w_, h_)
        pbox(cv, 4, 4, w_ - 10, h_ - 14, C["clear"], px=6, shadow=4)
        cursor(cv, 30, (h_ - 10) / 2, 4, PAPER)
        return cv.result()
    w.put("box_highlight", box_hl)
    n += w.write()

    w = SubsetWriter(G, "settings", "option")
    w.put("button_off", lambda i, n, w_, h_: card_img(w_, h_, PAPER, (6, 6, 12, 16)))
    w.put("button_on", lambda i, n, w_, h_: card_img(w_, h_, C["clear"], (6, 6, 12, 16), 6, 4))
    n += w.write()
    return n


# ================================================================== loading
def f_loading_warning(i, n, w, h):
    cv = Canvas(w, h)
    pbox(cv, 4, 4, w - 10, h - 10, PAPER, px=3, shadow=6)
    cv.rect(7, 7, w - 13, 40, C["sky"])
    cv.rect(7, 40, w - 13, 43, INK)
    pcloud(cv, 40, 12, 4, True)
    pcloud(cv, w - 130, 14, 4)
    wordmark(cv, w / 2, 226, 5)
    cv.rect(60, 280, w - 66, 283, C["bg3"])
    pixtext(cv, w / 2 - word_w("NOTICE") * 3 / 2, 300, "NOTICE", 3, C["roll"], INK, 1)
    items = [("ときどき休けいして、音量はほどよく。", "Take breaks and keep the volume comfortable."),
             ("バチ以外で太鼓をたたかないでね。", "Only strike the drum with the sticks.")]
    for k, (ja, en) in enumerate(items):
        y = 362 + k * 78
        cv.text(w / 2, y, ja, 24, INK, max_w=w - 70)
        cv.text(w / 2, y + 30, en, 12, C["text2"], max_w=w - 70)
    im = cv.result()
    put_sprite(im, "momo", "idle", 4, w / 2 - 66, 170)
    put_sprite(im, "hoshi", "idle", 3, w / 2 + 70, 170)
    return im


def build_loading(G):
    w = SubsetWriter(G, "loading", "kidou")
    w.put("warning", f_loading_warning)
    return w.write()


# ================================================================== Lua
INK_LUA = "{ 58, 38, 51, 255 }"
LUA_PATCHES = {
    # no Bana-passport advert panels on the sides; the attract scene keeps the camera + cloud
    "title/attract_scene.lua": [
        ('require("title/bana_advert")\n', ""),
        ("    self.bana_advert_1 = BanaAdvertisement.new()\n    self.bana_advert_2 = BanaAdvertisement.new()\n", ""),
        ("    self.bana_advert_1:update(current_ms)\n    self.bana_advert_2:update(current_ms)\n", ""),
        ("    self.bana_advert_1:draw(34, 157)\n    self.bana_advert_2:draw(1011, 157)\n", ""),
    ],
    # no after-image of the previous pose (a faded, differently posed copy of a pixel sprite looks like a glitch)
    "title/warning_screen.lua": [
        ("    if -1 < self.chara_1_frame.attribute - 1 and", "    if false and -1 < self.chara_1_frame.attribute - 1 and"),
    ],
    # the demo window (baked scene + flat notes) under the camera feed; the mascots stand beside it
    "title/attract_camera.lua": [
        ('require("title/attract_chara")\n',
         'require("title/attract_chara")\nlocal SS_UI = require("global.ss_ui")\n'),
        ("    if self.viewport then\n        camera.draw(",
         "    if self.viewport then\n"
         "        self.chara:draw_window(self.viewport.x, self.viewport.y)\n"
         "        camera.draw("),
        ("    self.chara:draw()\n    tex.draw_texture(self.t_background)\n",
         "    tex.draw_texture(self.t_background)\n    self.chara:draw()\n"),
    ],
    # the pre-join scene (PRESS DON window, mascots) is hidden once a player has joined
    "entry/entry.lua": [
        ("    local self = setmetatable({}, Entry)\n", "    local self = setmetatable({}, Entry)\n    SS_ENTRY_JOINED = false\n"),
        ("    tex.draw_texture(self.bg_tower)\n", "    if not SS_ENTRY_JOINED then tex.draw_texture(self.bg_tower) end\n"),
        ("    tex.draw_texture(self.bg_shops_left)\n    tex.draw_texture(self.bg_shops_right)\n",
         "    if not SS_ENTRY_JOINED then\n        tex.draw_texture(self.bg_shops_left)\n        tex.draw_texture(self.bg_shops_right)\n    end\n"),
    ],
    "entry/box.lua": [
        ("local DESC_COLOR   = { 0, 0, 0, 255 }", "local DESC_COLOR   = " + INK_LUA),
        ("{ 255, 255, 255, 255 }, { 109, 68, 24, 255 }, true, 5)", "{ 255, 255, 255, 255 }, " + INK_LUA + ", true, 5)"),
        ("local GREY_FILL, GREY_OUTLINE = { 156, 155, 156, 255 }, { 76, 76, 76, 255 }",
         "local GREY_FILL, GREY_OUTLINE = { 255, 255, 255, 255 }, { 140, 123, 130, 255 }"),
    ],
    # Momo stands on the pedestal where the (disabled) 3D chara would be
    "entry/player.lua": [
        ("EntryPlayer = {}\n", 'local SS_UI = require("global.ss_ui")\nEntryPlayer = {}\n'),
        ("    self.side = side\n",
         "    self.side = side\n    SS_ENTRY_JOINED = true\n    SS_UI.reset()\n    self.ss_mascot = SS_UI.Mascot.new()\n"
         '    self.t_hoshi = tex.get_texture("entry/ss_char/hoshi")\n'),
        ("    local chara_x = move_x + self.drum_offset + self.chara_x_offset\n"
         "    local chara_y = self.chara_y_base + move_y\n",
         "    local chara_x = move_x + self.drum_offset + self.chara_x_offset\n"
         "    local chara_y = self.chara_y_base + move_y\n"
         "    local now = tex.get_current_ms()\n"
         "    if self.side == 0 then\n"
         "        self.ss_mascot:update(now, 100)\n"
         "        self.ss_mascot:draw(chara_x - 10, chara_y - 12, 0.75)\n"
         "    else\n"
         "        local hop = ((now % 600) < 120) and 5 or 0\n"
         "        local f = ((now % 3400) < 120) and 1 or 0\n"
         "        tex.draw_texture(self.t_hoshi, { frame = f, x = chara_x - 95, y = chara_y - 186 - hop })\n"
         "    end\n"),
    ],
}


# ================================================================== README
README = """# YataiDONSimpleStyle

A light, 8-bit style skin for YataiDON. Every screen keeps the layout of its parent skin and is redrawn in
one game-like look: a cream screen with a sky band and pixel clouds, white windows with a thick ink border,
notched corners and a hard drop shadow, segmented pixel meters, and a pixel font. Notes and the lane stay
flat and smooth.

## Characters

Two original pixel mascots appear throughout the skin:

- **Momo**, a pink rabbit with a mint belly, the main character (player and gameplay).
- **Hoshi**, a husky pup in a grey hoodie, the buddy who cheers from the side.

They never stretch or rotate; they hop by whole sprite pixels or swap expression frames.

## Requirements

This skin is a child skin of **PyTaikoGreen**. It only contains the files it replaces; everything else
(screens it does not restyle, sounds, layouts, most scripts) is inherited from the parent. The game installs
the parent automatically when the skin is installed.

## Contents

- `Graphics/` - all textures, drawn from scratch by a generator script (original work).
- `Scripts/` - Lua scripts. A few are adapted from PyTaikoGreen (the parent's scripts with small changes such as
  colours, removed artwork and the mascot hooks); the rest are original. Credit for the adapted scripts goes to
  the PyTaikoGreen authors.
- `Fonts/` - Fusion Pixel Font 12px (https://github.com/TakWolf/fusion-pixel-font, release 2026.10.25),
  licensed under the SIL Open Font License 1.1. The licence texts are in `Fonts/OFL.txt` and
  `Fonts/LICENSES/`.
- `Videos/` - empty placeholder folders, so that no attract videos play.

## Graphics

All graphics are original and generated by code (no photographs, no scanned or copied art, no generated
images). The block-pixel YATAI DON wordmark and the two mascots are part of this generated artwork.

## Licence

Licence of the graphics and scripts of this skin: TBD (to be decided by the author).
The font is under the SIL Open Font License 1.1 (see above).
"""


# ================================================================== build
def configure(ctx):
    pass


def build(ctx):
    G = ctx.G
    n = 0
    for fn in (build_camera, build_warning, build_movie, build_background, build_global, build_wait,
               build_mode_select, build_side_select, build_ss_char, build_name_entry, build_costume_select,
               build_settings, build_loading):
        n += fn(G)
    for d in ("op_videos", "attract_videos"):
        p = os.path.join(ctx.out, "Videos", d)
        os.makedirs(p, exist_ok=True)
        with open(os.path.join(p, ".keep"), "w", encoding="utf-8", newline="\n") as f:
            f.write("")
    with open(os.path.join(ctx.out, "README.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write(README)
    return n + 3
