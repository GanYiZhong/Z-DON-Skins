"""v2 module `meta`: dan select, game over, retry game, dan loading and the global overlays
(timer, nameplate, guide pill, transitions, credit / entry overlays, network msg, allnet icon,
practice timer) on Nijiiro's layouts, drawn as original light 8-bit art.

Units: every coordinate here is LOGICAL (1920x1080); Canvas / SubsetWriter turn them physical.
Bible numbers are translated with the core table (U = 3, mascot k menu 6 / scene 9 / tiny 3,
text 18/24/36/48). See reports/v2_meta.md."""
from __future__ import annotations

import os
import re

from . import chrome, deco, mascot, strings, style
from .atlas import OwnSubset, SubsetWriter, ancestor_script
from .style import C, U, Canvas, blank_l

NAME = "v2_meta"
OWNS = [
    "Graphics/dan_select", "Graphics/game_over", "Graphics/retry_game", "Graphics/dan_loading",
    "Graphics/global/timer", "Graphics/global/nameplate", "Graphics/global/indicator",
    "Graphics/global/overlay", "Graphics/global/network_msg", "Graphics/global/practice_timer",
    "Graphics/global/rainbow_transition", "Graphics/global/result_transition", "Graphics/global/ss_meta",
    "Scripts/dan_select", "Scripts/game_over", "Scripts/retry_game",
    "Scripts/global/timer.lua", "Scripts/global/nameplate.lua", "Scripts/global/guide_panel.lua",
    "Scripts/global/transition.lua", "Scripts/global/result_transition.lua",
    "Scripts/global/coin_overlay.lua", "Scripts/global/allnet_indicator.lua",
    "Scripts/global/practice_timer.lua", "Scripts/global/ss_meta.lua", "Scripts/global/entry_overlay.lua",
]

INK = C["ink"]
PAPER = C["paper"]

# dan colour (box.dan_color 0..6) -> fill; one system for chips, plates, plaques
DAN_COL = [C["tower"], C["tower"], C["hard"], C["don"], C["line"], C["dan"], C["normal"]]
# rank_plate frames (Nijiiro order)
RANKS = ["五級", "四級", "三級", "二級", "一級", "初段", "二段", "三段", "四段", "五段", "六段", "七段",
         "八段", "九段", "十段", "玄人", "名人", "超人", "達人", "創作", "外伝", "初級", "十級", "九級",
         "八級", "七級", "六級"]
# nameplate dan_emblem frames (Nijiiro order)
EMBLEMS = ["初級", "十級", "九級", "八級", "七級", "六級", "五級", "四級", "三級", "二級", "一級", "初段",
           "二段", "三段", "四段", "五段", "六段", "七段", "八段", "九段", "十段", "玄人", "名人", "超人", "達人"]


# frame-local text positions captured while the frames are drawn (some depend on the ancestor frame size);
# write_lua puts them into the dan_select.lua tail
LAYOUT: dict[str, tuple] = {}
LANG_VARIANTS = ("en", "zh", "ko")


def put_lang_variants(w, key, draw, entry=None):
    """Bake `key` once per language: `<key>_en / _zh / _ko` (draw(..., lang=l)) and the Japanese base `<key>`.
    For C++ fixed-name textures: the engine (skin option language_variants) prefers `<name>_<lang>`."""
    for lang in LANG_VARIANTS:
        w.put(key, lambda i, nn, ww, hh, lang=lang: lang_font_call(lang, draw, i, nn, ww, hh), entry=entry)
        for d in (w.out, w.keys, w.mode):
            d[f"{key}_{lang}"] = d.pop(key)
    w.put(key, draw, entry=entry)


# the Fusion Pixel file the engine uses for a language (ss/fonts.py: font_tw = zh_tw, font_kr = ko), so a
# baked variant has the glyph forms the engine text around it has
LANG_FONT = {"zh": "zh_tw", "ko": "ko"}  # Z-DON: zh is Traditional Chinese


def lang_font_call(lang, draw, i, nn, ww, hh):
    base = style.FONT_PIXEL
    if lang in LANG_FONT:
        style.FONT_PIXEL = base.replace("-ja.ttf", "-%s.ttf" % LANG_FONT[lang])
        style.font_phys.cache_clear()
    try:
        return draw(i, nn, ww, hh, lang=lang)
    finally:
        if style.FONT_PIXEL != base:
            style.FONT_PIXEL = base
            style.font_phys.cache_clear()


def rank_key(name):
    """ss/strings.py key of a dan / kyu rank name (二段 -> dan_2)."""
    for k, v in strings.STRINGS.items():
        if k.startswith("dan_") and v["ja"] == name:
            return k
    raise KeyError(name)


def rank_col(name):
    if name.endswith("級"):
        return C["tower"]
    if name in ("初段", "二段", "三段", "四段", "五段"):
        return C["hard"]
    if name.endswith("段"):
        return C["don"]
    if name == "達人":
        return C["dan"]
    if name == "創作":
        return C["wood"]
    if name == "外伝":
        return C["normal"]
    return C["line"]          # 玄人 / 名人 / 超人: silver


def rank_mark(name):
    """The mark in a rank emblem: the number of a dan / kyu (十段 -> 十), else the first glyph."""
    if len(name) >= 2 and name[-1] in ("段", "級"):
        return name[:-1]
    return name[0]


def g(v):
    """floor to the U grid"""
    return int(v // U * U)


def text_on(cv, x, y, s, size, fill, anchor="mm"):
    """Text on a fill: ink on light fills, paper + 1U ink outline on saturated ones."""
    if fill in (C["don"], C["hard"], C["ka"], C["p1"], C["p2"], C["normal"], C["ura"], C["wood2"], C["grass"]):
        cv.text(x, y, s, size, PAPER, anchor=anchor, outline=U)
    else:
        cv.text(x, y, s, size, INK, anchor=anchor)


def vtext(cv, cx, y0, s, size, fill=INK, outline=0, gap=0):
    """Vertical text: one glyph per row, centred on cx, starting at y0."""
    for i, ch in enumerate(s):
        cv.text(cx, y0 + i * (size + gap) + size / 2, ch, size, fill, anchor="mm", outline=outline)


def emblem(cv, cx, cy, fill=PAPER):
    """The small dan emblem on chip caps: a pixel drum-top (disc + ink ring + inner dot)."""
    deco.pixdisc(cv, cx, cy, 4, fill, cell=U)
    cv.rect(g(cx) - U, g(cy) - U, g(cx) + U, g(cy) + U, INK)


def border_ring(cv, x0, y0, x1, y1, col, w):
    cv.rect(x0, y0, x1, y0 + w, col)
    cv.rect(x0, y1 - w, x1, y1, col)
    cv.rect(x0, y0, x0 + w, y1, col)
    cv.rect(x1 - w, y0, x1, y1, col)


def focus_ring(cv, x0, y0, x1, y1):
    """Focus = 1U ink + 2U gold + 1U ink ring (transparent inside), notched corners."""
    chrome.notched(cv, x0, y0, x1, y1, INK, U)
    cv.rect(x0 + U, y0 + U, x1 - U, y1 - U, C["clear"])
    cv.rect(x0 + 3 * U, y0 + 3 * U, x1 - 3 * U, y1 - 3 * U, INK)
    cv.rect(x0 + 4 * U, y0 + 4 * U, x1 - 4 * U, y1 - 4 * U, (0, 0, 0, 0))


# ================================================================ shared scene / icons
def scene(w, h, ground_y, clouds=((120, 48, "M"), (1410, 30, "S")), sky_h=252, props=False):
    """The house scene: sky band with the horizon checker, cream, ground strip at ground_y."""
    cv = Canvas(w, h, bg=C["bg0"])
    deco.sky(cv, 0, 0, w, sky_h)
    for x, y, s in clouds:
        deco.cloud(cv, x, y, s)
    if props:
        deco.lanterns(cv, 0, w, sky_h - 24 * U, 8)
    deco.ground(cv, 0, ground_y, w, h)
    return cv


ICONS = {
    # 8x8 cells at k=3, one set (bible: camera / card / phone; + dojo, network)
    "card": ["........", "KKKKKKKK", "KGGGGGGK", "KKKKKKKK", "KPPPPPPK", "KPPRRPPK", "KPPPPPPK", "KKKKKKKK"],
    "phone": [".KKKKKK.", ".KPPPPK.", ".KPKKPK.", ".KPKKPK.", ".KPPPPK.", ".KPPPPK.", ".KPPRPK.", ".KKKKKK."],
    "dojo": ["..KKKK..", ".KRRRRK.", "KRPPPPRK", "KRPPPPRK", "KRPPPPRK", ".KRRRRK.", "..KKKK..", "........"],
}
ICON_PAL = {"K": INK, "G": C["clear"], "P": PAPER, "R": C["don"]}


def icon(cv, x, y, name, cell=3):
    deco.cells(cv, x, y, ICONS[name], ICON_PAL, cell)


def neutral_chip(cv, x0, y0, x1):
    """The not-connected state: an empty bg3 chip (not an error NG); its word (オフ / なし) is engine
    text in the player's language (entry_overlay.lua / coin_overlay.lua)."""
    return chrome.chip(cv, x0, y0, x1, None, None, accent=C["bg3"])


def status_tile(w, h, name, ok):
    """A 106x106 status tile: panel, pixel icon, OK chip (connected) or a neutral dash chip (offline:
    the free-play install is always offline, so NG would read as an error state)."""
    cv = Canvas(w, h)
    b = chrome.panel(cv, 0, 0, 99, 99)
    icon(cv, g(b.cx - 24), b.iy0 + U, name, 6)
    # text24: the word is 24 px engine text, so the chip is 11U (33) high, y 60..93 (centre 76.5)
    if ok:   # the OK word is engine text (entry_overlay.lua: the chip centre TILE_OK)
        chrome.chip(cv, b.ix0 + 3 * U, 60, b.ix1 - 3 * U, 93, None, accent=C["mint"])
    else:
        chrome.chip(cv, b.ix0 + 3 * U, 60, b.ix1 - 3 * U, 93, None, accent=C["bg3"])
    return cv.result()


# ================================================================ dan select
def seal(cv, cx, cy, r, i, s, size):
    """Pass seal: paper disc, a 2-cell ring in the pass colour (frames 0-2 red, 3-5 gold), the text in
    the matching text-strength colour. Full combo (1, 4) adds an inner ring, all good (2, 5) a gold /
    red inner ring."""
    ring = C["don"] if i < 3 else C["clear"]
    tcol = C["red_t"] if i < 3 else C["gold_t"]
    inner = {0: None, 1: (ring, 1), 2: ((C["clear"] if i < 3 else C["don"]), 1)}[i % 3]
    deco.pixdisc(cv, cx, cy, r, PAPER, cell=U, ring_w=1)
    deco.pixdisc(cv, cx, cy, r - 2, PAPER, ring=ring, ring_w=2, cell=U)
    if inner:
        deco.pixdisc(cv, cx, cy, r - 4, PAPER, ring=inner[0], ring_w=1, cell=U)
    if s:
        cv.text(cx, cy, s, size, tcol)


# dan chip strip (round 2): chips 42 wide (14U) on a 69 px (23U) ribbon pitch, so the gaps hold the
# arrows; 141 tall, so the selected chip (dropped 21) ends above the board's top edge (183).
# Every box/back texture is drawn at bx + entry x; CHIP_E = entry x keeps the chip on the screen U grid.
CHIP_E, CHIP_TOP = -42, 15            # folder entry (frame origin = bx - 42, y 15)
CHIP_X0, CHIP_X1, CHIP_Y1 = 21, 63, 141
CAP_Y1 = 45                           # cap fill to 45, 1U ink rule 45..48, name area 48..141


PLATE_CHIP_C = (141, 123)             # rank chip text centre in the plate frame (screen 258, 294)
PLATE_CAP_C = (138, 36)               # 段位道場 on the plate's gold cap
PLATE_SLOT_C = (138, 372)             # 未 in the seal slot


def dashed_ring(cv, cx, cy, r, col, dashes=20):
    """A 1U pixel ring of radius r cells around (cx, cy), drawn as `dashes` on / off arcs."""
    import math
    R = r + 1
    x0, y0 = deco.snap(cx - R * U), deco.snap(cy - R * U)
    inner = {(x + 1, y + 1) for x, y in deco.disc_cells(r)}
    for x, y in deco.disc_cells(R):
        if (x, y) in inner:
            continue
        a = math.atan2(y + .5 - R, x + .5 - R) % (2 * math.pi)
        if int(a / (2 * math.pi) * dashes * 2) % 2 == 0:
            cv.rect(x0 + x * U, y0 + y * U, x0 + (x + 1) * U, y0 + (y + 1) * U, col)


def chip_body(cv, cap_col):
    """A dan chip: panel, colour cap with the emblem, paper body for the engine's vertical name."""
    b = chrome.panel(cv, CHIP_X0, 0, CHIP_X1, CHIP_Y1)
    cv.rect(b.ix0, b.iy0, b.ix1, CAP_Y1, cap_col)
    cv.rect(b.ix0, CAP_Y1, b.ix1, CAP_Y1 + U, INK)
    emblem(cv, (CHIP_X0 + CHIP_X1) / 2, 24)
    return b


def build_dan_select(ctx):
    n = 0
    # ---- global: background scene (the board covers x 330..1874, y 182..1054)
    w = SubsetWriter(ctx.G, "dan_select", "global")
    w.put("bg", lambda i, nn, ww, hh: scene(ww, hh, 912).result())
    for k in ("dan_select", "footer", "bg_footer", "bg_header", "arrow"):
        w.put_blank(k)
    n += w.write()

    # ---- box: chips, cursor, arrows, stamps
    w = SubsetWriter(ctx.G, "dan_select", "box")

    chip_entry = {"x": CHIP_E, "y": CHIP_TOP}

    def folder(i, nn, ww, hh):
        cv = Canvas(ww, hh)
        chip_body(cv, DAN_COL[min(i, 6)])
        return cv.result()
    w.put("folder", folder, entry=chip_entry)

    def cursor(i, nn, ww, hh):
        # focus ring hugging the chip: 1U ink outside, 1U gold over the chip's border, 1U ink inside
        # (frame origin 3 px up and left of the chip's: entry y 12)
        cv = Canvas(ww, hh)
        x0, y0, x1, y1 = CHIP_X0 - U, 0, CHIP_X1 + U, CHIP_Y1 + 2 * U
        chrome.notched(cv, x0, y0, x1, y1, INK, U)
        cv.rect(x0 + U, y0 + U, x1 - U, y1 - U, C["clear"])
        cv.rect(x0 + 2 * U, y0 + 2 * U, x1 - 2 * U, y1 - 2 * U, INK)
        cv.rect(x0 + 3 * U, y0 + 3 * U, x1 - 3 * U, y1 - 3 * U, (0, 0, 0, 0))
        return cv.result()
    w.put("cursor", cursor, entry={"x": CHIP_E, "y": CHIP_TOP - U})

    ARROW = ["X..", "XX.", "XXX", "XX.", "X.."]

    def arrow(right):
        def f(i, nn, ww, hh):          # 5x7 cells with the outline = 15x21, top-left at the frame origin
            cv = Canvas(ww, hh)
            rows = ARROW if right else [r[::-1] for r in ARROW]
            deco.cells(cv, U, U, rows, {"X": C["clear"]}, U, outline=INK)
            return cv.result()
        return f
    # in the gaps beside the ring (ring +-24, neighbours +-48 on the 69 pitch), centred on the name area
    w.put("arrow_r", arrow(True), entry={"x": 27, "y": 99})
    w.put("arrow_l", arrow(False), entry={"x": -42, "y": 99})

    def small_stamp(i, nn, ww, hh):    # a small pass seal over the chip's cap (cap centre y 39)
        cv = Canvas(ww, hh)
        ring = C["don"] if i < 3 else C["clear"]
        fill = PAPER if i % 3 == 0 else (C["mint"] if i % 3 == 1 else C["bg3"])
        deco.pixdisc(cv, 39, 24, 6, fill, ring=INK, ring_w=1, cell=U)
        deco.pixdisc(cv, 39, 24, 5, fill, ring=ring, ring_w=1, cell=U)
        return cv.result()          # the 合 mark: engine text (dan_select.lua labels, dan_pass_mark)
    w.put("clear_mark", small_stamp, entry={"x": -39, "y": CHIP_TOP})
    for k in ("back_graphic", "back_text", "back_text_highlight", "folder_texture_left", "folder_texture",
              "folder_texture_right"):
        w.put_blank(k)
    n += w.write()

    # ---- back chip
    w = SubsetWriter(ctx.G, "dan_select", "back")

    def back(i, nn, ww, hh):
        cv = Canvas(ww, hh)
        b = chip_body(cv, C["bg3"])
        # a pixel return arrow on the cap instead of the emblem
        cv.rect(b.ix0, b.iy0, b.ix1, CAP_Y1, C["bg3"])
        rows = ["..X....", ".XX....", "XXXXXX.", ".XX..X.", "..X..X.", ".....X.", "..XXXX."]
        deco.cells(cv, (CHIP_X0 + CHIP_X1) / 2 - 12, 12, rows, {"X": C["ka"]}, U, outline=INK)
        return cv.result()
    w.put("folder", back, entry={"x": CHIP_E, "y": CHIP_TOP})
    for k in ("chip", "board_tl", "board_t", "board_tr", "board_r", "board_br", "board_b", "board_bl", "board_l",
              "board_c", "graphic", "text", "pill"):
        w.put_blank(k)
    n += w.write()

    n += build_yellow_box(ctx)
    n += build_confirm(ctx)

    w = SubsetWriter(ctx.G, "dan_select", "dan_transition")   # Green-only, nothing draws it in Nijiiro
    for k in ("background", "don", "emblem", "flash"):
        w.put_blank(k)
    n += w.write()
    return n


# the course board: Nijiiro's 9-slice, pieces from x 330 / y 182 (anim 13-17) to 1874 / 1054 (bottom 974).
# Round 2: the panel inside the pieces starts right of the dan plate (plate ends 390 with its shadow)
# and ends above the hint pill's footer zone (y >= 981): outer border x 399..1869, y 183..972 (1U shadow to 1872 / 975).
PX0 = 330                                    # left pieces' origin (animation 13's end)
BX0, BY0, BX1, BY1 = 399, 183, 1869, 972


def board_piece(key, ww, hh, ox, oy):
    """Piece of the board panel, piece origin at (ox, oy) in board-absolute coords."""
    big = Canvas(ww, hh)
    # draw the panel in piece coords: board outer rect shifted by -origin
    x0, y0, x1, y1 = BX0 - ox, BY0 - oy, BX1 - ox, BY1 - oy
    for sh, col in ((U, INK), (0, INK)):
        chrome.notched(big, x0 + sh, y0 + sh, x1 + sh, y1 + sh, col, U)
    big.rect(x0 + U, y0 + U, x1 - U, y1 - U, PAPER)
    return big.result()


def build_yellow_box(ctx):
    w = SubsetWriter(ctx.G, "dan_select", "yellow_box")
    E = 80
    pieces = {
        "yellow_box_top_left": (PX0, 182), "yellow_box_top_right": (1794, 182),
        "yellow_box_bottom_left": (PX0, 974), "yellow_box_bottom_right": (1794, 974),
        "yellow_box_top": (PX0 + E, 182), "yellow_box_bottom": (PX0 + E, 974),
        "yellow_box_left": (PX0, 182 + E), "yellow_box_right": (1794, 182 + E),
        "yellow_box_center": (PX0 + E, 182 + E),
    }
    for k, (ox, oy) in pieces.items():
        w.put(k, lambda i, nn, ww, hh, ox=ox, oy=oy: board_piece(k, ww, hh, ox, oy),
              entry={"x": 0, "y": 0})

    # ---- song rows (genre_banner 1380x104 at 412,234; step 110)
    def row(i, nn, ww, hh):
        cv = Canvas(ww, hh)
        chrome.frame(cv, 0, 0, 1377, 99, C["bg2"], border=U, shadow=U, notch=U)
        return cv.result()
    w.put("genre_banner", row)

    def song_label(i, nn, ww, hh):       # 80x80 at (430,246): "1曲目"
        cv = Canvas(ww, hh)
        b = chrome.panel(cv, 0, 0, 75, 75)
        cv.text(b.cx, 30, str(i + 1), 36, INK)     # 曲目 under it: engine text (dan_song_label)
        return cv.result()
    w.put("song_label", song_label)

    # the course is core's course chip, drawn from Lua (UI.course.chip at 525, 249 + row); the
    # engine's difficulty frame is too narrow for it
    w.put_blank("difficulty")

    def level(i, nn, ww, hh):            # 72x36, under the course chip: ★n
        cv = Canvas(ww, hh)
        s = "★" + (str(i + 1) if i < 10 else "10+")
        cv.text(0, hh / 2, s, 24, INK, anchor="lm")
        return cv.result()
    w.put("difficulty_level", level, entry={"x": 528, "y": 282})
    for k in ("difficulty_star", "difficulty_num", "difficulty_x", "difficulty_ura", "total_notes_bg",
              # the non-grid exam board (Nijiiro runs dan_exam_grid): blank
              "exam_box_top_left", "exam_box_top_right", "exam_box_bottom_left", "exam_box_bottom_right",
              "exam_box_top", "exam_box_bottom", "exam_box_left", "exam_box_right", "exam_box_center"):
        w.put_blank(k)

    # "？？？" (masked title) and 総ノーツ数: words only, drawn as engine text (dan_select.lua labels); the
    # keys stay as transparent frames (the parent tests hidden_title to hide the song title)
    def words_only(key, ox, oy_frac):
        def f(i, nn, ww, hh):
            LAYOUT[key] = (ox, hh * oy_frac)
            return blank_l(ww, hh)
        return f
    w.put("hidden_title", words_only("hidden_title", 6, 0))
    LAYOUT["hidden_title"] = (6, 30)
    w.put("total_notes", words_only("total_notes", 0, .5))

    def digit(size, fill=INK):
        def f(i, nn, ww, hh):
            cv = Canvas(ww, hh)
            cv.text(ww / 2, hh / 2, str(i), size, fill)
            return cv.result()
        return f
    w.put("total_notes_counter", digit(36))
    w.put("judge_num", digit(36))

    def word(s, size=24):
        def f(i, nn, ww, hh):
            cv = Canvas(ww, hh)
            cv.text(0, hh / 2, s, size, INK, anchor="lm")
            return cv.result()
        return f
    w.put("exam_percent", word("%"))
    # 未満 / 以上 belong to the parent's non-grid exam rows; our exam grid prints the engine's captions
    w.put_blank("exam_less")
    w.put_blank("exam_more")

    # ---- exam area
    def header(i, nn, ww, hh):           # 410x37 at (420,561): the 合格条件 tab on the frame's top edge
        cv = Canvas(ww, hh)
        chrome.frame(cv, 0, 0, 270, 36, C["dan"], border=U, shadow=0, notch=U)   # 合格条件: engine text
        return cv.result()
    w.put("exam_header", header, entry={"x": 420, "y": 561})

    def exam_frame(i, nn, ww, hh):       # 1369x421 drawn at (417,594): x 417..1782, y 594..957
        cv = Canvas(ww, hh)
        chrome.frame(cv, 0, 0, 1365, 363, C["bg2"], border=U, shadow=0, notch=U)
        return cv.result()
    w.put("exam_frame", exam_frame, entry={"x": 417, "y": 594})

    def gauge_box(i, nn, ww, hh):        # 321x171 drawn at (436,610)
        cv = Canvas(ww, hh)
        chrome.panel(cv, 0, 6, 315, 165)
        return cv.result()
    w.put("exam_gauge_box", gauge_box)

    def judge_box(i, nn, ww, hh):        # 1008x136 drawn at (766,608)+132*row
        cv = Canvas(ww, hh)
        chrome.panel(cv, 0, 6, 1002, 123)
        return cv.result()
    w.put("judge_box", judge_box)

    # exam name tabs: chrome only, the name is engine text (exam_panel in the dan_select.lua tail)
    for k in ("exam_gauge", "exam_combo", "exam_score", "exam_hit", "exam_roll", "exam_judgeperfect",
              "exam_judgebad", "exam_judgegood"):
        def pill(i, nn, ww, hh):         # 260x44 drawn at (box x+28, box y-1): tab on the box top
            cv = Canvas(ww, hh)
            chrome.chip(cv, 0, 0, 228, 36, None, accent=C["dan"], edge=True)   # text24: 36 high (was 33)
            return cv.result()
        w.put(k, pill, entry={"x": 0, "y": 0})      # our Lua grid draws it at absolute positions

    def seg(i, nn, ww, hh):              # 163x34 x4: the 全体 / 1曲目..3曲目 chip; our Lua grid draws it
        cv = Canvas(ww, hh)              # itself, sized to the label (this textless frame is a fallback)
        chrome.chip(cv, 0, 0, 87, 36, None, accent=C["line"], edge=False)
        return cv.result()
    w.put("exam_seg_label", seg, entry={"x": 0, "y": 0})

    def best(ww_, hh_):
        def f(i, nn, ww, hh):
            cv = Canvas(ww, hh)
            chrome.chip(cv, 0, 0, g(ww), g(hh), None, accent=C["bg3"])
            return cv.result()
        return f
    w.put("exam_best_pill", best(317, 31))
    w.put("exam_gauge_best_pill", best(302, 32))

    # ---- rank plate (27, baked name) and frame (7, engine draws the name at y 380). Plate x 123..387,
    # y 171..675 on screen: a colour cap with the name, the large rank emblem (3U = 9 px cells, the
    # scene-k grid) and the seal slot where the pass stamp (yellow_box/clear_mark) lands.
    # Round 3: the cap is the dan accent everywhere (gold, ink 段位道場, as the game's and the dan
    # result's plates); the tier lives only on the rank chip (bg3, 2U tier-colour left edge, 48 px ink
    # name). The frame variant's chip is blank: the Lua draws box.dan_title in it (PLATE_CHIP_C).
    def plate(col, name=None):
        def f(i, nn, ww, hh):
            cv = Canvas(ww, hh)
            c = col if name is None else rank_col(RANKS[i])
            b = chrome.panel(cv, 6, 0, 270, 504)
            cv.rect(b.ix0, b.iy0, b.ix1, 69, C["dan"])
            cv.rect(b.ix0, 69, b.ix1, 72, INK)
            # words (段位道場 on the cap, the rank name on the chip, 未 in the seal slot): engine text, the
            # dan_select.lua labels at PLATE_CAP_C / PLATE_CHIP_C / PLATE_SLOT_C
            r = chrome.frame(cv, 30, 87, 246, 159, C["bg3"], border=U, shadow=0, notch=0)
            cv.rect(r.ix0, r.iy0, r.ix0 + 2 * U, r.iy1, c)
            # the dan emblem: a neutral drum-top (9 px cells, gold inner ring, ink centre)
            deco.pixdisc(cv, 138, 222, 4, PAPER, ring=INK, ring_w=1, cell=3 * U, inner_ring=(C["dan"], 1))
            cv.rect(129, 213, 147, 231, INK)
            # the seal slot (the pass stamp lands here): a dashed 1U outline with 未, so it reads as a slot
            dashed_ring(cv, 138, 372, 28, C["mute"])
            return cv.result()
        return f
    w.put("rank_plate", plate(None, True))

    def frame(i, nn, ww, hh):
        return plate(DAN_COL[min(i, 6)])(i, nn, ww, hh)
    w.put("frame", frame)

    def big_stamp(i, nn, ww, hh):        # 293x258 x6, seal centre (147,111) on the plate's slot (255,543)
        cv = Canvas(ww, hh)
        cx, cy = 147, 111
        # 合格 and the フルコンボ / 全良 chip under it (sized to the word): Lua, the dan_select.lua labels
        seal(cv, cx, cy, 28, i, None, 48)
        return cv.result()
    w.put("clear_mark", big_stamp, entry={"x": 108, "y": 432})
    return w.write()


def build_confirm(ctx):
    w = SubsetWriter(ctx.G, "dan_select", "confirm_box")

    def bg(i, nn, ww, hh):               # 1392x512 at (264,239)
        cv = Canvas(ww, hh)
        b = chrome.dialog(cv, 0, 0, 1386, 504)
        # the gold title band (chrome.dialog's); its 段位道場 title is engine text (LAYOUT confirm_title)
        th = chrome.DIALOG_TITLE_H
        cv.rect(b.ix0, b.iy0, b.ix1, b.iy0 + th, C["focus"])
        cv.rect(b.ix0, b.iy0 + th, b.ix1, b.iy0 + th + U, INK)
        LAYOUT["confirm_title"] = ((b.ix0 + b.ix1) / 2, b.iy0 + th / 2)
        return cv.result()
    w.put("bg", bg)

    # the question and the two answers: words only, engine text centred on the frame (C++ reads the yes /
    # no x positions, so the keys stay, as transparent frames)
    def centre_words(key):
        def f(i, nn, ww, hh):
            LAYOUT[key] = (ww / 2, hh / 2)
            return blank_l(ww, hh)
        return f
    w.put("confirmation_text", centre_words("confirmation_text"))

    def sel(state):
        def f(i, nn, ww, hh):            # 344x136
            cv = Canvas(ww, hh)
            if state == "outline":
                chrome.cursor(cv, 27, 68, cell=U, fill=PAPER)
            else:
                chrome.button(cv, 9, 27, 333, 108, state=state)
            return cv.result()
        return f
    w.put("selection_box", sel("normal"))
    w.put("selection_box_highlight", sel("focused"))
    w.put("selection_box_outline", sel("outline"))

    w.put("yes", centre_words("yes"))
    w.put("no", centre_words("no"))

    def option(i, nn, ww, hh):           # 98x96 at (565,492): options button with a pixel wrench
        cv = Canvas(ww, hh)
        b = chrome.button(cv, 3, 3, 93, 90)
        rows = ["..X.X.X..", ".XXXXXXX.", "XXX...XXX", ".XX...XX.", "XXX...XXX", ".XXXXXXX.", "..X.X.X.."]
        deco.cells(cv, g(b.cx - 27), g(b.cy - 21), rows, {"X": C["text2"]}, 2 * U, outline=None)
        return cv.result()
    w.put("option", option)

    def opt_hi(i, nn, ww, hh):           # 142x142 at (543,469): option at +22,+23
        cv = Canvas(ww, hh)
        focus_ring(cv, 12, 12, 132, 129)
        return cv.result()
    w.put("option_highlight", opt_hi)
    return w.write()


# ================================================================ dan loading (engine-drawn intro)
PLAQUE_X = 960 - 138              # plaque frame x: its centre column (138) on the screen centre
DAN_OFFSET = 1224                 # skin_config transition_offset.y: Green 816 x its 1.5 scale (see build_dan_loading)


STAGE_H = 20 * U                   # dan intro stage: deck height above the grass line


def intro_stage(cv, x0, x1, foot):
    """A low festival stage on the grass line `foot`: 1U ink outline, 2U wood deck edge, wood2 planks
    on a 10U pitch, a 1U wood2 shadow under the deck edge. Returns the deck top (the cast's foot)."""
    top = foot - STAGE_H
    cv.rect(x0, top, x1, foot, INK)
    cv.rect(x0 + U, top + U, x1 - U, top + 3 * U, C["wood"])
    cv.rect(x0 + U, top + 3 * U, x1 - U, top + 4 * U, C["wood2"])
    cv.rect(x0 + U, top + 4 * U, x1 - U, foot, C["wood"])
    x = x0 + 10 * U
    while x < x1 - 4 * U:
        cv.rect(x, top + 4 * U, x + U, foot, C["wood2"])
        x += 10 * U
    return top


def nobori(cv, cx, foot):
    """A nobori banner standing on the grass: a 2U wood pole with an ink outline, a 1U ink top bar, and a
    dan-gold flag (paper top stripe, drum-top emblem, paper hem) hanging from it. No words."""
    pole_top = foot - 150 * U
    cv.rect(cx - 2 * U, pole_top, cx + 2 * U, foot, INK)
    cv.rect(cx - U, pole_top + U, cx + U, foot, C["wood2"])
    fx0, fx1 = cx + 2 * U, cx + 34 * U
    fy0, fy1 = pole_top + 6 * U, pole_top + 96 * U
    cv.rect(cx - 2 * U, pole_top + 3 * U, fx1 + 2 * U, pole_top + 6 * U, INK)      # top bar
    cv.rect(fx0, fy0, fx1, fy1, INK)
    cv.rect(fx0 + U, fy0 + U, fx1 - U, fy1 - U, C["dan"])
    cv.rect(fx0 + U, fy0 + U, fx1 - U, fy0 + 7 * U, PAPER)
    cv.rect(fx0 + U, fy0 + 7 * U, fx1 - U, fy0 + 8 * U, INK)
    cv.rect(fx0 + U, fy1 - 7 * U, fx1 - U, fy1 - 6 * U, INK)
    cv.rect(fx0 + U, fy1 - 6 * U, fx1 - U, fy1 - U, PAPER)
    ex, ey = g((fx0 + fx1) // 2), g((fy0 + fy1) // 2)
    deco.pixdisc(cv, ex, ey, 5, PAPER, ring=INK, ring_w=1, cell=2 * U, inner_ring=(C["don"], 1))
    cv.rect(ex - 2 * U, ey - 2 * U, ex + 2 * U, ey + 2 * U, INK)


def build_dan_loading(ctx):
    w = SubsetWriter(ctx.G, "dan_loading", "loading_dan")
    # night: 1920x1300 at y -106, slides up 112 px: our scene, ground line at 1080 (on screen 974 -> 862)
    # The engine draws the intro shifted up by transition_offset.y (Green 816 x 1.5 = 1224; Nijiiro has
    # none), which put it off screen; the entries carry +1224 so it lands where it is laid out.
    def night(i, nn, ww, hh):
        # The engine's key says "night", but the house palette has no night: this is the day house scene
        # (sky, lantern string, cream, ground). Momo and Hoshi (scene k) flank the centred rank plaque,
        # both turned to it.
        cv = scene(ww, hh, 1080, sky_h=360, clouds=((150, 150, "M"), (1560, 210, "S")), props=True)
        # polish_meta: the challenge is staged. A festival stage (wood deck) under the plaque with the taiko
        # in the middle; two dan-gold nobori banners (drum-top emblem, no words) frame it; the cast stands
        # on the deck, turned to the plaque.
        deck = intro_stage(cv, 576, 1344, 1080)
        nobori(cv, 456, 1080)
        nobori(cv, 1464, 1080)
        deco.taiko(cv, 960, deck)
        mascot.paste(cv, "hoshi", "turn", "scene", 726, deck)
        mascot.paste(cv, "momo", "turn", "scene", 1194, deck, mirror=True)
        return cv.result()
    w.put("night", night, entry={"x": 0, "y": DAN_OFFSET})       # the engine adds its own -106

    # The plaque, centred on the screen (x 822..1098 incl. shadow, y 40..412): the tier colour as the
    # slab, a gold 段位道場 cap, the dan emblem (drum-top, 9 px cells) and the engine's vertical rank
    # text (role 36, dan_select_title size) centred under it at (960, 290) (dan_loading_rank).
    def plaque(i, nn, ww, hh, lang="ja"):  # 280x560 x7
        cv = Canvas(ww, hh)
        col = DAN_COL[min(i, 6)]
        b = chrome.dialog(cv, 6, 0, 270, 372)
        cv.rect(b.ix0, b.iy0, b.ix1, b.iy1, col)
        cv.rect(b.ix0, b.iy0, b.ix1, b.iy0 + 16 * U, C["dan"])
        cv.rect(b.ix0, b.iy0 + 16 * U, b.ix1, b.iy0 + 17 * U, INK)
        cv.text(138, b.iy0 + 8 * U, strings.get("dan_dojo", lang), 36, INK)
        border_ring(cv, b.ix0 + 2 * U, b.iy0 + 19 * U, b.ix1 - 2 * U, b.iy1 - 2 * U, PAPER, U)
        deco.pixdisc(cv, 138, 132, 4, PAPER, ring=INK, ring_w=1, cell=3 * U, inner_ring=(C["dan"], 1))
        cv.rect(129, 123, 147, 141, INK)
        return cv.result()
    # C++ draws loading_dan/plaque by a fixed name: with skin option language_variants (core) the engine
    # prefers plaque_<lang>, so the cap word ships baked per language (the base stays Japanese)
    put_lang_variants(w, "plaque", plaque, entry={"x": PLAQUE_X, "y": 40 + DAN_OFFSET})
    return w.write()


# ================================================================ globals
def build_timer(ctx):
    w = SubsetWriter(ctx.G, "global", "timer")
    # bg 240x240 at (1669,12): a panel 168x111 centred on (1789,132); our Lua draws the digits
    def bg(red):
        def f(i, nn, ww, hh):
            cv = Canvas(ww, hh)
            x0, y0 = 36, 57
            chrome.panel(cv, x0, y0, x0 + 168, y0 + 111, fill=C["don"] if red else PAPER)
            return cv.result()           # のこり: engine text (timer.lua, timer_left)
        return f
    w.put("bg", bg(False))
    w.put("bg_red", bg(True))
    w.put_blank("highlight")

    def counter(red):
        def f(i, nn, ww, hh):            # 64x96: one 48 px digit, centred
            cv = Canvas(ww, hh)
            if red:
                cv.text(ww / 2, hh / 2, str(i), 48, PAPER, outline=U)
            else:
                cv.text(ww / 2, hh / 2, str(i), 48, INK)
            return cv.result()
        return f
    w.put("counter_black", counter(False))
    w.put("counter_white", counter(True))
    return w.write()


TITLE_BG = ["bg3", "mint", "sky", "pink", "clear"]
RAINBOW = ["easy", "normal", "hard", "oni", "ura", "clear"]
PLATE_X0, PLATE_Y0, PLATE_X1, PLATE_Y1 = 3, 6, 402, 90     # plate body in the 408x96 frame
BAND_Y1 = 45                                               # title band 9..45, 1U rule 45..48


def build_nameplate(ctx):
    w = SubsetWriter(ctx.G, "global", "nameplate")
    full = {"x": 0, "y": 0}

    def shadow(i, nn, ww, hh):
        cv = Canvas(ww, hh)
        chrome.panel(cv, PLATE_X0, PLATE_Y0, PLATE_X1, PLATE_Y1)
        return cv.result()
    w.put("shadow", shadow, entry=full)

    def outline(i, nn, ww, hh):           # ink border + the band rule, transparent inside
        cv = Canvas(ww, hh)
        chrome.frame(cv, PLATE_X0, PLATE_Y0, PLATE_X1, PLATE_Y1, None, border=U, shadow=0, notch=U)
        return cv.result()
    w.put("outline", outline, entry=full)

    def band(cols):
        def f(i, nn, ww, hh):
            cv = Canvas(ww, hh)
            x0, x1 = PLATE_X0 + U, PLATE_X1 - U
            if cols == "rainbow":
                seq = RAINBOW[i:] + RAINBOW[:i]
                bw = (x1 - x0) / 6
                for k, c in enumerate(seq):
                    cv.rect(g(x0 + k * bw), PLATE_Y0 + U, g(x0 + (k + 1) * bw) if k < 5 else x1, BAND_Y1, C[c])
            else:
                cv.rect(x0, PLATE_Y0 + U, x1, BAND_Y1, C[TITLE_BG[min(i, 4)]])
            cv.rect(x0, BAND_Y1, x1, BAND_Y1 + U, INK)
            return cv.result()
        return f
    # frame_top 408x56 crops: drawn at the plate origin
    w.put("frame_top", band("plain"), entry=full)
    w.put("frame_top_rainbow", band("rainbow"), entry=full)

    def badge(p):
        def f(i, nn, ww, hh):             # 88x88 drawn at (3,6): the plate's accent cell
            cv = Canvas(ww, hh)
            col = C["p1"] if p == 1 else C["p2"]
            chrome.frame(cv, 0, 0, 84, 84, col, border=U, shadow=U, notch=U)
            return cv.result()           # 1P / 2P: engine text (nameplate.lua)
        return f
    w.put("1p", badge(1), entry={"x": PLATE_X0, "y": PLATE_Y0})
    w.put("2p", badge(2), entry={"x": PLATE_X0, "y": PLATE_Y0})

    def ai(i, nn, ww, hh):
        cv = Canvas(ww, hh)
        chrome.panel(cv, PLATE_X0, PLATE_Y0, PLATE_X1, PLATE_Y1)
        chrome.frame(cv, PLATE_X0, PLATE_Y0, PLATE_X0 + 84, PLATE_Y1, C["mint"], border=U, shadow=0, notch=U)
        return cv.result()               # AI / コンピュータ: engine text (nameplate.lua)
    w.put("ai", ai, entry=full)

    def emblem_bg(i, nn, ww, hh):         # 160x48: the dan chip under the emblem text
        cv = Canvas(ww, hh)
        return cv.result()      # text24: the chip is drawn in nameplate.lua (it grows with the rank name)
    w.put("dan_emblem_bg", emblem_bg, entry={"x": 93, "y": 48})

    # the dan name on the chip: engine text (nameplate.lua, SSM.EMBLEM_KEYS); the 25-frame keys stay
    # (the frame count tells the script which dan values exist), as transparent frames
    w.put("dan_emblem", lambda i, nn, ww, hh: blank_l(ww, hh), entry={"x": 98, "y": 48})
    w.put("dan_emblem_gold", lambda i, nn, ww, hh: blank_l(ww, hh), entry={"x": 98, "y": 48})
    for k in ("shimmer", "sparkle", "sparkle_gold"):
        w.put_blank(k)
    return w.write()


def build_indicator(ctx):
    w = SubsetWriter(ctx.G, "global", "indicator")
    for k in ("guide_49", "guide_51", "guide_53", "guide_57", "guide_59", "guide_61", "guide_63", "guide_65",
              "guide_68", "guide_74", "guide_78", "guide_80", "guide_82", "guide_84", "guide_86", "guide_plate",
              "background", "blue_arrow", "drum_don", "drum_kat", "drum_face"):
        w.put_blank(k)
    return w.write()


def build_overlay(ctx):
    w = SubsetWriter(ctx.G, "global", "overlay")

    def camera(i, nn, ww, hh):           # 416x280 x2 at [(1492,638) 2P side, (12,638) 1P side]: invite sign
        # round 4: core's speech bubble with the readable 3-step tail (36 px text -> tail="steps"),
        # pointing down at the join side's drum; the body box is unchanged (the engine text sits in it)
        cv = Canvas(ww, hh)
        chrome.bubble(cv, 6, 66, 405, 216, 204, tail="steps")
        return cv.result()
    w.put("camera", camera)
    w.put("banapass_card", lambda i, nn, ww, hh: status_tile(ww, hh, "card", i == 1))
    w.put("banapass_osaifu_keitai", lambda i, nn, ww, hh: status_tile(ww, hh, "phone", i == 1))

    def plate_or(i, nn, ww, hh):         # 240x64 x2 at (1200,45): play count plate
        cv = Canvas(ww, hh)
        chrome.panel(cv, 0, 0, 237, 60)
        return cv.result()               # 1プレイ 4曲: engine text (entry_overlay.lua, per_play)
    w.put("banapass_or", plate_or)

    # text24: the 段位道場 status tile is our own wider / taller plate (ss_meta/dojo_plate, entry_overlay.lua
    # draws it 44 px left of the old tile so the right edge stays at 1164); the old texture is blank
    w.put_blank("banapass_no")

    def allnet(i, nn, ww, hh):            # 40x40 x3 at (1868,1028): network bars (0 offline, 2 online)
        cv = Canvas(ww, hh)
        on = i == 2
        col = C["normal"] if on else C["line"]
        for k in range(4):
            h = (k + 1) * 2 * U
            x = 3 + k * 3 * U
            cv.rect(x, 33 - h, x + 2 * U + U, 36, INK)
            cv.rect(x + U, 33 - h + U, x + 2 * U, 33, col)
        return cv.result()
    w.put("allnet_indicator", allnet)
    w.put_blank("touch_drum")
    return w.write()


def build_misc_globals(ctx):
    n = 0
    w = SubsetWriter(ctx.G, "global", "network_msg")
    for k in ("dim", "bar", "dot"):
        w.put_blank(k)
    n += w.write()
    w = SubsetWriter(ctx.G, "global", "practice_timer")
    for k in ("gauge", "disc", "digits", "unit_minute", "unit_second", "remaining", "mode_label", "banner", "fade"):
        w.put_blank(k)
    n += w.write()
    w = SubsetWriter(ctx.G, "global", "rainbow_transition")
    for k in ("rainbow_bg", "rainbow_bg_top", "rainbow_bg_bottom", "text_bg", "chara_left", "chara_right",
              "chara_center"):
        w.put_blank(k)
    n += w.write()
    w = SubsetWriter(ctx.G, "global", "result_transition")
    for k in ("1p_shutter", "2p_shutter", "4p_shutter", "fade", "1p_shutter_footer", "2p_shutter_footer",
              "4p_shutter_footer"):
        w.put_blank(k)
    n += w.write()
    return n


def build_ss_meta(ctx):
    """Our own global textures for the Lua-drawn globals: scene, lanterns, title band, hint panel,
    GAME OVER letters, retry lamps (the wipe and the hint pill are core's)."""
    o = OwnSubset(ctx.G, "global", "ss_meta")
    o.add("scene", [scene(1920, 1080, 1032, props=True).result()])
    # transition: the title band (paper dialog) and the hint panel
    cv = Canvas(1560, 228)
    chrome.dialog(cv, 0, 0, 1554, 222)
    o.add("band", [cv.result()])
    cv = Canvas(960, 222)
    chrome.panel(cv, 3, 3, 954, 216)     # its ゲームのヒント plate is drawn in Lua (transition.lua, SSM.plate)
    o.add("hint", [cv.result()])
    # text24: dojo status tile 168x78: title line (24 px engine text) over a 33 px chip (None / なし)
    cv = Canvas(168, 78)
    b = chrome.panel(cv, 0, 0, 164, 75)
    chrome.chip(cv, b.ix0 + 6 * U, 39, b.ix1 - 6 * U, 72, None, accent=C["bg3"])
    o.add("dojo_plate", [cv.result()])
    # GAME OVER block letters (3U cells: the bible's 2U logo grid at 1280, x1.5)
    s = "GAME OVER"
    wd = deco.pixtext_width(s, 3 * U) + U
    cv = Canvas(wd, 9 * 3 * U + U)
    deco.pixtext(cv, 0, 0, s, cell=3 * U, fill=C["don"], shadow=U)
    o.add("game_over", [cv.result()])
    # polish_meta: the same letters one per frame (same canvas, same x), so game_over.lua drops them one
    # by one; the space is a blank frame
    letters = []
    for k, ch in enumerate(s):
        cv = Canvas(wd, 9 * 3 * U + U)
        if ch != " ":
            deco.pixtext(cv, k * 6 * 3 * U, 0, ch, cell=3 * U, fill=C["don"], shadow=U)
        letters.append(cv.result())
    o.add("go_letters", letters)
    # retry: lantern lamp (off / lit)
    lamps = []
    for lit in (False, True):
        cv = Canvas(42, 60)
        pal = {"K": INK, "R": C["don"] if lit else C["line"], "W": PAPER if lit else C["bg3"],
               "G": C["clear"] if lit else C["mute"]}
        deco.cells(cv, 3, 3, deco.LANTERN, pal, 2 * U)
        lamps.append(cv.result())
    o.add("lamp", lamps)
    return o.write()


# ================================================================ game over / retry textures
def build_game_over(ctx):
    n = 0
    w = SubsetWriter(ctx.G, "game_over", "global")
    for k in ("kitsune", "curtain", "curtain_side", "game_over_text_ja", "game_over_text_en", "game_over_text_zh",
              "copyright"):
        w.put_blank(k)
    n += w.write()
    w = SubsetWriter(ctx.G, "game_over", "logged_out")
    def bana_ad(i, nn, ww, hh):          # the game over scene: house scene + the festival taiko on the grass
        cv = scene(ww, hh, 1032, props=True)
        deco.taiko(cv, 1170, 1032)
        return cv.result()
    w.put("bana_ad", bana_ad, entry={"x": 0, "y": 0})
    n += w.write()
    return n


def build_retry(ctx):
    from .atlas import subset_keys
    n = 0
    for sub in ("background", "drum", "effects", "hands", "lamps", "moon", "shutter", "stage", "text"):
        w = SubsetWriter(ctx.G, "retry_game", sub)
        for k in subset_keys("retry_game", sub):
            w.put_blank(k)
        n += w.write()
    return n


# ================================================================ Lua: copied ancestors with our colours
INK_RGBA = "{ 58, 38, 51, 255 }"


def copy_patch(ctx, rel, subs, regex=()):
    src = ancestor_script(rel)
    with open(src, encoding="utf-8") as f:
        s = f.read()
    for a, b in subs:
        if a not in s:
            raise SystemExit(f"meta: patch target not found in {rel}: {a!r}")
        s = s.replace(a, b)
    for pat, rep in regex:
        s = re.sub(pat, rep, s)
    dst = os.path.join(ctx.scripts, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, "w", encoding="utf-8", newline="\n") as f:
        f.write(s)


DAN_SELECT_SUBS = [
    # the cursor ring is solid (no breathing alpha); the arrows sit still in the gaps (no drift)
    ("tex.draw_texture(self.t_cursor, { x = pos, y = y, fade = a })",
     "tex.draw_texture(self.t_cursor, { x = pos, y = y })"),
    ("tex.draw_texture(self.t_arrow_r, { x = pos + drift, y = y, fade = a })",
     "tex.draw_texture(self.t_arrow_r, { x = pos, y = y, fade = a })"),
    ("tex.draw_texture(self.t_arrow_l, { x = pos - drift, y = y, fade = a })",
     "tex.draw_texture(self.t_arrow_l, { x = pos, y = y, fade = a })"),
    # chip strip on the 23U pitch, selected chip drops 7U
    ("return { 960, 68, 0, 0 }", "return { 960, 69, 0, 0 }"),
    ("local SELECTED_DROP = 22", "local SELECTED_DROP = 21"),
    # song titles: ink on the row, whole pixels (no 1.02 CJK stretch)
    ("local TITLE_CJK = { latin = 1, cjk = 1.02, sy = 1, dy = 0, max_w = 1100 }",
     "local TITLE_CJK = { latin = 1, cjk = 1, sy = 1, dy = 0, max_w = 1080 }"),
    ("local TITLE_PLAIN = { latin = 1, cjk = 1, sy = 1, dy = 0, max_w = 1100 }",
     "local TITLE_PLAIN = { latin = 1, cjk = 1, sy = 1, dy = 0, max_w = 1080 }"),
    ("{ 255, 255, 255, 255 }, { 0, 0, 0, 255 }, ol, 2,",
     "{ 58, 38, 51, 255 }, { 58, 38, 51, 255 }, 0, 2,"),
    # background scene + Momo on the ground in the left column (k=6 menu), reacting to the cursor
    ("""function DanSelect:draw_back()
    local bg = tex.get_texture("dan_select/global/bg")
    if bg then tex.draw_texture(bg) end
end""",
     """local SSM = require("global.ss_meta")
function DanSelect:draw_back()
    local bg = tex.get_texture("dan_select/global/bg")
    if bg then tex.draw_texture(bg) end
    SSM.dan_momo_draw()
end"""),
    ("""function DanSelect:draw_cursor(pos, now_ms, moved_ms)
    local boxes = held_boxes""",
     """function DanSelect:draw_cursor(pos, now_ms, moved_ms)
    SSM.dan_momo_cursor(moved_ms)
    local boxes = held_boxes"""),
]

DAN_SELECT_TAIL = r"""
local ss_new = DanSelect.new
function DanSelect.new(...)
    local s = ss_new(...)
    SSM.dan_reset()
    return s
end
-- SimpleStyle: Momo cheers once when the confirm box opens. polish_meta: the box opens and closes as a
-- window (UI.open_rect: 33 / 66 / 100 % height, 50 ms steps) instead of popping in at the fade's midpoint.
local ss_confirm = DanSelect.draw_confirm
local CONF_X, CONF_Y, CONF_W, CONF_H = 264, 239, 1386, 504     -- confirm_box/bg's dialog (ss/v2_meta.py)
local conf = { open = nil, close = nil, shown = false }
function DanSelect:draw_confirm(f, index)
    SSM.dan_momo_confirm(f)
    local now = tex.get_current_ms()
    local on = UI.solid(f or 0) == 1
    if on and not conf.shown then conf.open, conf.close = now, nil end
    if not on and conf.shown then conf.close = now end
    conf.shown = on
    local since
    if on and conf.open and now - conf.open < 100 then since = now - conf.open end
    if not on and conf.close and now - conf.close < 100 then since = 99 - (now - conf.close) end
    if since then
        UI.wipe(1, UI.D.P.ink)
        local x, y, w, h = UI.open_rect(CONF_X, CONF_Y, CONF_W, CONF_H, since)
        if x then UI.chrome.dialog(x, y, w, h) end
        return
    end
    if ss_confirm then return ss_confirm(self, f, index) end
end

-- ===================================================================== SimpleStyle round 2
-- Course chips: core's course chip (UI.course.chip, one course identity) left of each song title.
local P = UI.D.P
local PLATE_CHIP_X, PLATE_CHIP_Y = @CHIPX@, @CHIPY@   -- the rank chip centre (ss/v2_meta.py PLATE_CHIP_C)
local ss_open = DanSelect.draw_dan_open
if ss_open then
    function DanSelect:draw_dan_open(box)
        ss_open(self, box)
        if UI.solid(box.open_fade.attribute) == 0 then return end
        local off = SKIN.dan_yellow_box_offset or { x = 0, y = 110 }
        for i = 0, box:song_count() - 1 do
            UI.course.chip(box:song_difficulty(i), 525 + i * (off.x or 0), 249 + i * (off.y or 110))
        end
        -- the frame plate (no rank plate): the course name in ink on the rank chip, 48 -> 36 -> 24 px
        local rank = tonumber(box.dan_rank) or -1
        if rank < 0 and box.dan_title and box.dan_title ~= "" then
            local t
            for _, sz in ipairs({ 48, 36, 24 }) do
                t = UI.text(box.dan_title, sz)
                if t and t.width <= 198 then break end
            end
            UI.draw_text(t, PLATE_CHIP_X, PLATE_CHIP_Y, "c")
        end
    end
end

-- The exam grid laid out across the frame (x 417..1782, y 594..957): one panel per exam, gauge
-- first; 1 exam = the whole width, 2 = two columns, 3 = 2 + 1 full row, 4 = 2 x 2. A panel holds its
-- name tab on its top edge, one value per song segment (全体 / 1曲目..), a gauge bar for the soul gauge
-- and the saved best. Values are engine text through UI.text (ink, whole pixels).
local EX = { x0 = 435, x1 = 1764, y0 = 630, y1 = 939, gap = 18 }
local FR = { x = 417, y = 594, w = 1365, h = 363 }   -- the exam frame (yellow_box/exam_frame)
local EXAM_KEY = { gauge = "exam_gauge", combo = "exam_combo", hit = "exam_hit", judgebad = "exam_judgebad",
                   judgegood = "exam_judgegood", judgeperfect = "exam_judgeperfect", score = "exam_score",
                   renda = "exam_roll" }
local EXAM_LABEL = { gauge = "dan_ex_gauge", combo = "dan_ex_combo", hit = "dan_ex_hit", judgebad = "dan_ex_bad",
                     judgegood = "dan_ex_ok", judgeperfect = "dan_ex_good", score = "dan_ex_score",
                     renda = "dan_ex_roll" }
local U = UI.U
local function ytex(name) return tex.get_texture("dan_select/yellow_box/" .. name) end
local function header_word()   -- 合格条件 on the yellow_box/exam_header tab (270 x 36 at 420, 561)
    UI.draw_text(SSM.fit_key("dan_conditions", 252, { 24, 18 }), 420 + 135, 561 + 18, "c")
end
local function call_opt(box, name, ...)
    local ok, fn = pcall(function() return box[name] end)
    if not ok or type(fn) ~= "function" then return nil end
    local ok2, v = pcall(fn, box, ...)
    return ok2 and v or nil
end
local function grid(v) return math.floor(v / UI.U) * UI.U end
-- "85 ％以上" (engine / Nijiiro format: space + full-width ％) reads as a double space in the pixel
-- font: the number and its percent sign belong together ("85%以上"), the dan result's
-- exam_threshold_text join
local function pct_join(s)
    s = tostring(s or "")
    return (s:gsub(" ?\239\188\133", "%%"):gsub(" +%%", "%%"))
end
-- the 合格条件 tab (yellow_box/exam_header: drawn at y 561, 36 tall) ends on the frame rule; a lone
-- exam's name tab (33 tall) sits on the same baseline
local TAB_Y = 561 + 36 - 36

local function exam_panel(box, i, x, y, w, h, tab_dx, tab_y)
    UI.chrome.panel(x, y, w, h)
    local etype = box:exam_type(i)
    local key = EXAM_KEY[etype]
    local pill = key and ytex(key)
    if pill then
        local px, py = x + (tab_dx or 18), tab_y or (y - 18)
        tex.draw_texture(pill, { x = px, y = py })
        -- the exam name: engine text, 24 px ink on the 228 x 33 tab (18 px when a translation is longer)
        local lk = EXAM_LABEL[etype]
        if lk then UI.draw_text(SSM.fit_key(lk, 204, { 24, 18 }), px + 5 * U, py + 18, "l") end
    end
    local gothrough = box:exam_gothrough(i)
    local segs = gothrough and 1 or math.max(1, math.min(box:song_count(), 3))
    local sw = grid((w - 12) / segs)
    local big = (segs == 1 and h >= 150)
    local cy = y + math.floor(h / 2)
    if etype == "gauge" and h >= 150 then cy = y + math.floor(h * 0.4) end
    local best_label = tex.skin_text("dan_exam_best_label")
    for k = 0, segs - 1 do
        local sx = x + 6 + k * sw
        local scx = sx + math.floor(sw / 2)
        local labelled = (etype ~= "gauge")
        if labelled then
            -- 全体 / 1曲目..: a line chip sized to the label (at least the old 87 px), 18 px ink
            local lk = gothrough and "dan_total" or ("dan_song_" .. (k + 1))
            local cw = math.max(87, math.ceil((UI.label_width(lk, 18) + 6 * U) / U) * U)
            local ix, iy, iw, ih = UI.chrome.chip(grid(scx - cw / 2), y + 24, cw, 36, P.line, false)
            UI.draw_text(UI.text_key(lk, 18), ix + iw / 2, iy + ih / 2, "c")
        end
        local cap = pct_join(gothrough and box:exam_caption(i) or box:exam_song_caption(i, k))
        local vy = labelled and (cy + 12) or cy
        UI.draw_text(UI.text(cap, big and 48 or 36), scx, vy, "c")
        local best = gothrough and call_opt(box, "exam_best", i) or call_opt(box, "exam_song_best", i, k)
        if best ~= nil and best_label then
            local s = best_label .. " " .. tostring(best) .. (etype == "gauge" and "%" or "")
            UI.draw_text(UI.text(s, 18, { color = P.text2 }), scx, y + h - 24, "c")
        end
    end
    if etype == "gauge" and h >= 150 then
        -- the soul gauge with the norma marked: fill to the required %, 10 segments
        local red = tonumber(box:exam_red(i)) or 0
        local bw = math.min(grid(w - 96), 720)
        UI.pixbar(grid(x + (w - bw) / 2), cy + 42, bw, 27, red / 100, P.clear, 10, P.bg3)
        local gold = tonumber(call_opt(box, "exam_gold", i))
        if gold and h >= 240 then   -- a whole-row gauge panel also states the gold pass
            UI.draw_text(UI.text_key("dan_gold_more", 24, { color = P.gold_t }, tostring(gold)),
                         x + math.floor(w / 2), cy + 108, "c")
        end
    end
end

function DanSelect:draw_exam_grid(box, f)
    if UI.solid(f) == 0 then return end
    local list = {}
    for i = 0, box:exam_count() - 1 do
        if #list < 4 then list[#list + 1] = i end
    end
    local n = #list
    -- one exam: that exam's panel IS the frame (no panel-in-panel); its name tab sits on the frame's
    -- top edge right of the 合格条件 tab (x 420..830)
    local frame = (n ~= 1) and ytex("exam_frame")
    if frame then tex.draw_texture(frame) end
    -- engine text made here is plain: draw_dan_open has wrapped create_raw_text for its captions
    local wrapped = text.create_raw_text
    text.create_raw_text = raw_create
    if n == 1 then
        local ok1, err1 = pcall(exam_panel, box, list[1], FR.x, FR.y, FR.w, FR.h, 432, TAB_Y)
        local header = ytex("exam_header")
        if header then tex.draw_texture(header); header_word() end
        text.create_raw_text = wrapped
        if not ok1 then error(err1, 0) end
        return
    end
    local header = ytex("exam_header")
    if header then tex.draw_texture(header); header_word() end
    local rows = (n <= 2) and 1 or 2
    local ph = grid((EX.y1 - EX.y0 - EX.gap * (rows - 1)) / rows)
    local fw = EX.x1 - EX.x0
    local hw = grid((fw - EX.gap) / 2)
    local ok, err = pcall(function()
        for idx, i in ipairs(list) do
            local r = (idx <= 2) and 0 or 1
            local first = (r == 0) and 1 or 3
            local in_row = math.min(2, n - first + 1)
            if n == 1 then in_row = 1 end
            local c = idx - first
            local w = (in_row == 1) and fw or hw
            local x = EX.x0 + c * (hw + EX.gap)
            local y = EX.y0 + r * (ph + EX.gap)
            exam_panel(box, i, x, y, w, ph)
        end
    end)
    text.create_raw_text = wrapped
    if not ok then error(err, 0) end
end

-- ===================================================================== SimpleStyle: dynamic text
-- The words of every dan select texture are engine text in the player's language (SCREEN_GUIDE_V2 §11):
-- the textures are chrome only and these labels draw the words right after the texture, whichever
-- script draws it (SSM.with_labels hooks tex.draw_texture while a DanSelect draw method runs).
-- Positions are frame-local (ss/v2_meta.py); x, y = the texture's drawn top-left.
local RANK_KEYS = { @RANKKEYS@ }   -- yellow_box/rank_plate frames
local function seal_col(frame) return ((frame or 0) < 3) and P.red_t or P.gold_t end
local function plate_words(x, y, rank)
    UI.draw_text(SSM.fit_key("dan_dojo", 252, { 36, 24 }), x + @CAPX@, y + @CAPY@, "c")
    local key = rank and RANK_KEYS[rank + 1]
    if key then UI.draw_text(SSM.fit_key(key, 198, { 48, 36, 24 }), x + @CHIPX0@, y + @CHIPY0@, "c") end
    UI.draw_text(UI.text_key("dan_unplayed", 36, { color = P.mute }), x + @SLOTX@, y + @SLOTY@, "c")
end
local function at(key, x, y, size, style, align, dx, dy)
    UI.draw_text(UI.text_key(key, size, style), x + dx, y + dy, align or "c")
end
local DAN_LABELS = SSM.label_set({
    { "dan_select/box/clear_mark", "box", "clear_mark", function(x, y, p)
        at("dan_pass_mark", x, y, 18, { color = seal_col(p.frame) }, "c", 39, 24)
    end },
    { "dan_select/yellow_box/clear_mark", "yellow_box", "clear_mark", function(x, y, p)
        local fr = p.frame or 0
        at("dan_pass", x, y, 48, { color = seal_col(fr) }, "c", 147, 111)
        if fr % 3 ~= 0 then   -- the フルコンボ / 全良 chip under the seal, sized to the word
            local key = (fr % 3 == 1) and "full_combo" or "zenryo"
            local cw = math.ceil((UI.label_width(key, 18) + 8 * U) / U) * U
            local ix, iy, iw, ih = UI.chrome.chip(grid(x + 147 - cw / 2), y + 204, cw, 36, P.paper, false)
            UI.draw_text(UI.text_key(key, 18), ix + iw / 2, iy + ih / 2, "c")
        end
    end },
    { "dan_select/yellow_box/song_label", "yellow_box", "song_label", function(x, y, p)
        -- text24: the 24 px 曲目 word needs more room under the number: the box is redrawn 84 high (the baked
        -- 75 x 75 box is covered), number at y 28, word at y 62
        UI.chrome.panel(x, y, 75, 84)
        UI.draw_text(UI.text(tostring((p.frame or 0) + 1), 36), x + 37.5, y + 28, "c")
        UI.draw_text(SSM.fit_key("dan_song_label", 69, { 24 }), x + 37.5, y + 62, "c")
    end },
    { "dan_select/yellow_box/hidden_title", "yellow_box", "hidden_title", function(x, y)
        at("dan_hidden_title", x, y, 36, { color = P.mute }, "l", @HIDX@, @HIDY@)
    end },
    { "dan_select/yellow_box/total_notes", "yellow_box", "total_notes", function(x, y)
        UI.draw_text(SSM.fit_key("dan_total_notes", 282, { 24, 18 }), x + @TNX@, y + @TNY@, "l")
    end },
    { "dan_select/yellow_box/rank_plate", "yellow_box", "rank_plate", function(x, y, p) plate_words(x, y, p.frame or 0) end },
    { "dan_select/yellow_box/frame", "yellow_box", "frame", function(x, y) plate_words(x, y, nil) end },
    { "dan_select/confirm_box/bg", "confirm_box", "bg", function(x, y)
        at("dan_dojo", x, y, 36, nil, "c", @CTX@, @CTY@)
    end },
    { "dan_select/confirm_box/confirmation_text", "confirm_box", "confirmation_text", function(x, y)
        at("dan_confirm", x, y, 36, nil, "c", @CQX@, @CQY@)
    end },
    { "dan_select/confirm_box/yes", "confirm_box", "yes", function(x, y) at("dan_yes", x, y, 36, nil, "c", @YX@, @YY@) end },
    { "dan_select/confirm_box/no", "confirm_box", "no", function(x, y) at("dan_no", x, y, 36, nil, "c", @NX@, @NY@) end },
})
for name, fn in pairs(DanSelect) do
    if type(fn) == "function" and name:sub(1, 5) == "draw_" then
        DanSelect[name] = function(...) return SSM.with_labels(DAN_LABELS, fn, ...) end
    end
end
"""


# alpha policy (SCREEN_GUIDE_V2 §6): every fade in the two dan scripts goes through UI.solid, so chips,
# cursor, arrows, stamps, the board and the confirm box are drawn at alpha 1 or not at all
FADE_SOLID = (r"\bfade = (?!UI\.solid)([^,}\n]+?)(\s*[,}\n])", r"fade = UI.solid(\1)\2")
UI_REQUIRE = 'local UI = require("global.ss_ui")\n'


def _n(v):
    return f"{v:g}"


def dan_tail():
    """DAN_SELECT_TAIL with the frame-local text positions filled in (LAYOUT is filled by the build)."""
    rep = {
        "@CHIPX@": str(117 + PLATE_CHIP_C[0]), "@CHIPY@": str(171 + PLATE_CHIP_C[1]),
        "@CHIPX0@": _n(PLATE_CHIP_C[0]), "@CHIPY0@": _n(PLATE_CHIP_C[1]),
        "@CAPX@": _n(PLATE_CAP_C[0]), "@CAPY@": _n(PLATE_CAP_C[1]),
        "@SLOTX@": _n(PLATE_SLOT_C[0]), "@SLOTY@": _n(PLATE_SLOT_C[1]),
        "@RANKKEYS@": ", ".join(f'"{rank_key(r)}"' for r in RANKS),
        "@HIDX@": _n(LAYOUT["hidden_title"][0]), "@HIDY@": _n(LAYOUT["hidden_title"][1]),
        "@TNX@": _n(LAYOUT["total_notes"][0]), "@TNY@": _n(LAYOUT["total_notes"][1]),
        "@CTX@": _n(LAYOUT["confirm_title"][0]), "@CTY@": _n(LAYOUT["confirm_title"][1]),
        "@CQX@": _n(LAYOUT["confirmation_text"][0]), "@CQY@": _n(LAYOUT["confirmation_text"][1]),
        "@YX@": _n(LAYOUT["yes"][0]), "@YY@": _n(LAYOUT["yes"][1]),
        "@NX@": _n(LAYOUT["no"][0]), "@NY@": _n(LAYOUT["no"][1]),
    }
    t = DAN_SELECT_TAIL
    for a, b in rep.items():
        t = t.replace(a, b)
    left = re.findall(r"@[A-Z0-9]+@", t)
    if left:
        raise SystemExit(f"meta: dan tail placeholders left: {left}")
    return t


def write_lua(ctx):
    copy_patch(ctx, "dan_select/dan_select.lua", DAN_SELECT_SUBS,
               regex=[(r"\{ 0, 0, 0, 255 \}", INK_RGBA), (r"\{ 20, 20, 20, 255 \}", INK_RGBA), FADE_SOLID])
    p = os.path.join(ctx.scripts, "dan_select/dan_select.lua")
    with open(p, encoding="utf-8") as f:
        body = f.read()
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(UI_REQUIRE + body + dan_tail())
    copy_patch(ctx, "dan_select/dan_select_base.lua", [
        # the dim behind the confirm box: a 25 % ink checker (UI.wipe), not a translucent rect
        ("tex.draw_rect(0, 0, tex.get_screen_width(), tex.get_screen_height(), 0, 0, 0, math.min(0.5, f) * 255)",
         "UI.wipe(math.min(1, UI.dither(f)), UI.D.P.ink)"),
        # the frame plate's name: ink on the rank chip, drawn by the tail's draw_dan_open (the cap is the
        # gold 段位道場 band), not the engine's white hori_name
        ("local hori = box:hori_name()", "local hori = nil"),
    ], regex=[(r"\{ 0, 0, 0, 255 \}", INK_RGBA), FADE_SOLID])
    p = os.path.join(ctx.scripts, "dan_select/dan_select_base.lua")
    with open(p, encoding="utf-8") as f:
        body = f.read()
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(UI_REQUIRE + body)


# ================================================================ skin_config
def skin_config(ctx):
    """Engine text sizes 18/24/36/48 and a 1U ink outline. The engine replaces a whole entry, so each one
    starts from Nijiiro's (positions, text) and only the size / outline change."""
    import json
    from .atlas import NIJIIRO_G
    with open(f"{NIJIIRO_G}/skin_config.json", encoding="utf-8") as f:
        nj = json.load(f)
    out = {}
    for k, v in _skin_sizes().items():
        e = dict(nj.get(k, {}))
        e.update(v)
        out[k] = e
    return out


def _skin_sizes():
    ol = 3
    E = style.ENGINE_TEXT          # text role -> engine font size
    return {
        "dan_select_title": {"x": 672, "y": 252, "height": 66, "font_size": E[36], "outline": 0},
        "dan_select_subtitle": {"font_size": E[24]},
        # the frame plate's engine name (courses without a rank plate): centred in the plate's cap
        "dan_hori_name": {"x": 255, "y": 177, "width": 240},
        # chip names: role 24 (2 vertical glyphs fit the 93 px name area of the 141 px chip)
        "dan_select_chip_name": {"y": 78, "height": 72, "font_size": E[24]},
        # text24: "Back" (4 glyphs) is wider than the 36 px chip at 24 px; the en label is the arrow glyph
        "dan_back_label": {"y": 78, "height": 72, "width": 36, "font_size": E[24],
                           "text": {"en": "←", "ja": "戻る", "zh": "返回", "ko": "뒤로"}},
        "dan_select_exam_border_text": {"font_size": E[24], "outline": ol},
        "dan_select_gauge_border_text": {"font_size": E[36], "outline": ol},
        "dan_exam_best_label": {"font_size": E[18]},
        "free_play": {"font_size": E[24]},
        "credit_side_player": {"font_size": E[36]},
        "credit_side_msg": {"font_size": E[24]},
        "guide_select_label": {"font_size": E[24]},
        "guide_decide_label": {"font_size": E[24]},
        "transition_title": {"font_size": E[48]},
        "transition_subtitle": {"font_size": E[36]},
        "transition_hint_title": {"font_size": E[36]},
        "transition_hint_line1": {"font_size": E[24]},
        "transition_hint_line2": {"font_size": E[24]},
        "song_num_max": {"font_size": E[24], "outline": ol},
        "skip_badge_text": {"font_size": E[24]},
        "screen_fade_ms": {"x": 1},
        # the dan intro's rank text: on the plaque, with the same +transition_offset as the textures
        "dan_loading_rank": {"x": 960, "y": 290 + DAN_OFFSET},
    }


def build(ctx):
    n = build_dan_select(ctx)
    n += build_dan_loading(ctx)
    n += build_timer(ctx)
    n += build_nameplate(ctx)
    n += build_indicator(ctx)
    n += build_overlay(ctx)
    n += build_misc_globals(ctx)
    n += build_ss_meta(ctx)
    n += build_game_over(ctx)
    n += build_retry(ctx)
    write_lua(ctx)
    return n
