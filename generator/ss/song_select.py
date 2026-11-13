"""Song select (Graphics/song_select, Scripts/song_select), light 8-bit direction: Green's layout and
Lua kept, every texture redrawn as pixel-art UI (ink borders, notched corners, hard shadows, flat
light fills, pixel glyphs, pixel mascots). Lua patches only recolour Green's text (light boards:
ink text with a paper outline) and record the chosen course/level for the enso info panel."""
from __future__ import annotations

import math

from . import mascot
from .atlas import OwnSubset, SubsetWriter
from .style import C, COURSES, Canvas, alpha, hexc, hue, mix, pixbox, pixdither, vtext

NAME = "song_select"
OWNS = ["Graphics/song_select", "Scripts/song_select"]
SCREEN = "song_select"
LANG = "ja"

INK = C["ink"]
PAPER = C["paper"]

# genre tints of box/background frames 0..15 (the frame order of the engine's genre_to_ref_frame);
# 10 is the multi-genre frame (drawn as a soft hue sweep)
GENRE_TINT = ["#3FCA45", "#3C99C9", "#FEB531", "#C8CFDD", "#FF6C72", "#99D346", "#D78E21", "#AB56E2",
              "#FF753A", "#FDB387", None, "#E6D55B", "#51CED6", "#3D5FCA", "#FF6C72", "#3D8EE5"]
# TextureIndex frames of the box boards: 0 NONE (recoloured by the engine's colortransform shader from
# the stock green 142,212,30 to the genre colour), 1 VOCALOID, 2 DEFAULT, 3 RECOMMENDED, 4 FAVORITE, 5 RECENT
SRC_GREEN = (142, 212, 30, 255)
BOARD_ACCENT = [SRC_GREEN, hexc("#3FC4B4"), hexc("#FF8A6B"), None, hexc("#FFC23D"), hexc("#3DB6E3")]

TXT = {
    "song_select": ("曲をえらぶ", "Select a song"),
    "difficulty_select": ("むずかしさをえらぶ", "Choose Difficulty"),
    "back": ("もどる", "Back"),
    "option": ("演奏オプション", "Options"),
    "neiro": ("音色をかえる", "Sounds"),
    "new_song": ("新曲", "New!"),
    "new_song_b": ("新", "New"),
    "limited": ("期間限定", "Limited"),
    "limited_b": ("限定", "Ltd."),
    "fav1": ("1Pのお気に入り", "1P Favorites"),
    "fav2": ("2Pのお気に入り", "2P Favorites"),
    "new_audio": ("新音源", None),
    "old_audio": ("旧音源", None),
    "branch": ("譜面分岐あり", None),
}


def t(key, lang):
    ja, en = TXT[key]
    return en if (lang == "en" and en) else ja


def accent_at(i, y, h):
    """Accent of board frame i (rainbow for RECOMMENDED, by height)."""
    a = BOARD_ACCENT[i]
    return a if a is not None else hue(y / max(1, h), 0.55, 1.0)


# ================================================================== 8-bit drawing helpers
def pgrid(cv, x, y, rows, cell, col, ow=0, ink=None):
    """Draw a bitmap ('X' = pixel) with its top-left at (x, y), `cell` px per bitmap pixel.
    `col` is a colour or fn(cx, cy) -> colour; `ow` px of ink outline around every pixel."""
    ink = ink or INK
    cells = [(cx, cy) for cy, r in enumerate(rows) for cx, ch in enumerate(r) if ch == "X"]
    if ow:
        for cx, cy in cells:
            cv.rect(x + cx * cell - ow, y + cy * cell - ow, x + (cx + 1) * cell + ow, y + (cy + 1) * cell + ow, ink)
    for cx, cy in cells:
        c = col(cx, cy) if callable(col) else col
        cv.rect(x + cx * cell, y + cy * cell, x + (cx + 1) * cell, y + (cy + 1) * cell, c)


def gsize(rows, cell):
    return len(rows[0]) * cell, len(rows) * cell


def pgrid_c(cv, cx, cy, rows, cell, col, ow=0, ink=None):
    """pgrid centred on (cx, cy)."""
    w, h = gsize(rows, cell)
    pgrid(cv, int(round(cx - w / 2)), int(round(cy - h / 2)), rows, cell, col, ow, ink)


def pdisc(cv, cx, cy, r, cell, fill):
    """A stepped (pixel) disc of radius r made of `cell`-px rows."""
    cx, cy = int(round(cx)), int(round(cy))
    n = int(r // cell)
    for k in range(-n, n):
        yc = (k + 0.5) * cell
        half = math.sqrt(max(0.0, r * r - yc * yc))
        hw = int(round(half / cell)) * cell
        if hw > 0:
            cv.rect(cx - hw, cy + k * cell, cx + hw, cy + (k + 1) * cell, fill)


def notch_pts(x0, y0, x1, y1, n):
    return [(x0 + n, y0), (x1 - n, y0), (x1 - n, y0 + n), (x1, y0 + n), (x1, y1 - n), (x1 - n, y1 - n),
            (x1 - n, y1), (x0 + n, y1), (x0 + n, y1 - n), (x0, y1 - n), (x0, y0 + n), (x0 + n, y0 + n)]


def pring(cv, box, t, col, n=3):
    """A hollow notched rectangle ring of thickness t (does not erase what is below)."""
    x0, y0, x1, y1 = (int(round(v)) for v in box)
    m, d = cv.mask()
    s = cv.ss
    d.polygon([(x * s, y * s) for x, y in notch_pts(x0, y0, x1, y1, n)], fill=255)
    nn = max(0, n - t) if n else 0
    d.polygon([(x * s, y * s) for x, y in notch_pts(x0 + t, y0 + t, x1 - t, y1 - t, nn)], fill=0)
    cv.paint(m, col)


def pframe(cv, box, col, t_ink=3, t_col=4, n=3):
    """Selection ring: ink outer ring + a coloured ring inside it."""
    x0, y0, x1, y1 = box
    pring(cv, (x0, y0, x1, y1), t_ink, INK, n)
    pring(cv, (x0 + t_ink, y0 + t_ink, x1 - t_ink, y1 - t_ink), t_col, col, 0)


def plate(cv, x0, y0, x1, y1, fill, shadow=3, px=3):
    pixbox(cv, x0, y0, x1, y1, fill, INK, shadow=shadow, px=px)


def tint(col, k=0.35, base=None):
    return mix(base or PAPER, col, k)


# ---- bitmaps
CLOUD = ["......XXXX......",
         "...XXXXXXXXXX...",
         "..XXXXXXXXXXXXX.",
         ".XXXXXXXXXXXXXXX",
         "XXXXXXXXXXXXXXXX"]
CHEV = ["....X", "...XX", "..XXX", ".XXXX", "XXXXX", ".XXXX", "..XXX", "...XX", "....X"]
PTR = ["XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]
CROWN = ["X...X...X", "XX.XXX.XX", "XXXXXXXXX", "XXXXXXXXX", "XXXXXXXXX", "XXXXXXXXX"]
I_BACK = ["...X...", "..XX...", ".XXXXXX", "XXXXXXX", ".XXXXXX", "..XX...", "...X..."]
I_GEAR = ["..X.X..", ".XXXXX.", "XXX.XXX", ".X...X.", "XXX.XXX", ".XXXXX.", "..X.X.."]
I_NOTE = ["..XXXXX", "..XXXXX", "..X...X", "..X...X", "..X...X", "XXX.XXX", "XXX.XXX"]
I_STAR = [".X.X.X.", ".XXXXX.", "XXXXXXX", ".XXXXX.", ".XXXXX.", ".XX.XX.", "X.....X"]


def pcloud(cv, x, y, cell=4):
    shade = mix(PAPER, C["sky"], 0.55)
    pgrid(cv, x, y, CLOUD, cell, lambda cx, cy: shade if cy == len(CLOUD) - 1 else PAPER)


def sky_band(cv, w, h_sky=96, seed=0):
    cv.rect(0, 0, w, h_sky, C["sky"])
    pixdither(cv, 0, h_sky, w, h_sky + 8, C["sky"], 4)
    spots = [(70, 18, 4), (330, 44, 3), (560, 14, 4)] if seed % 2 == 0 else [(150, 40, 3), (410, 12, 4), (600, 50, 3)]
    for x, y, c in spots:
        pcloud(cv, x + (seed % 5) * 6, y, c)


# ---- pixel course emblem (replaces the round vector emblem everywhere)
def pemblem(cv, cx, cy, r, i):
    cell = 2 if r < 22 else (3 if r < 40 else 6)
    col = C[COURSES[i][0]]
    cx, cy = int(round(cx)), int(round(cy))
    pdisc(cv, cx, cy, r, cell, INK)
    pdisc(cv, cx, cy, r - cell, cell, col)
    g = PAPER if i == 4 else INK
    sq = cell * 2 if r < 40 else cell * 4
    if i <= 3:
        k = i + 1
        sp = sq + cell
        tot = (k - 1) * sp + sq
        for j in range(k):
            x0 = cx - tot // 2 + j * sp
            cv.rect(x0, cy - sq // 2, x0 + sq, cy + sq // 2, g)
    elif i == 4:
        h = sq + cell
        cv.rect(cx - h, cy - h, cx + h, cy + h, g)
        cv.rect(cx - h + cell, cy - h + cell, cx + h - cell, cy + h - cell, col)
        cv.rect(cx - cell, cy - cell, cx + cell, cy + cell, g)
    elif i == 5:
        for j in range(3):
            hw = sq * 2 - j * cell * 2
            yy = cy + (1 - j) * (cell * 3)
            cv.rect(cx - hw, yy - cell, cx + hw, yy + cell, g)
    else:
        cv.rect(cx - sq, cy - sq, cx + sq, cy + sq, g)
        cv.rect(cx - sq // 2, cy - sq // 2, cx + sq // 2, cy + sq // 2, C["dan"])


# ---- pixel crown (clear = silver, fc = gold, dfc = rainbow, outline = empty slot)
def pcrown(cv, cx, cy, kind, cell=4, course=None):
    w, h = gsize(CROWN, cell)
    x, y = int(round(cx - w / 2)), int(round(cy - h / 2))
    if kind == "outline":
        pgrid(cv, x, y, CROWN, cell, C["bg3"], ow=2, ink=mix(INK, PAPER, 0.45))
    elif kind == "dfc":
        pgrid(cv, x, y, CROWN, cell, lambda cx_, cy_: hue(cx_ / 9, 0.55, 1.0), ow=2)
    else:
        pgrid(cv, x, y, CROWN, cell, C["clear"] if kind == "fc" else hexc("#C9CFDA"), ow=2)
    if course is not None:
        bx, by = int(cx + w / 2 - 6), int(cy + h / 2 - 4)
        cv.rect(bx - 2, by - 2, bx + 12, by + 12, INK)
        cv.rect(bx, by, bx + 10, by + 10, C[COURSES[course][0]])


# ================================================================== global
def header_plate(text_s):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        size = 24
        tw = cv.text_width(text_s, size, 900)
        x1 = int(min(w - 12, max(240, 50 + tw + 40)))
        plate(cv, 3, 3, x1, 62, C["clear"], shadow=5, px=3)
        cv.rect(14, 27, 26, 39, INK)
        cv.rect(17, 30, 23, 36, C["p1"])
        cv.text(33 + (x1 - 33) / 2, 34, text_s, size, INK, weight=900, max_w=x1 - 66)
        return cv.result()
    return draw


def f_footer(i, n, w, h):
    """Bottom strip: an ink rule, paper floor and a red/blue lane stripe."""
    cv = Canvas(w, h)
    cv.rect(0, 37, w, 40, INK)
    cv.rect(0, 40, w, h, PAPER)
    cv.rect(0, 40, w // 2, 46, C["p1"])
    cv.rect(w // 2, 40, w, 46, C["p2"])
    pixdither(cv, 0, 46, w, 54, C["bg2"], 4)
    # pixel grass tufts and flowers growing from the rule (above it, in the free corners only)
    tuft = ["X.X.X", "XXXXX", ".XXX."]
    flower = [".X.", "XYX", ".X.", ".G.", ".G."]
    for gx in list(range(150, 400, 62)) + list(range(868, 1130, 62)):
        pgrid(cv, gx, 37 - 9, tuft, 3, C["normal"], ow=0)
    for gx, col in ((240, C["pink"]), (330, C["clear"]), (930, C["pink"]), (1040, C["clear"])):
        for r, row in enumerate(flower):
            for q, ch in enumerate(row):
                if ch == ".":
                    continue
                fc = {"X": col, "Y": PAPER, "G": C["normal"]}[ch]
                cv.rect(gx + q * 3, 37 - 15 + r * 3, gx + q * 3 + 3, 37 - 12 + r * 3, fc)
    return cv.result()


def f_background_diff(i, n, w, h):
    """The big course drum behind the difficulty select (left of the card): an ink-rimmed disc in
    the course colour, a light inner face and the course's pixel dots. Whole, never clipped: it spans
    screen x 16..224 (the card starts at 237). The engine draws it at 50 %, so it is saturated."""
    cv = Canvas(w, h, ss=1)
    cx, cy = 170, 168
    col = C[COURSES[i][0]]
    pdisc(cv, cx, cy, 104, 4, INK)
    pdisc(cv, cx, cy, 98, 4, col)
    pdisc(cv, cx, cy, 74, 4, INK)
    pdisc(cv, cx, cy, 70, 4, mix(PAPER, col, 0.28))
    if i <= 3:
        sq, gap = 24, 10
        k = i + 1
        tot = k * sq + (k - 1) * gap
        for j in range(k):
            x0 = cx - tot // 2 + j * (sq + gap)
            cv.rect(x0, cy - sq // 2, x0 + sq, cy + sq // 2, INK)
            cv.rect(x0 + 4, cy - sq // 2 + 4, x0 + 10, cy - sq // 2 + 10, col)
    else:
        pemblem(cv, cx, cy, 54, i)
    return cv.result()


def f_background_diff_highlight(i, n, w, h):
    cv = Canvas(w, h)
    pdisc(cv, 170, 168, 104, 6, (255, 255, 255, 255))
    return cv.result()


def f_bg_diff_text_bg(i, n, w, h):
    cv = Canvas(w, h)
    plate(cv, 12, 14, 249, 78, PAPER, shadow=4)
    return cv.result()


def f_arrow(i, n, w, h):
    """A pixel left chevron (the engine mirrors index 1 for the right arrow)."""
    cv = Canvas(w, h)
    pgrid_c(cv, 52, 60, CHEV, 6, C["clear"], ow=3)
    return cv.result()


def f_song_num_bg(i, n, w, h):
    cv = Canvas(w, h)
    plate(cv, 8, 6, 308, 54, PAPER, shadow=4)
    return cv.result()


def build_pets(G):
    """Momo and Hoshi stand on the footer's ink rule (Lua draws them in draw_footer): frames
    idle / squash (hop landing) / blink, 3 px per sprite pixel, 102 px tiles (feet 3 px above the
    bottom edge, which sits on screen y 608 = the rule's lower edge)."""
    sub = OwnSubset(G, SCREEN, "ss_pets")
    for key, concept in (("momo", mascot.MAIN), ("hoshi", mascot.BUDDY)):
        sub.add(key, [mascot.sized(concept, "idle", 102), mascot.sized(concept, "idle", 102, frame=1),
                      mascot.sized(concept, "blink", 102)])
    return sub.write()


def build_global(G, lang):
    w = SubsetWriter(G, SCREEN, "global")
    for key, tk in (("song_select", "song_select"), ("difficulty_select", "difficulty_select")):
        w.put(key + "_ja", header_plate(TXT[tk][0]))
        w.put(key + "_en", header_plate(TXT[tk][1]))
    w.put("footer", f_footer)
    w.put("background_diff", f_background_diff)
    w.put("background_diff_highlight", f_background_diff_highlight)
    w.put("bg_diff_text_bg", f_bg_diff_text_bg)
    # chevrons outside the neighbour boards (Green: 412 / 776 sit on the boards)
    w.put("arrow", f_arrow, entry=[{"x": 299, "y": 290}, {"x": 883, "y": 290}])
    w.put("song_num_bg", f_song_num_bg)
    return w.write()


# ================================================================== box
def f_background(i, n, w, h):
    """Full-screen backdrop tile per genre: cream with a faint genre wash, a sky band with pixel
    clouds at the top and a few sparse pixel specks (calm: nothing behind the boards' text)."""
    tint_c = GENRE_TINT[i] if i < len(GENRE_TINT) else None
    cv = Canvas(w, h, ss=1)
    base = C["bg0"]
    if tint_c is None:
        cv.rect(0, 0, w, h, base)
        for y in range(0, h, 12):   # a soft hue sweep, very low
            cv.rect(0, y, w, y + 12, mix(base, hue(y / h, 0.5, 1.0), 0.07))
    else:
        cv.rect(0, 0, w, h, mix(base, hexc(tint_c), 0.08))
    dot = mix(base, C["line"], 0.5)
    for y in range(140, h, 48):
        for x in range(24 + (y // 48 % 2) * 24, w, 48):
            cv.rect(x, y, x + 3, y + 3, dot)
    sky_band(cv, w, 96, seed=i)
    return cv.result()


BOARD_TOP, BOARD_BOT = 9, 466   # the board's vertical extent inside the 480 px frames (shadow below)
SRC_H = 0.22                    # hue of the shader's source colour (142, 212, 30)


def board_full(i):
    """The whole closed board on a 72-wide strip (32 left + 8 middle + 32 right); cut into slices."""
    W, H = 72, 480
    cv = Canvas(W, H)
    acc = accent_at(i, 0, 1)
    if i == 0:   # frame 0 goes through the recolour shader: stay in the source hue, neutral inks
        import colorsys
        body = tuple(int(v * 255) for v in colorsys.hsv_to_rgb(SRC_H, 0.30, 1.0)) + (255,)
        dark = tuple(int(v * 255) for v in colorsys.hsv_to_rgb(SRC_H, 0.40, 0.90)) + (255,)
        ink_c = (46, 40, 44, 255)
    else:
        body = tint(acc, 0.32)
        dark = tint(acc, 0.5)
        ink_c = INK
    x0, x1 = 5, 64
    pixbox(cv, x0, BOARD_TOP, x1, BOARD_BOT, body, ink_c, shadow=4, px=3)
    # accent cap (rainbow bands for RECOMMENDED), then an ink rule under it
    cap0, cap1 = BOARD_TOP + 3, BOARD_TOP + 24   # shorter cap: the engine's title starts below it with air
    if i == 3:
        for k in range(5):
            cv.rect(x0 + 3, cap0 + k * 6, x1 - 3, cap0 + (k + 1) * 6, hue(k / 5, 0.55, 1.0))
    else:
        cv.rect(x0 + 3, cap0, x1 - 3, cap1, acc)
    cv.rect(x0 + 3, cap1, x1 - 3, cap1 + 3, ink_c)
    cv.rect(x0 + 3, cap0, x1 - 3, cap0 + 2, alpha(PAPER, 170))
    # a dithered foot band (flat 8-bit shading)
    pixdither(cv, x0 + 3, BOARD_BOT - 15, x1 - 3, BOARD_BOT - 3, dark, 3)
    return cv.result()


def f_board(side):
    def draw(i, n, w, h):
        im = board_full(i)
        box = {"left": (0, 0, 32, 480), "mid": (32, 0, 40, 480), "right": (40, 0, 72, 480)}[side]
        return im.crop(box)
    return draw


def f_folder_clip(i, n, w, h):
    cv = Canvas(w, h)
    pixbox(cv, 4, 3, 83, 21, accent_at(i, 0, 1), INK, shadow=0, px=3)
    cv.rect(32, 9, 56, 15, INK)
    return cv.result()


def f_folder_top(edge):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        acc = accent_at(i, 0, 1)
        if edge:
            pixbox(cv, 2, 11, w + 30, 72 + 30, acc, INK, shadow=0, px=3)
        else:
            cv.rect(0, 11, w, 72, acc)
            cv.rect(0, 11, w, 14, INK)
        return cv.result()
    return draw


GFX_EXPR = ["idle", "good", "combo", "gogo", "clear", "good", "idle", "combo", "clear", "gogo"]


def f_folder_graphic(i, n, w, h):
    """The genre picture in the open folder: a pixel mascot (Momo / Hoshi, pose varies per genre)
    on a stepped light disc; the difficulty-sort folder gets a pixel star trio."""
    cv = Canvas(w, h)
    tint_c = hexc(GENRE_TINT[i % 16] or "#A9B1C3")
    pdisc(cv, 96, 230, 84, 6, INK)
    pdisc(cv, 96, 230, 78, 6, mix(PAPER, tint_c, 0.35))
    im = cv.result()
    if i == 14:
        cv2 = Canvas(w, h)
        for dx, dy, cell in ((-40, 244, 4), (0, 206, 6), (40, 244, 4)):
            pgrid_c(cv2, 96 + dx, dy, I_STAR, cell, C["clear"], ow=3)
        im.alpha_composite(cv2.result())
        return im
    m = mascot.sized(mascot.MAIN if i % 2 == 0 else mascot.BUDDY, GFX_EXPR[i % len(GFX_EXPR)], 160)
    im.alpha_composite(m, (96 - 80, 296 - 160))
    return im


def strip_canvas(i, w, h, kind):
    """The opened-genre strip behind the songs (folder_background*), frames by TextureIndex.
    kind: body | edge | tab | tab_edge.  Tab = rows 2..59, body = rows 59..559."""
    cv = Canvas(w, h)
    acc = accent_at(i, 0, 1)
    body = alpha(tint(acc, 0.2), 238)
    top, bot = 59, 559
    if kind in ("body", "tab"):
        cv.rect(0, top, w, bot, body)
        cv.rect(0, top, w, top + 3, INK)
        cv.rect(0, bot - 3, w, bot, INK)
        cv.rect(0, top + 3, w, top + 7, acc)
        if kind == "tab":
            cv.rect(0, 14, w, top + 1, acc)
            cv.rect(0, 11, w, 14, INK)
            cv.rect(0, top - 3, w, top + 3, INK)
        return cv.result()
    # the left end (the engine mirrors it for the right): a notched ink-bordered end
    pixbox(cv, 3, top, w + 40, bot, body, INK, shadow=0, px=3)
    cv.rect(6, top + 3, w, top + 7, acc)
    if kind == "tab_edge":
        cv3 = Canvas(w, h)
        pixbox(cv3, 6, 11, w + 30, top + 20, acc, INK, shadow=0, px=3)
        tab = cv3.result().crop((0, 0, w, top + 1))
        res = cv.result()
        res.alpha_composite(tab, (0, 0))
        return res
    return cv.result()


def f_strip(kind):
    def draw(i, n, w, h):
        return strip_canvas(i, w, h, kind)
    return draw


def f_back_graphic(i, n, w, h):
    """The back board's picture: Hoshi on a pixel disc beside a pixel return-arrow tile."""
    cv = Canvas(w, h)
    pdisc(cv, 128, 160, 96, 6, INK)
    pdisc(cv, 128, 160, 90, 6, mix(PAPER, C["sky"], 0.7))
    im = cv.result()
    im.alpha_composite(mascot.sized(mascot.BUDDY, "blink", 192), (32, 250 - 192 + 60))
    cv2 = Canvas(w, h)
    plate(cv2, 176, 30, 232, 86, C["clear"], shadow=4)
    pgrid_c(cv2, 204, 58, I_BACK, 4, INK)
    im.alpha_composite(cv2.result())
    return im


def f_back_icon(highlight):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        if highlight:
            pgrid_c(cv, 24, 22, I_BACK, 5, C["clear"], ow=3)
        else:
            pgrid_c(cv, 24, 22, I_BACK, 5, INK, ow=2, ink=PAPER)
        return cv.result()
    return draw


def build_box(G, lang):
    w = SubsetWriter(G, SCREEN, "box")
    w.put("background", f_background)
    w.put("folder_texture_left", f_board("left"))
    w.put("folder_texture", f_board("mid"))
    w.put("folder_texture_right", f_board("right"))
    w.put("folder_clip", f_folder_clip)
    w.put("folder_top", f_folder_top(False))
    w.put("folder_top_edge", f_folder_top(True))
    w.put("folder_graphic", f_folder_graphic)
    w.put("folder_background", f_strip("body"))
    w.put("folder_background_edge", f_strip("edge"))
    w.put("folder_background_folder", f_strip("tab"))
    w.put("folder_background_folder_edge", f_strip("tab_edge"))
    for k in ("genre_overlay", "genre_overlay_large", "diff_overlay", "diff_overlay_large"):
        w.put_blank(k)
    w.put("back_graphic", f_back_graphic)
    w.put("back_icon", f_back_icon(False))
    w.put("back_icon_highlight", f_back_icon(True))
    return w.write()


# ================================================================== yellow_box (the open board)
def card_pieces(w=72, h=72):
    """A 9-slice source: the open board card (paper window, ink border, notched corners, hard shadow)."""
    cv = Canvas(w, h)
    pixbox(cv, 6, 9, 61, 60, PAPER, INK, shadow=4, px=3)
    return cv.result()


def f_slice(sx, sy, sw, sh):
    card = card_pieces()

    def draw(i, n, w, h):
        return card.crop((sx, sy, sx + sw, sy + sh))
    return draw


def f_crown(kind):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pcrown(cv, 26, 28, kind, 4, course=i)
        return cv.result()
    return draw


def f_s_crown(kind):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        pcrown(cv, 20, 21, kind, 3)
        return cv.result()
    return draw


def pill(text_s, fill, fg, w, h, box=(9, 8, 213, 56), size=24):
    cv = Canvas(w, h)
    x0, y0, x1, y1 = box
    plate(cv, x0, y0, x1, y1, fill, shadow=3)
    cv.text((x0 + x1) / 2, (y0 + y1) / 2 + 1, text_s, size, fg, weight=900, max_w=x1 - x0 - 24)
    return cv.result()


def f_pill(key, lang, fill, fg=None):
    def draw(i, n, w, h):
        return pill(t(key, lang), fill, fg or INK, w, h)
    return draw


def badge(text_s, fill, w, h, size=36):
    cv = Canvas(w, h)
    pdisc(cv, 52, 50, 44, 4, INK)
    pdisc(cv, 52, 50, 40, 4, fill)
    cv.text(52, 51, text_s, size, INK, weight=900, max_w=62)
    return cv.result()


def f_badge(key, lang, fill):
    def draw(i, n, w, h):
        return badge(t(key, lang), fill, w, h, 36 if len(t(key, lang)) <= 2 else 24)
    return draw


def f_preimage_bg(i, n, w, h):
    cv = Canvas(w, h)
    plate(cv, 10, 20, 90, 100, C["bg3"], shadow=4)
    return cv.result()


def f_song_count_back(i, n, w, h):
    cv = Canvas(w, h)
    plate(cv, 3, 4, 178, 49, C["bg3"], shadow=3)
    return cv.result()


BAR = (16, 6, 56, 318)   # difficulty bar body inside its 72x328 frame


def f_difficulty_bar(i, n, w, h):
    """The four (five) course bars of the open board: a light course-tinted pixbox with the pixel emblem."""
    cv = Canvas(w, h)
    x0, y0, x1, y1 = BAR
    cx = (x0 + x1) // 2
    col = C[COURSES[i][0]]
    plate(cv, x0, y0, x1, y1, tint(col, 0.28), shadow=3)
    for yy in range(150, y1 - 14, 8):   # a dotted guide line
        cv.rect(cx - 1, yy, cx + 1, yy + 4, alpha(INK, 70))
    pemblem(cv, cx, y0 + 24, 17, i)
    return cv.result()


def f_difficulty_bar_shadow(i, n, w, h):
    cv = Canvas(w, h)
    x0, y0, x1, y1 = BAR
    cv.rect(x0 + 3, y0 + 3, x1 + 3, y1 + 3, INK)
    return cv.result()


def f_star(col):
    """Level 'stars' are pixel squares: ink frame, flat fill, a 2 px paper highlight."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cx, cy = 20, 21
        cv.rect(cx - 6, cy - 6, cx + 6, cy + 6, INK)
        cv.rect(cx - 4, cy - 4, cx + 4, cy + 4, col)
        cv.rect(cx - 4, cy - 4, cx + 1, cy - 2, alpha(PAPER, 200))
        return cv.result()
    return draw


def f_branch(lang, fill, fg, box):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        x0, y0, x1, y1 = box
        plate(cv, x0, y0, x1 - 3, y1 - 3, fill, shadow=3)
        vtext(cv, (x0 + x1 - 3) / 2, y0 + 10, t("branch", lang), 12, fg, weight=900, max_h=y1 - y0 - 24)
        return cv.result()
    return draw


def build_yellow_box(G, lang):
    w = SubsetWriter(G, SCREEN, "yellow_box")
    # 9-slice pieces: corners 32x32, edges 32x8 / 8x32, centre 8x8 from one 72x72 card
    w.put("yellow_box_top_left", f_slice(0, 0, 32, 32))
    w.put("yellow_box_top", f_slice(32, 0, 8, 32))
    w.put("yellow_box_top_right", f_slice(40, 0, 32, 32))
    w.put("yellow_box_left", f_slice(0, 32, 32, 8))
    w.put("yellow_box_center", f_slice(32, 32, 8, 8))
    w.put("yellow_box_right", f_slice(40, 32, 32, 8))
    w.put("yellow_box_bottom_left", f_slice(0, 40, 32, 32))
    w.put("yellow_box_bottom", f_slice(32, 40, 8, 32))
    w.put("yellow_box_bottom_right", f_slice(40, 40, 32, 32))
    for k in ("shadow_bottom_left", "shadow_bottom_right", "shadow_bottom", "shadow_right", "shadow_top_right"):
        w.put_blank(k)
    w.put("crown_clear", f_crown("clear"))
    w.put("crown_fc", f_crown("fc"))
    w.put("crown_dfc", f_crown("dfc"))
    w.put("s_crown_clear", f_s_crown("clear"))
    w.put("s_crown_fc", f_s_crown("fc"))
    w.put("s_crown_dfc", f_s_crown("dfc"))
    w.put("s_crown_outline", f_s_crown("outline"))
    w.put("song_count_back", f_song_count_back)
    w.put("preimage_bg", f_preimage_bg)
    for lg in ("ja", "en"):
        w.put("ex_data_new_song_" + lg, f_pill("new_song", lg, C["clear"]))
        w.put("ex_data_limited_time_" + lg, f_pill("limited", lg, C["normal"]))
        w.put("favorite_1p_" + lg, f_pill("fav1", lg, C["p1"], PAPER))
        w.put("favorite_2p_" + lg, f_pill("fav2", lg, C["p2"], PAPER))
        w.put("ex_data_new_song_balloon_" + lg, f_badge("new_song_b", lg, C["clear"]))
        w.put("ex_data_limited_time_balloon_" + lg, f_badge("limited_b", lg, C["normal"]))
    w.put("ex_data_new_audio", f_pill("new_audio", "ja", C["sky"]))
    w.put("ex_data_old_audio", f_pill("old_audio", "ja", C["bg3"]))
    w.put("difficulty_bar", f_difficulty_bar)
    w.put("difficulty_bar_shadow", f_difficulty_bar_shadow)
    w.put("star", f_star(C["clear"]))
    w.put("star_ura", f_star(C["clear"]))
    w.put("branch_indicator", f_branch("ja", C["roll"], INK, (6, 8, 34, 192)))
    w.put("branch_indicator_diff", f_branch("ja", C["roll"], INK, (16, 2, 48, 206)))
    w.put("branch_indicator_ura", f_branch("ja", C["ura"], PAPER, (16, 2, 48, 206)))
    return w.write()


# ================================================================== diff_select
TOWER = (8, 8, 92, 462)   # tower card inside 104x584 (outer edge of the ink border)


def f_tower(i, n, w, h):
    """Difficulty tower: a light course-tinted pixbox with the pixel emblem on top and a course-coloured foot."""
    cv = Canvas(w, h)
    x0, y0, x1, y1 = TOWER
    cx = (x0 + x1) // 2
    col = C[COURSES[i][0]]
    plate(cv, x0, y0, x1, y1, tint(col, 0.22), shadow=4)
    # the foot ends inside the card (screen y ~552), clear of the nav strip and the engine footer
    cv.rect(x0 + 3, 418, x1 - 3, y1 - 3, col)
    cv.rect(x0 + 3, 418, x1 - 3, 421, INK)
    pixdither(cv, x0 + 3, 421, x1 - 3, 429, mix(col, INK, 0.25), 4)
    pemblem(cv, cx, 443, 12, i)
    pemblem(cv, cx, 42, 24, i)
    for yy in range(232, 408, 8):                 # dotted guide line
        cv.rect(cx - 1, yy, cx + 1, yy + 4, alpha(INK, 60))
    return cv.result()


def f_tower_shadow(i, n, w, h):
    cv = Canvas(w, h)
    x0, y0, x1, y1 = TOWER
    cv.rect(x0 + 4, y0 + 4, x1 + 4, y1 + 4, INK)
    return cv.result()


def f_outline(color, half=None, box=(8, 20, 74, 380), n=3):
    """Selection ring around a tower / button: ink + player colour; full, or the left/right half for 1P+2P."""
    def draw(i, n_, w, h):
        cv = Canvas(w, h)
        pframe(cv, box, color, 3, 4, n)
        im = cv.result()
        x0, y0, x1, y1 = box
        if half == "left":
            im.paste((0, 0, 0, 0), (int((x0 + x1) / 2), 0, w, h))
        elif half == "right":
            im.paste((0, 0, 0, 0), (0, 0, int((x0 + x1) / 2), h))
        return im
    return draw


ICON = {"back": I_BACK, "option": I_GEAR, "neiro": I_NOTE}
BTN = (12, 10, 66, 308)


def f_button(key, lang, accent):
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        x0, y0, x1, y1 = BTN
        cx = (x0 + x1) // 2
        plate(cv, x0, y0, x1, y1, PAPER, shadow=4)
        cv.rect(cx - 19, y0 + 11, cx + 19, y0 + 49, INK)
        cv.rect(cx - 16, y0 + 14, cx + 16, y0 + 46, accent)
        pgrid_c(cv, cx, y0 + 30, ICON[key], 3, INK)
        vtext(cv, cx, y0 + 62, t(key, lang), 24, INK, weight=800, max_h=y1 - y0 - 76)
        return cv.result()
    return draw


def f_disable(i, n, w, h):
    cv = Canvas(w, h)
    x0, y0, x1, y1 = BTN
    cv.rect(x0 + 3, y0 + 3, x1 - 3, y1 - 3, alpha(C["bg0"], 215))
    pixdither(cv, x0 + 3, y0 + 3, x1 - 3, y1 - 3, alpha(C["mute"], 90), 4)
    return cv.result()


def f_player_balloon(label, color, half=False):
    """The 1P / 2P marker above the cursor: a pixbox plate with a pixel pointer (half: shifted for 1P+2P)."""
    def draw(i, n, w, h):
        cv = Canvas(w, h)
        cx = 52
        tipx = 52 if not half else 98
        plate(cv, cx - 38, 8, cx + 38, 64, color, shadow=4)
        cv.text(cx, 37, label, 36, PAPER, weight=900)
        pgrid_c(cv, tipx, 92, PTR, 6, color, ow=3)
        return cv.result()
    return draw


def f_ura_plate(i, n, w, h):
    cv = Canvas(w, h)
    plate(cv, 10, 23, 66, 377, tint(C["ura"], 0.3), shadow=3)
    return cv.result()


def f_ura_switch(i, n, w, h):
    """The plate flip when the ura course is toggled: a card narrowing and widening in whole 4 px steps."""
    cv = Canvas(w, h)
    k = i / max(1, n - 1)
    sx = abs(math.cos(k * math.pi))
    face = mix(C["bg3"], C["ura"], min(1.0, k * 1.6))
    half = max(2, int(round(28 * max(0.1, sx) / 4)) * 4)
    cx = w // 2
    cv.rect(cx - half - 3, 18, cx + half + 3, 374, INK)
    cv.rect(cx - half, 21, cx + half, 371, face)
    return cv.result()


def build_diff_select(G, lang):
    w = SubsetWriter(G, SCREEN, "diff_select")
    w.put("diff_tower", f_tower)
    w.put("diff_tower_shadow", f_tower_shadow)
    tb = (8, 20, 74, 380)
    bb = (9, 8, 72, 312)
    for p, col in (("1p", C["p1"]), ("2p", C["p2"])):
        w.put(p + "_outline", f_outline(col, None, tb))
        w.put(p + "_outline_half", f_outline(col, "left" if p == "1p" else "right", tb))
        w.put(p + "_outline_back", f_outline(col, None, bb))
        w.put(p + "_outline_back_half", f_outline(col, "left" if p == "1p" else "right", bb))
        w.put(p + "_balloon", f_player_balloon(p.upper(), col))
        w.put(p + "_balloon_half", f_player_balloon(p.upper(), col, half=True))
    for lg in ("ja", "en"):
        w.put("back_" + lg, f_button("back", lg, C["bg3"]))
        w.put("option_" + lg, f_button("option", lg, C["normal"]))
        w.put("neiro_" + lg, f_button("neiro", lg, C["oni"]))
    w.put("disable", f_disable)
    w.put("ura_oni_plate", f_ura_plate)
    w.put("ura_switch", f_ura_switch)
    return w.write()


# ================================================================== Lua patches
INK_RGBA = "{ 58, 38, 51, 255 }"      # C["ink"]
PAPER_RGBA = "{ 255, 255, 255, 255 }"
# boards are light now: ink text with a paper outline (Green: white text with a dark outline)
SWAP = ("local WHITE = " + INK_RGBA + "   -- SimpleStyle: ink text on light boards\n"
        "local BLACK = " + PAPER_RGBA + "   -- ... with a paper outline\n")
LUA_PATCHES = {
    # remember the chosen course + level per player for the enso info panel (background.lua)
    "song_select/song_select.lua": [
        ("function SongSelect:draw_box(box)\n    base.track_yellow_box(box)\n",
         "function SongSelect:draw_box(box)\n    base.track_yellow_box(box)\n"
         "    if box:lua_kind() == \"song\" and box:draw_state() == \"diff_select\" then SS_DIFF_BOX = box end\n"),
        ('    tex.load_folder("song_select", "diff_select")\n',
         '    tex.load_folder("song_select", "diff_select")\n    tex.load_folder("song_select", "ss_pets")\n'
         '    self._id_momo  = tex.get_texture("song_select/ss_pets/momo")  or 0\n'
         '    self._id_hoshi = tex.get_texture("song_select/ss_pets/hoshi") or 0\n'
         '    self._ms = 0\n'),
        ("function SongSelect:update(current_ms)\n",
         "function SongSelect:update(current_ms)\n    self._ms = current_ms\n"),
        ("function SongSelect:draw_footer()\n    tex.draw_texture(self._id_footer)\n",
         "function SongSelect:draw_footer()\n    tex.draw_texture(self._id_footer)\n"
         "    -- SimpleStyle: Momo and Hoshi stand on the footer rule (tile bottom = the rule's lower edge,\n"
         "    -- y 608); they hop one sprite pixel (3 px) on the beat, land squashed, and blink now and then\n"
         "    for k, id in ipairs({ self._id_momo, self._id_hoshi }) do\n"
         "        local ms = self._ms + (k - 1) * 500\n"
         "        local ph = ms % 1000\n"
         "        local frame, dy = 0, 0\n"
         "        if ph < 110 then dy = -3 elseif ph < 220 then frame = 1 elseif (ms + k * 700) % 3400 < 140 then frame = 2 end\n"
         "        tex.draw_texture(id, { frame = frame, x = (k == 1) and 41 or 1137, y = 506 + dy })\n"
         "    end\n"),
        ("SongSelect = {}\n",
         "SongSelect = {}\n\n"
         "-- SimpleStyle: the course/level a player has on the cursor (read by the enso background)\n"
         "function SS_RECORD_COURSE(player)\n"
         "    local d = player:selected_difficulty()\n"
         "    if d < 0 or d > 4 then return end\n"
         "    local lvl = 0\n"
         "    if SS_DIFF_BOX then\n"
         "        local ok, info = pcall(function() return SS_DIFF_BOX:course_info(d) end)\n"
         "        if ok and info then lvl = info.level or 0 end\n"
         "    end\n"
         "    if type(SS_COURSE_BY_PLAYER) ~= \"table\" then SS_COURSE_BY_PLAYER = {} end\n"
         "    SS_COURSE_BY_PLAYER[player:player_num() == 2 and 2 or 1] = { diff = d, level = lvl }\n"
         "end\n"),
    ],
    "song_select/player_ui.lua": [
        ("function M.draw_selector(_self, player, is_half, fade_in, pass)\n",
         "function M.draw_selector(_self, player, is_half, fade_in, pass)\n"
         "    if SS_RECORD_COURSE then SS_RECORD_COURSE(player) end   -- SimpleStyle\n"),
        # search box: a paper field with an ink ring and ink text (was white / maroon / black)
        ("        { 255, 255, 255, alpha }, 3, { 119, 26, 45, alpha })\n",
         "        { 255, 255, 255, alpha }, 3, { 58, 38, 51, alpha })   -- SimpleStyle\n"),
        ("            { 0, 0, 0, 255 }, { 0, 0, 0, 0 }, false, 0, 1.0)\n",
         "            " + INK_RGBA + ", { 0, 0, 0, 0 }, false, 0, 1.0)\n"),
    ],
    # leaderboard: light cards (ink digits), the shinuchi bar is an ink bar (paper digits, as in Green)
    "song_select/score_history.lua": [
        ("            local t = text.create_raw_text(label, font_size, { 0, 0, 0, 255 }, { 0, 0, 0, 0 }, false, 0, 2.0)\n",
         "            local t = text.create_raw_text(label, font_size, " + INK_RGBA + ", { 0, 0, 0, 0 }, false, 0, 2.0)\n"),
        ("            self.title = text.create_raw_text(label, 8, { 0, 0, 0, 255 }, { 0, 0, 0, 0 }, false, 0, 2.0)\n",
         "            self.title = text.create_raw_text(label, 8, " + INK_RGBA + ", { 0, 0, 0, 0 }, false, 0, 2.0)\n"),
        ("tex.draw_texture(self.t_pts, { color = { 0, 0, 0, 255 }, index = 1 })",
         "tex.draw_texture(self.t_pts, { color = " + INK_RGBA + ", index = 1 })"),
        ("    local score_color = self.is_shinuchi and { 255, 255, 255, 255 } or { 0, 0, 0, 255 }\n",
         "    local score_color = self.is_shinuchi and { 255, 255, 255, 255 } or " + INK_RGBA + "\n"),
    ],
    # option / neiro panels: ink text with a paper outline (Green: white with a black outline)
    "song_select/option_panel.lua": [
        ("local WHITE, BLACK = { 255, 255, 255, 255 }, { 0, 0, 0, 255 }\n",
         "local WHITE, BLACK = " + INK_RGBA + ", " + PAPER_RGBA + "   -- SimpleStyle: ink text, paper outline\n"),
    ],
    # the course labels: ink on the light towers/bars
    "song_select/file_navigator/box_song.lua": [
        ("local BLACK = { 0, 0, 0, 255 }\nlocal WHITE = { 255, 255, 255, 255 }\n", SWAP),
        ("    local fills = { BLACK, BLACK, BLACK, BLACK, WHITE }\n"
         "    local outlines = { BLANK, BLANK, BLANK, BLANK, { 0, 73, 90, 255 } }\n",
         "    local fills = { WHITE, WHITE, WHITE, WHITE, WHITE }   -- SimpleStyle: ink on light towers\n"
         "    local outlines = { BLANK, BLANK, BLANK, BLANK, BLANK }\n"),
        ("    local colors = { BLACK, BLACK, BLACK, BLACK }\n"
         "    self._difficulty_bar_labels = build_vertical_labels(keys, cfg, 0.9, 7.0, colors, colors, 0.0)\n",
         "    local colors = { WHITE, WHITE, WHITE, WHITE }   -- SimpleStyle: ink on light bars\n"
         "    self._difficulty_bar_labels = build_vertical_labels(keys, cfg, 0.9, 7.0, colors, colors, 0.0)\n"),
        # titles: ink fill + paper outline, thin (was a 5 px genre / black outline)
        ("        local name_text = text.create_raw_text(name, name_font, WHITE, fore, true, 5.0, 2.0, 1.0)\n",
         "        local name_text = text.create_raw_text(name, name_font, WHITE, BLACK, true, 3.0, 2.0, 1.0)\n"),
    ],
    "song_select/file_navigator/box_folder.lua": [
        ("local WHITE = { 255, 255, 255, 255 }\nlocal BLACK = { 0, 0, 0, 255 }\n", SWAP),
    ],
    "song_select/file_navigator/box_back.lua": [
        ("local WHITE = { 255, 255, 255, 255 }\nlocal BLACK = { 0, 0, 0, 255 }\nlocal OUTLINE_COLOR = { 77, 39, 0, 255 }\n",
         SWAP + "local OUTLINE_COLOR = " + PAPER_RGBA + "\n"),
    ],
    "song_select/file_navigator/box_base.lua": [
        # closed board titles: ink text, thin paper outline (the genre colour lives in the board's body)
        ("        t = text.create_raw_text(name, font_size, { 255, 255, 255, 255 }, outline, true, 5.0, 2.0, 1.0)\n",
         "        t = text.create_raw_text(name, font_size, " + INK_RGBA + ", " + PAPER_RGBA + ", true, 3.0, 2.0, 1.0)\n"),
    ],
}


def configure(ctx):
    global LANG
    LANG = ctx.lang


def build(ctx):
    n = 0
    n += build_global(ctx.G, ctx.lang)
    n += build_pets(ctx.G)
    n += build_box(ctx.G, ctx.lang)
    n += build_yellow_box(ctx.G, ctx.lang)
    n += build_diff_select(ctx.G, ctx.lang)
    from . import song_select_extra
    n += song_select_extra.build(ctx.G, ctx.lang)
    return n
