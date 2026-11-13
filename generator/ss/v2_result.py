"""v2 result + dan result (Nijiiro geometry, light 8-bit art, density aware).

The Nijiiro result flow is Lua-driven (Scripts/result/*.lua; the engine only owns the state machine,
the nameplate and the overlays). This module ships its OWN versions of every result script, and they
draw only this module's own textures (Graphics/result/ss, Graphics/dan_result/ss) plus the core Lua
chrome. So no Nijiiro / Green result texture is ever drawn: the ancestor keys of result/* and
dan_result/* stay loaded by the engine but unused (documented in reports/v2_result.md).

Layout follows Nijiiro's 1920x1080 configuration:
  result 1P   board on the left (Nijiiro overlay x 40, y 180) with gauge, score, judge rows, medal
              (score rank) and crown in Nijiiro's places; the right half and the floor are the
              festival stage (Momo + Hoshi at the scene k, taiko on a stand, lantern string, bubble)
  result 2P   two tall boards (Nijiiro x 40 / 996); the lower compartment is each player's stage:
              Momo (1P) and Hoshi (2P) where Nijiiro's Don stands, the bubble where its message is
  dan result  left column (dan plate, stamp, Momo on a floor line, nameplate), board 339..1860:
              page 1 = song rows, page 2 = score / totals / exam rows; promotion + congrats overlays

Everything is LOGICAL (1920x1080) here; PNGs are physical (x style.D)."""
from __future__ import annotations

import os
import shutil

from PIL import Image, ImageDraw, ImageFont

from . import chrome, course, deco, mascot, pixel, style
from .atlas import ANCESTORS, OwnSubset, SubsetWriter, anc_json, resolve, to_phys_entry
from .style import C, U, Canvas, snap

NAME = "v2_result"
OWNS = ["Graphics/result/ss", "Graphics/dan_result/ss", "Scripts/result"]
INK, PAPER = C["ink"], C["paper"]
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# ---------------------------------------------------------------- result geometry (logical)
OFF2 = 957                       # 2P board offset (Nijiiro 996 - 40, snapped to U)
BX0, BX1, BY0 = 42, 936, 180     # board outer box (1P)
BY1_S, BY1_T = 846, 918          # 1P board (r3: grown from 606 to hold the judge breakdown strip) /
                                 # tall 2P board with the stage compartment; both end above the engine
                                 # nameplate (y 922+)
GX0, GY0, GY1 = 72, 246, 288     # gauge frame (50 cells x 15 + 1U border each side)
G_CELL = 15
SB = (72, 330, 498, 438)         # score box
JX0, JX1, JY0 = 528, 912, 330    # judge rows
JPITCH_S, JPITCH_T = 72, 54       # row pitch: 1P (tall board, roomy) / 2P (rows above the compartment)
# 1P judge breakdown strip (r3): rule, label + legend row, a 55-cell bar of 15 (良 / 可 / 不可 shares)
DIST_RULE_Y = 705
DIST_ROW_Y = 723                  # chip row (27 tall)
DIST_BAR = (72, 768, 55, 15, 42)  # x, y, cells, cell pitch, height (the soul gauge's; frame + groove baked)
DIST_SLOTS = (396, 570, 744)      # legend slot x (chip >= 66 wide; % value right-aligned at slot + 168, pitch 174: en GOOD chip 90 + value 70); the label chip + accuracy end by ~385 in en
DIST_SLOT_W = 168
COMP = (57, 609, 921, 909)       # 2P stage compartment (inner panel), floor at COMP_FLOOR
COMP_FLOOR = 900
COMP_HORIZON = 756
STAGE_FLOOR = 927                # 1P festival stage floor
STAGE_CX = 1428                  # 1P stage group centre: the free space right of the board (936..1920)
TAIKO_X = STAGE_CX
HORIZON = 450                    # 1P sky ends here (lantern rope)

SPEEDS = [11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 25, 30, 35, 40]


def _cv_full():
    return Canvas(1920, 1080)


# ---------------------------------------------------------------- shared small drawings
STAMP_FONT = {"ko": "ko", "zh": "zh_tw"}    # Fusion Pixel variant per language (ja / en: the ja file)


def glyph_rows(s, lang="ja"):
    """The 12 px pixel font rendered 1-bit at its native size -> rows of 'X'/'.' (for big stamp
    lettering drawn as U-grid cells, like deco.pixtext but for kanji / hangul)."""
    f = style.font_phys(12)
    if lang in STAMP_FONT:
        f = ImageFont.truetype(style.FONT_PIXEL.replace("-ja.ttf", "-%s.ttf" % STAMP_FONT[lang]), 12)
    asc, desc = f.getmetrics()
    gap = 1 if s.isascii() else 0      # Latin: one extra column between letters (the bold fills the font's own)
    w = int(f.getlength(s)) + gap * len(s) + 2
    m = Image.new("L", (w, asc + desc), 0)
    d = ImageDraw.Draw(m)
    d.fontmode = "1"
    x = 0
    for ch in (s if gap else [s]):
        d.text((x, 0), ch, font=f, fill=255)
        x += f.getlength(ch) + gap
    bb = m.getbbox()
    m = m.crop(bb)
    return ["".join("X" if m.getpixel((x, y)) > 127 else "." for x in range(m.width)) for y in range(m.height)]


def stamp_text(cv, cx, cy, s, cell, fill, shadow=0, bold=True, lang="ja", max_w=None):
    """Cell lettering centred on (cx, cy); with max_w the cell shrinks (whole U) until it fits."""
    rows = glyph_rows(s, lang)
    if bold:   # pixel bold: every stroke one cell wider to the right
        rows = ["".join("X" if (r[i] == "X" or (i and r[i - 1] == "X")) else "." for i in range(len(r))) + ("X" if r[-1] == "X" else ".")
                for r in rows]
    while max_w and cell > U and deco.size_of(rows, cell)[0] > max_w:
        cell -= U
    if shadow:
        shadow = max(U, cell // 2 // U * U)
    w, h = deco.size_of(rows, cell)
    deco.cells(cv, snap(cx - w / 2), snap(cy - h / 2), rows, {"X": fill}, cell, outline=None, shadow=shadow)
    return w, h


RCHIP_H = 10 * U               # 30: result chips (the 24 px label needs 1U air; core CHIP_H is 27)


def chip_w(text, size=18, pad=4 * U):
    return int(-(-(Canvas(1, 1).text_width(text, size) + 2 * pad + 2 * U) // U) * U)


def chip_image(text, accent=None, edge=False, size=18):
    """A baked chip (digits / symbols only: every word chip is drawn by the Lua at run time)."""
    w = chip_w(text, size)
    cv = Canvas(w, RCHIP_H)
    chrome.chip(cv, 0, 0, w, RCHIP_H, text, accent=accent, edge=edge, size=size)
    return cv.result()


# ---------------------------------------------------------------- score digits (block lettering)
DIGIT_CELL = 2 * U           # 6 logical per digit pixel: 5x7 glyph + 1-cell ink outline = 42 x 54
DIGIT_PITCH = 6 * DIGIT_CELL  # 36: neighbouring outlines overlap by one cell


def score_digits():
    out = []
    for d in "0123456789":
        cv = Canvas(7 * DIGIT_CELL, 9 * DIGIT_CELL)
        deco.pixtext(cv, 0, 0, d, cell=DIGIT_CELL, fill=PAPER)
        out.append(cv.result())
    return out


# ---------------------------------------------------------------- medal (score rank) and crown
MEDAL_W, MEDAL_H = 141, 156      # the core rank badge (135, tier 0..6 = 粋 粋 粋 雅 雅 雅 極) + ribbon tails
MEDAL_R = (21, 48)               # course.rank_badge "l" size (result)


def medal(tier, ribbon):
    """Score-rank medal: ribbon tails in the player colour behind the shared core rank badge
    (course.rank_paste: the select screen's 粋 / 雅 / 極 language; 極 = the full 6-block rainbow ring)."""
    cv = Canvas(MEDAL_W, MEDAL_H)
    R = MEDAL_R[0] + 1
    cx, cy = snap(MEDAL_W / 2), R * U    # badge centre (rank_size = 2R*U + U)
    for sx in (cx - 33, cx + 15):   # two 6U-wide strips with a swallowtail notch
        x0 = snap(sx)
        cv.rect(x0 - U, cy, x0 + 18 + U, MEDAL_H, INK)
        cv.rect(x0, cy, x0 + 18, MEDAL_H - U, ribbon)
        cv.rect(x0 + 6, MEDAL_H - 2 * U, x0 + 12, MEDAL_H, (0, 0, 0, 0))   # notch
        cv.rect(x0 + 6, MEDAL_H - 3 * U, x0 + 12, MEDAL_H - 2 * U, INK)
    course.rank_paste(cv, tier, cx, cy, *MEDAL_R)
    return cv.result()


CROWN_CELL = 3 * U
CROWN_W, CROWN_H = 132, 102


def crown(kind, crs):
    """The core crown (course.crown, 3U cells) on its 132 x 102 cell. The chip under it (clear = course
    colour + paper outlined text; full combo / 全良 = gold + ink text) is drawn by the Lua at run time
    (y CROWN_H - CHIP_H - U, centred), in the player's language. Bible 2.3: no rainbow crown."""
    cv = Canvas(CROWN_W, CROWN_H)
    cw, ch = course.crown_size(CROWN_CELL)
    course.crown(cv, snap((CROWN_W - cw) / 2), U, kind, crs, CROWN_CELL)
    return cv.result()


def crowns():
    """frames 0..4 = clear (course colour), 5 = full combo (gold), 6 = all good / 全良 (gold, ink jewels)."""
    out = [crown("clear", i) for i in range(5)]
    out.append(crown("fc", None))
    out.append(crown("dfc", None))
    return out


def soul_frames():
    """Gauge end disc: dark (not cleared), lit (cleared), full (gauge maxed: paper inner ring). The 魂 /
    Soul label is drawn by the Lua (a chip instead of the disc when the word is wider than the disc)."""
    out = []
    for fill, ring in ((C["bg3"], None), (C["clear"], None), (C["clear"], PAPER)):
        cv = Canvas(48, 48)
        deco.pixdisc(cv, 24, 24, 7, fill, inner_ring=(ring, 1) if ring else None)
        out.append(cv.result())
    return out


# ---------------------------------------------------------------- bubbles: UI.bubble at run time
BUB_H = 66


# ---------------------------------------------------------------- the result board
def board(tall, pcol, pnum):
    """One player's board at its own origin (BX0, BY0) -> image of (BX1-BX0+U) x (BY1-BY0+U)."""
    by1 = BY1_T if tall else BY1_S
    W, H = BX1 - BX0 + U, by1 - BY0 + U
    cv = Canvas(W, H)
    ox, oy = -BX0, -BY0      # draw in screen coords

    def X(v):
        return v + ox

    def Y(v):
        return v + oy
    chrome.panel(cv, 0, 0, BX1 - BX0, by1 - BY0)
    # score box: player colour fill, label chip drawn by Lua (score / shinuchi)
    chrome.frame(cv, X(SB[0]), Y(SB[1]), X(SB[2]), Y(SB[3]), fill=pcol)
    # judge rows: chips with an accent edge, 1U line separators
    # (the judge chips themselves are drawn by the Lua, sized to the label in the player's language)
    pitch = JPITCH_T if tall else JPITCH_S
    for r in range(5):
        top = JY0 + pitch * r
        if r < 4:
            cv.rect(X(JX0), Y(top + pitch - U), X(JX1), Y(top + pitch), C["line"])
    if not tall:
        # judge breakdown strip: rule and the bar frame (label / legend chips and cells drawn by Lua)
        cv.rect(X(72), Y(DIST_RULE_Y), X(JX1), Y(DIST_RULE_Y + U), C["line"])
        bx, by, n, cp, bh = DIST_BAR
        cv.rect(X(bx), Y(by), X(bx + n * cp + 2 * U), Y(by + bh), INK)
        cv.rect(X(bx + U), Y(by + U), X(bx + U + n * cp), Y(by + bh - U), C["bg3"])
    if tall:
        x0, y0, x1, y1 = COMP
        chrome.frame(cv, X(x0), Y(y0), X(x1), Y(y1), fill=C["sky"], shadow=0, notch=0)
        hy = deco.horizon_dither(cv, X(x0 + U), Y(COMP_HORIZON), X(x1 - U), cell=4 * U)
        cv.rect(X(x0 + U), hy, X(x1 - U), Y(COMP_FLOOR), C["bg0"])
        deco.ground(cv, X(x0 + U), Y(COMP_FLOOR), X(x1 - U), Y(y1 - U))
    return cv.result()


def bg_1p():
    cv = _cv_full()
    cv.rect(0, 0, 1920, 1080, C["bg0"])
    deco.sky(cv, 0, 0, 1920, HORIZON)
    deco.lanterns(cv, 951, 1920, HORIZON, n=5)
    deco.ground(cv, 0, STAGE_FLOOR, 1920, 1080)
    deco.taiko(cv, TAIKO_X, STAGE_FLOOR)
    return cv.result()


def bg_2p():
    cv = _cv_full()
    cv.rect(0, 0, 1920, 1080, C["bg0"])
    deco.sky(cv, 0, 0, 1920, 168)
    deco.ground(cv, 0, 981, 1920, 1080)
    return cv.result()


def cloud_img(size):
    rows = deco.CLOUD_S if size == "S" else deco.CLOUD_M
    w, h = deco.size_of(rows, deco.CLOUD_CELL)
    cv = Canvas(w, h)
    deco.cloud(cv, 0, 0, size)
    return cv.result()


# ---------------------------------------------------------------- polish: celebration art
# big crown for the 1P sky "crown slam" (the crown pops in over the stage, then hands off to the board)
CROWN_BIG_CELL = 8 * U


def crowns_big():
    """frames as crowns(): 0..4 clear (course colour), 5 full combo, 6 全良; 8U cells, no chip."""
    cw, ch = course.crown_size(CROWN_BIG_CELL)
    out = []
    for kind, crs in [("clear", i) for i in range(5)] + [("fc", None), ("dfc", None)]:
        cv = Canvas(cw + U, ch + U)
        course.crown(cv, 0, 0, kind, crs, CROWN_BIG_CELL)
        out.append(cv.result())
    return out


# pixel fireworks (own drawing; the idea follows the game stage's): a rising shell (3 frames) then a
# burst (7 frames), 100 ms per frame, frame swaps only. Variants use accents already on the screen.
FW_CELL = 2 * U
FW_R = 12                         # burst centre cell
FW_N = 2 * FW_R + 1               # burst image: FW_N x (FW_N + 3) cells (room for the drop)
FW_RISE_ROWS = 15
# (main, tip): both saturated accents already on the screen (paper alone vanishes on the pale sky)
FW_VARIANTS = (("clear", "don"), ("don", "clear"))


def _fw_burst(main, tip):
    """7 frames: core flash, 12 streaks shooting out (paper head, tip-coloured neck, main body),
    a full 24-point ring, then the embers falling and thinning out."""
    import math
    spec = ((1, 0), (4, 0), (8, 0), (10, 1), (11, 1), (11, 2), (11, 3))   # (radius, drop) per frame
    frames = []
    for f, (rad, drop) in enumerate(spec):
        cl = {}

        def put(a, r, tok):
            cl[(round(math.cos(a) * r), round(math.sin(a) * r) + drop)] = tok
        if f == 0:
            for c, r in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                cl[(c, r)] = "paper" if (c, r) == (0, 0) else (main if c == 0 or r == 0 else tip)
        for k in range(24):
            if f == 0:
                break
            a = k * math.pi / 12
            if f in (1, 2):              # streaks on the 12 even directions, sparks between
                if k % 2 == 0:
                    L = 3 if f == 1 else 5
                    r = rad - L
                    while r <= rad:
                        put(a, max(1, r), main)
                        r += 0.5
                    put(a, rad - 1, tip)
                    put(a, rad, "paper")
                elif f == 2:
                    put(a, rad - 3, tip)
            elif f == 3:                 # the full ring: body inside, tips outside
                put(a, rad, tip)
                put(a, rad - 1, main)
                if k % 2 == 0:
                    put(a, rad - 3, main)
            elif f == 4:
                put(a, rad, tip if k % 2 else main)
                if k % 2 == 0:
                    put(a, rad - 2, tip)
            elif f == 5:
                if k % 2 == 0:
                    put(a, rad, main)
                elif k % 4 == 1:
                    put(a, rad - 2, tip)
            elif k % 3 == 0:             # last embers
                put(a, rad, tip)
        cv = Canvas(FW_N * FW_CELL, (FW_N + 3) * FW_CELL)
        for (c, r), tok in cl.items():
            x, y = (FW_R + c) * FW_CELL, (FW_R + r) * FW_CELL
            cv.rect(x, y, x + FW_CELL, y + FW_CELL, C[tok])
        frames.append(cv.result())
    return frames


def _fw_rise():
    frames = []
    for k in range(3):
        cv = Canvas(FW_CELL, FW_RISE_ROWS * FW_CELL)
        head = FW_RISE_ROWS - 1 - (3 + 5 * k)     # climbs 5 cells a frame; ends 1 cell under the centre
        for dr, tok in ((0, "paper"), (1, "clear"), (3, "clear"), (5, "don")):
            r = head + dr
            if 0 <= r < FW_RISE_ROWS:
                cv.rect(0, r * FW_CELL, FW_CELL, (r + 1) * FW_CELL, C[tok])
        frames.append(cv.result())
    return frames


def add_fireworks(s):
    s.add("fw_rise", _fw_rise())
    for i, (main, tip) in enumerate(FW_VARIANTS):
        s.add(f"fw_{i}", _fw_burst(main, tip))


def build_result(G):
    s = OwnSubset(G, "result", "ss")
    s.add("bg_1p", [bg_1p()])
    s.add("bg_2p", [bg_2p()])
    s.add("cloud_m", [cloud_img("M")])
    s.add("cloud_s", [cloud_img("S")])
    for tall, nm in ((False, "s"), (True, "t")):
        for pc, pn in ((C["p1"], 1), (C["p2"], 2)):
            s.add(f"board_{nm}_p{pn}", [board(tall, pc, pn)])
    s.add("score_digit", score_digits())
    s.add("medal_p1", [medal(t, C["p1"]) for t in range(7)])
    s.add("medal_p2", [medal(t, C["p2"]) for t in range(7)])
    s.add("crown", crowns())
    s.add("soul", soul_frames())
    s.add("crown_big", crowns_big())
    add_fireworks(s)
    # every word chip (course plate, score label, clear / 1P / option chips, best banner, crown chip) and
    # the mascot bubble are drawn at run time in the player's language (result_player.lua)
    s.add("opt_speed", [chip_image("×%d.%d" % (v // 10, v % 10)) for v in SPEEDS])
    return s.write()


# ================================================================ dan result
DB = (339, 90, 1860, 1011)       # board
DPL = (39, 57, 315, 300)         # dan plate (left column)
DSTAMP_C = (177, 462)            # stamp centre
D_FLOOR = 921                    # Momo's floor line in the left column
SONG_Y0, SONG_PITCH, SONG_H = 132, 276, 246
EXAM_Y0, EXAM_PITCH, EXAM_H = 345, 154, 141


def dan_bg():
    cv = _cv_full()
    cv.rect(0, 0, 1920, 1080, C["bg0"])
    deco.sky(cv, 0, 0, 1920, 336)
    deco.ground(cv, 0, D_FLOOR, 1920, 1080)
    return cv.result()


def dan_board():
    x0, y0, x1, y1 = DB
    cv = Canvas(x1 - x0 + U, y1 - y0 + U)
    chrome.panel(cv, 0, 0, x1 - x0, y1 - y0, fill=C["bg2"])
    return cv.result()


def dan_plate():
    """Left-column dan plate: panel with a 16U dan-accent band (段位道場: drawn by the Lua) and room for
    the engine title."""
    x0, y0, x1, y1 = DPL
    cv = Canvas(x1 - x0 + U, y1 - y0 + U)
    b = chrome.panel(cv, 0, 0, x1 - x0, y1 - y0)
    cv.rect(b.ix0, b.iy0, b.ix1, b.iy0 + 16 * U, C["dan"])
    cv.rect(b.ix0, b.iy0 + 16 * U, b.ix1, b.iy0 + 17 * U, INK)
    return cv.result()


def song_row(i):
    """Page-1 song row panel (1437 x 246). The number plate, course chip and the four judge chips are
    drawn by the Lua (sized to the player's language)."""
    w, h = 1437, SONG_H
    cv = Canvas(w + U, h + U)
    b = chrome.panel(cv, 0, 0, w, h)
    cv.rect(b.ix0, 147, b.ix1, 150, C["line"])     # header line under the plate row
    return cv.result()


def dan_scorebox():
    """Page-2 score box (the スコア chip is drawn by the Lua)."""
    w, h = 441, 153
    cv = Canvas(w + U, h + U)
    chrome.frame(cv, 0, 0, w, h, fill=C["dan"])
    return cv.result()


def totals_panel():
    """Page-2 totals: two columns x 3 rows (row rules baked; chips and values by Lua)."""
    w, h = 864, 177
    cv = Canvas(w + U, h + U)
    chrome.panel(cv, 0, 0, w, h)
    for c in range(2):
        for r in range(2):
            x = 18 + c * 432
            y = 18 + r * 54
            cv.rect(x, y + 51, x + 396, y + 54, C["line"])
    return cv.result()


def exam_row():
    w, h = 1413, EXAM_H
    cv = Canvas(w + U, h + U)
    chrome.panel(cv, 0, 0, w, h)
    return cv.result()


def stamp_word(key, lang):
    """The stamp lettering for a language (Latin in capitals: it reads as a stamp)."""
    from . import strings
    t = strings.get(key, lang)
    return t.upper() if lang == "en" else t


def dan_stamp(kind, lang):
    """合格 (red or gold letters) / 不合格 (bad blue), U-grid cell lettering in an ink-ringed paper
    stamp, one sheet per language (dan_pass / dan_fail). The フルコンボ / 全良 chip under the stamp (frames
    1, 2, 4, 5) is drawn by the Lua at y 228."""
    W, H = 306, 264
    cv = Canvas(W, H)
    b = chrome.frame(cv, 0, 0, W - 2 * U, 207, fill=PAPER, border=2 * U, shadow=2 * U, notch=U)
    col = {"red": C["don"], "gold": C["clear"], "fail": C["bad"]}[kind]
    ring = col if kind != "gold" else C["clear"]
    cv.rect(b.ix0 + U, b.iy0 + U, b.ix1 - U, b.iy0 + 2 * U, ring)
    cv.rect(b.ix0 + U, b.iy1 - 2 * U, b.ix1 - U, b.iy1 - U, ring)
    cv.rect(b.ix0 + U, b.iy0 + U, b.ix0 + 2 * U, b.iy1 - U, ring)
    cv.rect(b.ix1 - 2 * U, b.iy0 + U, b.ix1 - U, b.iy1 - U, ring)
    text = stamp_word("dan_fail" if kind == "fail" else "dan_pass", lang)
    cell = 2 * U if kind == "fail" else 3 * U
    stamp_text(cv, b.cx, b.cy, text, cell, col, shadow=True, lang=lang, max_w=b.ix1 - b.ix0 - 16 * U)
    return cv.result()


def stage_bg():
    """Promotion / congrats overlay backdrop: the festival stage, full screen."""
    cv = _cv_full()
    cv.rect(0, 0, 1920, 1080, C["bg0"])
    deco.sky(cv, 0, 0, 1920, 540)
    deco.lanterns(cv, 0, 1920, 540, n=8)
    deco.ground(cv, 0, 909, 1920, 1080)
    return cv.result()


def promo_dialog():
    """The promotion / congrats window: chrome.dialog with its gold title band; the title (昇段 /
    おめでとう！) is drawn by the Lua in the player's language."""
    W, H = 1104, 300
    cv = Canvas(W + 2 * U, H + 2 * U)
    b = chrome.dialog(cv, 0, 0, W, H)
    ty1 = b.iy0 + chrome.DIALOG_TITLE_H
    cv.rect(b.ix0, b.iy0, b.ix1, ty1, C["focus"])
    cv.rect(b.ix0, ty1, b.ix1, ty1 + U, INK)
    return cv.result()


def build_dan(G):
    s = OwnSubset(G, "dan_result", "ss")
    s.add("bg", [dan_bg()])
    s.add("board", [dan_board()])
    s.add("plate", [dan_plate()])
    s.add("song_row", [song_row(0)])
    s.add("scorebox", [dan_scorebox()])
    s.add("score_digit", score_digits())
    s.add("totals", [totals_panel()])
    s.add("exam_row", [exam_row()])
    # the 合格 / 不合格 stamps are cell lettering (no engine text that size): one sheet per language,
    # picked by the Lua lookup (dan_result/ss/stamp -> stamp_<lang>, _ja, _en). Frames as before:
    # red x3, gold x3 (variant 0 / FC chip / 全良 chip: the chips are run-time), fail.
    for lang in strings_langs():
        s.add("stamp_" + lang, [dan_stamp(k, lang) for k in ("red", "red", "red", "gold", "gold", "gold", "fail")])
        s.add("gokaku_" + lang, [_gokaku(lang)])
    s.add("soul", soul_frames())
    s.add("stage", [stage_bg()])
    s.add("dialog", [promo_dialog()])
    add_fireworks(s)
    # word chips, number plates, exam labels, best banner, dialog titles, the no-save note: run time
    return s.write()


def strings_langs():
    from . import strings
    return strings.LANGS


def _gokaku(lang):
    cv = Canvas(345, 144)
    stamp_text(cv, 168, 66, stamp_word("dan_pass", lang), 4 * U, C["clear"], shadow=True, lang=lang, max_w=300)
    return cv.result()


# ================================================================ ancestor keys: blanked
# Our own Scripts/result/*.lua replace every parent result script and draw only result/ss + dan_result/ss,
# and no engine C++ reads these keys (the only C++ check is the folder test has_dan_result_art("shoudan" /
# "congrats"), which our folders still pass). So every ancestor key of these subsets is written as a 1x1U
# transparent single image: no Green / Nijiiro art can ever show, and no VRAM is spent on it.
ANCESTOR_SUBSETS = {
    "result": ("background", "basin", "bottom", "crown", "gauge", "retry", "score"),
    "dan_result": ("background", "bestscore", "congrats", "exam_info", "gauge", "result_info", "shoudan",
                   "tamashii"),
}
OWNS += [f"Graphics/{scr}/{sub}" for scr, subs in ANCESTOR_SUBSETS.items() for sub in subs]


def blank_ancestors(G):
    n = 0
    for scr, subs in ANCESTOR_SUBSETS.items():
        for sub in subs:
            w = SubsetWriter(G, scr, sub)
            keys = []
            for _, gdir, _, _ in ANCESTORS:
                for k in (anc_json(gdir, scr, sub) or {}):
                    if k not in keys:
                        keys.append(k)
            for k in keys:
                g = resolve(scr, sub, k)
                if g is None:      # listed but no ancestor ships the image: the engine loads nothing
                    continue
                w.out[k] = ("file", style.blank_l(U, U))
                w.keys[k] = to_phys_entry(g.entry, g.scale)
                w.mode[k] = "crisp"
            n += w.write()
    return n


# ================================================================ module entry points
def build(ctx):
    n = build_result(ctx.G)
    n += build_dan(ctx.G)
    n += blank_ancestors(ctx.G)
    # own Lua: lua/result/** (Scripts-relative), copied here (the module NAME is v2_result)
    src = os.path.join(HERE, "lua", "result")
    for root, _, files in os.walk(src):
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), src)
            dst = os.path.join(ctx.scripts, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(os.path.join(root, f), dst)
            n += 1
    # generated geometry for the Lua (bubble height, board heights, row pitch, breakdown strip)
    gen = os.path.join(ctx.scripts, "result", "ss_result_def.lua")
    with open(gen, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERATED by ss/v2_result.py: result geometry (logical)\n")
        f.write("return { bubble_h = %d, judge_chip_w = %d, dist_chip_w = %d,\n" % (BUB_H, 156, 66))
        f.write("  pitch_s = %d, pitch_t = %d, board_s_y1 = %d, board_t_y1 = %d,\n" % (JPITCH_S, JPITCH_T, BY1_S, BY1_T))
        cw, ch = course.crown_size(CROWN_BIG_CELL)
        f.write("  dist_row_y = %d, dist_bar = { %s }, dist_slots = { %s }, dist_slot_w = %d,\n"
                % (DIST_ROW_Y, ", ".join(map(str, DIST_BAR)), ", ".join(map(str, DIST_SLOTS)), DIST_SLOT_W))
        # polish: big crown (w, h); fireworks: cell, burst centre offset in the image, rise rows
        f.write("  crown_big = { %d, %d }, fw_cell = %d, fw_r = %d, fw_rise = %d, fw_variants = %d }\n"
                % (cw + U, ch + U, FW_CELL, FW_R * FW_CELL, FW_RISE_ROWS, len(FW_VARIANTS)))
    return n + 1
