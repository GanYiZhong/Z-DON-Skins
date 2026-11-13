"""Module "dan": dan select (Graphics/dan_select), the retry mini-game (Graphics/retry_game) and the game
over screen (Graphics/game_over). Light 8-bit look: pixbox windows, pixel clouds, Momo and Hoshi sprites.
Green's frame geometry (texture sizes, offsets) is kept; the festival art of the retry / game over screens
is gone and replaced by our own simple scenes.
Lua patches: the mascot on the dan floor, and un-fading the pixel clouds of the retry scene.

Everything is drawn by code (ss/style.py Canvas); only geometry (canvas sizes, frame layout) follows the
parent's texture.json."""
from __future__ import annotations

import math
import random

from PIL import Image

from . import mascot
from .atlas import SubsetWriter
from .style import (C, COURSES, Canvas, alpha, blank, hexc, mix, pixbox, vtext)

NAME = "dan"
OWNS = ["Graphics/dan_select", "Graphics/retry_game", "Graphics/game_over", "Scripts/dan_select",
        "Scripts/retry_game", "Scripts/game_over"]
LANG = "ja"

LUA_PATCHES = {
    "dan_select/dan_select.lua": [
        ("local SKIN_S = tex.get_screen_scale()\n",
         'local UI = require("global.ss_ui")\nlocal SKIN_S = tex.get_screen_scale()\n'),
        ("    local self = setmetatable({ now = 0 }, DanSelect)\n",
         "    local self = setmetatable({ now = 0 }, DanSelect)\n    UI.reset()\n    self.mascot = UI.Mascot.new()\n"),
        ("function DanSelect:update(ms)\n    self.now = ms\n",
         "function DanSelect:update(ms)\n    self.now = ms\n    self.mascot:update(ms, 110)\n"),
        ('function DanSelect:draw_title()\n    draw_tex("global", "dan_select", {})\n',
         'function DanSelect:draw_title()\n    draw_tex("global", "dan_select", {})\n'
         '    self.mascot:draw(76, 623, 4 / 7, {})\n'),
    ],
    # the pixel clouds are opaque (Green drew its stars at 40 %)
    "retry_game/retry_game.lua": [
        ("    draw(self.stars, { fade = 0.4 })\n", "    draw(self.stars)\n"),
    ],
}


def configure(ctx):
    global LANG
    LANG = ctx.lang


# ---------------------------------------------------------------- colours
INK, PAPER = C["ink"], C["paper"]
RANK = [hexc("#D9B48A"), hexc("#C98A5A"), hexc("#8F98AE"), hexc("#E8453A"), hexc("#C9CFDB"), hexc("#F5B21E"),
        hexc("#F28A3B")]   # dan_color frames 0..6: wood, bronze, black, red, silver, gold, light wood
BANNER = [hexc("#4FC4B4"), hexc("#F5B21E"), hexc("#C8CFDD"), hexc("#F25CA2"), hexc("#99D346"), hexc("#E0C25A"),
          hexc("#9B6BF2"), hexc("#FF7A45")]
GOLD = C["dan"]
SKY, SKY2 = C["sky"], mix(C["sky"], PAPER, 0.55)


# ---------------------------------------------------------------- 8-bit helpers (local; see report)
def spr(cv, im, x, y):
    """Composite a pixel sprite onto a Canvas with NEAREST (stays crisp at any supersample)."""
    if cv.ss != 1:
        im = im.resize((im.width * cv.ss, im.height * cv.ss), Image.NEAREST)
    cv.im.alpha_composite(im, (int(round(x * cv.ss)), int(round(y * cv.ss))))


def mas(who, expr, size, frame=0):
    return mascot.sized("M" if who == "momo" else "H", expr, size, frame)


def cells(cv, rows, x, y, cell, fill, edge=None, shade=None):
    """Draw a grid of '#' cells (optionally '+' = paper highlight, '=' = shade) with an ink edge of one
    cell on the four sides (notched corners, 8-bit style)."""
    pts = [(i, j, ch) for j, row in enumerate(rows) for i, ch in enumerate(row) if ch != "."]
    if edge:
        for i, j, _ in pts:
            px, py = x + i * cell, y + j * cell
            cv.rect(px - cell, py, px + 2 * cell, py + cell, edge)
            cv.rect(px, py - cell, px + cell, py + 2 * cell, edge)
    for i, j, ch in pts:
        col = fill
        if ch == "+":
            col = PAPER
        elif ch == "=" and shade:
            col = shade
        cv.rect(x + i * cell, y + j * cell, x + (i + 1) * cell, y + (j + 1) * cell, col)


def grid_size(rows, cell, edge=True):
    return len(rows[0]) * cell, len(rows) * cell


def pixdisc(cv, cx, cy, r, cell, fill):
    n = int(r // cell) + 1
    for j in range(-n, n + 1):
        for i in range(-n, n + 1):
            if (i * i + j * j) * cell * cell <= r * r:
                cv.rect(cx + i * cell - cell / 2, cy + j * cell - cell / 2, cx + i * cell + cell / 2,
                        cy + j * cell + cell / 2, fill)


def pixmedal(cv, cx, cy, r, cell, fill, edge=INK):
    pixdisc(cv, cx, cy, r + cell, cell, edge)
    pixdisc(cv, cx, cy, r, cell, fill)


CLOUD = ["...#####....", "..#######...", ".##########.", "############", "############", ".##########."]


def cloud(cv, x, y, cell=6, col=PAPER, shade=SKY2):
    for j, row in enumerate(CLOUD):
        for i, ch in enumerate(row):
            if ch == "#":
                c = shade if j == len(CLOUD) - 1 else col
                cv.rect(x + i * cell, y + j * cell, x + (i + 1) * cell, y + (j + 1) * cell, c)


STAR = [".....#.....", "....###....", "....###....", "###########", ".#########.", "..#######..", "..#######..",
        ".####.####.", ".###...###.", ".##.....##."]
SPARK = ["..#..", "..#..", "#####", "..#..", "..#.."]
HEART = [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]
NOTE = ["...####", "...#..#", "...#...", "...#...", ".###...", "####...", ".##...."]
DROP = ["..#..", "..#..", ".###.", ".###.", "#####", "#####", ".###."]
ARROW_R = ["#.....", "###...", "#####.", "#######", "#####.", "###...", "#....."]
ARROW_L = [r[::-1] for r in ARROW_R]

FONT = {
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    " ": ["00000"] * 7,
}


def pixtext(cv, cx, y, s, cell, fill, edge=INK, shadow=0):
    """Pixel-font string (5x7 glyphs), centred on cx, top at y."""
    w = (len(s) * 6 - 1) * cell
    x0 = cx - w / 2
    pts = []
    for k, ch in enumerate(s):
        for j, row in enumerate(FONT[ch]):
            for i, b in enumerate(row):
                if b == "1":
                    pts.append((x0 + (k * 6 + i) * cell, y + j * cell))
    if shadow:
        for px, py in pts:
            cv.rect(px - cell + shadow, py + shadow, px + 2 * cell + shadow, py + cell + shadow, INK)
            cv.rect(px + shadow, py - cell + shadow, px + cell + shadow, py + 2 * cell + shadow, INK)
    if edge:
        for px, py in pts:
            cv.rect(px - cell, py, px + 2 * cell, py + cell, edge)
            cv.rect(px, py - cell, px + cell, py + 2 * cell, edge)
    for px, py in pts:
        cv.rect(px, py, px + cell, py + cell, fill)


def pixline(cv, p0, p1, cell, ink_n, fill_n, ink, fill):
    """A stair-stepped stroke: squares snapped to a `cell` grid, `ink_n` cells thick with a `fill_n` core."""
    steps = int(max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1])) / (cell / 2)) + 1
    pts = []
    for k in range(steps + 1):
        t = k / steps
        gx = round((p0[0] + (p1[0] - p0[0]) * t) / cell) * cell
        gy = round((p0[1] + (p1[1] - p0[1]) * t) / cell) * cell
        pts.append((gx, gy))
    a, b = ink_n * cell / 2, fill_n * cell / 2
    for gx, gy in pts:
        cv.rect(gx - a, gy - a, gx + a, gy + a, ink)
    for gx, gy in pts:
        cv.rect(gx - b, gy - b, gx + b, gy + b, fill)


def text_img(w, h, s, size, fill, weight=800, x=None, anchor="mm", stroke=0, stroke_fill=None, max_w=None):
    cv = Canvas(w, h)
    cv.text(w / 2 if x is None else x, h / 2, s, size, fill, weight=weight, anchor=anchor, stroke=stroke,
            stroke_fill=stroke_fill, max_w=max_w or (w - 8))
    return cv.result()


def clear_rect(cv, x0, y0, x1, y1):
    cv.rect(x0, y0, x1, y1, (0, 0, 0, 0))


def sky_scene(cv, w, h, sky_h, ground_y=None, clouds=()):
    """Cream screen with a stepped sky band (and optional mint ground)."""
    cv.rect(0, 0, w, h, C["bg0"])
    cv.rect(0, 0, w, sky_h, SKY)
    for k, t in enumerate((0.33, 0.66)):
        cv.rect(0, sky_h + k * 8, w, sky_h + k * 8 + 8, mix(SKY, C["bg0"], t))
    if ground_y is not None:
        cv.rect(0, ground_y, w, h, C["mint"])
        cv.rect(0, ground_y, w, ground_y + 6, INK)
        cv.rect(0, ground_y + 6, w, ground_y + 14, mix(C["mint"], PAPER, 0.5))
    for cx, cy, cell in clouds:
        cloud(cv, cx, cy, cell)


# nine-slice piece of a pixbox panel (col/row: 0 first, 1 middle, 2 last)
NINE = {"tl": (0, 0), "t": (1, 0), "tr": (2, 0), "l": (0, 1), "c": (1, 1), "r": (2, 1), "bl": (0, 2),
        "b": (1, 2), "br": (2, 2)}


def nine(w, h, col, row, fill, px=3, accent=None, acc_w=3, inset=0):
    cv = Canvas(w, h)
    x0 = inset if col == 0 else -200
    x1 = w - inset if col == 2 else w + 200
    y0 = inset if row == 0 else -200
    y1 = h - inset if row == 2 else h + 200
    if accent:
        pixbox(cv, x0, y0, x1, y1, fill=accent, border=INK, shadow=0, px=px)
        pixbox(cv, x0 + px + acc_w - px, y0 + px + acc_w - px, x1 - acc_w, y1 - acc_w, fill=fill, border=accent,
               shadow=0, px=0, notch=False)
    else:
        pixbox(cv, x0, y0, x1, y1, fill=fill, border=INK, shadow=0, px=px)
    return cv.result()


def put_nine(w, names, fill, px=3, accent=None, acc_w=3, inset=0):
    for p, key in names.items():
        c, rr = NINE[p]
        w.put(key, lambda i, n, ww, hh, c=c, rr=rr: nine(ww, hh, c, rr, fill, px, accent, acc_w, inset))


def banded(cv, box, acc, top, bot, fill=None, px=3):
    """A tall plate: ink border, paper body, accent caps (dan folder / genre banner / rank plate)."""
    x0, y0, x1, y1 = box
    pixbox(cv, x0, y0, x1, y1, fill=fill or C["bg1"], border=INK, shadow=0, px=px)
    cv.rect(x0 + px, y0 + px, x1 - px, y0 + top, acc)
    cv.rect(x0 + px, y0 + top, x1 - px, y0 + top + 3, INK)
    if bot:
        cv.rect(x0 + px, y1 - bot, x1 - px, y1 - px, acc)
        cv.rect(x0 + px, y1 - bot - 3, x1 - px, y1 - bot, INK)


# ================================================================================ dan select
SC = "dan_select"


def build_global(G):
    w = SubsetWriter(G, SC, "global")

    def bg(i, n, ww, hh):
        cv = Canvas(ww, hh, ss=1)
        cv.rect(0, 0, ww, hh, C["bg0"])
        return cv.result()

    def bg_header(i, n, ww, hh):
        cv = Canvas(ww, hh)
        cv.rect(0, 0, ww, 96, SKY)
        for k, t in enumerate((0.33, 0.66)):
            cv.rect(0, 96 + k * 8, ww, 104 + k * 8, mix(SKY, C["bg0"], t))
        cloud(cv, 560, 14, 5)
        cloud(cv, 770, 50, 4)
        cloud(cv, 1060, 20, 5)
        return cv.result()

    def bg_footer(i, n, ww, hh):
        cv = Canvas(ww, hh)
        cv.rect(0, 0, ww, 6, INK)
        cv.rect(0, 6, ww, 14, C["bg3"])
        return cv.result()

    def footer(i, n, ww, hh):
        cv = Canvas(ww, hh)
        cv.rect(0, 40, ww, hh, C["bg1"])
        cv.rect(0, 40, ww, 44, INK)
        cv.rect(0, 44, ww / 2, 47, C["p1"])
        cv.rect(ww / 2, 44, ww, 47, C["p2"])
        return cv.result()

    def arrow(i, n, ww, hh):
        cv = Canvas(ww, hh)
        cells(cv, ARROW_L, 22, 36, 9, C["roll"], edge=INK)
        return cv.result()

    def title(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pixbox(cv, 4, 10, 4 + 52 + int(cv.text_width("段位をえらぶ", 24, 900)) + 16, 62, fill=C["roll"], shadow=4)
        cv.text(34, 36, "▶", 18, INK, weight=900)
        cv.text(52, 36, "段位をえらぶ", 24, INK, weight=900, anchor="lm")
        return cv.result()

    w.put("bg", bg)
    w.put("bg_header", bg_header)
    w.put("bg_footer", bg_footer)
    w.put("footer", footer)
    w.put("arrow", arrow)
    w.put("dan_select", title)
    return w.write()


def f_dan_folder(i, n, ww, hh):
    acc = RANK[i % len(RANK)]
    cv = Canvas(ww, hh)
    banded(cv, (6, 9, 90, 463), acc, 44, 14)
    for k in range(3):
        cv.rect(22, 58 + k * 6, 74, 61 + k * 6, alpha(acc, 150))
    return cv.result()


def f_clear_mark(i, n, ww, hh):
    col, tx = (C["p1"], PAPER) if i == 0 else (C["roll"], INK)
    cv = Canvas(ww, hh)
    cv.rect(6, 84, 22, 100, INK)
    cv.rect(34, 84, 50, 100, INK)
    pixbox(cv, 4, 2, 52, 90, fill=col, shadow=0, px=3)
    cv.rect(10, 84, 24, 98, col)
    cv.rect(32, 84, 46, 98, col)
    cv.rect(24, 84, 32, 90, col)
    vtext(cv, 28, 16, "合格", 22, tx, weight=900)
    return cv.result()


def f_back_chip(i, n, ww, hh):
    cv = Canvas(ww, hh)
    pixbox(cv, 4, 2, 50, hh - 6, fill=C["bg3"], shadow=4, px=3)
    vtext(cv, 27, 14, "もどる", 26, INK, weight=900)
    return cv.result()


def f_vtext_chip(s, col):
    def draw(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pixbox(cv, 3, 2, ww - 7, 44, fill=col, shadow=4, px=3)
        cx = (ww - 4) / 2
        for dx, dy in ((-9, -9), (-3, -3), (3, 3), (9, 9), (9, -9), (3, -3), (-3, 3), (-9, 9)):
            cv.rect(cx + dx - 1.5, 23 + dy - 1.5, cx + dx + 1.5, 23 + dy + 1.5, INK)
        vtext(cv, cx, 58, s, 30, INK, weight=900)
        return cv.result()
    return draw


def f_mascot_card(accent):
    def draw(i, n, ww, hh):
        cv = Canvas(ww, hh)
        # the card is 28 px narrower than Green's art: the engine's vertical text column starts at its right edge
        r = ww - 38
        pixbox(cv, 4, 4, r, hh - 10, fill=C["bg1"], shadow=6, px=4)
        cv.rect(8, 8, r - 4, 46, accent)
        cv.rect(8, 46, r - 4, 49, INK)
        pixdither_band(cv, 8, hh - 60, r - 4, hh - 14, C["bg3"])
        spr(cv, mas("momo", "blink", 192), (r + 4 - 192) / 2, hh - 24 - 192 + 4)
        return cv.result()
    return draw


def pixdither_band(cv, x0, y0, x1, y1, col, cell=6):
    for y in range(int(y0), int(y1), cell):
        for x in range(int(x0) + ((y - int(y0)) // cell % 2) * cell, int(x1), cell * 2):
            cv.rect(x, y, min(x + cell, x1), min(y + cell, y1), col)


def build_back(G):
    w = SubsetWriter(G, SC, "back")
    acc = C["ka"]

    def folder(i, n, ww, hh):
        cv = Canvas(ww, hh)
        banded(cv, (6, 9, 90, 463), acc, 44, 14)
        return cv.result()

    w.put("folder", folder)
    w.put("chip", f_back_chip)
    put_nine(w, {"tl": "board_tl", "t": "board_t", "tr": "board_tr", "r": "board_r", "br": "board_br",
                 "b": "board_b", "bl": "board_bl", "l": "board_l", "c": "board_c"},
             C["bg1"], px=3, accent=acc, acc_w=3, inset=4)
    w.put("graphic", f_mascot_card(acc))

    def text(i, n, ww, hh):
        cv = Canvas(ww, hh)
        vtext(cv, ww - 40, 10, "道場からもどって", 30, INK, weight=800, max_h=hh - 20)
        vtext(cv, ww - 108, 10, "演奏する曲をえらべるよ", 30, INK, weight=800, max_h=hh - 20)
        return cv.result()

    w.put("text", text)

    def pill(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pixbox(cv, 4, 4, ww - 8, hh - 8, fill=C["roll"], shadow=4, px=3)
        cv.text(ww / 2 - 2, hh / 2 - 2, "もどる", 28, INK, weight=900)
        return cv.result()

    w.put("pill", pill)
    return w.write()


def build_box(G):
    w = SubsetWriter(G, SC, "box")
    w.put("folder", f_dan_folder)
    w.put("clear_mark", f_clear_mark)
    w.put("back_graphic", f_mascot_card(C["ka"]))
    w.put("back_text", f_vtext_chip("とじる", C["bg3"]))
    w.put("back_text_highlight", f_vtext_chip("とじる", C["roll"]))
    # the song-select leftovers of this subset (the dan Lua never draws them)
    for k in ("folder_texture", "folder_texture_left", "folder_texture_right"):
        w.put_blank(k)
    return w.write()


def build_yellow_box(G):
    w = SubsetWriter(G, SC, "yellow_box")
    # the open dan board (grown by the engine's animations)
    put_nine(w, {"tl": "yellow_box_top_left", "t": "yellow_box_top", "tr": "yellow_box_top_right",
                 "l": "yellow_box_left", "c": "yellow_box_center", "r": "yellow_box_right",
                 "bl": "yellow_box_bottom_left", "b": "yellow_box_bottom", "br": "yellow_box_bottom_right"},
             C["bg1"], px=4, accent=GOLD, acc_w=4)

    def banner(i, n, ww, hh):
        tint = BANNER[i % len(BANNER)]
        cv = Canvas(ww, hh)
        banded(cv, (4, 4, ww - 8, hh - 8), tint, 22, 16, fill=C["bg1"])
        return cv.result()

    w.put("genre_banner", banner)

    def hidden(i, n, ww, hh):
        cv = Canvas(ww, hh)
        vtext(cv, ww / 2, 24, "？？？", 58, INK, weight=900)
        return cv.result()

    w.put("hidden_title", hidden)
    w.put("clear_mark", f_clear_mark)

    def fill_for(i):
        col = C[COURSES[i][0]]
        return mix(col, PAPER, 0.3) if i == 4 else col

    def diff(i, n, ww, hh):
        col = fill_for(i)
        cv = Canvas(ww, hh)
        pixbox(cv, 2, 2, ww - 6, hh - 6, fill=col, shadow=3, px=3)
        pixmedal(cv, 28, 24, 15, 3, PAPER)
        if i <= 3:
            for j in range(i + 1):
                cv.rect(28 + (j - i / 2) * 7 - 2.5, 21.5, 28 + (j - i / 2) * 7 + 2.5, 26.5, INK)
        else:
            cells(cv, ["#####", "#...#", "#...#", "#...#", "#####"], 22, 18, 3, INK)
        return cv.result()

    w.put("difficulty", diff)

    def ura(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pixbox(cv, 2, 2, ww - 6, hh - 6, fill=C["ura"], shadow=3, px=3)
        cv.text(ww / 2 - 2, hh / 2 - 1, "裏", 28, PAPER, weight=900)
        return cv.result()

    w.put("difficulty_ura", ura)

    def num(i, n, ww, hh):
        cv = Canvas(ww, hh)
        cv.text(ww / 2, hh / 2 + 1, str(i), 21, INK, weight=900)
        return cv.result()

    w.put("difficulty_num", num)

    def times(i, n, ww, hh):
        cv = Canvas(ww, hh)
        cx, cy = 10, hh / 2
        for k in (-6, -3, 0, 3, 6):
            cv.rect(cx + k - 1.5, cy + k - 1.5, cx + k + 1.5, cy + k + 1.5, INK)
            cv.rect(cx + k - 1.5, cy - k - 1.5, cx + k + 1.5, cy - k + 1.5, INK)
        return cv.result()

    w.put("difficulty_x", times)

    def star(i, n, ww, hh):
        cv = Canvas(ww, hh)
        cells(cv, STAR, 2, 3, 2, INK)
        return cv.result()

    w.put("difficulty_star", star)

    def tn_bg(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pixbox(cv, 2, 2, ww - 6, hh - 6, fill=C["bg0"], shadow=4, px=3)
        return cv.result()

    w.put("total_notes_bg", tn_bg)
    w.put("total_notes", lambda i, n, ww, hh: text_img(ww, hh, "総音符数", 24, C["text2"], 800))

    def tn_digit(i, n, ww, hh):
        cv = Canvas(ww, hh)
        cv.text(ww / 2, hh / 2 + 1, str(i), 31, INK, weight=800)
        return cv.result()

    w.put("total_notes_counter", tn_digit)

    # rank plate (frames = dan_color); the engine's name sits on it
    def frame(i, n, ww, hh):
        acc = RANK[i % len(RANK)]
        cv = Canvas(ww, hh)
        banded(cv, (6, 8, ww - 10, hh - 12), acc, 18, 14)
        cv.rect(ww - 10, 16, ww - 4, hh - 6, INK)
        cv.rect(10, hh - 12, ww - 4, hh - 6, INK)
        return cv.result()

    w.put("frame", frame)

    # exam board
    put_nine(w, {"tl": "exam_box_top_left", "t": "exam_box_top", "tr": "exam_box_top_right",
                 "l": "exam_box_left", "c": "exam_box_center", "r": "exam_box_right",
                 "bl": "exam_box_bottom_left", "b": "exam_box_bottom", "br": "exam_box_bottom_right"},
             C["bg2"], px=3)

    def header(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pixbox(cv, 2, 2, ww - 6, hh - 6, fill=C["roll"], shadow=4, px=3)
        cv.text(ww / 2 - 2, hh / 2 - 1, "クリア条件", 23, INK, weight=900, max_w=ww - 28)
        return cv.result()

    w.put("exam_header", header)

    def judge_box(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pixbox(cv, 2, 2, ww - 2, hh - 2, fill=C["bg1"], shadow=0, px=2)
        return cv.result()

    w.put("judge_box", judge_box)
    labels = {"exam_gauge": "魂ゲージ", "exam_combo": "最大コンボ数", "exam_score": "スコア", "exam_hit": "たたけた数",
              "exam_roll": "連打数", "exam_judgeperfect": "良の数", "exam_judgebad": "不可の数",
              "exam_judgegood": "可の数"}
    for k, s in labels.items():
        w.put(k, lambda i, n, ww, hh, s=s: text_img(ww, hh, s, 19, C["text2"], 800, x=2, anchor="lm"))

    def jnum(i, n, ww, hh):
        cv = Canvas(ww, hh)
        cv.text(ww / 2, hh / 2 + 1, str(i), 33, INK, weight=800)
        return cv.result()

    w.put("judge_num", jnum)
    w.put("exam_percent", lambda i, n, ww, hh: text_img(ww, hh, "%", 26, C["text2"], 800))
    w.put("exam_less", lambda i, n, ww, hh: text_img(ww, hh, "未満", 25, INK, 800))
    w.put("exam_more", lambda i, n, ww, hh: text_img(ww, hh, "以上", 25, INK, 800))
    return w.write()


def build_confirm(G):
    w = SubsetWriter(G, SC, "confirm_box")

    def bg(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pixbox(cv, 4, 4, ww - 10, hh - 10, fill=C["bg1"], shadow=6, px=4)
        cv.rect(8, 8, ww - 14, 20, GOLD)
        cv.rect(8, 20, ww - 14, 23, INK)
        return cv.result()

    w.put("bg", bg)
    w.put("confirmation_text", lambda i, n, ww, hh: text_img(ww, hh, "この段位に挑戦しますか？", 34, INK, 800))

    def sel(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pixbox(cv, 4, 4, ww - 8, hh - 10, fill=C["bg1"], shadow=4, px=3)
        return cv.result()

    w.put("selection_box", sel)

    def hi(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pixbox(cv, 4, 4, ww - 8, hh - 10, fill=C["roll"], shadow=4, px=3)
        return cv.result()

    w.put("selection_box_highlight", hi)

    def out(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pixbox(cv, 1, 1, ww - 5, hh - 7, fill=INK, shadow=0, px=3)
        clear_rect(cv, 8, 8, ww - 12, hh - 14)
        cells(cv, ARROW_R, 18, hh / 2 - 12, 4, INK)
        return cv.result()

    w.put("selection_box_outline", out)
    w.put("yes", lambda i, n, ww, hh: text_img(ww, hh, "挑戦する", 32, INK, 900))
    w.put("no", lambda i, n, ww, hh: text_img(ww, hh, "挑戦しない", 32, INK, 900))
    return w.write()


def build_transition(G):
    w = SubsetWriter(G, SC, "dan_transition")

    def background(i, n, ww, hh):
        cv = Canvas(ww, hh, ss=1)
        cv.rect(0, 0, ww, hh, C["bg0"])
        cv.rect(0, 0, ww, 330, SKY)
        for k, t in enumerate((0.33, 0.66)):
            cv.rect(0, 330 + k * 12, ww, 342 + k * 12, mix(SKY, C["bg0"], t))
        cv.rect(0, 600, ww, hh, C["mint"])
        cv.rect(0, 600, ww, 608, INK)
        return cv.result()

    w.put("background", background)

    def duo(i, n, ww, hh):
        # Hoshi and Momo cheering, whole-pixel sprites (Lua slides this picture in)
        cv = Canvas(ww, hh)
        spr(cv, mas("hoshi", "good", 352), 12, hh - 352 - 24)
        spr(cv, mas("momo", "gogo", 352), ww - 352 - 12, hh - 352 - 24)
        for x in (190, 520):
            cells(cv, SPARK, x, hh - 400, 8, C["roll"], edge=INK)
        return cv.result()

    # Green parked the picture at y 753 (+ the engine rise) so the feet ran off the screen: 150 px higher puts them on the ground
    w.put("don", duo, entry={"x": 560, "y": 603})

    def emblem(i, n, ww, hh):
        cv = Canvas(ww, hh)
        c = ww / 2
        pixmedal(cv, c, c, c - 36, 8, GOLD)
        pixdisc(cv, c, c, c - 80, 8, PAPER)
        cells(cv, STAR, c - 11 * 14, c - 5 * 14 - 14, 14, GOLD, edge=INK)
        return cv.result()

    w.put("emblem", emblem)
    w.put("flash", lambda i, n, ww, hh: Image.new("RGBA", (ww, hh), (255, 255, 255, 255)))
    return w.write()


# ================================================================================ retry game
RG = "retry_game"
LAMP = [C["don"], C["ka"], C["roll"], C["ura"], C["normal"], C["oni"]]
# the "もう一回？" window (screen coordinates; the moon texture sits at (320, -140))
WIN = (340, 28, 940, 292)
MX, MY = 320, -140


def tx(x):
    return x - MX


def ty(y):
    return y - MY


def retry_sky(win):
    def draw(i, n, ww, hh):
        cv = Canvas(ww, hh, ss=1)
        top = hexc("#FCE3A4") if win else SKY
        cv.rect(0, 0, ww, hh, C["bg0"])
        cv.rect(0, 0, ww, 318, top)
        for k, t in enumerate((0.33, 0.66)):
            cv.rect(0, 318 + k * 12, ww, 330 + k * 12, mix(top, C["bg0"], t))
        cv.rect(0, 548, ww, hh, C["mint"])
        cv.rect(0, 548, ww, 556, INK)
        cv.rect(0, 556, ww, 566, mix(C["mint"], PAPER, 0.5))
        cv.rect(0, 628, ww, 640, mix(C["mint"], INK, 0.12))
        return cv.result()
    return draw


def build_background(G):
    w = SubsetWriter(G, RG, "background")
    w.put("sky", retry_sky(False))
    w.put("sky_win", retry_sky(True))

    def clouds(i, n, ww, hh):
        cv = Canvas(ww, hh)
        for x, y, c in ((40, 40, 6), (250, 110, 5), (1020, 30, 6), (1130, 120, 5), (110, 150, 4), (1210, 70, 3)):
            cloud(cv, x, y, c)
        return cv.result()

    w.put("stars", clouds)
    return w.write()


def window_base(cv):
    """The pixbox "もう一回？" window drawn into a moon-sized canvas."""
    x0, y0, x1, y1 = (tx(WIN[0]), ty(WIN[1]), tx(WIN[2]), ty(WIN[3]))
    pixbox(cv, x0, y0, x1, y1, fill=C["bg1"], shadow=6, px=4)
    cv.rect(x0 + 4, y0 + 4, x1 - 4, y0 + 60, C["roll"])
    cv.rect(x0 + 4, y0 + 60, x1 - 4, y0 + 63, INK)
    cv.text(x0 + 28, y0 + 33, "もう一回？", 40, INK, weight=900, anchor="lm")
    for cx, label in ((tx(748), "はい"), (tx(872), "いいえ")):
        pixbox(cv, cx - 50, y0 + 10, cx + 50, y0 + 54, fill=PAPER, shadow=3, px=3)
        cv.text(cx, y0 + 32, label, 25, INK, weight=900)
    ix0, iy0, ix1, iy1 = x0 + 12, y0 + 72, x1 - 12, y1 - 12
    pixbox(cv, ix0, iy0, ix1, iy1, fill=SKY, shadow=0, px=3)
    cv.rect(ix0 + 3, iy1 - 38, ix1 - 3, iy1 - 3, C["mint"])
    cv.rect(ix0 + 3, iy1 - 38, ix1 - 3, iy1 - 33, INK)
    cloud(cv, ix0 + 40, iy0 + 18, 5)
    cloud(cv, ix1 - 170, iy0 + 40, 4)


def build_moon(G):
    w = SubsetWriter(G, RG, "moon")

    def moon(i, n, ww, hh):
        cv = Canvas(ww, hh)
        window_base(cv)
        return cv.result()

    w.put("moon", moon)
    w.put_blank("mark")     # Green spins this; pixel art never rotates

    chip_y = ty(WIN[1]) + 10

    def face(win):
        def draw(i, n, ww, hh):
            cv = Canvas(ww, hh)
            cx = tx(748) if win else tx(872)
            label = "はい" if win else "いいえ"
            pixbox(cv, cx - 50, chip_y, cx + 50, chip_y + 44, fill=C["roll"] if win else C["bg3"], shadow=3, px=3)
            cv.text(cx, chip_y + 22, label, 25, INK, weight=900)
            cells(cv, ARROW_R, cx - 50 - 34, chip_y + 10, 4, INK)
            ix1, iy0 = tx(WIN[2]) - 12, ty(WIN[1]) + 72
            if win:
                pixmedal(cv, ix1 - 70, iy0 + 58, 24, 6, C["roll"])
                for sx, sy in ((ix1 - 150, iy0 + 30), (ix1 - 80, iy0 + 120), (tx(WIN[0]) + 90, iy0 + 90)):
                    cells(cv, SPARK, sx, sy, 5, C["roll"], edge=INK)
            else:
                cloud(cv, ix1 - 130, iy0 + 20, 6, col=mix(C["bg3"], INK, 0.25), shade=mix(C["bg3"], INK, 0.5))
                for dx in (0, 30, 60):
                    cells(cv, DROP[:4], ix1 - 118 + dx, iy0 + 78 + dx % 20, 4, C["ka"], edge=None)
            return cv.result()
        return draw

    w.put("face_win", face(True))
    w.put("face_lose", face(False))

    def wave(i, n, ww, hh):
        cv = Canvas(ww, hh)
        x0, y0, x1, y1 = tx(WIN[0]) - 14, ty(WIN[1]) - 14, tx(WIN[2]) + 14, ty(WIN[3]) + 14
        cv.rect(x0 - 4, y0 - 4, x1 + 4, y1 + 4, INK)
        cv.rect(x0, y0, x1, y1, C["roll"])
        clear_rect(cv, x0 + 8, y0 + 8, x1 - 8, y1 - 8)
        return cv.result()

    w.put("wave", wave)
    return w.write()


def build_lamps(G):
    """Progress stars (one pair per lamp). The back / big sets and all glows are blank: the stars at scale 1
    are the only lamps, so nothing is resampled or blurred."""
    w = SubsetWriter(G, RG, "lamps")
    for k in range(6):
        def star(i, n, ww, hh, k=k):
            cv = Canvas(ww, hh)
            cell = 6
            fill = LAMP[k] if i == 1 else C["bg3"]
            gw, gh = len(STAR[0]) * cell, len(STAR) * cell
            x0, y0 = (ww - gw) / 2, (hh - gh) / 2
            cells(cv, STAR, x0, y0, cell, fill, edge=INK)
            if i == 1:
                for ix, iy in ((4, 1), (3, 2), (2, 3), (3, 3)):
                    cv.rect(x0 + ix * cell, y0 + iy * cell, x0 + (ix + 1) * cell, y0 + (iy + 1) * cell, PAPER)
            return cv.result()

        xl = 20 + k * 62
        entry = [{"x": xl, "y": 290}, {"x": 1280 - xl - 96, "y": 290}]
        w.put(f"front_{k}", star, entry=entry)
        w.put_blank(f"back_{k}")
        w.put_blank(f"big_{k}")
        w.put_blank(f"glow_{k}")
    return w.write()


def build_stage(G):
    w = SubsetWriter(G, RG, "stage")
    for k in ("pole", "rope_a", "rope_b", "yagura"):
        w.put_blank(k)

    def hero(who):
        def draw(i, n, ww, hh):
            cv = Canvas(ww, hh)
            cv.rect(34, hh - 12, ww - 34, hh - 4, alpha(INK, 40))
            cv.rect(46, hh - 16, ww - 46, hh - 12, alpha(INK, 40))
            spr(cv, mas(who, "idle", 192), (ww - 192) / 2, hh - 192 - 8)
            return cv.result()
        return draw

    # lifted 76 px: the feet stand on the ground strip above the engine's bottom bar (y > 640 is the engine's)
    w.put("stall_octopus", hero("momo"), entry={"x": 0, "y": 391})
    w.put("stall_squid", hero("hoshi"), entry={"x": 1080, "y": 391})

    def bubble(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pixbox(cv, 0, 0, ww - 5, hh - 9, fill=PAPER, shadow=4, px=3)
        rows, col = ((NOTE, C["ka"]), (HEART, C["don"]), (DROP, C["ka"]))[i % 3]
        c = 4 if len(rows[0]) <= 7 else 3
        gw, gh = len(rows[0]) * c, len(rows) * c
        cells(cv, rows, (ww - 4 - gw) / 2, (hh - 8 - gh) / 2, c, col)
        return cv.result()

    w.put("face_octopus", bubble, entry={"x": 150, "y": 402})
    w.put("face_squid", bubble, entry={"x": 1080, "y": 402})
    return w.write()


def build_hands(G):
    w = SubsetWriter(G, RG, "hands")

    def baton(cv, top, tip):
        """A pixel stick from its butt end `top` to its tip; the fist grips it a third of the way down."""
        pixline(cv, top, tip, 6, 4, 2, INK, C["roll"])
        fx, fy = top[0] + (tip[0] - top[0]) * 0.3, top[1] + (tip[1] - top[1]) * 0.3
        fx, fy = round(fx / 6) * 6, round(fy / 6) * 6
        pixbox(cv, fx - 18, fy - 18, fx + 18, fy + 18, fill=C["pink"], shadow=0, px=3)
        cv.rect(fx - 12, fy - 12, fx - 6, fy - 6, PAPER)

    RD, RU = ((214, 112), (160, 190)), ((226, 52), (190, 142))    # right stick: down / raised
    LD, LU = ((48, 112), (102, 190)), ((36, 52), (72, 142))       # left stick

    def fist(i, n, ww, hh):      # the right-hand stick: down in poses 0/1, raised in 2/3
        cv = Canvas(ww, hh)
        baton(cv, *(RD if i < 2 else RU))
        return cv.result()

    def stick(i, n, ww, hh):     # the left-hand stick: raised in 0/1, down in 2/3
        cv = Canvas(ww, hh)
        baton(cv, *(LU if i < 2 else LD))
        return cv.result()

    w.put("fist_fill", fist)
    w.put("stick_fill", stick)
    w.put_blank("fist_outline")
    w.put_blank("stick_outline")
    return w.write()


def build_drum(G):
    w = SubsetWriter(G, RG, "drum")

    def body(hit):
        def draw(i, n, ww, hh):
            cv = Canvas(ww, hh)
            skin = mix(C["don"], PAPER, 0.35) if hit else C["don"]
            head = C["bg0"] if not hit else PAPER
            cv.rect(40, hh - 14, 84, hh, INK)       # feet
            cv.rect(ww - 84, hh - 14, ww - 40, hh, INK)
            pixbox(cv, 24, 58, ww - 24, hh - 12, fill=skin, shadow=0, px=4)          # barrel
            pixbox(cv, 6, 12, ww - 6, 72, fill=head, shadow=0, px=4, notch=True)    # head
            cv.rect(30, 30, ww - 30, 54, C["bg3"])
            cv.rect(30, 30, ww - 30, 34, mix(C["bg3"], INK, 0.2))
            for k in range(11):
                x = 44 + k * (ww - 100) / 10
                cv.rect(x, 82, x + 12, 94, INK)
                cv.rect(x + 2, 82, x + 10, 90, PAPER)
            cv.rect(40, 104, ww - 40, 108, alpha(INK, 70))
            return cv.result()
        return draw

    w.put("body", body(False))
    w.put("hit", body(True))

    def ring(i, n, ww, hh):
        cv = Canvas(ww, hh)
        cv.rect(0, 0, ww, hh, INK)
        cv.rect(6, 6, ww - 6, hh - 6, C["roll"])
        clear_rect(cv, 14, 14, ww - 14, hh - 14)
        return cv.result()

    w.put("ring", ring)
    return w.write()


def build_effects(G):
    w = SubsetWriter(G, RG, "effects")

    def sparkles(i, n, ww, hh):
        rnd = random.Random(40 + i)
        cv = Canvas(ww, hh)
        for _ in range(16):
            cell = rnd.choice((4, 6, 8))
            x, y = rnd.randrange(10, ww - 60, 4), rnd.randrange(10, hh - 60, 4)
            cells(cv, SPARK, x, y, cell, rnd.choice((C["roll"], PAPER, C["pink"])), edge=INK)
        return cv.result()

    w.put("rays", sparkles)
    w.put("white", lambda i, n, ww, hh: Image.new("RGBA", (ww, hh), (255, 255, 255, 255)))
    w.put_blank("beam")      # Green rotated light beams; pixel art is never rotated

    def firework(i, n, ww, hh):
        cv = Canvas(ww, hh)
        c = ww / 2
        cols = [C["don"], C["roll"], C["ka"], PAPER]
        for k in range(8):
            a = math.radians(k * 45)
            for s, r in enumerate((72, 108, 144, 180)):
                x = round((c + r * math.cos(a)) / 12) * 12
                y = round((c + r * math.sin(a)) / 12) * 12
                sz = 20 - s * 3
                cv.rect(x - sz / 2 - 3, y - sz / 2 - 3, x + sz / 2 + 3, y + sz / 2 + 3, INK)
                cv.rect(x - sz / 2, y - sz / 2, x + sz / 2, y + sz / 2, cols[(k + s) % 4])
        return cv.result()

    w.put("firework", firework)
    w.put_blank("leaf")      # Green's leaf spun across the stage; dropped
    return w.write()


def build_shutter(G):
    w = SubsetWriter(G, RG, "shutter")
    for name, col in (("red", C["pink"]), ("blue", SKY)):
        def tile(i, n, ww, hh, col=col):
            cv = Canvas(ww, hh)
            cv.rect(0, 0, ww, hh, col)
            pixdither_band(cv, 0, 0, ww, hh, mix(col, PAPER, 0.35), cell=16)
            return cv.result()

        def cap(i, n, ww, hh, col=col):
            cv = Canvas(ww, hh)
            cv.rect(0, 0, ww, hh - 18, col)
            pixdither_band(cv, 0, 0, ww, hh - 18, mix(col, PAPER, 0.35), cell=16)
            cv.rect(0, hh - 18, ww, hh - 10, INK)
            for x in range(0, ww, 32):
                cv.rect(x + 8, hh - 10, x + 24, hh, INK)
            return cv.result()
        w.put(f"{name}_tile", tile)
        w.put(f"{name}_cap", cap)
    return w.write()


def build_text(G):
    w = SubsetWriter(G, RG, "text")

    def rule(i, n, ww, hh):
        cv = Canvas(ww, hh)
        x0, y0, x1, y1 = 56, 40, ww - 64, hh - 52
        pixbox(cv, x0, y0, x1, y1, fill=C["bg1"], shadow=8, px=5)
        cv.rect(x0 + 5, y0 + 5, x1 - 5, y0 + 18, C["roll"])
        cv.rect(x0 + 5, y0 + 18, x1 - 5, y0 + 22, INK)
        c = ww / 2 - 4
        cv.text(c, 168, "とにかく", 64, INK, weight=900)
        cv.text(c, 262, "太鼓を連打！", 82, C["red_t"], weight=900)
        pixdither_band(cv, x0 + 40, 330, x1 - 40, 342, C["bg3"], cell=6)
        cv.text(c, 392, "成功するともう1曲あそべる！", 36, C["text2"], weight=800, max_w=520)
        spr(cv, mas("momo", "gogo", 160), x0 + 24, y1 - 160 - 22)
        spr(cv, mas("hoshi", "good", 160), x1 - 160 - 24, y1 - 160 - 22)
        return cv.result()

    w.put("rule_ja", rule)

    def plate(label, size, fill, tcol, box_fill):
        def draw(i, n, ww, hh):
            cv = Canvas(ww, hh)
            pixbox(cv, 4, 4, ww - 12, hh - 12, fill=box_fill, shadow=8, px=5)
            cv.text(ww / 2 - 4, hh / 2 - 3, label, size, tcol, weight=900, max_w=ww - 80)
            return cv.result()
        return draw

    w.put("ready_ja", plate("よーい", 74, None, INK, C["bg1"]))
    w.put("go_ja", plate("ドン！", 130, None, INK, C["roll"]))
    w.put("success_ja", plate("復活成功", 104, None, INK, C["roll"]))
    w.put("failure_ja", plate("復活失敗", 104, None, C["blue_t"], C["bg1"]))
    w.put("more_ja", plate("もう1曲あそべる！", 50, None, INK, C["bg1"]))

    def burst(i, n, ww, hh):
        cv = Canvas(ww, hh)
        x0, y0, x1, y1 = ww / 2 - 190, hh / 2 - 90, ww / 2 + 190, hh / 2 + 90
        pixbox(cv, x0, y0, x1, y1, fill=C["roll"], shadow=10, px=6)
        cv.rect(x0 + 6, y0 + 6, x1 - 6, y0 + 16, mix(C["roll"], PAPER, 0.5))
        for sx, sy in ((x0 - 30, y0 - 20), (x1 - 10, y0 - 26), (x1 - 20, y1 - 30)):
            cells(cv, SPARK, sx, sy, 6, C["roll"], edge=INK)
        cv.text(ww / 2, hh / 2 - 2, "連打", 124, INK, weight=900)
        return cv.result()

    w.put("burst_ja", burst)

    def digit(i, n, ww, hh):
        cv = Canvas(ww, hh)
        pixtext(cv, ww / 2, (hh - 7 * 18) / 2 - 4, str(i), 18, C["roll"], edge=INK, shadow=0)
        return cv.result()

    # the counter sits inside the window's sky inset (Green's counter was centred on the moon)
    w.put("digits", digit, entry={"x": 548, "y": 82})
    return w.write()


# ================================================================================ game over
GO = "game_over"


def build_game_over(G):
    w = SubsetWriter(G, GO, "global")

    def scene(cv, ww, hh):
        cv.rect(0, 0, ww, hh, C["bg0"])
        cv.rect(0, 0, ww, 300, SKY)
        for k, t in enumerate((0.33, 0.66)):
            cv.rect(0, 300 + k * 10, ww, 310 + k * 10, mix(SKY, C["bg0"], t))
        cv.rect(0, 600, ww, hh, C["mint"])
        cv.rect(0, 600, ww, 606, INK)
        cv.rect(0, 606, ww, 614, mix(C["mint"], PAPER, 0.5))

    def curtain(i, n, ww, hh):
        cv = Canvas(ww, hh)
        scene(cv, ww, hh)
        cloud(cv, 70, 90, 6)       # one cloud per tile: tiles repeat every 360 px
        cloud(cv, 250, 200, 3)
        pixdither_band(cv, 0, 650, ww, 700, mix(C["mint"], INK, 0.1), cell=12)
        return cv.result()

    w.put("curtain", curtain)

    def side(i, n, ww, hh):
        cv = Canvas(ww, hh)
        scene(cv, ww, hh)
        cloud(cv, 250, 90, 6)
        cloud(cv, 470, 200, 3)
        # the leading edge: an ink stair with a checker lip
        cv.rect(0, 0, 12, hh, INK)
        pixdither_band(cv, 12, 0, 60, hh, C["bg3"], cell=12)
        for y in range(0, hh, 48):
            cv.rect(0, y, 24 if (y // 48) % 2 else 12, y + 24, INK)
        return cv.result()

    w.put("curtain_side", side)

    def runner(i, n, ww, hh):
        cv = Canvas(ww, hh)
        hop = (0, 6, 12, 6, 0, 6, 12, 6, 0, 6)[i % 10]
        cv.rect(36, hh - 14, ww - 20 + 0, hh - 6, alpha(INK, 40))
        spr(cv, mas("hoshi", "good", 192, i % 2), 4, hh - 192 - 18 - hop)
        return cv.result()

    w.put("kitsune", runner)

    def over(lines):
        def draw(i, n, ww, hh):
            cv = Canvas(ww, hh)
            pixbox(cv, 8, 8, ww - 18, hh - 18, fill=C["bg1"], shadow=10, px=6)
            cv.rect(14, 14, ww - 24, 26, C["roll"])
            cv.rect(14, 26, ww - 24, 30, INK)
            # Momo stands on a floor line inside the plate (feet ON the line, clear of the text column)
            fy = hh - 18 - 26
            cv.rect(26, fy, 214, fy + 6, INK)
            spr(cv, mas("momo", "fail", 170), 28, fy - 170 + 8)
            pixtext(cv, 440, 56, "GAME OVER", 8, C["p1"], edge=INK, shadow=6)
            (s2, z2, c2), (s3, z3, c3) = lines
            cv.text(456, 178, s2, z2, c2, weight=900, max_w=480)
            cv.text(456, 236, s3, z3, c3, weight=800, max_w=480)
            return cv.result()
        return draw

    w.put("game_over_text_ja", over([("またあそんでね！", 54, INK), ("バチはバチ入れにもどしてね！", 28, C["text2"])]))
    w.put("game_over_text_en", over([("See you next time!", 52, INK),
                                     ("Please put the drumsticks back in the holder!", 26, C["text2"])]))
    n1 = w.write()
    w2 = SubsetWriter(G, GO, "logged_out")

    def ad(i, n, ww, hh):
        cv = Canvas(ww, hh)
        scene(cv, ww, hh)
        for x, y, c in ((120, 90, 6), (520, 40, 5), (900, 120, 6), (1100, 50, 4)):
            cloud(cv, x, y, c)
        pixbox(cv, 336, 392, 944, 560, fill=C["bg1"], shadow=8, px=5)
        cv.rect(341, 397, 939, 409, C["roll"])
        cv.rect(341, 409, 939, 413, INK)
        cv.text(640, 472, "ご利用ありがとうございました", 36, INK, weight=900, max_w=560)
        cv.text(640, 524, "Thank you for playing", 24, C["text2"], weight=700)
        # feet on the ground line (y 600); the two sprites have different bottom margins
        spr(cv, mas("momo", "good", 256), 48, 610 - 256)
        spr(cv, mas("hoshi", "good", 256), 976, 602 - 256)
        return cv.result()

    w2.put("bana_ad", ad)
    return n1 + w2.write()


def build(ctx):
    G = ctx.G
    n = 0
    for fn in (build_global, build_back, build_box, build_yellow_box, build_confirm, build_transition,
               build_lamps, build_background, build_moon, build_stage, build_hands, build_drum, build_effects,
               build_shutter, build_text, build_game_over):
        n += fn(G)
    return n
